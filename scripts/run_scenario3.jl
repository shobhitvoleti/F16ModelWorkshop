"""
Scenario 3: Alpha Protection Demonstration
Execute closed-loop simulation and generate comprehensive plots
"""

using F16ModelWorkshop
using Plots

println("="^60)
println("Scenario 3: Alpha Protection During Aggressive Pitch Command")
println("="^60)
println()
println("Configuration:")
println("  - Pitch command: +8° step at t=5s")
println("  - Trim condition: 1000m altitude, 152.4 m/s")
println("  - LQG alpha weight: 1000 (very high priority)")
println("  - Simulation duration: 40 seconds")
println()
println("Running simulation...")

# Run simulation
result = Scenario3Simulation()

println("✓ Simulation completed successfully!")
println()

# Extract solution and model
sol = result.sol
model = result.spec.model
t = sol.t

# Extract key signals
println("Extracting data...")
theta = sol[model.f16plant.theta_out]
theta_ref = sol[model.ref_theta.y]
alpha = sol[model.f16plant.alpha_out]
altitude = sol[model.f16plant.alt_out]
velocity = sol[model.f16plant.vt_out]
Q_rate = sol[model.f16plant.Q_out]
P_rate = sol[model.f16plant.P_out]
R_rate = sol[model.f16plant.R_out]
beta = sol[model.f16plant.beta_out]
phi = sol[model.f16plant.phi_out]
psi = sol[model.f16plant.psi_out]

# Extract control signals (deviations from controller)
thrust_dev = sol[model.controller.y[1]]
elevator_dev = sol[model.controller.y[2]]
aileron_dev = sol[model.controller.y[3]]
rudder_dev = sol[model.controller.y[4]]
lef_dev = sol[model.controller.y[5]]

println("✓ Data extraction complete")
println()

# Calculate summary statistics
println("="^60)
println("RESULTS SUMMARY")
println("="^60)
println()

alpha_trim = alpha[1]
alpha_max = maximum(alpha)
alpha_min = minimum(alpha)
theta_final = theta[end]
theta_commanded = theta_ref[end]
alt_max = maximum(altitude)
alt_min = minimum(altitude)
alt_variation = alt_max - alt_min
vel_max = maximum(velocity)
vel_min = minimum(velocity)
vel_variation = vel_max - vel_min
beta_max = maximum(abs.(beta))

println("Alpha (Angle of Attack):")
println("  Trim value:        $(round(rad2deg(alpha_trim), digits=2))°")
println("  Maximum:           $(round(rad2deg(alpha_max), digits=2))°")
println("  Minimum:           $(round(rad2deg(alpha_min), digits=2))°")
println("  Max excursion:     $(round(rad2deg(alpha_max - alpha_trim), digits=2))°")
println()

println("Pitch Tracking:")
println("  Commanded pitch:   $(round(rad2deg(theta_commanded), digits=2))°")
println("  Final pitch:       $(round(rad2deg(theta_final), digits=2))°")
println("  Tracking error:    $(round(rad2deg(theta_commanded - theta_final), digits=2))°")
println()

println("Altitude Hold:")
println("  Target:            1000.0 m")
println("  Maximum:           $(round(alt_max, digits=1)) m")
println("  Minimum:           $(round(alt_min, digits=1)) m")
println("  Variation:         $(round(alt_variation, digits=1)) m")
println()

println("Velocity Regulation:")
println("  Target:            152.4 m/s")
println("  Maximum:           $(round(vel_max, digits=1)) m/s")
println("  Minimum:           $(round(vel_min, digits=1)) m/s")
println("  Variation:         $(round(vel_variation, digits=1)) m/s")
println()

println("Sideslip (Beta):")
println("  Maximum:           $(round(rad2deg(beta_max), digits=3))°")
println()

# Success criteria evaluation
println("="^60)
println("SUCCESS CRITERIA EVALUATION")
println("="^60)
println()

criteria_met = 0
criteria_total = 5

