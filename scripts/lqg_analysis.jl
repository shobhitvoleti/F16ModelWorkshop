using DyadInterface, F16ModelWorkshop

using DyadControlSystems

solution = F16LQGControllerAnalysis()
L = artifacts(solution, :ControllerGain)
K = artifacts(solution, :ObserverGain)


open("output.jl", "w") do f
    show_construction(f, solution.Cfb,name = "Controller",letb = false)
end

