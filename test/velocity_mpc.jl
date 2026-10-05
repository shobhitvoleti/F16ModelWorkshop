using Test
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

# One second of a constant-signal check model: twenty ticks of the 20 Hz controller.
check(model) = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(; model, stop = 1.0))

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
# constant trimmed state as both measurement and reference, one model per knot.
@testset "bank members hold their own trim" begin
    for velocity in VelocityMPC.KNOTS
        result = check(F16ModelWorkshop.Tests.VelocityMPCHoldsTrim(; name = :holds, velocity))
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

# The terminal weight of every member is the Riccati cost-to-go of its own stage cost, so
# the member's unconstrained optimum is the infinite-horizon discrete LQR of that cost and
# the horizon length cannot move it. A bank's members have no public accessor
# (MPCComponents.jl#48), so the property is asserted on the scheduled components:
# `VelocityMPCMemberIsLQR` holds the reference at a knot's trim and the measurement one
# fixed `dx` away, so every tick must return `u - K * dx`.
@testset "unconstrained member equals LQR" begin
    Ts = 0.05
    # Every knot on the default forty-step horizon, and the middle knot on five steps.
    runs = [[(velocity, 40) for velocity in VelocityMPC.KNOTS]; (152.4, 5)]

    commands = Dict{Tuple{Float64,Int},Vector{Float64}}()
    worst = 0.0
    for (velocity, Np) in runs
        result = check(F16ModelWorkshop.Tests.VelocityMPCMemberIsLQR(; name = :lqr, velocity, Np))
        sol = result.sol
        model = DyadInterface.symbolic_container(result)
        @test SciMLBase.successful_retcode(sol.retcode)

        # The offset is read back from the model, so its Dyad default is the only copy.
        # That default is 0.006 of the Bryson state scales: a quarter of the largest
        # multiple of them whose LQR move fits one tick's slew limit at every knot, rounded
        # down to one significant figure. The optimum is interior only if the move stays
        # well inside the slew limits and the command box, whichever way it points.
        dx = sol.ps[model.perturbation.k]
        @test dx ≈ 0.006 .* VelocityMPC.STATE_SCALES
        design = member_design(velocity, VelocityMPC.ALTITUDE, Ts)
        move = design.K * dx
        expected = design.u .- move
        @test all(abs.(move) .< 0.5 .* VelocityMPC.COMMAND_RATE .* Ts)
        @test all(VelocityMPC.COMMAND_MIN .< design.u .- abs.(move))
        @test all(design.u .+ abs.(move) .< VelocityMPC.COMMAND_MAX)

        # One entry per controller tick: twenty over a second at 20 Hz, every one of them a
        # solved command rather than a hold's initial value.
        @test length(sol[model.exitflag]) == 20
        @test all(>=(1), sol[model.exitflag])

        held = (model.T_cmd, model.el_cmd, model.ail_cmd, model.rud_cmd)
        settled = Float64[]
        for (channel, signal) in pairs(held)
            samples = sol[signal]
            @test length(samples) == 20
            # The measurement is constant and the optimum interior, so every tick returns
            # the same LQR command. That includes the first: the observer corrects its
            # initial estimate, the unperturbed trim, with the current measurement before
            # the optimizer reads it.
            deviation = maximum(abs, samples .- expected[channel])
            worst = max(worst, deviation)
            @test deviation < 1e-6
            push!(settled, samples[end])
        end
        commands[(velocity, Np)] = settled
    end

    # The terminal weight removes the horizon from the answer, so five steps and forty at
    # the same knot must agree.
    @test commands[(152.4, 5)]≈commands[(152.4, 40)] atol=1e-6
    @info "unconstrained member equals LQR: largest command deviation $worst"
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
