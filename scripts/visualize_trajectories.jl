using F16ModelWorkshop


result = Scenario1OpenLoop()
result2 = Scenario1ClosedLoop()

"""
STATE Symbols - :npos, :epos, :alt, :phi, :theta, :psi, :vt, :alpha, :beta, :P, :Q, :R
CONTROL Symbols = :T, :el, :ail, :rud, :lef

Generates an animation of the F16 trajectory with the specified state and control variables plotted over time. 
For visual clarity limited to three variables supplied as kwargs.
"""

include("animate_trajectories_turbo.jl")
animate_trajectories_turbo(result, duration=10.0;
                            plot1=:alt, 
                            plot2=:theta, 
                            plot3=:vt)
animate_trajectories_turbo(result2, duration=10.0;
                            plot1=:alt, 
                            plot2=:theta, 
                            plot3=:vt)