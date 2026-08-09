# F16 Trimming

## What is Trimming?

Trimming an aircraft means finding the control inputs (thrust, elevator) and flight attitude (angle of attack α, pitch angle θ) such that the aircraft flies in steady equilibrium — all accelerations zero, constant speed, constant altitude.

For straight-and-level symmetric flight, four equilibrium conditions determine four unknowns:

| Condition | Physical meaning | Determines |
|-----------|-----------------|------------|
| d(Vt)/dt = 0 | Constant airspeed | Thrust T |
| d(α)/dt = 0 | Constant angle of attack | α / δe coupling |
| d(alt)/dt = 0 | Level flight | Couples θ and α |
| d(Q)/dt = 0 | No pitch acceleration | Elevator δe |

## Approach: `missing` Parameters + `stop = 0.0`

The trim component `TrimDemo` (in `dyad/Tutorial/01_trim.dyad`) reuses the simulation plant `F16PlantModel` (vector I/O), with the five scalar control commands routed through a `Mux5` into the plant's `u_in[1:5]`. The key idea:

1. **`Constant(k = missing)`** on the thrust and elevator commands — `missing` drops the default value, promoting `k` to an unknown in the initialization system.
2. **`alpha_init = missing, theta_init = missing`** on `F16PlantModel` — the `initial alpha = alpha_init` / `initial theta = theta_init` equations remain, but the parameters are now free.
3. **`TransientAnalysis(stop = 0.0)`** — zero-duration simulation, so only the initialization solver runs.
4. **4 equilibrium constraints** as `initial der(...)` equations provide the equations that pin down the 4 unknowns.

```dyad
test component TrimDemo
  # alpha_init and theta_init are missing — they become decision variables
  f16plant = F16ModelWorkshop.Plant.F16PlantModel(
    alt_init = 3000.0, vt_init = 152.4,
    alpha_init = missing, theta_init = missing)
  # k = missing makes the thrust/elevator commands unknowns for the solver
  T_cmd   = BlockComponents.Sources.Constant(k = missing)
  el_cmd  = BlockComponents.Sources.Constant(k = missing)
  ail_cmd = BlockComponents.Sources.Constant(k = 0.0)
  rud_cmd = BlockComponents.Sources.Constant(k = 0.0)
  lef_cmd = BlockComponents.Sources.Constant(k = 0.0)
  mux = F16ModelWorkshop.Utils.Mux5()
relations
  connect(T_cmd.y,   mux.u1)
  connect(el_cmd.y,  mux.u2)
  connect(ail_cmd.y, mux.u3)
  connect(rud_cmd.y, mux.u4)
  connect(lef_cmd.y, mux.u5)
  connect(mux.y, f16plant.u_in)

  # Equilibrium constraints — all time derivatives zero at t = 0
  initial der(f16plant.vt)    = 0.0
  initial der(f16plant.alpha) = 0.0
  initial der(f16plant.alt)   = 0.0
  initial der(f16plant.Q)     = 0.0

  # Guesses for the 4 decision variables
  guess T_cmd.k = 11000.0
  guess el_cmd.k = -0.7
  guess f16plant.alpha_init = 0.06
  guess f16plant.theta_init = 0.06
end

analysis TutorialTrim
  extends TransientAnalysis(stop = 0.0)
  model = TrimDemo()
end
```

### Equation balance

- 12 differential states → 12 `initial x = x_init` equations from `F16PlantModel`
- 4 `initial der(...)` equilibrium constraints → 4 more equations
- **Total: 16 initialization equations**
- 12 state unknowns + 4 `missing` parameters (`T_cmd.k`, `el_cmd.k`, `alpha_init`, `theta_init`) → **16 unknowns**
- **Balanced.**

### Result (h = 3000 m, V = 152.4 m/s)

```
  α  =   3.3879°
  θ  =   3.3879°
  T  =  10794.89 N   (2427 lbf)
  δe =  -0.6949°     (degrees — F16PlantModel control-surface units)
```

The elevator comes out in **degrees** directly, matching the units expected by `F16PlantModel` and all closed-loop models. No unit conversion is needed.

### Validation against the book

The plant's coefficients condense the Stevens & Lewis F-16 tables (`scripts/fit_snl_aero.jl`), so the trim can be checked against published numbers. Trimming at the book's nominal condition — 502 ft/s at sea level, `xcg = 0.35c̄` — reproduces Table 3.6-3:

| | this model | S&L Table 3.6-3 |
|---|---|---|
| α | 0.03714 rad | 0.03691 rad |
| δe | −0.790° | −0.7588° |

