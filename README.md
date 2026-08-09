# F16ModelWorkshop

Workshop teaching material for modeling and control design in
[Dyad](https://juliahub.com/products/dyad): a 6-DOF F16 aircraft plant, trimming,
linearization, and LQG control — continuous and discrete (sampled-data).

## Repository layout

Dyad sources live in `dyad/`; the compiler regenerates `generated/` from them
(never edit `generated/` by hand — run `dyad compile .`).

| Module | Contents |
|---|---|
| `dyad/Plant/` | `F16PlantModel` — the F16 6-DOF plant, vector I/O |
| `dyad/Trimming/` | Trim scenarios: the trimmed plant, and the open-loop departure |
| `dyad/VectorBlocks/` | Vector-connector building blocks (constant, add, sampler, ZOH, clock) |
| `dyad/Utils/` | Mux/demux and the signal→pose bridge for visualization |
| `dyad/Tutorial/` | **Start here** — a guided five-step walkthrough (below) |

## Tutorial walkthrough

The `Tutorial` module is a self-contained tour from a raw plant to a working
sampled-data controller:

1. **`01_trim.dyad` — `TutorialTrim` / `TutorialTrimExport`.** Find the steady
   flight condition by declaring the unknown controls/states `missing` and solving
   the equilibrium constraints. `TutorialTrimExport` (extends the custom
   `TrimExportAnalysis`) does the same solve and writes the operating point to
   `trim/tutorial_trim_point.toml`.
2. **`02_linearize.dyad` — `TutorialLinearize` / `TutorialLinearizeExport`.**
   Linearize the trimmed plant to the state-space model that control design is
   built on. `TutorialLinearizeExport` (extends the custom `LinearizeExportAnalysis`)
   also writes the A/B/C/D to `trim/tutorial_linear_model.toml`.
3. **`03_lqg_continuous.dyad` — `TutorialLQG`.** Design a continuous LQG
   regulator and simulate the closed-loop response to a pitch perturbation.
4. **`04_lqg_discrete.dyad` — `TutorialDiscreteClosedLoop`.** The same loop as a
   100 Hz sampled-data system, wired entirely with vector connectors: sampler →
   discrete state-space controller → zero-order hold.
5. **`05_visualize.dyad` — `TutorialVisualizeContinuous` /
   `TutorialVisualizeDiscrete`.** Render either closed loop as a 3-D animation.
   Each viz model `extends` its loop and adds only a measurement tap, a
   `SignalPoseSource` and a `ShapefileVisualizer`; the analysis simulates the model
   and writes the video to `assets/`. Requires a Makie backend (`using GLMakie`).
6. **`06_codegen.dyad` — `TutorialControllerCodegen`.** Emit the discrete
   controller as standalone C.

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

## Running the models

1. Instantiate the environment (first run downloads dependencies):
   ```
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```
2. Run the test harness to confirm the models build:
   ```
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```
3. Run an analysis and plot it. Analyses live in their module's namespace, so
   bring the submodule into scope or fully-qualify:
   ```julia
   using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
   plot(TutorialDiscreteClosedLoop())                     # sampled-data pitch recovery
   TutorialLQG()                                          # synthesize the continuous LQG controller
   plot(F16ModelWorkshop.Trimming.F16OpenLoopDepartureAnalysis())  # the same airframe with no regulator
   ```

## Trim workflow

`F16ModelWorkshop.TrimPlantAnalysis()` solves the trim and writes
`trim/trim_point.toml`. Components load their operating point from that file at
build time via `load_trim`, so re-running the trim and recompiling refreshes the
whole workshop to the new condition automatically.
