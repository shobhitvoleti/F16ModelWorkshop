using Test
using F16ModelWorkshop
using F16ModelWorkshop.Tutorial
using F16ModelWorkshop.VelocityMPC: VelocityMPC
using LinearAlgebra
import ControlSystemsBase as CS
import TOML

# Steps 2 and 3 run DyadControlSystems' `LinearAnalysis` and `LQGAnalysis`, and steps 4–6 fly
# the controllers step 3 designed, saved in `assets/`. These tests rerun both designs, so a
# dependency upgrade that changes the linearization or the LQG synthesis fails here instead
# of silently drifting away from the controllers the workshop ships.

# A saved controller as a state space. The TOML matrices are row-major nested arrays.
function saved_controller(name; Ts = nothing)
    data = TOML.parsefile(F16ModelWorkshop.asset_path(name))
    matrix(rows) = reduce(vcat, permutedims.(Vector{Float64}.(rows)))
    A, B, C, D = (matrix(data[k]) for k in ("A", "B", "C", "D"))
    return isnothing(Ts) ? CS.ss(A, B, C, D) : CS.ss(A, B, C, D, Ts)
end

# Two controllers are the same design if they have the same input-output behaviour: the
# realization (state coordinates) may differ between library versions without changing it.
function same_controller(designed, saved; rtol)
    size(designed) == size(saved) || return false
    ws = exp10.(range(-2, 2; length = 40))
    if CS.isdiscrete(saved)
        ws = filter(<(π / saved.Ts), ws)
    end
    Gd, Gs = CS.freqresp(designed, ws), CS.freqresp(saved, ws)
    return all(norm(Gd[:, :, k] - Gs[:, :, k]) <= rtol * norm(Gs[:, :, k]) for k in eachindex(ws))
end

sorted_poles(sys) = sort(CS.poles(sys); by = p -> (real(p), imag(p)))

@testset "step 2 linearization agrees with the plant's own Jacobian" begin
    result = TutorialLinearize()
    sys = result.sys
    @test size(sys) == (12, 4)
    # The same trim, linearized by F16ModelWorkshop's symbolic Jacobian, independently of
    # DyadControlSystems. Both models have the twelve physical states.
    reference = VelocityMPC.linear_model(VelocityMPC.dynamics(), VelocityMPC.trim_states(152.4),
        VelocityMPC.trim_command(152.4) .* VelocityMPC.CONTROL_UNITS)
    @test sorted_poles(sys) ≈ sorted_poles(CS.ss(reference.Ac, reference.Bc, I(12), 0)) atol = 1e-6
    # The airframe is unstable in pitch: one real pole in the right half plane.
    unstable = filter(p -> real(p) > 1e-6, CS.poles(sys))
    @test length(unstable) == 1
    @test real(only(unstable)) ≈ 0.0953 atol = 1e-3
end

@testset "step 3 LQG designs reproduce the shipped controllers" begin
    continuous = TutorialLQG().Cfb
    # The redesign comes back in other state coordinates, with B entries near 1e5, and agrees
    # with the asset to 3.5e-5 in frequency response and 7e-8 in its poles: floating-point
    # noise of that scaling. A changed design moves the response by far more than 1e-4.
    @test same_controller(continuous, saved_controller("controller.toml"); rtol = 1e-4)
    @test sorted_poles(continuous) ≈ sorted_poles(saved_controller("controller.toml")) atol = 1e-6
    @test all(p -> real(p) < 0, CS.poles(continuous))

    discrete = TutorialDiscreteLQG().Cfb
    @test discrete.Ts ≈ ControllerTs
    @test same_controller(discrete, saved_controller("discrete_controller.toml"; Ts = ControllerTs);
        rtol = 1e-6)
    @test all(p -> abs(p) < 1, CS.poles(discrete))
end
