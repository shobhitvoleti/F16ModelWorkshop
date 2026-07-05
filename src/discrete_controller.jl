# Discrete-time LQG controller.
#
# The discrete controller is produced by the disc="zoh" path of
# DyadControlSystems.LQGAnalysis (Controls.F16DiscreteLQGControllerAnalysis), which
# ZOH-discretizes the LQG design at the sample time ControllerTs.  Its A/B/C/D
# matrices are captured as literals in discrete_output.jl so this remains the
# single source of truth for the discrete controller — no post-hoc c2d() of the
# continuous controller.
#
# Dyad components reference these symbols (DiscreteControllerA/B/C/D, ControllerTs)
# as parameter defaults, so this file is included before the generated code.

# Controller sample time [s] (100 Hz).  Used as the PeriodicClock period in the
# discrete closed loop and as the Ts kwarg of the discrete LQGAnalysis.
const ControllerTs = 0.01

# DiscreteControllerA/B/C/D literals (captured from the disc="zoh" LQGAnalysis).
include("discrete_output.jl")
