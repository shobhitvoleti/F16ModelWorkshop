"""
Design-time support for the velocity-scheduled MPC of tutorial step 7: the plant's
symbolic linearization, straight-and-level trim at an airspeed, and the bank of
`LinearMPC` controllers that `dyad/Tutorial/07_velocity_mpc.dyad` hands to
`MPCComponents.Experimental`. The loop itself is Dyad; this module only supplies the
numbers a Dyad structural parameter cannot compute on its own.

Controller units are kilonewtons of thrust and degrees of surface deflection; plant
units are newtons and degrees. `CONTROL_UNITS` converts between them.
"""
module VelocityMPC

using LinearAlgebra
using ADTypes: AutoFiniteDiff
import ControlSystemsBase as CS
import ControlSystemsMTK
import MPCComponents
import ModelingToolkit as MTK
import Symbolics
import NonlinearSolve
import SciMLBase
using ..F16ModelWorkshop: Plant

export F16Dynamics, bank, linear_model, member_design, reference_map, trim_command, trim_point,
    trim_states

"Public state order of the plant, matching `F16PlantModel.y_out`."
const STATE_NAMES = (:npos, :epos, :alt, :phi, :theta, :psi, :vt, :alpha, :beta, :P, :Q, :R)
"Control order of the plant's first four inputs; the leading-edge flap is held at zero."
const CONTROL_NAMES = (:T, :el, :ail, :rud)
"The ten regulated states: everything but the horizontal position, which never settles."
const FLIGHT = 3:12
"Index of true airspeed within `STATE_NAMES`."
const VELOCITY = 7
"Index of pitch attitude within `STATE_NAMES`."
const PITCH = 5
"Index of angle of attack within `STATE_NAMES`."
const ANGLE_OF_ATTACK = 8
"Plant units per controller unit, [N/kN, deg/deg, deg/deg, deg/deg]."
const CONTROL_UNITS = [1000.0, 1.0, 1.0, 1.0]

"Airspeed knots the controller bank is designed at, m/s."
const KNOTS = [140.0, 152.4, 170.0]
"Altitude every knot is trimmed at, m."
const ALTITUDE = 3000.0
"Airspeed the closed loop starts trimmed at, m/s."
const INITIAL_VELOCITY = 148.0
"Center of gravity, as a fraction of the mean aerodynamic chord."
const XCG = 0.35

"Cost weight of each regulated state, in units of `STATE_SCALES`."
const STATE_WEIGHTS = ones(10)
"""
Bryson-rule scales of the ten regulated states `STATE_NAMES[FLIGHT]`: the deviation of
each state that costs one unit of `STATE_WEIGHTS`.
"""
const STATE_SCALES = [100.0, 0.1, 0.1, 0.1, 10.0, 0.1, 0.1, 0.2, 0.2, 0.2]
"Cost weight of each command, in units of `COMMAND_SCALES`."
const COMMAND_WEIGHTS = fill(0.1, 4)
"""
Bryson-rule scales of the four commands `[kN, deg, deg, deg]`: the departure from the
trimmed command that costs one unit of `COMMAND_WEIGHTS`.
"""
const COMMAND_SCALES = fill(10.0, 4)
"Lower bound of each command, `[kN, deg, deg, deg]`."
const COMMAND_MIN = [0.0, -25.0, -21.5, -30.0]
"Upper bound of each command, `[kN, deg, deg, deg]`."
const COMMAND_MAX = [50.0, 25.0, 21.5, 30.0]
"Largest change of each command per second, `[kN/s, deg/s, deg/s, deg/s]`."
const COMMAND_RATE = [20.0, 60.0, 80.0, 120.0]

function finite_vector(x, n, name)
    x isa AbstractVector || throw(ArgumentError("$name must be a vector"))
    length(x) == n || throw(DimensionMismatch("$name must have $n entries"))
    all(isfinite, x) || throw(ArgumentError("$name must contain only finite values"))
    return Vector{Float64}(x)
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
    F16Dynamics(plant::ModelingToolkit.System)
    F16Dynamics(; xcg=0.35)

