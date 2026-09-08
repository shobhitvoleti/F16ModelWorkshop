# Interactive GLMakie dashboard for tuning the F-16 LQG design.
#
# Every view is registered as a function of the current design. Moving the
# input-penalty slider re-runs the Dyad LQG analysis and refreshes all views.

using DyadControlSystems
using DyadControlSystems: LQGAnalysisSpec, LQGAnalysisSolution, run_analysis
using ControlSystemsBase
using GLMakie
using Printf

const BLUE = RGBf(0.29, 0.43, 0.88)
const INK = RGBf(0.10, 0.11, 0.14)
const DARK = RGBf(0.25, 0.27, 0.32)
const MUTED = RGBf(0.38, 0.42, 0.49)
const SOFT = RGBf(0.61, 0.64, 0.70)
const GRID = RGBf(0.86, 0.88, 0.91)
const PANEL = RGBf(0.995, 0.995, 1.0)
const AMBER = RGBf(0.66, 0.39, 0.12)

const TAGLINE = "Q1 · Q2 · R1 · R2 · every panel recomputes"

# Peak sensitivity target drawn on the Gang of Four panel.
const MS_TARGET = 2.0

"""A dashboard panel: a named function of the latest LQG solution."""
struct DashboardPlugin
    name::Symbol
    title::String
    update!::Function
end

mutable struct LQGDesignerState
    fig::Figure
    original_spec::LQGAnalysisSpec
    elevator_weight::Observable{Float64}
    sol::Observable{Union{Nothing, LQGAnalysisSolution}}
    status::Observable{String}
    plugins::Vector{DashboardPlugin}
    busy::Bool
    pending_weight::Union{Nothing, Float64}
end

function tuned_spec(spec::LQGAnalysisSpec, elevator_weight::Real)
    q2 = copy(spec.q2_diag)
    length(q2) >= 2 || error("The F-16 design must expose elevator as q2_diag[2].")
    q2[2] = Float64(elevator_weight)

    LQGAnalysisSpec(
        name=spec.name,
        model=spec.model,
        measurement=spec.measurement,
        controlled_output=spec.controlled_output,
        control_input=spec.control_input,
        disturbance_inputs=spec.disturbance_inputs,
        loop_openings=spec.loop_openings,
        t=spec.t,
        q1_diag=spec.q1_diag,
        q2_diag=q2,
        r1_diag=spec.r1_diag,
        r2_diag=spec.r2_diag,
        qQ=spec.qQ,
        qR=spec.qR,
        disc=spec.disc,
        Ts=spec.Ts,
        integrator_indices=spec.integrator_indices,
        integrator_r1_diag=spec.integrator_r1_diag,
        wl=spec.wl,
        wu=spec.wu,
        num_frequencies=spec.num_frequencies,
        duration=spec.duration,
        maximum_order=spec.maximum_order,
        overrides=copy(spec.overrides),
    )
end

function panel_axis(parent, title; kwargs...)
    Axis(parent;
        title=title,
        titlealign=:left,
        titlefont=:bold,
        titlesize=13,
        titlecolor=MUTED,
        titlegap=10,
        backgroundcolor=PANEL,
        xgridvisible=false,
        ygridvisible=false,
        topspinecolor=GRID,
        bottomspinecolor=GRID,
        leftspinecolor=GRID,
        rightspinecolor=GRID,
        xtickcolor=GRID,
        ytickcolor=GRID,
        xticklabelsize=10,
        yticklabelsize=10,
        xticklabelcolor=SOFT,
        yticklabelcolor=SOFT,
        kwargs...,
    )
end

"""Annotation floated over a panel, in the same layout cell as its axis."""
function panel_note!(slot, text; halign, valign, color=SOFT, fontsize=12)
    Label(slot, text;
        halign=halign,
        valign=valign,
        color=color,
        fontsize=fontsize,
        tellwidth=false,
        tellheight=false,
        padding=(16, 16, 12, 34),
    )
end

