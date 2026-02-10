#=
Shared utilities for interactive GLMakie control system design apps.

This file provides a plugin architecture for common visualizations that can be
shared across pid_autotuning_app.jl, mixed_sensitivity_app.jl, and lqg_app.jl.

Usage:
    # In an app, discover supported plugins
    plugins = supported_plugins(P, Cfb)

    # Initialize plugin states
    for PluginType in plugins
        state = init_plugin_state(PluginType, ny, nu)
        # Store state...
    end

    # Create visuals
    axes = create_plugin_visuals!(parent, row, PluginType, state)

    # Update on data change
    update_plugin!(state, P, Cfb, w)
=#

using GLMakie
using GLMakie: Observable, Axis, GridLayout, rich, DataAspect, Point2f
using GLMakie: lines!, hlines!, vlines!, scatter!, tooltip!, @lift, xlims!, ylims!
using GLMakie: events, Mouse, mouseposition, on

function smart_update_nonotify(obs, val)
    if obs.val !== nothing && size(obs.val) == size(val)
        obs.val .= val
    else
        obs[] = val
    end
end

function smart_update(obs, val)
    if obs.val !== nothing && size(obs.val) == size(val)
        obs.val .= val
        notify(obs)
    else
        obs[] = val
    end
end


# ============================================================================
# Abstract Plugin Interface
# ============================================================================

"""
    AbstractControlAppPlugin

Base type for control app visualization plugins.

Each plugin must implement:
- `supports_args(::Type{<:Plugin}, P, Cfb; kwargs...) -> Bool`
- `plugin_title(::Type{<:Plugin}) -> String`
- `plugin_name(::Type{<:Plugin}) -> Symbol`
- `grid_size(::Type{<:Plugin}) -> Tuple{Int,Int}` - (rows, cols) needed
- `init_plugin_state(::Type{<:Plugin}, ny, nu; kwargs...) -> PluginState`
- `create_plugin_visuals!(parent, row, ::Type{<:Plugin}, state; kwargs...) -> Tuple of Axes`
- `update_plugin!(state, P, Cfb, w; kwargs...) -> nothing`
"""
abstract type AbstractControlAppPlugin end

# Default implementations (can be overridden)
supports_args(::Type{<:AbstractControlAppPlugin}, P, Cfb; kwargs...) = false
plugin_title(::Type{<:AbstractControlAppPlugin}) = "Unknown Plugin"
plugin_name(::Type{<:AbstractControlAppPlugin}) = :unknown
grid_size(::Type{<:AbstractControlAppPlugin}) = (1, 1)

# ============================================================================
# Plugin Discovery
# ============================================================================

"""
    available_plugins()

Return all concrete plugin types (subtypes of AbstractControlAppPlugin).
"""
function available_plugins()
    # Collect all concrete subtypes
    result = Type{<:AbstractControlAppPlugin}[]
    for T in subtypes(AbstractControlAppPlugin)
        if isconcretetype(T)
            push!(result, T)
        end
    end
    return result
end

"""
    supported_plugins(P, Cfb; kwargs...)

Return plugins that support the given plant P and controller Cfb.
"""
function supported_plugins(P, Cfb; kwargs...)
    filter(available_plugins()) do PluginType
        supports_args(PluginType, P, Cfb; kwargs...)
    end
end

# ============================================================================
# Gang of Four Plugin
# ============================================================================

"""
    GangOfFourPlugin <: AbstractControlAppPlugin

Plugin for Gang of Four sensitivity plots: σ(S), σ(T), σ(PS), σ(CS).

Displays two axes:
1. S and T (sensitivity and complementary sensitivity)
2. PS and CS (disturbance rejection and controller effort)

Supports MIMO systems by plotting all singular values.
"""
struct GangOfFourPlugin <: AbstractControlAppPlugin end

"""
    GangOfFourPluginState

State container for Gang of Four plugin observables and axes.
"""
mutable struct GangOfFourPluginState
    # Axes (set during create_plugin_visuals!)
    st_ax::Union{Nothing, Axis}
    pscs_ax::Union{Nothing, Axis}

    # Frequency vector (shared)
    w::Observable{Vector{Float64}}

    # Singular value observables (one per singular value for MIMO support)
    S_sigmas::Vector{Observable{Vector{Float64}}}
    T_sigmas::Vector{Observable{Vector{Float64}}}
    PS_sigmas::Vector{Observable{Vector{Float64}}}
    CS_sigmas::Vector{Observable{Vector{Float64}}}

    # Optional constraint lines
    Ms::Observable{Float64}
    Mt::Observable{Float64}
    Mks::Observable{Float64}  # Max noise sensitivity (CS = KS)
end

# Gang of Four is always supported for any P, Cfb pair
supports_args(::Type{GangOfFourPlugin}, P, Cfb; kwargs...) = true

plugin_title(::Type{GangOfFourPlugin}) = "Gang of Four (S, T, PS, CS)"
plugin_name(::Type{GangOfFourPlugin}) = :GangOfFour
grid_size(::Type{GangOfFourPlugin}) = (1, 2)

