using Test
using F16ModelWorkshop
using F16ModelWorkshop.ScheduledPID
using F16ModelWorkshop.VelocityMPC: KNOTS, ALTITUDE
using DyadInterface
using SciMLBase
import ControlSystemsBase as CS

# Hat-function weights over strictly increasing knots, clamped at the ends: the reference
# the Dyad schedule's interpolation is checked against.
function hat_weights(knots, x)
    x = clamp(x, first(knots), last(knots))
    j = clamp(searchsortedlast(knots, x), 1, length(knots) - 1)
    t = (x - knots[j]) / (knots[j + 1] - knots[j])
    w = zeros(length(knots))
    w[j], w[j + 1] = 1 - t, t
    return w
end

# The scheduled PID must behave as the library's standard PID whenever
# its gains are constant, including while the output saturates.
@testset "scheduled PID with constant gains is the standard PID" begin
    model = F16ModelWorkshop.Tests.PIDScheduledMatchesStandard(; name = :pid)
    sol = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(; model, stop = 10.0)).sol
    @test SciMLBase.successful_retcode(sol.retcode)
    standard, scheduled = sol[model.y_standard], sol[model.y_scheduled]
    # One entry per tick: two hundred over ten seconds at 20 Hz.
    @test length(scheduled) == 200
    @test maximum(abs, scheduled .- standard) < 1e-10
    # The limit is reached, so the comparison covers the anti-windup tracking.
    @test maximum(abs, standard) ≈ 1.5
end

# Stevens & Lewis: the same design repeated at every design point. Every loop must come
# out with the crossover and margin it was designed for, at every point; the derivative
# filter, which the design leaves out, may move them only a little.
@testset "every design point meets the loop specifications" begin
    specs = (pitch = ScheduledPID.PITCH_LOOP, altitude = ScheduledPID.ALTITUDE_LOOP,
        speed = ScheduledPID.SPEED_LOOP)
    for velocity in KNOTS
        design = loop_design(velocity)
        for (name, spec) in pairs(specs)
            wgm, gm, wpm, pm = CS.margin(design.loops[name])
            @test wpm[1] ≈ spec.crossover rtol = 0.1
            # The pitch loop's unstable airframe pole makes `margin` unwrap its phase by a turn.
            @test mod(pm[1], 360) ≈ spec.margin atol = 5
        end
        # The airframe is unstable in pitch, so the pitch loop has a lower gain margin: below
        # some fraction of its gain the loop no longer holds the aircraft.
        @test CS.margin(design.loops.pitch)[2][1] < 0.5
        # Elevator effectiveness grows with dynamic pressure; the pitch gain is negative
        # because positive elevator pitches the nose down.
        @test design.pitch.K < 0
        @test design.altitude_hold.K > 0 && design.speed.K > 0
    end
end

@testset "gain table" begin
    table = gain_table()
    knots = knot_pressures()
    @test size(table) == (length(ScheduledPID.SCHEDULE_ROWS), length(KNOTS))
    @test issorted(knots)
    for (j, velocity) in pairs(KNOTS)
        design = loop_design(velocity)
        @test table[:, j] == [design.pitch.K, design.pitch.Td, design.altitude_hold.K,
            design.altitude_hold.Ti, design.altitude_hold.Td, design.speed.K, design.speed.Ti,
            design.theta_trim, design.el_trim, design.T_trim]
        @test knots[j] ≈ dynamic_pressure(ALTITUDE, velocity)
    end
    # The pitch gain is what the schedule exists for: it falls by about a quarter between
    # the first design point and the last, while the dynamic pressure rises by half.
    @test abs(table[1, end]) < 0.8 * abs(table[1, 1])
    @test_throws "at least two knots" gain_table([152.4])
end

# Stevens & Lewis: the gains at each design point must also hold the aircraft near it.
# The sampled-data loop, with the controllers discretized as `DiscretePIDScheduled` runs
# them, is checked with every design point's gains on every design point's plant, and with
# the interpolated gains at airspeeds between and beyond the design points.
@testset "schedule is stable between and around the design points" begin
    table = gain_table()
    knots = knot_pressures()
    stable(model, column) = maximum(abs, CS.poles(closed_loop(model, column))) < 1
    models = [longitudinal_model(v) for v in KNOTS]
    for model in models, j in eachindex(KNOTS)
        @test stable(model, table[:, j])
    end
    for velocity in 130.0:5.0:180.0
        column = table * hat_weights(knots, dynamic_pressure(ALTITUDE, velocity))
        @test stable(longitudinal_model(velocity), column)
    end
end

@testset "schedule interpolates on dynamic pressure" begin
    table = gain_table()
    knots = knot_pressures()
    # Between two design points, on one, and below the first (held at the end column).
    for velocity in (160.0, 152.4, 130.0)
        model = F16ModelWorkshop.Tests.GainScheduleInterpolates(; name = :schedule, velocity)
        sol = DyadInterface.run_analysis(DyadInterface.TransientAnalysisSpec(; model, stop = 0.5)).sol
        @test SciMLBase.successful_retcode(sol.retcode)
        expected = table * hat_weights(knots, dynamic_pressure(ALTITUDE, velocity))
        held = [sol[model.scheduled[i]][end] for i in eachindex(expected)]
        @test held ≈ expected rtol = 1e-10
    end
end

# The closed loop: a solved trajectory, not just a model that builds. The manoeuvre is
# step 8's, so the two controllers are held to the same tolerances.
@testset "gain-scheduled PID tracks the airspeed ramp" begin
    result = F16ModelWorkshop.Tutorial.TutorialGainScheduledPID()
    sol = result.sol
    loop = DyadInterface.symbolic_container(result)
    p = loop.f16plant

    @test SciMLBase.successful_retcode(sol.retcode)
    @test sol.t[end] ≈ 25.0

    # The schedule's dynamic pressure is the plant's.
    @test sol[p.qbar] ≈ dynamic_pressure.(sol[p.alt], sol[p.vt]) rtol = 1e-12

    # Accelerated onto the commanded 160 m/s while holding altitude and wings level.
    @test sol[p.vt][end] ≈ 160.0 atol = 0.5
    @test sol[p.alt][end] ≈ 3000.0 atol = 10.0
    @test maximum(abs, sol[p.phi]) < 0.02
    @test maximum(abs, sol[p.theta]) < 0.25
    # The ramp crosses the middle design point, so both neighbouring columns are scheduled in.
    @test maximum(sol[p.vt]) > 153.0

    # Held commands stay inside the controllers' output limits (thrust in newtons here).
    @test all(0.0 .<= sol[p.T] .<= 5.0e4)
    @test maximum(abs, sol[p.el]) <= 25.0
    @test all(==(0.0), sol[p.ail])
    @test all(==(0.0), sol[p.rud])
end
