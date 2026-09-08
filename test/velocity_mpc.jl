using Test
using LinearAlgebra
using F16ModelWorkshop
using F16ModelWorkshop.VelocityMPC
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

@testset "F16 velocity MPC" begin
    bank = build_velocity_mpc()
    @test bank.dynamics isa F16Dynamics
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

    # Nonlinear rollout crosses the middle knot while recovering a pitch perturbation.
    initial = trim_point(bank.dynamics,148.0)
    x0 = copy(initial.x); x0[5] += deg2rad(2)
    reference(t) = trim_state(bank,148.0 + 12.0*clamp((t-2.0)/12.0,0,1))
    result = VelocityMPC.simulate(bank; x0, reference, applied0=initial.u, duration=25.0)
    @test all(isfinite,result.x)
    @test maximum(result.x[7,:]) > 153
    @test abs(result.x[7,end]-160) < 2.0
    @test abs(result.x[3,end]-3000) < 10
    @test maximum(abs,result.x[4,:]) < 0.02
    @test maximum(abs,result.x[5,:]) < 0.2
    @test all(bank.umin .- 1e-4 .<= result.u .<= bank.umax .+ 1e-4)
    increments = diff(hcat(initial.u,result.u); dims=2)
    @test all(abs.(increments) .<= bank.slew*bank.Ts .+ 1e-4)
    @test all(abs.(sum(result.weights;dims=1).-1) .< 1e-12)
    @test any(>(0),result.weights[1,:]) && any(>(0),result.weights[3,:])
end
