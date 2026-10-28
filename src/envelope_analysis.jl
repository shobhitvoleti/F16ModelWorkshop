# Flight-envelope survey (dyad/envelope_analysis.dyad). The survey lives in `EnvelopeMPC`,
# which is included after this file and resolved at run time.

abstract type AbstractEnvelopeAnalysisSpec <: AbstractAnalysisSpec end

"""
    EnvelopeAnalysisSpec(; velocities = [140.0, 250.0], altitudes = [0.0, 9000.0], points = 100, table_dir = "")

Trim and linearize the plant on a `points × points` grid between the bounds of
`velocities` (m/s) and `altitudes` (m). With `table_dir`, also rewrite
`envelope_trim_alpha.csv` there at the nodes of the committed table.
"""
@kwdef mutable struct EnvelopeAnalysisSpec <: AbstractEnvelopeAnalysisSpec
    name::Symbol = :EnvelopeAnalysis
    model::Union{Nothing, System} = nothing
    velocities::Vector{Float64} = [140.0, 250.0]
    altitudes::Vector{Float64} = [0.0, 9000.0]
    points::Int = 100
    table_dir::String = ""
    overrides::_Overrides = _Overrides()
    __system::Union{Nothing, System} = nothing   # handed over by Dyad-generated specs; unused
end

"""
    EnvelopeAnalysisSolution

`envelope` is `EnvelopeMPC.envelope` on the grid, `nodes` the bank's `(velocity, altitude)`
nodes from the trim table, and `table` the rewritten table's path, or `nothing`.
"""
struct EnvelopeAnalysisSolution{E} <: AbstractAnalysisSolution
    spec::EnvelopeAnalysisSpec
    envelope::E
    nodes::Vector{NTuple{2, Float64}}
    table::Union{Nothing, String}
end

Base.nameof(sol::EnvelopeAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::EnvelopeAnalysisSpec)
    length(spec.velocities) == 2 && length(spec.altitudes) == 2 ||
        throw(ArgumentError("velocities and altitudes are each [lowest, highest]"))
    spec.points >= 2 || throw(ArgumentError("points must be at least 2"))
    E = EnvelopeMPC
    env = E.envelope(range(spec.velocities...; length = spec.points),
        range(spec.altitudes...; length = spec.points))
    table = isempty(spec.table_dir) ? nothing : E.write_trim_table(_resolve_export(spec.table_dir))
    knots = E.trim_table()
    nodes = vec([(Float64(v), Float64(h)) for v in knots["vt"], h in knots["alt"]])
    return EnvelopeAnalysisSolution(spec, env, nodes, table)
end

function envelope_figure(sol::EnvelopeAnalysisSolution)
    env = sol.envelope
    panel(z, title, label) = begin
        p = Plots.heatmap(env.velocities, env.altitudes, permutedims(z); title, titlefontsize = 10,
            xlabel = "airspeed (m/s)", ylabel = "altitude (m)", colorbar_title = label)
        Plots.scatter!(p, first.(sol.nodes), last.(sol.nodes); color = :white, markersize = 5,
            label = "bank nodes")
    end
    return Plots.plot(
        panel(rad2deg.(env.alpha), "Trimmed angle of attack", "deg"),
        panel(env.thrust, "Trimmed thrust", "kN"),
        panel(env.elevator, "Trimmed elevator", "deg"),
        panel(env.unstable, "Pitch divergence rate (0 = statically stable)", "1/s");
        layout = (2, 2), size = (1250, 850), left_margin = 6Plots.mm, right_margin = 6Plots.mm)
end

function DyadInterface.AnalysisSolutionMetadata(sol::EnvelopeAnalysisSolution)
    arts = ArtifactMetadata[ArtifactMetadata(:Envelope, ArtifactType.PlotlyPlot, "Flight envelope",
        "Trim and pitch stability over the airspeed-altitude grid, with the bank nodes.")]
    isnothing(sol.table) || push!(arts, ArtifactMetadata(:TrimTable, ArtifactType.Download,
        basename(sol.table), "The bank's trim table, rewritten at $(sol.table)."))
    return AnalysisSolutionMetadata(arts, Dict{Symbol, Vector{Symbol}}())
end

function DyadInterface.artifacts(sol::EnvelopeAnalysisSolution, name::Symbol)
    name === :Envelope && return envelope_figure(sol)
    name === :TrimTable && !isnothing(sol.table) && return sol.table
    throw(ArgumentError("EnvelopeAnalysis has no artifact $name"))
end

export AbstractEnvelopeAnalysisSpec, EnvelopeAnalysisSpec, EnvelopeAnalysisSolution
