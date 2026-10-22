"""
Design-time support for the gain-scheduled PID autopilot of tutorial step 7: the
longitudinal model at each design point, the per-point loop design, and the gain table
that `dyad/Tutorial/07_gain_scheduled_pid.dyad` interpolates on dynamic pressure.

The design follows the gain-scheduling procedure of Stevens & Lewis, *Aircraft Control and
Simulation*: linearize the aircraft at several straight-and-level flight conditions, repeat
one fixed-structure design at each, tabulate the gains, and interpolate them on the
dynamic pressure `q̄ = ½ρV²`, which sets the effectiveness of every aerodynamic control.
The loops are the book's classical longitudinal autopilot, closed inner loop first:

1. pitch-attitude hold, elevator from pitch attitude, PD (the derivative is the pitch-rate
   damping);
2. altitude hold around it, pitch-attitude command from altitude, PID;
3. autothrottle around both, thrust from airspeed, PI.

Every loop is designed for the same gain-crossover frequency and phase margin at every
design point, so the scheduled gains keep the loop shapes fixed while `q̄` changes. Trim,
plant and linearization come from `VelocityMPC`, so steps 7 and 8 fly one aircraft.
"""
module ScheduledPID

using LinearAlgebra
import ControlSystemsBase as CS
using ..VelocityMPC: VelocityMPC, dynamics, linear_model, trim_command, trim_states

export closed_loop, discrete_controller, dynamic_pressure, gain_table, knot_pressures, loop_design,
    loop_transfers, longitudinal_model

"Longitudinal states within `VelocityMPC.STATE_NAMES`: altitude, pitch, airspeed, angle of attack, pitch rate."
const LONGITUDINAL = [3, 5, 7, 8, 11]

"Crossover frequency (rad/s) and phase margin (deg) of the pitch-attitude loop."
const PITCH_LOOP = (crossover = 2.0, margin = 60.0)
"Crossover frequency (rad/s) and phase margin (deg) of the altitude loop."
const ALTITUDE_LOOP = (crossover = 0.3, margin = 60.0)
"Crossover frequency (rad/s) and phase margin (deg) of the airspeed loop."
const SPEED_LOOP = (crossover = 0.5, margin = 70.0)
"Ratio `Ti / Td` of the altitude PID, the third condition its three gains need."
const ALTITUDE_TI_OVER_TD = 4.0

"""
Rows of `gain_table`, the order of `AutopilotGainSchedule`'s outputs: the pitch PD, the
altitude PID and the airspeed PI in standard form, then the trimmed pitch attitude (rad),
elevator (deg) and thrust (kN) the three loops add as feed-forward.
"""
const SCHEDULE_ROWS = (:K_pitch, :Td_pitch, :K_alt, :Ti_alt, :Td_alt, :K_speed, :Ti_speed,
    :theta_trim, :el_trim, :T_trim)

"""
    dynamic_pressure(altitude, velocity) -> Float64

`q̄ = ½ρV²` in pascals, with the density of `F16PlantModel`'s troposphere model,
`ρ = 1.225 (1 - 0.0065 h / 288.15)^4.256`. `AutopilotGainSchedule` evaluates the same
expression on the sampled altitude and airspeed.
"""
dynamic_pressure(altitude, velocity) =
    0.5 * 1.225 * (1 - 0.0065 * altitude / 288.15)^4.256 * velocity^2

"""
    knot_pressures(velocities=VelocityMPC.KNOTS, altitude=VelocityMPC.ALTITUDE) -> Vector{Float64}

The dynamic pressure at each design point, the knots the schedule interpolates between.
"""
knot_pressures(velocities = VelocityMPC.KNOTS, altitude = VelocityMPC.ALTITUDE) =
    [dynamic_pressure(altitude, v) for v in VelocityMPC.check_grid(velocities)]

"""
    longitudinal_model(velocity, altitude=VelocityMPC.ALTITUDE) -> ControlSystemsBase.StateSpace

The plant linearized at the straight-and-level trim of `velocity` (m/s) and `altitude`
(m), restricted to the longitudinal states `LONGITUDINAL`. Inputs are thrust (kN) and
elevator (deg), outputs altitude (m), pitch attitude (rad) and airspeed (m/s): the
controllers' units, deviations from trim.
"""
function longitudinal_model(velocity, altitude = VelocityMPC.ALTITUDE)
    x = trim_states(velocity, altitude)
    u = trim_command(velocity, altitude) .* VelocityMPC.CONTROL_UNITS
    model = linear_model(dynamics(), x, u)
    A = model.Ac[LONGITUDINAL, LONGITUDINAL]
    B = model.Bc[LONGITUDINAL, 1:2] * Diagonal(VelocityMPC.CONTROL_UNITS[1:2])
    C = Matrix{Float64}(I, 3, 5)
    return CS.ss(A, B, C, 0)
end