"""
    init_plugin_state(::Type{GangOfFourPlugin}, ny::Int, nu::Int; Ms=nothing, Mt=nothing, Mks=nothing, kwargs...)

Initialize observable state for Gang of Four plugin.

# Arguments
- `ny`: Number of plant outputs (determines number of S/T singular values)
- `nu`: Number of plant inputs (with ny, determines PS/CS singular values)

# Keyword Arguments
- `Ms`: Optional existing Observable{Float64} for max sensitivity constraint
- `Mt`: Optional existing Observable{Float64} for max complementary sensitivity constraint
- `Mks`: Optional existing Observable{Float64} for max noise sensitivity (CS = KS) constraint
"""
function init_plugin_state(::Type{GangOfFourPlugin}, ny::Int, nu::Int;
                           Ms::Union{Nothing, Observable{Float64}}=nothing,
                           Mt::Union{Nothing, Observable{Float64}}=nothing,
                           Mks::Union{Nothing, Observable{Float64}}=nothing,
                           kwargs...)
    nsv_st = ny  # S and T are ny × ny
    nsv_pscs = min(ny, nu)  # PS and CS are rectangular

    # Use provided observables or create new ones
    ms_obs = isnothing(Ms) ? Observable(1.5) : Ms
    mt_obs = isnothing(Mt) ? Observable(1.5) : Mt
    mks_obs = isnothing(Mks) ? Observable(Inf) : Mks

    GangOfFourPluginState(
        nothing,  # st_ax
        nothing,  # pscs_ax
        Observable(Float64[1.0]),  # w (placeholder)
        [Observable(Float64[1.0]) for _ in 1:nsv_st],   # S_sigmas
        [Observable(Float64[1.0]) for _ in 1:nsv_st],   # T_sigmas
        [Observable(Float64[1.0]) for _ in 1:nsv_pscs], # PS_sigmas
        [Observable(Float64[1.0]) for _ in 1:nsv_pscs], # CS_sigmas
        ms_obs,   # Ms (provided or default)
        mt_obs,   # Mt (provided or default)
        mks_obs,  # Mks (provided or default Inf = no constraint)
    )
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{GangOfFourPlugin}, state::GangOfFourPluginState;
                           show_constraints=false)

Create axes and plot elements for Gang of Four visualization.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `show_constraints`: If true, add dashed lines for Ms/Mt constraints

# Returns
Tuple (st_ax, pscs_ax) of created axes.
"""
function create_plugin_visuals!(parent, row::Int, ::Type{GangOfFourPlugin}, state::GangOfFourPluginState;
                                 show_constraints::Bool=false)
    # Create S/T axis with colored title
    st_ax = Axis(parent[row, 1],
        title = rich("σ(", rich("S", color=:blue), ") and σ(", rich("T", color=:red), ")"),
        xlabel = "Frequency (rad/s)",
        ylabel = "Singular value",
        xscale = log10,
        yscale = log10,
        tellheight = false,
    )
    state.st_ax = st_ax

    # Create PS/CS axis with colored title
    pscs_ax = Axis(parent[row, 2],
        title = rich("σ(", rich("PS", color=:blue), ") and σ(", rich("CS", color=:red), ")"),
        xlabel = "Frequency (rad/s)",
        ylabel = "Singular value",
        xscale = log10,
        yscale = log10,
        tellheight = false,
    )
    state.pscs_ax = pscs_ax

    # Plot S singular values (blue)
    for s_obs in state.S_sigmas
        lines!(st_ax, state.w, s_obs, color=:blue)
    end

    # Plot T singular values (red)
    for t_obs in state.T_sigmas
        lines!(st_ax, state.w, t_obs, color=:red)
    end

    # Plot PS singular values (blue)
    for ps_obs in state.PS_sigmas
        lines!(pscs_ax, state.w, ps_obs, color=:blue)
    end

    # Plot CS singular values (red)
    for cs_obs in state.CS_sigmas
        lines!(pscs_ax, state.w, cs_obs, color=:red)
    end

    # Unity reference line
    hlines!(st_ax, [1.0], color=:gray, linestyle=:dash, linewidth=0.5)

    # Optional Ms/Mt/Mks constraint lines
    if show_constraints
        hlines!(st_ax, state.Ms, color=:blue, linestyle=:dash, linewidth=1)
        hlines!(st_ax, state.Mt, color=:red, linestyle=:dash, linewidth=1)
        # Mks constraint on CS (noise sensitivity) - only if finite
        hlines!(pscs_ax, state.Mks, color=:red, linestyle=:dash, linewidth=1)
    end

    return (st_ax, pscs_ax)
end

"""
    update_plugin!(state::GangOfFourPluginState, P, Cfb, w; kwargs...)

Update Gang of Four plugin observables with new frequency response data.

