"""
Design-time support for the altitude- and velocity-scheduled MPC of tutorial step 9.

The flight envelope is a rectangle in true airspeed and altitude. `envelope` trims and
linearizes the plant on a dense grid of it; `bank` builds one constrained `LinearMPC`
member at each node of a coarser tensor grid, which `dyad/Tutorial/09_envelope_mpc.dyad`
schedules on measured airspeed and altitude.

The bank's grid lives in `assets/envelope_trim_alpha.csv`: the trimmed angle of attack
(rad) at each node, airspeed knots as rows and altitude knots as columns. The Dyad model
reads its knots from the table's axes and its pitch and angle-of-attack references from
its values; `write_trim_table` regenerates it from the plant.

Members are built as in `VelocityMPC` (same plant, cost, limits and absolute frame); this
module adds the second scheduling axis. The bank is flattened airspeed-fastest: member
`k = (j - 1) * length(velocities) + i` sits at `(velocities[i], altitudes[j])`, the order
in which `VectorBlocks.OuterProduct` emits its weights.
"""
module EnvelopeMPC

using LinearAlgebra
import DyadData
using ..F16ModelWorkshop: asset_path
using ..VelocityMPC: VelocityMPC, FLIGHT, PITCH, ANGLE_OF_ATTACK, VELOCITY, XCG, check_grid

export envelope, flight_conditions

"Airspeed the closed loop starts trimmed at, m/s."
const INITIAL_VELOCITY = 150.0
"Altitude the closed loop starts trimmed at, m."
const INITIAL_ALTITUDE = 3000.0
"Index of altitude within `VelocityMPC.STATE_NAMES`."
const ALTITUDE = 3

"""
    flight_conditions(velocities, altitudes) -> Vector{NTuple{2,Float64}}

The nodes `(velocity, altitude)` of the tensor grid, airspeed running fastest.
"""
function flight_conditions(velocities, altitudes)
    vs, hs = check_grid(velocities), check_grid(altitudes)
    return [(v, h) for h in hs for v in vs]
end

"""
    bank(velocities, altitudes, initial_velocity=INITIAL_VELOCITY,
         initial_altitude=INITIAL_ALTITUDE, Ts=0.05; kwargs...) -> MPCComponents.MPCRef

One `VelocityMPC.member_design` at every node of the `velocities × altitudes` grid,
flattened airspeed-fastest. Members are keyed by index `1:N`; the scheduled components
never read the keys, since the weights come from the outer product of two scalar
schedulers. Keyword arguments are those of `VelocityMPC.build_bank`.
"""
function bank(velocities, altitudes, initial_velocity=INITIAL_VELOCITY,
        initial_altitude=INITIAL_ALTITUDE, Ts=0.05; kwargs...)
    conditions = flight_conditions(velocities, altitudes)
    first(velocities) <= initial_velocity <= last(velocities) &&
        first(altitudes) <= initial_altitude <= last(altitudes) ||
        throw(ArgumentError("initial condition ($initial_velocity m/s, $initial_altitude m) is outside the design grid"))
    return VelocityMPC.build_bank(collect(1.0:length(conditions)), conditions,
        (initial_velocity, initial_altitude), Ts; kwargs...)
end

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
    reference_map(table) -> Matrix{Float64}

The `10 × (2 + N)` matrix mapping `[commanded airspeed; commanded altitude; member
weights]` onto the ten regulated states' references, from the trim table `table`
(`trim_table()`). The commands go onto their own channels and member `k`'s tabulated angle
of attack onto both the pitch and angle-of-attack channels: in straight and level flight
the flight-path angle `theta - alpha` is zero, so trimmed pitch equals trimmed angle of
attack. Those references are bilinear in airspeed and altitude and exact at the nodes;
every other channel is regulated to zero.
"""
function reference_map(table::DyadData.DyadInterpolationTable2D)
    channel(state) = state - first(FLIGHT) + 1
    trims = vec(table["alpha"])                              # column-major: airspeed fastest
    K = zeros(length(FLIGHT), 2 + length(trims))
    K[channel(VELOCITY), 1] = 1.0
    K[channel(ALTITUDE), 2] = 1.0
    K[channel(PITCH), 3:end] = trims
    K[channel(ANGLE_OF_ATTACK), 3:end] = trims
    return K
end

"""
    envelope(velocities=range(140, 250; length=100), altitudes=range(0, 9000; length=100);
             xcg=XCG) -> NamedTuple

Trim and linearize the plant at every node of a dense `velocities × altitudes` grid
(10 000 conditions by default; seconds of work, since the symbolic Jacobian is compiled
once). Returns the grid; the trimmed `alpha`, `theta` (rad), `thrust` (kN) and `elevator`
(deg) as `length(velocities) × length(altitudes)` matrices; the continuous linearizations
`A`, `B` of the ten regulated states; and `unstable`, the largest real part of each
linearization's eigenvalues (1/s), i.e. the pitch-mode divergence rate. It is zero above
α ≈ 5.7°, where the deck's `Cma2 α²` term makes the airframe statically stable.
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
        trim = VelocityMPC.trim_point(d, v; altitude=h)
        model = VelocityMPC.linear_model(d, trim.x, trim.u)
        A[i, j] = model.Ac[FLIGHT, FLIGHT]
        B[i, j] = model.Bc[FLIGHT, :]
        alpha[i, j], theta[i, j] = trim.x[ANGLE_OF_ATTACK], trim.x[PITCH]
        thrust[i, j], elevator[i, j] = trim.u[1] / 1000, trim.u[2]
        unstable[i, j] = maximum(real, eigvals(A[i, j]))
    end
    return (; velocities=vs, altitudes=hs, alpha, theta, thrust, elevator, A, B, unstable)
end

end
