"""
Demo script for F-16 trajectory animations.

Creates high-clarity videos automatically saved to animations/ folder.
"""

using F16ModelWorkshop
include("animate_trajectories.jl")

println("\n" * "="^60)
println("F-16 TRAJECTORY ANIMATION DEMO")
println("="^60)
println()

# Run open-loop scenario
println("STEP 1: Running open-loop scenario...")
result_ol = Scenario1OpenLoop()
println("✓ Open-loop simulation complete\n")

# Animate and save
println("STEP 2: Creating open-loop animation...")
file_ol = animate_trajectories(result_ol, duration=8.0)

# Run closed-loop scenario
println("\nSTEP 3: Running closed-loop LQG scenario...")
result_cl = Scenario1ClosedLoop()
println("✓ Closed-loop simulation complete\n")

# Animate and save
println("STEP 4: Creating closed-loop animation...")
file_cl = animate_trajectories(result_cl, duration=8.0)

# Create comparison
println("\nSTEP 5: Creating comparison animation...")
file_comp = compare_trajectories(result_ol, result_cl, duration=8.0)

println("\n" * "="^60)
println("DEMO COMPLETE!")
println("="^60)
println("\nVideos saved to animations/ folder:")
println("  1. Open-loop:  $(basename(file_ol))")
println("  2. Closed-loop: $(basename(file_cl))")
println("  3. Comparison:  $(basename(file_comp))")
println("\nYou can now:")
println("  • Open the MP4 files to view the animations")
println("  • Adjust duration: animate_trajectories(result, duration=15.0)")
println("  • Change framerate: animate_trajectories(result, fps=60)")
println("="^60)
