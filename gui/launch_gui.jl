#!/usr/bin/env julia

using F16ModelWorkshop
using F16ModelWorkshop.Tutorial
using DyadControlSystems

include(joinpath(@__DIR__, "lqg_app.jl"))

function base_lqg_spec(spec)
    DyadControlSystems.LQGAnalysisSpec(
        name=spec.name,
        model=spec.model,
        measurement=spec.measurement,
        controlled_output=spec.controlled_output,
        control_input=spec.control_input,
        disturbance_inputs=spec.disturbance_inputs,
        loop_openings=spec.loop_openings,
        t=spec.t,
        q1_diag=spec.q1_diag,
        q2_diag=spec.q2_diag,
        r1_diag=spec.r1_diag,
        r2_diag=spec.r2_diag,
        qQ=spec.qQ,
        qR=spec.qR,
        disc=spec.disc,
        Ts=spec.Ts,
        integrator_indices=spec.integrator_indices,
        integrator_r1_diag=spec.integrator_r1_diag,
        wl=spec.wl,
        wu=spec.wu,
        num_frequencies=spec.num_frequencies,
        duration=spec.duration,
    )
end

println("Loading the F-16 tutorial LQG design...")
spec = base_lqg_spec(TutorialLQGSpec())
println("Launching live tuning dashboard (12 measurements, 5 controls)...")
state = DyadControlSystems.launch_lqg_designer(spec; elevator_weight=0.33)
