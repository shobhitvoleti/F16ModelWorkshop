module F16ModelWorkshop

using ModelingToolkit, OrdinaryDiffEqDefault, NonlinearSolve
import Symbolics: unwrap
export unwrap
export ControllerA, ControllerB, ControllerC, ControllerD
export DiscreteControllerA, DiscreteControllerB, DiscreteControllerC, DiscreteControllerD
export ControllerTs

include("output.jl")

# Defined BEFORE the generated code so Dyad components can reference the discrete
# controller matrices (DiscreteControllerA/B/C/D, ControllerTs) in parameter
# defaults.  Depends on ControllerA-D from output.jl.
include("discrete_controller.jl")

# Defined BEFORE the generated code so Dyad components can call load_trim in
# parameter defaults (see dyad/Trimming/f16_trimmed_plant_linked.dyad).
include("trim_io.jl")

include("../generated/module.jl")

# Defined AFTER the generated code: references the generated Trimming.F16Trim model.
include("trim_plant_analysis.jl")

end