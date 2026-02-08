"""
High-clarity 3D trajectory animation for F-16 flight scenarios.

Usage:
    result = Scenario1OpenLoop()
    animate_trajectories(result)  # Auto-saves to animations/
    
    result_cl = Scenario1ClosedLoop()
    animate_trajectories(result_cl)
"""

using GLMakie
using Rotations
using GeometryBasics
using LinearAlgebra
using Printf
using Dates

# Create output directory
const ANIM_DIR = joinpath(@__DIR__, "..", "animations")
mkpath(ANIM_DIR)

"""
    animate_trajectories(result; kwargs...)

Create high-clarity 3D visualization and automatically save to animations/ folder.

# Arguments
- `result`: Solution from Scenario1OpenLoop(), Scenario1ClosedLoop(), or similar

# Keyword Arguments
- `title::String`: Plot title (default: auto-detected)
- `filename::String`: Output filename (default: auto-generated with timestamp)
- `fps::Int`: Video framerate (default: 30)
- `duration::Real`: Target video duration in seconds (default: 10.0)
"""
function animate_trajectories(result; 
                              title=nothing,
                              filename=nothing,
                              fps=30,
                              duration=10.0)
    
    println("=" ^ 60)
    println("F-16 TRAJECTORY ANIMATION")
    println("=" ^ 60)
    
    # Extract solution
    sol = hasproperty(result, :sol) ? result.sol : result.solution
    sys = hasproperty(result, :sys) ? result.sys : result.system
    t_sim = sol.t
    
    # Auto-detect scenario name
    if title === nothing
        if hasproperty(sys, :f16plant)
            # Check if it has controller (closed-loop)
            has_controller = any(s -> occursin("controller", string(s)), propertynames(sys))
            title = has_controller ? "Closed-Loop LQG Response" : "Open-Loop Response"
        else
            title = "F-16 Flight Trajectory"
        end
    end
    
    # Generate filename with timestamp
    if filename === nothing
        timestamp = replace(string(now()), ":" => "-", "." => "-")
        safe_title = replace(lowercase(title), " " => "_", "-" => "_")
        filename = joinpath(ANIM_DIR, "$(safe_title)_$(timestamp).mp4")
    elseif !isabspath(filename)
        filename = joinpath(ANIM_DIR, filename)
    end
    
    println("Title: $title")
    println("Output: $filename")
    
    # Find plant component
    plant = hasproperty(sys, :f16plant) ? sys.f16plant : sys
    
    # Create interpolated time vector for target video duration
    n_video_frames = round(Int, duration * fps)
    t = range(t_sim[1], t_sim[end], length=n_video_frames)
    
    println("\nVideo settings:")
    println("  Simulation time points: $(length(t_sim))")
    println("  Simulation duration: $(t_sim[end]) s")
    println("  Target video duration: $(duration) s")
    println("  Target FPS: $(fps)")
    println("  Video frames: $(n_video_frames)")
    println("  Actual duration: $(length(t) / fps) s")
    
    # Extract state trajectories at interpolated times
    println("\nInterpolating states...")
    npos = [sol(ti, idxs=plant.npos) for ti in t]
    epos = [sol(ti, idxs=plant.epos) for ti in t]
    alt = [sol(ti, idxs=plant.alt) for ti in t]
    phi = [sol(ti, idxs=plant.phi) for ti in t]
    theta = [sol(ti, idxs=plant.theta) for ti in t]
    psi = [sol(ti, idxs=plant.psi) for ti in t]
    vt = [sol(ti, idxs=plant.vt) for ti in t]
    alpha = [sol(ti, idxs=plant.alpha) for ti in t]
    
    # Print trajectory statistics
    println("\nTrajectory statistics:")
    println("  Altitude: $(round(minimum(alt), digits=1)) to $(round(maximum(alt), digits=1)) m")
    println("  Velocity: $(round(minimum(vt), digits=1)) to $(round(maximum(vt), digits=1)) m/s")
    println("  Pitch: $(round(rad2deg(minimum(theta)), digits=1)) to $(round(rad2deg(maximum(theta)), digits=1))°")
    
    # Pre-compute rotations for all frames
    # Note: Negate theta because F-16 uses NED (Z-down) but we visualize Z-up
    println("\nPre-computing rotations...")
    rotations = [RotXYZ(phi[i], -theta[i], psi[i]) for i in 1:length(t)]
    frame_indices = 1:length(t)
    
    # Create figure - white background for clarity
    fig = Figure(size=(1920, 1080), backgroundcolor=:white)
    
    # Large 3D plot - main focus
    ax3d = Axis3(fig[1:3, 1:3],
                 xlabel="East (m)", 
                 ylabel="North (m)", 
                 zlabel="Altitude (m)",
                 title=title,
                 titlesize=36,
                 xlabelsize=24,
                 ylabelsize=24,
                 zlabelsize=24,
                 aspect=:data,
                 elevation=π/6,
                 azimuth=π/4,
                 backgroundcolor=:white)
    
    # Large, clear state plots on the side
    ax_alt = Axis(fig[1, 4], 
                  ylabel="Altitude (m)",
                  ylabelsize=20,
                  xlabelsize=18,
                  backgroundcolor=:white,
                  xticklabelsvisible=false)
    
    ax_theta = Axis(fig[2, 4], 
                    ylabel="Pitch (deg)",
                    ylabelsize=20,
                    xlabelsize=18,
                    backgroundcolor=:white,
                    xticklabelsvisible=false)
    
    ax_vt = Axis(fig[3, 4], 
                 ylabel="Velocity (m/s)", 
                 xlabel="Time (s)",
                 ylabelsize=20,
                 xlabelsize=18,
                 backgroundcolor=:white)
    
    # Create larger, more visible aircraft mesh
    function create_aircraft_mesh(scale=100.0)  # Much larger for visibility
        # Wing shape: swept delta wing with fuselage
        vertices = Point3f[
            # Fuselage nose
            (1.5*scale, 0, 0),
            # Fuselage tail
            (-1.0*scale, 0, 0),
            # Left wing tip
            (-0.5*scale, -1.5*scale, 0),
            # Right wing tip  
            (-0.5*scale, 1.5*scale, 0),
            # Vertical stabilizer top
            (-0.8*scale, 0, 0.5*scale),
        ]
        
        # Faces for solid mesh
        faces = [
            TriangleFace(1, 2, 3),  # Left wing
            TriangleFace(1, 2, 4),  # Right wing
            TriangleFace(2, 3, 4),  # Trailing edge
            TriangleFace(2, 4, 5),  # Vertical stabilizer right
            TriangleFace(2, 3, 5),  # Vertical stabilizer left
        ]
        
        return GeometryBasics.Mesh(vertices, faces)
    end
    
    aircraft_mesh = create_aircraft_mesh()
    
    # Pre-compute degrees for plotting
    theta_deg = rad2deg.(theta)
    alpha_deg = rad2deg.(alpha)
    
    # Record animation directly to file
    println("\nRendering animation...")
    progress_step = max(1, length(frame_indices) ÷ 20)
    
    record(fig, filename, enumerate(frame_indices); framerate=fps) do (iframe, idx)
        # Progress indicator
        if iframe % progress_step == 0
            pct = round(Int, 100 * iframe / length(frame_indices))
            println("  Progress: $pct%")
        end
        
        # Clear 3D axis for this frame
        empty!(ax3d)
        
        # TRAJECTORY: Full path in light gray (very visible)
        lines!(ax3d, epos, npos, alt, 
               color=:gray60, 
               linewidth=3,
               transparency=true)
        
        # AIRCRAFT: Transform and plot
        pos = Point3f(epos[idx], npos[idx], alt[idx])
        rot_idx = findfirst(==(idx), frame_indices)
        rot = rotations[rot_idx]
        
        original_vertices = coordinates(aircraft_mesh)
        transformed_verts = [Point3f(rot * Vec3f(v) + Vec3f(pos)) for v in original_vertices]
        transformed = GeometryBasics.Mesh(transformed_verts, faces(aircraft_mesh))
        
        mesh!(ax3d, transformed, color=:red)
        
        # NOSE DIRECTION ARROW: Shows where aircraft nose is pointing
        # Transform from body frame to NED frame using DCM, then NED to visualization frame
        nose_body = [1.0, 0.0, 0.0]  # Nose points along +X in body frame
        
        # Compute DCM from body to NED using Euler angles
        ct = cos(theta[idx])
        st = sin(theta[idx])
        cphi = cos(phi[idx])
        sphi = sin(phi[idx])
        cpsi = cos(psi[idx])
        spsi = sin(psi[idx])
        
        # Transform to NED: [North, East, Down]
        north_ned = ct*cpsi
        east_ned = ct*spsi
        down_ned = -st
        
        # Convert NED to visualization frame (East, North, Up)
        nose_vis = Vec3f(east_ned, north_ned, -down_ned)
        
        arrow_start = Point3f(epos[idx], npos[idx], alt[idx])
        arrow_direction = 200.0 * nose_vis  # 200m long arrow
        
        arrows3d!(ax3d, [arrow_start], [arrow_direction],
                  lengthscale=1.0,
                  tiplength=40,
                  tipradius=15,
                  shaftradius=5,
                  color=:red)
        
        # STATE PLOTS: Clear and redraw
        empty!(ax_alt)
        empty!(ax_theta)
        empty!(ax_vt)
        
        # Altitude plot
        lines!(ax_alt, t, alt, color=:black, linewidth=3)
        scatter!(ax_alt, [t[idx]], [alt[idx]], color=:red, markersize=20)
        vlines!(ax_alt, t[idx], color=:red, linewidth=3, linestyle=:dash)
        
        # Pitch plot
        lines!(ax_theta, t, theta_deg, color=:black, linewidth=3)
        scatter!(ax_theta, [t[idx]], [theta_deg[idx]], color=:red, markersize=20)
        vlines!(ax_theta, t[idx], color=:red, linewidth=3, linestyle=:dash)
        hlines!(ax_theta, 0.0, color=:gray50, linewidth=1, linestyle=:dot)
        
        # Velocity plot
        lines!(ax_vt, t, vt, color=:black, linewidth=3)
        scatter!(ax_vt, [t[idx]], [vt[idx]], color=:red, markersize=20)
        vlines!(ax_vt, t[idx], color=:red, linewidth=3, linestyle=:dash)
        
        # INFO OVERLAY: Large, clear text
        info_str = @sprintf("Time: %.2f s\nAlt: %.0f m\nVel: %.1f m/s\nPitch: %.1f°", 
                           t[idx], alt[idx], vt[idx], theta_deg[idx])
        
        text!(ax3d, info_str,
              position=(0.02, 0.98),
              align=(:left, :top),
              space=:relative,
              color=:black,
              fontsize=28,
              font=:bold)
    end
    
    println("\n" * "=" ^ 60)
    println("✓ Animation saved to:")
    println("  $filename")
    println("=" ^ 60)
    
    return filename
