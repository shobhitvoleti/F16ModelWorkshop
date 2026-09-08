"""
Velocity-scheduled linear MPC for the workshop plant. States and commands use the
plant's physical channel order; each QP uses scaled deviations from its own trim.
"""
module VelocityMPC

using LinearAlgebra
using ADTypes: AutoFiniteDiff
import ControlSystemsBase as CS
import ControlSystemsMTK
import LinearMPC as LMPC
import ModelingToolkit as MTK
import Symbolics
import NonlinearSolve
import SciMLBase
import OrdinaryDiffEqDefault
using ..F16ModelWorkshop: Plant

export F16Dynamics, VelocityMPCBank, build_velocity_mpc, scheduling_weights,
    trim_state, control!, simulate, linear_model, trim_point

const STATE_NAMES = (:npos, :epos, :alt, :phi, :theta, :psi, :vt, :alpha, :beta, :P, :Q, :R)
const CONTROL_NAMES = (:T, :el, :ail, :rud)
const FLIGHT = 3:12
const VELOCITY = 7

function finite_vector(x, n, name)
    x isa AbstractVector || throw(ArgumentError("$name must be a vector"))
    length(x) == n || throw(DimensionMismatch("$name must have $n entries"))
    all(isfinite, x) || throw(ArgumentError("$name must contain only finite values"))
    return Float64[x...]
end

function check_grid(velocities)
    grid = Float64[velocities...]
    length(grid) >= 2 || throw(ArgumentError("velocity grid needs at least two knots"))
    all(isfinite, grid) && all(>(0), grid) ||
        throw(ArgumentError("velocity knots must be finite and positive (m/s)"))
    all(>(0), diff(grid)) || throw(ArgumentError("velocity knots must be strictly increasing"))
    return grid
end

"""
    scheduling_weights(velocities, velocity; method=:linear, outside=:error)

Weights for measured true airspeed in m/s. Linear scheduling activates at most two
neighbors; `:nearest` activates one (ties choose the upper knot). Out-of-range
speeds throw unless `outside=:clamp` is explicitly selected. NaN/Inf always throw.
"""
function scheduling_weights(velocities, velocity; method=:linear, outside=:error)
    grid = check_grid(velocities)
    isfinite(velocity) || throw(ArgumentError("measured velocity must be finite"))
    method in (:linear, :nearest) || throw(ArgumentError("method must be :linear or :nearest"))
    outside in (:error, :clamp) || throw(ArgumentError("outside must be :error or :clamp"))
    if outside === :error && !(first(grid) <= velocity <= last(grid))
        throw(DomainError(velocity, "measured velocity is outside the MPC design grid"))
    end
    v = clamp(velocity, first(grid), last(grid))
    hi = searchsortedfirst(grid, v)
    w = zeros(length(grid))
    if hi == 1 || grid[hi] == v
        w[hi] = 1
    else
        lo = hi - 1
        a = (v - grid[lo]) / (grid[hi] - grid[lo])
        if method === :nearest
            w[a < 0.5 ? lo : hi] = 1
        else
            w[lo], w[hi] = 1 - a, a
        end
    end
    return w
end

"""
    F16Dynamics(; xcg=0.35)

Compile the Dyad-generated plant into nonlinear dynamics and a symbolic Jacobian
function once. Public state order is `STATE_NAMES`; inputs are thrust (N) and
three surface deflections (degrees). Leading-edge flap is held at zero.
"""
struct F16Dynamics{F,L,P}
    rhs::F
    jacobian::L
    parameters::P
    permutation::Vector{Int}
end

function F16Dynamics(; xcg=0.35)
    isfinite(xcg) || throw(ArgumentError("xcg must be finite"))
    plant = Plant.F16PlantModel(; name=:mpc_plant, xcg)
    plant = MTK.toggle_namespacing(plant, false)
    inputs = collect(plant.u_in)
    states = [getproperty(plant, s) for s in STATE_NAMES]
    mats, sys = MTK.linearize_symbolic(plant, inputs, states; split=false)
    unknowns = MTK.unknowns(sys)
    permutation = [findfirst(isequal(s), unknowns) for s in states]
    length(unknowns) == 12 && all(!isnothing, permutation) ||
        error("MPC linearization must preserve the twelve physical plant states")
    pars = MTK.parameters(sys)
    # The generated state-space function follows ControlSystemsMTK's symbolic
    # linearization interface; input operating values remain explicit parameters.
    symbolic_model = CS.ss(mats.A, mats.B, mats.C, mats.D)
    jacobian = Symbolics.build_function(symbolic_model, unknowns, pars;
        expression=Val(false), force_SA=true)
    rhs = MTK.generate_control_function(sys, inputs; split=false)
    p = MTK.varmap_to_vars(MTK.initial_conditions(sys), rhs.ps)
    return F16Dynamics(rhs.f[1], (jacobian, pars, inputs, sys), p, Int[permutation...])
