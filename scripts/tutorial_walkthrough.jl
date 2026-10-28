# Run the nine workshop steps in order and report the result each step points at: figures
# are written to results/walkthrough/, tables and file paths are printed.
#
#   julia --project=. scripts/tutorial_walkthrough.jl              # every step
#   julia --project=. scripts/tutorial_walkthrough.jl --no-video   # skip step 5 (needs a display)

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
using F16ModelWorkshop, F16ModelWorkshop.Tutorial, DyadInterface, Plots
using DyadInterface: AnalysisSolutionMetadata, ArtifactType, artifacts

# Steps 2 and 3 show their single-panel results: the multi-panel step-response and Bode
# figures are interactive Studio views that do not export to a static image.
const STEPS = [
    ("1",  "Trim",                         TutorialTrim,               [:TrimTable]),
    ("2",  "Linearize",                    TutorialLinearize,          [:PoleZeroMap, :DampReport]),
    ("3",  "LQG design, 100 Hz",           TutorialDiscreteLQG,        [:PZMaps]),
    ("4",  "Digital closed loop",          TutorialDiscreteClosedLoop, [:FlightResponse]),
    ("5",  "3-D animation",                TutorialVisualizeDiscrete,  [:Animation]),
    ("6",  "C code generation",            TutorialControllerCodegen,  [:StepCheck, :GeneratedFiles]),
    ("7a", "Gain-schedule design",         TutorialGainScheduleDesign, [:LoopShapes, :GainSchedule, :Margins]),
    ("7b", "Gain-scheduled PID autopilot", TutorialGainScheduledPID,   [:FlightResponse]),
    ("8",  "Velocity-scheduled MPC",       TutorialVelocityMPC,        [:FlightResponse]),
    ("9a", "Flight envelope",              TutorialEnvelope,           [:Envelope]),
    ("9b", "Envelope-scheduled MPC",       TutorialEnvelopeMPC,        [:FlightResponse]),
]

skipped = "--no-video" in ARGS ? ("5",) : ()
outdir = mkpath(joinpath(dirname(@__DIR__), "results", "walkthrough"))

for (step, title, analysis, shown) in STEPS
    step in skipped && (println("\nStep $step  $title: skipped"); continue)
    seconds = @elapsed result = analysis()
    println("\nStep $step  $title  ($(nameof(analysis)), $(round(seconds; digits = 1)) s)")
    types = Dict(a.name => a.type for a in AnalysisSolutionMetadata(result).artifacts)
    for name in shown
        value = artifacts(result, name)
        if types[name] == ArtifactType.PlotlyPlot
            path = joinpath(outdir, "$(step)_$(name).png")
            savefig(value, path)
            println("  $name: $path")
        elseif types[name] == ArtifactType.DataFrame
            println("  $name:")
            show(stdout, MIME("text/plain"), value; allrows = true, allcols = true)
            println()
        else
            println("  $name: $value")
        end
    end
end
