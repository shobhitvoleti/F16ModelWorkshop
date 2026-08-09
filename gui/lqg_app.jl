#=
Interactive GLMakie app for LQG controller design.

Usage:
    using DyadControlSystems
    spec = LQGAnalysisSpec(...)
    state = launch_lqg_designer(spec)
=#

using DyadControlSystems
using DyadControlSystems: LQGAnalysisSpec, LQGAnalysisSolution, run_analysis, system_mapping, named_ss
using ControlSystemsBase
using ControlSystemsBase: feedback, gangoffour, sigma, poles, tzeros, step
using GLMakie
using GLMakie: Observable, Figure, Axis, GridLayout, Label, Slider, Button, Toggle, Textbox
using GLMakie: on, @lift, display, notify, rowsize!, colgap!, Fixed, contents, delete!

# Load shared plugin infrastructure
include(joinpath(@__DIR__, "shared_app_utils.jl"))

# ============================================================================
# State Container
# ============================================================================

mutable struct LQGDesignerState
    fig::Figure
    original_spec::LQGAnalysisSpec
    
    # Parameter observables
    disc::Observable{String}
    qQ::Observable{Float64}
    qR::Observable{Float64}
    t::Observable{Float64}
    Ts::Observable{Float64}
    wl::Observable{Float64}
    wu::Observable{Float64}
    num_frequencies::Observable{Int}
    duration::Observable{Float64}
    
    # Vector parameters
    q1_diag::Observable{Vector{Float64}}
    q2_diag::Observable{Vector{Float64}}
    r1_diag::Observable{Vector{Float64}}
    r2_diag::Observable{Vector{Float64}}
    integrator_indices::Observable{Vector{Int}}
    integrator_r1_diag::Observable{Vector{Float64}}
    
    # Results
    sol::Observable{Union{Nothing, LQGAnalysisSolution}}
    
    # Robustness constraints (shared with plugins)
    Ms::Observable{Float64}
    Mt::Observable{Float64}
    
    # Plugin management
    plugin_states::Dict{Symbol, Any}
    plugin_enabled::Dict{Symbol, Observable{Bool}}
    right_panel::Union{Nothing, GridLayout}
    
    # Status and trigger
    status::Observable{String}
    trigger::Observable{Int}
    
    # Result displays
    L_display::Observable{String}
    K_display::Observable{String}
end

# ============================================================================
# Spec Builder
# ============================================================================

function build_spec(state::LQGDesignerState)
    orig = state.original_spec
    LQGAnalysisSpec(
        name = orig.name,
        model = orig.model,
        measurement = orig.measurement,
        controlled_output = orig.controlled_output,
        control_input = orig.control_input,
        disturbance_inputs = orig.disturbance_inputs,
        loop_openings = orig.loop_openings,
        t = state.t[],
        q1_diag = state.q1_diag[],
        q2_diag = state.q2_diag[],
        r1_diag = state.r1_diag[],
        r2_diag = state.r2_diag[],
        qQ = state.qQ[],
        qR = state.qR[],
        disc = state.disc[],
        Ts = state.Ts[],
        integrator_indices = state.integrator_indices[],
        integrator_r1_diag = state.integrator_r1_diag[],
        wl = state.wl[],
        wu = state.wu[],
        num_frequencies = state.num_frequencies[],
        duration = state.duration[],
    )
end

# ============================================================================
# Analysis Runner
# ============================================================================

function run_lqg!(state::LQGDesignerState)
    try
        state.status[] = "Designing..."
        
        spec = build_spec(state)
        sol = run_analysis(spec)
        state.sol[] = sol
        
        # Update result displays
        if !isnothing(sol)
            L = sol.L
            K = sol.K
            state.L_display[] = "L: " * join([string(round(l, digits=3)) for l in vec(L[1:min(5, length(L))])], ", ") * (length(L) > 5 ? "..." : "")
            state.K_display[] = "K: " * join([string(round(k, digits=3)) for k in vec(K[1:min(5, length(K))])], ", ") * (length(K) > 5 ? "..." : "")
        end
        
        # Update plots
        update_all_plots!(state)
        
        state.status[] = "Done!"
        
    catch e
        state.status[] = "Error: $(sprint(showerror, e))"
        @error "LQG design failed" exception=(e, catch_backtrace())
    end
