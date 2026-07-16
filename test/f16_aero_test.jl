# Verifies the transcribed S&L aero tables and buildup (src/f16_aero_data.jl,
# src/f16_aero.jl) against the 17 checkcases embedded in the DAVE-ML source.
# The checkcases were generated from Morelli's Matlab adaptation, so they run
# against the CL0_ABS_DML rolling-moment table; the shipped baseline CL0_ABS
# carries the S&L book values and is pinned to it by the delta testset below.
include("f16_aero_checkcases.jl")

@testset "F16 aero DAVE-ML checkcases" begin
    for case in F16_AERO_CHECKCASES
        i = case.inputs
        got = F16ModelWorkshop.f16_aero_coefficients(
            i.vt, i.alpha, i.beta, i.p, i.q, i.r, i.el, i.ail, i.rdr;
            xcg = i.xcg, cl0_table = F16ModelWorkshop.F16AeroData.CL0_ABS_DML)
        @testset "$(case.name)" begin
            for k in (:cx, :cy, :cz, :cl, :cm, :cn)
                @test isapprox(getfield(got, k), getfield(case.expected, k);
                               atol = case.tol)
            end
        end
    end
end

@testset "F16 aero Cl0 book-vs-DML delta" begin
    D = F16ModelWorkshop.F16AeroData
    # (|beta| deg, alpha deg) => S&L book value; must mirror BOOK_CL0_OVERRIDES
    # in scripts/parse_f16_dml.py.
    overrides = Dict(
        (5, 15) => -0.019, (5, 20) => -0.020, (5, 25) => -0.020,
        (10, 15) => -0.034, (10, 20) => -0.040, (10, 25) => -0.037,
        (15, 15) => -0.044, (15, 20) => -0.050, (15, 25) => -0.049,
        (20, 15) => -0.046, (20, 20) => -0.059, (20, 25) => -0.061,
        (25, 15) => -0.046, (25, 20) => -0.068, (25, 25) => -0.071,
        (30, 15) => -0.047, (30, 20) => -0.074, (30, 25) => -0.079,
    )
    ndiff = 0
    for (i, b) in enumerate(D.BETA_ABS_BP), (j, a) in enumerate(D.ALPHA_BP)
        book, dml = D.CL0_ABS[i, j], D.CL0_ABS_DML[i, j]
        if haskey(overrides, (b, a))
            @test book == overrides[(b, a)]
            @test book != dml
            ndiff += 1
        else
            @test book == dml
        end
    end
    @test ndiff == 18
end
