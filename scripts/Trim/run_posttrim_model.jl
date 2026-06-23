# Simulate the trimmed plant. F16TrimmedPlantLinked loads its control inputs and
# plant initial conditions from trim/trim_point.toml (via F16ModelWorkshop.load_trim)
# at build time, so starting at the trim the states hold steady.
#
#   julia --project=. scripts/run_trim_plant.jl       # 1. export the trim point
#   julia --project=. scripts/run_trimmed_plant.jl    # 2. simulate from it
#
# (Run the export first — load_trim errors if trim/trim_point.toml is missing.)

using F16ModelWorkshop
using DyadInterface
using DyadInterface: symbolic_container

res = F16ModelWorkshop.Trimming.F16TrimmedPlantLinkedAnalysis()
sol = res.sol
m = symbolic_container(res)

println("retcode: ", sol.retcode)
println("Drift over the run (should be ~0 at a true trim):")
for s in ("vt", "alpha", "theta", "alt", "Q")
    series = sol[getproperty(m.plant, Symbol(s))]
    println("  ", rpad(s, 6), " start = ", first(series), "  end = ", last(series),
            "  Δ = ", last(series) - first(series))
end