"""Diagonal elevator return ratio, the loop the slider shapes."""
function elevator_return_ratio(sol)
    elevator_idx = findfirst(==("uEl"), input_names(sol.P))
    elevator_idx === nothing && error("uEl is not present in the plant inputs.")
    minreal((sol.Cfb * sol.P)[elevator_idx, elevator_idx], 1e-4)
end

function register_step_plugin!(state, slot)
    ax = panel_axis(slot, "STEP RESPONSE")
    t_obs = Observable(Float64[])
    y_obs = Observable(Float64[])
    lines!(ax, t_obs, y_obs; color=BLUE, linewidth=2.5)
    hlines!(ax, [1.0]; color=GRID, linestyle=:dot, linewidth=1)

    update! = function (sol, _w)
        L = elevator_return_ratio(sol)
        G = feedback(L)
        duration = state.original_spec.duration > 0 ? state.original_spec.duration : 10.0
        tv = range(0.0, duration; length=700)
        result = step(G, tv)
        t_obs[] = collect(result.t)
        y_obs[] = vec(result.y[1, :, 1])
        autolimits!(ax)
    end
    push!(state.plugins, DashboardPlugin(:step, "Step response", update!))
end

function register_pz_plugin!(state, slot)
    ax = panel_axis(slot, "POLE–ZERO MAP")
    pole_re = Observable(Float64[])
    pole_im = Observable(Float64[])
    zero_re = Observable(Float64[])
    zero_im = Observable(Float64[])
    hlines!(ax, [0.0]; color=GRID, linewidth=1)
    vlines!(ax, [0.0]; color=GRID, linewidth=1)
    scatter!(ax, pole_re, pole_im; marker=:xcross, markersize=16, color=BLUE, strokewidth=0)
    scatter!(ax, zero_re, zero_im; marker=:circle, markersize=9,
        color=(:white, 0.0), strokecolor=MUTED, strokewidth=1.5)
    panel_note!(slot, "← more damping"; halign=:left, valign=:bottom)

    update! = function (sol, _w)
        T = feedback(elevator_return_ratio(sol))
        # Keep the modes that determine the visible transient; very fast
        # actuator/filter modes would otherwise collapse the useful scale.
        p = filter(x -> abs(x) <= 10.0, poles(T))
        z = filter(x -> abs(x) <= 10.0, tzeros(T))
        pole_re[] = real.(p)
        pole_im[] = imag.(p)
        zero_re[] = real.(z)
        zero_im[] = imag.(z)
        autolimits!(ax)
    end
    push!(state.plugins, DashboardPlugin(:pzmap, "Pole-zero map", update!))
end

function register_loop_transfer_plugin!(state, slot)
    ax = panel_axis(slot, "LOOP TRANSFER · σ"; xscale=log10)
    bundle_x = Observable(Float64[])
    bundle_y = Observable(Float64[])
    top_x = Observable(Float64[])
    top_y = Observable(Float64[])
    zero_db_at = Observable(Point2f(1.0, 0.0))
    channels = Observable("")
    hlines!(ax, [0.0]; color=GRID, linestyle=:dot, linewidth=1)
    lines!(ax, bundle_x, bundle_y; color=(SOFT, 0.75), linewidth=1.2)
    lines!(ax, top_x, top_y; color=BLUE, linewidth=2.4)
    text!(ax, zero_db_at; text="0 dB", color=SOFT, fontsize=11, align=(:left, :bottom))
    panel_note!(slot, channels; halign=:right, valign=:top)

    update! = function (sol, w)
        # Return ratio broken at the plant input: one singular value per control
        # channel. The largest is highlighted; the rest set the spread.
        sv, _ = sigma(sol.Cfb * sol.P, w)
        db = 20 .* log10.(sv)
        wv = collect(w)
        # NaN separators draw every singular value as one line object, so the
        # panel does not need to know the channel count until the design exists.
        joined_x = Float64[]
        joined_y = Float64[]
        for i in axes(db, 1)
            append!(joined_x, wv)
            append!(joined_y, view(db, i, :))
            push!(joined_x, NaN)
            push!(joined_y, NaN)
        end
        bundle_x[] = joined_x
        bundle_y[] = joined_y
        top_x[] = wv
        top_y[] = collect(view(db, 1, :))
        zero_db_at[] = Point2f(first(wv), 0.0)
        channels[] = @sprintf("%d inputs", size(db, 1))
        autolimits!(ax)
    end
    push!(state.plugins, DashboardPlugin(:loop_transfer, "Loop transfer", update!))
