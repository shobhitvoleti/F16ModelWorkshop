# ---------------------------------------------------------------------------
# TrimPlantAnalysis — a custom Dyad/DyadInterface analysis that trims the F16
# plant and exports the operating point as a native Dyad **parameter set** TOML.
#
# It reuses the tutorial trim model (`Tutorial.TrimDemo`), which solves for the
# unknown control inputs and angles via a zero-duration TransientAnalysis, then
# reads the full trimmed operating point (5 control inputs + 12 plant states)
# out of the solution and writes it to `spec.export_path`.
#
# The TOML is laid out keyed by the **instance paths** of the
# `F16TrimmedPlantLinked` example component (see
# dyad/Trimming/f16_trimmed_plant_linked.dyad):
#
#     [T_cmd]
#     k = 28696.23
#     ...
#     [plant]
#     alpha_init = -0.01695
#     ...
#
# so F16TrimmedPlantLinked can pull each value with
# `load_trim("trim/trim_point.toml", "T_cmd.k")` / `"plant.alpha_init"` at build
# time. Literal values only.
#
# Usage (Julia):
#   using F16ModelWorkshop
#   res  = F16ModelWorkshop.TrimPlantAnalysis()      # writes trim/trim_point.toml
#   path = artifacts(res, :TrimToml)                 # Download artifact (file path)
#   pset = artifacts(res, :TrimPoint)                # Native artifact (nested Dict)
#
# Then run `F16TrimmedPlantLinkedAnalysis`, which loads these values via
# load_trim at build time.
#
# This file is included AFTER the generated code because it references the
# generated `Tutorial.TrimDemo` component.
# ---------------------------------------------------------------------------

import DyadInterface
import TOML
using DyadInterface: AbstractAnalysisSolution, AnalysisSolutionMetadata,
                     ArtifactMetadata, ArtifactType, TransientAnalysisSpec,
                     artifacts, customizable_visualization, symbolic_container

# Control inputs: trim-model instance name (`<key>_cmd`) -> parameter set section.
const _TRIM_INPUTS = ("T", "el", "ail", "rud", "lef")
# Plant states: (state variable on the trim model's plant) => (F16PlantModel
# initial-condition parameter the value seeds in F16TrimmedPlantLinked's `plant`).
const _TRIM_STATES = (
    ("npos", "npos_init"), ("epos", "epos_init"), ("alt", "alt_init"),
    ("phi", "phi_init"), ("theta", "theta_init"), ("psi", "psi_init"),
    ("vt", "vt_init"), ("alpha", "alpha_init"), ("beta", "beta_init"),
    ("P", "P_init"), ("Q", "Q_init"), ("R", "R_init"),
)

# `default_trim_path()` is defined in trim_io.jl (included before the generated
# code) and shared with the build-time `load_trim` import helper.

"""
    TrimPlantAnalysisSpec(; name, model, export_path, abstol, reltol)

Specification for [`TrimPlantAnalysis`](@ref). Wraps a zero-duration transient
(initialization) solve of a trim model and exports the trimmed operating point
as a Dyad parameter-set TOML.

# Keyword arguments
  - `model`: the trim component to solve. Defaults to `Tutorial.TrimDemo()`,
    whose missing control inputs / angles become the trim unknowns.
  - `export_path`: where the parameter-set TOML is written. Defaults to
    [`default_trim_path`](@ref) (`<project>/trim/trim_point.toml`).
  - `abstol`, `reltol`: tolerances passed to the underlying initialization solve.
"""
Base.@kwdef mutable struct TrimPlantAnalysisSpec <: DyadInterface.AbstractAnalysisSpec
    name::Symbol = :TrimPlantAnalysis
    model::Union{Nothing, System} = Tutorial.TrimDemo(; name = :TrimDemo)
    export_path::String = default_trim_path()
    abstol::Float64 = 1e-6
    reltol::Float64 = 1e-6
end

"""
    TrimPlantAnalysisSolution

Result of [`TrimPlantAnalysis`](@ref). Wraps the underlying transient solution
and the exported parameter set. Adds two artifacts on top of the standard
transient ones: `:TrimToml` (a `Download` — the path to the written TOML) and
`:TrimPoint` (a `Native` — the parameter set as a nested `Dict`).
"""
struct TrimPlantAnalysisSolution{S} <: AbstractAnalysisSolution
    spec::TrimPlantAnalysisSpec
    inner::S                 # underlying TransientAnalysisSolution
    paramset::Dict{String, Any}  # nested dict serialized to TOML (parameter set)
    path::String             # absolute path of the written TOML
end

Base.nameof(sol::TrimPlantAnalysisSolution) = sol.spec.name

