# C* (C-star) Controller Plan for the F-16 Model

Plan for taking the current F-16 model in this repo to a C* longitudinal flight
control law, based on published reference implementations.

> **Prerequisite:** [STEP0_BASELINE_PLAN.md](STEP0_BASELINE_PLAN.md) — plant
> fidelity upgrades (spec aero, atmosphere, engine, actuators, control mixer,
> sensors) that must land before this plan's phases. Step 0 subsumes this
> plan's Phases 1–2 (nz output and actuators).

## Where the model is today

The repo has everything a C* design needs except the C*-specific signals and
loop structure:

- **Plant**: [`dyad/Plant/f16_plant_model.dyad`](dyad/Plant/f16_plant_model.dyad)
  is a 12-state, 6-DOF F-16 (Stevens & Lewis-style aero with matrix
  stability/control derivatives), vector I/O: 5 inputs `[T, el, ail, rud, lef]`,
  12 state outputs. There is also a scalar-port variant in
  [`dyad/Plant/f16_plant_io.dyad`](dyad/Plant/f16_plant_io.dyad).
- **Trim**: a working trim pipeline ([`dyad/Trimming/`](dyad/Trimming/),
  [`trim/trim_point.toml`](trim/trim_point.toml)) with trim values loaded via
  `F16ModelWorkshop.load_trim`.
- **Controllers**: a full-state continuous LQG loop
  ([`dyad/Controls/closed_loop.dyad`](dyad/Controls/closed_loop.dyad)) designed
  with `DyadControlSystems.LQGAnalysis` over named analysis points, and a
  100 Hz sampled-data variant
  ([`dyad/Controls/discrete_closed_loop.dyad`](dyad/Controls/discrete_closed_loop.dyad))
  with a clocked `DiscreteStateSpace` and `MultiSampler`/`MultiZeroOrderHold`
  vector blocks.

Two gaps matter for C*:

1. The plant **does not output normal acceleration (n_z)** — the one extra
   measurement C* requires.
2. There are **no actuator models** — the elevator command goes straight into
   the aero.

## Reference documents