# Arguments
- `state`: Plugin state to update
- `P`: Plant system (StateSpace or similar)
- `Cfb`: Feedback controller (StateSpace or similar)
- `w`: Frequency vector (rad/s)
"""
@views function update_plugin!(state::GangOfFourPluginState, P, Cfb, w; kwargs...)
    # Compute Gang of Four transfer functions
    S, PS, CS, T = gangoffour(P, Cfb; minimal=true)

    # Update frequency vector
    smart_update_nonotify(state.w, w)

    # S singular values
    sig_S, _ = sigma(S, w)
    for i in 1:min(size(sig_S, 1), length(state.S_sigmas))
        smart_update(state.S_sigmas[i], sig_S[i, :])
    end

    # T singular values
    sig_T, _ = sigma(T, w)
    for i in 1:min(size(sig_T, 1), length(state.T_sigmas))
        smart_update(state.T_sigmas[i], sig_T[i, :])
    end

    # PS singular values
    sig_PS, _ = sigma(PS, w)
    for i in 1:min(size(sig_PS, 1), length(state.PS_sigmas))
        smart_update(state.PS_sigmas[i], sig_PS[i, :])
    end

    # CS singular values
    sig_CS, _ = sigma(CS, w)
    for i in 1:min(size(sig_CS, 1), length(state.CS_sigmas))
        smart_update(state.CS_sigmas[i], sig_CS[i, :])
    end
end

# ============================================================================
# Controller Bode Plugin
# ============================================================================

"""
    ControllerBodePlugin <: AbstractControlAppPlugin

Plugin for controller Bode magnitude plot: σ(K).

Displays one axis showing the controller frequency response magnitude.
Supports MIMO systems by plotting all singular values.
"""
struct ControllerBodePlugin <: AbstractControlAppPlugin end

"""
    ControllerBodePluginState

State container for Controller Bode plugin observables and axes.
"""
mutable struct ControllerBodePluginState
    # Axis (set during create_plugin_visuals!)
    ax::Union{Nothing, Axis}

    # Frequency vector
    w::Observable{Vector{Float64}}

    # Singular value observables (one per singular value for MIMO support)
    K_sigmas::Vector{Observable{Vector{Float64}}}
end

# Controller Bode is always supported for any P, Cfb pair
supports_args(::Type{ControllerBodePlugin}, P, Cfb; kwargs...) = true

plugin_title(::Type{ControllerBodePlugin}) = "Controller Bode |K|"
plugin_name(::Type{ControllerBodePlugin}) = :ControllerBode
grid_size(::Type{ControllerBodePlugin}) = (1, 1)

"""
    init_plugin_state(::Type{ControllerBodePlugin}, ny::Int, nu::Int; kwargs...)

Initialize observable state for Controller Bode plugin.

# Arguments
- `ny`: Number of plant outputs (controller inputs)
- `nu`: Number of plant inputs (controller outputs)
"""
function init_plugin_state(::Type{ControllerBodePlugin}, ny::Int, nu::Int; kwargs...)
    nsv = min(ny, nu)  # Controller is nu × ny, so min(nu, ny) singular values

    ControllerBodePluginState(
        nothing,  # ax
        Observable(Float64[1.0]),  # w (placeholder)
        [Observable(Float64[1.0]) for _ in 1:nsv],  # K_sigmas
    )
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{ControllerBodePlugin}, state::ControllerBodePluginState;
                           col::Int=1)

Create axes and plot elements for Controller Bode visualization.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `col`: Column index in parent layout (default 1)

# Returns
Tuple (ax,) of created axes.
"""
function create_plugin_visuals!(parent, row::Int, ::Type{ControllerBodePlugin}, state::ControllerBodePluginState;
                                 col::Int=1)
    # Create axis with colored title
    ax = Axis(parent[row, col],
        title = rich("σ(", rich("K", color=:blue), ")"),
        xlabel = "Frequency (rad/s)",
        ylabel = "Singular value",
        xscale = log10,
        yscale = log10,
        tellheight = false,
    )
    state.ax = ax

    # Plot K singular values (blue)
    for k_obs in state.K_sigmas
        lines!(ax, state.w, k_obs, color=:blue)
    end

    return (ax,)
end

"""
    update_plugin!(state::ControllerBodePluginState, P, Cfb, w; kwargs...)

Update Controller Bode plugin observables with new frequency response data.

# Arguments
- `state`: Plugin state to update
- `P`: Plant system (StateSpace or similar) - not used but kept for interface consistency
- `Cfb`: Feedback controller (StateSpace or similar)
- `w`: Frequency vector (rad/s)
"""
function update_plugin!(state::ControllerBodePluginState, P, Cfb, w; kwargs...)
    # Update frequency vector
    smart_update_nonotify(state.w, w)

    # K singular values
    sig_K, _ = sigma(Cfb, w)
    @views for i in 1:min(size(sig_K, 1), length(state.K_sigmas))
        smart_update(state.K_sigmas[i], sig_K[i, :])
    end
end

# ============================================================================
# Nyquist Plugin
# ============================================================================

