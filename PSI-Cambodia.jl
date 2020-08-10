#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# # [PowerSimulations.jl](https://github.com/nrel-siip/powersimulations.jl) Production Cost Modeling Demo
# **Cambodia Example**: from [PowNet](https://github.com/kamal0013/PowNet)

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
using PowerGraphics
using Logging
using Dates
using CSV
using DataFrames
using GLPK
solver  = optimizer_with_attributes(GLPK.Optimizer)

#-
#nb %% A slide [code] {"slideshow": {"slide_type": "skip"}}
plotlyjs()
logger = configure_logging(console_level = Logging.Info,
    file_level = Logging.Debug,
    filename = "log.txt")

sim_folder = mkpath(joinpath(pwd(), "Cambodia-sim"))
ann_sim_folder = joinpath(sim_folder, "Cambodia-year")
ann_sim_run_folder =
    joinpath(ann_sim_folder, "$(maximum(parse.(Int64,readdir(ann_sim_folder))))")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Load the `System` from the serialized data.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
sys =  System("sys-cambodia.json")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## PCM in 5-minutes

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Create a problem `template`
# Now we can create a `template` that specifies a standard unit commitment problem
# with a DCOPF network representation.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
template = template_unit_commitment(network = StandardPTDFModel)
UC_stage = "UC" => Stage(
        GenericOpProblem,
        template,
        sys,
        solver;
        PTDF = PTDF(sys),
    )
template

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Sequential Simulation
# In addition to defining the formulation template, sequential simulations require
# definitions for how information flows between problems.

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
DA_sequence = SimulationSequence(
    step_resolution = Hour(24),
    order = Dict(1 => "UC"),
    horizons =  Dict("UC" => 48),
    intervals =  Dict("UC" => (Hour(24), Consecutive())),
    ini_cond_chronology = IntraStageChronology(),
)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Define and build a simulation

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
sim = Simulation(
    name = "Cambodia-test",
    steps = 3,
    stages = Dict(UC_stage),
    stages_sequence = DA_sequence,
    simulation_folder = sim_folder,
)

build!(sim, console_level = Logging.Info, file_level = Logging.Debug,  recorders = [:simulation])

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Execute the simulation

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
sim_results = execute!(sim)

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "slide"}}
# ## Analysis of Annual Simulation Results
# * requires execution of `include("PSI-Cambodia-Year.jl)` *

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Load annual simulation results

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
#nb annual_results = load_simulation_results(ann_sim_run_folder, "UC")

#nb # %% A slide [markdown] {"slideshow": {"slide_type": "subslide"}}
# ### Plot annual simulation results using [PowerGraphics.jl](https://github.com/nrel-siip/PowerGrahpics.jl)

#nb %% A slide [code] {"slideshow": {"slide_type": "fragment"}}
#nb fuel_plot(annual_results, sys, load = true, generator_mapping_file = "fuel_mapping.yaml")