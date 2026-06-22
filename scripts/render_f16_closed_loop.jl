# Closed-loop pitch recovery render
using F16ModelWorkshop, MultibodyComponents, GLMakie, ModelingToolkit

result = F16ModelWorkshop.Controls.F16ClosedLoopVizAnalysis()
render(result;
    filename = "animations/f16_closed_loop_viz.mp4",
    nominal_length = 500.0,
    x = -500, y = 3200, z = 200,
    lookat = Vec3f(2000, 3000, 0),
    show_axis = false
)
