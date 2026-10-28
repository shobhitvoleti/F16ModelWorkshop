# Trim export (dyad/trim_export_analysis.dyad).
#
# The trim model declares its unknown controls and attitude `missing` (see
# `Tutorial.TrimDemo`); a zero-duration transient solve resolves them, and the operating
# point is written as the parameter sets every later model applies:
#
#   trim_point.toml      F16PlantModel initial conditions
#   trim_reference.toml  `k`: state set-points [npos,epos,alt,phi,theta,psi,vt,alpha,beta,P,Q,R]
#   trim_controls.toml   `k`: control offsets [T,el,ail,rud,lef]
#
# The model must name the plant `f16plant` and the commands `T_cmd`, `el_cmd`, `ail_cmd`,
# `rud_cmd`, `lef_cmd` (Constant blocks).

const _TRIM_CONTROLS = ("T", "el", "ail", "rud", "lef")
# (plant state, F16PlantModel initial-condition parameter)
const _TRIM_STATES = (
    ("npos", "npos_init"), ("epos", "epos_init"), ("alt", "alt_init"),
    ("phi", "phi_init"), ("theta", "theta_init"), ("psi", "psi_init"),
    ("vt", "vt_init"), ("alpha", "alpha_init"), ("beta", "beta_init"),
    ("P", "P_init"), ("Q", "Q_init"), ("R", "R_init"),
)
const _TRIM_FILES = (
    "trim_point" => [
        "# F16 trim operating point, applied to an F16PlantModel instance:",
        "#   F16PlantModel(apply \"dyad://F16ModelWorkshop/trim_point.toml\")",
        "# A named argument after the clause overrides it (last-wins), which is how a",
        "# scenario perturbs one state off trim.",
    ],
    "trim_reference" => [
        "# State set-points [npos,epos,alt,phi,theta,psi,vt,alpha,beta,P,Q,R],",
        "# applied to the 12-channel reference VectorConstant.",
    ],
    "trim_controls" => [
        "# Trim control offsets [T,el,ail,rud,lef], applied to the 5-channel",
        "# trim VectorConstant.",
    ],
)

# An inner transient analysis' artifacts without `:ObservablesTable`, which throws
# "Duplicate variable names" on these models: it names every element of an array
# observable (`y_out`, `u_in`, ...) after the array. Used by every transient-wrapping analysis.
transient_artifacts(md) = filter(a -> a.name !== :ObservablesTable, md.artifacts)

abstract type AbstractTrimExportAnalysisSpec <: AbstractAnalysisSpec end

"""
    TrimExportAnalysisSpec(; model, export_dir = "assets", abstol = 1e-6, reltol = 1e-6)

Trim `model` and write `trim_point.toml`, `trim_reference.toml` and `trim_controls.toml`
to `export_dir` (relative to the package root). The default `assets/` holds the operating
point the rest of the workshop applies; pass another directory to trim a different flight
condition without replacing it, or `""` to skip writing.
"""
@kwdef mutable struct TrimExportAnalysisSpec <: AbstractTrimExportAnalysisSpec
    name::Symbol = :TrimExportAnalysis
    model::Union{Nothing, System} = nothing
    export_dir::String = "assets"
    abstol::Float64 = 1e-6
    reltol::Float64 = 1e-6
    overrides::_Overrides = _Overrides()
    __system::Union{Nothing, System} = nothing   # handed over by Dyad-generated specs; unused
end

"""
    TrimExportAnalysisSolution

The zero-duration transient solution (`inner`), the operating point as `paramset` (one
table per asset: `"trim_point"`, `"trim_reference"`, `"trim_controls"`) and the paths
written (`files`, empty when `export_dir == ""`).
"""
struct TrimExportAnalysisSolution{S} <: AbstractAnalysisSolution
    spec::TrimExportAnalysisSpec
    inner::S
    paramset::Dict{String, Dict{String, Any}}
    files::Vector{String}
end

Base.nameof(sol::TrimExportAnalysisSolution) = sol.spec.name

# The trim is solved by a trust-region Newton method. The default initialization
# polyalgorithm tries Broyden, then Klement, whose diagonal Jacobian approximation cannot
# represent this problem: the trim Jacobian's diagonal is near zero (thrust ~1e-4,
# pitch ~3e-8), so Klement goes singular and throws before the Newton members run.
const _TRIM_INIT = SciMLBase.OverrideInit(; nlsolve = TrustRegion())

# A transient setup with its problem replaced, every other field kept.
_with_prob(setup, prob) = DyadInterface.TransientAnalysisSetup(
    (f === :prob ? prob : getfield(setup, f) for f in fieldnames(typeof(setup)))...)

