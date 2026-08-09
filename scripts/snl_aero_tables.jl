# Stevens & Lewis F-16 aerodynamic tables — reference data for
# scripts/fit_snl_aero.jl, which condenses them into the coefficient deck carried
# by F16PlantModel. Not part of the package: the plant uses the fitted deck, because
# table interpolants carry no symbolic derivative and the tutorial's
# linearization-based analyses need one.
#
# Source encoding: DAVE-ML example "F16_aero.dml" (Bruce Jackson, NASA Langley,
# 2002), https://daveml.org/examples/F16_aero.dml
# Data lineage: NASA TP-1538 (Nguyen et al., 1979) -> Stevens & Lewis,
# "Aircraft Control and Simulation" -> NASA TM-2003-212145 (Garza & Morelli).
#
# Units: all breakpoints in degrees; table values nondimensional.
# Interpolation contract (per the DML independentVarRef spec): linear, with
# inputs CLAMPED to the breakpoint range (extrapolate="neither").
# 2-D tables are stored (first breakpoint = rows, second = columns), matching
# the DML row-major layout where the last breakpoint dimension varies fastest.

"Stevens & Lewis F-16 aerodynamic tables (see file header for provenance)."
module F16AeroData

# Reference geometry (English units, per the DML constants)
const CBAR_FT = 11.32   # mean aerodynamic chord
const BSPAN_FT = 30.0   # wing span
const XCGR = 0.35       # reference CG, fraction of cbar

# Breakpoints (deg)
const ALPHA_BP = [-10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45]
const BETA_ABS_BP = [0, 5, 10, 15, 20, 25, 30]
const BETA_BP = [-30, -20, -10, 0, 10, 20, 30]
const EL_BP = [-24, -12, 0, 12, 24]

# "Basic CX": Basic coefficient of X-force table as a function of angle of attack and elevator
# dims: EL_BP x ALPHA_BP
const CX = [
    -0.099 -0.081 -0.081 -0.063 -0.025 0.044 0.097 0.113 0.145 0.167 0.174 0.166;
    -0.048 -0.038 -0.04 -0.021 0.016 0.083 0.127 0.137 0.162 0.177 0.179 0.167;
    -0.022 -0.02 -0.021 -0.004 0.032 0.094 0.128 0.13 0.154 0.161 0.155 0.138;
    -0.04 -0.038 -0.039 -0.025 0.006 0.062 0.087 0.085 0.1 0.11 0.104 0.091;
    -0.083 -0.073 -0.076 -0.072 -0.046 0.012 0.024 0.025 0.043 0.053 0.047 0.04
]

# "Basic CZ": Basic coefficient of Z-force table as a function of angle of attack
# dims: ALPHA_BP
const CZ = [0.77, 0.241, -0.1, -0.416, -0.731, -1.053, -1.366, -1.646, -1.917, -2.12, -2.248, -2.229]

# "Basic Cm": Basic coefficient of pitching-moment as a function of angle of attack and elevator
# dims: EL_BP x ALPHA_BP
const CM = [
    0.205 0.168 0.186 0.196 0.213 0.251 0.245 0.238 0.252 0.231 0.198 0.192;
    0.081 0.077 0.107 0.11 0.11 0.141 0.127 0.119 0.133 0.108 0.081 0.093;
    -0.046 -0.02 -0.009 -0.005 -0.006 0.01 0.006 -0.001 0.014 0 -0.013 0.032;
    -0.174 -0.145 -0.121 -0.127 -0.129 -0.102 -0.097 -0.113 -0.087 -0.084 -0.069 -0.006;
    -0.259 -0.202 -0.184 -0.193 -0.199 -0.15 -0.16 -0.167 -0.104 -0.076 -0.041 -0.005
]

# "Basic Cl": Basic coefficient of rolling moment as a function of angle of attack and sideslip angle
# dims: BETA_ABS_BP x ALPHA_BP
# S&L book values (see the parser's data-lineage note); the
# Morelli/DML original follows as CL0_ABS_DML.
const CL0_ABS = [
    0 0 0 0 0 0 0 0 0 0 0 0;
    -0.001 -0.004 -0.008 -0.012 -0.016 -0.019 -0.02 -0.02 -0.015 -0.008 -0.013 -0.015;
    -0.003 -0.009 -0.017 -0.024 -0.03 -0.034 -0.04 -0.037 -0.016 -0.002 -0.01 -0.019;
    -0.001 -0.01 -0.02 -0.03 -0.039 -0.044 -0.05 -0.049 -0.023 -0.006 -0.014 -0.027;
    0 -0.01 -0.022 -0.034 -0.047 -0.046 -0.059 -0.061 -0.033 -0.036 -0.035 -0.035;
    0.007 -0.01 -0.023 -0.034 -0.049 -0.046 -0.068 -0.071 -0.06 -0.058 -0.062 -0.059;
    0.009 -0.011 -0.023 -0.037 -0.05 -0.047 -0.074 -0.079 -0.091 -0.076 -0.077 -0.076
]

