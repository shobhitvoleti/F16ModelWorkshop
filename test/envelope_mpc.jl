using Test
using F16ModelWorkshop
using F16ModelWorkshop.EnvelopeMPC
using DyadInterface
using SciMLBase

# All 10 000 default flight conditions trim inside the deck's fitted alpha range. The
# deck's pitch slope is dCm/dα = Cma + 2 Cma2 α, so the airframe is statically unstable
# below α = -Cma / (2 Cma2) = 5.66 deg and stable above it, in the slow, high corner.
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

# The committed trim table is the grid the model reads; a plant change without a re-run of
# TutorialEnvelopeTable fails here. The table doubles as the pitch reference because level
# trim has theta = alpha.
@testset "trim table matches the plant" begin
    table = EnvelopeMPC.trim_table()
    trims = [F16ModelWorkshop.VelocityMPC.trim_states(v, h) for v in table["vt"], h in table["alt"]]
    @test getindex.(trims, 8) ≈ table["alpha"] rtol = 1e-10   # round-off varies by platform
    @test getindex.(trims, 5) ≈ table["alpha"] atol = 1e-12
end

# The grid bank builds a node only when a tick weights it, and a node is step 8's member
# design there: given its own trim as state and reference, its command is the trim command.
@testset "grid bank solves only the active nodes" begin
    vs, hs = [140.0, 175.0, 210.0], [1000.0, 4000.0, 7000.0]
    ref = EnvelopeMPC.grid_bank(vs, hs)
    bank = ref[]
    @test isempty(bank.nodes)
    x = F16ModelWorkshop.VelocityMPC.trim_states(175.0, 4000.0)[3:12]
    u = F16ModelWorkshop.VelocityMPC.trim_command(175.0, 4000.0)
    # Exactly at node (2, 2): one weight, one node built and solved.
    flag = EnvelopeMPC.grid_bank_solve([0.0, 1.0, 0.0], [0.0, 1.0, 0.0], x, x, u, ref)
    @test flag == 1
    @test collect(keys(bank.nodes)) == [(2, 2)]
    @test [EnvelopeMPC.grid_bank_u(flag, k, ref) for k in 1:4] ≈ u atol = 1e-6
    # Inside a cell: its four corners.
    EnvelopeMPC.grid_bank_solve([0.0, 0.5, 0.5], [0.0, 0.25, 0.75], x, x, u, ref)
    @test sort(collect(keys(bank.nodes))) == [(2, 2), (2, 3), (3, 2), (3, 3)]
    @test EnvelopeMPC.grid_bank_built(flag, ref) == 4
    @test bank.solves == 5
    @test_throws "weights for a 3 × 3 grid" EnvelopeMPC.grid_bank_solve([0.0, 1.0], [0.0, 1.0, 0.0], x, x, u, ref)
    @test_throws "strictly increasing" EnvelopeMPC.grid_bank([140.0, 140.0], hs)
end

# The closed loop on the committed 100 x 100 grid: climb and accelerate across many cells,
# building only the nodes the flight passes.
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

    @test all(0 .<= sol[p.T] .<= 5.0e4)
    @test maximum(abs, sol[p.el]) <= 25.0
    @test all(>=(1), sol[loop.optimizer.exitflag])
    # A small fraction of the grid is ever built.
    built = sol[loop.optimizer.built]
    @test issorted(built) && 4 <= built[end] < 500
    # The reference interpolated in the grid is the trim at the start.
    @test sol[loop.alpha_ref.y][1] ≈ F16ModelWorkshop.VelocityMPC.trim_states(150.0, 3000.0)[8] rtol = 1e-6
end
