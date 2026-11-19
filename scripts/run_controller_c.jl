# Build and run Tutorial 6's C controller. Use a fresh Julia process:
#   julia --project=. scripts/run_controller_c.jl [export_dir]
# Install the compiler once if needed:
#   julia --project=. -e 'using Pkg; Pkg.add("Clang_unified_jll")'
# On macOS, Xcode Command Line Tools are also required.

Base.find_package("Clang_unified_jll") === nothing && error(
    "Install Clang_unified_jll first; see the command at the top of this script.")

# Load Clang before compiling the controller to avoid world-age errors.
import Clang_unified_jll
using F16ModelWorkshop.Tutorial: TutorialControllerCodegen
import SynchJulia

Base.get_extension(SynchJulia, :SynchJuliaClangExt) === nothing &&
    error("SynchJulia's Clang extension did not load.")

length(ARGS) <= 1 || error("Usage: run_controller_c.jl [export_dir]")
export_dir = isempty(ARGS) ?
    joinpath(@__DIR__, "..", "agent_outputs", "f16_controller_c") : abspath(only(ARGS))

# This analysis builds and loads C, then checks 200 ticks against the saved design.
result = TutorialControllerCodegen(; export_dir)
show(stdout, MIME"text/plain"(), result.check)
println()

c_check = only(row for row in eachrow(result.check) if row.backend == "C")
c_check.ticks == 200 && isfinite(c_check.max_abs_error) &&
    c_check.status == "matches the designed controller" || error("C controller check failed.")
println("C controller check passed. Sources: ", result.export_dir)
