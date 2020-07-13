
# # Cambodia Production Cost Model Demo
# **Originally Contributed by**: Clayton Barrows

# ## Introduction

# This example shows how to run a PCM using Powersimulation study. This example depends upon a
# dataset of the Cambodian grid.

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

# ## Read the `System` from the serialized data.

sys =  System("sys-cambodia.json")

# ### Create a `template`
# Now we can create a `template` that specifies a standard unit commitment problem
template = template_unit_commitment(network = DCPPowerModel)

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
sim_folder = mkpath(joinpath(pwd(), "Cambodia-sim"), )
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
    name = "Cambodia-test",
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
