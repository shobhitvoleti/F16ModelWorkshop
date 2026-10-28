# Transient analysis with a curated figure (dyad/flight_analysis.dyad).

import Plots

abstract type AbstractFlightAnalysisSpec <: AbstractAnalysisSpec end

"""
    FlightAnalysisSpec(; model, stop = 10.0, panels = String[], abstol = 1e-6, reltol = 1e-6)

Simulate `model` from 0 to `stop` (s). Each `panels` entry `"Title: signal, ..."` is one
panel of the `:FlightResponse` figure; a signal is a path into the model such as
`"f16plant.vt"` or `"scheduler.w[2]"`.
"""
@kwdef mutable struct FlightAnalysisSpec <: AbstractFlightAnalysisSpec
    name::Symbol = :FlightAnalysis
    model::Union{Nothing, System} = nothing
    stop::Float64 = 10.0
    panels::Vector{String} = String[]
    abstol::Float64 = 1e-6
    reltol::Float64 = 1e-6
    overrides::_Overrides = _Overrides()
    __system::Union{Nothing, System} = nothing   # handed over by Dyad-generated specs; unused
end

"""
    FlightAnalysisSolution

The transient solution (`inner`, and its ODE solution as `sol`) and the `spec` whose
`panels` the `:FlightResponse` figure draws.
"""
struct FlightAnalysisSolution{S, O} <: AbstractAnalysisSolution
    spec::FlightAnalysisSpec
    inner::S
    sol::O
end

Base.nameof(sol::FlightAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::FlightAnalysisSpec)
    inner = DyadInterface.run_analysis(TransientAnalysisSpec(;
        name = spec.name, model = spec.model, stop = spec.stop,
        abstol = spec.abstol, reltol = spec.reltol, overrides = spec.overrides))
    sol = FlightAnalysisSolution(spec, inner, inner.sol)
    # Resolve every panel now, so a misspelt signal fails the run instead of the figure.
    flight_panels(sol)
    return sol
end

"""
    parse_panel(entry) -> (title, signals)

Split a `panels` entry `"Title: a, b"` into its title and signal paths.
"""
function parse_panel(entry::AbstractString)
    title, sep, rest = rpartition_colon(entry)
    isempty(sep) && throw(ArgumentError("a panel is `Title: signal, ...`, got \"$entry\""))
    signals = filter(!isempty, strip.(split(rest, ',')))
    isempty(signals) && throw(ArgumentError("the panel \"$title\" lists no signals"))
    return String(strip(title)), String.(signals)
end

# The title may itself contain a colon (a time, a ratio), so split at the last one.
function rpartition_colon(s::AbstractString)
    i = findlast(':', s)
    i === nothing && return (s, "", "")
    return (s[1:prevind(s, i)], ":", s[nextind(s, i):end])
end

"""
    resolve_signal(model, path)

The symbolic variable at `path` in `model`: a dotted path of subcomponents and
variables, where any step may carry one index, as in `"scheduler.w[2]"`.
"""
function resolve_signal(model, path::AbstractString)
    x = model
    for part in split(path, '.')
        m = match(r"^([A-Za-z_][A-Za-z0-9_]*)(?:\[(\d+)\])?$", part)
        m === nothing && throw(ArgumentError("cannot read the signal path \"$path\""))
        name = Symbol(m.captures[1])
        hasproperty(x, name) || throw(ArgumentError("the model has no `$path`: no `$name` in `$(nameof(x))`"))
        x = getproperty(x, name)
        isnothing(m.captures[2]) || (x = x[parse(Int, m.captures[2])])
    end
    return x
end

"""
    flight_panels(sol::FlightAnalysisSolution) -> Vector

One `(title, [(path, t, values, clocked)...])` per panel. A clocked signal has one value
per controller tick rather than per solver step; its ticks are spaced evenly from 0.
"""
function flight_panels(fsol::FlightAnalysisSolution)
    sol = fsol.sol
    model = symbolic_container(fsol.inner)
    return map(fsol.spec.panels) do entry
        title, paths = parse_panel(entry)
        series = map(paths) do path
            values = sol[resolve_signal(model, path)]
            if length(values) == length(sol.t)
                (path, sol.t, values, false)
            else
                n = length(values)
                ticks = range(first(sol.t), last(sol.t); length = n + 1)[1:n]
                (path, collect(ticks), values, true)
            end
        end
        (title, series)
    end
end

function flight_figure(fsol::FlightAnalysisSolution)
    panels = flight_panels(fsol)
    plots = map(enumerate(panels)) do (i, (title, series))
        p = Plots.plot(; title, titlefontsize = 10, legend = :best, left_margin = 12Plots.mm,
            xlabel = i == length(panels) ? "t (s)" : "")
        for (path, t, values, clocked) in series
            Plots.plot!(p, t, values; label = path, seriestype = clocked ? :steppost : :path)
        end
        p
    end
    return Plots.plot(plots...; layout = (length(plots), 1), size = (900, 230 * length(plots)))
end

DyadInterface.symbolic_container(sol::FlightAnalysisSolution) = symbolic_container(sol.inner)

function DyadInterface.AnalysisSolutionMetadata(sol::FlightAnalysisSolution)
    inner_md = AnalysisSolutionMetadata(sol.inner)
    arts = ArtifactMetadata[
        ArtifactMetadata(:FlightResponse, ArtifactType.PlotlyPlot, "Flight response",
            "The signals named in the analysis' `panels`, one panel each."),
    ]
    append!(arts, transient_artifacts(inner_md))
    return AnalysisSolutionMetadata(arts, inner_md.symbol_groups)
end

function DyadInterface.artifacts(sol::FlightAnalysisSolution, name::Symbol)
    name === :FlightResponse && return flight_figure(sol)
    return artifacts(sol.inner, name)
end

DyadInterface.customizable_visualization(sol::FlightAnalysisSolution, vizspec) =
    customizable_visualization(sol.inner, vizspec)

export AbstractFlightAnalysisSpec, FlightAnalysisSpec, FlightAnalysisSolution
