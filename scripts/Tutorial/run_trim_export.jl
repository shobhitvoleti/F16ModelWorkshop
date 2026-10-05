# Tutorial step 1: trim the plant and write the operating point as the package's trim
# assets (assets/trim_point.toml, trim_reference.toml, trim_controls.toml), which every
# later step applies.
#
#   julia --project=. scripts/Tutorial/run_trim_export.jl

using F16ModelWorkshop, F16ModelWorkshop.Tutorial

res = TutorialTrimExport()
foreach(path -> println("wrote ", path), res.files)
println("controls [T, el, ail, rud, lef] = ", res.paramset["trim_controls"]["k"])
println("alpha = theta = ", res.paramset["trim_point"]["alpha_init"], " rad")
