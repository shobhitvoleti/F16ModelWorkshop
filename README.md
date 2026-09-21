# F16ModelWorkshop

Workshop material for modeling and control design in
[Dyad](https://juliahub.com/products/dyad): a 6-DOF F-16 plant taken from trim through
linearization to an LQG regulator, its sampled-data implementation, a 3-D animation, and
standalone C for the controller, followed by velocity-scheduled linear MPC.

## Layout

Dyad sources live in `dyad/`; the compiler regenerates `generated/` from them. Never edit
`generated/` by hand — Dyad Studio regenerates it on save, or run `dyad compile .`.

| Path | Contents |
|---|---|
| `dyad/Tutorial/` | **Start here** — the seven-step walkthrough below |
| `dyad/Plant/` | `F16PlantModel`, the 6-DOF plant with vector I/O |
| `dyad/Trimming/` | The trimmed plant flown open loop, and its pitch departure |
| `dyad/VectorBlocks/`, `dyad/Utils/` | Vector-signal blocks, mux/demux, and the signal-to-pose bridge the tutorial is wired with |
| `dyad/*.dyad` | The three custom analyses (trim export, visualization, C export), each backed by a spec in `src/` |
| `assets/` | Parameter sets the models `apply` — the trim point from step 1 and the two controllers from step 3 — plus icons and the airframe mesh |
| `scripts/Tutorial/` | Regenerate the committed assets and animations from the command line |
| `generated_c/` | The C emitted by step 6 |
| `gui/` | Optional live tuning dashboard for the step-3 design (GLMakie) |
| `test/` | Pins the plant to Stevens & Lewis and checks that the closed loops hold trim and track |
| `MPCCOMPONENTS_ISSUES.md` | Friction log for the MPCComponents dependency step 7 is built on |

## The walkthrough

All seven steps are Dyad analyses in `dyad/Tutorial/`: run them from Dyad Studio, or call
them by name in the REPL after `using F16ModelWorkshop, F16ModelWorkshop.Tutorial`. Steps 1
and 3 produce the parameter-set assets used by the LQG walkthrough. Re-run those two
to update its flight condition or plant. Step 7 computes its own trim and
linearization at each velocity knot instead of applying those assets.

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
6. **C code — `06_codegen.dyad`.** `TutorialControllerCodegen` isolates the clocked
   controller at its analysis points and emits it as standalone C under
   `generated_c/f16_controller/`.

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
   `MPCCOMPONENTS_ISSUES.md` records what that dependency forced.

   ```sh
   julia --project=. scripts/Tutorial/run_velocity_mpc.jl
   ```

   writes `results/velocity_mpc/response.png` — airspeed against its reference,
   altitude, elevator and thrust. Exporting the bank to C needs `backend = C` on the
   optimizer and a `CCodeExport` analysis, which is a follow-up.

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
julia --project=. -e 'using Pkg; Pkg.test()'          # plant validation + both closed loops
```

```julia
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
plot(TutorialDiscreteClosedLoop())       # step 4: sampled-data pitch recovery
TutorialLQG()                            # step 3: synthesize the continuous regulator
plot(F16ModelWorkshop.Trimming.F16OpenLoopDepartureAnalysis())  # the same airframe with no regulator
```

`julia --project=. gui/launch_gui.jl` opens the tuning dashboard on the step-3 design.
