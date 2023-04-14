#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # [PowerSimulations.jl](https://github.com/nrel-siip/powersimulations.jl) Production Cost Modeling Demo
# **Cambodia Example**: from [PowNet](https://github.com/kamal0013/PowNet)
#
# https://github.com/NREL-SIIP/PSI-Cambodia

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## Introduction
# This example shows how to run a PCM study using Powersimulations.jl. This example depends upon a
# dataset of the Cambodian grid assembled using the
# [Cambodia-data-prep.jl](./Cambodia-data-prep.jl) script and [PowerSystems.jl](https://github.com/nrel-siip/powersystems.jl).

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Dependencies

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
using PowerSystems
using PowerSimulations
using PowerAnalytics
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames
using HiGHS
solver  = optimizer_with_attributes(HiGHS.Optimizer)

#-
#nb %% A slide [code] {"slideshow": {"slide_type": "skip"}}
plotlyjs()
logger = configure_logging(console_level = Logging.Info,
    file_level = Logging.Debug,
    filename = "log.txt")

sim_folder = mkpath(joinpath(pwd(), "Cambodia-sim"))
ann_sim_folder = joinpath(sim_folder, "Cambodia-year")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Load the `System` from the serialized data.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
sys = System("sys-cambodia.json")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## PCM in 5-minutes

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Create a problem `template`
# Now we can create a `template` that specifies a standard unit commitment problem
# with a DCOPF network representation.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
template = template_unit_commitment(network = DCPPowerModel)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Create a `model`
# Now we can apply the `template` to the data (`sys`) to create a `model`.
# *note that you can define multiple models here to create multi-stage simulations*

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
models = SimulationModels(
    decision_models=[
        DecisionModel(template, sys, optimizer=solver, name="UC"),
    ],
)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Sequential Simulation
# In addition to defining the formulation template, sequential simulations require
# definitions for how information flows between problems.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
DA_sequence = SimulationSequence(
    models=models,
    ini_cond_chronology=InterProblemChronology(),
)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Define and build a simulation

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
sim = Simulation(
    name = "Cambodia-test",
    steps = 3,
    models=models,
    sequence=DA_sequence,
    simulation_folder=mktempdir(cleanup=true),
)

build!(sim, console_level = Logging.Info, file_level = Logging.Debug,  recorders = [:simulation])

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Execute the simulation

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
execute!(sim)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## Analysis of Simulation Results

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Load simulation results

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
results = SimulationResults(sim)
uc_results = get_decision_problem_results(results, "UC")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Plot simulation results using [PowerGraphics.jl](https://github.com/nrel-siip/PowerGrahpics.jl)

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
plot_fuel(uc_results, generator_mapping_file = "fuel_mapping.yaml");