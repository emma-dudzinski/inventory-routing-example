
using Pkg

Pkg.activate(@__DIR__)
Pkg.instantiate()

println("Running IRP sample model...")
include(joinpath(@__DIR__, "src", "model.jl"))

run_model()