module F16ModelWorkshop

using ModelingToolkit, OrdinaryDiffEqDefault, NonlinearSolve
import DyadInterface
import Symbolics
import TOML
import DataFrames
using DyadInterface: AbstractAnalysisSpec, AbstractAnalysisSolution, TransientAnalysisSpec,
                     AnalysisSolutionMetadata, ArtifactMetadata, ArtifactType,
                     artifacts, customizable_visualization, symbolic_container

# Controller sample period (s) of steps 3b, 4 and 6: the discrete LQG design's Ts and its clocks' period.
const ControllerTs = 0.01
export ControllerTs

# Relative paths resolve against the package root, independent of the working directory.
_project_root() = normpath(joinpath(@__DIR__, ".."))
_resolve_export(path::AbstractString) = isabspath(path) ? path : joinpath(_project_root(), path)

"""
    asset_path(parts...) -> String

Absolute path to a file under the package's `assets/`. Asset-valued component parameters
(e.g. the airframe mesh) are read at simulation time from any working directory, so they
must be absolute.
"""
asset_path(parts::AbstractString...) = joinpath(_project_root(), "assets", parts...)

"""
    trim_asset(name) -> Vector{Float64}

The `k` vector of a trim asset written by `TrimExportAnalysis`: `"trim_reference"`
(12 state set-points) or `"trim_controls"` (5 control offsets). `LQGDemo` seeds its
initialization guesses from these so it linearizes about the applied trim.
"""
trim_asset(name::AbstractString) = Float64.(TOML.parsefile(asset_path(name * ".toml"))["k"])

export asset_path, trim_asset

const _Overrides = Dict{Symbolics.SymbolicT, Symbolics.SymbolicT}

# Custom analyses: each file implements a `partial analysis` from dyad/. They precede the
# generated code, which subtypes and constructs their specs.
include("trim_export_analysis.jl")
include("visualize_analysis.jl")
include("controller_codegen_analysis.jl")
include("flight_analysis.jl")
include("gain_schedule_analysis.jl")
include("controller_export_analysis.jl")
include("envelope_analysis.jl")

include("../generated/module.jl")
include("velocity_mpc.jl")
include("envelope_mpc.jl")
include("scheduled_pid.jl")
export VelocityMPC, EnvelopeMPC, ScheduledPID

end
