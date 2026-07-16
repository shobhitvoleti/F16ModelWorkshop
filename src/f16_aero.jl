# Reference implementation of the Stevens & Lewis F-16 aerodynamic model,
# operating on the tables in f16_aero_data.jl (see that file for provenance).
# The coefficient-buildup equations are transcribed from the MathML
# <calculation> elements of assets/F16_aero.dml; the embedded checkcases
# (test/f16_aero_checkcases.jl) verify both the tables and this buildup.
#
# Inputs: vt ft/s; alpha, beta, el, ail, rdr deg; p, q, r rad/s;
# xcg fraction of cbar. Outputs: nondimensional body-axis coefficients.

"""
    interp1_clamped(xbp, table, x)

Linear interpolation of `table` over breakpoints `xbp`, with `x` clamped to
the breakpoint range (the DML `extrapolate="neither"` contract).
"""
function interp1_clamped(xbp::AbstractVector, table::AbstractVector, x::Real)
    x = clamp(x, first(xbp), last(xbp))
    i = searchsortedlast(xbp, x)
    i = clamp(i, 1, length(xbp) - 1)
    t = (x - xbp[i]) / (xbp[i+1] - xbp[i])
    return table[i] + t * (table[i+1] - table[i])
end

"""
    interp2_clamped(xbp, ybp, table, x, y)

Bilinear interpolation of `table` (rows over `xbp`, columns over `ybp`), with
both inputs clamped to their breakpoint ranges.
"""
function interp2_clamped(xbp::AbstractVector, ybp::AbstractVector,
                         table::AbstractMatrix, x::Real, y::Real)
    x = clamp(x, first(xbp), last(xbp))
    y = clamp(y, first(ybp), last(ybp))
    i = clamp(searchsortedlast(xbp, x), 1, length(xbp) - 1)
    j = clamp(searchsortedlast(ybp, y), 1, length(ybp) - 1)
    tx = (x - xbp[i]) / (xbp[i+1] - xbp[i])
    ty = (y - ybp[j]) / (ybp[j+1] - ybp[j])
    f00, f10 = table[i, j], table[i+1, j]
    f01, f11 = table[i, j+1], table[i+1, j+1]
    return (1 - tx) * (1 - ty) * f00 + tx * (1 - ty) * f10 +
           (1 - tx) * ty * f01 + tx * ty * f11
end

"""
    f16_aero_coefficients(vt, alpha, beta, p, q, r, el, ail, rdr;
                          xcg=0.35, cl0_table=F16AeroData.CL0_ABS)

Total body-axis aerodynamic coefficients `(cx, cy, cz, cl, cm, cn)` of the
Stevens & Lewis F-16 model: table lookups plus damping, control-power, and
CG moment-transfer terms. Units per the file header.

`cl0_table` selects the basic rolling-moment table: `F16AeroData.CL0_ABS`
(S&L book values, the Step 0 baseline) or `F16AeroData.CL0_ABS_DML` (the
Morelli/DML variant the NASA checkcases were generated against). The two
differ in 18 cells at alpha 15-25 deg, |beta| >= 5 deg — see the data-lineage
note in scripts/parse_f16_dml.py.
"""
function f16_aero_coefficients(vt::Real, alpha::Real, beta::Real,
                               p::Real, q::Real, r::Real,
                               el::Real, ail::Real, rdr::Real;
                               xcg::Real = F16AeroData.XCGR,
                               cl0_table::AbstractMatrix = F16AeroData.CL0_ABS)
    D = F16AeroData
    rtd = 180.0 / 3.14159265

    # Normalized control deflections
    del = el / 25.0
    dail = ail / 20.0
    drdr = rdr / 30.0

    # Rate nondimensionalization
    tvt = 2.0 * vt
    b2v = D.BSPAN_FT / tvt
    cq2v = D.CBAR_FT * q / tvt

    # Basic tables
    cxt = interp2_clamped(D.EL_BP, D.ALPHA_BP, D.CX, el, alpha)
    czt = interp1_clamped(D.ALPHA_BP, D.CZ, alpha)
    cmt = interp2_clamped(D.EL_BP, D.ALPHA_BP, D.CM, el, alpha)
    abscl0 = interp2_clamped(D.BETA_ABS_BP, D.ALPHA_BP, cl0_table, abs(beta), alpha)
    abscn0 = interp2_clamped(D.BETA_ABS_BP, D.ALPHA_BP, D.CN0_ABS, abs(beta), alpha)
    clt = beta < 0 ? -abscl0 : abscl0
    cnt = beta < 0 ? -abscn0 : abscn0

    # Damping derivatives (all functions of alpha)
    cxq = interp1_clamped(D.ALPHA_BP, D.CXQ, alpha)
    cyr = interp1_clamped(D.ALPHA_BP, D.CYR, alpha)
    cyp = interp1_clamped(D.ALPHA_BP, D.CYP, alpha)
    czq = interp1_clamped(D.ALPHA_BP, D.CZQ, alpha)
    clr = interp1_clamped(D.ALPHA_BP, D.CLR, alpha)
    clp = interp1_clamped(D.ALPHA_BP, D.CLP, alpha)
    cmq = interp1_clamped(D.ALPHA_BP, D.CMQ, alpha)
    cnr = interp1_clamped(D.ALPHA_BP, D.CNR, alpha)
    cnp = interp1_clamped(D.ALPHA_BP, D.CNP, alpha)

    # Lateral control power
    dclda = interp2_clamped(D.BETA_BP, D.ALPHA_BP, D.DLDA, beta, alpha)
    dcldr = interp2_clamped(D.BETA_BP, D.ALPHA_BP, D.DLDR, beta, alpha)
    dcnda = interp2_clamped(D.BETA_BP, D.ALPHA_BP, D.DNDA, beta, alpha)
    dcndr = interp2_clamped(D.BETA_BP, D.ALPHA_BP, D.DNDR, beta, alpha)

    # Buildup (transcribed from the DML calculations)
    cy0 = -0.02 * beta + 0.021 * dail + 0.086 * drdr
    cz1 = czt * (1.0 - (beta / rtd)^2) - 0.19 * del
    cl1 = clt + dclda * dail + dcldr * drdr
    cn1 = cnt + dcnda * dail + dcndr * drdr

    cx = cxt + cq2v * cxq
    cy = cy0 + b2v * (cyp * p + cyr * r)
    cz = cz1 + cq2v * czq
    cl = cl1 + b2v * (clp * p + clr * r)
    cm = cmt + cq2v * cmq + cz * (D.XCGR - xcg)
    cn = cn1 + b2v * (cnp * p + cnr * r) - cy * (D.XCGR - xcg) * D.CBAR_FT / D.BSPAN_FT

    return (cx = cx, cy = cy, cz = cz, cl = cl, cm = cm, cn = cn)
end
