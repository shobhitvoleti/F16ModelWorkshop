# F-16 control design in Dyad

In this workshop you take a 6-degree-of-freedom F-16 model from a steady flight condition to
working controllers, in eight steps:

| Step | You will | File in `dyad/Tutorial/` |
|---|---|---|
| 1 | Find the steady flight condition (trim) | `01_trim.dyad` |
| 2 | Linearize the aircraft about it | `02_linearize.dyad` |
| 3 | Design an LQG regulator | `03_lqg_continuous.dyad` |
| 4 | Run the regulator as a 100 Hz digital controller | `04_lqg_discrete.dyad` |
| 5 | Watch both loops as 3-D animations | `05_visualize.dyad` |
| 6 | Generate C code for the digital controller | `06_codegen.dyad` |
| 7 | Control airspeed with gain-scheduled MPC | `07_velocity_mpc.dyad` |
| 8 | Schedule the MPC on airspeed and altitude | `08_envelope_mpc.dyad` |

Each step is a Dyad *analysis*: a named, runnable experiment on a model. Steps build on each
other, so work through them in order.

## Before you start

You need:

- Dyad Studio (the VS Code extension) and Julia 1.12, with access to the JuliaHub package
  registries that the Dyad libraries come from.
- About 30 minutes for the first setup: the first run downloads and compiles many packages.
  Later runs are much faster.
- Optional: a C compiler. Steps 7 and 8 use it to compile the MPC solvers; without one they
  use the slower Julia solver.

## Set up

1. Clone this repository and open its folder in VS Code.
2. In a terminal in that folder, install the dependencies:

   ```sh
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

3. Check that everything works. This runs the full test suite, about 10 minutes:

   ```sh
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

   You should see `F16ModelWorkshop tests passed`. On a machine without a display, set
   `JULIA_PKG_PRECOMPILE_AUTO=0` first: GLMakie cannot precompile there, and the tests do
   not need it.

## How to run a step

**In Dyad Studio:** open the step's file and run its analysis (named `Tutorial…`) from the
analysis panel. Studio shows the results and plots.

**In the Julia REPL:** load the tutorial once, then call an analysis by name:

```julia
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
result = TutorialDiscreteClosedLoop()   # run step 4
plot(result)                            # plot every signal
```

Never edit the `generated/` folder. Dyad Studio rebuilds it from `dyad/` every time you save.

## The walkthrough

### Step 1 — Trim

**What it shows.** *Trim* is the steady flight condition: the controls and states at which
nothing changes. `TrimDemo` leaves thrust, elevator and pitch attitude unknown and requires
the rates of change to be zero, so the solver finds them.

**Run it.** `TutorialTrim` solves the trim. `TutorialTrimExport` also saves it to
`assets/trim_point.toml`, `trim_reference.toml` and `trim_controls.toml`, which steps 2–6
load.

**You should see** level flight at 3000 m and 152.4 m/s: angle of attack 0.059 rad (3.4°),
thrust about 10.8 kN and elevator about −0.7°.

### Step 2 — Linearize

**What it shows.** Near trim, the nonlinear aircraft behaves like a linear model.
`TutorialLinearize` computes that model from the four controls to the 12 measured states.

**Run it.** `TutorialLinearize`.