end

# ============================================================================
# Plot Update Functions
# ============================================================================

function update_all_plots!(state::LQGDesignerState)
    sol = state.sol[]
    isnothing(sol) && return
    
    # Extract plant and controller
    Psys = named_ss(system_mapping(sol.P_ext),
                    u=Symbol.(state.original_spec.control_input),
                    y=Symbol.(state.original_spec.measurement))
    Cfb = sol.Cfb
    
    # Frequency vector for plots
    nfreq = 200
    wl = state.wl[] > 0 ? state.wl[] : sol.w[1]
    wu = state.wu[] > 0 ? state.wu[] : sol.w[end]
    plot_w = exp10.(LinRange(log10(wl), log10(wu), nfreq))
    
    # Update each enabled plugin
    ny = length(state.original_spec.measurement)
    nu = length(state.original_spec.control_input)
    
    for (pname, plugin_state) in state.plugin_states
        if state.plugin_enabled[pname][]
            # Different update signatures for different plugins
            if pname == :PZMap
                T_cl = feedback(Psys * Cfb)
                update_plugin!(plugin_state, T_cl)
            elseif pname == :StepResponse
                # Step response needs time-domain data
                T_cl = feedback(Psys * Cfb)
                duration = state.duration[] > 0 ? state.duration[] : 10.0
                Ts_sim = ControlSystemsBase.isdiscrete(T_cl) ? T_cl.Ts : 0.01
                tv = 0:Ts_sim:duration
                step_res = step(T_cl, tv)
                G_ur = feedback(Cfb, Psys)
                control_res = step(G_ur, tv)
                # Extract time, output, and control arrays from SimResult
                update_plugin!(plugin_state, step_res.t, step_res.y, control_res.y)
            else
                # Standard frequency-domain plugins (GangOfFour, ControllerBode, Nyquist, LoopTransfer)
                update_plugin!(plugin_state, Psys, Cfb, plot_w; ny=ny, nu=nu)
            end
        end
    end
end

# ============================================================================
# Dynamic Plot Rebuild
# ============================================================================

function rebuild_plots!(state::LQGDesignerState)
    right_panel = state.right_panel
    isnothing(right_panel) && return
    
    # Delete legends stored on plugin states before clearing axes
    for (_, pstate) in state.plugin_states
        if hasproperty(pstate, :legends)
            for l in pstate.legends
                delete!(l)
            end
            empty!(pstate.legends)
        end
    end

    # Clear remaining layout content (axes, etc.)
    for c in copy(contents(right_panel))
        delete!(c)
    end
    
    # Get available plugins
    ny = length(state.original_spec.measurement)
    nu = length(state.original_spec.control_input)
    all_plugins = available_plugins()
    
    # Rebuild enabled plugins, packing single-column plugins side-by-side
    row = 1
    single_col_pending = false  # true when col=1 of current row has a single-col plugin
    for PluginType in all_plugins
        pname = plugin_name(PluginType)

        if haskey(state.plugin_enabled, pname) && state.plugin_enabled[pname][]
            plugin_state = state.plugin_states[pname]
            grid_rows, grid_cols = grid_size(PluginType)

            if pname == :GangOfFour
                # Full-width 2-column plugin
                if single_col_pending
                    row += 1
                    single_col_pending = false
                end
                create_plugin_visuals!(right_panel, row, PluginType, plugin_state; show_constraints=true)
                row += grid_rows
            elseif pname == :StepResponse
                # Full-width 2-column plugin
                if single_col_pending
                    row += 1
                    single_col_pending = false
                end
                create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=1)
                row += grid_rows
            elseif pname == :PZMap
                # Full-width 2-column plugin
                if single_col_pending
                    row += 1
                    single_col_pending = false
                end
                create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=1)
                row += grid_rows
            else
                # Single-column plugins: pack two per row
                if single_col_pending
                    # Place in col=2 of current row
                    if pname == :Nyquist
                        create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=2, show_constraints=true)
                    else
                        create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=2)
                    end
                    row += 1
                    single_col_pending = false
                else
                    # Place in col=1 of new row
                    if pname == :Nyquist
                        create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=1, show_constraints=true)
                    else
                        create_plugin_visuals!(right_panel, row, PluginType, plugin_state; col=1)
                    end
                    single_col_pending = true
                end
            end
        end
    end
    # If an odd single-col plugin is left, advance the row
    if single_col_pending
        row += 1
    end
