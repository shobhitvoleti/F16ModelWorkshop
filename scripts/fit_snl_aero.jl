# Condense the Stevens & Lewis F-16 aerodynamic tables into the constant-derivative
# deck carried by F16PlantModel (dyad/Plant/f16_plant_model.dyad). Run it to
# regenerate those coefficients:
#
#     julia --startup-file=no scripts/fit_snl_aero.jl
#
# The fit is taken at the reference CG (xcg = XCGR = 0.35c̄), so the deck carries no
# CG transfer and the plant applies it live from its own `xcg` parameter. That is
# what lets `xcg` alone move the aircraft across the pitch stability boundary.
#
# Sample ranges bracket the tutorial operating point rather than the full envelope:
# a deck linear in α cannot follow the tables to 45°, and the tutorial only ever
# flies within a few degrees of trim. Widening them degrades the fit where it matters.

include("snl_aero_tables.jl")
include("snl_aero_buildup.jl")

using LinearAlgebra
using Printf

const D2R = pi / 180
const XCG = F16AeroData.XCGR      # fit at the reference CG: no CG transfer in the deck
const VT_FIT = 500.0              # ft/s; the S&L tables carry no Mach dependence

# Sample ranges
const ALPHA_DEG = -2:1.0:10
const EL_DEG = -10:2.0:10
const BETA_DEG = -8:2.0:8
const AIL_DEG = (-15.0, 0.0, 15.0)
const RDR_DEG = (-20.0, 0.0, 20.0)
const QHAT = (-0.02, 0.0, 0.02)
const PHAT = (-0.05, 0.0, 0.05)
const RHAT = (-0.05, 0.0, 0.05)

coeffs(a, b, p, q, r, el, ail, rdr) =
    f16_aero_coefficients(VT_FIT, a, b, p, q, r, el, ail, rdr; xcg = XCG)

"""
    fit(rows) -> (coefficients, rms, maxerr)

Least-squares fit of one coefficient. `rows` is a vector of `(regressors, value)`
pairs; the returned vector is ordered as the regressors are.
"""
function fit(rows)
    M = permutedims(reduce(hcat, first.(rows)))
    y = last.(rows)
    b = M \ y
    res = M * b .- y
    return b, sqrt(sum(abs2, res) / length(res)), maximum(abs, res)
end

"""
    longitudinal() -> (C0, Cmat, diagnostics)

Fit `[Cx, Cz, Cm] = C0 + Cmat * [α, α², δe_rad, c̄Q/2V]`.
"""
function longitudinal()
    rowsx, rowsz, rowsm = [], [], []
    for a in ALPHA_DEG, el in EL_DEG, qh in QHAT
        q = qh * 2VT_FIT / F16AeroData.CBAR_FT
        c = coeffs(a, 0.0, 0.0, q, 0.0, el, 0.0, 0.0)
        x = [1.0, a * D2R, (a * D2R)^2, el * D2R, qh]
        push!(rowsx, (x, c.cx)); push!(rowsz, (x, c.cz)); push!(rowsm, (x, c.cm))
    end
    bx, rx, mx = fit(rowsx)
    bz, rz, mz = fit(rowsz)
    bm, rm, mm = fit(rowsm)
    C0 = [bx[1], bz[1], bm[1]]
    Cmat = permutedims(reduce(hcat, [bx[2:end], bz[2:end], bm[2:end]]))
    return C0, Cmat, [("Cx", rx, mx), ("Cz", rz, mz), ("Cm", rm, mm)]
end

"""
    lateral() -> (C0, Cmat, diagnostics)

Fit `[Cy, Cl, Cn] = C0 + Cmat * [β, δa_rad, δr_rad, bP/2V, bR/2V]`.
"""
function lateral()
    rowsy, rowsl, rowsn = [], [], []
    for a in ALPHA_DEG, b in BETA_DEG, da in AIL_DEG, dr in RDR_DEG, ph in PHAT, rh in RHAT
        p = ph * 2VT_FIT / F16AeroData.BSPAN_FT
        r = rh * 2VT_FIT / F16AeroData.BSPAN_FT
        c = coeffs(a, b, p, 0.0, r, -0.76, da, dr)
        x = [1.0, b * D2R, da * D2R, dr * D2R, ph, rh]
        push!(rowsy, (x, c.cy)); push!(rowsl, (x, c.cl)); push!(rowsn, (x, c.cn))
    end
    by, ry, my = fit(rowsy)
    bl, rl, ml = fit(rowsl)
    bn, rn, mn = fit(rowsn)
    # The airframe is symmetric, so Cy, Cl and Cn all vanish at zero sideslip with the
    # lateral controls centered. The fitted intercepts are rounding noise; carrying them
    # would give the trimmed aircraft a phantom roll-off. Anything larger means the
    # tables are no longer symmetric and the deck's structure no longer fits them.
    C0 = [by[1], bl[1], bn[1]]
    maximum(abs, C0) < 1e-12 ||
        error("lateral intercepts are not symmetry noise: $C0")
    C0 = zeros(3)
    Cmat = permutedims(reduce(hcat, [by[2:end], bl[2:end], bn[2:end]]))
    return C0, Cmat, [("Cy", ry, my), ("Cl", rl, ml), ("Cn", rn, mn)]
end

dyad_vector(v) = "[" * join((@sprintf("%.5g", x) for x in v), ", ") * "]"

dyad_matrix(M) = "[" * join(("[" * join((@sprintf("%.5g", M[i, j]) for j in axes(M, 2)), ", ") * "]"
                             for i in axes(M, 1)), ", ") * "]"

function main()
    C0_lon, Cmat_lon, diag_lon = longitudinal()
    C0_lat, Cmat_lat, diag_lat = lateral()

    println("Fitted at xcg = ", XCG, ", VT = ", VT_FIT, " ft/s")
    println("  alpha ", extrema(ALPHA_DEG), " deg, elevator ", extrema(EL_DEG), " deg, beta ",
            extrema(BETA_DEG), " deg\n")

    println("Residuals (nondimensional coefficient units):")
    for (name, rms, mx) in vcat(diag_lon, diag_lat)
        @printf("  %-3s rms=%.2e  max=%.2e\n", name, rms, mx)
    end

    @printf("\nStatic margin check: Cma = %+.4f /rad at xcg = %.2f -> %s\n",
            Cmat_lon[3, 1], XCG, Cmat_lon[3, 1] > 0 ? "STATICALLY UNSTABLE" : "stable")

    println("\nDyad literals for f16_plant_model.dyad:")
    println("  final parameter C0_lon::Real[3] = ", dyad_vector(C0_lon))
    println("  final parameter Cmat_lon::Real[3, 4] = ", dyad_matrix(Cmat_lon))
    println("  final parameter C0_lat::Real[3] = ", dyad_vector(C0_lat))
    println("  final parameter Cmat_lat::Real[3, 5] = ", dyad_matrix(Cmat_lat))

    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
