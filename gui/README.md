# F16 LQG Controller Designer GUI

Interactive GUI for designing LQG controllers for the F16 aircraft using the shared plugin architecture.

## Quick Start

### Option 1: Launch F16 GUI Directly
```bash
cd /path/to/F16ModelWorkshop
julia gui/launch_gui.jl
```

### Option 2: Use Simple Interface
```julia
using DyadControlSystems
include("gui/lqg_app.jl")

spec = LQGAnalysisSpec(
    name = :MyLQG,
    model = my_model,
    measurement = ["y1", "y2"],
    controlled_output = ["y1", "y2"],  # Required: which outputs to control
    control_input = ["u1"],
    q1_diag = [1.0, 1.0],
    q2_diag = [0.1],
    r1_diag = [0.01],
    r2_diag = [0.01, 0.01]
)

state = launch_lqg_designer(spec)
```

### Option 3: From F16ModelWorkshop
```julia
using F16ModelWorkshop, DyadControlSystems
include("gui/lqg_app.jl")

# Use F16 default spec
spec = F16ModelWorkshop.F16LQGControllerAnalysisSpec()

# Convert to base spec
base_spec = DyadControlSystems.LQGAnalysisSpec(
    name = spec.name,
    model = spec.model,
    measurement = spec.measurement,
    controlled_output = spec.controlled_output,
    control_input = spec.control_input,
    disturbance_inputs = spec.disturbance_inputs,
    loop_openings = spec.loop_openings,
    t = spec.t,
    q1_diag = spec.q1_diag,
    q2_diag = spec.q2_diag,
    r1_diag = spec.r1_diag,
    r2_diag = spec.r2_diag,
    qQ = spec.qQ,
    qR = spec.qR,
    disc = spec.disc,
    Ts = spec.Ts,
    integrator_indices = spec.integrator_indices,
    integrator_r1_diag = spec.integrator_r1_diag,
    wl = spec.wl,
    wu = spec.wu,
    num_frequencies = spec.num_frequencies,
    duration = spec.duration,
)

state = DyadControlSystems.launch_lqg_designer(base_spec)
```

## Architecture

### Plugin System (`shared_app_utils.jl`)

The GUI uses a proper plugin architecture:

- **AbstractControlAppPlugin**: Base type for all plugins
- **Plugin Discovery**: Automatic detection of available plugins
- **MIMO Support**: All plugins handle multi-input multi-output systems with singular values

### Available Plugins

1. **GangOfFourPlugin** - Sensitivity functions (S, T, PS, CS)
2. **ControllerBodePlugin** - Controller frequency response
3. **NyquistPlugin** - Nyquist plot (SISO loops only)
4. **LoopTransferPlugin** - Loop transfer singular values  
5. **StepResponsePlugin** - Time-domain step response
6. **PZMapPlugin** - Pole-zero map of closed loop

### Files

- `shared_app_utils.jl` - Plugin infrastructure (1100+ lines)
- `lqg_app.jl` - LQG designer using plugins
- `launch_gui.jl` - F16 launcher script

## GUI Features

**Left Panel - Interactive Controls:**
- **LQR Weights (Q1, Q2)**: Logarithmic sliders (1e-6 to 1e6) for output and input penalties
- **Kalman Variances (R1, R2)**: Logarithmic sliders for process and measurement noise covariance
- **Visualization Toggles**: Enable/disable any plugin visualization
- **Computed Gains**: Real-time display of Kalman gain (L) and LQR gain (K)

**Right Panel - Real-Time Visualizations:**
- Plots update automatically when parameters change
- Dynamic layout based on enabled plugins
- Ms/Mt constraint lines for robustness margins (on GangOfFour and Nyquist)
- MIMO systems show all singular values

## F16 Model

- 12 states: npos, epos, alt, phi, theta, psi, vt, alpha, beta, P, Q, R
- 5 controls: uT, uEl, uAil, uRud, uLef

## Technical Details

- Uses GLMakie observables for reactive updates
- `smart_update` functions avoid unnecessary redraws
- Plugin `supports_args()` for conditional availability (e.g., Nyquist only for SISO)
- Frequency responses via ControlSystemsBase: `gangoffour`, `sigma`, `poles`, `tzeros`

## Working with Results

After launching the GUI, the state object provides access to all results:

