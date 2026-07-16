# Step 0 — Bring the F-16 Plant to the Stevens & Lewis Baseline

Companion to [CSTAR_CONTROLLER_PLAN.md](CSTAR_CONTROLLER_PLAN.md).

**Scope rule: one authority.** Everything in Step 0 is sourced from a single
reference — Stevens, Lewis & Johnson, *Aircraft Control and Simulation*
(the F-16 model of Chapter 3 and its appendix, hereafter **S&L**), which is
itself a documented subset of NASA TP-1538. If a feature is not in the S&L
F-16 model, it is out of scope for Step 0 — no mixing in BMS notes, Morelli
polynomials, or TP-1538 extras. That gives us a baseline that is complete,
internally consistent, and — most importantly — **checkable against the
book's published trim and linearization tables.**

## 1. What the S&L baseline model is

- **13 states**: the current 12 rigid-body states **plus engine power** `pow`.
- **4 control inputs**: throttle `thtl ∈ [0,1]`, elevator, aileron, rudder
  (degrees). **No leading-edge flap** — LEF is a TP-1538 feature that S&L
  deliberately omit.
- **Atmosphere**: the `adc` routine — density and Mach from altitude and
  airspeed (temperature-based, valid through the stratosphere).
- **Propulsion**: `tgear` (throttle → commanded power), `pdot` (first-order
  power lag with regime-dependent time constants), `thrust` (idle/mil/max
  tables in altitude × Mach, interpolated by power level).
- **Aerodynamics**: table lookups in α (−10°…45°) and β — `CX(α, δe)`,
  `CZ(α, β, δe)`, `Cm(α, δe)`, `CY(β, δa, δr)`, `Cl(α, β)`, `Cn(α, β)`,
  control-derivative tables `DLDA, DLDR, DNDA, DNDR(α, β)`, damping
  derivatives `damp(α)` (9 coefficients), **and the CG moment corrections**
  `Cm_tot = Cm + CZ·(xcgr − xcg)`, `Cn_tot = Cn − CY·(xcgr − xcg)·c̄/b`.
