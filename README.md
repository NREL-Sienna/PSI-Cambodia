# PSI-Cambodia

This repository contains an example of how to execute a power system scheduling simulation in [PowerSimulations.j](https://github.com/NREL-SIIP/PowerSimulations.jl), expanding on the data assembled for the [PowNet](https://github.com/kamal0013/PowNet) application for the power
grid in Cambodia. [![DOI](https://zenodo.org/badge/278169749.svg)](https://zenodo.org/badge/latestdoi/278169749)

![](https://github.com/kamal0013/PowNet/blob/master/fig2_Cambodia_grid.jpg)

This simulation is based on three open-source data and modeling tools used to model power systems with renewable resources such as wind and solar:

1. The [RE-Data Explorer](re-explorer.org/) can be used to investigate where to site wind and solar plants and to download wind and solar time-series resource files for selected latitude & longitudes where the plants will be located.
    - This repository already contains resource data files in the *REDE_resource_data/Input/* folder from the RE-Data Explorer for 5 hypothetical wind and solar plants in Cambodia.

2. The [System Advisor Model (SAM)](https://sam.nrel.gov/) can be used to model the power output (MW) from a wind or solar power plant, using the hourly or subhourly resource data from the RE-Data Explorer as inputs.
    - There are multiple ways for users to access SAM, including but not limited to:
        - A [downloadable GUI](https://sam.nrel.gov/download.html), which can be used for manual analysis of individual locations, i.e., power plants
        - A Python interface called [PySAM](https://nrel-pysam.readthedocs.io/en/main/index.html), which can be used to programmatically process multiple locations and/or plant configurations
        - The [Renewable Energy Potential (reV) tool](https://github.com/NREL/reV), which can be used for very large scenario analysis and batch runs
    - In the *REDE_resource_data* folder, there is a Python script that uses PySAM to process multiple solar and wind time-series resource files downloaded from the RE-Data Explorer for locations in Cambodia. This notebook is based on a PySAM example notebook, available [here](https://github.com/NREL/pysam/blob/main/Examples/PySAMWorkshop.ipynb). 
    - This processing has already been complete for the 5 example plants, and the outputs are available in the *REDE_resource_data/Output/* folder. However, if users would like to add other wind and solar locations and process those, here are the required steps:
        1. Add wind or solar resource files from the RE-Data Explorer to the *REDE_resource_data/Input/* folders
        2. Update the *REDE_resource_data/RE_plant_config.csv* file, which is a manually generated .csv file to make it easier to load the same plant metadata into both PySAM (to generate the plant-specific power profiles) and SIIP (to attach the hypothetical solar and wind plants to the existing PowerSystem.jl model). 
            - Resource file (from RE-Data Explorer or the [National Solar Radiation Database (NSRDB)](https://nsrdb.nrel.gov/))
            - Plant specification file, [exported from the SAM GUI](https://nrel-pysam.readthedocs.io/en/latest/inputs-from-sam.html). Example wind and solar plant specification files are already included in the *REDE_resource_data/Input* folders for the following configurations:
                 * Solar: A 100 MWdc fixed (12 degree ~= Cambodia's latitute) tilt system
                 * Wind: Models plant with Gamesa G114 2.0 MW turbines, which is selected to emulate the 'T200' representative turbine in the RE-Data Explorer's wind technical potential study (more info Table 12, page 23 [here](https://www.nrel.gov/docs/fy17osti/66861.pdf)); A review of Cambodia's mean wind speeds in the RE-Data Explorer indicates that the T200 or perhaps T237 representative turbines are a good choice for Cambodia.
            - Acronym of the node in the PowNet system that the plant should connect to (for example, the closest node based on the latitude/longitude of the plant.)
        3. Then, run the `REDE_timeseries_prep.py` script using the PySAM Python package. There are two ways to install PySAM: pip and conda. Due to delays updating the conda version of PySAM, it is recommended to install via pip:

```
    pip install nrel-pysam
```

3. Finally, the PowerSimulations.jl package can be used to run simulations of the Cambodia system, including the new renewable resources. 

This example includes two pieces of code:
 - Data preparation for [PowerSystems.jl](https://github.com/nrel-siip/PowerSystems.jl) and
 construction of a `System`. This includes pulling in the wind and solar power profiles. 
 - Example `Simulation` of a day-ahead unit-commitment scheduling sequence.

Examples are provided in `.jl` script format. To autogenerate ipython notebooks, execute
the following commands from a Julia REPL:

```julia
] activate . # Activates the required environment
include("literate.jl")
```







