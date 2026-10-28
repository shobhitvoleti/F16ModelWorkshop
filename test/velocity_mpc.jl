using Test
using F16ModelWorkshop
using F16ModelWorkshop.VelocityMPC
using DyadInterface
using SciMLBase

# `VectorSelect` narrows the plant's twelve outputs to the ten the controller regulates; a
# wrong or reordered selection would feed the observer the wrong states. The test model
# integrates two picked channels, so the integrals at t = 1 s equal the channels.
@testset "vector channel selector" begin
    result = F16ModelWorkshop.VectorBlocks.TestVectorSelectTransient()
    sol = result.sol
    model = DyadInterface.symbolic_container(result)

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol[model.pick_first.x][end]≈4.0 atol=1e-6
    @test sol[model.pick_second.x][end]≈2.0 atol=1e-6
end

# One second of a constant-signal check model: twenty ticks of the 20 Hz controller.
check(model) = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(; model, stop = 1.0))

# The bank is designed in Julia from the compiled plant: every knot must trim, and the
# symbolic Jacobians the members are built from must agree with the nonlinear plant.
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

# Each member is exact at its own trim: held at its design state with the trimmed command
# applied, it returns that command. Bank members have no public accessor
# (MPCComponents.jl#48), so `VelocityMPCHoldsTrim` feeds the scheduled components a constant
# trimmed state as both measurement and reference, one model per knot.
@testset "bank members hold their own trim" begin
    for velocity in VelocityMPC.KNOTS
        result = check(F16ModelWorkshop.Tests.VelocityMPCHoldsTrim(; name = :holds, velocity))
        sol = result.sol
        model = DyadInterface.symbolic_container(result)
        held = (model.T_cmd, model.el_cmd, model.ail_cmd, model.rud_cmd)
        expected = VelocityMPC.trim_command(velocity)

        @test SciMLBase.successful_retcode(sol.retcode)
        # One entry per controller tick, twenty at 20 Hz starting at t = 0: every entry is a
        # solved command, none a hold's initial value.
        @test length(sol[model.exitflag]) == 20
        @test all(>=(1), sol[model.exitflag])
        for (channel, signal) in pairs(held)
            @test maximum(abs, sol[signal] .- expected[channel]) < 1e-5
        end
    end
end

# Each member's terminal weight is the Riccati cost-to-go of its stage cost, so its
# unconstrained optimum is the infinite-horizon discrete LQR and independent of the
# horizon. `VelocityMPCMemberIsLQR` holds the reference at a knot's trim and the
# measurement a fixed `dx` away, so every tick must return `u - K * dx`.
@testset "unconstrained member equals LQR" begin
    Ts = 0.05
    # Every knot on the default forty-step horizon, and the middle knot on five steps.
    runs = [[(velocity, 40) for velocity in VelocityMPC.KNOTS]; (152.4, 5)]

    commands = Dict{Tuple{Float64,Int},Vector{Float64}}()
    for (velocity, Np) in runs
        result = check(F16ModelWorkshop.Tests.VelocityMPCMemberIsLQR(; name = :lqr, velocity, Np))
        sol = result.sol
        model = DyadInterface.symbolic_container(result)
        @test SciMLBase.successful_retcode(sol.retcode)

        # `dx` is read from the model, so its Dyad default is the only copy: 0.006 of the
        # Bryson state scales, a quarter of the largest multiple whose LQR move fits one
        # tick's slew limit at every knot, rounded down to one significant figure. The
        # optimum is interior only if the move stays well inside the slew limits and the
        # command box in either direction.
        dx = sol.ps[model.perturbation.k]
        @test dx ≈ 0.006 .* VelocityMPC.STATE_SCALES
        design = member_design(velocity, VelocityMPC.ALTITUDE, Ts)
        move = design.K * dx
        expected = design.u .- move
        @test all(abs.(move) .< 0.5 .* VelocityMPC.COMMAND_RATE .* Ts)
        @test all(VelocityMPC.COMMAND_MIN .< design.u .- abs.(move))
        @test all(design.u .+ abs.(move) .< VelocityMPC.COMMAND_MAX)

        @test length(sol[model.exitflag]) == 20
        @test all(>=(1), sol[model.exitflag])

        held = (model.T_cmd, model.el_cmd, model.ail_cmd, model.rud_cmd)
        settled = Float64[]
        for (channel, signal) in pairs(held)
            samples = sol[signal]
            @test length(samples) == 20
            # Constant measurement and interior optimum: every tick returns the same LQR
            # command, including the first, because the observer corrects its initial
            # estimate (the unperturbed trim) with the measurement before the optimizer runs.
            deviation = maximum(abs, samples .- expected[channel])
            @test deviation < 1e-6
            push!(settled, samples[end])
        end
        commands[(velocity, Np)] = settled
    end

    # The terminal weight removes the horizon from the answer: five steps and forty agree.
    @test commands[(152.4, 5)]≈commands[(152.4, 40)] atol=1e-6
end

@testset "velocity MPC bank rejects unusable designs" begin
    @test_throws "strictly increasing" VelocityMPC.bank([160.0, 140.0])
    @test_throws "at least two knots" VelocityMPC.bank([152.4])
    @test_throws "outside the design grid" VelocityMPC.bank(VelocityMPC.KNOTS, 3000.0, 100.0)
    @test_throws "Ts must be positive" VelocityMPC.bank(VelocityMPC.KNOTS, 3000.0, 148.0, 0.0)
    @test_throws "umin must be below umax" VelocityMPC.bank(; umax = zeros(4))
    @test_throws "rate must be positive" VelocityMPC.bank(; rate = zeros(4))
    @test_throws "q and r must be positive" VelocityMPC.bank(; r = zeros(4))
end

# Tolerances are slightly wider than the design achieves, tight enough that a broken
# schedule, a lost reference channel or an infeasible QP fails.
@testset "velocity MPC tracks the airspeed ramp" begin
    result = F16ModelWorkshop.Tutorial.TutorialVelocityMPC()
    sol = result.sol
    loop = DyadInterface.symbolic_container(result)
    p = loop.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 25.0

    # Commanded 160 m/s, holding altitude and wings level.
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