"""
    NyquistPlugin <: AbstractControlAppPlugin

Plugin for Nyquist plot of the loop transfer function L.

For SISO loops (ny==1), plots Lo = P*C (output loop transfer).
For loops with nu==1, plots Li = C*P (input loop transfer).

Only supported when ny==1 OR nu==1 (SISO loop transfer).
Displays Ms and Mt constraint circles and the -1 critical point.
"""
struct NyquistPlugin <: AbstractControlAppPlugin end

"""
    NyquistPluginState

State container for Nyquist plugin observables and axes.
"""
mutable struct NyquistPluginState
    # Axis (set during create_plugin_visuals!)
    ax::Union{Nothing, Axis}

    # Nyquist curve data
    nyq_re::Observable{Vector{Float64}}
    nyq_im::Observable{Vector{Float64}}

    # Constraint circles
    Ms::Observable{Float64}
    Mt::Observable{Float64}
    Ms_circle_x::Observable{Vector{Float64}}
    Ms_circle_y::Observable{Vector{Float64}}
    Mt_circle_x::Observable{Vector{Float64}}
    Mt_circle_y::Observable{Vector{Float64}}

    # Configuration
    ny::Int  # Number of outputs (to determine which loop to use)
end

# Only supported for SISO loops
supports_args(::Type{NyquistPlugin}, P, Cfb; ny::Int=1, nu::Int=1, kwargs...) = ny == 1 || nu == 1

plugin_title(::Type{NyquistPlugin}) = "Nyquist"
plugin_name(::Type{NyquistPlugin}) = :Nyquist
grid_size(::Type{NyquistPlugin}) = (1, 1)

"""
    init_plugin_state(::Type{NyquistPlugin}, ny::Int, nu::Int; Ms=nothing, Mt=nothing, kwargs...)

Initialize observable state for Nyquist plugin.

# Arguments
- `ny`: Number of plant outputs
- `nu`: Number of plant inputs

# Keyword Arguments
- `Ms`: Optional existing Observable{Float64} for max sensitivity constraint
- `Mt`: Optional existing Observable{Float64} for max complementary sensitivity constraint
"""
function init_plugin_state(::Type{NyquistPlugin}, ny::Int, nu::Int;
                           Ms::Union{Nothing, Observable{Float64}}=nothing,
                           Mt::Union{Nothing, Observable{Float64}}=nothing,
                           kwargs...)
    # Use provided observables or create new ones
    ms_obs = isnothing(Ms) ? Observable(1.5) : Ms
    mt_obs = isnothing(Mt) ? Observable(1.5) : Mt

    NyquistPluginState(
        nothing,  # ax
        Observable(Float64[]),  # nyq_re
        Observable(Float64[]),  # nyq_im
        ms_obs,   # Ms
        mt_obs,   # Mt
        Observable(Float64[]),  # Ms_circle_x
        Observable(Float64[]),  # Ms_circle_y
        Observable(Float64[]),  # Mt_circle_x
        Observable(Float64[]),  # Mt_circle_y
        ny,       # ny (to determine loop direction)
    )
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{NyquistPlugin}, state::NyquistPluginState;
                           col::Int=1, show_constraints::Bool=true)

Create axes and plot elements for Nyquist visualization.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `col`: Column index in parent layout (default 1)
- `show_constraints`: If true, show Ms/Mt constraint circles (default true)

# Returns
Tuple (ax,) of created axes.
"""
function create_plugin_visuals!(parent, row::Int, ::Type{NyquistPlugin}, state::NyquistPluginState;
                                 col::Int=1, show_constraints::Bool=true)
    # Create axis with title indicating loop type
    loop_label = state.ny == 1 ? "(Lo = PC)" : "(Li = CP)"
    ax = Axis(parent[row, col],
        title = "Nyquist $loop_label",
        xlabel = "Real",
        ylabel = "Imaginary",
        aspect = DataAspect(),
        tellheight = false,
    )
    state.ax = ax

    # Plot Nyquist curve
    lines!(ax, state.nyq_re, state.nyq_im, color=:blue)

    # Plot -1 critical point
    scatter!(ax, [-1], [0], marker=:xcross, color=:red, markersize=15)

    # Reference lines at origin
    vlines!(ax, [0], color=:gray, linewidth=0.5)
    hlines!(ax, [0], color=:gray, linewidth=0.5)

    # Ms and Mt constraint circles (if enabled)
    if show_constraints
        lines!(ax, state.Ms_circle_x, state.Ms_circle_y, color=:blue, linestyle=:dash, linewidth=1)
        lines!(ax, state.Mt_circle_x, state.Mt_circle_y, color=:red, linestyle=:dash, linewidth=1)
    end

    # Set reasonable default limits
    xlims!(ax, -3, 1)
    ylims!(ax, -2, 2)

    return (ax,)
end

"""
    update_plugin!(state::NyquistPluginState, P, Cfb, w; kwargs...)

Update Nyquist plugin observables with new frequency response data.

