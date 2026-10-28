# Run tutorial analyses and save what Studio shows for each: every figure as a PNG and
# every table as a CSV, under results/<analysis>/. Prints each analysis' run time, the
# artifacts saved, and any that could not be built.
#
#   julia --project=. scripts/save_artifacts.jl TutorialGainScheduleDesign TutorialGainScheduledPID
#
# With no arguments it runs every `Tutorial*` analysis except the ones that write assets
# (`*Export`, `*Table`) or videos (`TutorialVisualize*`).

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
using DyadInterface, F16ModelWorkshop, F16ModelWorkshop.Tutorial, Plots
using DyadInterface: AnalysisSolutionMetadata, ArtifactType, artifacts

# DyadControlSystems' `LinearAnalysis` never finishes building its `RGAPlot` for the F-16's
# 4-input, 12-output plant, so it is skipped.
const DOES_NOT_FINISH = (:RGAPlot,)

writes_files(name) = endswith(name, "Export") || endswith(name, "Table") || startswith(name, "TutorialVisualize")
is_analysis(n) = startswith(String(n), "Tutorial") && getproperty(F16ModelWorkshop.Tutorial, n) isa Function &&
                 !endswith(String(n), "Spec") && !writes_files(String(n))
default = sort([String(n) for n in names(F16ModelWorkshop.Tutorial) if is_analysis(n)])
requested = isempty(ARGS) ? default : ARGS

root = joinpath(dirname(@__DIR__), "results")
for name in requested
    seconds = @elapsed result = getproperty(F16ModelWorkshop.Tutorial, Symbol(name))()
    dir = mkpath(joinpath(root, name))
    saved, failed = String[], String[]
    for art in AnalysisSolutionMetadata(result).artifacts
        art.type in (ArtifactType.PlotlyPlot, ArtifactType.DataFrame) || continue
        # The transient analysis' own all-states plot is not what a step shows.
        art.name === :SimulationSolutionPlot && continue
        art.name in DOES_NOT_FINISH && (push!(failed, "$(art.name) (not built: does not finish)"); continue)
        # An artifact that cannot be built is reported, so a presenter knows not to open it.
        value = try
            artifacts(result, art.name)
        catch err
            push!(failed, "$(art.name) ($(first(split(sprint(showerror, err), '\n'))))")
            continue
        end
        if art.type == ArtifactType.PlotlyPlot
            savefig(value, joinpath(dir, "$(art.name).png"))
        else
            open(joinpath(dir, "$(art.name).csv"), "w") do io
                println(io, join(names(value), ","))
                foreach(row -> println(io, join(row, ",")), eachrow(Matrix(value)))
            end
        end
        push!(saved, String(art.name))
    end
    println(rpad(name, 32), round(seconds; digits = 1), " s  ", join(saved, ", "))
    isempty(failed) || println(" "^32, "cannot be built: ", join(failed, "; "))
end
