# F16ModelWorkshop

Workshop teaching material for modeling and control design in
[Dyad](https://juliahub.com/products/dyad): a 6-DOF F16 aircraft plant, trimming,
linearization, and LQG control — continuous and discrete (sampled-data).

## Repository layout

Dyad sources live in `dyad/`; the compiler regenerates `generated/` from them
(never edit `generated/` by hand — run `dyad compile .`).

| Module | Contents |
|---|---|
| `dyad/Plant/` | F16 6-DOF plant: `F16PlantModel` (vector I/O) and `F16PlantIO` (scalar I/O) |
| `dyad/Trimming/` | Trim models and the trimmed-plant scenario |
| `dyad/Controls/` | LQG controller design (`lqg_design.dyad`), demo loops, and 3-D visualizers |
| `dyad/VectorBlocks/` | Vector-connector building blocks (constant, add, sampler, ZOH, clock) |
| `dyad/Utils/` | Mux/demux and the signal→pose bridge for visualization |
| `dyad/Tutorial/` | **Start here** — a guided four-step walkthrough (below) |

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
   bring the submodule into scope (or fully-qualify, e.g.
   `F16ModelWorkshop.Controls.Scenario1OpenLoop()`):
   ```julia
   using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
   plot(TutorialDiscreteClosedLoop())                     # sampled-data pitch recovery
   TutorialLQG()                                          # synthesize the continuous LQG controller
   plot(F16ModelWorkshop.Controls.Scenario1OpenLoop())   # open-loop 10° pitch perturbation
   ```

## Trim workflow

`F16ModelWorkshop.TrimPlantAnalysis()` solves the trim and writes
`trim/trim_point.toml`. Components load their operating point from that file at
build time via `load_trim`, so re-running the trim and recompiling refreshes the
whole workshop to the new condition automatically.