# Arguments
- `state`: Plugin state to update
- `P`: Plant system (StateSpace or similar)
- `Cfb`: Feedback controller (StateSpace or similar)
- `w`: Frequency vector (rad/s)
"""
function update_plugin!(state::NyquistPluginState, P, Cfb, w; kwargs...)
    # Determine loop transfer based on ny
    if state.ny == 1
        L = P * Cfb  # Output loop transfer Lo = PC
    else
        L = Cfb * P  # Input loop transfer Li = CP
    end

    # Compute Nyquist curve
    re, im = nyquistv(L, w)
    smart_update_nonotify(state.nyq_re, vec(re))
    smart_update(state.nyq_im, vec(im))

    # Update constraint circles
    update_nyquist_circles!(state)
end

"""
    update_nyquist_circles!(state::NyquistPluginState)

Update Ms and Mt constraint circles based on current Ms/Mt values.
"""
function update_nyquist_circles!(state::NyquistPluginState)
    Ms = state.Ms[]
    Mt = state.Mt[]

    θ = range(0, 2π, length=100)

    # Ms circle: centered at (-1, 0), radius = 1/Ms
    rs = 1 / Ms
    smart_update(state.Ms_circle_x, -1 .+ rs .* cos.(θ))
    smart_update(state.Ms_circle_y, rs .* sin.(θ))

    # Mt circle: center = -Mt^2/(Mt^2-1), radius = Mt/(Mt^2-1)
    ct = -Mt^2 / (Mt^2 - 1)
    rt = Mt / (Mt^2 - 1)
    smart_update(state.Mt_circle_x, ct .+ rt .* cos.(θ))
    smart_update(state.Mt_circle_y, rt .* sin.(θ))
end

# ============================================================================
# Loop Transfer Plugin - σ(L) where L=PC or L=CP
# ============================================================================

struct LoopTransferPlugin <: AbstractControlAppPlugin end

mutable struct LoopTransferPluginState
    ax::Union{Nothing, Axis}
    w::Observable{Vector{Float64}}
    L_sigmas::Vector{Observable{Vector{Float64}}}
    ny::Int  # To determine loop type (Lo=PC if ny==1, else Li=CP)
end

supports_args(::Type{LoopTransferPlugin}, P, Cfb; kwargs...) = true
plugin_title(::Type{LoopTransferPlugin}) = "Loop Transfer σ(L)"
plugin_name(::Type{LoopTransferPlugin}) = :LoopTransfer
grid_size(::Type{LoopTransferPlugin}) = (1, 1)

"""
    init_plugin_state(::Type{LoopTransferPlugin}, ny::Int, nu::Int; kwargs...)

Initialize state for LoopTransferPlugin.
Creates observables for frequency vector and singular values of loop transfer function.
"""
function init_plugin_state(::Type{LoopTransferPlugin}, ny::Int, nu::Int; kwargs...)
    nsv = min(ny, nu)
    LoopTransferPluginState(
        nothing,
        Observable(Float64[]),
        [Observable(Float64[]) for _ in 1:nsv],
        ny
    )
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{LoopTransferPlugin},
                           state::LoopTransferPluginState; col::Int=1, kwargs...)

Create axis and plot elements for loop transfer function visualization.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `col`: Column index in parent layout (default: 1)

# Returns
Tuple (ax,) of created axes.
"""
function create_plugin_visuals!(parent, row::Int, ::Type{LoopTransferPlugin},
                                state::LoopTransferPluginState; col::Int=1, kwargs...)
    loop_label = state.ny == 1 ? "(Lo = PC)" : "(Li = CP)"
    ax = Axis(parent[row, col],
        title = "σ(L) $loop_label",
        xlabel = "Frequency (rad/s)",
        ylabel = "Singular value",
        xscale = log10,
        yscale = log10,
        tellheight = false,
    )
    state.ax = ax

    # Plot each singular value
    colors = [:blue, :red, :green, :orange, :purple]
    for (i, L_obs) in enumerate(state.L_sigmas)
        c = colors[mod1(i, length(colors))]
        lines!(ax, state.w, L_obs, color=c)
    end

    # Unity reference line (crossover frequency indicator)
    hlines!(ax, [1.0], color=:gray, linestyle=:dash, linewidth=0.5)

    return (ax,)
end

"""
    update_plugin!(state::LoopTransferPluginState, P, Cfb, w; kwargs...)

Update LoopTransferPlugin observables with new frequency response data.

# Arguments
- `state`: Plugin state to update
- `P`: Plant (StateSpace or similar)
- `Cfb`: Feedback controller (StateSpace or similar)
- `w`: Frequency vector (rad/s)
"""
function update_plugin!(state::LoopTransferPluginState, P, Cfb, w; kwargs...)
    # Compute loop transfer function
    L = state.ny == 1 ? P * Cfb : Cfb * P

    smart_update_nonotify(state.w, w)
    mag, _ = sigma(L, w)
    nsv = min(size(mag, 1), length(state.L_sigmas))
    @views for i in 1:nsv
        smart_update(state.L_sigmas[i], mag[i, :])
    end
end

