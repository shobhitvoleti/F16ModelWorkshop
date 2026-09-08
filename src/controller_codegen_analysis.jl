# Discrete-controller C export, paired with the `partial analysis` in
# dyad/controller_codegen_analysis.dyad. `ModelingToolkit.isolate_subsystem` cuts the
# model at its input and output analysis points so only the clocked controller between
# them remains; SynchToolkit compiles that to a synchronous node and SynchCompiler
# emits the C sources.

import SynchToolkit, SynchCompiler

abstract type AbstractControllerCodegenAnalysisSpec <: AbstractAnalysisSpec end

@kwdef mutable struct ControllerCodegenAnalysisSpec <: AbstractControllerCodegenAnalysisSpec
    name::Symbol = :ControllerCodegenAnalysis
    model::Union{Nothing, System} = nothing
    inputs::Vector{String} = String[]
    outputs::Vector{String} = String[]
    export_dir::String = "generated_c/f16_controller"
    overrides::_Overrides = _Overrides()
end

struct ControllerCodegenAnalysisSolution
    spec::ControllerCodegenAnalysisSpec
    system::System
    input_vars::Vector
    output_vars::Vector
    compiled
    export_dir::String
    files::Vector{String}
end

function DyadInterface.run_analysis(spec::ControllerCodegenAnalysisSpec)
    input_aps = Symbol.(spec.inputs)
    output_aps = Symbol.(spec.outputs)
    controller_sys, input_vars, output_vars = ModelingToolkit.isolate_subsystem(
        spec.model, input_aps, output_aps)

    # The hierarchical system is what gets compiled; the un-namespaced view only selects
    # the interface symbols. Inputs are the clocked scalars entering the input mux plus
    # the controller clock, parameters are gathered into one generated struct, and the
    # outputs are the clocked scalars leaving the output demux.
    nsys = ModelingToolkit.toggle_namespacing(controller_sys, false)
    in_syms = [ModelingToolkit.unwrap(getproperty(nsys.input_mux, Symbol("u", i)))
               for i in eachindex(input_vars)]
    out_syms = [ModelingToolkit.unwrap(getproperty(nsys.output_demux, Symbol("y", i)))
                for i in eachindex(output_vars)]
    auto_struct = SynchToolkit.ParametersStruct(arg_name = :auto, struct_name = :AutoPars)
    codegen_inputs = Any[
        [SynchToolkit.ClockedInput(v) for v in in_syms]...,
        SynchToolkit.InputClock(ModelingToolkit.Clock(ControllerTs)),
        auto_struct,
    ]
    codegen_outputs = Any[SynchToolkit.ClockedOutput(v) for v in out_syms]

    compiled = SynchToolkit.stkcompile(
        controller_sys; inputs = codegen_inputs, outputs = codegen_outputs)
    export_dir = _resolve_export(spec.export_dir)
    mkpath(export_dir)
    # SynchCompiler writes its runtime header read-only. Make a previous export writable
    # first so re-exporting replaces every file instead of failing after the sources.
    for f in readdir(export_dir; join = true)
        isfile(f) && chmod(f, 0o644)
    end
    SynchCompiler.export_c(export_dir, SynchToolkit.node(compiled))
    files = sort(readdir(export_dir))
    return ControllerCodegenAnalysisSolution(
        spec, controller_sys, input_vars, output_vars, compiled, export_dir, files)
end

export AbstractControllerCodegenAnalysisSpec, ControllerCodegenAnalysisSpec,
       ControllerCodegenAnalysisSolution