end

"""
    compare_trajectories(result_ol, result_cl; kwargs...)

Create side-by-side comparison animation of open-loop vs closed-loop.

# Arguments
- `result_ol`: Open-loop solution
- `result_cl`: Closed-loop solution

# Keyword Arguments
- `filename::String`: Output filename (default: auto-generated)
- `fps::Int`: Video framerate (default: 30)
- `duration::Real`: Target video duration (default: 10.0)
"""
function compare_trajectories(result_ol, result_cl;
                              filename=nothing,
                              fps=30,
                              duration=10.0)
    
    println("=" ^ 60)
    println("F-16 TRAJECTORY COMPARISON")
    println("=" ^ 60)
    
    # Generate filename
    if filename === nothing
        timestamp = replace(string(now()), ":" => "-", "." => "-")
        filename = joinpath(ANIM_DIR, "comparison_$(timestamp).mp4")
    elseif !isabspath(filename)
        filename = joinpath(ANIM_DIR, filename)
    end
    
    println("Output: $filename\n")
    
    # Extract both solutions
    sol_ol = hasproperty(result_ol, :sol) ? result_ol.sol : result_ol.solution
    sys_ol = hasproperty(result_ol, :sys) ? result_ol.sys : result_ol.system
    sol_cl = hasproperty(result_cl, :sol) ? result_cl.sol : result_cl.solution
    sys_cl = hasproperty(result_cl, :sys) ? result_cl.sys : result_cl.system
    
    # Find plants
    plant_ol = hasproperty(sys_ol, :f16plant) ? sys_ol.f16plant : sys_ol
    plant_cl = hasproperty(sys_cl, :f16plant) ? sys_cl.f16plant : sys_cl
    
    # Use common time vector - interpolate to target video duration
    t_ol_sim = sol_ol.t
    t_cl_sim = sol_cl.t
    t_max = min(t_ol_sim[end], t_cl_sim[end])
    
    # Create interpolated time vector for video
    n_video_frames = round(Int, duration * fps)
    t = range(0, t_max, length=n_video_frames)
    
    println("  Simulation durations: OL=$(t_ol_sim[end])s, CL=$(t_cl_sim[end])s")
    println("  Video duration: $(t_max)s")
    println("  Video frames: $(n_video_frames)")
    println("  FPS: $(fps)")
    
    println("\nInterpolating open-loop states...")
    function extract_states(sol, plant, t)
        return (
            npos = [sol(ti, idxs=plant.npos) for ti in t],
            epos = [sol(ti, idxs=plant.epos) for ti in t],
            alt = [sol(ti, idxs=plant.alt) for ti in t],
            phi = [sol(ti, idxs=plant.phi) for ti in t],
            theta = [sol(ti, idxs=plant.theta) for ti in t],
            psi = [sol(ti, idxs=plant.psi) for ti in t],
            vt = [sol(ti, idxs=plant.vt) for ti in t],
            alpha = [sol(ti, idxs=plant.alpha) for ti in t]
        )
    end
    
    states_ol = extract_states(sol_ol, plant_ol, t)
    println("Interpolating closed-loop states...")
    states_cl = extract_states(sol_cl, plant_cl, t)
    
    # All frames are used (no subsampling)
    frame_indices = 1:length(t)
    
    # Pre-compute rotations
    # Note: Negate theta because F-16 uses NED (Z-down) but we visualize Z-up
    println("Pre-computing rotations...")
    rotations_ol = [RotXYZ(states_ol.phi[i], -states_ol.theta[i], states_ol.psi[i]) for i in frame_indices]
    rotations_cl = [RotXYZ(states_cl.phi[i], -states_cl.theta[i], states_cl.psi[i]) for i in frame_indices]
    
    # Create figure - side by side
    fig = Figure(size=(2560, 1080), backgroundcolor=:white)
    
    # Open-loop 3D
    ax3d_ol = Axis3(fig[1:2, 1],
                    title="Open-Loop Response",
                    titlesize=32,
                    xlabelsize=20,
                    ylabelsize=20,
                    zlabelsize=20,
                    xlabel="East (m)",
                    ylabel="North (m)",
                    zlabel="Altitude (m)",
                    aspect=:data,
                    elevation=π/6,
                    azimuth=π/4)
    
    # Closed-loop 3D
    ax3d_cl = Axis3(fig[1:2, 2],
                    title="Closed-Loop LQG Response",
                    titlesize=32,
                    xlabelsize=20,
                    ylabelsize=20,
                    zlabelsize=20,
                    xlabel="East (m)",
                    ylabel="North (m)",
                    zlabel="Altitude (m)",
                    aspect=:data,
                    elevation=π/6,
                    azimuth=π/4)
    
    # Comparison plots
    ax_alt = Axis(fig[1, 3], ylabel="Altitude (m)", ylabelsize=18,
                  xticklabelsvisible=false)
    ax_theta = Axis(fig[2, 3], ylabel="Pitch (deg)", xlabel="Time (s)",
                    ylabelsize=18, xlabelsize=18)
    
    # Create aircraft mesh
    function create_aircraft_mesh(scale=100.0)
        vertices = Point3f[
            (1.5*scale, 0, 0),
            (-1.0*scale, 0, 0),
            (-0.5*scale, -1.5*scale, 0),
            (-0.5*scale, 1.5*scale, 0),
            (-0.8*scale, 0, 0.5*scale),
        ]
        faces = [
            TriangleFace(1, 2, 3),
            TriangleFace(1, 2, 4),
            TriangleFace(2, 3, 4),
            TriangleFace(2, 4, 5),
            TriangleFace(2, 3, 5),
        ]
        return GeometryBasics.Mesh(vertices, faces)
    end
    
    aircraft_mesh = create_aircraft_mesh()
    
    # Pre-compute degrees
    theta_deg_ol = rad2deg.(states_ol.theta)
    theta_deg_cl = rad2deg.(states_cl.theta)
    
    # Record
    println("\nRendering comparison...")
    progress_step = max(1, length(frame_indices) ÷ 20)
    
    record(fig, filename, enumerate(frame_indices); framerate=fps) do (iframe, idx)
        if iframe % progress_step == 0
            pct = round(Int, 100 * iframe / length(frame_indices))
            println("  Progress: $pct%")
        end
        
        # Clear 3D axes
        empty!(ax3d_ol)
        empty!(ax3d_cl)
        
        # Open-loop trajectory
        lines!(ax3d_ol, states_ol.epos, states_ol.npos, states_ol.alt,
               color=:gray60, linewidth=3)
        
        # Open-loop aircraft
        pos_ol = Point3f(states_ol.epos[idx], states_ol.npos[idx], states_ol.alt[idx])
        rot_idx = findfirst(==(idx), frame_indices)
        rot_ol = rotations_ol[rot_idx]
        verts_ol = [Point3f(rot_ol * Vec3f(v) + Vec3f(pos_ol)) for v in coordinates(aircraft_mesh)]
        mesh!(ax3d_ol, GeometryBasics.Mesh(verts_ol, faces(aircraft_mesh)), color=:red)
        
        # Open-loop nose direction arrow
        ct_ol = cos(states_ol.theta[idx])
        st_ol = sin(states_ol.theta[idx])
        cpsi_ol = cos(states_ol.psi[idx])
        spsi_ol = sin(states_ol.psi[idx])
        north_ol = ct_ol*cpsi_ol
        east_ol = ct_ol*spsi_ol
        down_ol = -st_ol
        nose_ol = Vec3f(east_ol, north_ol, -down_ol)
        arrow_dir_ol = 200.0 * nose_ol
        arrows3d!(ax3d_ol, [pos_ol], [arrow_dir_ol],
                  lengthscale=1.0,
                  tiplength=40,
                  tipradius=15,
                  shaftradius=5,
                  color=:red)
        
        # Closed-loop trajectory
        lines!(ax3d_cl, states_cl.epos, states_cl.npos, states_cl.alt,
               color=:gray60, linewidth=3)
        
        # Closed-loop aircraft
        pos_cl = Point3f(states_cl.epos[idx], states_cl.npos[idx], states_cl.alt[idx])
        rot_cl = rotations_cl[rot_idx]
        verts_cl = [Point3f(rot_cl * Vec3f(v) + Vec3f(pos_cl)) for v in coordinates(aircraft_mesh)]
        mesh!(ax3d_cl, GeometryBasics.Mesh(verts_cl, faces(aircraft_mesh)), color=:green)
        
        # Closed-loop nose direction arrow
        ct_cl = cos(states_cl.theta[idx])
        st_cl = sin(states_cl.theta[idx])
        cpsi_cl = cos(states_cl.psi[idx])
        spsi_cl = sin(states_cl.psi[idx])
        north_cl = ct_cl*cpsi_cl
        east_cl = ct_cl*spsi_cl
        down_cl = -st_cl
        nose_cl = Vec3f(east_cl, north_cl, -down_cl)
        arrow_dir_cl = 200.0 * nose_cl
        arrows3d!(ax3d_cl, [pos_cl], [arrow_dir_cl],
                  lengthscale=1.0,
                  tiplength=40,
                  tipradius=15,
                  shaftradius=5,
                  color=:green)
        
        # Comparison plots
        empty!(ax_alt)
        empty!(ax_theta)
        
        lines!(ax_alt, t, states_ol.alt, color=:red, linewidth=3, label="Open-Loop")
        lines!(ax_alt, t, states_cl.alt, color=:green, linewidth=3, label="Closed-Loop")
        vlines!(ax_alt, t[idx], color=:black, linewidth=2, linestyle=:dash)
        axislegend(ax_alt, position=:rt, labelsize=16)
        
        lines!(ax_theta, t, theta_deg_ol, color=:red, linewidth=3, label="Open-Loop")
        lines!(ax_theta, t, theta_deg_cl, color=:green, linewidth=3, label="Closed-Loop")
        vlines!(ax_theta, t[idx], color=:black, linewidth=2, linestyle=:dash)
        hlines!(ax_theta, 0.0, color=:gray50, linewidth=1, linestyle=:dot)
        axislegend(ax_theta, position=:rt, labelsize=16)
    end
    
    println("\n" * "=" ^ 60)
    println("✓ Comparison saved to:")
    println("  $filename")
    println("=" ^ 60)
    
    return filename
end
