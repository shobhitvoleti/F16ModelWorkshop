# Controller export (dyad/controller_export_analysis.dyad). The design analyses it runs
# are generated, so they are looked up at run time.

abstract type AbstractControllerExportAnalysisSpec <: AbstractAnalysisSpec end

"""
    ControllerExportAnalysisSpec(; design = "TutorialLQG", file = "assets/controller.toml", add_trim = false)

Run the LQG design analysis `design` of `F16ModelWorkshop.Tutorial` and write its feedback
controller to `file` (relative to the package root), with the trim controls as output
offset `y0` when `add_trim` is set.
"""
@kwdef mutable struct ControllerExportAnalysisSpec <: AbstractControllerExportAnalysisSpec
    name::Symbol = :ControllerExportAnalysis
    model::Union{Nothing, System} = nothing
    design::String = "TutorialLQG"
    file::String = "assets/controller.toml"
    add_trim::Bool = false
    overrides::_Overrides = _Overrides()
    __system::Union{Nothing, System} = nothing   # handed over by Dyad-generated specs; unused
end

"""
    ControllerExportAnalysisSolution

The design analysis' solution (`inner`), the written `file` and its `controller` table.
"""
struct ControllerExportAnalysisSolution{S} <: AbstractAnalysisSolution
    spec::ControllerExportAnalysisSpec
    inner::S
    file::String
    controller::Dict{String, Any}
end

Base.nameof(sol::ControllerExportAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::ControllerExportAnalysisSpec)
    tutorial = getfield(@__MODULE__, :Tutorial)
    isdefined(tutorial, Symbol(spec.design)) ||
        throw(ArgumentError("F16ModelWorkshop.Tutorial has no analysis `$(spec.design)`"))
    inner = Base.invokelatest(getfield(tutorial, Symbol(spec.design)))
    hasproperty(inner, :Cfb) || throw(ArgumentError("`$(spec.design)` is not an LQG design analysis"))
    rows(M) = [collect(Float64.(r)) for r in eachrow(M)]
    Cfb = inner.Cfb
    controller = Dict{String, Any}("A" => rows(Cfb.A), "B" => rows(Cfb.B), "C" => rows(Cfb.C), "D" => rows(Cfb.D))
    spec.add_trim && (controller["y0"] = trim_asset("trim_controls"))
    path = _resolve_export(spec.file)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# LQG controller state space, written by ControllerExportAnalysis from `", spec.design, "`.")
        println(io, "# Applied to a state-space block with `apply \"dyad://F16ModelWorkshop/", basename(path), "\"`.")
        println(io, "# Matrices are nested arrays, row-major (outer array = first axis).")
        TOML.print(io, controller; sorted = true)
    end
    return ControllerExportAnalysisSolution(spec, inner, path, controller)
end

DyadInterface.symbolic_container(sol::ControllerExportAnalysisSolution) = symbolic_container(sol.inner)

function DyadInterface.AnalysisSolutionMetadata(sol::ControllerExportAnalysisSolution)
    inner_md = AnalysisSolutionMetadata(sol.inner)
    arts = ArtifactMetadata[ArtifactMetadata(:Controller, ArtifactType.Download, basename(sol.file),
        "The controller of `$(sol.spec.design)`, written to $(sol.file).")]
    append!(arts, inner_md.artifacts)
    return AnalysisSolutionMetadata(arts, inner_md.symbol_groups)
end

function DyadInterface.artifacts(sol::ControllerExportAnalysisSolution, name::Symbol)
    name === :Controller && return sol.file
    return artifacts(sol.inner, name)
end

export AbstractControllerExportAnalysisSpec, ControllerExportAnalysisSpec, ControllerExportAnalysisSolution