end

function register_gang_of_four_plugin!(state, slot)
    ax = panel_axis(slot, "GANG OF FOUR"; xscale=log10, yscale=log10)
    w_obs = Observable(Float64[])
    s_obs = Observable(Float64[])
    t_obs = Observable(Float64[])
    ps_obs = Observable(Float64[])
    cs_obs = Observable(Float64[])
    hlines!(ax, [MS_TARGET]; color=AMBER, linestyle=:dash, linewidth=1.5)
    lines!(ax, w_obs, ps_obs; color=(BLUE, 0.30), linewidth=1.3)
    lines!(ax, w_obs, cs_obs; color=(DARK, 0.30), linewidth=1.3)
    lines!(ax, w_obs, s_obs; color=BLUE, linewidth=2.4)
    lines!(ax, w_obs, t_obs; color=DARK, linewidth=2.4)
    panel_note!(slot, @sprintf("Ms = %g", MS_TARGET);
        halign=:left, valign=:top, color=AMBER)
    panel_note!(slot, "PS · CS"; halign=:right, valign=:top)
    panel_note!(slot, "S"; halign=:left, valign=:bottom, color=BLUE)
    panel_note!(slot, "T"; halign=:right, valign=:bottom, color=DARK)

    update! = function (sol, w)
        elevator_idx = findfirst(==("uEl"), input_names(sol.P))
        elevator_idx === nothing && error("uEl is not present in the plant inputs.")
        Pcol = sol.P[:, elevator_idx]
        Crow = sol.Cfb[elevator_idx, :]
        S, PS, CS, T = gangoffour(Pcol, Crow; minimal=true)
        s, _ = sigma(S, w)
        t, _ = sigma(T, w)
        ps, _ = sigma(PS, w)
        cs, _ = sigma(CS, w)
        w_obs[] = collect(w)
        # Show the worst-case singular value at each frequency. S and T are
        # 12×12 for this one-actuator return-ratio construction; PS and CS
        # are rectangular and therefore each have one singular value.
        s_obs[] = vec(maximum(s; dims=1))
        t_obs[] = vec(maximum(t; dims=1))
        ps_obs[] = vec(maximum(ps; dims=1))
        cs_obs[] = vec(maximum(cs; dims=1))
        autolimits!(ax)
    end
    push!(state.plugins, DashboardPlugin(:gang_of_four, "Gang of Four", update!))
end

function update_all_plugins!(state::LQGDesignerState, sol)
    w = 10.0 .^ range(-3.0, 3.0; length=420)
    for plugin in state.plugins
        plugin.update!(sol, w)
    end
end

function run_lqg!(state::LQGDesignerState, requested_weight::Real=state.elevator_weight[])
    weight = Float64(requested_weight)
    if state.busy
        state.pending_weight = weight
        return
    end

    state.busy = true
    try
        state.status[] = @sprintf("RECOMPUTING · Q2 = %.3g", weight)
        sol = run_analysis(tuned_spec(state.original_spec, weight))
        state.sol[] = sol
        update_all_plugins!(state, sol)
        max_real_pole = maximum(real.(poles(feedback(sol.P * sol.Cfb))))
        state.status[] = max_real_pole >= 0 ?
            @sprintf("UNSTABLE · RIGHTMOST CLOSED-LOOP POLE %.3g", max_real_pole) :
            TAGLINE
    catch err
        state.status[] = "DESIGN ERROR · " * sprint(showerror, err)
        @error "F-16 LQG redesign failed" exception=(err, catch_backtrace())
    finally
        state.busy = false
    end

    if state.pending_weight !== nothing
        pending = state.pending_weight
        state.pending_weight = nothing
        !isapprox(pending, weight) && run_lqg!(state, pending)
    end
    return state.sol[]
end

