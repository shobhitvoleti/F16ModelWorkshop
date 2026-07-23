# Tutorial step 1 export: trim the tutorial plant (Tutorial.TrimDemo) and write
# the operating point to trim/tutorial_trim_point.toml. Leaves the committed
# trim/trim_point.toml (loaded by steps 03/04 at build time) untouched.
#
#   julia --project=. scripts/Tutorial/run_trim_export.jl

using F16ModelWorkshop
using DyadInterface

res  = F16ModelWorkshop.Tutorial.TutorialTrimExport()
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