# As encoded in the DML (Morelli adaptation); referenced by the
# NASA checkcase tests.
const CL0_ABS_DML = [
    0 0 0 0 0 0 0 0 0 0 0 0;
    -0.001 -0.004 -0.008 -0.012 -0.016 -0.022 -0.022 -0.021 -0.015 -0.008 -0.013 -0.015;
    -0.003 -0.009 -0.017 -0.024 -0.03 -0.041 -0.045 -0.04 -0.016 -0.002 -0.01 -0.019;
    -0.001 -0.01 -0.02 -0.03 -0.039 -0.054 -0.057 -0.054 -0.023 -0.006 -0.014 -0.027;
    0 -0.01 -0.022 -0.034 -0.047 -0.06 -0.069 -0.067 -0.033 -0.036 -0.035 -0.035;
    0.007 -0.01 -0.023 -0.034 -0.049 -0.063 -0.081 -0.079 -0.06 -0.058 -0.062 -0.059;
    0.009 -0.011 -0.023 -0.037 -0.05 -0.068 -0.089 -0.088 -0.091 -0.076 -0.077 -0.076
]

# "Basic Cn": Basic coefficient of yawing moment as a function of angle of attack and sideslip angle
# dims: BETA_ABS_BP x ALPHA_BP
const CN0_ABS = [
    0 0 0 0 0 0 0 0 0 0 0 0;
    0.018 0.019 0.018 0.019 0.019 0.018 0.013 0.007 0.004 -0.014 -0.017 -0.033;
    0.038 0.042 0.042 0.042 0.043 0.039 0.03 0.017 0.004 -0.035 -0.047 -0.057;
    0.056 0.057 0.059 0.058 0.058 0.053 0.032 0.012 0.002 -0.046 -0.071 -0.073;
    0.064 0.077 0.076 0.074 0.073 0.057 0.029 0.007 0.012 -0.034 -0.065 -0.041;
    0.074 0.086 0.093 0.089 0.08 0.062 0.049 0.022 0.028 -0.012 -0.002 -0.013;
    0.079 0.09 0.106 0.106 0.096 0.08 0.068 0.03 0.064 0.015 0.011 -0.001
]

# "CXq": Damping derivative: axial force due to pitch rate as a function of angle-of-attack
# dims: ALPHA_BP
const CXQ = [-0.267, -0.11, 0.308, 1.34, 2.08, 2.91, 2.76, 2.05, 1.5, 1.49, 1.83, 1.21]

# "CYr": Damping derivative: lateral force due to yaw rate as a function of angle-of-attack
# dims: ALPHA_BP
const CYR = [0.882, 0.852, 0.876, 0.958, 0.962, 0.974, 0.819, 0.483, 0.59, 1.21, -0.493, -1.04]

# "CYp": Damping derivative: lateral force due to roll rate as a function of angle-of-attack
# dims: ALPHA_BP
const CYP = [-0.108, -0.108, -0.188, 0.11, 0.258, 0.226, 0.344, 0.362, 0.611, 0.529, 0.298, -0.227]

# "CZq": Damping derivative: normal force due to pitch rate as a function of angle-of-attack
# dims: ALPHA_BP
const CZQ = [-8.8, -25.8, -28.9, -31.4, -31.2, -30.7, -27.7, -28.2, -29, -29.8, -38.3, -35.3]

# "Clr": Damping derivative: rolling moment due to yaw rate as a function of angle-of-attack
# dims: ALPHA_BP
const CLR = [-0.126, -0.026, 0.063, 0.113, 0.208, 0.23, 0.319, 0.437, 0.68, 0.1, 0.447, -0.33]

# "Clp": Damping derivative: rolling moment due to roll rate as a function of angle-of-attack
# dims: ALPHA_BP
const CLP = [-0.36, -0.359, -0.443, -0.42, -0.383, -0.375, -0.329, -0.294, -0.23, -0.21, -0.12, -0.1]

# "Cmq": Damping derivative: pitching moment due to pitch rate as a function of angle-of-attack
# dims: ALPHA_BP
const CMQ = [-7.21, -5.4, -5.23, -5.26, -6.11, -6.64, -5.69, -6, -6.2, -6.4, -6.6, -6]

# "Cnr": Damping derivative: yawing moment due to yaw rate as a function of angle-of-attack
# dims: ALPHA_BP
const CNR = [-0.38, -0.363, -0.378, -0.386, -0.37, -0.453, -0.55, -0.582, -0.595, -0.637, -1.02, -0.84]

# "Cnp": Damping derivative: yawing moment due to roll rate as a function of angle-of-attack
# dims: ALPHA_BP
const CNP = [0.061, 0.052, 0.052, -0.012, -0.013, -0.024, 0.05, 0.15, 0.13, 0.158, 0.24, 0.15]

