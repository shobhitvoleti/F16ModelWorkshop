
using F16ModelWorkshop
using DyadInterface
using SciMLBase
using Test

include("../generated/tests.jl")

# Pins the plant to the Stevens & Lewis F-16: published trim, and the pitch
# instability the airframe is designed around.
include("f16_snl_validation.jl")

const TRIM_ALPHA = 0.059129
const TRIM_ALT = 3000.0
const TRIM_VT = 152.4

# The Dyad-generated testsets above only check that models build. A closed loop can
# build, solve, and report retcode = Success while flying the aircraft into the
# ground, so assert the trajectory itself: a 10 deg pitch attitude recovered about the
# 3000 m / 152.4 m/s trim. These fail if the applied controller assets stop matching
# the design in dyad/Tutorial/03_lqg_continuous.dyad.
#
# The aircraft is statically unstable, so holding trim here is entirely the
# regulator's doing — `Trimming.F16OpenLoopDeparture` is the same airframe without it.
@testset "discrete closed loop holds trim over the tutorial horizon" begin
    model = F16ModelWorkshop.Tutorial.DiscreteClosedLoopDemo(; name = :loop)
    sol = DyadInterface.run_analysis(
        F16ModelWorkshop.DiscreteClosedLoopAnalysisSpec(; model, stop = 10.0)).sol
    p = model.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 10.0
    @test maximum(abs, sol[p.phi]) < 0.01           # stays wings-level
    @test maximum(abs, sol[p.theta]) < 0.25         # recovers from the 0.175 rad attitude
    @test all(2990 .< sol[p.alt] .< 3020)
    @test all(148 .< sol[p.vt] .< 155)

    # Settled back onto the trim it started away from, not merely bounded.
    @test sol[p.theta][end]≈TRIM_ALPHA atol=0.01
    @test sol[p.alt][end]≈TRIM_ALT atol=5.0
    @test sol[p.vt][end]≈TRIM_VT atol=2.0
end

# Control effort is asserted on the continuous loop: in the sampled loop the commands
# live in the clocked partition, where `sol[...]` reports a single held value rather
# than the sampled sequence, so bounds there would pass without meaning anything.
@testset "continuous closed loop keeps the commands physical" begin
    model = F16ModelWorkshop.Tutorial.ContinuousClosedLoopDemo(; name = :cont)
    sol = DyadInterface.run_analysis(
        DyadInterface.TransientAnalysisSpec(; model, stop = 60.0)).sol
    p = model.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test all(>(0), sol[p.T])                       # no engine produces negative thrust
    @test maximum(abs, sol[p.el]) < 25.0            # inside the elevator's travel
    @test sol[p.alt][end]≈TRIM_ALT atol=5.0
    @test sol[p.vt][end]≈TRIM_VT atol=2.0

    # The deck is fitted over alpha in [-2, 10] deg and the recovery transient dips a
    # few degrees below that. `deck tracks the S&L tables` bounds the error out to
    # -6 deg, so that is the range this trajectory is allowed to use; past it the
    # extrapolation stops being checked and the trajectory stops meaning anything.
    @test all(a -> -6 <= rad2deg(a) <= 10, sol[p.alpha])
end

@testset "open loop departs without the regulator" begin
    res = DyadInterface.run_analysis(
        F16ModelWorkshop.Trimming.F16OpenLoopDepartureAnalysisSpec())
    sol = res.sol
    p = DyadInterface.symbolic_container(res).plant

    @test SciMLBase.successful_retcode(sol.retcode)
    # Started 1 deg nose-up of trim with the controls frozen: pitch runs away from it.
    offset = sol[p.theta] .- TRIM_ALPHA
    @test offset[end] > 5 * first(offset)
    @test sol[p.vt][end] < TRIM_VT - 10          # and bleeds airspeed doing it
end
