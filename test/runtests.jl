
using F16ModelWorkshop
using DyadInterface
using SciMLBase
using Test

include("../generated/tests.jl")

# Plant validation against the Stevens & Lewis F-16.
include("f16_snl_validation.jl")

const TRIM_ALPHA = 0.059129
const TRIM_ALT = 3000.0
const TRIM_VT = 152.4

# The generated testsets only check that models build. A closed loop can solve with
# retcode = Success while flying into the ground, so these assert the trajectory: a
# 10 deg pitch attitude recovered about the 3000 m / 152.4 m/s trim. They fail if the
# controller assets stop matching dyad/Tutorial/03_lqg_continuous.dyad. The airframe is
# statically unstable, so holding trim is the regulator's work;
# `Trimming.F16OpenLoopDeparture` is the same airframe without it.
@testset "discrete closed loop holds trim over the tutorial horizon" begin
    model = F16ModelWorkshop.Tutorial.DiscreteClosedLoopDemo(; name = :loop)
    sol = DyadInterface.run_analysis(
        DyadInterface.TransientAnalysisSpec(; model, stop = 10.0)).sol
    p = model.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 10.0
    @test maximum(abs, sol[p.phi]) < 0.01
    @test maximum(abs, sol[p.theta]) < 0.25         # recovers from the 0.175 rad attitude
    @test all(2990 .< sol[p.alt] .< 3020)
    @test all(148 .< sol[p.vt] .< 155)

    # Settled on trim, not merely bounded.
    @test sol[p.theta][end]≈TRIM_ALPHA atol=0.01
    @test sol[p.alt][end]≈TRIM_ALT atol=5.0
    @test sol[p.vt][end]≈TRIM_VT atol=2.0
end

@testset "continuous closed loop keeps the commands physical" begin
    model = F16ModelWorkshop.Tutorial.ContinuousClosedLoopDemo(; name = :cont)
    sol = DyadInterface.run_analysis(
        DyadInterface.TransientAnalysisSpec(; model, stop = 60.0)).sol
    p = model.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test all(>(0), sol[p.T])
    @test maximum(abs, sol[p.el]) < 25.0            # elevator travel limit
    @test sol[p.alt][end]≈TRIM_ALT atol=5.0
    @test sol[p.vt][end]≈TRIM_VT atol=2.0

    # The deck is fitted over alpha in [-2, 10] deg and the recovery dips a few degrees
    # below. `deck tracks the S&L tables` checks the extrapolation down to -6 deg, so
    # that bounds the range this trajectory may use.
    @test all(a -> -6 <= rad2deg(a) <= 10, sol[p.alpha])
end

@testset "open loop departs without the regulator" begin
    res = F16ModelWorkshop.Trimming.F16OpenLoopDepartureAnalysis()
    sol = res.sol
    p = DyadInterface.symbolic_container(res).plant

    @test SciMLBase.successful_retcode(sol.retcode)
    # Starts 1 deg nose-up of trim with the controls frozen; pitch diverges.
    offset = sol[p.theta] .- TRIM_ALPHA
    @test offset[end] > 5 * first(offset)
    @test sol[p.vt][end] < TRIM_VT - 10
end

include("analyses.jl")
include("lqg_design.jl")
include("gain_scheduled_pid.jl")
include("velocity_mpc.jl")
include("envelope_mpc.jl")
