# F-16 control design in Dyad

In this workshop you take a 6-degree-of-freedom F-16 model from a steady flight condition to
working controllers, in nine steps:

| Step | You will | File in `dyad/Tutorial/` |
|---|---|---|
| 1 | Find the steady flight condition (trim) | `01_trim.dyad` |
| 2 | Linearize the aircraft about it | `02_linearize.dyad` |
| 3 | Design an LQG regulator | `03_lqg_continuous.dyad` |
| 4 | Run the regulator as a 100 Hz digital controller | `04_lqg_discrete.dyad` |
| 5 | Watch both loops as 3-D animations | `05_visualize.dyad` |
| 6 | Generate C code for the digital controller | `06_codegen.dyad` |
| 7 | Hold airspeed and altitude with a gain-scheduled PID autopilot | `07_gain_scheduled_pid.dyad` |
| 8 | Control airspeed with gain-scheduled MPC | `08_velocity_mpc.dyad` |
| 9 | Schedule the MPC on airspeed and altitude | `09_envelope_mpc.dyad` |

Each step is a Dyad *analysis*: a named, runnable experiment on a model. Steps build on each
other, so work through them in order.

## Before you start

You need:

- Dyad Studio (the VS Code extension) and Julia 1.12, with access to the JuliaHub package
  registries that the Dyad libraries come from.
- About 30 minutes for the first setup: the first run downloads and compiles many packages.
  Later runs are much faster.
- Optional: a C compiler. Steps 8 and 9 use it to compile the MPC solvers; without one they
  use the slower Julia solver. Step 6 checks its generated C against the design when
  `Clang_unified_jll` is loaded, and checks SynchJulia's Julia backend otherwise.

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

**In Dyad Studio:** open the step's file, run the analysis the step names from the analysis
panel, and open the result the step names. Every step's point is in one of its results; the
generic *Solution plot* of a flight shows every state at once and is not one of them.

**In the Julia REPL:** load the tutorial once, then call an analysis by name and ask for a
result by its name:

```julia
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, DyadInterface, Plots
result = TutorialGainScheduledPID()                      # step 7b
DyadInterface.artifacts(result, :FlightResponse)         # the figure Studio shows
```

To save every figure and table of some analyses as files under `results/`, for a handout
or to check them before a session:

```sh
julia --project=. scripts/save_artifacts.jl TutorialGainScheduleDesign TutorialGainScheduledPID
```

Never edit the `generated/` folder. Dyad Studio rebuilds it from `dyad/` every time you save.

## The walkthrough

### Step 1 — Trim

**The idea.** *Trim* is the steady flight condition: the controls and states at which
nothing changes. `TrimDemo` leaves thrust, elevator and pitch attitude unknown and requires
the rates of change to be zero, so the solver finds them.

**Run** `TutorialTrim` and open **`TrimTable`**.

**You should see** level flight at 3000 m and 152.4 m/s: angle of attack and pitch attitude
3.39°, thrust 10.8 kN and elevator −0.69°.

**Also.** `TutorialTrimExport` does the same solve and saves it as
`assets/trim_point.toml`, `trim_reference.toml` and `trim_controls.toml`, which steps 2–6
apply. Run it only after changing the flight condition or the plant.

### Step 2 — Linearize

**The idea.** Near trim, the nonlinear aircraft behaves like a linear model.

**Run** `TutorialLinearize` and open **`PoleZeroMap`** and **`BodePlot`**.