end

function (d::F16Dynamics)(x, u)
    xx = finite_vector(x, 12, "state")
    uu = finite_vector(u, 4, "control")
    xx[VELOCITY] > 0 || throw(DomainError(xx[VELOCITY], "true airspeed must be positive"))
    internal = xx[invperm(d.permutation)]
    result = d.rhs(internal, [uu; 0.0], d.parameters, 0.0)
    return collect(result[d.permutation])
end

"""
    trim_point(dynamics, velocity; altitude=3000.0)

Straight-and-level trim at fixed altitude and airspeed. Solve thrust, elevator,
angle of attack, and pitch, and verify all ten flight-state derivatives. North
position advances at airspeed and is deliberately excluded from equilibrium.
"""
function trim_point(d::F16Dynamics, velocity; altitude=3000.0)
    isfinite(velocity) && velocity > 0 || throw(ArgumentError("trim velocity must be positive and finite"))
    isfinite(altitude) && 0 <= altitude <= 11000 ||
        throw(ArgumentError("altitude must be within the plant's troposphere model (0–11000 m)"))
    function unpack(z)
        x = zeros(eltype(z), 12)
        x[3], x[5], x[7], x[8] = altitude, z[4], velocity, z[3]
        u = [1e4*z[1], z[2], zero(z[1]), zero(z[1])]
        return x, u
    end
    # Numerical differentiation avoids imposing dual-number support on the
    # compiled ModelingToolkit function and its concrete parameter storage.
    residual(z, _) = begin
        x, u = unpack(z)
        f = d(x, u)
        [f[7], 100*f[8], f[3], 100*f[11]]
    end
    problem = NonlinearSolve.NonlinearProblem(residual, [1.1, -0.7, 0.06, 0.06])
    sol = NonlinearSolve.solve(problem, NonlinearSolve.NewtonRaphson(; autodiff=AutoFiniteDiff());
        abstol=1e-10, reltol=1e-10, maxiters=100)
    SciMLBase.successful_retcode(sol) || error("trim failed at $velocity m/s: $(sol.retcode)")
    x, u = unpack(sol.u)
    residual_norm = norm(d(x, u)[FLIGHT], Inf)
    residual_norm < 1e-7 || error("trim residual at $velocity m/s is $residual_norm")
    return (; velocity=Float64(velocity), x, u, residual_norm)
end

"""
    linear_model(dynamics, x, u; Ts=0.05)

Evaluate the symbolic linearization at a physical operating point, reorder it to
`STATE_NAMES`, remove horizontal position, and discretize with a zero-order hold.
"""
function linear_model(d::F16Dynamics, x, u; Ts=0.05)
    isfinite(Ts) && Ts > 0 || throw(ArgumentError("Ts must be positive and finite"))
    xx, uu = finite_vector(x, 12, "state"), finite_vector(u, 4, "control")
    jac, pars, inputs, sys = d.jacobian
    values = merge(MTK.initial_conditions(sys), Dict(inputs .=> [uu; 0.0]))
    p = MTK.varmap_to_vars(values, pars)
    model = jac(xx[invperm(d.permutation)], p)
    A = Matrix{Float64}(model.A[d.permutation, d.permutation])
    B = Matrix{Float64}(model.B[d.permutation, 1:4])
    discrete = CS.c2d(CS.ss(A[FLIGHT, FLIGHT], B[FLIGHT, :], Matrix{Float64}(I, 10, 10), zeros(10,4)), Ts)
    return (; A=discrete.A, B=discrete.B, Ac=A, Bc=B, Ts=Float64(Ts))
end

struct MPCMember{T,M}
    trim::T
    model::M
    controller::LMPC.MPC
end

"""
A bank of condensed LinearMPC QPs. `previous` stores the physical applied command;
`solves` counts member optimizations. Use a separate bank for each control loop.
"""
mutable struct VelocityMPCBank{D,M}
    dynamics::D
    grid::Vector{Float64}
    members::Vector{M}
    Ts::Float64
    state_scale::Vector{Float64}
    input_scale::Vector{Float64}
    umin::Vector{Float64}
    umax::Vector{Float64}
    slew::Vector{Float64}
    method::Symbol
    outside::Symbol
    previous::Vector{Float64}
    solves::Int
