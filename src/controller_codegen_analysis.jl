# Clocked-controller C export, paired with the `partial analysis` in
# dyad/controller_codegen_analysis.dyad. SynchToolkit compiles the model's whole-array
# `u` and `y` connectors straight into a synchronous node, and SynchJulia emits its C.

import SynchToolkit, SynchJulia

abstract type AbstractControllerCodegenAnalysisSpec <: AbstractAnalysisSpec end

@kwdef mutable struct ControllerCodegenAnalysisSpec <: AbstractControllerCodegenAnalysisSpec
    name::Symbol = :ControllerCodegenAnalysis
    model::Union{Nothing, System} = nothing
    export_dir::String = "generated_c/f16_controller"
    overrides::_Overrides = _Overrides()
end

struct ControllerCodegenAnalysisSolution
    spec::ControllerCodegenAnalysisSpec
    compiled
    export_dir::String
    files::Vector{String}
end

function DyadInterface.run_analysis(spec::ControllerCodegenAnalysisSpec)
    sys = spec.model
    top = ModelingToolkit.toggle_namespacing(sys, false)
    inputs = Any[
        SynchToolkit.ClockedInput(top.u),
        SynchToolkit.InputClock(ModelingToolkit.Clock(ControllerTs)),
        SynchToolkit.ParametersStruct(arg_name = :pars, struct_name = :Pars),
    ]
    compiled = SynchToolkit.stkcompile(sys; inputs, outputs = [SynchToolkit.ClockedOutput(top.y)])

    export_dir = _resolve_export(spec.export_dir)
    mkpath(export_dir)
    # SynchJulia writes its files read-only; make a previous export writable so this one
    # replaces every file instead of failing part-way.
    for f in readdir(export_dir; join = true)
        isfile(f) && chmod(f, 0o644)
    end
    SynchJulia.export_c(export_dir, SynchToolkit.node(compiled))
    return ControllerCodegenAnalysisSolution(spec, compiled, export_dir, sort(readdir(export_dir)))
end

export AbstractControllerCodegenAnalysisSpec, ControllerCodegenAnalysisSpec,
       ControllerCodegenAnalysisSolution
