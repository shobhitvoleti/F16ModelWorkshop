using Test
using LinearAlgebra
using F16ModelWorkshop
using F16ModelWorkshop.VelocityMPC
using DyadInterface
using SciMLBase

# `VectorSelect` narrows the plant's twelve outputs to the ten the controller regulates,
# so a wrong or reordered selection would feed the observer the wrong states. The Dyad
# test model drives two integrators from the picked channels; their values at t = 1 s are
# the picked channels themselves.
@testset "vector channel selector" begin
    result = F16ModelWorkshop.VectorBlocks.TestVectorSelectTransient()
    sol = result.sol
    model = DyadInterface.symbolic_container(result)

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol[model.pick_first.x][end]≈4.0 atol=1e-6
    @test sol[model.pick_second.x][end]≈2.0 atol=1e-6
end

# The bank is designed in Julia from the compiled plant, so the plant and its symbolic
# linearization are checked on their own terms: every knot trims, and the Jacobians the
# members are built from agree with the nonlinear plant they came from.
@testset "velocity MPC bank" begin
    plant = VelocityMPC.dynamics()

    for velocity in VelocityMPC.KNOTS
        trim = trim_point(plant, velocity; altitude = VelocityMPC.ALTITUDE)
        @test trim.residual_norm < 1e-7
        u = trim.u ./ VelocityMPC.CONTROL_UNITS
        @test 0 < u[1] < 50
        @test abs(u[2]) < 25

        # The symbolic Jacobians against an independent central difference.
        model = linear_model(plant, trim.x, trim.u)
        Afd, Bfd = zeros(12, 12), zeros(12, 4)
        for k in eachindex(trim.x)
            h = 1e-5 * max(1, abs(trim.x[k]))
            up, um = copy(trim.x), copy(trim.x)
            up[k] += h
            um[k] -= h
            Afd[:, k] = (plant(up, trim.u) - plant(um, trim.u)) / (2h)
        end
        for k in eachindex(trim.u)
            h = 1e-5 * max(1, abs(trim.u[k]))
            up, um = copy(trim.u), copy(trim.u)
            up[k] += h
            um[k] -= h
            Bfd[:, k] = (plant(trim.x, up) - plant(trim.x, um)) / (2h)
        end
        @test model.Ac≈Afd rtol=1e-6 atol=1e-7
        @test model.Bc≈Bfd rtol=1e-6 atol=1e-7
    end
end

# Every member must be exact at its own trim: held at the state it was designed around,
# with the trimmed command already applied, it must return that command and nothing else.
# A bank's members have no public accessor (MPCComponents.jl#48), so the property is
# asserted on the scheduled components themselves: `VelocityMPCHoldsTrim` feeds them a
# constant trimmed state as both measurement and reference, one knot per analysis.
@testset "bank members hold their own trim" begin
    knots = (F16ModelWorkshop.Tutorial.VelocityMPCHoldsTrimLowTransient => 140.0,
             F16ModelWorkshop.Tutorial.VelocityMPCHoldsTrimMidTransient => 152.4,
             F16ModelWorkshop.Tutorial.VelocityMPCHoldsTrimHighTransient => 170.0)

    for (analysis, velocity) in knots
        result = analysis()
        sol = result.sol
        model = DyadInterface.symbolic_container(result)
        held = (model.T_cmd, model.el_cmd, model.ail_cmd, model.rud_cmd)
        expected = VelocityMPC.trim_command(velocity)

        @test SciMLBase.successful_retcode(sol.retcode)
        # A held signal reads back on the controller's clock, one entry per tick: twenty of
        # them over a second at 20 Hz, starting at the t = 0 tick, so every entry is a
        # solved command and none is a hold's initial value.
        @test length(sol[model.exitflag]) == 20
        @test all(>=(1), sol[model.exitflag])
        for (channel, signal) in pairs(held)
            @test maximum(abs, sol[signal] .- expected[channel]) < 1e-5
        end
    end
end

@testset "velocity MPC bank rejects unusable designs" begin
    @test_throws "strictly increasing" VelocityMPC.bank([160.0, 140.0])
    @test_throws "at least two knots" VelocityMPC.bank([152.4])
    @test_throws "outside the design grid" VelocityMPC.bank(VelocityMPC.KNOTS, 3000.0, 100.0)
    @test_throws "Ts must be positive" VelocityMPC.bank(VelocityMPC.KNOTS, 3000.0, 148.0, 0.0)
    @test_throws "umin must be below umax" VelocityMPC.bank(; umax = zeros(4))
    @test_throws "rate must be positive" VelocityMPC.bank(; rate = zeros(4))
end

# The closed loop: a solved trajectory, not just a model that builds. The tolerances are
# a little wider than the design achieves, tight enough that a broken schedule, a lost
# reference channel or an infeasible QP fails here.
@testset "velocity MPC tracks the airspeed ramp" begin
    result = F16ModelWorkshop.Tutorial.TutorialVelocityMPC()
    sol = result.sol
    loop = DyadInterface.symbolic_container(result)
    p = loop.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 25.0

    # Accelerated onto the commanded 160 m/s while holding altitude and wings level.
    @test sol[p.vt][end]≈160.0 atol=0.5
    @test sol[p.alt][end]≈3000.0 atol=10.0
    @test maximum(abs, sol[p.phi]) < 0.02
    @test maximum(abs, sol[p.theta]) < 0.25
    # The ramp crosses the middle knot, so both of the outer members are scheduled in.
    @test maximum(sol[p.vt]) > 153.0

    # Held commands stay inside the limits the QP was given (thrust in newtons here).
    @test all(-1.0 .<= sol[p.T] .<= 5.0e4)
    @test maximum(abs, sol[p.el]) <= 25.0
    @test maximum(abs, sol[p.ail]) <= 21.5
    @test maximum(abs, sol[p.rud]) <= 30.0

    # Every solve reported success; a negative composite flag is a failed member.
    @test all(>=(1), sol[loop.exitflag])
end