end

"""
    build_velocity_mpc(velocities=[140.0, 152.4, 170.0]; kwargs...)

Build one scaled, constrained linear MPC per velocity knot, at fixed `altitude`
and `xcg`. The scheduling variable is measured true airspeed, not the reference.
Defaults use Ts=0.05 s and Np=40 samples. `umin`, `umax`, and `slew` are physical
control limits in [N, deg, deg, deg] and per-second units. All ten flight states
are measured; this is state feedback, with no state estimator.

The positive diagonal Q/R/Rr weights apply in scaled coordinates. Every member
uses a discrete LQR terminal cost. Convex command blending preserves common
input/slew limits but does not establish stability or recursive feasibility.
"""
function build_velocity_mpc(velocities=[140.0, 152.4, 170.0];
        altitude=3000.0, xcg=0.35, Ts=0.05, Np=40,
        Q=ones(10), R=fill(0.1, 4), Rr=fill(0.02, 4),
        state_scale=[100.0, 0.1, 0.1, 0.1, 10.0, 0.1, 0.1, 0.2, 0.2, 0.2],
        input_scale=[10000.0, 10.0, 10.0, 10.0],
        umin=[0.0, -25.0, -21.5, -30.0], umax=[50000.0, 25.0, 21.5, 30.0],
        slew=[20000.0, 60.0, 80.0, 120.0], method=:linear, outside=:error,
        dynamics=nothing)
    grid = check_grid(velocities)
    scheduling_weights(grid, first(grid); method, outside)
    isfinite(Ts) && Ts > 0 || throw(ArgumentError("Ts must be positive and finite"))
    Np isa Integer && Np >= 2 || throw(ArgumentError("Np must be an integer at least 2"))
    sx, su = finite_vector(state_scale,10,"state_scale"), finite_vector(input_scale,4,"input_scale")
    q, r, rr = finite_vector(Q,10,"Q"), finite_vector(R,4,"R"), finite_vector(Rr,4,"Rr")
    all(>(0), [sx; su; q; r]) && all(>=(0), rr) ||
        throw(ArgumentError("scales, Q and R must be positive; Rr must be nonnegative"))
    lower, upper, rate = finite_vector(umin,4,"umin"), finite_vector(umax,4,"umax"), finite_vector(slew,4,"slew")
    all(lower .< upper) && all(>(0),rate) || throw(ArgumentError("invalid input or slew limits"))
    dynamics = isnothing(dynamics) ? F16Dynamics(; xcg) : dynamics
    members = map(grid) do velocity
        tr = trim_point(dynamics, velocity; altitude)
        all(lower .<= tr.u .<= upper) || error("trim command at $velocity m/s violates input bounds")
        model = linear_model(dynamics, tr.x, tr.u; Ts)
        A = Diagonal(1 ./ sx) * model.A * Diagonal(sx)
        B = Diagonal(1 ./ sx) * model.B * Diagonal(su)
        mpc = LMPC.MPC(LMPC.Model(A, B; Ts); Np, Nc=Np)
        LMPC.settings!(mpc; reference_tracking=true)
        terminal = CS.are(CS.Discrete, A, B, Diagonal(q), Diagonal(r))
        LMPC.set_objective!(mpc; Q=q, R=r, Rr=rr, Qf=terminal)
        LMPC.set_input_bounds!(mpc; umin=(lower-tr.u)./su, umax=(upper-tr.u)./su)
        identity = Matrix{Float64}(I,4,4)
        LMPC.add_constraint!(mpc; Au=identity, Aup=-identity,
            lb=-rate .* Ts ./ su, ub=rate .* Ts ./ su, ks=1:Np)
        LMPC.setup!(mpc)
        mpc.mpqp_issetup || error("MPC setup failed at $velocity m/s")
        MPCMember(tr, model, mpc)
    end
    previous = copy(members[cld(length(members),2)].trim.u)
    return VelocityMPCBank(dynamics, grid, members, Float64(Ts), sx, su,
        lower, upper, rate, method, outside, previous, 0)
end

