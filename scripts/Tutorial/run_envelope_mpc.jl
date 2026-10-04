# Tutorial step 8: linearize the envelope at 10 000 flight conditions, fly the altitude-
# and velocity-scheduled MPC loop, and plot both into results/envelope_mpc/.
#
#   julia --project=. scripts/Tutorial/run_envelope_mpc.jl

using DyadInterface, F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots

directory = joinpath(dirname(dirname(@__DIR__)), "results", "envelope_mpc")
mkpath(directory)

# ---- The envelope: 100 x 100 trims and linearizations ----
seconds = @elapsed env = EnvelopeMPC.envelope()
println("linearized ", length(env.A), " flight conditions in ", round(seconds; digits = 1), " s")

table = EnvelopeMPC.trim_table()
knots_v, knots_h = table["vt"], table["alt"]
nodes = vec([(v, h) for v in knots_v, h in knots_h])
panel(z, title, label) = begin
    p = heatmap(env.velocities, env.altitudes, permutedims(z); title, xlabel = "vt [m/s]",
        ylabel = "alt [m]", colorbar_title = label)
    scatter!(p, first.(nodes), last.(nodes); color = :white, markersize = 5, label = "bank nodes")
end
envelope = plot(
    panel(rad2deg.(env.alpha), "Trim angle of attack", "deg"),
    panel(env.thrust, "Trim thrust", "kN"),
    panel(env.elevator, "Trim elevator", "deg"),
    panel(env.unstable, "Pitch divergence rate", "1/s");
    layout = (2, 2), size = (1250, 850), left_margin = 4Plots.mm, right_margin = 6Plots.mm)
savefig(envelope, joinpath(directory, "envelope.png"))

# ---- The closed loop ----
result = TutorialEnvelopeMPC()
sol = result.sol
loop = DyadInterface.symbolic_container(result)
p = loop.f16plant

# Held commands live in the clocked partition: one value per controller tick.
ticks(values) = range(0, sol.t[end]; length = length(values) + 1)[1:length(values)]

speed = plot(sol.t, sol[p.vt]; label = "vt", ylabel = "m/s", title = "Airspeed")
plot!(speed, sol.t, sol[loop.vt_reference]; label = "reference", linestyle = :dash)
altitude = plot(sol.t, sol[p.alt]; label = "alt", ylabel = "m", title = "Altitude")
plot!(altitude, sol.t, sol[loop.alt_reference]; label = "reference", linestyle = :dash)
elevator = plot(ticks(sol[p.el]), sol[p.el]; label = "elevator", ylabel = "deg",
    title = "Elevator", seriestype = :steppost)
thrust = plot(ticks(sol[p.T]), sol[p.T] ./ 1000; label = "thrust", ylabel = "kN",
    xlabel = "t [s]", title = "Thrust", seriestype = :steppost)
response = plot(speed, altitude, elevator, thrust; layout = (4, 1), size = (900, 1100))
savefig(response, joinpath(directory, "response.png"))

println("wrote ", directory)
println("final airspeed = ", sol[p.vt][end], " m/s, final altitude = ", sol[p.alt][end], " m")
