# Velocity-scheduled MPC rollout, paired with the `partial analysis` in
# dyad/velocity_mpc_analysis.dyad. The analysis model is the plant to control: the
# bank is designed from it (one trim and one linearization per airspeed knot) and then
# flown against it, so design and rollout cannot disagree about the airframe.

import Plots

abstract type AbstractVelocityMPCAnalysisSpec <: AbstractAnalysisSpec end

"""
    VelocityMPCAnalysisSpec(; model, velocities, altitude, Ts, Np, initial_velocity,
                            final_velocity, ramp_start, ramp_duration,
                            pitch_perturbation, stop, export_dir)

Design a `VelocityMPC` bank at the airspeed knots `velocities` (m/s, all trimmed at
`altitude` m, sampled at `Ts` s over a horizon of `Np` samples) and fly `model` with
it. The rollout starts at the `initial_velocity` trim with `pitch_perturbation`
degrees added to the pitch attitude, and tracks a reference that ramps to
`final_velocity` over `ramp_duration` s beginning at `ramp_start`. `stop` is the
rollout duration and must be a whole number of sample periods. The trajectory, a
summary, and a response plot are written under `export_dir` (a relative path resolves
against the package root).
"""
@kwdef mutable struct VelocityMPCAnalysisSpec <: AbstractVelocityMPCAnalysisSpec
    name::Symbol = :VelocityMPCAnalysis
    model::Union{Nothing, System} = nothing
    velocities::Vector{Float64} = [140.0, 152.4, 170.0]
    altitude::Float64 = 3000.0
    Ts::Float64 = 0.05
    Np::Int = 40
    initial_velocity::Float64 = 148.0
    final_velocity::Float64 = 160.0
    ramp_start::Float64 = 2.0
    ramp_duration::Float64 = 12.0
    pitch_perturbation::Float64 = 2.0
    stop::Float64 = 25.0
    export_dir::String = "results/velocity_mpc"
    overrides::_Overrides = _Overrides()
end

"""
    VelocityMPCAnalysisSolution

The designed controller bank and the rollout it flew: `bank` is the scheduled
`VelocityMPCBank`, `result` the sample-aligned states, commands, references and
scheduling weights, and `files` the paths written.
"""
struct VelocityMPCAnalysisSolution{B, R} <: AbstractAnalysisSolution
    spec::VelocityMPCAnalysisSpec
    bank::B
    result::R
    files::Vector{String}
end

Base.nameof(sol::VelocityMPCAnalysisSolution) = sol.spec.name

# Speed tracking, the altitude and elevator it costs, and which members were active.
function _response_plot(bank, result)
    samples = result.t[1:(end - 1)]
    velocity = Plots.plot(result.t, result.x[7, :]; label = "Measured",
        ylabel = "Airspeed (m/s)")
    Plots.plot!(velocity, samples, result.reference[7, :];
        label = "Reference", linestyle = :dash)
    altitude = Plots.plot(result.t, result.x[3, :]; label = false, ylabel = "Altitude (m)")
    elevator = Plots.plot(samples, result.u[2, :]; label = false, ylabel = "Elevator (deg)")
    weights = Plots.plot(samples, permutedims(result.weights);
        label = permutedims(string.(bank.grid) .* " m/s"),
        ylabel = "MPC weight", xlabel = "Time (s)")
    return Plots.plot(velocity, altitude, elevator, weights;
        layout = (4, 1), size = (900, 900))
end

