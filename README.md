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
| `test/` | Pins the plant to Stevens & Lewis and checks that both closed loops hold trim |

## The walkthrough

Steps 1–6 are Dyad analyses in `dyad/Tutorial/`: run them from Dyad Studio, or call them by
name in the REPL after `using F16ModelWorkshop, F16ModelWorkshop.Tutorial`. Steps 1 and 3
produce the parameter-set assets used by the LQG walkthrough. Re-run those two
to update its flight condition or plant. Step 7 is a Julia example that computes
its own trim and linearization at each velocity knot.

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

7. **Velocity-scheduled MPC — [07_velocity_mpc.jl](dyad/Tutorial/07_velocity_mpc.jl).**
   Build constrained linear MPC controllers at an airspeed grid, blend their commands
   using measured true airspeed, and simulate a speed ramp on the nonlinear Dyad plant.
   The [step-7 guide](dyad/Tutorial/07_velocity_mpc.md) explains the model, scheduling,
   and actuator constraints. Run from the repository root:

   ```sh
   julia --project=. dyad/Tutorial/07_velocity_mpc.jl
   ```

   Results are written to `results/velocity_mpc/`: trajectory CSV, summary TOML,
   and a plot of speed tracking, altitude, elevator, and controller weights.

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
