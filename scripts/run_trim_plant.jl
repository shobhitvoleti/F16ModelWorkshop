# Export a trim point: trims the F16 plant and writes trim/trim_point.toml,
# keyed by the instance paths of the F16TrimmedPlantLinked component
# (`T_cmd.k`, ..., `plant.alpha_init`).
#
#   julia --project=. scripts/run_trim_plant.jl       # 1. export the trim point
#   julia --project=. scripts/run_trimmed_plant.jl    # 2. simulate from it
#
# F16TrimmedPlantLinked loads these values via F16ModelWorkshop.load_trim at
# build time, so once this file exists the trimmed scenario simulates directly.

using F16ModelWorkshop
using DyadInterface

res = F16ModelWorkshop.TrimPlantAnalysis()

path = artifacts(res, :TrimToml)      # Download artifact: path to the TOML
pset = artifacts(res, :TrimPoint)     # Native artifact: parameter set (nested Dict)

println("Trim parameter set written to: ", path)
println()
for section in sort(collect(keys(pset)))
    println("[", section, "]")
    for (k, v) in sort(collect(pset[section]); by = first)
        println("  ", rpad(k, 10), " = ", v)
    end
end
println()
println("Next: run F16TrimmedPlantLinkedAnalysis (it loads these values from the")
println("file at build time) — e.g. scripts/run_trimmed_plant.jl.")
