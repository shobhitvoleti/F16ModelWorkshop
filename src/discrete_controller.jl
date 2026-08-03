# Controller sample time, referenced by Dyad components as a parameter default
# (the PeriodicClock period in the discrete closed loop, and the Ts of the discrete
# LQG design). Included before the generated code.
#
# The controller matrices are not here: they are package assets
# (assets/discrete_controller.toml) applied directly to the DiscreteStateSpace block,
# so the design round-trips through a file Dyad validates rather than Julia literals.
const ControllerTs = 0.01
