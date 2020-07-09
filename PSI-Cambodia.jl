
# # Laos Production Cost Model Demo
# **Originally Contributed by**: Clayton Barrows

# ## Introduction

# This example shows how to run a PCM using Powersimulation study. This example depends upon a
# dataset of the Laos grid.

# ### Dependencies
using PowerSystems
using PowerSimulations
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames

PSI = PowerSimulations
plotlyjs()

using Cbc
solver = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.1)

logger = configure_logging(console_level = Logging.Info,
    file_level = Logging.Debug,
    filename = "log.txt")

# ## Create a `System` from the data

pownet_data_dir = joinpath("PowNet", "Model")

rename_files = [
    "data_camb_genparams.csv" => "gen.csv"
    "data_camb_load_2016.csv" => "load.csv"
    "data_camb_transparam.csv" => "branch.csv"
]
[cp(joinpath(pownet_data_dir,f[1]), joinpath(pownet_data_dir, f[2])) for f in rename_files]

arcs = CSV.read(joinpath(pownet_data_dir, "branch.csv"))
bus = DataFrame(Dict(:bus=>union(arcs.source, arcs.sink)))
CSV.write(joinpath(pownet_data_dir, "bus.csv"), bus)

rawsys = PowerSystems.PowerSystemTableData(
    pownet_data_dir,
    100.0,
    "user_descriptors.yaml";
    #"timeseries_pointers.csv",
    #"generator_mapping.yaml",
)

sys = System(rawsys, forecast_resolution = Dates.Hour(1))

# ### Selecting flow limited lines
# Since PowerSimulations will apply constraints by component type (e.g. Line), we need to
# change the component type of the lines on which we want to enforce flow limits. So, let's
# change the device type of certain branches from Line to MonitoredLine differentiate
# treatment when we build the model. Here, we can select inter-regional lines, or lines
# above a voltage threshold.

for line in get_components(Line, sys)
    if (get_basevoltage(get_from(get_arc(line))) >= 230.0) &&
       (get_basevoltage(get_to(get_arc(line))) >= 230.0)
        #if get_area(get_from(get_arc(line))) != get_area(get_to(get_arc(line)))
        @info "Changing $(get_name(line)) to MonitoredLine"
        convert_component!(MonitoredLine, line, sys)
    end
end

# ### Create a `template`
# Now we can create a `template` that applies an unbounded formulation to `Line`s and the standard
# flow limited formulation to `MonitoredLine`s.
branches = Dict{Symbol, DeviceModel}(
    :L => DeviceModel(Line, StaticLineUnbounded),
    :T => DeviceModel(Transformer2W, StaticTransformer),
    :TT => DeviceModel(TapTransformer, StaticTransformer),
    :ML => DeviceModel(MonitoredLine, StaticLine),
    :DC => DeviceModel(HVDCLine, HVDCDispatch),
)

devices = Dict(
    :Generators => DeviceModel(ThermalStandard, ThermalStandardUnitCommitment),
    :Ren => DeviceModel(RenewableDispatch, RenewableFullDispatch),
    :Loads => DeviceModel(PowerLoad, StaticPowerLoad),
    :HydroROR => DeviceModel(HydroDispatch, HydroDispatchRunOfRiver),
    :RenFx => DeviceModel(RenewableFix, FixedOutput),
    :ILoads => DeviceModel(InterruptibleLoad, InterruptiblePowerLoad),
)

template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, Dict());

# ### Build and execute single step problem
op_problem =
    OperationsProblem(
        GenericOpProblem,
        template,
        sys;
        optimizer = solver,
        horizon = 24,
        balance_slack_variables = false,
        use_parameters = true)

res =solve!(op_problem)

# ### Analyze results
fuel_plot(res, sys, load = true, curtailment = true)

# ## Sequential Simulation
# In addition to defining the formulation template, sequential simulations require
# definitions for how information flows between problems.
sim_folder = mkpath(joinpath(pwd(), "LA100-sim"), )
stages_definition = Dict(
    "UC" => Stage(
        GenericOpProblem,
        template,
        sys,
        solver;
        balance_slack_variables = false,
    )
)
order = Dict(1 => "UC")
horizons = Dict("UC" => 48)
intervals = Dict("UC" => (Hour(24), Consecutive()))
DA_sequence = SimulationSequence(
    step_resolution = Hour(24),
    order = order,
    horizons = horizons,
    intervals = intervals,
    ini_cond_chronology = IntraStageChronology(),
)

# ### Define and build a simulation
sim = Simulation(
    name = "LA100-test",
    steps = 3,
    stages = stages_definition,
    stages_sequence = DA_sequence,
    simulation_folder = sim_folder,
)

build!(sim, console_level = Logging.Info, file_level = Logging.Debug,  recorders = [:simulation])

# ### Execute the simulation
sim_results = execute!(sim)

# ### Load and analyze results
uc_results = load_simulation_results(sim_results, "UC");

fuel_plot(uc_results, sys, load = true)
