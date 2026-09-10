using Test
using LinearAlgebra
using F16ModelWorkshop
using F16ModelWorkshop.VelocityMPC
using DyadInterface
import LinearMPC

@testset "velocity scheduler" begin
    grid = [140.0,152.4,170.0]
    @test scheduling_weights(grid,140.0) == [1,0,0]
    @test scheduling_weights(grid,152.4) == [0,1,0]
    @test scheduling_weights(grid,170.0) == [0,0,1]
    @test scheduling_weights(grid,146.2) ≈ [0.5,0.5,0]
    @test scheduling_weights(grid,160.0; method=:nearest) == [0,1,0]
    @test scheduling_weights(grid,200.0; outside=:clamp) == [0,0,1]
    @test_throws "outside the MPC design grid" scheduling_weights(grid,130.0)
    @test_throws "strictly increasing" scheduling_weights([140,140],140)
    @test_throws "strictly increasing" scheduling_weights([160,140],150)
    @test_throws "finite" scheduling_weights(grid,NaN)
    @test_throws "finite" scheduling_weights(grid,Inf; outside=:clamp)
    @test_throws "at least two" scheduling_weights([140.0],140.0)
    @test_throws "method" scheduling_weights(grid,150; method=:cubic)
    for v in range(140,170; length=101)
        w = scheduling_weights(grid,v)
        @test sum(w) ≈ 1
        @test all(>=(0),w)
        @test count(>(0),w) <= 2
    end
end

# Every rejection here happens before any controller is designed, so this testset is
# cheap: only the plant model is built.
@testset "velocity MPC analysis rejects unusable specs" begin
    Spec = F16ModelWorkshop.VelocityMPCAnalysisSpec
    run = DyadInterface.run_analysis
    plant = F16ModelWorkshop.Plant.F16PlantModel(; name = :guard_plant)
    @test_throws "needs a plant model" run(Spec())
    @test_throws "outside the design grid" run(Spec(; model=plant, initial_velocity=100.0))
    @test_throws "outside the design grid" run(Spec(; model=plant, final_velocity=200.0))
    @test_throws "ramp_start must be nonnegative" run(Spec(; model=plant, ramp_start=-1.0))
    @test_throws "ramp_duration must be positive" run(Spec(; model=plant, ramp_duration=0.0))
    @test_throws "whole number of Ts" run(Spec(; model=plant, stop=25.03))
    @test_throws "ends before the reference ramp" run(Spec(; model=plant, stop=10.0))
end

# The analysis designs the bank and flies the ramp once; everything below reads that
# one run, so the expensive symbolic linearization and QP setups are not repeated.
@testset "F16 velocity MPC" begin
    res = F16ModelWorkshop.Tutorial.TutorialVelocityMPC(export_dir = mktempdir())
    bank, result = res.bank, res.result

    @test bank.dynamics isa F16Dynamics
    @test all(isfile, res.files)
    @test sort(basename.(res.files)) == ["response.png","summary.toml","trajectory.csv"]
    @test DyadInterface.artifacts(res,:Trajectory) === res.result
    @test DyadInterface.artifacts(res,:Bank) === res.bank

    for member in bank.members
        tr = member.trim
        @test tr.residual_norm < 1e-7
        @test bank.dynamics(tr.x,tr.u)[1] ≈ tr.velocity rtol=1e-8
        @test 0 < tr.u[1] < 50000
        @test abs(tr.u[2]) < 25
        # Compare generated symbolic derivatives with an independent central difference.
        Afd, Bfd = zeros(12,12), zeros(12,4)
        for j in eachindex(tr.x)
            h = 1e-5*max(1,abs(tr.x[j]))
            up, um = copy(tr.x), copy(tr.x)
            up[j] += h; um[j] -= h
            Afd[:,j] = (bank.dynamics(up,tr.u)-bank.dynamics(um,tr.u))/(2h)
        end
        for j in eachindex(tr.u)
            h = 1e-5*max(1,abs(tr.u[j]))
            up, um = copy(tr.u), copy(tr.u)
            up[j] += h; um[j] -= h
            Bfd[:,j] = (bank.dynamics(tr.x,up)-bank.dynamics(tr.x,um))/(2h)
        end
        @test member.model.Ac ≈ Afd rtol=1e-6 atol=1e-7
        @test member.model.Bc ≈ Bfd rtol=1e-6 atol=1e-7
        count0 = bank.solves
        output = control!(bank,tr.x; reference=tr.x,applied=tr.u)
        @test bank.solves-count0 == 1
        @test output.u ≈ tr.u atol=1e-5
    end

    # The keyword constructor builds its own F16PlantModel; the analysis passed in the
    # plant it flies. Both must compile the same airframe in the same state order.
    keyword_dynamics = F16Dynamics(; xcg=0.35)
    middle = bank.members[findfirst(≈(152.4), bank.grid)]
    @test keyword_dynamics.permutation == bank.dynamics.permutation
    @test linear_model(keyword_dynamics, middle.trim.x, middle.trim.u; Ts=bank.Ts).Ac ≈
          middle.model.Ac rtol=1e-10

    x = trim_state(bank,146.2)
    x[5] += deg2rad(1)
    ref = trim_state(bank,146.2)
    previous = [11000.0,-0.5,0.1,-0.1]
    w = scheduling_weights(bank.grid,x[7])
    expected = zeros(4)
    for i in findall(>(0),w)
        tr, c = bank.members[i].trim, bank.members[i].controller
        du = LinearMPC.compute_control(c,(x[3:12]-tr.x[3:12])./bank.state_scale;
            r=(ref[3:12]-tr.x[3:12])./bank.state_scale,
            uprev=(previous-tr.u)./bank.input_scale)
        expected .+= w[i].*(tr.u+bank.input_scale.*du)
    end
    count0 = bank.solves
    output = control!(bank,x; reference=ref,applied=previous)
    @test bank.solves-count0 == 2
    @test output.u ≈ expected atol=1e-5
    @test all(bank.umin .<= output.u .<= bank.umax)
    @test all(abs.(output.u-previous) .<= bank.slew*bank.Ts .+ 1e-4)
    @test bank.previous == output.u
    @test_throws "12 entries" control!(bank,zeros(11); reference=ref)
    @test_throws "finite" control!(bank,fill(NaN,12); reference=ref)
    @test_throws "applied command" control!(bank,x; reference=ref,applied=fill(-1e6,4))
    @test_throws "outside" trim_state(bank,200)

    # The rollout crosses the middle knot while recovering the pitch perturbation.
    initial = trim_point(bank.dynamics,148.0)
    @test all(isfinite,result.x)
    @test maximum(result.x[7,:]) > 153
    @test abs(result.x[7,end]-160) < 0.3
    @test abs(result.x[3,end]-3000) < 5
    @test maximum(abs,result.x[4,:]) < 0.02
    @test maximum(abs,result.x[5,:]) < 0.2
    @test all(bank.umin .- 1e-4 .<= result.u .<= bank.umax .+ 1e-4)
    increments = diff(hcat(initial.u,result.u); dims=2)
    @test all(abs.(increments) .<= bank.slew*bank.Ts .+ 1e-4)
    @test all(abs.(sum(result.weights;dims=1).-1) .< 1e-12)
    @test any(>(0),result.weights[1,:]) && any(>(0),result.weights[3,:])
end
