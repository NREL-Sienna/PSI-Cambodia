#

using PowerSystems
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames


pownet_data_dir = joinpath("PowNet", "Model")
siip_data_dir = mkdir("siip_data")

branch = CSV.read(joinpath(pownet_data_dir, "data_camb_transparam.csv"))
gens = CSV.read(joinpath(pownet_data_dir, "data_camb_genparams.csv"))
loads = CSV.read(joinpath(pownet_data_dir, "data_camb_load_2016.csv"))


branch[!,:r] .= 0.0
branch[!,:x] .= 0.0

bus = DataFrame(Dict(:node=>union(branch.source, branch.sink)))
bus[!,:type] .= "PV"
bus[!,:voltage] .= 100.0
bus[[b in names(loads) for b in bus.node],:type] .= "PQ"
bus[bus.node .== gens[gens.maxcap .== maximum(gens.maxcap),:node], :type] .= "REF"
bus[!,:id] = [1:nrow(bus)...]

gens[!, :fuel] = [t[1] for t in split.(gens.typ, "_")]
gens[!, :prime_mover] = [t[end] for t in split.(gens.typ, "_")]
gens[!, :fuel_price] .= 0.0
gens[gens.fuel .== "oil", :fuel_price] .= 10.3
gens[gens.fuel .== "coal", :fuel_price] .= 2.1
gens[gens.fuel .== "imp", :prime_mover] .="HY"
gens = gens[gens.fuel .!= "slack",:]


CSV.write(joinpath(siip_data_dir, "bus.csv"), bus)
CSV.write(joinpath(siip_data_dir, "branch.csv"), branch)
CSV.write(joinpath(siip_data_dir, "gen.csv"), gens)



rawsys = PowerSystems.PowerSystemTableData(
    siip_data_dir,
    100.0,
    "user_descriptors.yaml";
    #"timeseries_pointers.csv",
    generator_mapping_file="generator_mapping.yaml",
)

sys = System(rawsys, forecast_resolution = Dates.Hour(1))