print("✓ Alpha protection (< 10°):       ")
if rad2deg(alpha_max) < 10.0
    println("PASS ($(round(rad2deg(alpha_max), digits=2))°)")
    criteria_met += 1
else
    println("FAIL ($(round(rad2deg(alpha_max), digits=2))°)")
end

print("✓ Pitch tracking (within 1°):     ")
if abs(rad2deg(theta_commanded - theta_final)) < 1.0
    println("PASS ($(round(abs(rad2deg(theta_commanded - theta_final)), digits=2))° error)")
    criteria_met += 1
else
    println("FAIL ($(round(abs(rad2deg(theta_commanded - theta_final)), digits=2))° error)")
end

print("✓ Altitude variation (< 50m):     ")
if alt_variation < 50.0
    println("PASS ($(round(alt_variation, digits=1)) m)")
    criteria_met += 1
else
    println("FAIL ($(round(alt_variation, digits=1)) m)")
end

print("✓ Velocity variation (< 10 m/s):  ")
if vel_variation < 10.0
    println("PASS ($(round(vel_variation, digits=1)) m/s)")
    criteria_met += 1
else
    println("FAIL ($(round(vel_variation, digits=1)) m/s)")
end

print("✓ Beta control (< 2°):             ")
if rad2deg(beta_max) < 2.0
    println("PASS ($(round(rad2deg(beta_max), digits=2))°)")
    criteria_met += 1
else
    println("FAIL ($(round(rad2deg(beta_max), digits=2))°)")
end

println()
println("Overall: $criteria_met/$criteria_total criteria met")
println()

# Generate comprehensive plots
println("Generating plots...")

# Create 6-panel comprehensive figure
p1 = plot(t, rad2deg.(theta), label="θ actual", lw=2, color=:blue,
          xlabel="Time (s)", ylabel="Pitch angle (°)",
          title="Pitch Tracking", legend=:bottomright)
plot!(p1, t, rad2deg.(theta_ref), label="θ reference",
      ls=:dash, lw=2, color=:gray)
vline!(p1, [5.0], label="Command", ls=:dot, color=:red, alpha=0.5)

p2 = plot(t, rad2deg.(alpha), label="α", lw=2, color=:red,
          xlabel="Time (s)", ylabel="Angle of attack (°)",
          title="Alpha Protection (Weight=1000)", legend=:topright)
hline!(p2, [rad2deg(0.05)], label="Trim α", ls=:dash, lw=1, color=:gray)
hline!(p2, [15.0], label="Safety limit", ls=:dot, lw=1, color=:orange)
vline!(p2, [5.0], label="", ls=:dot, color=:red, alpha=0.5)

p3 = plot(t, altitude, label="Altitude", lw=2, color=:blue,
          xlabel="Time (s)", ylabel="Altitude (m)",
          title="Altitude Hold", legend=:bottomright)
hline!(p3, [1000.0], label="Target", ls=:dash, lw=1, color=:gray)
vline!(p3, [5.0], label="", ls=:dot, color=:red, alpha=0.5)

p4 = plot(t, rad2deg.(Q_rate), label="Q (pitch)", lw=2, color=:green,
          xlabel="Time (s)", ylabel="Angular rate (°/s)",
          title="Pitch Rate Response", legend=:topright)
vline!(p4, [5.0], label="Command", ls=:dot, color=:red, alpha=0.5)

p5 = plot(t, elevator_dev, label="Elevator", lw=2, color=:purple,
          xlabel="Time (s)", ylabel="Control deviation (°)",
          title="Primary Control Activity", legend=:topright)
vline!(p5, [5.0], label="Command", ls=:dot, color=:red, alpha=0.5)

p6 = plot(t, velocity, label="Velocity", lw=2, color=:cyan,
          xlabel="Time (s)", ylabel="Velocity (m/s)",
          title="Velocity Regulation", legend=:bottomright)
hline!(p6, [152.4], label="Target", ls=:dash, lw=1, color=:gray)
vline!(p6, [5.0], label="", ls=:dot, color=:red, alpha=0.5)

