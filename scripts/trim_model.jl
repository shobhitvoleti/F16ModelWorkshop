using F16ModelWorkshop
using ModelingToolkit

# Trim at 1000m altitude, 152.4 m/s velocity
result = F16LevelFlightTrim(altitude = 1000.0, velocity = 152.4)

# Access trimmed values
model = result.spec.model

# Extract trim state
alpha_trim = result.u0[findfirst(isequal(model.aircraft.alpha), unknowns(result.sys))]
theta_trim = result.u0[findfirst(isequal(model.aircraft.theta), unknowns(result.f.sys))]
T_trim = result.u0[findfirst(isequal(model.aircraft.T), unknowns(result.f.sys))]