end

# ============================================================================
# Main Entry Point
# ============================================================================

"""
    launch_lqg_designer(spec::LQGAnalysisSpec)

Launch an interactive GUI for LQG controller design.

# Arguments
- `spec`: An LQGAnalysisSpec with the model and initial parameters.

# Returns
- `LQGDesignerState`: Contains the designed solution and all GUI state.

# Example
```julia
using DyadControlSystems
spec = LQGAnalysisSpec(
    name = :MyLQG,
    model = my_model,
    measurement = ["y"],
    controlled_output = ["y"],
    control_input = ["u"],
    q1_diag = [1.0],
    q2_diag = [0.1],
    r1_diag = [0.01],
    r2_diag = [0.1]
)
state = launch_lqg_designer(spec)
```
"""
function launch_lqg_designer(spec::LQGAnalysisSpec)
    
    fig = Figure(size=(1400, 850))
    
    # Shared robustness constraints
    Ms = Observable(1.5)
    Mt = Observable(1.5)
    
    # Initialize plugin states for all available plugins
    ny = length(spec.measurement)
    nu = length(spec.control_input)
    all_plugins = available_plugins()
    
    plugin_states = Dict{Symbol, Any}()
    plugin_enabled = Dict{Symbol, Observable{Bool}}()
    
    for PluginType in all_plugins
        pname = plugin_name(PluginType)
        
        # Initialize state with shared Ms/Mt if supported
        if pname == :GangOfFour
            plugin_states[pname] = init_plugin_state(PluginType, ny, nu; Ms=Ms, Mt=Mt)
            plugin_enabled[pname] = Observable(true)  # Default: show Gang of Four
        elseif pname == :Nyquist
            # Only enable if SISO
            is_siso = (ny == 1 || nu == 1)
            plugin_states[pname] = init_plugin_state(PluginType, ny, nu; Ms=Ms, Mt=Mt)
            plugin_enabled[pname] = Observable(is_siso)
        elseif pname == :StepResponse
            plugin_states[pname] = init_plugin_state(PluginType, ny, nu;
                y_names=spec.measurement, u_names=spec.control_input)
            plugin_enabled[pname] = Observable(true)
        else
            plugin_states[pname] = init_plugin_state(PluginType, ny, nu)
            plugin_enabled[pname] = Observable(false)  # Off by default, user toggles on
        end
    end
    
    # Initialize state
    state = LQGDesignerState(
        fig,
        spec,
        Observable(spec.disc),
        Observable(spec.qQ),
        Observable(spec.qR),
        Observable(spec.t),
        Observable(spec.Ts),
        Observable(Float64(spec.wl)),
        Observable(Float64(spec.wu)),
        Observable(spec.num_frequencies),
        Observable(spec.duration),
        Observable(copy(spec.q1_diag)),
        Observable(copy(spec.q2_diag)),
        Observable(copy(spec.r1_diag)),
        Observable(copy(spec.r2_diag)),
        Observable(copy(spec.integrator_indices)),
        Observable(copy(spec.integrator_r1_diag)),
        Observable{Union{Nothing, LQGAnalysisSolution}}(nothing),
        Ms,
        Mt,
        plugin_states,
        plugin_enabled,
        nothing,  # right_panel (set below)
        Observable("Ready - adjust parameters"),
        Observable(0),
        Observable("L: (not computed)"),
        Observable("K: (not computed)"),
    )
    
    # === LEFT PANEL: Controls ===
    left_panel = fig[1, 1] = GridLayout()
    colsize!(fig.layout, 1, Fixed(280))
    left_row = 1
    
    # --- LQR WEIGHTS SECTION ---
    Label(left_panel[left_row, 1:4], "LQR WEIGHTS", fontsize=13, font=:bold)
    left_row += 1
    
    log_range = exp10.(LinRange(-6, 6, 100))
    for (i, q1_val) in enumerate(spec.q1_diag)
        Label(left_panel[left_row, 1], "Q1[$i]:", halign=:right)
        q1_slider = Slider(left_panel[left_row, 2:3], range=log_range, startvalue=q1_val)
        Label(left_panel[left_row, 4], @lift(string(round($(q1_slider.value), sigdigits=3))))
        let idx = i
            on(q1_slider.value) do v
                q1_vec = copy(state.q1_diag[])
                q1_vec[idx] = v
                state.q1_diag[] = q1_vec
                state.trigger[] += 1
            end
        end
        left_row += 1
    end
    
    for (i, q2_val) in enumerate(spec.q2_diag)
        Label(left_panel[left_row, 1], "Q2[$i]:", halign=:right)
        q2_slider = Slider(left_panel[left_row, 2:3], range=log_range, startvalue=q2_val)
        Label(left_panel[left_row, 4], @lift(string(round($(q2_slider.value), sigdigits=3))))
        let idx = i
            on(q2_slider.value) do v
                q2_vec = copy(state.q2_diag[])
                q2_vec[idx] = v
                state.q2_diag[] = q2_vec
                state.trigger[] += 1
            end
        end
        left_row += 1
    end
    
    # --- KALMAN VARIANCE SECTION ---
    Label(left_panel[left_row, 1:4], "KALMAN VARIANCE", fontsize=13, font=:bold)
    left_row += 1
    
    for (i, r1_val) in enumerate(spec.r1_diag)
        Label(left_panel[left_row, 1], "R1[$i]:", halign=:right)
        r1_slider = Slider(left_panel[left_row, 2:3], range=log_range, startvalue=r1_val)
        Label(left_panel[left_row, 4], @lift(string(round($(r1_slider.value), sigdigits=3))))
        let idx = i
            on(r1_slider.value) do v
                r1_vec = copy(state.r1_diag[])
                r1_vec[idx] = v
                state.r1_diag[] = r1_vec
                state.trigger[] += 1
            end
        end
        left_row += 1
    end
    
    for (i, r2_val) in enumerate(spec.r2_diag)
        Label(left_panel[left_row, 1], "R2[$i]:", halign=:right)
        r2_slider = Slider(left_panel[left_row, 2:3], range=log_range, startvalue=r2_val)
        Label(left_panel[left_row, 4], @lift(string(round($(r2_slider.value), sigdigits=3))))
        let idx = i
            on(r2_slider.value) do v
                r2_vec = copy(state.r2_diag[])
                r2_vec[idx] = v
                state.r2_diag[] = r2_vec
                state.trigger[] += 1
            end
        end
        left_row += 1
    end
    
    # --- VISUALIZATIONS SECTION ---
    Label(left_panel[left_row, 1:4], "VISUALIZATIONS", fontsize=13, font=:bold)
    left_row += 1
    
    for PluginType in all_plugins
        pname = plugin_name(PluginType)
        ptitle = plugin_title(PluginType)
        
        toggle = Toggle(left_panel[left_row, 1], active=state.plugin_enabled[pname][])
        Label(left_panel[left_row, 2:4], ptitle)
        on(toggle.active) do v
            state.plugin_enabled[pname][] = v
            rebuild_plots!(state)
            update_all_plots!(state)
        end
        left_row += 1
    end
    
    # --- RESULTS SECTION ---
    Label(left_panel[left_row, 1:4], "COMPUTED GAINS", fontsize=13, font=:bold)
    left_row += 1
    
    Label(left_panel[left_row, 1:4], state.L_display, fontsize=11)
    left_row += 1
    
    Label(left_panel[left_row, 1:4], state.K_display, fontsize=11)
    left_row += 1
    
    rowgap!(left_panel, 4)
    colgap!(left_panel, 6)

    # === RIGHT PANEL: Plots ===
    state.right_panel = fig[1, 2] = GridLayout()
    rebuild_plots!(state)
    
    # Status bar
    status_label = Label(fig[2, 1:2], state.status, fontsize=14)
    rowsize!(fig.layout, 2, Fixed(25))
    
    # === Reactive Updates ===
    on(state.trigger) do _
        run_lqg!(state)
    end
    
    # Initial run
    state.trigger[] += 1
    
    display(fig)
    return state
end