"""
    crossover_gains(P, crossover, margin; integral, derivative, ratio=ALTITUDE_TI_OVER_TD)

Standard-form gains `(K, Ti, Td)` of the PD, PI or PID controller `C` that puts the
gain crossover of `P C` at `crossover` (rad/s) with phase margin `margin` (deg):
`P(jω) C(jω) = -exp(j margin)` at `ω = crossover`. A PD or PI has two gains for the two
conditions; a PID fixes `Ti = ratio * Td` as the third. The derivative filter is left
out of the design and checked afterwards. `Ti = Inf` and `Td = 0` mark absent terms.
"""
function crossover_gains(P, crossover, margin; integral::Bool, derivative::Bool,
        ratio = ALTITUDE_TI_OVER_TD)
    ω = crossover
    r = CS.freqresp(P, ω)[1]
    # The phase the controller must add, and its magnitude: C(jω) = |C| exp(jφ).
    φ = rem2pi(deg2rad(margin - 180) - angle(r), RoundNearest)
    t = tan(φ)
    if integral && derivative
        Td = (t + sqrt(t^2 + 4 / ratio)) / (2ω)
        Ti = ratio * Td
    elseif derivative
        t > 0 || error("a PD cannot meet the specification: the plant needs $(rad2deg(φ))° of phase")
        Td, Ti = t / ω, Inf
    elseif integral
        t < 0 || error("a PI cannot meet the specification: the plant needs $(rad2deg(φ))° of phase")
        Td, Ti = 0.0, -1 / (ω * t)
    else
        error("a design needs an integral or a derivative term")
    end
    abs(φ) < π / 2 || error("the specification needs $(rad2deg(φ))° of phase, beyond a PID")
    K = 1 / (abs(r) * abs(1 + im * (ω * Td - (isfinite(Ti) ? 1 / (ω * Ti) : 0.0))))
    return (; K, Ti, Td)
end

"""
    controller(gains; Nd=10) -> ControlSystemsBase.TransferFunction

The continuous standard-form controller `K (1 + 1/(Ti s) + Td s / (1 + Td s / Nd))`, with
the filtered derivative `DiscretePIDScheduled` uses.
"""
function controller(g; Nd = 10)
    s = CS.tf("s")
    C = 1 + 0 * s
    isfinite(g.Ti) && (C += 1 / (g.Ti * s))
    g.Td > 0 && (C += g.Td * s / (1 + g.Td / Nd * s))
    return g.K * C
end

"""
    loop_design(velocity, altitude=VelocityMPC.ALTITUDE) -> NamedTuple

The autopilot at one design point, inner loop first:

- `pitch` — elevator from pitch attitude, a PD. The elevator's positive deflection pitches
  the nose down, so the design runs on the sign-flipped plant and `K` comes out negative.
- `altitude` — pitch-attitude command from altitude, a PID designed on the plant with the
  pitch loop closed.
- `speed` — thrust from airspeed, a PI designed on the plant with both loops closed.
- `model` — the `longitudinal_model` it was designed on, and the trims `theta_trim` (rad),
  `el_trim` (deg) and `T_trim` (kN).
- `loops` — the loop transfer functions `pitch`, `altitude` and `speed`, each broken at its
  controller's output with the inner loops closed. They include the derivative filter,
  which the design leaves out, so their margins sit a few degrees off the `*_LOOP` values.
"""
function loop_design(velocity, altitude = VelocityMPC.ALTITUDE)
    P = longitudinal_model(velocity, altitude)
    pitch = crossover_gains(-P[2, 2], PITCH_LOOP...; integral = false, derivative = true)
    pitch = (; pitch..., K = -pitch.K)
    Cθ = controller(pitch)
    # Pitch loop closed: el = Cθ (θc - θ). Input θc, outputs [h, θ, V].
    from_pitch_command = CS.feedback(P[:, 2] * Cθ, CS.ss([0.0 1.0 0.0]))
    alt = crossover_gains(from_pitch_command[1, 1], ALTITUDE_LOOP...; integral = true, derivative = true)
    Ch = controller(alt)
    # Both elevator loops closed: el = -Cθ (Ch h + θ). Input T, outputs [h, θ, V].
    from_thrust = CS.feedback(P, elevator_law(Cθ, Ch))[:, 1]
    speed = crossover_gains(from_thrust[3, 1], SPEED_LOOP...; integral = true, derivative = false)
    x = trim_states(velocity, altitude)
    u = trim_command(velocity, altitude)
    design = (; velocity = Float64(velocity), altitude = Float64(altitude), pitch, altitude_hold = alt,
        speed, model = P, theta_trim = x[VelocityMPC.PITCH], el_trim = u[2], T_trim = u[1])
    return (; design..., loops = loop_transfers(P, gain_column(design)))
end

