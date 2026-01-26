module F16ModelWorkshop

# Import F16Model for aerodynamic lookup tables
using F16Model

# Re-export aerodynamic lookup functions for use in Dyad
# These expect degrees for angles
const f16_Cx = F16Model._Cx
const f16_Cy = F16Model._Cy
const f16_Cz = F16Model._Cz
const f16_Cl = F16Model._Cl
const f16_Cm = F16Model._Cm
const f16_Cn = F16Model._Cn
const f16_atmos = F16Model.atmos

# Wrapper functions that unpack tuples for Dyad
function f16_Delta_lef(alpha_deg::Real, beta_deg::Real)
    return F16Model.Delta_lef(alpha_deg, beta_deg)
end

function f16_Damping(alpha_deg::Real)
    return F16Model._Damping(alpha_deg)
end

function f16_Damping_lef(alpha_deg::Real)
    return F16Model._Damping_lef(alpha_deg)
end

function f16_RudderInfluence(alpha_deg::Real, beta_deg::Real)
    return F16Model._RudderInfluence(alpha_deg, beta_deg)
end

function f16_AileronInfluence(alpha_deg::Real, beta_deg::Real)
    return F16Model._AileronInfluence(alpha_deg, beta_deg)
end

function f16_OtherCoefficients(alpha_deg::Real, el_deg::Real)
    return F16Model._OtherCoefficients(alpha_deg, el_deg)
end

include("../generated/module.jl")
    
end # module F16ModelWorkshop