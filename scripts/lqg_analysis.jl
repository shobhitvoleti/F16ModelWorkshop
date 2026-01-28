using  DyadInterface, F16ModelWorkshop
solution = F16LQGControllerAnalysis()
L = artifacts(solution, :ControllerGain)
K = artifacts(solution, :ObserverGain)
