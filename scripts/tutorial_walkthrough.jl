# The nine workshop steps in order: each runs its analysis, then shows the result the step
# points at. Run it line by line in the REPL or VS Code, or as a whole:
#
#   julia --project=. scripts/tutorial_walkthrough.jl

using F16ModelWorkshop, F16ModelWorkshop.Tutorial, DyadInterface, Plots

# 1 — Trim
trim = TutorialTrim()
display(artifacts(trim, :TrimTable))

# 2 — Linearize
linear = TutorialLinearize()
display(artifacts(linear, :PoleZeroMap))

# 3 — LQG design, 100 Hz
lqg = TutorialDiscreteLQG()
display(artifacts(lqg, :PZMaps))

# 4 — Digital closed loop
digital = TutorialDiscreteClosedLoop()
display(artifacts(digital, :FlightResponse))

# 5 — 3-D animation (needs a display)
video = TutorialVisualizeDiscrete()
display(artifacts(video, :Animation))

# 6 — C code generation
codegen = TutorialControllerCodegen()
display(artifacts(codegen, :StepCheck))

# 7a — Gain-schedule design
gain_schedule = TutorialGainScheduleDesign()
display(artifacts(gain_schedule, :LoopShapes))

# 7b — Gain-scheduled PID autopilot
pid = TutorialGainScheduledPID()
display(artifacts(pid, :FlightResponse))

# 8 — Velocity-scheduled MPC
velocity_mpc = TutorialVelocityMPC()
display(artifacts(velocity_mpc, :FlightResponse))

# 9a — Flight envelope
envelope = TutorialEnvelope()
display(artifacts(envelope, :Envelope))

# 9b — Envelope-scheduled MPC
envelope_mpc = TutorialEnvelopeMPC()
display(artifacts(envelope_mpc, :FlightResponse))
