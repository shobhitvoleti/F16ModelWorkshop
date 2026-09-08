# Tutorial 7: velocity-scheduled linear MPC on the nonlinear Dyad plant.
# Run from the repository root: julia --project=. dyad/Tutorial/07_velocity_mpc.jl
# See 07_velocity_mpc.md for the model, constraints, and scheduling interface.

using F16ModelWorkshop.VelocityMPC
using TOML
using Plots

# Velocity is measured in m/s; commands use N for thrust and degrees for surfaces.
bank = build_velocity_mpc()
initial = trim_point(bank.dynamics,148.0)
x0 = copy(initial.x)
x0[5] += deg2rad(2)
reference(t) = trim_state(bank,148.0 + 12.0*clamp((t-2.0)/12.0,0,1))
result = VelocityMPC.simulate(bank; x0, reference, applied0=initial.u, duration=25.0)

output = abspath(isempty(ARGS) ? joinpath(@__DIR__,"..","..","results","velocity_mpc") : ARGS[1])
mkpath(output)
open(joinpath(output,"trajectory.csv"),"w") do io
    println(io,"time,velocity,velocity_reference,altitude,pitch,thrust,elevator,aileron,rudder,w1,w2,w3")
    for k in axes(result.u,2)
        println(io,join([result.t[k],result.x[7,k],result.reference[7,k],result.x[3,k],
            result.x[5,k],result.u[:,k]...,result.weights[:,k]...],","))
    end
end
open(joinpath(output,"summary.toml"),"w") do io
    TOML.print(io,Dict("velocity_grid"=>bank.grid,"sample_period"=>bank.Ts,
        "member_solves"=>bank.solves,"final_velocity"=>result.x[7,end],
        "final_altitude"=>result.x[3,end],"final_pitch"=>result.x[5,end]); sorted=true)
end
println("Velocity MPC results: ",output)
println("Final velocity: ",result.x[7,end]," m/s; altitude: ",result.x[3,end]," m")

velocity_plot = plot(result.t,result.x[7,:]; label="Measured",ylabel="Airspeed (m/s)")
plot!(velocity_plot,result.t[1:end-1],result.reference[7,:]; label="Reference",linestyle=:dash)
altitude_plot = plot(result.t,result.x[3,:]; label=false,ylabel="Altitude (m)")
elevator_plot = plot(result.t[1:end-1],result.u[2,:]; label=false,ylabel="Elevator (deg)")
weights_plot = plot(result.t[1:end-1],permutedims(result.weights);
    label=permutedims(string.(bank.grid).*" m/s"),ylabel="MPC weight",xlabel="Time (s)")
figure = plot(velocity_plot,altitude_plot,elevator_plot,weights_plot; layout=(4,1),size=(900,900))
savefig(figure,joinpath(output,"response.png"))
