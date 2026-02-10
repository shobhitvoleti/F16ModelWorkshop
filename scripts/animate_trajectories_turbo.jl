"""
TURBO MODE: Maximum speed 3D trajectory animation for F-16.

Optimizations:
- Pre-compute ALL data before rendering
- Minimal per-frame computations
- No dynamic state extraction
- Direct array indexing
- Reduced visual complexity

Usage:
    result = Scenario1OpenLoop()
    animate_trajectories_turbo(result, 
                               plot1=:alt,    # altitude
                               plot2=:theta,  # pitch
                               plot3=:vt)     # velocity
"""

using GLMakie
using Rotations
using GeometryBasics
using LinearAlgebra
using Printf
using Dates

const ANIM_DIR = joinpath(@__DIR__, "..", "animations")
mkpath(ANIM_DIR)

# Available state variables
STATE_VARS = [:npos, :epos, :alt, :phi, :theta, :psi, :vt, :alpha, :beta, :P, :Q, :R]
CONTROL_VARS = [:T, :el, :ail, :rud, :lef]

"""
    animate_trajectories_turbo(result; kwargs...)

TURBO MODE: Blazingly fast 3D animation.

# Keyword Arguments
- `plot1::Symbol`: Variable for top right plot (default: :alt)
- `plot2::Symbol`: Variable for middle right plot (default: :theta)
- `plot3::Symbol`: Variable for bottom right plot (default: :vt)
- `filename::String`: Output filename (default: auto-generated)
- `fps::Int`: Video framerate (default: 30)
- `duration::Real`: Target video duration (default: 10.0)

Available variables: npos, epos, alt, phi, theta, psi, vt, alpha, beta, P, Q, R, T, el, ail, rud, lef
"""
function animate_trajectories_turbo(result; 
                                    plot1::Symbol=:alt,
                                    plot2::Symbol=:theta,
                                    plot3::Symbol=:vt,
                                    filename=nothing,
                                    fps=30,
                                    duration=10.0)
    
    println("="^60)
    println("F-16 TURBO ANIMATION")
    println("="^60)
    
    # Extract solution
    sol = hasproperty(result, :sol) ? result.sol : result.solution
    sys = hasproperty(result, :sys) ? result.sys : result.system
    plant = hasproperty(sys, :f16plant) ? sys.f16plant : sys
    
    # Generate filename
    if filename === nothing
        timestamp = replace(string(now()), ":" => "-", "." => "-")
        filename = joinpath(ANIM_DIR, "turbo_$(timestamp).mp4")
    elseif !isabspath(filename)
        filename = joinpath(ANIM_DIR, filename)
    end
    
    println("Output: $filename")
    println("Plots: $plot1, $plot2, $plot3")
    
    # Create interpolated time vector
    t_sim = sol.t
    n_video_frames = round(Int, duration * fps)
    t = range(t_sim[1], t_sim[end], length=n_video_frames)
    
    println("\n=== PRE-COMPUTING ALL DATA ===")
    
    # Extract ALL states once
    println("Extracting states...")
    npos = [sol(ti, idxs=plant.npos) for ti in t]
    epos = [sol(ti, idxs=plant.epos) for ti in t]
    alt = [sol(ti, idxs=plant.alt) for ti in t]
    phi = [sol(ti, idxs=plant.phi) for ti in t]
    theta = [sol(ti, idxs=plant.theta) for ti in t]
    psi = [sol(ti, idxs=plant.psi) for ti in t]
    vt = [sol(ti, idxs=plant.vt) for ti in t]
    alpha = [sol(ti, idxs=plant.alpha) for ti in t]
    beta = [sol(ti, idxs=plant.beta) for ti in t]
    P = [sol(ti, idxs=plant.P) for ti in t]
    Q = [sol(ti, idxs=plant.Q) for ti in t]
    R = [sol(ti, idxs=plant.R) for ti in t]
    T = [sol(ti, idxs=plant.T) for ti in t]
    el = [sol(ti, idxs=plant.el) for ti in t]
    ail = [sol(ti, idxs=plant.ail) for ti in t]
    rud = [sol(ti, idxs=plant.rud) for ti in t]
    lef = [sol(ti, idxs=plant.lef) for ti in t]
    
    # Create data dictionary for easy access
    data = Dict(
        :npos => npos, :epos => epos, :alt => alt,
        :phi => phi, :theta => theta, :psi => psi,
        :vt => vt, :alpha => alpha, :beta => beta,
        :P => P, :Q => Q, :R => R,
        :T => T, :el => el, :ail => ail, :rud => rud, :lef => lef
    )
    
    # Pre-compute all rotations and arrows
    println("Pre-computing rotations and arrows...")
    arrows_vis = Vector{Vector{Float32}}(undef, n_video_frames)
    for i in 1:n_video_frames
        ct = cos(theta[i])
        st = sin(theta[i])
        cpsi = cos(psi[i])
        spsi = sin(psi[i])
        
        north_ned = ct*cpsi
        east_ned = ct*spsi
        down_ned = -st
        
        arrows_vis[i] = [east_ned, north_ned, -down_ned]
    end
    
    # Pre-compute aircraft meshes (simplified for speed)
    println("Pre-computing meshes...")
    
    scale = 100.0
    vertices_base = Point3f[
        (1.5*scale, 0, 0),
        (-1.0*scale, 0, 0),
        (-0.5*scale, -1.5*scale, 0),
        (-0.5*scale, 1.5*scale, 0),
        (-0.8*scale, 0, 0.5*scale),
    ]
    
    faces_base = [
        TriangleFace(1, 2, 3),
        TriangleFace(1, 2, 4),
        TriangleFace(2, 3, 4),
        TriangleFace(2, 4, 5),
        TriangleFace(2, 3, 5),
    ]
    
    meshes = Vector{GeometryBasics.Mesh}(undef, n_video_frames)
    for i in 1:n_video_frames
        rot = RotXYZ(phi[i], -theta[i], psi[i])
        pos = Point3f(epos[i], npos[i], alt[i])
        verts = [Point3f(rot * Vec3f(v) + Vec3f(pos)) for v in vertices_base]
        meshes[i] = GeometryBasics.Mesh(verts, faces_base)
    end
    
    # Get plot data
    function get_plot_data(var::Symbol)
        if haskey(data, var)
            vals = data[var]
            # Convert angles to degrees if needed
            if var in [:phi, :theta, :psi, :alpha, :beta]
                return rad2deg.(vals), string(var) * " (deg)"
            elseif var in [:P, :Q, :R]
                return rad2deg.(vals), string(var) * " (deg/s)"
            else
                return vals, string(var)
            end
        else
            error("Unknown variable: $var. Available: $STATE_VARS, $CONTROL_VARS")
        end
    end
    
    plot1_data, plot1_label = get_plot_data(plot1)
    plot2_data, plot2_label = get_plot_data(plot2)
    plot3_data, plot3_label = get_plot_data(plot3)
    
    println("\n=== CREATING FIGURE ===")
    
    # Create figure
    fig = Figure(size=(1920, 1080), backgroundcolor=:white)
    
    # 3D plot
    ax3d = Axis3(fig[1:3, 1:3],
                 xlabel="East (m)", 
                 ylabel="North (m)", 
                 zlabel="Altitude (m)",
                 title="F-16 Trajectory",
                 titlesize=36,
                 xlabelsize=24,
                 ylabelsize=24,
                 zlabelsize=24,
                 aspect=:data,
                 elevation=π/6,
                 azimuth=π/4,
                 backgroundcolor=:white)
    
    # Side plots
    ax1 = Axis(fig[1, 4], 
               ylabel=plot1_label,
               ylabelsize=20,
               xlabelsize=18,
               backgroundcolor=:white,
               xticklabelsvisible=false)
    
    ax2 = Axis(fig[2, 4], 
               ylabel=plot2_label,
               ylabelsize=20,
               xlabelsize=18,
               backgroundcolor=:white,
               xticklabelsvisible=false)
    
    ax3 = Axis(fig[3, 4], 
               ylabel=plot3_label,
               xlabel="Time (s)",
               ylabelsize=20,
               xlabelsize=18,
               backgroundcolor=:white)
    
    println("\n=== RENDERING ===")
    progress_step = max(1, n_video_frames ÷ 20)
    
    record(fig, filename, 1:n_video_frames; framerate=fps) do idx
        if idx % progress_step == 0
            pct = round(Int, 100 * idx / n_video_frames)
            println("  Progress: $pct%")
        end
        
        # Clear 3D
        empty!(ax3d)
        
        # Full trajectory (static)
        lines!(ax3d, epos, npos, alt, color=:gray60, linewidth=3)
        
        # Aircraft mesh (pre-computed)
        mesh!(ax3d, meshes[idx], color=:red)
        
        # Arrow (pre-computed)
        arrow_start = Point3f(epos[idx], npos[idx], alt[idx])
        arrow_dir = 200.0 * arrows_vis[idx]
        arrows3d!(ax3d, [arrow_start], [arrow_dir],
                  lengthscale=1.0, tiplength=40, tipradius=15, shaftradius=5, color=:red)
        
        # Side plots
        empty!(ax1)
        empty!(ax2)
        empty!(ax3)
        
        lines!(ax1, t, plot1_data, color=:black, linewidth=3)
        scatter!(ax1, [t[idx]], [plot1_data[idx]], color=:red, markersize=20)
        vlines!(ax1, t[idx], color=:red, linewidth=2, linestyle=:dash)
        
        lines!(ax2, t, plot2_data, color=:black, linewidth=3)
        scatter!(ax2, [t[idx]], [plot2_data[idx]], color=:red, markersize=20)
        vlines!(ax2, t[idx], color=:red, linewidth=2, linestyle=:dash)
        
        lines!(ax3, t, plot3_data, color=:black, linewidth=3)
        scatter!(ax3, [t[idx]], [plot3_data[idx]], color=:red, markersize=20)
        vlines!(ax3, t[idx], color=:red, linewidth=2, linestyle=:dash)
    end
    
    println("\n" * "="^60)
    println("✓ TURBO Animation complete!")
    println("  $filename")
    println("="^60)
    
    return filename
end