- **Actuators & sensors** (from the book's FLCS design chapter): first-order
  20.2 rad/s elevator servo, ±25° position / 60°/s rate limits; normal
  accelerometer output `an`; these are part of the book's F-16 control
  examples and belong to the baseline.
- **Validation data**: the book publishes trim tables at several CG locations
  (e.g. at V_T = 502 ft/s, xcg = 0.35c̄: `thtl ≈ 0.1385`, `δe ≈ −0.7588°`,
  `α ≈ 0.03691 rad`) and linearized model matrices/eigenvalues. These become
  our acceptance tests.

## 2. Gap audit: current plant vs. S&L baseline

Current plant: [`dyad/Plant/f16_plant_model.dyad`](dyad/Plant/f16_plant_model.dyad)
(+ scalar-port twin [`f16_plant_io.dyad`](dyad/Plant/f16_plant_io.dyad)).
The mass properties are already the S&L airframe in SI (m = 9295.44 kg ≙
636 slug, S = 27.87 m² ≙ 300 ft², b = 9.144 m ≙ 30 ft, c̄ = 3.45 m ≙ 11.32 ft,
and the S&L inertias), so the repo is already "S&L converted to SI" — the
gaps are in the subsystem models:

| Subsystem | Current | S&L baseline | Gap |
|---|---|---|---|
| Rigid body | 12-state 6-DOF, correct structure (incl. `Jxz` coupling, `Heng` term) | Same | ✅ None — keep as-is |
| Lateral modes | Present (β, φ, ψ, P, R + lateral derivatives) | Same structure, table aero | Fidelity only |
| Aero | Constant single-point derivative matrices; **`xcg`/`xcgr` declared but CG corrections missing** | Full α/β tables + damping + CG corrections | Replace |
| Atmosphere | Density-only ISA troposphere; no Mach | `adc`: ρ, Mach | Replace |
| Propulsion | Instantaneous thrust force in Newtons | `pow` state + `tgear`/`pdot`/`thrust` tables, throttle input | Add (13th state, input change) |
| Controls | 5 inputs incl. **LEF, which is inert** (`lef_rad` computed at [line 154](dyad/Plant/f16_plant_model.dyad#L154), never used) | 4 inputs, no LEF | **Drop LEF channel** |
| Actuators | None (commands go straight to aero) | 20.2 rad/s servo, ±25°, 60°/s (elevator; analogous for ail/rud) | Add |
| Sensor outputs | 12 states only; no n_z | `an` (normal accel), Mach, q̄ | Add |

Decision to make once, up front: **unit system.** The repo is SI; the book is
English units (ft, slug, lbf). Recommendation: stay SI (repo convention,
already converted mass properties), encode the S&L tables with their native
breakpoints and convert at the interfaces, and validate against book numbers
converted to SI. Document every conversion in one place.

## 3. Work plan

Ordering: encode the data package and the checks first, then swap subsystems
inside-out, re-trimming after each phase. Every phase's acceptance test is a
comparison against S&L published numbers.

### Phase 0.1 — Encode the S&L data package (single source of truth)

**Status: aero package DONE (2026-07-15).** Instead of hand-transcription, the
tables are machine-extracted from NASA's DAVE-ML encoding
([`assets/F16_aero.dml`](assets/F16_aero.dml), Bruce Jackson, NASA LaRC — the
Garza/Morelli encoding of the S&L model) by
[`scripts/parse_f16_dml.py`](scripts/parse_f16_dml.py), which generates:

- [`src/f16_aero_data.jl`](src/f16_aero_data.jl) — 4 breakpoint sets + all 18
  aero tables (`F16AeroData` module, provenance header, loaded before the
  generated Dyad code);
- [`test/f16_aero_checkcases.jl`](test/f16_aero_checkcases.jl) — the 17 NASA
  verification cases embedded in the DML (tol 1e-6).

[`src/f16_aero.jl`](src/f16_aero.jl) implements the clamped-linear
interpolation and the coefficient buildup (transcribed from the DML MathML,
including the CG moment-transfer corrections), and
[`test/f16_aero_test.jl`](test/f16_aero_test.jl) verifies all 17 checkcases ×
6 coefficients plus the table-variant delta below. Wired into
`src/F16ModelWorkshop.jl` and `test/runtests.jl`.

**Data-lineage finding (audited against `assets/SnLtext.pdf`, Appendix A):**
CX, CZ, Cm, Cn0 match the book exactly; the DML's Cl0(|β|, α) table differs
from the book in exactly 18 cells (α = 15/20/25°, |β| ≥ 5°) because the DML
encodes Morelli's 1995 Matlab adaptation of the 1992 first edition.
Resolution per the single-authority scope: `F16AeroData.CL0_ABS` carries the
book values (the baseline), `F16AeroData.CL0_ABS_DML` preserves the Morelli
variant so the NASA checkcases remain exactly reproducible; a testset pins
the delta to those 18 audited cells. Damping and lateral-control tables are
validated via the checkcases (book-side PDF extraction of those blocks is
OCR-unreliable).

Still open in 0.1: transcribe the book's **trim cases and linearization
results** as fixtures (needed by Phase 0.2/0.8), and the **engine tables**
(needed by Phase 0.5).

### Phase 0.2 — Verification harness (before touching physics)

- Script in `scripts/` that trims and linearizes the plant and classifies
  modes (short period, phugoid, Dutch roll, roll subsidence, spiral); wire it
  into the Dyad test harness.
- Run it on the **current** plant and record the snapshot, so every later
  phase shows exactly what changed.
- Acceptance: harness runs headlessly; current-model modes documented.

### Phase 0.3 — Atmosphere: implement `adc`

- New `dyad/Environment/atmosphere.dyad` reproducing S&L `adc`: temperature
  model, ρ, Mach = V_T/a, q̄.
- Acceptance: ρ and Mach match `adc` outputs at the book's test altitudes;
  current trim reproduced within tolerance (density-formula equivalence).

### Phase 0.4 — Aerodynamics: S&L tables + CG corrections

The big one. Replace `C0_lon/Cmat_lon/C0_lat/Cmat_lat` with the S&L table
functions:

- Interpolation in Dyad: the S&L tables are coarse (α every 5°, β every 5°)
  and the reference implementation uses the book's specific linear
  interpolation with clamping — reproduce that exactly rather than a
  higher-order scheme, so numbers are comparable. (Implementation route:
  Dyad external/interpolation functions per `agent_resources/docs/data.md`;
  fallback is calling a registered Julia function.)
- Include all of: `CX, CZ, Cm, CY, Cl, Cn`, `DLDA/DLDR/DNDA/DNDR`, `damp(α)`
  q̂/p̂/r̂ damping terms, and the **CG moment-transfer corrections** using the
  existing `xcgr`/`xcg` parameters (finally making them live).
- Keep aero in its own component with a coefficient-output interface; the
  rigid-body equations don't change.
- Acceptance: coefficient outputs match the book's example evaluations; trim
  δe/α at the reference condition move to the S&L values.

### Phase 0.5 — Propulsion: `tgear` / `pdot` / `thrust`

- Add `pow` as the 13th state; plant input becomes throttle ∈ [0,1].
- Implement the regime-dependent power lag (`pdot`/`rtau`) and the
  idle/mil/max thrust tables in (alt, Mach), interpolated by power —
  exactly as in the book (the lag logic has conditionals; Dyad `if`
  expressions or a registered function).
- Acceptance: thrust at sea-level static mil power matches the table; trim
  now yields `thtl ≈ 0.1385` at the book's reference condition (SI-converted).

### Phase 0.6 — Drop the LEF channel; add actuators

- Remove the inert 5th input from both plant variants and downstream loops
  (LQG weight rationale in `closed_loop.dyad` updates from 5 to 4 controls).
  If keeping diagram compatibility matters, deprecate rather than delete the
  old wrapper.
- One reusable `ServoActuator` component (first-order + position/rate
  saturation), instantiated per surface with the book's values (elevator
  20.2 rad/s, ±25°, 60°/s; aileron/rudder with their S&L limits), packaged as
  an `F16Airframe` wrapper: `[thtl, el_cmd, ail_cmd, rdr_cmd] → plant`.
- Acceptance: actuator step responses show spec lag and limits; existing LQG
  scenarios re-run against the wrapper (retune if needed, documented).

### Phase 0.7 — Sensor outputs

- `an` normal accelerometer (per the book's output equations: at CG
  `an = −q̄·S·CZ_tot/(m·g)` plus pilot-station lever-arm term with parameter
  `x_a`), lateral accel, Mach, q̄ — on a dedicated output connector so the
  existing 12-channel `y_out` loops are untouched.
- Acceptance: `an` = 1 g in trimmed level flight; sign checks on an elevator
  step.

### Phase 0.8 — Re-trim, validate against the book, freeze

- Regenerate `trim/trim_point.toml` through the full stack.
- **The Step 0 exit criterion:** reproduce the S&L published results —
  (a) trim table across the CG cases (xcg = 0.30, 0.35, 0.38): throttle,
  elevator, α within table tolerance; (b) linearized longitudinal and
  lateral matrices/eigenvalues at the book's flight condition matching the
  published ones; (c) all five classical modes classified and matching.
- Migrate or pin the existing LQG continuous/discrete loops (note: controller
  dimensions change — 13 states, 4 inputs).
- Tag the commit as the baseline the C* plan builds on.

## 4. Explicitly out of scope (not in the S&L baseline)

- **Leading-edge flap** — TP-1538 extension; revisit only if high-α work
  needs it. (Step 0 *removes* the current inert LEF input.)
- The real F-16 FLCS gain schedules (BMS/TP-1538) — that's C*-plan Phase 7.
- Morelli polynomial aero — an alternative fit, not the S&L source; would
  break comparability with the book's tables.
- Wind/turbulence, fuel burn/CG travel, high-α beyond the table range,
  flexible modes, gear/ground effects.

## 5. Dependency graph

```
0.1 data package ─> everything
0.2 harness ─> gates every later phase
0.3 adc ─> 0.4 aero (q̄, Mach) ─> 0.5 engine (Mach) ─> 0.8 validate/freeze
0.6 LEF-drop + actuators ─> 0.8       (after 0.4 so retrim is done once)
0.7 sensors ─> 0.8; needed by C* Phase 1
```

Execution order: **0.1 → 0.2 → 0.3 → 0.4 → 0.5 → 0.6 → 0.7 → 0.8**.

## 6. Reference

- Stevens, B. L., Lewis, F. L., Johnson, E. N., *Aircraft Control and
  Simulation*, 3rd ed., Wiley — Chapter 3 F-16 model (`adc`, `tgear`, `pdot`,
  `thrust`, aero tables, trim/linearization tables) and the FLCS design
  chapter (actuator and accelerometer models).
  ([2nd ed. scan](https://www.scribd.com/doc/156011399/B-L-stevens-26-F-L-lewis-Aircraft-Control-and-Simulation-1992))
- Underlying data source (for provenance only, not scope): Nguyen et al.,
  NASA TP-1538 (1979).
