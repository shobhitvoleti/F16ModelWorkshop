using Test
using F16ModelWorkshop
using F16ModelWorkshop.EnvelopeMPC
using DyadInterface
using SciMLBase

# The envelope the bank is drawn from: every one of the 10 000 default flight conditions
# trims inside the alpha range the aero deck was fitted over. The pitch slope of the deck
# is dCm/dα = Cma + 2 Cma2 α, so the airframe is statically unstable below
# α = -Cma / (2 Cma2) = 5.66 deg and stable above it, in the slow, high corner.
@testset "envelope linearizes at 10 000 flight conditions" begin
    env = EnvelopeMPC.envelope()
    @test length(env.A) == 10_000
    @test all(a -> -2 <= rad2deg(a) <= 10, env.alpha)
    @test all(>(0), env.thrust)
    boundary = -0.082392 / (2 * -0.41732)
    @test all(env.unstable[env.alpha .< boundary - 1e-3] .> 0)
    @test all(env.unstable[env.alpha .> boundary + 1e-3] .< 1e-9)
    # Slower and higher both need more angle of attack.
    @test env.alpha[1, end] > env.alpha[end, end]
    @test env.alpha[1, end] > env.alpha[1, 1]
end

# The committed trim table is the grid the model reads. Regenerating it must reproduce it
# exactly, so a plant change without a re-run of run_envelope_tables.jl fails here. The
# table also serves as the pitch reference, which holds because level trim has theta = alpha.
@testset "trim table matches the plant" begin
    table = EnvelopeMPC.trim_table()
    trims = [F16ModelWorkshop.VelocityMPC.trim_states(v, h) for v in table["vt"], h in table["alt"]]
    @test table["alpha"] == getindex.(trims, 8)
    @test getindex.(trims, 5) ≈ table["alpha"] atol = 1e-12
end

@testset "reference map follows the flattened grid" begin
    table = EnvelopeMPC.trim_table()
    vs, hs = table["vt"], table["alt"]
    K = EnvelopeMPC.reference_map(table)
    @test size(K) == (10, 2 + length(vs) * length(hs))
    @test K[5, 1] == 1 && K[1, 2] == 1          # commanded airspeed and altitude
    # Member k = (j - 1) * length(vs) + i sits at (vs[i], hs[j]).
    i, j = 2, 3
    @test K[3, 2 + (j - 1) * length(vs) + i] == table["alpha"][i, j]   # pitch
    @test K[6, 2 + (j - 1) * length(vs) + i] == table["alpha"][i, j]   # angle of attack
    @test_throws "outside the design grid" EnvelopeMPC.bank(vs, hs, 100.0, 3000.0)
end

# The closed loop: climb and accelerate across a knot on each axis.
@testset "envelope MPC tracks airspeed and altitude" begin
    result = F16ModelWorkshop.Tutorial.TutorialEnvelopeMPC()
    sol = result.sol
    loop = DyadInterface.symbolic_container(result)
    p = loop.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 80.0
    @test sol[p.vt][end]≈190.0 atol=1.0
    @test sol[p.alt][end]≈4500.0 atol=20.0
    @test maximum(abs, sol[p.phi]) < 0.02
    # Both axes cross a knot, so the schedule hands over on each.
    @test minimum(sol[p.vt]) < 175 < maximum(sol[p.vt])
    @test minimum(sol[p.alt]) < 4000 < maximum(sol[p.alt])

    @test all(0 .<= sol[p.T] .<= 5.0e4)
    @test maximum(abs, sol[p.el]) <= 25.0
    @test all(>=(1), sol[loop.exitflag])
end