**You should see** poles, zeros, Bode and step responses. One pole sits in the right half
plane at about +0.09 rad/s: the airframe is unstable in pitch (see [The aircraft](#the-aircraft)).

### Step 3 — Design an LQG regulator

**What it shows.** An *LQG regulator* combines an optimal state-feedback controller with a
Kalman filter. `LQGDemo` is the aircraft wired to a state-space controller; `TutorialLQG`
designs that controller. Each weight is set in its channel's own units, and the file's
docstring explains every value.

**Run it.** `TutorialLQG` designs the continuous regulator; `TutorialDiscreteLQG` designs the
same regulator for a 100 Hz digital controller. To save them for steps 4–6, run:

```sh
julia --project=. scripts/Tutorial/run_lqg_continuous_export.jl
julia --project=. scripts/Tutorial/run_lqg_discrete_export.jl
```

**You should see** the designed controller and the analysis results for the closed loop.

To tune the design interactively, run `julia --project=. gui/launch_gui.jl` (see
[gui/README.md](gui/README.md)).

### Step 4 — Run it as a digital controller

**What it shows.** The regulator from step 3 runs at 100 Hz: the aircraft's states are
sampled, the controller updates once per tick, and its commands are held between ticks.

**Run it.** `TutorialDiscreteClosedLoop` starts the aircraft 10° nose-up of trim.

**You should see** pitch return to trim within 10 s, with altitude within 20 m and airspeed
within 5 m/s of trim.

### Step 5 — Visualize

**What it shows.** The continuous loop (step 3) and the digital loop (step 4) as 3-D
animations of the airframe, on the same 10° disturbance.

**Run it.** First load a Makie backend with `using GLMakie`. Then run
`TutorialVisualizeContinuous` and `TutorialVisualizeDiscrete`, or run
`julia --project=. scripts/Tutorial/run_visualize.jl`.

**You should see** two videos in `assets/`: `f16_continuous_closed_loop.mp4` and
`f16_discrete_closed_loop.mp4`.

### Step 6 — Generate C code

**What it shows.** The digital controller from step 4, compiled to standalone C that can run
on embedded hardware.

**Run it.** `TutorialControllerCodegen`.

**You should see** C sources in `generated_c/f16_controller/`. Each tick, the step function
takes the 12 tracking errors, `double u[12]`, and returns the 5 commands, `double y[5]`.

### Step 7 — Gain-scheduled MPC on airspeed

**What it shows.** *Model predictive control* (MPC) plans the next few seconds of commands
by optimization and respects limits such as maximum thrust and elevator travel. One linear
model is only accurate near one airspeed, so the controller is a *bank*: one MPC per airspeed
*knot* (140, 152.4 and 170 m/s). The bank blends the two controllers on either side of the
measured airspeed. This is *gain scheduling*.

**Run it.** `TutorialVelocityMPC` starts at 148 m/s and commands 160 m/s. To plot the
response:

```sh
julia --project=. scripts/Tutorial/run_velocity_mpc.jl
```

**You should see** airspeed reach 160 m/s while altitude holds at 3000 m. The plot is
`results/velocity_mpc/response.png`. The first run takes a few minutes while the solvers
compile.

### Step 8 — Schedule on airspeed and altitude

**What it shows.** The aircraft also changes with altitude, so this bank has one MPC at each
point of a 3 × 3 airspeed × altitude grid. The grid comes from a lookup table,
`assets/envelope_trim_alpha.csv`: its rows are the airspeed knots, its columns the altitude
knots, and its values the trimmed angle of attack, which sets the pitch and angle-of-attack
references. `EnvelopeMPC.envelope()` also linearizes the aircraft at 10 000 points of the
flight envelope, to show how it changes across it.

**Run it.** `TutorialEnvelopeMPC` starts at 150 m/s and 3000 m and commands 190 m/s and
4500 m. To plot the response and the envelope:

```sh
julia --project=. scripts/Tutorial/run_envelope_mpc.jl
```

**You should see** airspeed reach 190 m/s and altitude 4500 m. The plots are in
`results/envelope_mpc/`.

**Try it.** To move the grid, edit the table's first column (airspeeds) or header row
(altitudes), then rebuild its values:

```sh
julia --project=. scripts/Tutorial/run_envelope_tables.jl
```

The bank stays small on purpose: the MPC components grow with the number of controllers,
so a bank of 10 000 is not yet possible
([MPCComponents.jl#94](https://github.com/JuliaComputing/MPCComponents.jl/issues/94)).

## The aircraft

The model's aerodynamic coefficients are fitted to the F-16 tables in Stevens & Lewis,
*Aircraft Control and Simulation*, at the reference center of gravity (35 % of the mean
chord). Like the real F-16, the model is **unstable in pitch**: a disturbance doubles about
every 7.6 s. That is why the aircraft needs the regulator from step 3.

- `Trimming.F16OpenLoopDepartureAnalysis` shows the aircraft departing with the controls
  frozen. Set `plant.xcg = 0.30` to move the center of gravity forward, and it becomes stable.
- At the book's reference condition (502 ft/s, sea level) the model trims at α = 0.03714 rad;
  the book gives 0.03691 rad. `test/f16_snl_validation.jl` checks this and the instability.
- `scripts/fit_snl_aero.jl` refits the coefficients from the tables in
  `scripts/snl_aero_tables.jl`.

## Repository layout

| Path | Contents |
|---|---|
| `dyad/Tutorial/` | The eight steps |
| `dyad/Plant/` | `F16PlantModel`, the aircraft |
| `dyad/Trimming/` | The aircraft flown open loop at trim, and its pitch departure |
| `dyad/VectorBlocks/`, `dyad/Utils/` | Vector blocks, mux/demux and the pose bridge for the animations |
| `dyad/Tests/` | Check models for the step-7 bank, run by the tests |
| `dyad/*.dyad`, `src/` | The custom analyses (trim export, visualization, C code) and the MPC design code of steps 7 and 8 |
| `assets/` | The saved trim and controllers, the step-8 lookup table, icons and the airframe mesh |
| `scripts/Tutorial/` | Command-line scripts that regenerate assets, animations and plots |
| `generated/`, `generated_c/` | Code generated by Dyad (step-6 C code in `generated_c/`); do not edit |
| `gui/` | Optional tuning dashboard for step 3 |
| `test/` | Checks the aircraft against the book and every closed loop |

## For maintainers

- **MPCComponents** is pinned to a commit (`[sources]` in `Project.toml`). Its latest version
  needs LinearMPC 0.11, which is not yet registered.
- **DiscreteComponents** stays on 0.4 because that MPCComponents commit requires it. Version
  0.5 defines its sampler and hold blocks in native Dyad; once it can be used,
  `MultiSampler` and `MultiZeroOrderHold` can become `y = sample(u)` and `y = hold(u)` on
  whole vectors.
- Native two-variable scheduling is proposed in
  [MPCComponents.jl#95](https://github.com/JuliaComputing/MPCComponents.jl/pull/95). Once it
  is merged, step 8 can use `LinearMPCScheduler2D` instead of two schedulers and
  `OuterProduct`.
