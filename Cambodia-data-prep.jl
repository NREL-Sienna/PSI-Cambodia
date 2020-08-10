
using PowerSystems
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames

using Logging
logger = PowerSystems.IS.configure_logging(
    console_level = Logging.Info,
    file_level = Logging.Debug,
)


pownet_data_dir = joinpath("PowNet", "Model") # data source
siip_data_dir = mkpath("siip_data") # formatted data target

# read PowNet data files
branch = CSV.read(joinpath(pownet_data_dir, "data_camb_transparam.csv"), DataFrame)
gens = CSV.read(joinpath(pownet_data_dir, "data_camb_genparams.csv"), DataFrame)

# add missing required branch info
branch[!, :r] .= 0.0
branch[!, :b] .= 0.0
branch[!, :x] .= 0.01 ./ branch.linesus
#branch[!,:linemva] .= branch.linemva .* 10.0
branch[!, :name] = branch.source .* "_" .* branch.sink

# function to format time series pointers
function make_tsp(ts_name, pownet_data_dir, siip_data_dir, category, simulation, label)
    ts_path = joinpath(pownet_data_dir, ts_name)
    ts = CSV.read(ts_path, DataFrame)
    rename!(ts, Dict(:Hour => :Period))
    ts[!, :Year] .= 2017 #2016 is a leap year but 2/29 isn't in these time series ... use 2017
    CSV.write(joinpath(siip_data_dir, ts_name), ts)
    df = ts[:, [c for c in names(ts) if !(c in ["Year", "Month", "Day", "Period"])]]
    df = combine(
        groupby(
            stack(df, variable_name = :component_name, value_name = :value),
            :component_name,
        ),
        :value => maximum => :scaling_factor,
    )
    df[!, :label] .= label
    df[!, :simulation] .= simulation
    df[!, :category] .= category
    df[!, :data_file] .= ts_name
    return df
end

# collect loads info
loads = make_tsp(
    "data_camb_load_2016.csv",
    pownet_data_dir,
    siip_data_dir,
    "PowerLoad",
    "test",
    "get_max_active_power",
)

# collect hydro generation info
hydro_ts = make_tsp(
    "data_camb_hydro_2016.csv",
    pownet_data_dir,
    siip_data_dir,
    "Generator",
    "test",
    "get_max_active_power",
)

hydro_ts = vcat(
    hydro_ts,
    make_tsp(
        "data_camb_hydro_import_2016.csv",
        pownet_data_dir,
        siip_data_dir,
        "Generator",
        "test",
        "get_max_active_power",
    ),
)

# create complete hydro info from hydro_ts
hydro = rename(hydro_ts[:, [:component_name, :scaling_factor]], [:name, :maxcap])
[
    hydro[!, col] .= val
    for
    (col, val) in [
        :typ => "hydro_HY",
        :mincap => 0.0,
        :heat_rate => 0.0,
        :var_om => 0.0,
        :fix_om => 0.0,
        :st_cost => 0.0,
        :minup => 0,
        :mindn => 0,
        :deratef => 1,
    ]
];
hydro[!, :node] = hydro.name
hydro[!, :ramp] = hydro.maxcap

# add missing required generator info
gens = vcat(gens, hydro)
gens[!, :fuel] = [t[1] for t in split.(gens.typ, "_")]
gens[!, :prime_mover] = [t[end] for t in split.(gens.typ, "_")]
gens[!, :fuel_price] .= 0.0
gens[!, :heat_rate] .*= 1000
gens[gens.fuel.=="oil", :fuel_price] .= 10.3
gens[gens.fuel.=="coal", :fuel_price] .= 2.1
gens[gens.fuel.=="imp", :prime_mover] .= "OT"
gens[gens.fuel.=="imp", :fuel] .= "OTHER"
gens = gens[gens.fuel.!="slack", :]
gens[gens.name.=="Salabam", :var_om] .= 48.0
gens[gens.name.=="impnode_viet", :var_om] .= 65.0
gens[gens.name.=="impnode_thai", :var_om] .= 66.0


# create a bus/node table
bus = DataFrame(Dict(:node => union(branch.source, branch.sink)))
bus[!, :type] .= "PV"
bus[!, :voltage] .= 100.0
bus[[b in names(loads) for b in bus.node], :type] .= "PQ"
bus[bus.node.==gens[gens.maxcap.==maximum(gens.maxcap), :node], :type] .= "REF"
bus[!, :id] = [1:nrow(bus)...]

# make a time series pointers table
tsp = vcat(loads, hydro_ts)

# write formatted tables to csv
CSV.write(joinpath(siip_data_dir, "bus.csv"), bus)
CSV.write(joinpath(siip_data_dir, "branch.csv"), branch)
CSV.write(joinpath(siip_data_dir, "gen.csv"), gens)
CSV.write(joinpath(siip_data_dir, "load.csv"), loads)
CSV.write(joinpath(siip_data_dir, "timeseries_pointers.csv"), tsp)

# parse the formatted PowNet data into PowerSystemsTableData
rawsys = PowerSystems.PowerSystemTableData(
    siip_data_dir,
    100.0,
    "user_descriptors.yaml";
    generator_mapping_file = "generator_mapping.yaml",
)

# create a system
sys = System(rawsys, forecast_resolution = Dates.Hour(1))

# serialize the system
to_json(sys, "sys-cambodia.json", force = true)

# plot demand
plotlyjs()
plot_demand(sys, horizon = 72)

plot_demand(sys, aggregate = System, horizon = 72)