Compile an F16 plant into nonlinear dynamics and a symbolic Jacobian function once.
The keyword form builds `Plant.F16PlantModel` at the given CG; pass a `System` to use
a plant configured elsewhere. Public state order is `STATE_NAMES`; inputs are thrust
(N) and three surface deflections (degrees). Leading-edge flap is held at zero.
`permutation` maps the public order onto the compiled system's unknowns, and
`inverse_permutation` maps back.
"""
struct F16Dynamics{F,L,P}
    rhs::F
    jacobian::L
    parameters::P
    permutation::Vector{Int}
    inverse_permutation::Vector{Int}
end

function F16Dynamics(; xcg=XCG)
    isfinite(xcg) || throw(ArgumentError("xcg must be finite"))
    return F16Dynamics(Plant.F16PlantModel(; name=:mpc_plant, xcg))
end

function F16Dynamics(plant::MTK.System)
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
    order = Int[permutation...]
    return F16Dynamics(rhs.f[1], (jacobian, pars, inputs, sys), p, order, invperm(order))
end

function (d::F16Dynamics)(x, u)
    xx = finite_vector(x, 12, "state")
    uu = finite_vector(u, 4, "control")
    xx[VELOCITY] > 0 || throw(DomainError(xx[VELOCITY], "true airspeed must be positive"))
    internal = xx[d.inverse_permutation]
    result = d.rhs(internal, [uu; 0.0], d.parameters, 0.0)
    return collect(result[d.permutation])
end

"""
    trim_point(dynamics, velocity; altitude=3000.0)

Straight-and-level trim at fixed altitude and airspeed. Solve thrust, elevator,
angle of attack, and pitch, and verify all ten flight-state derivatives. North
position advances at airspeed and is deliberately excluded from equilibrium.
"""
function trim_point(d::F16Dynamics, velocity; altitude=ALTITUDE)
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
    model = jac(xx[d.inverse_permutation], p)
    A = Matrix{Float64}(model.A[d.permutation, d.permutation])
    B = Matrix{Float64}(model.B[d.permutation, 1:4])
    discrete = CS.c2d(CS.ss(A[FLIGHT, FLIGHT], B[FLIGHT, :], Matrix{Float64}(I, 10, 10), zeros(10,4)), Ts)
    return (; A=discrete.A, B=discrete.B, Ac=A, Bc=B, Ts=Float64(Ts))
end

# Compiling the plant and solving a trim are the two expensive steps here, and one Dyad
# model asks for them from several independent structural parameters (the bank, the
# plant's initial state, the reference gains). Memoizing on the arguments keeps a model
# build to one symbolic linearization and one trim solve per flight condition.
const _DYNAMICS = Dict{Float64,F16Dynamics}()
const _TRIMS = Dict{NTuple{3,Float64},NamedTuple}()

"""
    dynamics(xcg=XCG) -> F16Dynamics

The compiled plant dynamics at center of gravity `xcg`, built on first use and reused
afterwards.
"""
dynamics(xcg=XCG) = get!(() -> F16Dynamics(; xcg), _DYNAMICS, Float64(xcg))

function _trim(velocity, altitude, xcg)
    key = (Float64(velocity), Float64(altitude), Float64(xcg))
    return get!(() -> trim_point(dynamics(xcg), velocity; altitude), _TRIMS, key)
end

"""
    trim_states(velocity=INITIAL_VELOCITY, altitude=ALTITUDE; xcg=XCG) -> Vector{Float64}

The twelve absolute plant states `STATE_NAMES` of straight-and-level flight at
`velocity` (m/s) and `altitude` (m). `VelocityMPCDemo` seeds the plant's `*_init`
parameters and its reference gains from this, so the flight condition the loop starts
from and the trims the bank is built around are one and the same solve.
"""
trim_states(velocity=INITIAL_VELOCITY, altitude=ALTITUDE; xcg=XCG) =
    copy(_trim(velocity, altitude, xcg).x)

"""
    trim_command(velocity=INITIAL_VELOCITY, altitude=ALTITUDE; xcg=XCG) -> Vector{Float64}