function DyadInterface.run_analysis(spec::VelocityMPCAnalysisSpec)
    spec.model === nothing &&
        throw(ArgumentError("VelocityMPCAnalysis needs a plant model to design against and fly"))
    lo, hi = minimum(spec.velocities), maximum(spec.velocities)
    for (name, v) in (("initial_velocity", spec.initial_velocity),
                      ("final_velocity", spec.final_velocity))
        lo <= v <= hi || throw(ArgumentError(
            "$name = $v m/s is outside the design grid [$lo, $hi] m/s"))
    end
    spec.ramp_start >= 0 || throw(ArgumentError("ramp_start must be nonnegative"))
    spec.ramp_duration > 0 || throw(ArgumentError("ramp_duration must be positive"))
    steps = round(Int, spec.stop / spec.Ts)
    isapprox(steps * spec.Ts, spec.stop; atol = 1e-10, rtol = 1e-10) || throw(ArgumentError(
        "stop = $(spec.stop) s is not a whole number of Ts = $(spec.Ts) s sample periods"))
    spec.stop >= spec.ramp_start + spec.ramp_duration || throw(ArgumentError(
        "stop = $(spec.stop) s ends before the reference ramp does at \
         $(spec.ramp_start + spec.ramp_duration) s"))

    dynamics = VelocityMPC.F16Dynamics(spec.model)
    bank = VelocityMPC.build_velocity_mpc(spec.velocities;
        altitude = spec.altitude, Ts = spec.Ts, Np = spec.Np, dynamics)
    initial = VelocityMPC.trim_point(dynamics, spec.initial_velocity; altitude = spec.altitude)
    x0 = copy(initial.x)
    # Physical channel order is VelocityMPC.STATE_NAMES: 3 is altitude, 5 the pitch
    # attitude the rollout is perturbed in, 7 true airspeed.
    x0[5] += deg2rad(spec.pitch_perturbation)
    span = spec.final_velocity - spec.initial_velocity
    reference(t) = VelocityMPC.trim_state(bank, spec.initial_velocity +
        span * clamp((t - spec.ramp_start) / spec.ramp_duration, 0, 1))
    result = VelocityMPC.simulate(bank;
        x0, reference, applied0 = initial.u, duration = spec.stop)

    dir = _resolve_export(spec.export_dir)
    mkpath(dir)
    trajectory = joinpath(dir, "trajectory.csv")
    open(trajectory, "w") do io
        println(io, "time,velocity,velocity_reference,altitude,pitch,thrust,elevator,",
            "aileron,rudder,", join(("w$i" for i in eachindex(bank.grid)), ","))
        for k in axes(result.u, 2)
            println(io, join([result.t[k], result.x[7, k], result.reference[7, k],
                result.x[3, k], result.x[5, k], result.u[:, k]..., result.weights[:, k]...], ","))
        end
    end
    summary = joinpath(dir, "summary.toml")
    open(summary, "w") do io
        TOML.print(io, Dict("velocity_grid" => bank.grid, "sample_period" => bank.Ts,
            "member_solves" => bank.solves, "final_velocity" => result.x[7, end],
            "final_altitude" => result.x[3, end], "final_pitch" => result.x[5, end]);
            sorted = true)
    end
    response = joinpath(dir, "response.png")
    Plots.savefig(_response_plot(bank, result), response)
    return VelocityMPCAnalysisSolution(spec, bank, result, [trajectory, summary, response])
end


function DyadInterface.AnalysisSolutionMetadata(sol::VelocityMPCAnalysisSolution)
    arts = ArtifactMetadata[
        ArtifactMetadata(:Response, ArtifactType.PlotlyPlot, "Response",
            "Airspeed tracking, altitude, elevator command, and scheduling weights."),
        ArtifactMetadata(:Trajectory, ArtifactType.Native, "Trajectory",
            "Sample-aligned states, commands, references, and scheduling weights."),
        ArtifactMetadata(:Bank, ArtifactType.Native, "Controller bank",
            "The scheduled MPC bank: one designed member per velocity knot."),
    ]
    for path in sol.files
        push!(arts, ArtifactMetadata(_file_artifact(path), ArtifactType.Download,
            basename(path), "Written to $path."))
    end
    # The rollout is sampled outside the ModelingToolkit solver, so there are no
    # symbolic signals to offer the customizable visualization.
    return AnalysisSolutionMetadata(arts, Symbol[])
end

function DyadInterface.artifacts(sol::VelocityMPCAnalysisSolution, name::Symbol)
    name === :Response && return _response_plot(sol.bank, sol.result)
    name === :Trajectory && return sol.result
    name === :Bank && return sol.bank
    i = findfirst(path -> _file_artifact(path) === name, sol.files)
    i === nothing && error("$name is not an artifact of this solution; available: " *
                           join(artifacts(sol), ", "))
    return sol.files[i]
end

# The bank steps the plant itself rather than handing it to a transient solve, so the
# solution holds matrices, not a symbolically indexable trajectory.
DyadInterface.symbolic_container(::VelocityMPCAnalysisSolution) = error(
    "VelocityMPCAnalysisSolution has no symbolic model to index; read the rollout \
     from the `:Trajectory` artifact, whose rows follow VelocityMPC.STATE_NAMES.")

export AbstractVelocityMPCAnalysisSpec, VelocityMPCAnalysisSpec, VelocityMPCAnalysisSolution
