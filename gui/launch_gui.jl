#!/usr/bin/env julia
#=
Launch F16 LQG Controller Designer GUI

Simple launcher - just load and launch!
=#

println("Loading packages...")
using F16ModelWorkshop
using DyadControlSystems

println("Loading GUI app...")
include(joinpath(@__DIR__, "lqg_app.jl"))

println("\nCreating F16 LQG spec...")
spec = F16ModelWorkshop.F16ReducedLQGControllerAnalysisSpec()

# Convert to base LQGAnalysisSpec
base_spec = DyadControlSystems.LQGAnalysisSpec(
    name = spec.name,
    model = spec.model,
    measurement = spec.measurement,
    controlled_output = spec.controlled_output,
    control_input = spec.control_input,
    disturbance_inputs = spec.disturbance_inputs,
    loop_openings = spec.loop_openings,
    t = spec.t,
    q1_diag = spec.q1_diag,
    q2_diag = spec.q2_diag,
    r1_diag = spec.r1_diag,
    r2_diag = spec.r2_diag,
    qQ = spec.qQ,
    qR = spec.qR,
    disc = spec.disc,
    Ts = spec.Ts,
    integrator_indices = spec.integrator_indices,
    integrator_r1_diag = spec.integrator_r1_diag,
    wl = spec.wl,
    wu = spec.wu,
    num_frequencies = spec.num_frequencies,
    duration = spec.duration,
)

println("\nF16 Configuration:")
println("  Measurements: ", length(base_spec.measurement))
println("  Control inputs: ", length(base_spec.control_input))
println("\nLaunching GUI...")

# Simple interface - just like you wanted!
state = DyadControlSystems.launch_lqg_designer(base_spec)

println("\n✓ GUI launched!")
