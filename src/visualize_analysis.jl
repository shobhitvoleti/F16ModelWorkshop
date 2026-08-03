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
    controller_name::String = ""
    filename::String = "assets/closed_loop.mp4"
    nominal_length::Float64 = 500.0
    camera::Vector{Float64} = [-500.0, 3200.0, 200.0]
    lookat::Vector{Float64} = [2000.0, 3000.0, 0.0]
    show_axis::Bool = false
    overrides::_SymPair = _SymPair()
end

# `MultibodyComponents.render` lives in that package's `Render` extension, which loads
# only once a Makie backend is present. Without one the function exists but has no
# methods, so check for the extension and say what to load rather than surfacing a
# MethodError.
function _assert_render_backend()
    if Base.get_extension(MultibodyComponents, :Render) === nothing
        error("""
              MultibodyComponents' `Render` extension is not loaded, so this analysis \
              cannot write its animation. Load a Makie backend first:

                  using GLMakie
              """)
    end
    return nothing
end

function DyadInterface.run_analysis(spec::VisualizeAnalysisSpec)
    _assert_render_backend()
    res = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(;
        name = :TransientAnalysis, model = spec.model, stop = spec.stop,
        overrides = seed_discrete_controller(spec.overrides, spec.model,
                                             spec.controller_name)))
    path = _resolve_export(spec.filename)
    mkpath(dirname(path))
    # `display = false`: this analysis exists to write a file. Letting the renderer
    # open its window segfaults outright in a session with no window server, and
    # would steal focus in one that has it.
    MultibodyComponents.render(res;
        filename = path,
        nominal_length = spec.nominal_length,
        x = spec.camera[1], y = spec.camera[2], z = spec.camera[3],
        lookat = GeometryBasics.Vec3f(spec.lookat...),
        show_axis = spec.show_axis,
        display = false)
    @info "Animation written to $path"
    return res
end

export AbstractVisualizeAnalysisSpec, VisualizeAnalysisSpec