The most directly usable document is **de Paula & Paglione, ["Longitudinal
Control Laws Based on C* Criterion" (COBEM 2007)](https://abcm.org.br/app/webroot/anais/cobem/2007/pdf/COBEM2007-1596.pdf)**.
It gives a complete, reproducible implementation:

- **C\* definition**: `C* = K_nz·n_zp + K_q·q` with the classic crossover ratio
  `K_q / K_nz = 12.4` (from crossover velocity 122 m/s; `n_zp` is normal
  acceleration at the pilot's station, `n_zp = V·γ̇/g + x_a·q̈/g`).
- **Architecture**: inner SAS pitch-rate loop (gain `K_q`), outer CAS with a
  **PI controller on the C\* error** plus pilot-station normal-acceleration
  feedback (`K_nz`), and a first-order elevator actuator (time constant 1/20 s,
  ±40° position / ±60°/s rate limits). Full closed-loop state-space equations
  are given (their Eq. 7).
- **Gain design method**: quadratic minimization (`fmincon`) of the area
  between the closed-loop C* step response and the normalized C* envelope
  (Field 1993 tracking/landing boundaries), then validation against
  MIL-F-8785C short-period/CAP requirements and the Gibson dropback criterion.

The paper's plant is a regional jet, but the control law is airframe-agnostic
and the C* concept is the basis of the F-16's own longitudinal FLCS — the real
F-16 law is a pitch-rate + normal-acceleration + AoA blend, documented in
[Stevens & Lewis, *Aircraft Control and Simulation*](https://www.scribd.com/doc/156011399/B-L-stevens-26-F-L-lewis-Aircraft-Control-and-Simulation-1992)
(also the source lineage of this repo's plant model) and in the very detailed
[F-16 FLCS developer's notes](https://www.falcon-bms.com/wp-content/uploads/2021/08/FM_Developers_Notes_Part_4.pdf),
which reproduce the actual longitudinal gain structure from NASA TP-1538. A
useful supporting document for pitch-axis design specifics on the F-16 is
[AFIT's "Pitch Rate Flight Control for the F-16" (DTIC ADA055417)](https://apps.dtic.mil/sti/tr/pdf/ADA055417.pdf).

## Path from here to a C* controller

### Phase 1 — Instrument the plant (new outputs, no dynamics changes)

Add `nz` as an output of `F16PlantModel`. Everything needed is already
computed: the z-body aerodynamic specific force is `qbar*S*C_lon[2]/m`, so

```
nz = -qbar*S*C_lon[2] / (m*g)          # at the CG, in g
```

with the pilot-station correction `+ x_a*der(Q)/g` as a parameter-controlled
term. Extend `y_out` (or add a dedicated `nz_out` port so existing 12-channel
loops stay untouched).

### Phase 2 — Actuator model

Add a first-order elevator actuator component (~20 rad/s bandwidth, ±25°
position and ±60°/s rate limits — F-16 values; the paper uses ±40° / 60°/s) in
`dyad/Controls/` or a new `dyad/Actuators/`. C* gain design is meaningless
without the actuator lag in the loop, since the PI gains trade against it.

### Phase 3 — C* control law in Dyad

New `dyad/Controls/cstar_closed_loop.dyad` following the `ClosedLoopModel`
pattern:

- C* blend block: `C* = nz + 12.4·q` (q in rad/s, nz in g).
- Pilot/reference input shaped as a C* command (a step block for testing;
  later a stick-gradient gain).
- PI on C* error → elevator, inner `K_q` rate loop, `K_nz` accel feedback —
  four scalar gains total (`K_p, K_i, K_q, K_nz`), declared as top-level
  parameters so the analysis can write them.
- Longitudinal only: hold thrust at trim (or keep a simple airspeed loop) and
  reuse the trim TOML for the operating point, exactly as the discrete loop
  does. Lateral-directional stays open (or keep simple roll/yaw dampers) —
  C* says nothing about those axes.

### Phase 4 — Gain design

Two workable routes, in order of preference:

1. **Mirror the paper**: linearize the longitudinal channel at trim via the
   existing analysis-point machinery, then run a small Julia script (in
   `scripts/`, like `render_f16_discrete_closed_loop.jl`) that optimizes the
   four gains against the Field C* envelope using
   `ControlSystems.jl`/`Optim.jl`.
2. **Classical loop-shaping**: place the short-period per MIL-F-8785C
   (ζ 0.35–1.3, CAP 0.28–3.6 for Category A) using the linearized model — good
   first cut, refined by route 1.

### Phase 5 — Validation scenarios

`Scenario` analyses parallel to `Scenario1ClosedLoop`:

- (a) the existing 10° pitch perturbation for regulation;
- (b) a unit C* step command checked against the tracking/landing envelopes;
- (c) CAP/damping extraction from the linearized closed loop.

Plot C*(t) normalized, as in the paper's Figures 3–4.

### Phase 6 — Discrete variant

Once the continuous C* loop is validated, reuse the whole 100 Hz sampled-data
path: the PI + static gains collapse into a tiny (2-state: integrator +
actuator-command filter) `DiscreteStateSpace`, driven through the existing
`VectorClock`/`MultiSampler`/`MultiZeroOrderHold` blocks. ZOH-discretize at
`ControllerTs` the same way `F16DiscreteLQGControllerAnalysis` does, keeping
one source of truth for the matrices.

### Phase 7 (stretch) — toward the real F-16 FLCS

Add the AoA limiter and dynamic-pressure gain scheduling from the
BMS / NASA TP-1538 block diagram. That turns the textbook C* law into a
faithful F-16 longitudinal FLCS, and the model is then good across the
envelope instead of at one trim point.

## First step

Phase 1 + 2 (nz output and actuator) — prerequisites for everything else, and
they don't disturb any existing loop.

## Sources

- [de Paula & Paglione, COBEM 2007 — Longitudinal Control Laws Based on C* Criterion](https://abcm.org.br/app/webroot/anais/cobem/2007/pdf/COBEM2007-1596.pdf)
- [Falcon BMS F-16 FLCS Developer's Notes](https://www.falcon-bms.com/wp-content/uploads/2021/08/FM_Developers_Notes_Part_4.pdf)
- [Stevens & Lewis, Aircraft Control and Simulation](https://www.scribd.com/doc/156011399/B-L-stevens-26-F-L-lewis-Aircraft-Control-and-Simulation-1992)
- [AFIT, Pitch Rate Flight Control for the F-16 (DTIC ADA055417)](https://apps.dtic.mil/sti/tr/pdf/ADA055417.pdf)
- [Combined Design of Gain-Scheduled C-Star and Maneuver Load Alleviation Laws (AIAA JGCD)](https://arc.aiaa.org/doi/10.2514/1.G009267)
