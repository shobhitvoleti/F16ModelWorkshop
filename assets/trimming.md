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

The trim component `F16TrimV3` (in `dyad/f16_trim_v3.dyad`) reuses the simulation plant `F16PlantIO` directly. The key idea:

1. **`Constant(k = missing)`** on the thrust and elevator inputs — `missing` drops the default value, promoting `k` to an unknown in the initialization system.
2. **`alpha_init = missing, theta_init = missing`** on `F16PlantIO` — the `initial alpha = alpha_init` equations remain, but `alpha_init` is now free.
3. **`TransientAnalysis(stop = 0.0)`** — zero-duration simulation, so only the initialization solver runs.
4. **4 equilibrium constraints** as `initial der(...)` equations provide the equations that pin down the 4 unknowns.

```dyad
test component F16TrimV3
  f16plant = F16PlantIO(
    alt_init = 3000.0, vt_init = 152.4,
    alpha_init = missing, theta_init = missing,
    beta_init = 0.0, phi_init = 0.0, psi_init = 0.0,
    P_init = 0.0, Q_init = 0.0, R_init = 0.0
  )
  T_cmd  = BlockComponents.Sources.Constant(k = missing)
  el_cmd = BlockComponents.Sources.Constant(k = missing)
  ail_cmd = BlockComponents.Sources.Constant(k = 0.0)
  rud_cmd = BlockComponents.Sources.Constant(k = 0.0)
  lef_cmd = BlockComponents.Sources.Constant(k = 0.0)
relations
  connect(T_cmd.y, f16plant.T_in)
  connect(el_cmd.y, f16plant.el_in)
  connect(ail_cmd.y, f16plant.ail_in)
  connect(rud_cmd.y, f16plant.rud_in)
  connect(lef_cmd.y, f16plant.lef_in)

  initial der(f16plant.vt) = 0.0
  initial der(f16plant.alpha) = 0.0
  initial der(f16plant.alt) = 0.0
  initial der(f16plant.Q) = 0.0

  # Guesses for the 4 decision variables (missing parameters)
  guess T_cmd.k = 30000.0
  guess el_cmd.k = 2.0
  guess f16plant.alpha_init = -0.02
  guess f16plant.theta_init = -0.02

  # Guesses for the 12 state variables
  guess f16plant.vt = 152.4
  guess f16plant.alpha = -0.02
  guess f16plant.beta = 0.0
  guess f16plant.phi = 0.0
  guess f16plant.theta = -0.02
  guess f16plant.psi = 0.0
  guess f16plant.P = 0.0
  guess f16plant.Q = 0.0
  guess f16plant.R = 0.0
  guess f16plant.npos = 0.0
  guess f16plant.epos = 0.0
  guess f16plant.alt = 3000.0
end

analysis F16TrimV3Analysis
  extends TransientAnalysis(stop = 0.0)
  model = F16TrimV3()
end
```

### Equation balance

- 12 differential states → 12 `initial x = x_init` equations from `F16PlantIO`
- 4 `initial der(...)` equilibrium constraints → 4 more equations
- **Total: 16 initialization equations**
- 12 state unknowns + 4 `missing` parameters (`T_cmd.k`, `el_cmd.k`, `alpha_init`, `theta_init`) → **16 unknowns**
- **Balanced.**

### Result (h = 3000 m, V = 152.4 m/s)

```
  α  =  -0.971166°
  θ  =  -0.971166°
  T  =  28696.23 N
  δe =   2.6305°     (degrees — F16PlantIO units)
```

The elevator comes out in **degrees** directly, matching the units expected by `F16PlantIO` and all closed-loop models. No unit conversion is needed.

## Running the Trim

```julia
using F16ModelWorkshop

# Dyad-native trim
result = F16TrimV3Analysis()

# Extract values
using DyadInterface: symbolic_container
sol   = result.sol
model = symbolic_container(result)
α  = sol(0.0, idxs = model.f16plant.alpha)
T  = sol(0.0, idxs = model.f16plant.T)
δe = sol(0.0, idxs = model.f16plant.el)   # degrees
```

For trim envelope sweeps across altitudes, the script `scripts/trim_f16.jl` provides a standalone `NonlinearSolve` + continuation approach:

```julia
include("scripts/trim_f16.jl")

# Single point
r = trim_f16(altitude = 5000.0, velocity = 180.0)
r.α_deg   # angle of attack in degrees
r.T       # thrust in Newtons
r.δe_deg  # elevator in degrees

# Sweep
envelope = trim_sweep(0.0:1000.0:12000.0; velocity = 200.0)
```

### Trim envelope (V = 152.4 m/s)

```
  Alt [m]  |  α [deg]  |  θ [deg]  |    T [N]   |  δe [deg]
  ---------------------------------------------------------------
        0  |  -2.0310  |  -2.0310  |  39232.05  |   3.6012
     1000  |  -1.7149  |  -1.7149  |  35328.70  |   3.2998
     2000  |  -1.3631  |  -1.3631  |  31819.61  |   2.9763
     3000  |  -0.9712  |  -0.9712  |  28696.23  |   2.6305
     5000  |  -0.0457  |  -0.0457  |  23580.28  |   1.8748
     7000  |   1.1118  |   1.1118  |  19945.26  |   1.0504
    10000  |   3.4292  |   3.4292  |  17266.97  |  -0.1973
```

Trends are as expected: thrust decreases with altitude (less drag at lower density), α increases (more incidence needed for the same lift).

## The Multiple-Equilibria Problem

The trim equations involve `sin(θ)`, `cos(θ)`, `sin(α)`, `cos(α)`. Because these are periodic, the nonlinear system has infinitely many mathematical solutions. The initialization solver may converge to a non-physical one if guesses are poor.

Examples of non-physical solutions the solver can find:

- θ ≈ 18.83 rad (≈ 6π) — mathematically equivalent to θ ≈ -0.97° via 2π periodicity, but the raw value is nonsensical.
- α ≈ -47°, T ≈ 110 kN — a completely different force-balance branch with extreme angle of attack and massive thrust.

Both satisfy the equilibrium equations exactly. The solver has no notion of physical plausibility.

**Mitigation:** provide guess values near the expected physical solution. The `F16TrimV3` component includes 16 guesses: 4 for the decision variables and 12 for the state variables. MTK resolves the intermediate algebraic variables (trig functions, aero coefficients, etc.) by substitution from these. For the NonlinearSolve approach, the `trim_sweep` function uses continuation (each solution seeds the next) to maintain convergence across the envelope.

## Components

| Component | File | Role |
|-----------|------|------|
| `F16TrimV3` | `dyad/f16_trim_v3.dyad` | Trim component (missing-Constant approach) |
| `F16TrimV3Analysis` | `dyad/f16_trim_v3.dyad` | Zero-duration analysis for trim |
| `F16PlantIO` | `dyad/f16_plant_io.dyad` | Simulation plant with I/O connectors |
| `ClosedLoopModel` | `dyad/closed_loop.dyad` | LQG closed-loop (uses trim values) |
| `F16OpenLoop` | `dyad/scenario1_open_loop.dyad` | Open-loop with trim inputs |
| `F16ClosedLoopPerturbed` | `dyad/scenario1_closed_loop.dyad` | Perturbed closed-loop |
