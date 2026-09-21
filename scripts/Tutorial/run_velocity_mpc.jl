# Tutorial step 7: fly the velocity-scheduled MPC loop and plot the response into
# results/velocity_mpc/response.png.
#
#   julia --project=. scripts/Tutorial/run_velocity_mpc.jl

using DyadInterface, F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots

result = TutorialVelocityMPC()
sol = result.sol
loop = DyadInterface.symbolic_container(result)
p = loop.f16plant

# The held commands live in the clocked partition: one value per controller tick over the
# whole run, not one per solver step, so they are plotted against the tick times.
ticks(values) = range(0, sol.t[end]; length = length(values) + 1)[1:length(values)]

speed = plot(sol.t, sol[p.vt]; label = "vt", ylabel = "m/s", title = "Airspeed")
plot!(speed, sol.t, sol[loop.vt_reference]; label = "reference", linestyle = :dash)
altitude = plot(sol.t, sol[p.alt]; label = "alt", ylabel = "m", title = "Altitude")

elevator_command = sol[p.el]
elevator = plot(ticks(elevator_command), elevator_command; label = "elevator",
    ylabel = "deg", title = "Elevator", seriestype = :steppost)

thrust_command = sol[p.T] ./ 1000
thrust = plot(ticks(thrust_command), thrust_command; label = "thrust", ylabel = "kN",
    xlabel = "t [s]", title = "Thrust", seriestype = :steppost)

figure = plot(speed, altitude, elevator, thrust; layout = (4, 1), size = (900, 1100),
    legend = :best)

directory = joinpath(dirname(dirname(@__DIR__)), "results", "velocity_mpc")
mkpath(directory)
path = joinpath(directory, "response.png")
savefig(figure, path)

println("wrote ", path)
println("final airspeed = ", sol[p.vt][end], " m/s")
println("final altitude = ", sol[p.alt][end], " m")
