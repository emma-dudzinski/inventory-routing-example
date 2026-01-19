
using Pkg, JuMP, Plots, DataFrames, CSV, Random, Gurobi, HiGHS, Statistics, CPLEX, Distances, JLD2, StatsBase



function run_model()
    #Decide solver
        solver_name = HiGHS # Gurobi, CPLEX

    #Start day of the week
        start_day = :Monday  #:Tuesday, :Wednesday, :Thursday
    
    #load in customer data
        @load joinpath(@__DIR__, "..", "data", "customers.jld2") N locations distances
    
    #load in pre-saved routes
        @load joinpath(@__DIR__, "..", "src", "routes_Sweep.jld2") routes

    #Set Indices (R routes, K vehicles, T days)
        R = length(routes)    
        K = 1
        T = 7

    #Set days of the week and Dict for converting t to days
        weekdays = [:Monday, :Tuesday, :Wednesday, :Thursday, :Friday, :Saturday, :Sunday]
        dayofweek = Dict(t => weekdays[(findfirst(==(start_day), weekdays) - 1 + t - 1) % 7 + 1] for t in 1:T)

    #Set parameters (vehicle capacity, minutes in workday, buffer days, initial inventory, usage rate, customer capacity)
        Q_k = [1000]
        m = 2*60
        b =2
        I_i0 = [0 700 200 200 100 0 800 1200 100 0]
        u_i = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
        u_i = u_i'
        C_i = [1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200] 


    #Set route dependent parameters (assignment/indicator, distance, cost, time to complete a route)
    #a_ir: whether customer i is visited on route r
       a_ir = zeros(Float64,N,R)
        for i in 2:N+1
            for r in 1:R
                if i in routes[r]
                    a_ir[i-1,r] = 1
                else
                    a_ir[i-1,r] = 0
                end
            end
        end 
        
    #d_r: distance of route r - kilometers
        d_r = zeros(Float64, R)
        for r in 1:R
            for i in 1:length(routes[r])-1
                d_r[r] = d_r[r] + distances[routes[r][i],routes[r][i+1]]
            end
        end

    #c_r: cost of route r - choose cost in miles or kilometers
        c_r = zeros(Float64, R)
        cost_mile = .77
        cost_kilometer = .4786
        for r in 1:R
            c_r[r] = cost_kilometer*d_r[r]
        end
        c_r = c_r'

    #y_r: time to complete route r
        y_r = zeros(Float64, R)
        for r in 1:R
            y_r[r] = d_r[r]/30#=miles/hour=#*60#=minutes/hour=#
        end
        y_r = y_r'

    #Model!
     model = Model(solver_name.Optimizer)

    #set_silent(model)

    #Set solver parameters
    if solver_name == Gurobi
        #set_optimizer_attribute(model, "TimeLimit", 10800.0) #600 seconds = 10 minutes, 10800 = 3 hours
        set_optimizer_attribute(model, "MIPGap", 0.01) #1% gap
        set_optimizer_attribute(model, "FeasibilityTol", 1e-9)
        set_optimizer_attribute(model, "IntFeasTol", 1e-9)
    elseif solver_name == CPLEX
        #set_optimizer_attribute(model, "CPXPARAM_TimeLimit", 600.0)
        set_optimizer_attribute(model, "CPXPARAM_MIP_Tolerances_MIPGap", 0.01)
        set_optimizer_attribute(model, "CPX_PARAM_EPRHS", 1e-9)
        set_optimizer_attribute(model, "CPX_PARAM_EPINT", 1e-9)
    elseif solver_name == HiGHS
        set_optimizer_attribute(model, "time_limit", 600.0)
    end
 
    # Create Variables 
    @variable(model, x[1:R, 1:K, 1:T], Bin)
    @variable(model, d[1:N, 1:R, 1:K, 1:T] >= 0)
    @variable(model, I[1:N, 1:T] >= 0)

    #Fix deliveries to 0 on weekends (Friday, Saturday, Sunday)
    for t in 1:T, i in 1:N, r in 1:R, k in 1:K
        if dayofweek[t] in [:Friday, :Saturday, :Sunday]
            fix(d[i,r,k,t], 0.0; force = true)
        end
    end


    # Set Objective
    @objective(model, Min, sum(c_r[r] * x[r,k,t] for r in 1:R for k in 1:K for t in 1:T))
    # Add Constraints

    #One 
    for t in 2:T
        for i in 1:N
            @constraint(model, I[i,t] == I[i,t-1] + sum(a_ir[i,r] * d[i,r,k,t] for r in 1:R for k in 1:K) - u_i[i])
        end
    end
    #One - case then t=1, uses initial inventory
    for i in 1:N
        @constraint(model, I[i,1] == I_i0[i] + sum(a_ir[i,r] * d[i,r,k,1] for r in 1:R for k in 1:K) - u_i[i])
    end

    #Two 
    for t in 1:T
        for i in 1:N
            @constraint(model, I[i,t] - (b * u_i[i]) >= 0)
        end
    end

    #Three 
    for t in 2:T
        for i in 1:N
            @constraint(model, sum(a_ir[i,r] * d[i,r,k,t] for r in 1:R for k in 1:K) <= C_i[i] - I[i,t-1])
        end
    end
    #Three - case then t=1, uses initial inventory
    for i in 1:N
        @constraint(model, sum(a_ir[i,r] * d[i,r,k,1] for r in 1:R for k in 1:K) <= C_i[i] - I_i0[i])
    end

    #Four
    for t in 1:T
        for k in 1:K 
            for r in 1:R
                for i in 1:N
                    @constraint(model, d[i,r,k,t] <= C_i[i] * x[r,k,t])
                end
            end
        end
    end

    #Five 
    for t in 1:T
        for k in 1:K
            for r in 1:R
                @constraint(model, sum(a_ir[i,r] * d[i,r,k,t] for i in 1:N) <= Q_k[k]*x[r,k,t])
            end
        end
    end

    #Six 
    for t in 1:T
        for k in 1:K
            @constraint(model, sum(y_r[r] * x[r,k,t] for r in 1:R) <= m)
        end
    end

    #Seven 
    for t in 1:T
        for k in 1:K
            for r in 1:R
                for i in 1:N
                    @constraint(model, d[i,r,k,t] <= min(Q_k[k],C_i[i]))
                end
            end
        end
    end

    #Solve
    optimize!(model)

    #Collect the model attributes
    runtime = solve_time(model)
    obj_value = objective_value(model)
    #Set solutions
    x_sol = value.(x)
    d_sol = value.(d)
    I_sol = value.(I)

    #choosen routes - (NOTE!!! adjusted to have depot=0 and customer=i)
    #ALSO - adjusted to only show x = 1 (excluding ~0s)
    nonzero_values_x= [(r, k, t, routes[r] .-1) for r in axes(x_sol,1),
                                                            k in axes(x_sol,2),
                                                            t in axes(x_sol,3) if x_sol[r,k,t] > .5]

    println("Objective Value (total cost): \$$(round(obj_value; digits = 2)), solved in $(round(runtime; digits=2)) seconds.")

    for (r,k,t,_) in nonzero_values_x
        for i in routes[r][2:end-1] #skip depots
            if d_sol[i-1, r, k, t] != 0 #remove undelivered customers (post-process)
                println("Customer $(i-1) received $(round(d_sol[i-1, r, k, t]; digits=1)) units on route $r by vehicle $k on day $t")
            end
        end
    end
       
end