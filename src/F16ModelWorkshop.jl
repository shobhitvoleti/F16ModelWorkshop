module F16ModelWorkshop

using ModelingToolkit, OrdinaryDiffEqDefault, NonlinearSolve
import Symbolics: unwrap
export unwrap
export ControllerTs

# Defined BEFORE the generated code so Dyad components can reference ControllerTs
# in parameter defaults. The controller matrices themselves now live in
# assets/controller.toml and assets/discrete_controller.toml, applied at the block.
include("discrete_controller.jl")

# Defined BEFORE the generated code so Dyad components can call load_trim in
# parameter defaults (see dyad/Trimming/f16_trimmed_plant_linked.dyad).
include("trim_io.jl")

# Custom analysis specs (extendable from Dyad via `partial analysis`) must be
# defined BEFORE the generated code that references them.
include("tutorial_export_analyses.jl")
include("discrete_closed_loop_analysis.jl")
include("visualize_analysis.jl")

include("../generated/module.jl")

# Defined AFTER the generated code: references the generated Tutorial.TrimDemo model.
include("trim_plant_analysis.jl")

end