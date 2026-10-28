# The plant's coefficient deck is a fit to the Stevens & Lewis F-16 tables
# (scripts/fit_snl_aero.jl). These tests pin it to the book: the published trim point
# and the pitch instability the F-16 is designed around.
#
# Reference: Stevens, Lewis & Johnson, "Aircraft Control and Simulation", 3rd ed.,
# Table 3.6-3 (trimmed flight conditions) and Example 3.8-1 (longitudinal modes).

using F16ModelWorkshop
using DyadInterface
using ModelingToolkit
using LinearAlgebra
using Test

const _Trimming = F16ModelWorkshop.Trimming
const _Tutorial = F16ModelWorkshop.Tutorial

"""
    trim_at(; alt, vt, xcg) -> (; T, el, alpha)

Straight-and-level trim at one flight condition and CG position. Exports to a scratch
directory so the package's trim assets stay untouched.
"""
function trim_at(; alt, vt, xcg)
    model = _Tutorial.TrimDemo(; name = :trim_probe, __overrides = Dict{String, Any}(
        "f16plant.alt_init" => alt, "f16plant.vt_init" => vt, "f16plant.xcg" => xcg))
    spec = F16ModelWorkshop.TrimExportAnalysisSpec(; model, export_dir = mktempdir())
    ps = DyadInterface.run_analysis(spec).paramset
    controls = ps["trim_controls"]["k"]
    return (T = controls[1], el = controls[2], alpha = ps["trim_point"]["alpha_init"])
end

"""
    modes_at(; alt, vt, xcg) -> (; lon, lat)

Eigenvalues of the trimmed plant, split into the longitudinal `[vt, α, θ, Q]` and
lateral `[β, φ, P, R]` sets. The submatrices of the full Jacobian hold the other states
fixed, as in S&L Example 3.8-1; position and heading are integrators that contribute
only poles at the origin.

The Jacobian is finite-differenced so the check does not depend on the plant's
expressions having an analytic derivative.
"""
function modes_at(; alt, vt, xcg)
    tr = trim_at(; alt, vt, xcg)
    model = _Trimming.F16OpenLoopTrim(; name = :mode_probe, __overrides = Dict{String, Any}(
        "T_cmd.k" => tr.T, "el_cmd.k" => tr.el, "plant.xcg" => xcg,
        "plant.alt_init" => alt, "plant.vt_init" => vt,
        "plant.alpha_init" => tr.alpha, "plant.theta_init" => tr.alpha))
    sys = mtkcompile(model)
    prob = ODEProblem(sys, Pair[], (0.0, 1.0))
    u0 = copy(prob.u0)
    rhs(u) = (du = similar(u); prob.f(du, u, prob.p, 0.0); du)
    f0 = rhs(u0)
    A = similar(u0, length(u0), length(u0))
    for j in eachindex(u0)
        h = 1e-6 * max(1.0, abs(u0[j]))
        up = copy(u0); up[j] += h
        A[:, j] = (rhs(up) - f0) / h
    end
    names = string.(Symbol.(unknowns(sys)))
    pick(wanted) = [findfirst(n -> occursin(w, n), names) for w in wanted]
    lon = pick(["vt", "alpha", "theta", "Q"])
    lat = pick(["beta", "phi", "P", "R"])
    return (lon = eigvals(A[lon, lon]), lat = eigvals(A[lat, lat]))
end

unstable(ev) = count(e -> real(e) > 1e-4, ev)