# "dlda": Rolling moment increment due to aileron deflection as a function of angles of attack and sideslip
# dims: BETA_BP x ALPHA_BP
const DLDA = [
    -0.041 -0.052 -0.053 -0.056 -0.05 -0.056 -0.082 -0.059 -0.042 -0.038 -0.027 -0.017;
    -0.041 -0.053 -0.053 -0.053 -0.05 -0.051 -0.066 -0.043 -0.038 -0.027 -0.023 -0.016;
    -0.042 -0.053 -0.052 -0.051 -0.049 -0.049 -0.043 -0.035 -0.026 -0.016 -0.018 -0.014;
    -0.04 -0.052 -0.051 -0.052 -0.048 -0.048 -0.042 -0.037 -0.031 -0.026 -0.017 -0.012;
    -0.043 -0.049 -0.048 -0.049 -0.043 -0.042 -0.042 -0.036 -0.025 -0.021 -0.016 -0.011;
    -0.044 -0.048 -0.048 -0.047 -0.042 -0.041 -0.02 -0.028 -0.013 -0.014 -0.011 -0.01;
    -0.043 -0.049 -0.047 -0.045 -0.042 -0.037 -0.003 -0.013 -0.01 -0.003 -0.007 -0.008
]

# "dldr": Rolling moment increment due to rudder deflection as a function of angles of attack and sideslip
# dims: BETA_BP x ALPHA_BP
const DLDR = [
    0.005 0.017 0.014 0.01 -0.005 0.009 0.019 0.005 0 -0.005 -0.011 0.008;
    0.007 0.016 0.014 0.014 0.013 0.009 0.012 0.005 0 0.004 0.009 0.007;
    0.013 0.013 0.011 0.012 0.011 0.009 0.008 0.005 0 0.005 0.003 0.005;
    0.018 0.015 0.015 0.014 0.014 0.014 0.014 0.015 0.013 0.011 0.006 0.001;
    0.015 0.014 0.013 0.013 0.012 0.011 0.011 0.01 0.008 0.008 0.007 0.003;
    0.021 0.011 0.01 0.011 0.01 0.009 0.008 0.01 0.006 0.005 0 0.001;
    0.023 0.01 0.011 0.011 0.011 0.01 0.008 0.01 0.006 0.014 0.02 0
]

# "dnda": Yawing moment increment due to aileron deflection as a function of angles of attack and sideslip
# dims: BETA_BP x ALPHA_BP
const DNDA = [
    0.001 -0.027 -0.017 -0.013 -0.012 -0.016 0.001 0.017 0.011 0.017 0.008 0.016;
    0.002 -0.014 -0.016 -0.016 -0.014 -0.019 -0.021 0.002 0.012 0.016 0.015 0.011;
    -0.006 -0.008 -0.006 -0.006 -0.005 -0.008 -0.005 0.007 0.004 0.007 0.006 0.006;
    -0.011 -0.011 -0.01 -0.009 -0.008 -0.006 0 0.004 0.007 0.01 0.004 0.01;
    -0.015 -0.015 -0.014 -0.012 -0.011 -0.008 -0.002 0.002 0.006 0.012 0.011 0.011;
    -0.024 -0.01 -0.004 -0.002 -0.001 0.003 0.014 0.006 -0.001 0.004 0.004 0.006;
    -0.022 0.002 -0.003 -0.005 -0.003 -0.001 -0.009 -0.009 -0.001 0.003 -0.002 0.001
]

# "dndr": Yawing moment increment due to rudder deflection as a function of angles of attack and sideslip
# dims: BETA_BP x ALPHA_BP
const DNDR = [
    -0.018 -0.052 -0.052 -0.052 -0.054 -0.049 -0.059 -0.051 -0.03 -0.037 -0.026 -0.013;
    -0.028 -0.051 -0.043 -0.046 -0.045 -0.049 -0.057 -0.052 -0.03 -0.033 -0.03 -0.008;
    -0.037 -0.041 -0.038 -0.04 -0.04 -0.038 -0.037 -0.03 -0.027 -0.024 -0.019 -0.013;
    -0.048 -0.045 -0.045 -0.045 -0.044 -0.045 -0.047 -0.048 -0.049 -0.045 -0.033 -0.016;
    -0.043 -0.044 -0.041 -0.041 -0.04 -0.038 -0.034 -0.035 -0.035 -0.029 -0.022 -0.009;
    -0.052 -0.034 -0.036 -0.036 -0.035 -0.028 -0.024 -0.023 -0.02 -0.016 -0.01 -0.014;
    -0.062 -0.034 -0.027 -0.028 -0.027 -0.027 -0.023 -0.023 -0.019 -0.009 -0.025 -0.01
]

end # module F16AeroData
