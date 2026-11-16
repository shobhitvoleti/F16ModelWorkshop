"""
Design-time and run-time support for the altitude- and velocity-scheduled MPC of tutorial
step 9.

The flight envelope is a rectangle in true airspeed and altitude. `envelope` trims and
linearizes the plant on a dense grid of it. `grid_bank` holds one constrained `LinearMPC`
controller per node of a `velocities × altitudes` grid, which
`dyad/Tutorial/09_envelope_mpc.dyad` schedules on measured airspeed and altitude.

The grid lives in `assets/envelope_trim_alpha.csv`: the trimmed angle of attack (rad) at
each node, airspeed knots as rows and altitude knots as columns. The Dyad model reads its
knots from the table's axes and interpolates its pitch and angle-of-attack references in
its values; `write_trim_table` regenerates it from the plant.

A node's controller is `VelocityMPC.member_controller` at that node (the plant, cost,
limits and absolute frame of step 8), built the first time the closed loop needs it. Each
tick solves only the nodes of the grid cell the aircraft is in, at most four, so neither
the model nor the run time grows with the number of nodes.
"""
module EnvelopeMPC

using LinearAlgebra
import DyadData
import MPCComponents
import Symbolics
using ..F16ModelWorkshop: asset_path
using ..VelocityMPC: VelocityMPC, FLIGHT, PITCH, ANGLE_OF_ATTACK, XCG, check_grid

export envelope, grid_bank

"""
    trim_table() -> DyadData.DyadInterpolationTable2D

The committed trim table: the trimmed angle of attack (rad) at each node, with axes `"vt"`
(m/s) and `"alt"` (m) — the table `EnvelopeMPCDemo` loads from `dyad://F16ModelWorkshop/`.
"""
trim_table() = DyadData.DyadInterpolationTable2D(
    "dyad://F16ModelWorkshop/envelope_trim_alpha.csv"; axis1_name="vt", axis2_name="alt", data_name="alpha")

"""
    write_trim_table(dir=asset_path(); velocities, altitudes, xcg=XCG) -> String

Trim the plant at every node of `velocities × altitudes` and write the angle-of-attack
table to `dir/envelope_trim_alpha.csv` in the `DyadData.DyadInterpolationTable2D` layout:
a header row of altitudes, then one row per airspeed with its trims. The knots default to
the committed table's axes, so editing those axes and re-running this moves the grid.
Values are written at full precision and read back exactly.
"""
function write_trim_table(dir=asset_path(); velocities=trim_table()["vt"], altitudes=trim_table()["alt"], xcg=XCG)
    vs, hs = check_grid(velocities), check_grid(altitudes)
    path = joinpath(dir, "envelope_trim_alpha.csv")
    open(path, "w") do io
        println(io, ",", join(hs, ","))
        for v in vs
            println(io, v, ",", join((repr(VelocityMPC.trim_states(v, h; xcg)[ANGLE_OF_ATTACK]) for h in hs), ","))
        end
    end
    return path
end

"""
    envelope(velocities=range(140, 250; length=100), altitudes=range(0, 9000; length=100);
             xcg=XCG) -> NamedTuple

Trim and linearize the plant at every node of a dense `velocities × altitudes` grid
(10 000 conditions by default; seconds of work, since the trim problem and the symbolic
Jacobian are compiled once). Returns the grid; the trimmed `alpha`, `theta` (rad), `thrust`
(kN) and `elevator` (deg) as `length(velocities) × length(altitudes)` matrices; the
continuous linearizations `A`, `B` of the ten regulated states; and `unstable`, the largest
real part of each linearization's eigenvalues (1/s), i.e. the pitch-mode divergence rate.
It is zero above α ≈ 5.7°, where the deck's `Cma2 α²` term makes the airframe statically
stable.
"""
function envelope(velocities=range(140.0, 250.0; length=100), altitudes=range(0.0, 9000.0; length=100);
        xcg=XCG)
    vs, hs = check_grid(velocities), check_grid(altitudes)
    d = VelocityMPC.dynamics(xcg)
    sz = (length(vs), length(hs))
    alpha, theta, thrust, elevator, unstable = (zeros(sz) for _ in 1:5)
    A = Array{Matrix{Float64}}(undef, sz)
    B = Array{Matrix{Float64}}(undef, sz)
    for (j, h) in pairs(hs), (i, v) in pairs(vs)
        trim = VelocityMPC.trim_point(v; altitude=h, xcg)
        model = VelocityMPC.linear_model(d, trim.x, trim.u)
        A[i, j] = model.Ac[FLIGHT, FLIGHT]
        B[i, j] = model.Bc[FLIGHT, :]
        alpha[i, j], theta[i, j] = trim.x[ANGLE_OF_ATTACK], trim.x[PITCH]
        thrust[i, j], elevator[i, j] = trim.u[1] / 1000, trim.u[2]
        unstable[i, j] = maximum(real, eigvals(A[i, j]))
    end
    return (; velocities=vs, altitudes=hs, alpha, theta, thrust, elevator, A, B, unstable)
end

# ## The grid bank

"""
    GridBank

The value the `MPCRef` of `grid_bank` holds: the knots, the sample period and design
keywords of the nodes, and the controllers built so far, keyed by node `(i, j)` at
`(velocities[i], altitudes[j])`. `ubuf` holds the blended command of the last solve and
`solves` counts node solves.
"""
mutable struct GridBank
    velocities::Vector{Float64}
    altitudes::Vector{Float64}
    Ts::Float64
    design::NamedTuple
    nodes::Dict{Tuple{Int,Int},Base.RefValue{Any}}
    ubuf::Vector{Float64}
    solves::Int