"""
    trim_state(bank, velocity; altitude=bank.members[1].trim.x[3])

Interpolate a physical trim reference. This interpolation is a set-point generator,
not a new nonlinear trim solve. References outside the bank always throw.
"""
function trim_state(bank::VelocityMPCBank, velocity; altitude=bank.members[1].trim.x[3])
    isfinite(altitude) || throw(ArgumentError("reference altitude must be finite"))
    w = scheduling_weights(bank.grid, velocity)
    x = sum(w[i] * bank.members[i].trim.x for i in eachindex(w))
    x[3], x[7] = altitude, velocity
    return x
end

"""
    control!(bank, measured_state; reference, applied=bank.previous)

Solve only the active members and blend their absolute commands. Every member
receives `applied` translated into its own trim coordinates, including after a
schedule switch. Pass actual actuator commands here if they differ from the last
requested command. Solver or feasibility failures throw; no stale control is returned.
Returns `(; u, weights, active)` and updates `bank.previous` after validation.
"""
function control!(bank::VelocityMPCBank, measured_state; reference, applied=bank.previous)
    x = finite_vector(measured_state,12,"measured_state")
    ref = finite_vector(reference,12,"reference")
    prev = finite_vector(applied,4,"applied")
    all(bank.umin .<= prev .<= bank.umax) || throw(ArgumentError("applied command is outside input limits"))
    w = scheduling_weights(bank.grid,x[VELOCITY]; method=bank.method,outside=bank.outside)
    active = findall(>(0),w)
    u = zeros(4)
    # Bank scheduling follows JuliaComputing/MPCComponents.jl#32; absolute command
    # blending also accounts for the F-16's different trim at each velocity knot.
    for i in active
        member = bank.members[i]
        tr, mpc = member.trim, member.controller
        delta = LMPC.compute_control(mpc, (x[FLIGHT]-tr.x[FLIGHT])./bank.state_scale;
            r=(ref[FLIGHT]-tr.x[FLIGHT])./bank.state_scale,
            uprev=(prev-tr.u)./bank.input_scale, check=true)
        bank.solves += 1
        u .+= w[i] .* (tr.u + bank.input_scale .* delta)
    end
    all(isfinite,u) || error("MPC returned nonfinite control")
    tolerance = 1e-5 .* bank.input_scale
    all(bank.umin-tolerance .<= u .<= bank.umax+tolerance) || error("MPC command violates input limits")
    all(abs.(u-prev) .<= bank.slew .* bank.Ts + tolerance) || error("MPC command violates slew limits")
    # Remove solver roundoff only after rejecting material constraint violations.
    u .= clamp.(u, max.(bank.umin, prev-bank.slew*bank.Ts),
        min.(bank.umax, prev+bank.slew*bank.Ts))
    bank.previous .= u
    return (; u, weights=w, active)
end

"""
    simulate(bank; x0, reference, duration=20.0, applied0=bank.previous)

Sample the nonlinear Dyad plant at `bank.Ts`, holding each optimized command over
one ODE interval. `reference` is a physical 12-state vector or a function of time.
Returns sample-aligned state, command, reference, and weight matrices. Commands and
weights have one fewer column than states. No project assets are overwritten.
"""
function simulate(bank::VelocityMPCBank; x0, reference, duration=20.0, applied0=bank.previous)
    isfinite(duration) && duration > 0 || throw(ArgumentError("duration must be positive and finite"))
    steps = round(Int,duration/bank.Ts)
    isapprox(steps*bank.Ts,duration; atol=1e-10,rtol=1e-10) ||
        throw(ArgumentError("duration must be a whole number of sample intervals"))
    state = finite_vector(x0,12,"x0")
    previous = finite_vector(applied0,4,"applied0")
    times = collect((0:steps) .* bank.Ts)
    X, U, W, Ref = zeros(12,steps+1), zeros(4,steps), zeros(length(bank.grid),steps), zeros(12,steps)
    X[:,1] = state
    for k in 1:steps
        r = reference isa AbstractVector ? reference : reference(times[k])
        output = control!(bank,state; reference=r,applied=previous)
        U[:,k], W[:,k], Ref[:,k] = output.u, output.weights, r
        problem = SciMLBase.ODEProblem((x,u,t)->bank.dynamics(x,u),state,(times[k],times[k+1]),output.u)
        sol = OrdinaryDiffEqDefault.solve(problem; abstol=1e-9,reltol=1e-8,save_everystep=false)
        SciMLBase.successful_retcode(sol) || error("nonlinear simulation failed at t=$(times[k]): $(sol.retcode)")
        state = finite_vector(sol.u[end],12,"simulated state")
        X[:,k+1] = state
        previous = output.u
    end
    return (; t=times,x=X,u=U,weights=W,reference=Ref)
end

end
