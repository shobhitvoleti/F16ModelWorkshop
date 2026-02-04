module F16ModelWorkshop

include("../generated/module.jl")

using ModelingToolkit, OrdinaryDiffEqDefault, NonlinearSolve
# Trim finding function for F16
"""
    f16_trim(; altitude=1000.0, velocity=152.4, gamma=0.0, psidot=0.0)

Find trim conditions for level flight at specified altitude and velocity.

# Arguments
- `altitude`: Altitude in meters (default: 1000.0)
- `velocity`: True airspeed in m/s (default: 152.4)
- `gamma`: Flight path angle in radians (default: 0.0 for level flight)
- `psidot`: Turn rate in rad/s (default: 0.0 for straight flight)

# Returns
Dictionary with trim values:
- `:T`: Thrust [N]
- `:el`: Elevator deflection [rad]
- `:alpha`: Angle of attack [rad]
- `:theta`: Pitch angle [rad]
- `:all_derivatives`: Vector of all state derivatives at trim
- `:max_derivative`: Maximum absolute derivative (should be near zero)
- `:success`: Boolean indicating if trim converged

# Example
```julia
trim = F16ModelWorkshop.f16_trim(altitude=1000.0, velocity=152.4)
println("Trim thrust: ", trim[:T], " N")
println("Trim elevator: ", trim[:el]*180/π, " deg")
println("Trim alpha: ", trim[:alpha]*180/π, " deg")
```

Note: This function uses NonlinearSolve.jl to find control inputs and states
that result in zero derivatives (equilibrium). MTK's symbolic trim finding doesn't
work well for this problem due to aggressive symbolic simplification.
"""
function f16_trim(; altitude=1000.0, velocity=152.4, gamma=0.0, psidot=0.0)
    # Build the F16 model
    model = F16SimplifiedPlant(name=:f16)
    sys = structural_simplify(model)
    
    # Trim objective: Find [alpha, theta, T, el] such that derivatives = 0
    # We'll use a NonlinearProblem to solve for these 4 unknowns
    
    function trim_residual(x, p)
        # x = [alpha, theta, T, el]
        alpha_val, theta_val, T_val, el_val = x
        h_val, V_val = p
        
        # Build parameter dictionary
        params_dict = Dict(
            sys.T => T_val,
            sys.el => el_val,
            sys.ail => 0.0,
            sys.rud => 0.0,
            sys.lef => 0.0
        )
        
        # Build initial conditions
        u0_dict = Dict(
            sys.alt => h_val,
            sys.vt => V_val,
            sys.alpha => alpha_val,
            sys.theta => theta_val,
            sys.beta => 0.0,
            sys.phi => 0.0,
            sys.psi => 0.0,
            sys.P => 0.0,
            sys.Q => 0.0,
            sys.R => 0.0,
            sys.npos => 0.0,
            sys.epos => 0.0
        )
        
        # Create ODE problem
        prob = ODEProblem(sys, u0_dict, (0.0, 0.1), params_dict)
        
        # Evaluate derivatives at t=0
        du = similar(prob.u0)
        prob.f(du, prob.u0, prob.p, 0.0)
        
        # Return residuals for the 4 equations we're solving:
        # 1. d(vt)/dt = 0
        # 2. d(alpha)/dt = 0
        # 3. d(theta)/dt = 0 (equivalently Q = 0, which is already in u0)
        # 4. d(Q)/dt = 0 (pitch acceleration = 0)
        
        idx_vt = findfirst(isequal(sys.vt), unknowns(sys))
        idx_alpha = findfirst(isequal(sys.alpha), unknowns(sys))
        idx_theta = findfirst(isequal(sys.theta), unknowns(sys))
        idx_Q = findfirst(isequal(sys.Q), unknowns(sys))
        
        return [du[idx_vt], du[idx_alpha], du[idx_theta], du[idx_Q]]
    end
    
    # Initial guess
    x0 = [0.05, 0.05, 44482.2, 0.0]  # [alpha, theta, T, el]
    p = [altitude, velocity]
    
    # Solve nonlinear system
    nl_prob = NonlinearProblem(trim_residual, x0, p)
    nl_sol = solve(nl_prob, NewtonRaphson(), abstol=1e-8, reltol=1e-8)
    
    # Extract solution
    alpha_trim, theta_trim, T_trim, el_trim = nl_sol.u
    
    # Verify by computing all derivatives
    params_final = Dict(
        sys.T => T_trim,
        sys.el => el_trim,
        sys.ail => 0.0,
        sys.rud => 0.0,
        sys.lef => 0.0
    )
    
    u0_final = Dict(
        sys.alt => altitude,
        sys.vt => velocity,
        sys.alpha => alpha_trim,
        sys.theta => theta_trim,
        sys.beta => 0.0,
        sys.phi => 0.0,
        sys.psi => 0.0,
        sys.P => 0.0,
        sys.Q => 0.0,
        sys.R => 0.0,
        sys.npos => 0.0,
        sys.epos => 0.0
    )
    
    prob_final = ODEProblem(sys, u0_final, (0.0, 0.1), params_final)
    du_final = similar(prob_final.u0)
    prob_final.f(du_final, prob_final.u0, prob_final.p, 0.0)
    
    return Dict(
        :T => T_trim,
        :el => el_trim,
        :alpha => alpha_trim,
        :theta => theta_trim,
        :altitude => altitude,
        :velocity => velocity,
        :all_derivatives => du_final,
        :max_derivative => maximum(abs.(du_final)),
        :success => nl_sol.retcode == ReturnCode.Success
    )
end

export f16_trim
    
end # module F16ModelWorkshop