end

"""
    grid_bank(velocities, altitudes, Ts=0.05; kwargs...) -> MPCComponents.MPCRef

A controller bank over the `velocities × altitudes` grid for `GridMPCOptimizer`: node
`(i, j)` is `VelocityMPC.member_controller(velocities[i], altitudes[j], Ts; kwargs...)`,
built the first time `grid_bank_solve` gives it a positive weight and kept for the rest of
the run. Building nothing up front, a grid costs the same however many nodes it has; a
node costs about 30 ms and 1 MiB when it is first flown through.
"""
function grid_bank(velocities, altitudes, Ts=0.05; kwargs...)
    vs, hs = check_grid(velocities), check_grid(altitudes)
    isfinite(Ts) && Ts > 0 || throw(ArgumentError("Ts must be positive and finite"))
    nu = length(VelocityMPC.CONTROL_UNITS)
    return Ref{Any}(GridBank(vs, hs, Float64(Ts), NamedTuple(kwargs), Dict{Tuple{Int,Int},Base.RefValue{Any}}(), zeros(nu), 0))
end

# The clocked partition is compiled by SynchToolkit, which needs every call in it to infer a
# concrete type: the bank comes out of its `Ref{Any}` with a type assertion, and the node
# table holds `MPCRef`s.
function _grid_bank(ref)::GridBank
    ref isa Base.RefValue && ref[] isa GridBank ||
        throw(ArgumentError("expected the MPCRef of a grid_bank, got $(typeof(ref))"))
    return ref[]::GridBank
end

"The controller of node `(i, j)`, built on first use."
node!(bank::GridBank, i, j)::Base.RefValue{Any} = get!(bank.nodes, (i, j)) do
    VelocityMPC.member_controller(bank.velocities[i], bank.altitudes[j], bank.Ts; bank.design...)
end

# No measured disturbance, estimated disturbance or generalized parameter: the placeholders
# `LinearMPCOptimizer` passes in their place.
const _NONE = [0.0]

# The composite exit flag of `LinearMPCScheduledOptimizer`: the first negative node flag,
# else 2 when a node reported active soft constraints, else 1; -99 when no node solved.
function _fold_flag(flag, fk, nactive)
    nactive == 0 && return fk
    fk < 0 && flag >= 0 && return fk
    fk == 2 && flag == 1 && return fk
    return flag
end

"""
    grid_bank_solve(wv, wh, xhat, r, u_prev, bank_ref) -> exitflag
    grid_bank_u(exitflag, i, bank_ref)
    grid_bank_built(exitflag, bank_ref)

One tick of `GridMPCOptimizer`. `wv` and `wh` are the knot weights of the airspeed and
altitude axes (`LinearMPCScheduler`); node `(i, j)` has the bilinear weight
`wv[i] * wh[j]`, positive for at most the four corners of the current cell. Each of those
nodes solves its QP (`MPCComponents.lmpc_solve`) for the same state `xhat`, reference `r`
and previous command `u_prev`, and the commands are blended with the weights, as
`LinearMPCScheduledOptimizer` does over a whole bank. The composite flag is returned.
`grid_bank_u` reads element `i` of the blended command and `grid_bank_built` the number of
nodes built so far; their `exitflag` argument orders them after the solve.
"""
function grid_bank_solve(wv, wh, xhat, r, u_prev, ref)
    t = MPCComponents.symbolic_call(grid_bank_solve, (wv, wh, xhat, r, u_prev, ref), MPCComponents.ScalarResult())
    t === nothing || return t
    bank = _grid_bank(ref)
    length(wv) == length(bank.velocities) && length(wh) == length(bank.altitudes) ||
        error("GridMPCOptimizer: $(length(wv)) × $(length(wh)) weights for a $(length(bank.velocities)) × $(length(bank.altitudes)) grid")
    fill!(bank.ubuf, 0.0)
    flag, nactive = -99.0, 0
    for j in eachindex(wh)
        wh[j] > 0 || continue
        for i in eachindex(wv)
            w = wv[i] * wh[j]
            w > 0 || continue
            node = node!(bank, i, j)
            fk = MPCComponents.lmpc_solve(xhat, r, _NONE, _NONE, _NONE, u_prev, node)::Float64
            for k in eachindex(bank.ubuf)
                bank.ubuf[k] += w * MPCComponents.lmpc_u(fk, k, node)::Float64
            end
            flag = _fold_flag(flag, fk, nactive)
            nactive += 1
            bank.solves += 1
        end
    end
    return Float64(flag)
end
@doc (@doc grid_bank_solve) function grid_bank_u(status, i, ref)
    t = MPCComponents.symbolic_call(grid_bank_u, (status, i, ref), MPCComponents.ScalarResult())
    t === nothing || return t
    return _grid_bank(ref).ubuf[Int(i)]
end
@doc (@doc grid_bank_solve) function grid_bank_built(status, ref)
    t = MPCComponents.symbolic_call(grid_bank_built, (status, ref), MPCComponents.ScalarResult())
    t === nothing || return t
    return Float64(length(_grid_bank(ref).nodes))
end
Symbolics.SymbolicUtils.promote_symtype(::typeof(grid_bank_solve), ::Type, ::Type, ::Type, ::Type, ::Type, ::Type) = Real
Symbolics.SymbolicUtils.promote_symtype(::typeof(grid_bank_u), ::Type, ::Type, ::Type) = Real
Symbolics.SymbolicUtils.promote_symtype(::typeof(grid_bank_built), ::Type, ::Type) = Real

end
