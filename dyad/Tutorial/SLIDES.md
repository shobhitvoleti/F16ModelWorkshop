---
marp: true
theme: default
paginate: true
title: F16 Control Design in Dyad
description: From a 6-DOF plant to a sampled-data LQG controller
---

<!--
Slide fodder for HTML generation (Marp/reveal.js).
Slides are separated by `---`. Speaker prose lives in HTML comments.
Diagram placeholders (`![](img/...)`) expect screenshots exported from Dyad Studio
of the five Tutorial models — capture them at your preferred zoom before rendering.
-->

# F16 Control Design in Dyad

### From a 6-DOF plant to a sampled-data LQG controller

A five-step workshop: **trim → linearize → design → implement → visualize**

`dyad/Tutorial/` · run every step in Dyad Studio or the REPL

---

## What we'll build

1. **Trim** — find the steady flight condition
2. **Linearize** — get the state-space model design is built on
3. **LQG (continuous)** — synthesize a stabilizing regulator
4. **Discrete closed loop** — run it as a 100 Hz sampled-data controller
5. **Visualize** — fly the result as a 3-D animation

<!-- One model per step; each is one .dyad file with one runnable analysis. -->

Each step is **one `.dyad` file, one analysis**, building on the last.

---

## The plant

**`F16PlantModel`** — nonlinear 6-DOF rigid-body F16 with matrix aerodynamics.

- **12 states:** `npos, epos, alt, phi, theta, psi, vt, alpha, beta, P, Q, R`
- **5 controls:** `T (thrust), el, ail, rud, lef`
- **Vector I/O:** `u_in :: Real[5]`, `y_out :: Real[12]`

Operating point for the whole tutorial: **3000 m, 152.4 m/s**.

![w:520](img/f16_plant.png)

---

## Step 1 — Trim

**Trim = the steady flight condition:** controls + states that hold every motion derivative at zero.

Technique — let the initializer solve it:

- Mark the unknowns **`missing`** (thrust, elevator, `alpha`, `theta`)
- Impose equilibrium: `initial der(vt)=0`, `der(alpha)=0`, `der(alt)=0`, `der(Q)=0`
- `guess` values only seed Newton — they don't bias the answer

```
TutorialTrim()            # solve (zero-duration TransientAnalysis)
TutorialTrimExport()      # solve + write trim/tutorial_trim_point.toml
```

---

## Step 1 — Result

The solver returns the operating point:

| control | value | state | value |
|---|---|---|---|
| `T` | 28 696 N | `alpha` | −0.0170 rad |
| `el` | 2.63° | `theta` | −0.0170 rad |
| `ail/rud/lef` | 0 | `vt` | 152.4 m/s |

<!-- Downstream steps load this operating point at build time via load_trim. -->

Everything downstream loads this point from TOML — retrim once, the whole workshop follows.

---

## Step 2 — Linearize

Design is built on the **linear** plant about trim.

`TutorialLinearize` (`DyadControlSystems.LinearAnalysis`):

- **inputs:** the 4 effective control points `uT, uEl, uAil, uRud` (LEF is unmodeled — excluded)
- **outputs:** the 12 measured analysis points `yn..yR`
- **loop openings:** break the feedback → the bare **open-loop plant P**

```
TutorialLinearize()        # poles, zeros, Bode, step
TutorialLinearizeExport()  # + write A/B/C/D to TOML
```

![w:560](img/linear_bode.png)

---

## Concept — Analysis points

An **analysis point** names a signal edge so an analysis can inject/measure/break there:

```
u: analysis_point(controller.y, plant.u)
```

Used for **linearization, sensitivity, loop-opening, LQG design**.