# ============================================================================
# Step Response Plugin - Output and Control Signal time-domain plots
# ============================================================================

struct StepResponsePlugin <: AbstractControlAppPlugin end

mutable struct StepResponsePluginState
    output_ax::Union{Nothing, Axis}     # Step response (output) - all outputs in one axis
    control_ax::Union{Nothing, Axis}    # Control signal - all controls in one axis
    t::Observable{Vector{Float64}}      # Time vector (shared)
    # y_data[k] = output response for k-th output-input combination (ny*nu total)
    y_data::Vector{Observable{Vector{Float64}}}
    # u_data[j] = control signal for input j
    u_data::Vector{Observable{Vector{Float64}}}
    ny::Int                             # Number of outputs
    nu::Int                             # Number of inputs
    show_control::Bool                  # Whether to show control signal plot
    y_names::Vector{String}             # Output signal names
    u_names::Vector{String}             # Input signal names
    legends::Vector{Any}                # Legend objects for explicit cleanup
end

supports_args(::Type{StepResponsePlugin}, args...; kwargs...) = true
plugin_title(::Type{StepResponsePlugin}) = "Step Response"
plugin_name(::Type{StepResponsePlugin}) = :StepResponse
grid_size(::Type{StepResponsePlugin}) = (1, 2)

"""
    init_plugin_state(::Type{StepResponsePlugin}, ny::Int, nu::Int; show_control::Bool=true,
                      y_names=["y\$i" for i in 1:ny], u_names=["u\$j" for j in 1:nu], kwargs...)

Initialize state for StepResponsePlugin.
Creates observables for time vector, and output/control responses for MIMO systems.
For a system with ny outputs and nu inputs, creates ny*nu output lines and nu control lines.

# Arguments
- `ny`: Number of outputs
- `nu`: Number of inputs
- `show_control`: Whether to show control signal plot (default: true)
- `y_names`: Vector of output signal names (default: ["y1", "y2", ...])
- `u_names`: Vector of input signal names (default: ["u1", "u2", ...])
"""
function init_plugin_state(::Type{StepResponsePlugin}, ny::Int, nu::Int;
                           show_control::Bool=true,
                           y_names::AbstractVector{<:AbstractString}=["y$i" for i in 1:ny],
                           u_names::AbstractVector{<:AbstractString}=["u$j" for j in 1:nu],
                           kwargs...)
    # Create observables for each output-input combination (ny*nu lines for output)
    y_data = [Observable(Float64[]) for _ in 1:(ny*nu)]
    u_data = [Observable(Float64[]) for _ in 1:nu]

    StepResponsePluginState(
        nothing,                    # output_ax
        nothing,                    # control_ax
        Observable(Float64[]),      # t
        y_data,
        u_data,
        ny,
        nu,
        show_control,
        collect(String, y_names),
        collect(String, u_names),
        Any[]                       # legends
    )
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{StepResponsePlugin},
                           state::StepResponsePluginState; col::Int=1, kwargs...)

Create axes and plot elements for step response visualization.
For MIMO systems, plots all output-input combinations in one axis with different colors/labels.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `col`: Column index in parent layout (default: 1)

# Returns
Tuple of created axes: (output_ax, control_ax) if show_control=true, else (output_ax,)
"""
function create_plugin_visuals!(parent, row::Int, ::Type{StepResponsePlugin},
                                state::StepResponsePluginState; col::Int=1, kwargs...)
    ny, nu = state.ny, state.nu
    colors = GLMakie.Makie.wong_colors()

    # Output response axis (all outputs in one plot)
    state.output_ax = Axis(parent[row, col],
        title = "Step Response",
        xlabel = "Time (s)",
        ylabel = "Output",
        tellheight = false,
    )

    # Plot lines for each output-input combination
    k = 1
    for i in 1:ny
        for j in 1:nu
            label = (ny > 1 || nu > 1) ? "$(state.y_names[i]) from $(state.u_names[j])" : ""
            lines!(state.output_ax, state.t, state.y_data[k],
                   color=colors[mod1(k, length(colors))],
                   label=label)
            k += 1
        end
    end

    # Delete old legends and clear the list
    for l in state.legends
        delete!(l)
    end
    empty!(state.legends)

    # Add legend if MIMO
    if ny > 1 || nu > 1
        push!(state.legends, GLMakie.Makie.axislegend(state.output_ax, position=:rt))
    end
    hlines!(state.output_ax, [1.0], color=:gray, linestyle=:dash, linewidth=0.5)

    # Control signal axis (if enabled)
    if state.show_control
        state.control_ax = Axis(parent[row, col+1],
            title = "Control Signal",
            xlabel = "Time (s)",
            ylabel = "Control",
            tellheight = false,
        )
        for j in 1:nu
            label = nu > 1 ? state.u_names[j] : ""
            lines!(state.control_ax, state.t, state.u_data[j],
                   color=colors[mod1(j, length(colors))],
                   label=label)
        end
        if nu > 1
            push!(state.legends, GLMakie.Makie.axislegend(state.control_ax, position=:rt))
        end
        return (state.output_ax, state.control_ax)
    end

    return (state.output_ax,)
end


"""
    update_plugin!(state::StepResponsePluginState, t::AbstractVector, y::AbstractArray,
                   u::AbstractArray=zeros(0,0); kwargs...)

