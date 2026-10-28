using Test
using F16ModelWorkshop
using F16ModelWorkshop.Tutorial
using F16ModelWorkshop.ScheduledPID
using DyadInterface
using DyadInterface: AnalysisSolutionMetadata, artifacts
import Plots
import TOML

# Studio shows an analysis through its artifacts. These tests check that each tutorial
# analysis offers the artifacts its step refers to, with the content the step describes.

artifact_names(result) = [a.name for a in AnalysisSolutionMetadata(result).artifacts]

# Studio lists every artifact an analysis declares; each must open.
opens_every_artifact(result) = all(name -> (artifacts(result, name); true), artifact_names(result))

@testset "flight analysis panels" begin
    @test F16ModelWorkshop.parse_panel("Airspeed (m/s): f16plant.vt, vt_reference") ==
          ("Airspeed (m/s)", ["f16plant.vt", "vt_reference"])
    # The title may contain a colon of its own; the signals follow the last one.
    @test F16ModelWorkshop.parse_panel("Ratio 1:2: a")[1] == "Ratio 1:2"
    @test_throws "a panel is" F16ModelWorkshop.parse_panel("no colon here")
    @test_throws "lists no signals" F16ModelWorkshop.parse_panel("Empty: ")

    result = TutorialDiscreteClosedLoop()
    @test :FlightResponse in artifact_names(result)
    panels = F16ModelWorkshop.flight_panels(result)
    @test length(panels) == 5
    # Continuous signals follow the solver's steps; the held elevator has one value per
    # 100 Hz tick over the 10 s run, drawn as steps.
    (_, (_, t_theta, _, clocked_theta)) = (panels[1][1], only(panels[1][2]))
    @test !clocked_theta && length(t_theta) == length(result.sol.t)
    (_, t_el, el, clocked_el) = only(panels[4][2])
    @test clocked_el && length(el) == 1000 && t_el[2] - t_el[1] ≈ ControllerTs
    @test artifacts(result, :FlightResponse) isa Plots.Plot
    @test opens_every_artifact(result)

    # A misspelt signal fails the run, not the figure.
    spec = F16ModelWorkshop.FlightAnalysisSpec(; model = DiscreteClosedLoopDemo(; name = :m),
        stop = 0.1, panels = ["Typo: f16plant.vtt"])
    @test_throws "no `vtt`" DyadInterface.run_analysis(spec)
end

@testset "trim analysis shows the trim" begin
    result = TutorialTrim()
    @test isempty(result.files)                       # TutorialTrim writes no assets
    table = artifacts(result, :TrimTable)
    value(name) = only(table.value[table.name .== name])
    @test value("alpha") ≈ rad2deg(0.059129) atol = 1e-3
    @test value("vt") ≈ 152.4
    @test 10_000 < value("T") < 12_000               # newtons
    @test only(table.unit[table.name .== "el"]) == "deg"
    @test opens_every_artifact(result)
end

# Step 7's point: with the schedule, every design point's pitch loop crosses over at the
# design frequency; with one design point's gains everywhere, the crossover moves.
@testset "gain schedule design shows what the schedule corrects" begin
    result = TutorialGainScheduleDesign()
    @test issubset([:GainSchedule, :LoopShapes, :Margins, :GainTable], artifact_names(result))
    margins = artifacts(result, :Margins)
    pitch = margins[margins.loop .== "Pitch attitude", :]
    @test all(isapprox.(pitch.crossover_scheduled_rad_s, ScheduledPID.PITCH_LOOP.crossover; rtol = 0.05))
    @test pitch.crossover_fixed_rad_s[1] < 0.95 * ScheduledPID.PITCH_LOOP.crossover
    @test pitch.crossover_fixed_rad_s[end] > 1.10 * ScheduledPID.PITCH_LOOP.crossover
    table = artifacts(result, :GainTable)
    @test Matrix(table[:, collect(ScheduledPID.SCHEDULE_ROWS)]) == permutedims(gain_table())
    @test artifacts(result, :LoopShapes) isa Plots.Plot
    @test artifacts(result, :GainSchedule) isa Plots.Plot
end

@testset "controller export writes the designed controller" begin
    file = joinpath(mktempdir(), "discrete_controller.toml")
    spec = F16ModelWorkshop.ControllerExportAnalysisSpec(; design = "TutorialDiscreteLQG", file,
        add_trim = true)
    result = DyadInterface.run_analysis(spec)
    @test artifacts(result, :Controller) == file
    written = TOML.parsefile(file)
    matrix(rows) = reduce(vcat, permutedims.(Vector{Float64}.(rows)))
    @test matrix(written["A"]) == result.inner.Cfb.A
    @test matrix(written["D"]) == result.inner.Cfb.D
    @test written["y0"] == F16ModelWorkshop.trim_asset("trim_controls")
    @test_throws "has no analysis" DyadInterface.run_analysis(
        F16ModelWorkshop.ControllerExportAnalysisSpec(; design = "TutorialNoSuchThing", file))
end

@testset "generated C computes the designed controller" begin
    result = TutorialControllerCodegen()
    check = artifacts(result, :StepCheck)
    julia = only(check[check.backend .== "Julia", :])
    @test julia.ticks == 200 && julia.max_abs_error < 1e-9
    files = artifacts(result, :GeneratedFiles)
    @test "top.c" in files.file && "top.h" in files.file
end

# The numbers of a CSV table, one vector per line (the header's empty corner cell dropped).
csv_numbers(path) = [parse.(Float64, filter(!isempty, split(line, ','))) for line in eachline(path)]

@testset "envelope analysis rebuilds the committed trim table" begin
    dir = mktempdir()
    spec = F16ModelWorkshop.EnvelopeAnalysisSpec(; velocities = [140.0, 250.0],
        altitudes = [0.0, 9000.0], points = 4, table_dir = dir)
    result = DyadInterface.run_analysis(spec)
    @test length(result.nodes) == 9
    # Same grid, and the same trims to round-off: the last bits of a Newton solve vary
    # with platform and package versions.
    rebuilt = csv_numbers(artifacts(result, :TrimTable))
    committed = csv_numbers(F16ModelWorkshop.asset_path("envelope_trim_alpha.csv"))
    @test length.(rebuilt) == length.(committed)
    @test reduce(vcat, rebuilt) ≈ reduce(vcat, committed) rtol = 1e-10
    @test artifacts(result, :Envelope) isa Plots.Plot
end
