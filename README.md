# F-16 control design in Dyad

A six-degree-of-freedom F-16 model, taken from a steady flight condition to working
controllers in nine steps. Each step is a Dyad *analysis*, a named and runnable experiment
on a model. The steps build on each other, so work through them in order.

| Step | Topic | File in `dyad/Tutorial/` |
|---|---|---|
| 1 | Find the steady flight condition (trim) | `01_trim.dyad` |
| 2 | Linearize the aircraft about it | `02_linearize.dyad` |
| 3 | Design an LQG regulator | `03_lqg_continuous.dyad` |
| 4 | Run the regulator as a 100 Hz digital controller | `04_lqg_discrete.dyad` |
| 5 | Animate both loops in 3-D | `05_visualize.dyad` |
| 6 | Generate C code for the digital controller | `06_codegen.dyad` |
| 7 | Hold airspeed and altitude with a gain-scheduled PID autopilot | `07_gain_scheduled_pid.dyad` |
| 8 | Control airspeed with gain-scheduled MPC | `08_velocity_mpc.dyad` |
| 9 | Schedule the MPC on airspeed and altitude | `09_envelope_mpc.dyad` |

## Requirements

- Dyad Studio (the VS Code extension) with the Dyad 3.5 runtime (Julia 1.13, the
  `dyad-3.5.0` juliaup channel), and access to the JuliaHub package registries that provide
  the Dyad libraries.
- About 30 minutes for the first setup, which downloads and compiles many packages.
- Optional: a C compiler. Steps 8 and 9 use it to compile the MPC solvers and fall back to
  a slower Julia solver without one.

## Setup

