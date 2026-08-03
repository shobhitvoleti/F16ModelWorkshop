
using F16ModelWorkshop
using DyadInterface
using SciMLBase
using Test

include("../generated/tests.jl")

# The Dyad-generated testsets above only check that models build. A closed loop can
# build, solve, and report retcode = Success while flying the aircraft into the
# ground, so assert the trajectory itself stays where the tutorial claims: a 10 deg
# pitch perturbation recovered about the 3000 m / 152.4 m/s trim.
#
# Bounds are loose next to the actual recovery (|phi| peaks near 0.8 rad, altitude
# holds within ~25 m) but tight enough to catch a departure. They fail if the applied
# controller assets stop matching the design in dyad/Tutorial/03_lqg_continuous.dyad.
@testset "closed loop stays near trim over the tutorial horizon" begin
    model = F16ModelWorkshop.Tutorial.DiscreteClosedLoopDemo(; name = :loop)
    sol = DyadInterface.run_analysis(
        F16ModelWorkshop.DiscreteClosedLoopAnalysisSpec(; model, stop = 10.0)).sol
    p = model.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 10.0
    @test maximum(abs, sol[p.phi]) < 0.5        # stays wings-level (design peaks near 0.007)
    @test maximum(abs, sol[p.theta]) < 0.4      # pitch recovers from the 0.175 rad kick
    @test all(2900 .< sol[p.alt] .< 3100)       # altitude held to ~100 m
    @test all(130 .< sol[p.vt] .< 170)          # airspeed returns toward the 152.4 trim
end
