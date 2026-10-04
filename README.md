# F16ModelWorkshop

Workshop material for modeling and control design in
[Dyad](https://juliahub.com/products/dyad): a 6-DOF F-16 plant taken from trim through
linearization to an LQG regulator, its sampled-data implementation, a 3-D animation, and
standalone C for the controller, followed by gain-scheduled linear MPC: first on airspeed,
then across an airspeed–altitude envelope.

## Layout

Dyad sources live in `dyad/`; the compiler regenerates `generated/` from them. Never edit
`generated/` by hand: Dyad Studio regenerates it on save.

| Path | Contents |
|---|---|
| `dyad/Tutorial/` | **Start here**: the eight-step walkthrough below |
| `dyad/Plant/` | `F16PlantModel`, the 6-DOF plant with vector I/O |
| `dyad/Trimming/` | The trimmed plant flown open loop, and its pitch departure |
| `dyad/VectorBlocks/`, `dyad/Utils/` | Vector-signal blocks, mux/demux and the signal-to-pose bridge the tutorial is wired with |
| `dyad/*.dyad` | The three custom analyses (trim export, visualization, C export), each backed by a spec in `src/` |
| `assets/` | Parameter sets the models `apply` (the trim point from step 1, the two controllers from step 3), the step-8 trim lookup table, icons and the airframe mesh |
| `src/` | The custom analyses' specs, and the MPC design code of steps 7 and 8 (`VelocityMPC`, `EnvelopeMPC`) |
| `scripts/Tutorial/` | Regenerate the committed assets, animations and MPC plots from the command line |
| `generated_c/` | The C emitted by step 6 |
| `gui/` | Optional live tuning dashboard for the step-3 design (GLMakie) |
| `test/` | Pins the plant to Stevens & Lewis and checks that the closed loops hold trim and track |

## The walkthrough

All eight steps are Dyad analyses in `dyad/Tutorial/`: run them from Dyad Studio, or call
them by name in the REPL after `using F16ModelWorkshop, F16ModelWorkshop.Tutorial`. Steps 1
and 3 produce the parameter-set assets that steps 2–6 apply; re-run them to change the
flight condition or the plant. Steps 7 and 8 trim and linearize their own flight
conditions instead.

1. **Trim — `01_trim.dyad`.** `TrimDemo` declares thrust, elevator and the pitch
   attitude `missing` and pins the motion derivatives to zero, so the initialization
   solver returns the steady flight condition. `TutorialTrim` solves it;
   `TutorialTrimExport` also writes it to `assets/trim_point.toml`,
   `trim_reference.toml` and `trim_controls.toml`.
2. **Linearize — `02_linearize.dyad`.** `TutorialLinearize` opens the measurement loop of
   the design model and linearizes the bare plant from its controls to its 12 measured
   states: poles, zeros, Bode and step responses.
3. **LQG, continuous — `03_lqg_continuous.dyad`.** `LQGDemo` closes the plant with a
   state-space controller through scalar analysis points. `TutorialLQG` synthesizes the
   regulator — the weights are set per channel in that channel's own units, and the
   docstring tabulates them — and `TutorialDiscreteLQG` is the same design
   ZOH-discretized at 100 Hz. `scripts/Tutorial/run_lqg_continuous_export.jl` and
   `run_lqg_discrete_export.jl` write the two results to `assets/controller.toml` and
   `assets/discrete_controller.toml`.
4. **LQG, sampled-data — `04_lqg_discrete.dyad`.** `DiscreteClosedLoopDemo` runs the
   discrete controller as a clocked `DiscreteStateSpace` between a vector sampler and a
   zero-order hold; `TutorialDiscreteClosedLoop` recovers a 10° pitch perturbation.
5. **Visualize — `05_visualize.dyad`.** `TutorialVisualizeContinuous` and
   `TutorialVisualizeDiscrete` render the two closed loops as animations of the airframe
   on the same perturbation. Needs a Makie backend in the session (`using GLMakie`).
6. **C code — `06_codegen.dyad`.** `ClockedDiscreteController` is step 4's controller
   and its clock with whole-array `u[12]`/`y[5]` connectors. `TutorialControllerCodegen`
   compiles it with SynchToolkit and writes standalone C to `generated_c/f16_controller/`,
   whose step function takes `double u[12]` and fills `double y[5]` each tick.
7. **Velocity-scheduled MPC — `07_velocity_mpc.dyad`.** `VelocityMPCDemo` closes the
   plant with the gain-scheduled MPC components of `MPCComponents.Experimental`:
   `LinearMPCScheduler` turns measured true airspeed into member weights,
   `LinearMPCScheduledObserver` blends the members' Kalman filters, and
   `LinearMPCScheduledOptimizer` solves the active members' quadratic programs and
   blends their first moves at 20 Hz between the vector samplers and zero-order holds of
   `dyad/VectorBlocks/`. Like step 4 it is wired with whole-array connections:
   `VectorSelect` narrows the plant's twelve outputs to the ten regulated states, and a
   `MatrixGain` each carries the reference map and the controller-to-plant unit
   conversion. `TutorialVelocityMPC` is a `TransientAnalysis` over it: trimmed at
   148 m/s with 2° of extra pitch attitude, commanded to 160 m/s over a ramp that
   crosses the middle knot.

   The bank is the one piece designed in Julia (`src/velocity_mpc.jl`, module
   `VelocityMPC`): it trims the plant and evaluates its symbolic linearization at each
   airspeed knot, in one absolute physical frame with a per-knot affine offset, and
   returns the `MPCComponents.MPCRef` the model takes as a structural parameter.

   ```sh
   julia --project=. scripts/Tutorial/run_velocity_mpc.jl
   ```

   writes `results/velocity_mpc/response.png` — airspeed against its reference,
   altitude, elevator and thrust.
8. **Envelope-scheduled MPC — `08_envelope_mpc.dyad`.** `EnvelopeMPCDemo` schedules a
   bank over a `velocities × altitudes` grid (3 × 3 by default) on both measured
   airspeed and measured altitude. `LinearMPCScheduler` takes one scalar, so the second
   axis is composed in Dyad: one scheduler per axis, and `VectorBlocks.OuterProduct`
   multiplies their hat-function weights into the bilinear weights of the grid. The
   observer and optimizer are step 7's. The grid is read from one lookup-table asset,
   `assets/envelope_trim_alpha.csv` (`DyadData.DyadInterpolationTable2D`): its axes are the
   knots, and its values are the trimmed angle of attack, which in level flight is also the
   trimmed pitch attitude; the pitch and angle-of-attack references blend it. Edit the axes
   and run `scripts/Tutorial/run_envelope_tables.jl` to move the grid.
   `TutorialEnvelopeMPC` starts trimmed at 150 m/s and 3000 m and is commanded to
   190 m/s and 4500 m, crossing a knot on each axis.

   `src/envelope_mpc.jl` (module `EnvelopeMPC`) builds the bank from step 7's member
   design, and `EnvelopeMPC.envelope()` trims and linearizes the plant at **10 000 flight
   conditions** (100 × 100 over 140–250 m/s and 0–9000 m) in about ten seconds once compiled. The bank
   is a coarse subset of those: the scheduled components hold one connector per member
   and stack every member's observer matrices, so their size grows with the member count
   and a 10 000-member bank is out of reach ([MPCComponents.jl#94](https://github.com/JuliaComputing/MPCComponents.jl/issues/94)).

   ```sh
   julia --project=. scripts/Tutorial/run_envelope_mpc.jl
   ```

   writes `results/envelope_mpc/envelope.png` (trim and pitch divergence rate over the
   10 000-point envelope, with the bank nodes) and `response.png`.

## The aircraft

The plant's coefficients are a least-squares condensation of the Stevens & Lewis
F-16 tables, taken at the reference CG (`xcg = 0.35c̄`). That leaves it **statically
unstable in pitch** — `Cma = +0.082/rad`, a real pole at +0.09 rad/s that doubles a
disturbance every 7.6 s — exactly as the real airframe is, and the reason the
regulator in steps 3 and 4 exists. `Trimming.F16OpenLoopDeparture` shows the same
trim with the controls frozen; setting `plant.xcg = 0.30` moves the CG forward and
the divergence goes away.

Trimming at the book's nominal condition (502 ft/s, sea level) reproduces S&L
Table 3.6-3 — α = 0.03714 rad against a published 0.03691. `scripts/fit_snl_aero.jl`
regenerates the deck from the tables in `scripts/snl_aero_tables.jl`, and
`test/f16_snl_validation.jl` pins both the trim and the instability.

## Running

```
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # first run downloads dependencies
julia --project=. -e 'using Pkg; Pkg.test()'          # plant validation and every closed loop
```

```julia
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
plot(TutorialDiscreteClosedLoop())       # step 4: sampled-data pitch recovery
TutorialLQG()                            # step 3: synthesize the continuous regulator
plot(F16ModelWorkshop.Trimming.F16OpenLoopDepartureAnalysis())  # the same airframe with no regulator
```

`julia --project=. gui/launch_gui.jl` opens the tuning dashboard on the step-3 design.

## Dependencies

- **MPCComponents** is pinned to a commit (`[sources]` in `Project.toml`). Its `main`
  needs LinearMPC 0.11, which is only on an unregistered branch, so the pin stays until
  that is released.
- **DiscreteComponents** stays on 0.4 because the MPCComponents pin requires it. 0.5
  rewrites `Sampler`/`ZeroOrderHold` in native Dyad with clock-typed connectors; once
  it is available, `MultiSampler`/`MultiZeroOrderHold` can become `y = sample(u)` and
  `y = hold(u)` on whole vectors instead of one scalar block per channel.