function DyadInterface.run_analysis(spec::TrimExportAnalysisSpec)
    setup = DyadInterface.setup_analysis(TransientAnalysisSpec(;
        name = spec.name, model = spec.model, stop = 0.0,
        abstol = spec.abstol, reltol = spec.reltol, overrides = spec.overrides))
    setup = _with_prob(setup, remake(setup.prob; initializealg = _TRIM_INIT))
    inner = DyadInterface.run_analysis(setup)
    sol = inner.sol
    m = symbolic_container(inner)
    at_trim(x) = Float64(sol(0.0, idxs = x))

    plant_init = Dict{String, Any}(
        init => at_trim(getproperty(m.f16plant, Symbol(state))) for (state, init) in _TRIM_STATES)
    paramset = Dict{String, Dict{String, Any}}(
        "trim_point" => plant_init,
        "trim_reference" => Dict{String, Any}("k" => [plant_init[init] for (_, init) in _TRIM_STATES]),
        "trim_controls" => Dict{String, Any}(
            "k" => [at_trim(getproperty(m, Symbol(c, "_cmd")).k) for c in _TRIM_CONTROLS]),
    )

    files = String[]
    isempty(spec.export_dir) && return TrimExportAnalysisSolution(spec, inner, paramset, files)
    dir = _resolve_export(spec.export_dir)
    mkpath(dir)
    for (name, header) in _TRIM_FILES
        path = joinpath(dir, name * ".toml")
        open(path, "w") do io
            println(io, "# Auto-generated by TrimExportAnalysis (retcode = ", sol.retcode,
                        "). Do not edit — rerun the trim.")
            foreach(line -> println(io, line), header)
            TOML.print(io, paramset[name]; sorted = true)
        end
        push!(files, path)
    end
    return TrimExportAnalysisSolution(spec, inner, paramset, files)
end

# Display units of `trim_table`. Angles are shown in degrees; the assets keep the plant's radians.
const _TRIM_UNITS = Dict("npos" => "m", "epos" => "m", "alt" => "m", "vt" => "m/s",
    "phi" => "deg", "theta" => "deg", "psi" => "deg", "alpha" => "deg", "beta" => "deg",
    "P" => "deg/s", "Q" => "deg/s", "R" => "deg/s",
    "T" => "N", "el" => "deg", "ail" => "deg", "rud" => "deg", "lef" => "deg")
const _RADIAN_STATES = ("phi", "theta", "psi", "alpha", "beta", "P", "Q", "R")

"""
    trim_table(sol::TrimExportAnalysisSolution) -> DataFrame

The trimmed states and controls, one row each, with their units.
"""
function trim_table(sol::TrimExportAnalysisSolution)
    point = sol.paramset["trim_point"]
    controls = sol.paramset["trim_controls"]["k"]
    names = String[]; kinds = String[]; values = Float64[]
    for (state, init) in _TRIM_STATES
        push!(names, state); push!(kinds, "state")
        push!(values, state in _RADIAN_STATES ? rad2deg(point[init]) : point[init])
    end
    for (c, value) in zip(_TRIM_CONTROLS, controls)
        push!(names, c); push!(kinds, "control"); push!(values, value)
    end
    return DataFrames.DataFrame(name = names, kind = kinds, value = values,
        unit = [_TRIM_UNITS[n] for n in names])
end

# Studio interface: delegates to the inner transient solution and adds `:TrimTable`,
# `:TrimPoint` (nested Dict) and one download per exported file.
_file_artifact(path) = Symbol(first(splitext(basename(path))))

DyadInterface.symbolic_container(sol::TrimExportAnalysisSolution) = symbolic_container(sol.inner)

function DyadInterface.AnalysisSolutionMetadata(sol::TrimExportAnalysisSolution)
    inner_md = AnalysisSolutionMetadata(sol.inner)
    arts = ArtifactMetadata[
        ArtifactMetadata(:TrimTable, ArtifactType.DataFrame, "Trim",
            "The trimmed states and controls, with their units."),
        ArtifactMetadata(:TrimPoint, ArtifactType.Native, "Trim point",
            "Trimmed operating point, one table per exported asset file."),
    ]
    for path in sol.files
        push!(arts, ArtifactMetadata(_file_artifact(path), ArtifactType.Download,
            basename(path), "Parameter set written to $path."))
    end
    append!(arts, transient_artifacts(inner_md))
    return AnalysisSolutionMetadata(arts, inner_md.symbol_groups)
end

function DyadInterface.artifacts(sol::TrimExportAnalysisSolution, name::Symbol)
    name === :TrimTable && return trim_table(sol)
    name === :TrimPoint && return sol.paramset
    i = findfirst(path -> _file_artifact(path) === name, sol.files)
    i === nothing || return sol.files[i]
    return artifacts(sol.inner, name)
end

DyadInterface.customizable_visualization(sol::TrimExportAnalysisSolution, vizspec) =
    customizable_visualization(sol.inner, vizspec)

export AbstractTrimExportAnalysisSpec, TrimExportAnalysisSpec, TrimExportAnalysisSolution
