
using PowerSystems
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames

logger = configure_logging(
    console_level = Logging.Info,
    file_level = Logging.Debug,
)

pownet_data_dir = joinpath("PowNet", "Model_withdata", "input") # data source
siip_data_dir = mkpath("siip_data") # formatted data target

# read PowNet data files
branch = CSV.read(joinpath(pownet_data_dir, "data_camb_transparam.csv"), DataFrame)
gens = CSV.read(joinpath(pownet_data_dir, "data_camb_genparams.csv"), DataFrame)

# add missing required branch info
branch[!, :r] .= 0.0
branch[!, :b] .= 0.0
branch[!, :x] .= 0.01 ./ branch.linesus
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
        :value => maximum => :normalization_factor,
    )
    df[!, :name] .= label
    df[!, :simulation] .= simulation
    df[!, :category] .= category
    df[!, :data_file] .= ts_name
    df[!, :resolution] .= 3600
    df[!, :scaling_factor_multiplier] .= "get_max_active_power"
    df[!, :scaling_factor_multiplier_module] .= "PowerSystems"
    return df
end

# collect loads info
loads = make_tsp(
    "data_camb_load_2016.csv",
    pownet_data_dir,
    siip_data_dir,
    "PowerLoad",
    "test",
    "max_active_power",
)

# collect hydro generation info
hydro_ts = vcat(
    make_tsp(
        "data_camb_hydro_2016.csv",
        pownet_data_dir,
        siip_data_dir,
        "Generator",
        "test",
        "max_active_power",
    ),
    make_tsp(
        "data_camb_hydro_import_2016.csv",
        pownet_data_dir,
        siip_data_dir,
        "Generator",
        "test",
        "max_active_power",
    ),
)

# create complete hydro info from hydro_ts
function create_hydro!(gen_df, hy)
    hy_row = Dict{String, Any}(zip(names(gen_df), zeros(ncol(gen_df))))
    hy_row["name"] = hy.component_name
    hy_row["node"] = hy.component_name
    hy_row["maxcap"] = hy.normalization_factor
    hy_row["ramp"] = hy.normalization_factor
    hy_row["typ"] = "hydro_HY"
    append!(gen_df, hy_row, promote = true)
end

for hy in eachrow(hydro_ts)
    create_hydro!(gens, hy)
end

# add missing required generator info
gens[!, :fuel] = [t[1] for t in split.(gens.typ, "_")]
gens[!, :prime_mover] = [t[end] for t in split.(gens.typ, "_")]
gens[!, :zero_col] .= 0.0
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
rawsys = PowerSystemTableData(
    siip_data_dir,
    100.0,
    "user_descriptors.yaml";
    generator_mapping_file = "generator_mapping.yaml",
)

# create a system
sys = System(rawsys, time_series_resolution = Dates.Hour(1))
transform_single_time_series!(sys, 48, Hour(24))

# serialize the system
to_json(sys, "sys-cambodia.json", force = true)

# plot demand
plotlyjs()
plot_demand(sys);

plot_demand(sys, aggregation = System);