The trimmed command `[thrust (kN), elevator, aileron, rudder (deg)]` of the same flight
condition, in the controller's units. `LinearMPCScheduledOptimizer.u_init` takes this as
the command assumed applied before the first tick, so the rate limits do not have to
walk the thrust up from zero.
"""
trim_command(velocity=INITIAL_VELOCITY, altitude=ALTITUDE; xcg=XCG) =
    _trim(velocity, altitude, xcg).u ./ CONTROL_UNITS

"""
    reference_map(velocities=KNOTS, altitude=ALTITUDE; xcg=XCG) -> Matrix{Float64}

The `10 x (1 + length(velocities))` matrix `VelocityMPCDemo` gives its reference
`MatrixGain`, mapping `[commanded airspeed; member weights]` onto the references of the
ten regulated states `STATE_NAMES[FLIGHT]`.

Column 1 routes the commanded airspeed into the airspeed channel. Column `1 + j` holds
knot `j`'s trimmed pitch attitude and angle of attack in the pitch and angle-of-attack
channels, so those two references come out as `Σ_j w_j θ_j` and `Σ_j w_j α_j`:
piecewise linear in airspeed, exact at the knots the bank members were built from, and
read from the same trim solve as the members themselves. Every other channel is
regulated to a constant the model supplies separately, so its row is zero.

`altitude` selects the flight condition the trims are taken at; it does not itself
appear in the matrix.
"""
function reference_map(velocities=KNOTS, altitude=ALTITUDE; xcg=XCG)
    grid = check_grid(velocities)
    channel(state) = state - first(FLIGHT) + 1
    K = zeros(length(FLIGHT), 1 + length(grid))
    K[channel(VELOCITY), 1] = 1.0
    for (j, velocity) in pairs(grid)
        x = _trim(velocity, altitude, xcg).x
        K[channel(PITCH), 1 + j] = x[PITCH]
        K[channel(ANGLE_OF_ATTACK), 1 + j] = x[ANGLE_OF_ATTACK]
    end
    return K
end

"""
    member_design(velocity, altitude=ALTITUDE, Ts=0.05; xcg=XCG, q=STATE_WEIGHTS,
                  sx=STATE_SCALES, r=COMMAND_WEIGHTS, su=COMMAND_SCALES) -> NamedTuple

One bank member: the plant's linearization at the straight-and-level trim of `velocity`
(m/s) and `altitude` (m), together with the quadratic cost built on it. States are the
ten regulated states `STATE_NAMES[FLIGHT]` in plant units, commands are kilonewtons of
thrust and degrees of deflection, and everything is in the absolute physical frame
`bank` puts every member in rather than in deviation coordinates.

The fields are

- `velocity`, `x`, `u` — the flight condition, its ten regulated trim states, and its
  trimmed command in controller units.
- `A`, `B`, `f_offset` — the continuous model `ẋ = A x + B u + f_offset`, whose affine
  term `-A x - B u` makes the trim an exact equilibrium.
- `F`, `G`, `Ts` — the same model under a zero-order hold of period `Ts`.
- `Q1`, `Q2` — the stage weights `diagm(q ./ sx.^2)` and `diagm(r ./ su.^2)`, penalizing
  the state against a reference and the command *level* against `u`.
- `eu` — the linear control cost `-Q2 u` that performs that centering in LinearMPC's
  `0.5 u' Q2 u + eu'u` convention.
- `Qf` — the terminal weight `are(Discrete, F, G, Q1, Q2)`, the cost-to-go of that same
  stage cost.
- `K` — the discrete LQR gain `lqr(Discrete, F, G, Q1, Q2)`. Because `Qf` is the
  cost-to-go, the member's unconstrained optimum against a reference `ref` is
  `u - K * (x_meas - ref)` for any horizon length.
