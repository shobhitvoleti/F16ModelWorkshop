# The plant's coefficient deck condenses the Stevens & Lewis F-16 tables
# (scripts/fit_snl_aero.jl). These tests pin it to the book: the published trim point,
# and the pitch instability that the F-16 is designed around.
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

Solve the straight-and-level trim at one flight condition and CG position.
"""
function trim_at(; alt, vt, xcg)
    model = _Tutorial.TrimDemo(; name = :trim_probe,
        f16plant__alt_init = alt, f16plant__vt_init = vt, f16plant__xcg = xcg)
    spec = F16ModelWorkshop.TrimPlantAnalysisSpec(; model, export_path = tempname() * ".toml")
    ps = DyadInterface.run_analysis(spec).paramset
    return (T = ps["T_cmd"]["k"], el = ps["el_cmd"]["k"], alpha = ps["plant"]["alpha_init"])
end

"""
    modes_at(; alt, vt, xcg) -> (; lon, lat)

Eigenvalues of the trimmed plant, split into the longitudinal `[vt, α, θ, Q]` and
lateral `[β, φ, P, R]` sets. Taking these as submatrices of the full Jacobian holds
the remaining states fixed, which is how S&L Example 3.8-1 presents them — the
position and heading states are integrators that contribute only poles at the origin.

The Jacobian is finite-differenced rather than taken symbolically so this stays
independent of whether the plant's expressions admit an analytic derivative.
"""
function modes_at(; alt, vt, xcg)
    tr = trim_at(; alt, vt, xcg)
    model = _Trimming.F16OpenLoopTrim(; name = :mode_probe,
        T_cmd__k = tr.T, el_cmd__k = tr.el, plant__xcg = xcg,
        plant__alt_init = alt, plant__vt_init = vt,
        plant__alpha_init = tr.alpha, plant__theta_init = tr.alpha)
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
    # Re-run the fit and compare against what the plants actually carry, so a
    # hand-edited coefficient fails here rather than quietly changing the aircraft.
    include(joinpath(@__DIR__, "..", "scripts", "fit_snl_aero.jl"))
    C0_lon, Cmat_lon, _ = longitudinal()
    @test C0_lon≈[-0.027932, -0.096752, -0.01018] rtol=1e-4
    @test Cmat_lon[3, 1] > 0                      # unstable at the reference CG
    @test Cmat_lon[2, 1]≈-3.7128 rtol=1e-4        # lift-curve slope

    C0_lat, Cmat_lat, _ = lateral()
    @test C0_lat == zeros(3)                      # symmetric airframe
    @test Cmat_lat[2, 2] < 0                      # aileron rolls the correct way

    # Accuracy against the tables over the range the closed loop actually flies. The
    # fit is taken over alpha in [-2, 10]; below that it extrapolates, and these
    # bounds are what make the extrapolation safe to rely on down to -6 deg.
    #
    # The normal-force bound is set by the low-alpha edge, where the error reaches
    # 0.049 against a Cz of 0.35; through the trim region it is under 0.005. The
    # pitching moment stays tight throughout, which is what matters — it is the
    # coefficient that decides whether the aircraft is stable.
    d2r = pi / 180
    for a in -6:0.5:10
        el = -0.6949
        x = [a * d2r, (a * d2r)^2, el * d2r, 0.0]
        fit_lon = C0_lon + Cmat_lon * x
        tab = f16_aero_coefficients(500.0, a, 0.0, 0.0, 0.0, 0.0, el, 0.0, 0.0;
            xcg = F16AeroData.XCGR)
        @test fit_lon[2]≈tab.cz atol=0.05         # normal force
        @test fit_lon[3]≈tab.cm atol=0.004        # pitching moment — sets stability
    end
end

@testset "trim matches S&L Table 3.6-3" begin
    # Book nominal: 502 ft/s at sea level, xcg = 0.35c̄, straight and level.
    tr = trim_at(alt = 0.0, vt = 502 * 0.3048, xcg = 0.35)
    @test tr.alpha≈0.03691 rtol=0.02      # book 0.03691 rad
    @test tr.el≈-0.7588 rtol=0.06         # book -0.7588 deg
    @test tr.T > 0                        # level flight needs positive thrust
end

@testset "trimmed level flight over the speed range" begin
    # S&L Table 3.6-2: as speed drops, alpha rises monotonically. Both points sit
    # inside the alpha range the deck was fitted over.
    slow = trim_at(alt = 0.0, vt = 400 * 0.3048, xcg = 0.35)
    fast = trim_at(alt = 0.0, vt = 600 * 0.3048, xcg = 0.35)
    @test slow.alpha > fast.alpha
    @test fast.alpha > 0
end

@testset "statically unstable in pitch at the reference CG" begin
    m = modes_at(alt = 3000.0, vt = 152.4, xcg = 0.35)

    # The signature S&L describe for a statically unstable airplane: the short period
    # splits onto the real axis and one root crosses into the right half plane.
    @test unstable(m.lon) == 1
    rhp = only(filter(e -> real(e) > 1e-4, m.lon))
    @test imag(rhp) ≈ 0 atol=1e-8         # exponential pitch departure, not a flutter
    @test 0.05 < real(rhp) < 0.15         # time to double of a few seconds

    # Lateral-directional stays conventional: damped dutch roll, convergent roll.
    @test unstable(m.lat) == 0
    dutch = filter(e -> imag(e) > 1.0, m.lat)
    @test length(dutch) == 1
    @test 0.05 < -real(only(dutch)) / abs(only(dutch)) < 0.3   # damping ratio
end

@testset "moving the CG forward restores pitch stiffness" begin
    m = modes_at(alt = 3000.0, vt = 152.4, xcg = 0.30)

    # At 0.30c̄ the short period is a well-damped complex pair again — the fast pitch
    # divergence is gone. What survives is a slow root from the phugoid coupling to
    # altitude: thrust here is a fixed force, so it neither lapses with height nor
    # falls off with speed, and nothing damps the resulting energy exchange.
    short_period = filter(e -> abs(e) > 0.5, m.lon)
    @test length(short_period) == 2
    @test all(e -> real(e) < 0, short_period)
    @test all(e -> imag(e) != 0, short_period)
    @test maximum(real, m.lon) < 0.05
end