**You should see** one pole in the right half plane at about +0.095 rad/s: the airframe is
unstable in pitch (see [The aircraft](#the-aircraft)).

### Step 3 — Design an LQG regulator

**The idea.** An *LQG regulator* combines an optimal state-feedback controller with a
Kalman filter. `LQGDemo` is the aircraft wired to a state-space controller; the analysis
designs that controller. Each weight is set in its channel's own units, and the file's
docstring explains every value.

**Run** `TutorialLQG` (continuous) or `TutorialDiscreteLQG` (100 Hz) and open
**`StepResponse`** and **`GangOfFour`**.

**You should see** every step response settle, and the sensitivity functions of the loop.

**Also.** `TutorialLQGExport` and `TutorialDiscreteLQGExport` run the same designs and save
the controllers as `assets/controller.toml` and `assets/discrete_controller.toml`, which
steps 4–6 apply. Run them after changing a weight. To tune the design interactively, run
`julia --project=. gui/launch_gui.jl` (see [gui/README.md](gui/README.md)).

### Step 4 — Run it as a digital controller

**The idea.** The regulator from step 3 runs at 100 Hz: the aircraft's states are sampled,
the controller updates once per tick, and its commands are held between ticks.

**Run** `TutorialDiscreteClosedLoop` and open **`FlightResponse`**.

**You should see** the aircraft, started 10° nose-up of trim, back at its trim pitch
attitude within 10 s, with altitude within 20 m and airspeed within 5 m/s of trim. The
elevator panel shows the held value of every tick.

### Step 5 — Visualize

**The idea.** The continuous loop (step 3) and the digital loop (step 4) as 3-D animations
of the airframe, on the same 10° disturbance.

**Run** `TutorialVisualizeContinuous` or `TutorialVisualizeDiscrete` and open
**`Animation`**. The analysis loads GLMakie to render, so the machine needs a display.

**You should see** the video, also written to `assets/f16_continuous_closed_loop.mp4` or
`assets/f16_discrete_closed_loop.mp4`.

### Step 6 — Generate C code

**The idea.** The digital controller from step 4, compiled to standalone C that can run on
embedded hardware.

**Run** `TutorialControllerCodegen` and open **`StepCheck`** and **`GeneratedFiles`**.

**You should see** that the compiled controller, stepped 200 ticks, returns the commands of
the designed controller to within 1e-15. The check runs the C build itself when
Clang_unified_jll is loaded (`using Clang_unified_jll`), and SynchJulia's Julia backend
otherwise. The C sources are in `generated_c/f16_controller/`, each also a download: each
tick, the step function takes the 12 tracking errors, `double u[12]`, and returns the 5
commands, `double y[5]`.

### Step 7 — Gain-scheduled PID autopilot

**The idea.** A classical autopilot from Stevens & Lewis: *pitch-attitude hold* moves the
elevator to hold a pitch attitude, *altitude hold* sets that pitch attitude from the
altitude error, and an *autothrottle* sets the thrust from the airspeed error. Each loop is
a PID controller (`DiscreteComponents.DiscretePIDScheduled`) whose gains are input signals.

The aircraft responds differently at different airspeeds and altitudes, so one set of gains
is not right everywhere. *Gain scheduling* designs the gains at a few flight conditions,
the *design points* (140, 152.4 and 170 m/s at 3000 m), and interpolates between them.
Following Stevens & Lewis, the gains are interpolated on the *dynamic pressure*
q̄ = ½ρV², because every aerodynamic force scales with it. `AutopilotGainSchedule` turns the
measured altitude and airspeed into q̄ and the gains; the PID controllers contain no
scheduling logic.

**Run** `TutorialGainScheduleDesign` (7a) and open **`LoopShapes`**.

**You should see** the pitch loop at all three design points. With each point's own gains
the loops cross 0 dB at 2.06–2.07 rad/s; with the 152.4 m/s gains held fixed, the crossover
moves from 1.87 to 2.36 rad/s. That difference is what the schedule is for. **`GainSchedule`**
shows the gains against q̄: the pitch gain falls from −30.4 to −22.5 deg/rad as q̄ rises from
8.9 to 13.1 kPa. **`Margins`** has the numbers for all three loops.

**Then run** `TutorialGainScheduledPID` (7b) and open **`FlightResponse`**.

**You should see** the step-8 manoeuvre, 148 to 160 m/s at 3000 m: airspeed at 160 m/s and
altitude within 7 m of 3000 m. Below them, q̄ crosses the middle design point at about
t = 9 s, the weight of the design points hands over there, and the scheduled pitch gain
follows.

**Try it.** Change the design points (`velocities`) and run 7a again.

### Step 8 — Gain-scheduled MPC on airspeed

**The idea.** *Model predictive control* (MPC) plans the next few seconds of commands by
optimization and respects limits such as maximum thrust and elevator travel. One linear
model is only accurate near one airspeed, so the controller is a *bank*: one MPC per airspeed
*knot* (140, 152.4 and 170 m/s). The bank blends the two controllers on either side of the
measured airspeed: the gain scheduling of step 7, applied to whole controllers.

**Run** `TutorialVelocityMPC` and open **`FlightResponse`**.

**You should see** airspeed reach 160 m/s while altitude holds at 3000 m, and the weights
of the bank's members handing over as the airspeed crosses 152.4 m/s. The first run takes a
few minutes while the solvers compile.

### Step 9 — Schedule on airspeed and altitude

**The idea.** The aircraft also changes with altitude, so this bank has one MPC at each
point of a 3 × 3 airspeed × altitude grid. The grid comes from a lookup table,
`assets/envelope_trim_alpha.csv`: its rows are the airspeed knots, its columns the altitude
knots, and its values the trimmed angle of attack, which sets the pitch and angle-of-attack
references.

**Run** `TutorialEnvelope` (9a) and open **`Envelope`**.

**You should see** the trimmed angle of attack, thrust and elevator and the pitch divergence
rate over 140–250 m/s and 0–9000 m, from 10 000 trims and linearizations, with the bank's
nine nodes marked: the aircraft changes along both axes.

**Then run** `TutorialEnvelopeMPC` (9b) and open **`FlightResponse`**.

**You should see** airspeed reach 190 m/s and altitude 4500 m, and below them the airspeed
and altitude weights with which the bank blends its nine members.

**Try it.** To move the grid, edit the table's first column (airspeeds) or header row
(altitudes), then run `TutorialEnvelopeTable` (9c), which re-trims the aircraft at the new
nodes and rewrites the table.

The bank stays small on purpose: the MPC components grow with the number of controllers,
so a bank of 10 000 is not yet possible
([MPCComponents.jl#94](https://github.com/JuliaComputing/MPCComponents.jl/issues/94)).

## Presenting the workshop

The run of show below opens one result per step. The times are each analysis' run in one
Julia session on a laptop (Apple Silicon), in this order, after the packages were loaded;
the first analysis also builds the plant, so it takes longest. Run everything once before
the session (`julia --project=. scripts/save_artifacts.jl`) so that nothing compiles in
front of the audience.

| Step | Run | Time | Open | Point at |
|---|---|---|---|---|
| 1 | `TutorialTrim` | 56 s | `TrimTable` | α = 3.39°, thrust 10.8 kN, elevator −0.69° |
| 2 | `TutorialLinearize` | 19 s | `PoleZeroMap` | the pole at +0.095 rad/s: unstable in pitch |
| 3 | `TutorialDiscreteLQG` | 2 s | `StepResponse` | every channel settles |
| 4 | `TutorialDiscreteClosedLoop` | 34 s | `FlightResponse` | pitch back at trim within 10 s |
| 5 | `TutorialVisualizeDiscrete` | — | `Animation` | the same recovery in 3-D |
| 6 | `TutorialControllerCodegen` | 13 s | `StepCheck` | the C matches the design |
| 7a | `TutorialGainScheduleDesign` | 12 s | `LoopShapes` | scheduled loops cross over together; fixed ones spread |
| 7b | `TutorialGainScheduledPID` | 15 s | `FlightResponse` | design-point weights hand over at 9 s |
| 8 | `TutorialVelocityMPC` | 26 s | `FlightResponse` | the bank members' weights |
| 9a | `TutorialEnvelope` | 3 s | `Envelope` | the aircraft changes along both axes |
| 9b | `TutorialEnvelopeMPC` | 23 s | `FlightResponse` | both references tracked |

Step 5 was not timed: it needs a display, and the timing machine had none. Rendering a
video takes noticeably longer than the other steps, so start it before talking about it.

Do not open these results of step 2, which `DyadControlSystems.LinearAnalysis` offers but
cannot build for this 4-input, 12-output plant: `RootLocusPlot` and `StepInfoPlot` stop
with an error, and `RGAPlot` does not return, which blocks the session until Julia is
restarted.


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
| `dyad/Tutorial/` | The nine steps |
| `dyad/Plant/` | `F16PlantModel`, the aircraft |
| `dyad/Trimming/` | The aircraft flown open loop at trim, and its pitch departure |
| `dyad/VectorBlocks/`, `dyad/Utils/` | Vector blocks, mux/demux and the pose bridge for the animations |
| `dyad/Tests/` | Check models for the step-7 controller and schedule and the step-8 bank, run by the tests |
| `dyad/*.dyad`, `src/` | The analyses the steps extend: trim, flight response, gain-schedule design, controller export, C code, visualization and envelope; and the design code of steps 7–9 |
| `assets/` | The saved trim and controllers, the step-9 lookup table, icons and the airframe mesh |
| `scripts/` | `save_artifacts.jl`, which saves the figures and tables of analyses as files; and the aerodynamic fit of the plant |
| `generated/`, `generated_c/` | Code generated by Dyad (step-6 C code in `generated_c/`); do not edit |
| `gui/` | Optional tuning dashboard for step 3 |
| `test/` | Checks the aircraft against the book and every closed loop |

## For maintainers

Several dependencies are pinned to commits (`[sources]` in `Project.toml`), because the
versions the workshop needs are not registered yet. `test/lqg_design.jl` reruns the step-2
linearization and the step-3 LQG designs against the controllers in `assets/`, so a change
to any of these pins that alters the designs fails the tests.

- **MPCComponents** 0.2 and its **LinearMPCRuntime** are pinned to a commit of `main`. They
  need **LinearMPC** 0.11 and **DAQPBase** 0.6, which are pinned to the
  [baggepinnen/LinearMPC.jl](https://github.com/baggepinnen/LinearMPC.jl) and
  [baggepinnen/daqp](https://github.com/baggepinnen/daqp) branches MPCComponents is tested
  with, together with **DAQP_jll**.
- **DiscreteComponents** is pinned to a commit of `main` for `DiscretePIDScheduled`
  ([DiscreteComponents#148](https://github.com/JuliaComputing/DiscreteComponents/pull/148)),
  which no release has yet. 0.5 defines its sampler and hold blocks in native Dyad, so
  `MultiSampler` and `MultiZeroOrderHold` can become `y = sample(u)` and `y = hold(u)` on
  whole vectors.
- **DyadControlSystems** and **DAQP** are forks whose only change is a compat bound:
  [`rv/linearmpc-0.11`](https://github.com/JuliaComputing/DyadControlSystems.jl/tree/rv/linearmpc-0.11)
  allows LinearMPC 0.11, and
  [`shobhitvoleti/DAQP.jl` `daqpbase-0.6`](https://github.com/shobhitvoleti/DAQP.jl/tree/daqpbase-0.6)
  allows DAQPBase 0.6. Without them DyadControlSystems, which steps 2 and 3 use, cannot be
  installed next to LinearMPC 0.11. Drop each fork once its upstream releases the bound.
- Native two-variable scheduling is proposed in
  [MPCComponents.jl#95](https://github.com/JuliaComputing/MPCComponents.jl/pull/95). Once it
  is merged, step 9 can use `LinearMPCScheduler2D` instead of two schedulers and
  `OuterProduct`.