"""
function member_design(velocity, altitude=ALTITUDE, Ts=0.05;
        xcg=XCG, q=STATE_WEIGHTS, sx=STATE_SCALES, r=COMMAND_WEIGHTS, su=COMMAND_SCALES)
    isfinite(Ts) && Ts > 0 || throw(ArgumentError("Ts must be positive and finite"))
    qq = finite_vector(q, 10, "q")
    sxx = finite_vector(sx, 10, "sx")
    rr = finite_vector(r, 4, "r")
    suu = finite_vector(su, 4, "su")
    all(>(0), sxx) && all(>(0), suu) || throw(ArgumentError("sx and su must be positive"))
    all(>(0), qq) && all(>(0), rr) || throw(ArgumentError("q and r must be positive"))

    trim = _trim(velocity, altitude, xcg)
    x = trim.x[FLIGHT]
    u = trim.u ./ CONTROL_UNITS
    model = linear_model(dynamics(xcg), trim.x, trim.u; Ts)
    A = model.Ac[FLIGHT, FLIGHT]
    B = model.Bc[FLIGHT, :] * Diagonal(CONTROL_UNITS)
    discrete = CS.c2d(CS.ss(A, B, Matrix{Float64}(I, 10, 10), zeros(10, 4)), Ts)
    Q1 = diagm(qq ./ sxx .^ 2)
    Q2 = diagm(rr ./ suu .^ 2)
    return (; velocity=Float64(velocity), x, u, A, B, f_offset=-A * x - B * u,
        F=discrete.A, G=discrete.B, Ts=Float64(Ts), Q1, Q2, eu=-Q2 * u,
        Qf=CS.are(CS.Discrete, discrete.A, discrete.B, Q1, Q2),
        K=CS.lqr(CS.Discrete, discrete.A, discrete.B, Q1, Q2))
end

"""
    bank(velocities=KNOTS, altitude=ALTITUDE, initial_velocity=INITIAL_VELOCITY, Ts=0.05; kwargs...)

The `MPCComponents.MPCRef` bank of constrained `LinearMPC` controllers that
`VelocityMPCDemo` schedules on measured true airspeed: one member per knot of
`velocities`, each of them a `member_design` at that knot's straight-and-level trim.
`bank` adds what the members share — the command box, the slew limits, the horizon, the
observer covariances and the scheduling grid.

All members are built in **one absolute physical frame** — states in the plant's units,
commands in kilonewtons and degrees — rather than in per-knot deviation coordinates:
the scheduled components require every member to share an operating point, and an
absolute frame also makes the weighted sum of the members' commands an absolute command.
Each knot carries its own affine offset `f_j = -A_j x_j - B_j u_j`, so `ẋ = A_j x + B_j u + f_j`
vanishes at that knot's trim and the member is exact there. `C` is the identity, so the
references, the output weights and the measurements are all plain physical states.

The cost weights `q` and `r` are given per channel in units of `sx` (states) and `su`
(commands), the Bryson-rule scales. The stage cost penalizes the command *level* about
knot `j`'s own trimmed command `u_j`,
`(x - reference)' Q1 (x - reference) + (u - u_j)' Q2 (u - u_j)`, with
`Q1 = diagm(q ./ sx.^2)` and `Q2 = diagm(r ./ su.^2)`. The centering is carried by
LinearMPC's constant linear control cost `eu = -Q2 u_j`: in its `0.5 u' Q2 u + eu'u`
convention that is `0.5 (u - u_j)' Q2 (u - u_j)` up to a constant. The penalty therefore
costs nothing at the knot's own trim and leaves no steady-state error there.

Each member's terminal weight is the discrete algebraic Riccati solution
`are(Discrete, F_j, G_j, Q1, Q2)` of exactly that stage cost, so the terminal cost *is*
the cost-to-go of the horizon's own running cost: the unconstrained solution of every
member is its infinite-horizon discrete LQR, `u = u_j - K_j (x - x_j)`, for any `Np`.
The horizon then buys constraint handling alone, not closed-loop behavior.

