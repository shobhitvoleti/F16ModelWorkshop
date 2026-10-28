# Clocked-controller C export (dyad/controller_codegen_analysis.dyad). SynchToolkit compiles
# the model's whole-array `u` and `y` connectors into a synchronous node; SynchJulia emits its C.

import SynchToolkit, SynchJulia

abstract type AbstractControllerCodegenAnalysisSpec <: AbstractAnalysisSpec end

@kwdef mutable struct ControllerCodegenAnalysisSpec <: AbstractControllerCodegenAnalysisSpec
    name::Symbol = :ControllerCodegenAnalysis
    model::Union{Nothing, System} = nothing
    export_dir::String = "generated_c/f16_controller"
    overrides::_Overrides = _Overrides()
    __system::Union{Nothing, System} = nothing   # handed over by Dyad-generated specs; unused
end

"""
    ControllerCodegenAnalysisSolution

The `compiled` node, the `export_dir` and `files` written, and `check`, the `step_check`
table.
"""
struct ControllerCodegenAnalysisSolution <: AbstractAnalysisSolution
    spec::ControllerCodegenAnalysisSpec
    compiled
    export_dir::String
    files::Vector{String}
    check::DataFrames.DataFrame
end

Base.nameof(sol::ControllerCodegenAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::ControllerCodegenAnalysisSpec)
    sys = spec.model
    top = ModelingToolkit.toggle_namespacing(sys, false)
    pars = SynchToolkit.ParametersStruct(arg_name = :pars, struct_name = :Pars)
    inputs = Any[
        SynchToolkit.ClockedInput(top.u),
        SynchToolkit.InputClock(ModelingToolkit.Clock(ControllerTs)),
        pars,
    ]
    compiled = SynchToolkit.stkcompile(sys; inputs, outputs = [SynchToolkit.ClockedOutput(top.y)])

    export_dir = _resolve_export(spec.export_dir)
    mkpath(export_dir)
    # SynchJulia writes files read-only; make a previous export writable so this one
    # overwrites it instead of failing part-way.
    for f in readdir(export_dir; join = true)
        isfile(f) && chmod(f, 0o644)
    end
    SynchJulia.export_c(export_dir, SynchToolkit.node(compiled))
    return ControllerCodegenAnalysisSolution(spec, compiled, export_dir, sort(readdir(export_dir)),
        step_check(compiled, pars(compiled)))
end

"""
    step_check(compiled, pars; ticks = 200) -> DataFrame

Step `compiled` on `ticks` tracking errors and compare its commands with the recursion
`y = C x + D u + y0`, `x⁺ = A x + B u` of `discrete_controller.toml`, the controller the
model applies. One row per SynchJulia backend (`backend`, `ticks`, `max_abs_error`,
`status`). The C backend runs only when `Clang_unified_jll` is loaded, which SynchJulia
needs to build it.
"""
function step_check(compiled, pars; ticks = 200)
    d = TOML.parsefile(asset_path("discrete_controller.toml"))
    matrix(rows) = reduce(vcat, permutedims.(Vector{Float64}.(rows)))
    A, B, C, D = (matrix(d[k]) for k in ("A", "B", "C", "D"))
    y0 = Vector{Float64}(d["y0"])
    # Small tracking errors, different on every channel.
    us = [0.01 .* sin.((1:size(B, 2)) .* (k / 7)) for k in 1:ticks]
    x = zeros(size(A, 1))
    reference = map(us) do u
        y = C * x + D * u + y0
        x = A * x + B * u
        y
    end
    c_available = any(m -> nameof(m) === :Clang_unified_jll, values(Base.loaded_modules))
    rows = map((:julia, :c)) do backend
        if backend === :c && !c_available
            return (; backend = "C", ticks = 0, max_abs_error = NaN,
                status = "not run: load Clang_unified_jll to build the C")
        end
        exe = SynchJulia.SynchExecutable(compiled; backend)
        err = maximum(zip(us, reference)) do (u, y)
            maximum(abs, collect(SynchJulia.step!(exe, u, true, pars)[1]) .- y)
        end
        (; backend = backend === :c ? "C" : "Julia", ticks, max_abs_error = err,
            status = err < 1e-9 * maximum(abs, y0) ? "matches the designed controller" : "DIFFERS")
    end
    return DataFrames.DataFrame(collect(rows))
end

DyadInterface.symbolic_container(sol::ControllerCodegenAnalysisSolution) = sol.compiled

_codegen_artifact(file) = Symbol("file_", replace(file, r"[^A-Za-z0-9]" => "_"))

function DyadInterface.AnalysisSolutionMetadata(sol::ControllerCodegenAnalysisSolution)
    arts = ArtifactMetadata[
        ArtifactMetadata(:StepCheck, ArtifactType.DataFrame, "Generated code against the design",
            "The compiled controller stepped next to the designed state-space recursion."),
        ArtifactMetadata(:GeneratedFiles, ArtifactType.DataFrame, "Generated files",
            "The C sources written to $(sol.export_dir)."),
    ]
    for f in sol.files
        push!(arts, ArtifactMetadata(_codegen_artifact(f), ArtifactType.Download, f,
            "$(joinpath(sol.export_dir, f))"))
    end
    return AnalysisSolutionMetadata(arts, Dict{Symbol, Vector{Symbol}}())
end

function DyadInterface.artifacts(sol::ControllerCodegenAnalysisSolution, name::Symbol)
    name === :StepCheck && return sol.check
    name === :GeneratedFiles && return DataFrames.DataFrame(file = sol.files,
        bytes = [filesize(joinpath(sol.export_dir, f)) for f in sol.files])
    i = findfirst(f -> _codegen_artifact(f) === name, sol.files)
    i === nothing && throw(ArgumentError("ControllerCodegenAnalysis has no artifact $name"))
    return joinpath(sol.export_dir, sol.files[i])
end

export AbstractControllerCodegenAnalysisSpec, ControllerCodegenAnalysisSpec,
       ControllerCodegenAnalysisSolution