@testset "deck tracks the S&L tables" begin
    # Re-runs the fit and compares it with the deck's coefficients, so a hand-edited
    # coefficient fails here.
    include(joinpath(@__DIR__, "..", "scripts", "fit_snl_aero.jl"))
    C0_lon, Cmat_lon, _ = longitudinal()
    @test C0_lon≈[-0.027932, -0.096752, -0.01018] rtol=1e-4
    @test Cmat_lon[3, 1] > 0                      # unstable at the reference CG
    @test Cmat_lon[2, 1]≈-3.7128 rtol=1e-4        # lift-curve slope

    C0_lat, Cmat_lat, _ = lateral()
    @test C0_lat == zeros(3)                      # symmetric airframe
    @test Cmat_lat[2, 2] < 0                      # aileron rolls the correct way

    # Accuracy against the tables over the alpha range the closed loop flies. The fit
    # covers [-2, 10] deg; these bounds make its extrapolation down to -6 deg safe.
    # The Cz bound is set by the low-alpha edge (error 0.049 against Cz ≈ 0.35; under
    # 0.005 near trim). Cm, which decides stability, stays tight throughout.
    d2r = pi / 180
    for a in -6:0.5:10
        el = -0.6949
        x = [a * d2r, (a * d2r)^2, el * d2r, 0.0]
        fit_lon = C0_lon + Cmat_lon * x
        tab = f16_aero_coefficients(500.0, a, 0.0, 0.0, 0.0, 0.0, el, 0.0, 0.0;
            xcg = F16AeroData.XCGR)
        @test fit_lon[2]≈tab.cz atol=0.05         # normal force
        @test fit_lon[3]≈tab.cm atol=0.004        # pitching moment
    end
end

@testset "trim matches S&L Table 3.6-3" begin
    # Book nominal: 502 ft/s at sea level, xcg = 0.35c̄, straight and level.
    tr = trim_at(alt = 0.0, vt = 502 * 0.3048, xcg = 0.35)
    @test tr.alpha≈0.03691 rtol=0.02      # book 0.03691 rad
    @test tr.el≈-0.7588 rtol=0.06         # book -0.7588 deg
    @test tr.T > 0
end

@testset "trimmed level flight over the speed range" begin
    # S&L Table 3.6-2: alpha rises monotonically as speed drops. Both points lie inside
    # the deck's fitted alpha range but far from `TrimDemo`'s guesses, so they are
    # trimmed with `VelocityMPC`'s Newton solve on the same plant.
    plant = F16ModelWorkshop.VelocityMPC.dynamics(0.35)
    alpha(vt) = F16ModelWorkshop.VelocityMPC.trim_point(plant, vt; altitude = 0.0).x[8]
    @test alpha(400 * 0.3048) > alpha(600 * 0.3048) > 0
end

@testset "statically unstable in pitch at the reference CG" begin
    m = modes_at(alt = 3000.0, vt = 152.4, xcg = 0.35)

    # S&L's signature of static instability: the short period splits onto the real axis
    # and one root enters the right half plane.
    @test unstable(m.lon) == 1
    rhp = only(filter(e -> real(e) > 1e-4, m.lon))
    @test imag(rhp) ≈ 0 atol=1e-8         # exponential pitch departure, not a flutter
    @test 0.05 < real(rhp) < 0.15         # time to double 5–14 s

    # Lateral-directional stays conventional: damped dutch roll, convergent roll.
    @test unstable(m.lat) == 0
    dutch = filter(e -> imag(e) > 1.0, m.lat)
    @test length(dutch) == 1
    @test 0.05 < -real(only(dutch)) / abs(only(dutch)) < 0.3   # damping ratio
end

@testset "moving the CG forward restores pitch stiffness" begin
    m = modes_at(alt = 3000.0, vt = 152.4, xcg = 0.30)

    # At 0.30c̄ the short period is a well-damped complex pair again. A slow root from the
    # phugoid's coupling to altitude survives: thrust is a fixed force that neither lapses
    # with height nor falls off with speed, so nothing damps the energy exchange.
    short_period = filter(e -> abs(e) > 0.5, m.lon)
    @test length(short_period) == 2
    @test all(e -> real(e) < 0, short_period)
    @test all(e -> imag(e) != 0, short_period)
    @test maximum(real, m.lon) < 0.05
end
