# Transient analysis for models containing a clocked
# `DiscreteComponents.DiscreteStateSpace`, paired with the `partial analysis` in
# dyad/discrete_closed_loop_analysis.dyad. Defined BEFORE the generated code, which
# references the `*Spec` types.

import DyadInterface
import ModelingToolkit
import Symbolics
using DyadInterface: AbstractAnalysisSpec

abstract type AbstractDiscreteClosedLoopAnalysisSpec <: AbstractAnalysisSpec end

@kwdef mutable struct DiscreteClosedLoopAnalysisSpec <: AbstractDiscreteClosedLoopAnalysisSpec
    name::Symbol = :DiscreteClosedLoopAnalysis
    model::Union{Nothing, System} = nothing
    stop::Float64 = 10.0
    # Instance name of the clocked DiscreteStateSpace whose state needs seeding.
    controller_name::String = "controller"
    overrides::Dict{Symbolics.SymbolicT, Symbolics.SymbolicT} =
        Dict{Symbolics.SymbolicT, Symbolics.SymbolicT}()
end

"""
    seed_discrete_controller(overrides, model, controller_name) -> Dict

Copy of `overrides` with a zero entry added for every element of the clocked
controller's state that is not already present.

A clocked `DiscreteComponents.DiscreteStateSpace` declares its own initial state
(`initial x@(clk-1) = x_init_q`), but that lands in the system's initialization
equations, which `SynchToolkit.SyncODEProblemHook` does not read — it requires the
state to be present in the operating point and otherwise aborts problem
construction with "An initial value must be specified for shifted variable
<controller>₊x(t) at shift -1". Seeding the operating point per element supplies
what the hook demands; the values match the component's own zero default, so the
simulated trajectory is the one the block already specifies.

Passing an empty `controller_name` returns `overrides` unchanged, for models with
no clocked controller to seed.
"""
function seed_discrete_controller(overrides, model, controller_name::AbstractString)
    isempty(controller_name) && return copy(overrides)
    no_namespace_model = ModelingToolkit.toggle_namespacing(model, false)
    controller = getproperty(no_namespace_model, Symbol(controller_name))
    seeded = copy(overrides)
    for xi in Symbolics.scalarize(controller.x)
        haskey(seeded, xi) || push!(seeded, xi => 0.0)
    end
    return seeded
end

DyadInterface.run_analysis(spec::DiscreteClosedLoopAnalysisSpec) =
    DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(;
        name = :TransientAnalysis, model = spec.model, stop = spec.stop,
        overrides = seed_discrete_controller(spec.overrides, spec.model,
                                             spec.controller_name)))

export AbstractDiscreteClosedLoopAnalysisSpec, DiscreteClosedLoopAnalysisSpec
