# Tutorial step 7: design the velocity-scheduled MPC bank on the plant, fly a speed
# ramp with it, and write the trajectory, summary and response plot under
# results/velocity_mpc/.
#
#   julia --project=. scripts/Tutorial/run_velocity_mpc.jl

using F16ModelWorkshop, F16ModelWorkshop.Tutorial

res = TutorialVelocityMPC()
foreach(path -> println("wrote ", path), res.files)
println("final velocity = ", res.result.x[7, end], " m/s")
println("final altitude = ", res.result.x[3, end], " m")
