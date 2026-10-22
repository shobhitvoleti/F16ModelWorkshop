# Transient analysis that renders its solution to a video, paired with the
# `partial analysis` in dyad/visualize_analysis.dyad. Defined BEFORE the generated
# code, which references the `*Spec` type.

import GeometryBasics
import MultibodyComponents

abstract type AbstractVisualizeAnalysisSpec <: AbstractAnalysisSpec end

@kwdef mutable struct VisualizeAnalysisSpec <: AbstractVisualizeAnalysisSpec
    name::Symbol = :VisualizeAnalysis
    model::Union{Nothing, System} = nothing
    stop::Float64 = 30.0
    filename::String = "assets/closed_loop.mp4"
    nominal_length::Float64 = 500.0
    camera::Vector{Float64} = [-500.0, 3200.0, 200.0]
    lookat::Vector{Float64} = [2000.0, 3000.0, 0.0]
    show_axis::Bool = false
    overrides::_Overrides = _Overrides()
end

# `MultibodyComponents.render` lives in that package's `Render` extension, which loads
# only once a Makie backend is present. Studio runs analyses in a session where nothing
# has loaded one, so load GLMakie, a dependency of this package, when it is missing.
const _GLMAKIE = Base.PkgId(Base.UUID("e9467ef8-e4e7-5192-8a1a-b1aee30e663a"), "GLMakie")

function _ensure_render_backend()
    Base.get_extension(MultibodyComponents, :Render) === nothing || return nothing
    Base.require(_GLMAKIE)
    Base.get_extension(MultibodyComponents, :Render) === nothing &&
        error("loading GLMakie did not load MultibodyComponents' `Render` extension")
    return nothing
end

function DyadInterface.run_analysis(spec::VisualizeAnalysisSpec)
    _ensure_render_backend()
    res = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(;
        name = :TransientAnalysis, model = spec.model, stop = spec.stop,
        overrides = spec.overrides))
    path = _resolve_export(spec.filename)
    mkpath(dirname(path))
    # `display = false`: this analysis exists to write a file. Letting the renderer
    # open its window segfaults outright in a session with no window server, and
    # would steal focus in one that has it. `invokelatest`, because the extension's
    # methods may have been defined after this function was compiled.
    Base.invokelatest(MultibodyComponents.render, res;
        filename = path,
        nominal_length = spec.nominal_length,
        x = spec.camera[1], y = spec.camera[2], z = spec.camera[3],
        lookat = GeometryBasics.Vec3f(spec.lookat...),
        show_axis = spec.show_axis,
        display = false)
    @info "Animation written to $path"
    return VisualizeAnalysisSolution(spec, res, res.sol, path)
end

"""
    VisualizeAnalysisSolution

The transient solution (`inner`, and its ODE solution as `sol`) and the `file` its
animation was written to.
"""
struct VisualizeAnalysisSolution{S, O} <: AbstractAnalysisSolution
    spec::VisualizeAnalysisSpec
    inner::S
    sol::O
    file::String
end

Base.nameof(sol::VisualizeAnalysisSolution) = sol.spec.name
DyadInterface.symbolic_container(sol::VisualizeAnalysisSolution) = symbolic_container(sol.inner)

function DyadInterface.AnalysisSolutionMetadata(sol::VisualizeAnalysisSolution)
    inner_md = AnalysisSolutionMetadata(sol.inner)
    arts = ArtifactMetadata[ArtifactMetadata(:Animation, ArtifactType.Download, basename(sol.file),
        "The 3-D animation of the flight, written to $(sol.file).")]
    append!(arts, transient_artifacts(inner_md))
    return AnalysisSolutionMetadata(arts, inner_md.symbol_groups)
end

function DyadInterface.artifacts(sol::VisualizeAnalysisSolution, name::Symbol)
    name === :Animation && return sol.file
    return artifacts(sol.inner, name)
end

DyadInterface.customizable_visualization(sol::VisualizeAnalysisSolution, vizspec) =
    customizable_visualization(sol.inner, vizspec)

export AbstractVisualizeAnalysisSpec, VisualizeAnalysisSpec, VisualizeAnalysisSolution