Update StepResponsePlugin observables with new time-domain data.
Handles MIMO systems with y having shape [ny, n_time, nu] from step response.

# Arguments
- `state`: Plugin state to update
- `t`: Time vector
- `y`: Output response array - can be:
  - Vector [n_time] for SISO
  - Matrix [ny, n_time] for single input
  - 3D array [ny, n_time, nu] for full MIMO step response
- `u`: Control signal array (optional) - can be:
  - Vector [n_time] for single input
  - Matrix [nu, n_time] for multiple inputs
  - 3D array [nu, n_time, nu] for full MIMO (uses diagonal)
"""
@views function update_plugin!(state::StepResponsePluginState, t::AbstractVector, y::AbstractArray,
                        u::AbstractArray=zeros(0,0); kwargs...)
    smart_update_nonotify(state.t, t)

    ny, nu = state.ny, state.nu

    # y has shape [ny, n_time, nu] or [ny, n_time] or [n_time] (vector)
    k = 1
    for i in 1:ny
        for j in 1:nu
            if ndims(y) == 3
                smart_update(state.y_data[k], y[i, :, j])
            elseif ndims(y) == 2
                # 2D case: y[ny, n_time], single input - only use first input column
                if j == 1
                    smart_update(state.y_data[k], y[i, :])
                end
            else
                # 1D case: vector, SISO
                if k == 1
                    smart_update(state.y_data[1], y)
                end
            end
            k += 1
        end
    end

    # u has shape [nu, n_time, nu] or [nu, n_time] or [n_time] (vector)
    if state.show_control && !isempty(u)
        for j in 1:nu
            if ndims(u) == 3
                smart_update(state.u_data[j], u[j, :, j])  # diagonal: control j for input j
            elseif ndims(u) >= 2
                smart_update(state.u_data[j], u[j, :])
            elseif j == 1
                smart_update(state.u_data[1], u)
            end
        end
    end
end

# ============================================================================
# Pole-Zero Map Plugin - Closed-loop pole-zero visualization
# ============================================================================

struct PZMapPlugin <: AbstractControlAppPlugin end

mutable struct PZMapPluginState
    ax::Union{Nothing, Axis}
    poles_re::Observable{Vector{Float64}}
    poles_im::Observable{Vector{Float64}}
    zeros_re::Observable{Vector{Float64}}
    zeros_im::Observable{Vector{Float64}}
    theta::Union{Nothing, Observable{Float64}}  # Optional - for cone visualization
    # Tooltip fields
    tooltip_pos::Observable{Point2f}
    tooltip_text::Observable{String}
    tooltip_visible::Observable{Bool}
end

supports_args(::Type{PZMapPlugin}, args...; kwargs...) = true
plugin_title(::Type{PZMapPlugin}) = "Pole-Zero Map"
plugin_name(::Type{PZMapPlugin}) = :PZMap
grid_size(::Type{PZMapPlugin}) = (1, 2)  # Full width (2 columns)

"""
    init_plugin_state(::Type{PZMapPlugin}, ny::Int, nu::Int; theta=nothing, kwargs...)

Initialize state for PZMapPlugin.
Creates observables for poles and zeros coordinates.

# Arguments
- `ny`: Number of plant outputs (not used, kept for interface consistency)
- `nu`: Number of plant inputs (not used, kept for interface consistency)

# Keyword Arguments
- `theta`: Optional Observable{Float64} for pole region cone visualization (mixed sensitivity only)
"""
function init_plugin_state(::Type{PZMapPlugin}, ny::Int, nu::Int;
                           theta::Union{Nothing, Observable{Float64}}=nothing, kwargs...)
    PZMapPluginState(
        nothing,
        Observable(Float64[]),  # poles_re
        Observable(Float64[]),  # poles_im
        Observable(Float64[]),  # zeros_re
        Observable(Float64[]),  # zeros_im
        theta,
        Observable(Point2f(0, 0)),  # tooltip_pos
        Observable(""),              # tooltip_text
        Observable(false)            # tooltip_visible
    )
end

"""
    pzmap_pole_properties(re::Real, im::Real)

Compute angular frequency and damping ratio for a pole/zero at position (re, im).

Returns (ωn, ζ) where:
- ωn = |s| = sqrt(re² + im²) is the natural frequency
- ζ = -re/ωn is the damping ratio (positive for stable poles in LHP)
"""
function pzmap_pole_properties(re::Real, im::Real)
    ωn = sqrt(re^2 + im^2)
    ζ = ωn > 0 ? -re / ωn : 0.0
    return ωn, ζ
end

"""
    create_plugin_visuals!(parent, row::Int, ::Type{PZMapPlugin},
                           state::PZMapPluginState; col::Int=1, kwargs...)

