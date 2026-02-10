# F16 Trim Script
# ================
# This script finds trim conditions for the F16 at a specified altitude and velocity.
# The model uses a DAE formulation where thrust (T) and elevator (el) are algebraic
# variables determined by equilibrium constraints.

using F16ModelWorkshop
using ModelingToolkit
using OrdinaryDiffEqDefault
using Printf

"""
    trim_f16(; altitude=1000.0, velocity=152.4)

Find trim conditions for the F16 at specified altitude and velocity.

# Arguments
- `altitude`: Trim altitude in meters (default: 1000.0)
- `velocity`: Trim airspeed in m/s (default: 152.4)

# Returns
- Dictionary with trim values: α, θ, T, δe and verification data
"""
function trim_f16(; altitude::Real=1000.0, velocity::Real=152.4)
    println("="^70)
    println("F16 TRIM ANALYSIS")
    println("="^70)
    println("\nOperating Point:")
    println("  Altitude: ", altitude, " m")
    println("  Velocity: ", velocity, " m/s")
    
    # Build the trim model
    # F16TrimV2 uses F16PlantForTrim which has T and el as algebraic variables
    # determined by equilibrium constraints (der(vt)=0, der(Q)=0)
    model = F16ModelWorkshop.F16TrimV2(name=:trim, h=altitude, V=velocity)
    sys = structural_simplify(model)
    
    println("\n✓ Model built")
    println("  Equations: ", length(equations(sys)))
    println("  Unknowns: ", length(unknowns(sys)))
    
    # Create ODE problem
    prob = ODEProblem(sys, [], (0.0, 0.01))
    println("✓ Problem created")
    
    # Solve - the DAE solver will find T and el that satisfy equilibrium
    sol = solve(prob, saveat=0.001)
    
    if !SciMLBase.successful_retcode(sol.retcode)
        error("Trim failed: $(sol.retcode)")
    end
    
    println("✓ Trim solution found")
    
    # Extract trim values (use t>0 to get DAE-corrected values)
    t_trim = sol.t[2]
    
    alpha_trim = sol(t_trim, idxs=sys.aircraft.alpha)
    theta_trim = sol(t_trim, idxs=sys.aircraft.theta)
    T_trim = sol(t_trim, idxs=sys.aircraft.T)
    el_trim = sol(t_trim, idxs=sys.aircraft.el)
    
    # Verify equilibrium - check all derivatives
    u_trim = sol.u[2]
    derivs = prob.f(u_trim, prob.p, t_trim)
    
    # Get indices for key states
    unknowns_list = unknowns(sys)
    var_map = Dict(string(u) => i for (i, u) in enumerate(unknowns_list))
    
    # Check critical derivatives
    der_vt = derivs[var_map["aircraft₊vt(t)"]]
    der_alpha = derivs[var_map["aircraft₊alpha(t)"]]
    der_theta = derivs[var_map["aircraft₊theta(t)"]]
    der_Q = derivs[var_map["aircraft₊Q(t)"]]
    der_alt = derivs[var_map["aircraft₊alt(t)"]]
    
    max_der = maximum(abs.([der_vt, der_alpha, der_theta, der_Q, der_alt]))
    trim_valid = max_der < 1e-4
    
    # Print results
    println("\n" * "="^70)
    println("TRIM RESULTS")
    println("="^70)
    
    println("\nDecision Variables (solved):")
    println("  α (angle of attack) = ", @sprintf("%8.4f", alpha_trim), " rad")
    println("  θ (pitch angle)     = ", @sprintf("%8.4f", theta_trim), " rad")
    println("  T (thrust)          = ", @sprintf("%10.2f", T_trim), " N")
    println("  δe (elevator)       = ", @sprintf("%8.4f", el_trim), " rad")
    
    println("\nEquilibrium Verification:")
    println("  der(vt)    = ", @sprintf("%12.8f", der_vt), abs(der_vt) < 1e-5 ? "  ✓" : "  ✗")
    println("  der(alpha) = ", @sprintf("%12.8f", der_alpha), abs(der_alpha) < 1e-5 ? "  ✓" : "  ✗")
    println("  der(theta) = ", @sprintf("%12.8f", der_theta), abs(der_theta) < 1e-5 ? "  ✓" : "  ✗")
    println("  der(Q)     = ", @sprintf("%12.8f", der_Q), abs(der_Q) < 1e-5 ? "  ✓" : "  ✗")
    println("  der(alt)   = ", @sprintf("%12.8f", der_alt), abs(der_alt) < 1e-5 ? "  ✓" : "  ✗")
    
    println("\n" * "="^70)
    if trim_valid
        println("✓✓✓ TRIM VALID - All equilibrium conditions satisfied ✓✓✓")
    else
        println("⚠ TRIM WARNING - Max derivative: ", max_der)
    end
    println("="^70)
    
    # Return results as dictionary
    return Dict(
        :altitude => altitude,
        :velocity => velocity,
        :alpha => alpha_trim,
        :alpha_deg => alpha_trim * 180/π,
        :theta => theta_trim,
        :theta_deg => theta_trim * 180/π,
        :thrust => T_trim,
        :elevator => el_trim,
        :valid => trim_valid,
        :max_derivative => max_der,
        :solution => sol,
        :system => sys,
        :problem => prob
    )
end

trim_results = trim_f16(altitude=3000.0, velocity=152.4)
# Run trim if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    # Default trim at 1000m, 152.4 m/s
    trim_results = trim_f16(altitude=1000.0, velocity=152.4)
    
    println("\n\nExample: Trim at different conditions")
    println("-"^40)
    
    # Trim at higher altitude
    trim_high = trim_f16(altitude=5000.0, velocity=200.0)
end
