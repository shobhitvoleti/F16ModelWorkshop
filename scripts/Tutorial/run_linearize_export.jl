# Tutorial step 2 export: linearize the open-loop F16 plant about trim and write
# its state-space (A/B/C/D + I/O names) to trim/tutorial_linear_model.toml.
#
#   julia --project=. scripts/Tutorial/run_linearize_export.jl

using F16ModelWorkshop
using DyadInterface

res = F16ModelWorkshop.Tutorial.TutorialLinearizeExport()
sys = res.sys

println("Linearized plant written to: trim/tutorial_linear_model.toml")
println("  nx = ", size(sys.A, 1), "   nu = ", size(sys.B, 2), "   ny = ", size(sys.C, 1))
println("  inputs  = ", res.spec.inputs)
println("  outputs = ", res.spec.outputs)
