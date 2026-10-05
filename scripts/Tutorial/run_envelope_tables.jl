# Tutorial step 8: trim the plant at the nodes of the scheduling grid and write the lookup
# table EnvelopeMPCDemo reads its knots and references from (assets/envelope_trim_alpha.csv).
# Re-run after changing the plant or the table's axes.
#
#   julia --project=. scripts/Tutorial/run_envelope_tables.jl

using F16ModelWorkshop

println("wrote ", EnvelopeMPC.write_trim_table())