function DyadInterface.run_analysis(spec::TrimPlantAnalysisSpec)
    # Trim is a zero-duration transient: the initialization solver resolves the
    # missing inputs/angles to the equilibrium operating point at t = 0.
    base = TransientAnalysisSpec(;
        name = spec.name, model = spec.model, stop = 0.0,
        abstol = spec.abstol, reltol = spec.reltol)
    inner = DyadInterface.run_analysis(base)

    sol = inner.sol
    m = symbolic_container(inner)
    plant = m.f16plant

    # Keyed by F16TrimmedPlantLinked instance paths. Each control input is its
    # own Constant subcomponent (`<name>_cmd.k`); the states seed the `plant`
    # subcomponent's initial-condition parameters.
    paramset = Dict{String, Any}()
    for k in _TRIM_INPUTS
        cmd = getproperty(m, Symbol(k * "_cmd"))
        paramset[k * "_cmd"] = Dict{String, Any}("k" => Float64(sol(0.0, idxs = cmd.k)))
    end
    plant_params = Dict{String, Any}()
    for (state, init_param) in _TRIM_STATES
        plant_params[init_param] = Float64(sol(0.0, idxs = getproperty(plant, Symbol(state))))
    end
    paramset["plant"] = plant_params

    path = abspath(spec.export_path)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# F16 trim point — auto-generated by TrimPlantAnalysis.")
        println(io, "# Keyed by F16TrimmedPlantLinked instance paths; loaded via")
        println(io, "# F16ModelWorkshop.load_trim(\"trim/trim_point.toml\", \"<instance>.<param>\").")
        println(io, "# retcode = ", sol.retcode)
        TOML.print(io, paramset; sorted = true)
    end

    _write_trim_assets(plant_params, paramset, sol.retcode)

    return TrimPlantAnalysisSolution(spec, inner, paramset, path)
end

# Emit the same operating point as package assets, in the shape Dyad's `apply`
# operator consumes: each file's keys are the parameter names of the component it is
# applied to, so a model states the whole operating point in one clause
# (`F16PlantModel(apply "dyad://F16ModelWorkshop/trim_point.toml")`) instead of a
# load_trim call per value. Written alongside the instance-keyed parameter set above,
# which the pre-`apply` load_trim call sites still read.
function _write_trim_assets(plant_params, paramset, retcode)
    dir = joinpath(_project_root(), "assets")
    mkpath(dir)
    banner = "# Auto-generated by TrimPlantAnalysis (retcode = $retcode). Do not edit — rerun the trim analysis."

    # F16PlantModel initial-condition parameters.
    open(joinpath(dir, "trim_point.toml"), "w") do io
        println(io, banner)
        println(io, "# F16 trim operating point, applied to an F16PlantModel instance:")
        println(io, "#   F16PlantModel(apply \"dyad://F16ModelWorkshop/trim_point.toml\")")
        println(io, "# A named argument after the clause overrides it (last-wins), which is how a")
        println(io, "# scenario perturbs one state off trim.")
        TOML.print(io, plant_params; sorted = true)
    end

    # Vector sources: `k` is the parameter name on VectorConstant.
    open(joinpath(dir, "trim_reference.toml"), "w") do io
        println(io, banner)
        println(io, "# State set-points [npos,epos,alt,phi,theta,psi,vt,alpha,beta,P,Q,R],")
        println(io, "# applied to the 12-channel reference VectorConstant.")
        TOML.print(io, Dict("k" => [plant_params[p] for (_, p) in _TRIM_STATES]))
    end
    open(joinpath(dir, "trim_controls.toml"), "w") do io
        println(io, banner)
        println(io, "# Trim control offsets [T,el,ail,rud,lef], applied to the 5-channel")
        println(io, "# trim VectorConstant.")
        TOML.print(io, Dict("k" => [paramset[k * "_cmd"]["k"] for k in _TRIM_INPUTS]))
    end
    return nothing
end

TrimPlantAnalysis(; kwargs...) = DyadInterface.run_analysis(TrimPlantAnalysisSpec(; kwargs...))

# --- AbstractAnalysisSolution interface (delegate to the inner transient) ----

DyadInterface.symbolic_container(sol::TrimPlantAnalysisSolution) =
    symbolic_container(sol.inner)

function DyadInterface.AnalysisSolutionMetadata(sol::TrimPlantAnalysisSolution)
    inner_md = AnalysisSolutionMetadata(sol.inner)
    arts = ArtifactMetadata[
        ArtifactMetadata(:TrimToml, ArtifactType.Download, "Trim point (parameter set TOML)",
            "Trimmed operating point as a Dyad parameter set written to $(sol.path)."),
        ArtifactMetadata(:TrimPoint, ArtifactType.Native, "Trim point (Dict)",
            "Trimmed operating point parameter set as a nested Julia Dict."),
    ]
    append!(arts, inner_md.artifacts)
    return AnalysisSolutionMetadata(arts, inner_md.symbol_groups)
end

function DyadInterface.artifacts(sol::TrimPlantAnalysisSolution, name::Symbol)
    if name === :TrimToml
        return sol.path
    elseif name === :TrimPoint
        return sol.paramset
    else
        return artifacts(sol.inner, name)
    end
end

DyadInterface.customizable_visualization(sol::TrimPlantAnalysisSolution, vizspec) =
    customizable_visualization(sol.inner, vizspec)

export TrimPlantAnalysis, TrimPlantAnalysisSpec
