module F16ModelWorkshop

using ModelingToolkit, OrdinaryDiffEqDefault, NonlinearSolve
import DyadInterface
import Symbolics
import TOML
using DyadInterface: AbstractAnalysisSpec, AbstractAnalysisSolution, TransientAnalysisSpec

# Controller sample period. Dyad components reference it as a parameter default: the
# VectorClock period of the sampled loop and the Ts of the discrete LQG design.
const ControllerTs = 0.01
export ControllerTs

# Paths resolve against the package root, so models and analyses behave the same from
# any working directory.
_project_root() = normpath(joinpath(@__DIR__, ".."))
_resolve_export(path::AbstractString) = isabspath(path) ? path : joinpath(_project_root(), path)

"""
    asset_path(parts...) -> String

Absolute path to a file under the package's `assets/` directory. Component parameters
that name an asset (the airframe mesh, for one) are read when the model is simulated,
which may be from any working directory, so they must not be relative.
"""
asset_path(parts::AbstractString...) = joinpath(_project_root(), "assets", parts...)

"""
    trim_asset(name) -> Vector{Float64}

The `k` vector of one of the vector-valued trim assets written by `TrimExportAnalysis`:
`"trim_reference"` (12 state set-points) or `"trim_controls"` (5 control offsets).
`LQGDemo` seeds its initialization guesses from these, so the point it is linearized
about is the applied trim.
"""
trim_asset(name::AbstractString) = Float64.(TOML.parsefile(asset_path(name * ".toml"))["k"])

export asset_path, trim_asset

const _Overrides = Dict{Symbolics.SymbolicT, Symbolics.SymbolicT}

# Custom analyses. Each pairs a `partial analysis` in dyad/ with a spec and
# `run_analysis` here; both are defined before the generated code, which extends them.
include("trim_export_analysis.jl")
include("visualize_analysis.jl")
include("controller_codegen_analysis.jl")

include("../generated/module.jl")
include("velocity_mpc.jl")
export VelocityMPC

end