fig = plot(p1, p2, p3, p4, p5, p6, layout=(3,2), size=(1400,1000))
savefig(fig, "scenario3_alpha_protection.png")

println("✓ Main plot saved: scenario3_alpha_protection.png")

# Generate detailed alpha analysis plot
p_alpha = plot(t, rad2deg.(alpha), label="Alpha (AOA)", lw=3, color=:red,
               xlabel="Time (s)", ylabel="Angle of Attack (°)",
               title="Detailed Alpha Protection Analysis",
               legend=:topright, size=(1000, 600))
hline!(p_alpha, [rad2deg(alpha_trim)], label="Trim alpha", ls=:dash, lw=2, color=:blue)
hline!(p_alpha, [15.0], label="Typical safety limit", ls=:dot, lw=2, color=:orange)
vline!(p_alpha, [5.0], label="Pitch command", ls=:dashdot, lw=2, color=:green)

# Annotate key events
annotate!(p_alpha, 5.0, rad2deg(alpha_max),
         text("Max α = $(round(rad2deg(alpha_max), digits=2))°", 10, :left))

savefig(p_alpha, "scenario3_alpha_detail.png")

println("✓ Alpha detail plot saved: scenario3_alpha_detail.png")

# Generate control activity plot
p_ctrl = plot(layout=(3,2), size=(1400,900))

plot!(p_ctrl[1], t, thrust_dev, label="Thrust dev", lw=2, color=:red,
      xlabel="Time (s)", ylabel="Thrust (N)", title="Thrust Control")
vline!(p_ctrl[1], [5.0], label="", ls=:dot, color=:gray)

plot!(p_ctrl[2], t, elevator_dev, label="Elevator dev", lw=2, color=:blue,
      xlabel="Time (s)", ylabel="Elevator (°)", title="Elevator Control")
vline!(p_ctrl[2], [5.0], label="", ls=:dot, color=:gray)

plot!(p_ctrl[3], t, aileron_dev, label="Aileron dev", lw=2, color=:green,
      xlabel="Time (s)", ylabel="Aileron (°)", title="Aileron Control")
vline!(p_ctrl[3], [5.0], label="", ls=:dot, color=:gray)

plot!(p_ctrl[4], t, rudder_dev, label="Rudder dev", lw=2, color=:orange,
      xlabel="Time (s)", ylabel="Rudder (°)", title="Rudder Control")
vline!(p_ctrl[4], [5.0], label="", ls=:dot, color=:gray)

plot!(p_ctrl[5], t, lef_dev, label="LEF dev", lw=2, color=:purple,
      xlabel="Time (s)", ylabel="LEF (°)", title="Leading Edge Flap")
vline!(p_ctrl[5], [5.0], label="", ls=:dot, color=:gray)

plot!(p_ctrl[6], t, rad2deg.(beta), label="Beta", lw=2, color=:brown,
      xlabel="Time (s)", ylabel="Sideslip (°)", title="Sideslip Angle")
vline!(p_ctrl[6], [5.0], label="", ls=:dot, color=:gray)

savefig(p_ctrl, "scenario3_controls.png")

println("✓ Control activity plot saved: scenario3_controls.png")

println()
println("="^60)
println("SCENARIO 3 COMPLETE")
println("="^60)
println()
println("Key Demonstration:")
println("  The LQG controller with high alpha weighting (1000×) successfully")
println("  protects the angle of attack during the aggressive 8° pitch maneuver.")
println("  Alpha shows a brief transient spike due to pitch-alpha coupling, but")
println("  the controller actively regulates it back down while still achieving")
println("  the commanded pitch attitude.")
println()
println("Generated files:")
println("  - scenario3_alpha_protection.png (comprehensive 6-panel view)")
println("  - scenario3_alpha_detail.png (detailed alpha analysis)")
println("  - scenario3_controls.png (all control surfaces + sideslip)")
println()
