# PSI-Cambodia

This repository contains an example of how to execute a power system scheduling simulation
of using [PowerSimulations.j](https://github.com/NREL-SIIP/PowerSimulations.jl) using data
assembled for the [PowNet](https://github.com/kamal0013/PowNet) application for the power
grid in Camboida.

![](https://github.com/kamal0013/PowNet/blob/master/fig2_Cambodia_grid.jpg)

The example includes two pieces of code:
 - Data preperation for [PowerSystems.jl](https://github.com/nrel-siip/PowerSystems.jl) and
 construction of a `System`.
 - Example `Simulation` of a day-ahead unit-commitment scheduling sequence.

Examples are provided in `.jl` script format. To autogenerate ipython notebooks, execute
the following command from a Julia REPL:

```julia
include("literate.jl")
```