"""
    launch_lqg_designer(spec; elevator_weight=0.33)

Launch the F-16 interactive tuning dashboard. The slider modifies the elevator
entry of the LQG input-weight vector (`q2_diag[2]`); all registered views are
recomputed from the resulting design.
"""
function DyadControlSystems.launch_lqg_designer(spec::LQGAnalysisSpec; elevator_weight=0.33)
    set_theme!(Theme(
        fontsize=12,
        font="DejaVu Sans",
        backgroundcolor=:white,
        textcolor=INK,
        Axis=(;
            backgroundcolor=PANEL,
            xgridvisible=false,
            ygridvisible=false,
            spinewidth=1,
        ),
    ))

    fig = Figure(size=(1366, 728), backgroundcolor=:white)
    plugins = DashboardPlugin[]
    state = LQGDesignerState(
        fig,
        spec,
        Observable(Float64(elevator_weight)),
        Observable{Union{Nothing, LQGAnalysisSolution}}(nothing),
        Observable("INITIALIZING F-16 DESIGN"),
        plugins,
        false,
        nothing,
    )

    # Header.
    Label(fig[1, 1], rich(rich("·8o· ", color=BLUE), "JuliaHub");
        halign=:left, fontsize=14, font=:bold)
    Label(fig[1, 2], "TOOLING"; halign=:right, color=BLUE, fontsize=13, font=:bold)
    Label(fig[2, 1:2], "Tune it live"; halign=:left, fontsize=36, font=:bold)

    # Tuning row. A logarithmic weight grid gives useful resolution over decades.
    controls = fig[3, 1:2] = GridLayout()
    Label(controls[1, 1], "Q2 · INPUT PENALTY"; color=MUTED, font=:bold, halign=:left)
    weight_grid = sort!(unique!(vcat(
        10.0 .^ range(-4.0, 2.0; length=321),
        Float64(elevator_weight),
    )))
    start_idx = findfirst(==(Float64(elevator_weight)), weight_grid)
    slider = Slider(controls[1, 2]; range=weight_grid, startvalue=weight_grid[start_idx],
        color_active=BLUE, color_inactive=GRID)
    Label(controls[1, 3], @lift(@sprintf("Q2 = %.3g", $(slider.value)));
        color=MUTED, font=:bold, halign=:left)
    Label(controls[1, 4], state.status; halign=:right, color=SOFT, font=:bold)
    colsize!(controls, 1, Fixed(180))
    colsize!(controls, 2, Fixed(230))
    colsize!(controls, 3, Fixed(110))

    # Four independent view plugins in the 2×2 layout.
    views = fig[4, 1:2] = GridLayout()
    register_step_plugin!(state, views[1, 1])
    register_pz_plugin!(state, views[1, 2])
    register_loop_transfer_plugin!(state, views[2, 1])
    register_gang_of_four_plugin!(state, views[2, 2])
    rowgap!(views, 14)
    colgap!(views, 14)

    Label(fig[5, 1], rich("adding a view is ", rich("adding a function", font=:bold));
        halign=:left, color=MUTED, fontsize=14)
    Label(fig[5, 2], rich(rich("TRIM · LINEARIZE · DESIGN · ", color=SOFT),
            rich("IMPLEMENT", color=BLUE));
        halign=:right, font=:bold)

    rowsize!(fig.layout, 1, Fixed(24))
    rowsize!(fig.layout, 2, Fixed(52))
    rowsize!(fig.layout, 3, Fixed(34))
    rowsize!(fig.layout, 5, Fixed(26))
    # Fill the window instead of shrinking the root grid to the natural title width.
    state.fig.layout.width = nothing
    state.fig.layout.tellwidth = false
    colsize!(state.fig.layout, 1, Relative(0.5))
    colsize!(state.fig.layout, 2, Relative(0.5))

    colgap!(fig.layout, 12)
    rowgap!(fig.layout, 10)

    on(slider.value) do value
        state.elevator_weight[] = Float64(value)
        run_lqg!(state, value)
    end

    run_lqg!(state, slider.value[])
    display(fig)
    return state
end