# A design's gains and trims in the order of `SCHEDULE_ROWS`.
gain_column(d) = [d.pitch.K, d.pitch.Td, d.altitude_hold.K, d.altitude_hold.Ti, d.altitude_hold.Td,
    d.speed.K, d.speed.Ti, d.theta_trim, d.el_trim, d.T_trim]

"""
    loop_transfers(model, column) -> NamedTuple

The continuous loop transfer functions `pitch`, `altitude` and `speed` of the autopilot
with the gains of `column` (in the order of `SCHEDULE_ROWS`) on `model` (a
`longitudinal_model`). Each is broken at its controller's output with the inner loops
closed, and includes the derivative filter. The column need not come from the same flight
condition: with another design point's gains, the loops show what the schedule corrects.
"""
function loop_transfers(model, column)
    length(column) == length(SCHEDULE_ROWS) ||
        throw(DimensionMismatch("a gain column has $(length(SCHEDULE_ROWS)) entries"))
    c = Dict(zip(SCHEDULE_ROWS, column))
    Cθ = controller((K = c[:K_pitch], Ti = Inf, Td = c[:Td_pitch]))
    Ch = controller((K = c[:K_alt], Ti = c[:Ti_alt], Td = c[:Td_alt]))
    Cv = controller((K = c[:K_speed], Ti = c[:Ti_speed], Td = 0.0))
    from_pitch_command = CS.feedback(model[:, 2] * Cθ, CS.ss([0.0 1.0 0.0]))
    from_thrust = CS.feedback(model, elevator_law(Cθ, Ch))[:, 1]
    return (pitch = model[2, 2] * Cθ, altitude = from_pitch_command[1, 1] * Ch,
        speed = from_thrust[3, 1] * Cv)
end

# The elevator's feedback law on the outputs [h, θ, V], el = -Cθ (Ch h + θ), as a 2 x 3
# system with a zero thrust row, for `feedback` against the plant's [T, el] inputs.
elevator_law(Cθ, Ch) = CS.ss([0 * Cθ 0 * Cθ 0 * Cθ; Cθ * Ch Cθ 0 * Cθ])

"""
    discrete_controller(gains, Ts; Nd=10) -> ControlSystemsBase.TransferFunction

The `DiscretePIDScheduled` of `GainScheduledPIDDemo` at constant gains, from the
measurement to the control signal with the sign of negative feedback: forward-Euler
integral `K Ts / (Ti (z - 1))` and backward-Euler filtered derivative, the controller's
default `Imethod` and `Dmethod`.
"""
function discrete_controller(g, Ts; Nd = 10)
    z = CS.tf("z", Ts)
    C = g.K + 0 * z
    isfinite(g.Ti) && (C += g.K * Ts / (g.Ti * (z - 1)))
    if g.Td > 0
        a = g.Td / (g.Td + Nd * Ts)
        C += g.K * Nd * a * (z - 1) / (z - a)
    end
    return C
end

"""
    closed_loop(model, column, Ts=0.05) -> ControlSystemsBase.StateSpace

The sampled-data autopilot at one flight condition: `model` (a `longitudinal_model`)
under a zero-order hold of period `Ts`, closed by the three `discrete_controller`s whose
gains are a column of `gain_table` in the order of `SCHEDULE_ROWS`. The column need not
come from the same flight condition, which is how a schedule is checked between and
around its design points. The loop is stable when every pole lies inside the unit circle.
"""
function closed_loop(model, column, Ts = 0.05)
    length(column) == length(SCHEDULE_ROWS) ||
        throw(DimensionMismatch("a gain column has $(length(SCHEDULE_ROWS)) entries"))
    c = Dict(zip(SCHEDULE_ROWS, column))
    Cθ = discrete_controller((K = c[:K_pitch], Ti = Inf, Td = c[:Td_pitch]), Ts)
    Ch = discrete_controller((K = c[:K_alt], Ti = c[:Ti_alt], Td = c[:Td_alt]), Ts)
    Cv = discrete_controller((K = c[:K_speed], Ti = c[:Ti_speed], Td = 0.0), Ts)
    law = elevator_law(Cθ, Ch) + CS.ss([0 * Cv 0 * Cv Cv; 0 * Cv 0 * Cv 0 * Cv])
    return CS.feedback(CS.c2d(model, Ts), law)
end

"""
    gain_table(velocities=VelocityMPC.KNOTS, altitude=VelocityMPC.ALTITUDE) -> Matrix{Float64}

The `length(SCHEDULE_ROWS) x length(velocities)` table of `AutopilotGainSchedule`: column
`j` is `loop_design(velocities[j], altitude)` in the order of `SCHEDULE_ROWS`. The schedule
interpolates its columns linearly in dynamic pressure between `knot_pressures`.
"""
function gain_table(velocities = VelocityMPC.KNOTS, altitude = VelocityMPC.ALTITUDE)
    grid = VelocityMPC.check_grid(velocities)
    return reduce(hcat, [gain_column(loop_design(v, altitude)) for v in grid])
end

end