**Key rule (the workshop's core lesson):**

> `LQGAnalysis` / `LinearAnalysis` count **each analysis-point name as ONE channel** — a vector AP is *1* channel, not *N*.

So control-design models must place **scalar** analysis points — one per channel.

---

## Step 3 — LQG (continuous)

Regulator: `u = -L·x̂`, estimator from a Kalman filter — synthesized from cost/noise weights.

The design model `LQGDemo`:

- plant + embedded controller + `ref − measurement` error
- **design analysis points**: 5 controls (`uT, uEl, uAil, uRud, uLef`) + 12 measurements (`yn..yR`); LEF has no aero effect, so synthesis returns a zero gain row for it
- weights capture intent (below)

```
TutorialLQG()   # linearize between the APs, synthesize the gains
```

---

## Step 3 — Vector wiring, scalar taps

Analysis points must be scalar — but per-channel blocks make spaghetti.
**Wire with vectors; tap to scalars only at the analysis points.**

```
measurements:  plant.y_out → Demux4x3 → 4× Demux3 ─[yn..yR]─ 4× Mux3 → Mux4x3 → err
controls:      controller  → Demux5   ─(+trim)──── [uT..uLef] ──────→ Mux5   → plant.u_in
```

- Vector everywhere except the 17 scalar tap points
- 2-stage demux/mux groups the 12 states: **position / attitude / airspeed / rates**

![w:640](img/lqg_model.png)

---

## Step 3 — LQG weights (Bryson's rule)

Don't hand-pick magnitudes. State a **largest acceptable deviation** per channel and
let the weight be `1 / deviation²`:

| output | tolerance | weight | control | tolerance | weight |
|---|---|---|---|---|---|
| `alt` | 0.5 m | 4.0 | thrust | 20 000 N | 2.5e-9 |
| `theta` | 5° | 131 | elevator | 10° | 0.01 |
| `vt` | 1 m/s | 1.0 | aileron | 10° | 0.01 |
| `alpha`,`beta` | 2° | 821 | rudder | 10° | 0.01 |
| `Q` | 10°/s | 32.8 | | | |

**Why it matters here:** thrust is in *newtons*, the surfaces in *degrees*. A uniform
penalty makes thrust ~10⁶× too expensive and the synthesis returns a controller with
**no usable throttle** — nothing holds airspeed.

---

## Step 3 — What you cannot regulate

`npos` and `epos` carry only a placeholder weight (the solver rejects zero).

> Steady level flight is an equilibrium for `alt, theta, vt, alpha, beta, P, Q, R` —
> each has a value you can hold. It is **not** one for position: the aircraft must
> keep flying forward.

Penalize position against a fixed reference and the error grows with distance flown
until it dominates the cost — the regulator tries to fly *back*, and departs.

**Position belongs to an outer guidance loop, not the inner regulator.**

<!-- Measured: with position weighted at 0.1 the loop departs at ~19 s, commanding
     2814 deg of elevator. With Bryson weights and position released, roll stays
     under 0.007 rad and every surface sits far inside its travel limit. -->

---

## Step 4 — Discrete closed loop

The same loop as a **100 Hz sampled-data** system — the real implementation.

- Continuous LQG → **ZOH-discretized** at `Ts = 0.01 s` (single source of truth)
- Controller = clocked `DiscreteStateSpace`, trim folded into its output `y0`
- **Sampler → discrete controller → zero-order hold**, all vector connectors
- One 100 Hz clock planted on `controller.u`, propagated by **clock inference**

```
TutorialDiscreteClosedLoop()   # 10° pitch perturbation, recovers to trim
```

---

## Step 4 — The clean model

No analysis points here — it's a **simulation**, so it stays fully vector:

```
ref − measurement → err → sample(100 Hz) → controller → zoh → plant
```

Vector `VectorConstant`, `VectorAdd`, `MultiSampler`, `MultiZeroOrderHold`, `VectorClock`
→ 7 blocks, one wire per stage.

![w:600](img/discrete_loop.png)

---

## Step 5 — Visualize

Watch the recovery instead of reading it off a plot.

Each viz model **`extends` its closed loop** and adds three blocks — nothing in the
control path changes:

```
f16plant.y_out → Demux4x3 → Demux3 → Mux3 → SignalPoseSource → ShapefileVisualizer
```

- The `Demux3`/`Mux3` pair reorders NED → Y-up: `npos→x, alt→y, epos→z`
- `SignalPoseSource` turns those signals into a `Frame3D` pose
- Same 10° perturbation on both loops, so continuous vs sampled is a fair race

```
TutorialVisualizeContinuous()   # → assets/f16_continuous_closed_loop.mp4
TutorialVisualizeDiscrete()     # → assets/f16_discrete_closed_loop.mp4
```

---

## Step 5 — The analysis writes the video

`VisualizeAnalysis` is a **custom analysis**, like the trim/linearize exporters:
it simulates the model, then renders the solution to a file.

- Camera, `stop`, and output path are **analysis parameters**, not script arguments
- `controller_name` seeds the clocked controller, so the sampled loop renders too
- Rendering needs a Makie backend — `using GLMakie` — and says so if it's missing

<!-- The visualizer is a model component; the renderer is an analysis. That split is
     why the same loop can be simulated headless or filmed without editing it. -->

The visualizer lives in the **model**; the renderer lives in the **analysis**.

---

## The through-line

**Vector connectors** for wiring and simulation — clean, one wire per bus.
**Scalar analysis points** for control design — one name per channel.

| Need | Use |
|---|---|
| Simulate / route signals | vector connectors (Step 4) |
| Linearize / design (LQG) | scalar APs, tapped via demux/mux (Steps 2–3) |

The demux/mux tap is how you get **both**: vector wiring *and* scalar design points.

---

## Bonus — analyses that write files

Trim & linearization export their results as **first-class Dyad analyses**
(`partial analysis` + a Julia `run_analysis`), the same pattern as `LQGAnalysis`:

```
TutorialTrimExport()          → trim/tutorial_trim_point.toml
TutorialLinearizeExport()     → trim/tutorial_linear_model.toml
TutorialVisualizeDiscrete()   → assets/f16_discrete_closed_loop.mp4
```

A custom analysis's `run_analysis` can do anything Julia can — including write a file.

---

## Run it yourself

```julia
using Pkg; Pkg.instantiate()
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots   # analyses live in the Tutorial submodule

plot(TutorialDiscreteClosedLoop())   # sampled-data pitch recovery
TutorialLQG()                        # synthesize the controller
TutorialTrimExport()                 # → trim/tutorial_trim_point.toml
TutorialLinearizeExport()            # → trim/tutorial_linear_model.toml

using GLMakie                        # rendering needs a Makie backend
TutorialVisualizeDiscrete()          # → assets/f16_discrete_closed_loop.mp4
```

Open `dyad/Tutorial/01…05` in **Dyad Studio** to see each model and run its analysis.

---

# Recap

1. **Trim** — `missing` + equilibrium constraints
2. **Linearize** — open-loop plant about trim
3. **LQG** — scalar APs, vector wiring, weights = intent
4. **Discrete** — ZOH controller, sampled-data, clock inference
5. **Visualize** — `extends` the loop, renders from an analysis

**One idea to keep:** wire with vectors, design at scalar analysis points.
