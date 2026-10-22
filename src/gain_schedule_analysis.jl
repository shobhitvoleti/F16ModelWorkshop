# Gain-schedule design, paired with the `partial analysis` in
# dyad/gain_schedule_analysis.dyad. Defined before the generated code, which references
# the `*Spec` type; the design itself is `ScheduledPID`, loaded after it.

import ControlSystemsBase

abstract type AbstractGainScheduleAnalysisSpec <: AbstractAnalysisSpec end

"""
    GainScheduleAnalysisSpec(; velocities = [140.0, 152.4, 170.0], altitude = 3000.0, fixed_point = 2)

Design the step-7 autopilot at each airspeed of `velocities` (m/s) at `altitude` (m), and
compare each design point's loops with those that the gains of design point
`fixed_point` give there.
"""
@kwdef mutable struct GainScheduleAnalysisSpec <: AbstractGainScheduleAnalysisSpec
    name::Symbol = :GainScheduleAnalysis
    model::Union{Nothing, System} = nothing
    velocities::Vector{Float64} = [140.0, 152.4, 170.0]
    altitude::Float64 = 3000.0
    fixed_point::Int = 2
    overrides::_Overrides = _Overrides()
end

"""
    GainScheduleAnalysisSolution

`table` is `ScheduledPID.gain_table`, `pressures` the dynamic pressure of each design
point, `scheduled[j]` and `fixed[j]` the loops (`ScheduledPID.loop_transfers`) at design
point `j` with its own gains and with those of `spec.fixed_point`.
"""
struct GainScheduleAnalysisSolution <: AbstractAnalysisSolution
    spec::GainScheduleAnalysisSpec
    table::Matrix{Float64}
    pressures::Vector{Float64}
    scheduled::Vector{Any}
    fixed::Vector{Any}
end

Base.nameof(sol::GainScheduleAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::GainScheduleAnalysisSpec)
    SP = ScheduledPID
    1 <= spec.fixed_point <= length(spec.velocities) ||
        throw(ArgumentError("fixed_point must name one of the $(length(spec.velocities)) design points"))
    table = SP.gain_table(spec.velocities, spec.altitude)
    models = [SP.longitudinal_model(v, spec.altitude) for v in spec.velocities]
    scheduled = Any[SP.loop_transfers(models[j], table[:, j]) for j in eachindex(models)]
    fixed = Any[SP.loop_transfers(m, table[:, spec.fixed_point]) for m in models]
    return GainScheduleAnalysisSolution(spec, table, SP.knot_pressures(spec.velocities, spec.altitude),
        scheduled, fixed)
end

const _LOOP_TITLES = (pitch = "Pitch attitude", altitude = "Altitude", speed = "Airspeed")

# Gain crossover (rad/s) and phase margin (deg) of a loop. The pitch loop's unstable
# airframe pole makes `margin` unwrap the phase by a whole turn, hence the `mod`.
function _crossover(L)
    _, _, wpm, pm = ControlSystemsBase.margin(L)
    return (wpm[1], mod(pm[1], 360))
end

function gain_schedule_figure(sol::GainScheduleAnalysisSolution)
    rows = Dict(r => i for (i, r) in enumerate(ScheduledPID.SCHEDULE_ROWS))
    q = sol.pressures ./ 1000
    labels = string.(sol.spec.velocities, " m/s")
    panels = map(((:K_pitch, "Pitch gain (deg of elevator per rad)"),
                  (:K_alt, "Altitude gain (rad of pitch per m)"),
                  (:K_speed, "Airspeed gain (kN of thrust per m/s)"))) do (row, title)
        k = sol.table[rows[row], :]
        p = Plots.plot(q, k; label = "interpolated", title, titlefontsize = 10,
            left_margin = 12Plots.mm, legend = :best)
        Plots.scatter!(p, q, k; label = "design points", series_annotations = Plots.text.(labels, 7, :bottom))
        p
    end
    Plots.xlabel!(panels[end], "dynamic pressure (kPa)")
    return Plots.plot(panels...; layout = (3, 1), size = (900, 720))