From the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # install the dependencies
julia --project=. -e 'using Pkg; Pkg.test()'          # run the test suite, about 10 minutes
```

The tests end with `F16ModelWorkshop tests passed`. On a machine without a display, set
`JULIA_PKG_PRECOMPILE_AUTO=0` first: GLMakie cannot precompile there, and the tests do not
need it.

## Running a step

**Dyad Studio.** Open the step's file, run the analysis the step names from the analysis
panel, and open the result it names. The generic *Solution plot* shows every state at once;
the point of each step is in the named result instead.

**Julia REPL.** Load the tutorial, then call an analysis and ask for a result by name:

```julia
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, DyadInterface, Plots
result = TutorialGainScheduledPID()                 # step 7b
DyadInterface.artifacts(result, :FlightResponse)    # the figure Studio shows
```

**All steps at once.** `scripts/tutorial_walkthrough.jl` runs steps 1–9 in order and
reports the result each step names: figures to `results/walkthrough/`, tables to the
terminal. Pass `--no-video` to skip step 5 on a machine without a display.

```sh
julia --project=. scripts/tutorial_walkthrough.jl
```

**Saving results.** `scripts/save_artifacts.jl` writes every figure (PNG) and table (CSV)
of the analyses it is given to `results/<analysis>/`. Without arguments it runs every
tutorial analysis except those that write assets or videos.

```sh
julia --project=. scripts/save_artifacts.jl TutorialGainScheduleDesign TutorialGainScheduledPID
```

Do not edit `generated/`: Dyad Studio rebuilds it from `dyad/` on every save.

## Walkthrough

### Step 1 — Trim

*Trim* is the steady flight condition: the controls and states at which nothing changes.
`TrimDemo` leaves thrust, elevator and pitch attitude unknown and requires the rates of
change to be zero, and the solver finds the unknowns.

- **Run** `TutorialTrim` and open **`TrimTable`**.
- **Expect** level flight at 3000 m and 152.4 m/s: angle of attack and pitch attitude
  3.39°, thrust 10.8 kN, elevator −0.69°.

`TutorialTrimExport` runs the same solve and writes `assets/trim_point.toml`,
`trim_reference.toml` and `trim_controls.toml`, which steps 2–6 apply. Rerun it only after
changing the flight condition or the plant.

### Step 2 — Linearize

Near trim, the nonlinear aircraft behaves like a linear model.

- **Run** `TutorialLinearize` and open **`PoleZeroMap`** and **`BodePlot`**.
- **Expect** one pole in the right half-plane at about +0.095 rad/s: the airframe is
  unstable in pitch (see [The aircraft](#the-aircraft)).

### Step 3 — LQG regulator

An *LQG regulator* combines optimal state feedback with a Kalman filter. `LQGDemo` is the
aircraft wired to a state-space controller, and the analysis designs that controller. Each
weight is set in its channel's own units; the file's docstring explains every value.

- **Run** `TutorialDiscreteLQG` (100 Hz) and open **`PZMaps`** and **`StepResponse`**.
- **Expect** every closed-loop pole inside the unit circle, and in the 30 s step response
  altitude settling in about 8 s and sideslip in about 27 s. Position, heading and bank
  angle take minutes: this inner regulator leaves them to an outer guidance loop (see the
  `TutorialLQG` docstring).

`TutorialLQG` is the same design in continuous time. Its `StepResponse` is very large, because
the Kalman filter's fastest pole (about 300 rad/s) sets the simulation step; open its
`PZMaps` instead.

`TutorialLQGExport` and `TutorialDiscreteLQGExport` run the same designs and write
`assets/controller.toml`, which the continuous loop of step 5 applies, and
`assets/discrete_controller.toml`, which steps 4–6 apply. Rerun them after changing a
weight. To tune the design interactively, run
`julia --project=. gui/launch_gui.jl` (see [gui/README.md](gui/README.md)).

### Step 4 — Digital controller

The step-3 regulator runs at 100 Hz: the aircraft's states are sampled, the controller
updates once per tick, and its commands are held between ticks.

- **Run** `TutorialDiscreteClosedLoop` and open **`FlightResponse`**.
- **Expect** the aircraft, started 10° nose-up of trim, back at its trim pitch attitude
  within 10 s, with altitude within 20 m and airspeed within 5 m/s of trim. The elevator
  panel shows the held value of each tick.

### Step 5 — Visualization

The continuous loop (step 3) and the digital loop (step 4) as 3-D animations of the
airframe, on the same 10° disturbance. The analysis renders with GLMakie, so the machine
needs a display.

- **Run** `TutorialVisualizeContinuous` or `TutorialVisualizeDiscrete` and open
  **`Animation`**.
- **Expect** the video, also written to `assets/f16_continuous_closed_loop.mp4` or
  `assets/f16_discrete_closed_loop.mp4`.

### Step 6 — C code generation

The step-4 controller compiled to standalone C for embedded targets. Each tick, the step
function takes the 12 tracking errors, `double u[12]`, and returns the 5 commands,
`double y[5]`.

- **Run** `TutorialControllerCodegen` and open **`StepCheck`** and **`GeneratedFiles`**.
- **Expect** the compiled controller, stepped 200 ticks, to return the designed
  controller's commands to within 1e-15. The check always runs SynchJulia's Julia backend,
  and also the C build when `Clang_unified_jll` is loaded (`using Clang_unified_jll`). The
  sources are written to `generated_c/f16_controller/`, and each is also a download.

### Step 7 — Gain-scheduled PID autopilot

The classical autopilot of Stevens & Lewis: *pitch-attitude hold* moves the elevator to
hold a pitch attitude, *altitude hold* sets that pitch attitude from the altitude error,
and an *autothrottle* sets thrust from the airspeed error. Each loop is a
`DiscreteComponents.DiscretePIDScheduled` controller whose gains are input signals.

The aircraft responds differently at different flight conditions, so one set of gains is
not right everywhere. *Gain scheduling* designs the gains at a few *design points* (140,
152.4 and 170 m/s at 3000 m) and interpolates between them on the *dynamic pressure*
q̄ = ½ρV², to which every aerodynamic force is proportional. `AutopilotGainSchedule` turns
the measured altitude and airspeed into q̄ and the gains; the PID controllers contain no
scheduling logic.

- **Run** `TutorialGainScheduleDesign` (7a) and open **`LoopShapes`**.
- **Expect** the pitch loop at all three design points. With each point's own gains, the
  loops cross 0 dB at 2.06–2.07 rad/s; with the 152.4 m/s gains held fixed, the crossover
  moves from 1.87 to 2.36 rad/s. That spread is what the schedule removes. **`GainSchedule`**
  shows the pitch gain falling from −30.4 to −22.5 deg/rad as q̄ rises from 8.9 to
  13.1 kPa, and **`Margins`** lists the margins of all three loops.

- **Run** `TutorialGainScheduledPID` (7b) and open **`FlightResponse`**.
- **Expect** the step-8 manoeuvre, 148 to 160 m/s at 3000 m: airspeed reaches 160 m/s and
  altitude stays within 7 m of 3000 m. Below, q̄ crosses the middle design point at about
  t = 9 s, the design-point weights hand over, and the scheduled pitch gain follows.

**Try it:** change the design points (`velocities`) and rerun 7a.

### Step 8 — Gain-scheduled MPC on airspeed

*Model predictive control* (MPC) plans the next few seconds of commands by optimization
and respects limits such as maximum thrust and elevator travel. A linear model is accurate
only near one airspeed, so the controller is a *bank* with one MPC per airspeed *knot*
(140, 152.4 and 170 m/s), blended between the two knots either side of the measured
airspeed: the gain scheduling of step 7, applied to whole controllers.

- **Run** `TutorialVelocityMPC` and open **`FlightResponse`**.
- **Expect** airspeed to reach 160 m/s while altitude holds at 3000 m, and the members'
  weights to hand over as airspeed crosses 152.4 m/s. The first run takes a few minutes
  while the solvers compile.

### Step 9 — Scheduling on airspeed and altitude

The aircraft also changes with altitude, so this bank has one MPC at each node of a 3 × 3
airspeed × altitude grid. The grid comes from `assets/envelope_trim_alpha.csv`: rows are
airspeed knots, columns are altitude knots, and values are the trimmed angle of attack,
which sets the pitch and angle-of-attack references.

- **Run** `TutorialEnvelope` (9a) and open **`Envelope`**.
- **Expect** the trimmed angle of attack, thrust, elevator and pitch divergence rate over
  140–250 m/s and 0–9000 m, from 10 000 trims and linearizations, with the bank's nine
  nodes marked: the aircraft changes along both axes.

- **Run** `TutorialEnvelopeMPC` (9b) and open **`FlightResponse`**.
- **Expect** airspeed to reach 190 m/s and altitude 4500 m, and the airspeed and altitude
  weights with which the bank blends its nine members.

**Try it:** to move the grid, edit the table's first column (airspeeds) or header row
(altitudes), then run `TutorialEnvelopeTable` (9c), which re-trims the aircraft at the new
nodes and rewrites the table.

## Presenting the workshop

Run everything once before the session (`julia --project=. scripts/save_artifacts.jl`) so
that nothing compiles in front of the audience. Times are for one Julia session on an
Apple Silicon laptop, run in this order after the packages were loaded; the first analysis
also builds the plant, so it takes longest.

| Step | Run | Time | Open | Point at |
|---|---|---|---|---|
| 1 | `TutorialTrim` | 56 s | `TrimTable` | α = 3.39°, thrust 10.8 kN, elevator −0.69° |
| 2 | `TutorialLinearize` | 19 s | `PoleZeroMap` | the pole at +0.095 rad/s: unstable in pitch |
| 3 | `TutorialDiscreteLQG` | 2 s | `PZMaps` | closed-loop poles inside the unit circle |
| 4 | `TutorialDiscreteClosedLoop` | 34 s | `FlightResponse` | pitch back at trim within 10 s |
| 5 | `TutorialVisualizeDiscrete` | 94 s | `Animation` | the same recovery in 3-D |
| 6 | `TutorialControllerCodegen` | 13 s | `StepCheck` | the C matches the design |
| 7a | `TutorialGainScheduleDesign` | 12 s | `LoopShapes` | scheduled loops cross over together; fixed ones spread |
| 7b | `TutorialGainScheduledPID` | 15 s | `FlightResponse` | design-point weights hand over at 9 s |
| 8 | `TutorialVelocityMPC` | 26 s | `FlightResponse` | the bank members' weights |
| 9a | `TutorialEnvelope` | 3 s | `Envelope` | the aircraft changes along both axes |
| 9b | `TutorialEnvelopeMPC` | 23 s | `FlightResponse` | both references tracked |

Step 5 needs a display and takes the longest, so start it before talking about it.

## Known limitations

- `DyadControlSystems.LinearAnalysis` offers results that it cannot build for this
  4-input, 12-output plant. In step 2, `RootLocusPlot` and `StepInfoPlot` stop with an
  error, and `RGAPlot` never returns, which blocks the session until Julia is restarted.
- The MPC components grow with the number of controllers, so the step-9 bank stays small;
  a bank of 10 000 is not yet possible
  ([MPCComponents.jl#94](https://github.com/JuliaComputing/MPCComponents.jl/issues/94)).

## The aircraft

The aerodynamic coefficients are fitted to the F-16 tables of Stevens & Lewis, *Aircraft
Control and Simulation*, at the reference center of gravity (35 % of the mean chord). Like
the real F-16, the model is **unstable in pitch**: a disturbance doubles about every 7.3 s,
which is why step 3 needs a regulator.

- `Trimming.F16OpenLoopDepartureAnalysis` flies the aircraft with the controls frozen and
  shows it departing.
- Moving the center of gravity forward to `xcg = 0.30` makes the airframe statically
  stable once it is re-trimmed there. The departure scenario's frozen controls are trimmed
  for 0.35, so at 0.30 they pitch it into a dive instead.
- At the book's reference condition (502 ft/s, sea level) the model trims at
  α = 0.03714 rad; the book gives 0.03691 rad. `test/f16_snl_validation.jl` checks this
  and the instability.
- `scripts/fit_snl_aero.jl` refits the coefficients from the tables in
  `scripts/snl_aero_tables.jl`.

## Repository layout

| Path | Contents |
|---|---|
| `dyad/Tutorial/` | The nine steps |
| `dyad/Plant/` | `F16PlantModel`, the aircraft |
| `dyad/Trimming/` | The aircraft flown open loop at trim, and its pitch departure |
| `dyad/VectorBlocks/`, `dyad/Utils/` | Vector blocks, mux/demux, and the pose bridge for the animations |
| `dyad/Tests/` | Check models for the step-7 controller and schedule and the step-8 bank |
| `dyad/*.dyad`, `src/` | The custom analyses the steps extend, and the design code of steps 7–9 |
| `assets/` | Saved trim and controllers, the step-9 lookup table, icons, and the airframe mesh |
| `scripts/` | `tutorial_walkthrough.jl`, `save_artifacts.jl`, and the aerodynamic fit of the plant |
| `generated/`, `generated_c/` | Code generated by Dyad, and the step-6 C code; do not edit |
| `gui/` | Optional tuning dashboard for step 3 |
| `test/` | Checks of the aircraft against the book and of every closed loop |

## Maintenance

The Dyad libraries are registered releases from DyadRegistry: MPCComponents 0.2,
DiscreteComponents 0.6 (which includes `DiscretePIDScheduled`) and DyadControlSystems 2.6.
They and `generated/` must share Dyad's constructor API, which `generated/definitions.jl`
checks when the package loads; recompile after changing a library version.
`test/lqg_design.jl` reruns the step-2 linearization and the step-3 designs against the
controllers in `assets/`, so a library change that alters the designs fails the tests.

- **MultibodyComponents**, used only for the step-5 animation, is pinned to a commit in
  `[sources]` of `Project.toml`.
- DiscreteComponents defines its sampler and hold in native Dyad, so `MultiSampler` and
  `MultiZeroOrderHold` can become `y = sample(u)` and `y = hold(u)` on whole vectors.
- Native two-variable scheduling is proposed in
  [MPCComponents.jl#95](https://github.com/JuliaComputing/MPCComponents.jl/pull/95). Once
  merged, step 9 can use `LinearMPCScheduler2D` in place of two schedulers and
  `OuterProduct`.