```julia
# Launch GUI
state = DyadControlSystems.launch_lqg_designer(spec)

# Access solution after design converges
sol = state.sol[]

# Extract gains
K = sol.K  # LQR feedback gain matrix
L = sol.L  # Kalman filter gain matrix

# Extract systems
Psys = sol.P          # Plant system
Cfb = sol.Cfb         # Feedback controller
P_ext = sol.P_ext     # Extended plant with analysis points

# Access observables for custom plots
state.q1_diag[]       # Current Q1 weights
state.Ms[]            # Ms constraint value (default 1.5)
state.trigger[] += 1  # Force re-analysis
```

## Modifying Parameters Programmatically

```julia
# Adjust Q1 weight for altitude (index 3)
q1_vec = copy(state.q1_diag[])
q1_vec[3] = 200.0  # Increase altitude tracking weight
state.q1_diag[] = q1_vec
state.trigger[] += 1  # Trigger re-design

# Change robustness constraints
state.Ms[] = 2.0  # Relaxed sensitivity constraint
state.Mt[] = 2.0  # Relaxed complementary sensitivity

# Toggle visualizations
state.plugin_enabled[:Nyquist][] = false  # Hide Nyquist
state.plugin_enabled[:PZMap][] = true     # Show pole-zero map
rebuild_plots!(state)
```

## Plugin Architecture Details

All plugins in `shared_app_utils.jl` inherit from `AbstractControlAppPlugin` and are automatically discovered.

### Plugin Lifecycle

1. **Discovery**: `available_plugins()` finds all concrete plugin types
2. **Initialization**: `init_plugin_state(PluginType, ny, nu; kwargs...)` creates observables
3. **Visual Creation**: `create_plugin_visuals!(parent, row, PluginType, state; kwargs...)` builds plots
4. **Updates**: `update_plugin!(state, ...)` computes new data and updates observables
5. **Reactive Rendering**: GLMakie observables trigger automatic plot updates

### Plugin Update Signatures

Different plugins expect different arguments:

```julia
# Frequency-domain plugins
update_plugin!(state::GangOfFourPluginState, P, Cfb, w; kwargs...)
update_plugin!(state::ControllerBodePluginState, P, Cfb, w; kwargs...)
update_plugin!(state::NyquistPluginState, P, Cfb, w; kwargs...)
update_plugin!(state::LoopTransferPluginState, P, Cfb, w; kwargs...)

# Time-domain plugin
update_plugin!(state::StepResponsePluginState, t, y, u; kwargs...)

# Closed-loop analysis
update_plugin!(state::PZMapPluginState, closed_loop_system; kwargs...)
```

### Extending with Custom Plugins

To add a new plugin to `shared_app_utils.jl`:

1. Define plugin type: `struct MyPlugin <: AbstractControlAppPlugin end`
2. Define state type: `mutable struct MyPluginState ... end`
3. Implement interface methods:
   - `supports_args(::Type{MyPlugin}, P, Cfb; kwargs...)` - When is this plugin available?
   - `plugin_title(::Type{MyPlugin})` - Display name
   - `plugin_name(::Type{MyPlugin})` - Symbol identifier
   - `grid_size(::Type{MyPlugin})` - Layout size (rows, cols)
   - `init_plugin_state(::Type{MyPlugin}, ny, nu; kwargs...)` - Create observables
   - `create_plugin_visuals!(parent, row, ::Type{MyPlugin}, state; kwargs...)` - Build GLMakie plots
   - `update_plugin!(state::MyPluginState, ...)` - Compute and update data
4. Plugin will be automatically discovered and available in all apps (lqg_app, pid_autotuning_app, etc.)

## Troubleshooting

**GUI doesn't launch:**
- Check that `shared_app_utils.jl` is in the same directory as `lqg_app.jl`
- Ensure DyadControlSystems is properly installed
- Verify GLMakie can display windows

**Analysis fails:**
- Check model has proper analysis points defined
- Verify measurement/control_input names match model
- Ensure q1_diag/q2_diag/r1_diag/r2_diag dimensions match system size

**Plots don't update:**
- Check observable values are changing: `state.q1_diag[]`
- Manually trigger: `state.trigger[] += 1`
- Verify plugin is enabled: `state.plugin_enabled[:GangOfFour][]`

**Performance issues:**
- Reduce `num_frequencies` (default: 3000)
- Disable heavy plugins like StepResponse for large MIMO systems
- Use shorter time vectors for step response
