using  DyadInterface, F16ModelWorkshop, DyadControlSystems

solution = F16LQGControllerAnalysis()


open("src/output.jl", "w") do f
    show_construction(f, solution.Cfb,name = "Controller",letb = false)
end


include("animate_trajectories_turbo.jl")
result2 = Scenario1ClosedLoop()

"""
STATE Symbols - :npos, :epos, :alt, :phi, :theta, :psi, :vt, :alpha, :beta, :P, :Q, :R
CONTROL Symbols = :T, :el, :ail, :rud, :lef

Generates an animation of the F16 trajectory with the specified state and control variables plotted over time. 
For visual clarity limited to three variables supplied as kwargs.
"""
fig = animate_trajectories_turbo(result2, duration=10.0;
                            plot1=:alt, 
                            plot2=:theta, 
                            plot3=:vt,
                            filename="closed_loop.mp4")