Create axis and plot elements for pole-zero map visualization.

# Arguments
- `parent`: Makie layout (e.g., GridLayout) to place axes in
- `row`: Row index in parent layout
- `state`: Plugin state with observables
- `col`: Column index in parent layout (default: 1)

# Returns
Tuple (ax,) of created axes.
"""
function create_plugin_visuals!(parent, row::Int, ::Type{PZMapPlugin},
                                state::PZMapPluginState; col::Int=1, kwargs...)
    state.ax = Axis(parent[row, col:col+1],
        title = "Closed-Loop Poles and Zeros",
        xlabel = "Real",
        ylabel = "Imaginary",
        tellheight = false,
    )

    # Poles as x markers (blue)
    scatter!(state.ax, state.poles_re, state.poles_im,
             marker=:xcross, markersize=12, color=:blue)

    # Zeros as circles (red outline)
    scatter!(state.ax, state.zeros_re, state.zeros_im,
             marker=:circle, markersize=10, color=(:red, 0.0),
             strokewidth=2, strokecolor=:red)

    # Reference axes
    vlines!(state.ax, [0], color=:gray, linewidth=0.5)
    hlines!(state.ax, [0], color=:gray, linewidth=0.5)

    # Theta cone lines (only if theta observable provided)
    if !isnothing(state.theta)
        # Reactive cone lines based on theta value
        theta_cone_upper_x = @lift begin
            t = $(state.theta)
            t > 0 && t < π - 0.01 ? [0.0, -20.0 * cos(t/2)] : Float64[]
        end
        theta_cone_upper_y = @lift begin
            t = $(state.theta)
            t > 0 && t < π - 0.01 ? [0.0, 20.0 * sin(t/2)] : Float64[]
        end
        theta_cone_lower_x = theta_cone_upper_x
        theta_cone_lower_y = @lift -1 .* $theta_cone_upper_y

        lines!(state.ax, theta_cone_upper_x, theta_cone_upper_y,
               color=:green, linewidth=1.5, linestyle=:dash)
        lines!(state.ax, theta_cone_lower_x, theta_cone_lower_y,
               color=:green, linewidth=1.5, linestyle=:dash)
    end

    # Tooltip for pole/zero information
    tooltip!(state.ax, state.tooltip_pos, state.tooltip_text,
             visible=state.tooltip_visible, placement=:above, fontsize=14)

    # Click event handler for tooltip
    on(events(state.ax).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            if state.tooltip_visible[]
                # Hide tooltip on second click
                state.tooltip_visible[] = false
            else
                # Find nearest pole/zero to click position
                pos = mouseposition(state.ax)
                click_re, click_im = pos[1], pos[2]

                # Collect all poles and zeros with their types
                candidates = Tuple{Float64, Float64, Symbol}[]
                for i in eachindex(state.poles_re[])
                    push!(candidates, (state.poles_re[][i], state.poles_im[][i], :pole))
                end
                for i in eachindex(state.zeros_re[])
                    push!(candidates, (state.zeros_re[][i], state.zeros_im[][i], :zero))
                end

                isempty(candidates) && return

                # Find nearest
                min_dist = Inf
                nearest_re, nearest_im = 0.0, 0.0
                nearest_type = :pole
                for (re, im, type) in candidates
                    dist = (re - click_re)^2 + (im - click_im)^2
                    if dist < min_dist
                        min_dist = dist
                        nearest_re, nearest_im = re, im
                        nearest_type = type
                    end
                end

                # Compute properties
                ωn, ζ = pzmap_pole_properties(nearest_re, nearest_im)

                # Format tooltip text
                type_str = nearest_type == :pole ? "Pole" : "Zero"
                im_sign = nearest_im >= 0 ? "+" : "-"
                tooltip_str = "$type_str: $(round(nearest_re, sigdigits=4)) $(im_sign) $(round(abs(nearest_im), sigdigits=4))im\nωn = $(round(ωn, sigdigits=4)) rad/s\nζ = $(round(ζ, sigdigits=4))"

                # Update tooltip
                state.tooltip_pos[] = Point2f(nearest_re, nearest_im)
                state.tooltip_text[] = tooltip_str
                state.tooltip_visible[] = true
            end
        end
    end

    return (state.ax,)
end

"""
    update_plugin!(state::PZMapPluginState, cl; kwargs...)

Update PZMapPlugin observables with poles and zeros from closed-loop system.

# Arguments
- `state`: Plugin state to update
- `cl`: Closed-loop system (StateSpace or NamedStateSpace)
"""
function update_plugin!(state::PZMapPluginState, cl; kwargs...)
    p = poles(cl)
    z = tzeros(cl)
    smart_update_nonotify(state.poles_re, real.(p))
    smart_update(state.poles_im, imag.(p))
    smart_update_nonotify(state.zeros_re, isempty(z) ? Float64[] : real.(z))
    smart_update(state.zeros_im, isempty(z) ? Float64[] : imag.(z))
end
