# ---------------------------------------------------------------------------
# Trim-point I/O helpers
#
# `load_trim` reads a single scalar out of the trim TOML written by
# `TrimPlantAnalysis`. It is meant to be called directly from Dyad parameter
# defaults so a component loads its initials / source-block values from the file
# at build time, e.g. in dyad/Trimming/f16_trimmed_plant_linked.dyad:
#
#   T_cmd = BlockComponents.Sources.Constant(
#             k = F16ModelWorkshop.load_trim("trim/trim_point.toml", "T_cmd.k"))
#   plant = F16ModelWorkshop.Plant.F16PlantModel(
#             alpha_init = F16ModelWorkshop.load_trim("trim/trim_point.toml", "plant.alpha_init"), ...)
#
# The dotted key is the instance path into the trim point (`T_cmd.k`,
# `plant.alpha_init`, ...).
#
# This file is included BEFORE the generated code so the function is available
# to Dyad components at construction time (see functions.md).
# ---------------------------------------------------------------------------

import TOML

# Package root, resolved against this file so relative trim paths are stable
# no matter what working directory a component/analysis is built from.
_project_root() = normpath(joinpath(@__DIR__, ".."))

"""
    default_trim_path() -> String

Default location of the trim parameter-set TOML: `<project>/trim/trim_point.toml`.
Shared by `TrimPlantAnalysis` (export) and [`load_trim`](@ref) (build-time import).
"""
default_trim_path() = joinpath(_project_root(), "trim", "trim_point.toml")

"""
    load_trim(path, key) -> Float64
    load_trim(key)       -> Float64

Read a single scalar value out of a trim parameter-set TOML.

`key` is a dotted path into the TOML table matching the parameter set's instance
paths, e.g. `"T_cmd.k"` or `"plant.alpha_init"`. A relative `path` is resolved
against the package root, so a bare `"trim/trim_point.toml"` works from anywhere.
The single-argument form uses [`default_trim_path`](@ref).

Returns a `Float64` so the result can be used directly as a `Real` parameter
default in a Dyad component. Throws a descriptive error if the file or key is
missing — typically because `TrimPlantAnalysis` has not been run yet.
"""
function load_trim(path::AbstractString, key::AbstractString)::Float64
    file = isabspath(path) ? path : joinpath(_project_root(), path)
    isfile(file) || error(
        "Trim file not found: $file\n" *
        "Run `F16ModelWorkshop.TrimPlantAnalysis()` first to generate it.")
    data = TOML.parsefile(file)
    val = data
    for part in split(key, '.')
        (val isa AbstractDict && haskey(val, part)) ||
            error("Key \"$key\" not found in trim file $file")
        val = val[part]
    end
    val isa Real || error("Trim value at \"$key\" is not numeric: $(repr(val))")
    return Float64(val)
end

load_trim(key::AbstractString) = load_trim(default_trim_path(), key)
