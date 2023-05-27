using PowerSystems
using PowerGraphics
using Dates
using CSV
using DataFrames

# # Read in and clean data
pownet_data_dir = joinpath("PowNet", "Model_withdata", "input") # data source
sienna_data_dir = mkpath("sienna_data") # formatted data target
re_config_dir = "REDE_resource_data" # configuration location for renewable plants
re_data_dir = joinpath("REDE_resource_data", "Output") # time series data source for renewable plants

# Read PowNet data files
branch = CSV.read(joinpath(pownet_data_dir, "data_camb_transparam.csv"), DataFrame)
gens = CSV.read(joinpath(pownet_data_dir, "data_camb_genparams.csv"), DataFrame)

# Add missing required branch info
branch[!, :r] .= 0.0
branch[!, :b] .= 0.0
branch[!, :x] .= 0.01 ./ branch.linesus
branch[!, :name] = branch.source .* "_" .* branch.sink

# # Collect time-varying component info
# Internal helper functions
function make_tsp(df, label, simulation, category, ts_name)
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

# Export time-series in required format and make time-series pointer table
function make_ts_and_tsp(ts_name, input_data_dir, sienna_data_dir, category, simulation, label)
    ts_path = joinpath(input_data_dir, ts_name)
    ts = CSV.read(ts_path, DataFrame)

    if occursin("load", ts_name) | occursin("hydro", ts_name)
        rename!(ts, Dict(:Hour => :Period))
        ts[!, :Year] .= 2017 #2016 is a leap year but 2/29 isn't in these time series ... use 2017
    else # Renewable energy data needs time index columns
        ts ./= 1000 # kW to MW
        ts = hcat(CSV.read(joinpath(sienna_data_dir, "data_camb_load_2016.csv"), DataFrame,
                    select = ["Year", "Month", "Day", "Period"]),
                ts)
    end
    CSV.write(joinpath(sienna_data_dir, ts_name), ts)

    df = ts[:, [c for c in names(ts) if !(c in ["Year", "Month", "Day", "Period"])]]
    df = make_tsp(df, label, simulation, category, ts_name)
    return df
end

# ### Collect loads info
loads = make_ts_and_tsp(
    "data_camb_load_2016.csv",
    pownet_data_dir,
    sienna_data_dir,
    "PowerLoad",
    "test",
    "max_active_power",
)

# ### Collect hydro generation info
hydro_ts = vcat(
    make_ts_and_tsp(
        "data_camb_hydro_2016.csv",
        pownet_data_dir,
        sienna_data_dir,
        "Generator",
        "test",
        "max_active_power",
    ),
    make_ts_and_tsp(
        "data_camb_hydro_import_2016.csv",
        pownet_data_dir,
        sienna_data_dir,
        "Generator",
        "test",
        "max_active_power",
    ),
)

# ### Collect wind and solar info
re_tsp = make_ts_and_tsp("data_solar_wind_power_2016.csv",
    re_data_dir,
    sienna_data_dir,
    "Generator",
    "test",
    "max_active_power",
)

# # Collect generator metadata
# Helper function to add hydro, solar, and wind plants
function create_gen!(gen_df, gen, node, typ)
    gen_row = Dict{String, Any}(zip(names(gen_df), zeros(ncol(gen_df))))
    gen_row["name"] = gen.component_name
    gen_row["node"] = node
    gen_row["maxcap"] = gen.normalization_factor
    gen_row["ramp"] = gen.normalization_factor
    gen_row["typ"] = typ
    append!(gen_df, gen_row, promote = true)
end

# Create complete hydro info from hydro_ts
for hy in eachrow(hydro_ts)
    create_gen!(gens, hy, hy.component_name, "hydro_HY")
end

# Create complete wind and solar data
re_config = CSV.read(
    joinpath(re_config_dir, "RE_plant_config.csv"), DataFrame)
for re in eachrow(leftjoin(
            re_tsp, re_config; on = :component_name=>:name))
    create_gen!(gens, re, re["node"], re["type"])
end

# # Clean up -- add missing required generator info
gens[!, :fuel] = [t[1] for t in split.(gens.typ, "_")]
gens[!, :prime_mover] = [t[end] for t in split.(gens.typ, "_")]
gens[!, :zero_col] .= 0.0
gens[gens.fuel.=="imp", :prime_mover] .= "OT"
gens[gens.fuel.=="imp", :fuel] .= "OTHER"
gens = gens[gens.fuel.!="slack", :]
gens[gens.name.=="Salabam", :var_om] .= 48.0
gens[gens.name.=="impnode_viet", :var_om] .= 65.0
gens[gens.name.=="impnode_thai", :var_om] .= 66.0

# # Export supporting .csv files
# Create a bus/node table
bus = DataFrame(Dict(:node => union(branch.source, branch.sink)))
bus[!, :type] .= "PV"
bus[!, :voltage] .= 100.0
bus[[b in names(loads) for b in bus.node], :type] .= "PQ"
bus[bus.node.==gens[gens.maxcap.==maximum(gens.maxcap), :node], :type] .= "REF"
bus[!, :id] = [1:nrow(bus)...]

# Make a time series pointers table
tsp = vcat(loads, hydro_ts, re_tsp)

# Write formatted tables to csv
CSV.write(joinpath(sienna_data_dir, "bus.csv"), bus)
CSV.write(joinpath(sienna_data_dir, "branch.csv"), branch)
CSV.write(joinpath(sienna_data_dir, "gen.csv"), gens)
CSV.write(joinpath(sienna_data_dir, "load.csv"), loads)
CSV.write(joinpath(sienna_data_dir, "timeseries_pointers.csv"), tsp)

# # Create and export the PowerSystem.jl system
# Parse the formatted PowNet data into PowerSystemsTableData
rawsys = PowerSystemTableData(
    sienna_data_dir,
    100.0,
    "user_descriptors.yaml";
    generator_mapping_file = "generator_mapping.yaml",
)

# Create a system
sys = System(rawsys, time_series_resolution = Dates.Hour(1))
transform_single_time_series!(sys, 48, Hour(24))

# Begin with renewable generators disconnected/unavailable
for g in get_components(RenewableDispatch, sys)
    set_available!(g, false)
end

# Serialize the system
to_json(sys, "sys-cambodia.json", force = true)
