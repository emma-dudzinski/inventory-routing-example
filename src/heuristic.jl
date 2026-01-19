
using Pkg, JuMP, Plots, DataFrames, CSV, Random, Gurobi, HiGHS, Statistics, CPLEX, Distances, JLD2, StatsBase

#load in customer data
@load "data/customers.jld2" N locations distances


#Function for polar coordinates
function polar_coordinates(x, y, x0, y0)
    dx = x - x0
    dy = y - y0
    r = sqrt(dx^2 + dy^2)
    θ = mod(atan(dy, dx), 2π)  #returns θ in radians
    #degree = θ*180/pi
    return r, θ
end

#to keep track of indices and polar coordinates
polar = Tuple[]

#Constructing the polar coordinates
for i in 2:N+1
    r, θ = polar_coordinates(locations[i,1],locations[i,2],locations[1,1],locations[1,2])
    r = round(r, digits=4)
    #θ = round(θ, digits=7)
    polar = push!(polar, (i, r, θ))
end

#sort the polar coordinates
sorted_polar_ccw = sort(polar, by = x->x[3])
sorted_polar_cw = reverse(sorted_polar_ccw)


#Making routes with sweep!
function sweep(sorted_polar, max_customers)
    routes = Tuple[]
    N = length(sorted_polar)
    customer_ids = [p[1] for p in sorted_polar]  
    #let each node be the starting node
    for node in 1:N
        #create variable for toring cutomers in the current route
        current_route = Int[]  
        #sweep from the current node and add routes until the max_customers along route are reached
        for position_in_route in 0:(max_customers-1)
            #using mod1 to index for wrapping around (for final starting nodes)
            index = mod1(node+position_in_route, N)
            #add to current route
            push!(current_route, customer_ids[index])
            #add current_route to routes
            route = (1, current_route..., 1)
            push!(routes, route)
        end
    end 

    return routes
end

max_customers = 3

#create routes by calling function, for both clockwise and counterclockwise sweeps
routes_ccw = sweep(sorted_polar_ccw, max_customers)
routes_cw = sweep(sorted_polar_cw, max_customers)


#Comparing routes
#convert both vectors to sets
set_routes_ccw = Set(routes_ccw)
set_routes_cw = Set(routes_cw)

#returns what is in the 1st set (cw) that is not in the 2nd (ccw)
added_routes = setdiff(set_routes_cw, set_routes_ccw)

#convert back to vector
added_routes_vector = collect(added_routes)

#combine both sets of routes    
routes = vcat(routes_ccw, added_routes_vector)

#Save routes to file
@save "src/routes_Sweep.jld2" routes