When the reference is not the member's own trim, the level penalty is centered on the
knot's command `u_j` rather than on the equilibrium command of the reference, so the
member trades airspeed error against command travel away from its design point. The
scheduler's hat-function blend of the neighboring members interpolates that centering
across the grid.

`umin`/`umax` bound the command and `rate` its change per second; both are common to all
members, so the convex blend of their commands respects them too. `x0` is the trim state
at `initial_velocity` and `measurement_noise` the observer's measurement covariance,
small enough against the unit process covariance that the Kalman gain is the identity to
one part in a million and the estimate is the measurement.
"""
function bank(velocities=KNOTS, altitude=ALTITUDE, initial_velocity=INITIAL_VELOCITY, Ts=0.05;
        xcg=XCG, Np=40,
        q=STATE_WEIGHTS, sx=STATE_SCALES, r=COMMAND_WEIGHTS, su=COMMAND_SCALES,
        umin=COMMAND_MIN, umax=COMMAND_MAX,
        rate=COMMAND_RATE, measurement_noise=1e-6)
    grid = check_grid(velocities)
    isfinite(Ts) && Ts > 0 || throw(ArgumentError("Ts must be positive and finite"))
    Np isa Integer && Np >= 2 || throw(ArgumentError("Np must be an integer at least 2"))
    qq = finite_vector(q, 10, "q")
    sxx = finite_vector(sx, 10, "sx")
    rr = finite_vector(r, 4, "r")
    suu = finite_vector(su, 4, "su")
    lower = finite_vector(umin, 4, "umin")
    upper = finite_vector(umax, 4, "umax")
    slew = finite_vector(rate, 4, "rate")
    all(>(0), sxx) && all(>(0), suu) || throw(ArgumentError("sx and su must be positive"))
    all(>(0), qq) && all(>(0), rr) || throw(ArgumentError("q and r must be positive"))
    all(lower .< upper) || throw(ArgumentError("umin must be below umax on every channel"))
    all(>(0), slew) || throw(ArgumentError("rate must be positive on every channel"))
    isfinite(measurement_noise) && measurement_noise > 0 ||
        throw(ArgumentError("measurement_noise must be positive and finite"))
    first(grid) <= initial_velocity <= last(grid) ||
        throw(ArgumentError("initial_velocity $initial_velocity m/s is outside the design grid $grid"))

    Inu = Matrix{Float64}(I, 4, 4)
    Inx = Matrix{Float64}(I, 10, 10)
    x0 = _trim(initial_velocity, altitude, xcg).x[FLIGHT]

    designs = [member_design(velocity, altitude, Ts; xcg, q=qq, sx=sxx, r=rr, su=suu)
               for velocity in grid]
    for design in designs
        all(lower .<= design.u .<= upper) || throw(ArgumentError(
            "the trim command at $(design.velocity) m/s, $(design.u), is outside [umin, umax]"))
    end
    # Only the model, its affine offset, the recentered control cost and the terminal
    # weight vary from member to member; everything else below is shared.
    knots = Dict(design.velocity => (; design.A, design.B, design.f_offset, design.eu,
        design.Qf) for design in designs)
    Q1, Q2 = first(designs).Q1, first(designs).Q2

    return MPCComponents.Experimental.build_linear_mpc_bank(grid, rho -> knots[rho];
        C=Inx, continuous=true, Ts, Np, Nc=Np,
        Q1, Q2,
        umin=lower, umax=upper,
        # Slew limit as a general constraint block: -rate*Ts <= u - u_prev <= rate*Ts.
        Au=Inu, Aup=-Inu, lb=-slew .* Ts, ub=slew .* Ts, constraint_ks=1:Np,
        reference_tracking=true,
        C_meas=Inx, R1=Inx, R2=measurement_noise .* Inx, x0)
end

end
