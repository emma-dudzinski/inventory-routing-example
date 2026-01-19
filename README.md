# inventory-routing-example
This repository contains a small, self-contained example of an inventory routing optimization model implemented in Julia using JuMP. The model is solved with HiGHs using a two-stage decomposition approach with route generation heuristics. The purpose of this repository is to provide a code sample of my applied operations research work. 


## Overview
- Formulation: Mixed-integer linear program
- Heuristic: Sweep route generation algorithm (adapted for IRP)
- Tools: Julia, JuMP, HiGHS (also can use Gurobi or CPLEX, if available)
- Data: Synthetic customer and depot data, Euclidean distances

This example is intentionally simplified and uses synthetic data. Customers (N) = 10, vehicles (K) = 1, days (T) = 7. Extended fomrulations and full implementations using partner data are not publicly available. Please reach out if you would like to learn more.

## How to run
1. Install Julia
2. Clone this repository:
```bash
   git clone https://github.com/emma-dudzinski/inventory-routing-example.git
```

3. From the repository root (```cd inventory-routing-example```):
```bash
julia --project=. src/run.jl
```