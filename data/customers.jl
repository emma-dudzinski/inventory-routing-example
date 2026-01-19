using Pkg, JuMP, Plots, DataFrames, CSV, Random, Gurobi, HiGHS, Statistics, CPLEX, Distances, JLD2, StatsBase

#Set number of customers
N = 10

locations = zeros(Float64,N+1,2)

#Make random depot and customer location data:
Random.seed!(56)
for i in 1:N+1
    locations[i,1] = round(rand()*10)
    locations[i,2] = round(rand()*10)
end

#Plot customer and depot locations
gr()
scatter(locations[:, 1], locations[:, 2], title = "Water Delivery Customers", legend = false)
scatter!([locations[1, 1]], [locations[1, 2]], color = "red")


#Convert to distance matrix
function make_euclidean(x1,y1,x2,y2)
    return sqrt((x1-x2)^2+(y1-y2)^2)
end

distances = zeros(Float64, N+1,N+1)
for i in 1:N+1
    for j in 1:N+1
        distances[i,j] = round(make_euclidean(locations[i,1],locations[i,2],locations[j,1],locations[j,2]), digits=4)
    end
end



#Save data as .jdl2 file
@save "data/customers.jld2" N locations distances

