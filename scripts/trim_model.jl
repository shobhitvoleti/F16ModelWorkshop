using F16ModelWorkshop
using ModelingToolkit

# Trim at 1000m altitude, 152.4 m/s velocity
result = F16LevelFlightTrim(altitude = 1000.0, velocity = 152.4)

# Access trimmed values
model = result.sys

# Extract trim state - 12 model states
npos_trim = result.u0[findfirst(isequal(model.aircraft.npos), unknowns(result.sys))]
epos_trim = result.u0[findfirst(isequal(model.aircraft.epos), unknowns(result.sys))]
alt_trim = result.u0[findfirst(isequal(model.aircraft.alt), unknowns(result.sys))]
phi_trim = result.u0[findfirst(isequal(model.aircraft.phi), unknowns(result.sys))]
theta_trim = result.u0[findfirst(isequal(model.aircraft.theta), unknowns(result.sys))]
psi_trim = result.u0[findfirst(isequal(model.aircraft.psi), unknowns(result.sys))]
vt_trim = result.u0[findfirst(isequal(model.aircraft.vt), unknowns(result.sys))]
alpha_trim = result.u0[findfirst(isequal(model.aircraft.alpha), unknowns(result.sys))]
beta_trim = result.u0[findfirst(isequal(model.aircraft.beta), unknowns(result.sys))]
P_trim = result.u0[findfirst(isequal(model.aircraft.P), unknowns(result.sys))]
Q_trim = result.u0[findfirst(isequal(model.aircraft.Q), unknowns(result.sys))]
R_trim = result.u0[findfirst(isequal(model.aircraft.R), unknowns(result.sys))]

# Print trim states
println("Trim States:")
println("  npos (North position):  ", npos_trim, " m")
println("  epos (East position):   ", epos_trim, " m")
println("  alt (Altitude):         ", alt_trim, " m")
println("  phi (Roll angle):       ", phi_trim, " rad")
println("  theta (Pitch angle):    ", theta_trim, " rad")
println("  psi (Yaw angle):        ", psi_trim, " rad")
println("  vt (Total velocity):    ", vt_trim, " m/s")
println("  alpha (Angle of attack):", alpha_trim, " rad")
println("  beta (Sideslip angle):  ", beta_trim, " rad")
println("  P (Roll rate):          ", P_trim, " rad/s")
println("  Q (Pitch rate):         ", Q_trim, " rad/s")
println("  R (Yaw rate):           ", R_trim, " rad/s")