`test/f16_snl_validation.jl` enforces both.

### The trim is an unstable equilibrium

At the reference CG the F-16 is statically unstable in pitch (`Cma = +0.082/rad`). The trim solve is unaffected — an equilibrium is an equilibrium whether or not it is attracting — but the longitudinal modes at that point are

```
  -1.438,  +0.0915,  -0.129 ± 0.106j
```

The positive real root is an exponential pitch divergence doubling roughly every 7.6 s. `Trimming.F16OpenLoopDeparture` starts 1° nose-up of trim with the controls frozen and shows it; setting `plant.xcg = 0.30` moves the CG forward of the aerodynamic reference and the same perturbation decays instead.

## Running the Trim

```julia
using F16ModelWorkshop

# Dyad-native trim (zero-duration transient = initialization solve)
result = F16ModelWorkshop.Tutorial.TutorialTrim()

# Extract values
using DyadInterface: symbolic_container
sol   = result.sol
model = symbolic_container(result)
α  = sol(0.0, idxs = model.f16plant.alpha)
T  = sol(0.0, idxs = model.f16plant.T)
δe = sol(0.0, idxs = model.f16plant.el)   # degrees
```

## Exporting and Reusing the Trim Point

`TrimPlantAnalysis` (defined in `src/trim_plant_analysis.jl`) is a custom analysis that solves `TrimDemo` and writes the operating point to `trim/trim_point.toml`, keyed by the instance paths of `F16TrimmedPlantLinked` (`T_cmd.k`, …, `plant.alpha_init`):

```julia
using F16ModelWorkshop
res  = F16ModelWorkshop.TrimPlantAnalysis()  # writes trim/trim_point.toml
path = F16ModelWorkshop.artifacts(res, :TrimToml)   # path to the written TOML
pset = F16ModelWorkshop.artifacts(res, :TrimPoint)  # parameter set as a nested Dict
```

`F16TrimmedPlantLinked` (in `dyad/Trimming/f16_trimmed_plant_linked.dyad`) then loads each value at build time via `F16ModelWorkshop.load_trim("trim/trim_point.toml", "<instance>.<param>")`, so `F16TrimmedPlantLinkedAnalysis` holds the states steady at the trim. Re-running `TrimPlantAnalysis` and rebuilding picks up the new operating point automatically.

## The Multiple-Equilibria Problem

The trim equations involve `sin(θ)`, `cos(θ)`, `sin(α)`, `cos(α)`. Because these are periodic, the nonlinear system has infinitely many mathematical solutions. The initialization solver may converge to a non-physical one if guesses are poor.

Examples of non-physical solutions the solver can find:

- θ ≈ 18.85 rad (≈ 6π) — mathematically equivalent to the physical θ via 2π periodicity, but the raw value is nonsensical.
- A completely different force-balance branch at extreme angle of attack and massive thrust.

Both satisfy the equilibrium equations exactly. The solver has no notion of physical plausibility.

**Mitigation:** provide guess values near the expected physical solution. `TrimDemo` seeds the four decision variables (`T_cmd.k`, `el_cmd.k`, `alpha_init`, `theta_init`). MTK resolves the remaining intermediate algebraic variables (trig functions, aero coefficients, etc.) by substitution from the pinned states and these guesses.

## Components

| Component | File | Role |
|-----------|------|------|
| `TrimDemo` | `dyad/Tutorial/01_trim.dyad` | Trim component (missing-Constant approach) |
| `TutorialTrim` | `dyad/Tutorial/01_trim.dyad` | Zero-duration analysis for trim |
| `TrimPlantAnalysis` | `src/trim_plant_analysis.jl` | Solves the trim and exports `trim/trim_point.toml` |
| `F16TrimmedPlantLinked` | `dyad/Trimming/f16_trimmed_plant_linked.dyad` | Plant scenario that loads the exported trim point |
| `F16PlantModel` | `dyad/Plant/f16_plant_model.dyad` | Simulation plant with vector I/O |
| `F16OpenLoopDeparture` | `dyad/Trimming/scenario_open_loop_departure.dyad` | Same trim, controls frozen — shows the pitch divergence |
| `ClosedLoopModel` | `dyad/Controls/lqg_design.dyad` | LQG closed-loop (uses trim values) |
| `F16OpenLoop` | `dyad/Controls/scenario1_open_loop.dyad` | Open-loop with trim inputs |
| `F16ClosedLoopPerturbed` | `dyad/Controls/scenario1_closed_loop.dyad` | Perturbed closed-loop |