end

function loop_shapes_figure(sol::GainScheduleAnalysisSolution)
    w = exp10.(range(log10(0.3), 1; length = 300))
    fixed_label = string(sol.spec.velocities[sol.spec.fixed_point], " m/s")
    panels = map(((sol.scheduled, "Pitch loop, each design point's own gains"),
                  (sol.fixed, "Pitch loop, the gains of $fixed_label at every design point"))) do (loops, title)
        p = Plots.plot(; xscale = :log10, title, titlefontsize = 10, ylabel = "loop gain (dB)",
            left_margin = 12Plots.mm, legend = :topright, ylims = (-20, 20))
        for (j, v) in enumerate(sol.spec.velocities)
            mag = abs.(vec(ControlSystemsBase.freqresp(loops[j].pitch, w)))
            wc = round(first(_crossover(loops[j].pitch)); digits = 2)
            Plots.plot!(p, w, 20 .* log10.(mag); label = "$v m/s, crosses 0 dB at $wc rad/s")
        end
        Plots.hline!(p, [0.0]; color = :black, linestyle = :dot, label = "")
        Plots.vline!(p, [ScheduledPID.PITCH_LOOP.crossover]; color = :gray, linestyle = :dash,
            label = "design crossover")
        p
    end
    Plots.xlabel!(panels[end], "frequency (rad/s)")
    return Plots.plot(panels...; layout = (2, 1), size = (900, 650))
end

function margins_table(sol::GainScheduleAnalysisSolution)
    rows = NamedTuple[]
    for (j, v) in enumerate(sol.spec.velocities), loop in keys(_LOOP_TITLES)
        wc, pm = _crossover(sol.scheduled[j][loop])
        wf, pf = _crossover(sol.fixed[j][loop])
        push!(rows, (; airspeed_m_s = v, dynamic_pressure_Pa = sol.pressures[j], loop = _LOOP_TITLES[loop],
            crossover_scheduled_rad_s = wc, phase_margin_scheduled_deg = pm,
            crossover_fixed_rad_s = wf, phase_margin_fixed_deg = pf))
    end
    return DataFrames.DataFrame(rows)
end

function gain_table_frame(sol::GainScheduleAnalysisSolution)
    df = DataFrames.DataFrame(airspeed_m_s = sol.spec.velocities, dynamic_pressure_Pa = sol.pressures)
    for (i, row) in enumerate(ScheduledPID.SCHEDULE_ROWS)
        df[!, row] = sol.table[i, :]
    end
    return df
end

function DyadInterface.AnalysisSolutionMetadata(::GainScheduleAnalysisSolution)
    arts = [
        ArtifactMetadata(:GainSchedule, ArtifactType.PlotlyPlot, "Gain schedule",
            "Each loop's gain against the dynamic pressure of its design point."),
        ArtifactMetadata(:LoopShapes, ArtifactType.PlotlyPlot, "Pitch loop shapes",
            "Pitch loop gain at every design point, scheduled and with fixed gains."),
        ArtifactMetadata(:Margins, ArtifactType.DataFrame, "Crossover and phase margin",
            "Every loop at every design point, scheduled and with fixed gains."),
        ArtifactMetadata(:GainTable, ArtifactType.DataFrame, "Gain table",
            "The gains and trims AutopilotGainSchedule interpolates, one row per design point."),
    ]
    return AnalysisSolutionMetadata(arts, Dict{Symbol, Vector{Symbol}}())
end

function DyadInterface.artifacts(sol::GainScheduleAnalysisSolution, name::Symbol)
    name === :GainSchedule && return gain_schedule_figure(sol)
    name === :LoopShapes && return loop_shapes_figure(sol)
    name === :Margins && return margins_table(sol)
    name === :GainTable && return gain_table_frame(sol)
    throw(ArgumentError("GainScheduleAnalysis has no artifact $name"))
end

export AbstractGainScheduleAnalysisSpec, GainScheduleAnalysisSpec, GainScheduleAnalysisSolution
