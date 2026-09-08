# Tutorial 7 — Velocity-scheduled linear MPC

After steps 1–6 introduce trim, linearization, LQG, simulation, and C export,
this step designs a constrained controller bank scheduled by measured airspeed.
Run the Julia script [07_velocity_mpc.jl](07_velocity_mpc.jl) from the repository
root with its project environment activated. It computes its own operating points.

`F16ModelWorkshop.VelocityMPC` builds a bank of constrained linear MPC controllers
for the existing Dyad `Plant.F16PlantModel`. Measured true airspeed `vt` (m/s) is
the scheduling variable. The speed reference is a separate set-point input.

```julia
using F16ModelWorkshop.VelocityMPC
bank = build_velocity_mpc([140.0, 152.4, 170.0]; altitude=3000.0, Ts=0.05, Np=40)
initial = trim_point(bank.dynamics, 148.0)
reference(t) = trim_state(bank, 148 + 12*clamp((t-2)/12, 0, 1))
result = VelocityMPC.simulate(bank; x0=initial.x, reference, applied0=initial.u, duration=25.0)
```

Run `julia --project=. dyad/Tutorial/07_velocity_mpc.jl /path/to/output` for a
speed ramp from 148 to 160 m/s with an initial 2° pitch perturbation. It writes
`trajectory.csv`, `summary.toml`, and `response.png` into the chosen directory. Existing trim and
LQG assets are not inputs to the MPC design and are not overwritten.

## Model and operating points

The nonlinear equations come directly from the generated Dyad plant. ModelingToolkit
symbolically linearizes it once; ControlSystemsMTK/Symbolics compile the symbolic
state-space matrices into a function evaluated at each operating point. The nonlinear
plant function is also generated once and reused for trim and simulation.

At each velocity knot, the trim solve determines thrust, elevator, angle of attack,
and pitch at the selected altitude and CG. All ten flight-state derivatives must be
zero within tolerance. Horizontal position advances in straight flight, so north/east
position are excluded from both the equilibrium residual and the MPC objective.
The ten-state linearization is discretized by a zero-order hold.

| Interface | Order and units |
|---|---|
| Measured state/reference | `[npos, epos, alt, phi, theta, psi, vt, alpha, beta, P, Q, R]`; positions m, speed m/s, angles rad, angular rates rad/s |
| Controlled state | `[alt, phi, theta, psi, vt, alpha, beta, P, Q, R]` |
| Applied command | `[T, el, ail, rud]`; thrust N, surfaces deg |
| Leading-edge flap | Fixed at zero; it has no aerodynamic effect in this plant |

Each member uses `z = (x - xtrim) ./ state_scale` and
`v = (u - utrim) ./ input_scale`. The QP penalizes state-reference error, control
relative to trim, and control increments. Defaults use positive diagonal state/input
weights and a discrete LQR terminal cost; all weights and scales are configurable.
The horizon is `Np*Ts` seconds. No online nonlinear optimization or model refactorization
is performed.

## Scheduling and constraints

`:linear` uses hat-function weights: one solve exactly at a knot, two solves between
knots. `:nearest` uses one member; ties choose the upper knot. Each active member sees
the same physical measured state, reference, and previous applied command, translated
into its own trim/scaled coordinates. Its optimized command is converted back to
physical units **before** blending. Blending deviation commands and adding only one
member's trim would introduce a scheduling bias.

Every QP enforces the same physical input bounds and per-second slew limits, shifted
and scaled for its own operating point. Because all members use the same previous
applied command, convex blending preserves these common limits. Default thrust bounds
are 0–50 kN; surface bounds are ±25° elevator, ±21.5° aileron, and ±30° rudder.
Slew defaults are 20 kN/s, 60°/s, 80°/s, and 120°/s. These are configurable workshop
controller limits, not a validated actuator/engine model.

`control!(bank, measurement; reference, applied)` returns `(; u, weights, active)`.
Pass the actual applied four-channel command when actuators or other logic modify
the requested command. Otherwise `applied` defaults to the last successful command.
For the first call initialize it to the actual starting command. A bank is mutable;
use a separate instance for each independent simulation/controller.

Malformed grids, nonfinite signals, failed trims/QPs, and unexpected command violations
throw errors. Speeds outside the design grid throw by default. `outside=:clamp` is an
explicit opt-in to use an endpoint controller; it is not evidence of validity outside
the design envelope. Reference interpolation always rejects out-of-grid speed requests.

## Scope and validation

This is a Julia state-feedback MPC implementation, with all plant flight states
measured. It does not include an estimator, C export, or a clocked Dyad MPC component.
It uses LinearMPC directly so the workshop's SynchCompiler/SynchToolkit stack can stay
on its existing versions. The bank architecture follows
[MPCComponents PR #32](https://github.com/JuliaComputing/MPCComponents.jl/pull/32)
(reviewed at commit `eabb59035fe824c6900f22e06ad8cb194980a301`), and matrix generation follows
[ControlSystemsMTK's symbolic linearization interface](https://juliacontrol.github.io/ControlSystemsMTK.jl/dev/#Symbolic-linearization-and-code-generation).

The model bank is designed at fixed altitude/CG; changing either requires rebuilding
it. `trim_state` interpolates references between knots and can change the altitude
set point, but does not retrim or redesign the bank. The plant's condensed aerodynamic
deck is a local approximation, so widening the schedule requires additional validation.
A convex combination of constrained MPC commands does not prove closed-loop stability
or recursive feasibility. There are no state/output envelope constraints or terminal
invariant sets in this implementation.

`test/velocity_mpc.jl` checks scheduling edge cases, trim residuals, symbolic versus
finite-difference Jacobians, exact-knot behavior, manually blended member commands,
physical travel/slew limits, and a nonlinear speed transition across a knot. In a
persistent development session run:

```julia
using Revise, F16ModelWorkshop
include("test/velocity_mpc.jl")
```

The main test entrypoint also includes these checks. Use `Pkg.test()` only for the
final pre-PR run, following the repository's development instructions.
