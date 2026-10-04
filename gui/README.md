# F-16 LQG tuning dashboard

A live GLMakie dashboard for the step-3 LQG design (`Tutorial.TutorialLQG`).

```sh
julia --project=. gui/launch_gui.jl
```

One slider sets the elevator entry of the input weight, `q2_diag[2]`, on a logarithmic
grid from 1e-4 to 1e2. Every move re-runs the Dyad `LQGAnalysis` and redraws four views
of the new design:

| View | Shows |
|---|---|
| Step response | Closed-loop response to an elevator step |
| Pole–zero map | Closed-loop poles |
| Loop transfer | Singular values of the loop transfer at the plant input |
| Gang of four | S, T, PS, CS against the Ms = 2 target |

`launch_gui.jl` converts `TutorialLQGSpec()` to a plain `LQGAnalysisSpec` and calls
`launch_lqg_designer(spec; elevator_weight = 0.33)` from `lqg_app.jl`, which returns the
dashboard state. `state.sol[]` is the latest `LQGAnalysisSolution` (`K`, `L`, `Cfb`, `P`).

Each view is a `register_*_plugin!` function in `lqg_app.jl`: a panel plus an update
function of the solution. Adding a view is adding one of those functions.
