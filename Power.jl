# Define the packages
using JuMP # used for mathematical programming
using Cbc # used as the LP solver
using DataFrames #used to create tables
using CSV # used to import from CSV
using Plots # used to create Plots
using StatPlots
#using StatsBase

#Import all data in the subfolder into tables to a dictionary structure
data=Dict()
for dataname in readdir("Power_Data")
 data[split(dataname,'.')[1]]=CSV.read("Power_Data/$dataname", delim=';')
end


loc=scatter()
loclist=["off" "grey" "Wind-Offshore"; "on" "blue" "Wind-Onshore"; "pv" "yellow" "PV"; "ror" "red" "Water" ]
for i=1:size(loclist,1)
    loc=scatter!(data["node_data"][:,:Long],data["node_data"][:,:Lat],ms=(log.(data["node_data"][:,Symbol(loclist[i,1])].+1)),alpha=0.8,color=loclist[i,2],label=loclist[i,3])
end
loc
# In this cell we create  function solve_ed, which solves the economic dispatch problem for a given set of input parameters.
function solve_el(data)
    #Define different stets
    tim=1:size(data["h_demand"],1)
    gen=1:size(data["plant_con"],1)
    nod=1:size(data["node_data"],1)
    #Define the economic dispatch (ED) model
    el=Model(solver=CbcSolver())

    # Define decision variables
    @variable(el, 0 <= G[p=gen, tim] <= data["plant_con"][p,:cap]) # power output of generators
    @variable(el, 0 <= W[n=nod, t=tim] <= (data["node_data"][n,:on]+data["node_data"][n,:off])*data["h_wind"][t,Symbol(data["node_data"][n,:dena])]) # wind power injection
    @variable(el, 0 <= PV[n=nod, t=tim] <= data["node_data"][n,:pv]*data["h_pv"][t,Symbol(data["node_data"][n,:dena])]) # wind power injection

    # Define the objective function
    @objective(el, Min, sum(data["h_price"][t,Symbol(data["plant_con"][p,:fuel])] * G[p,t] for p=gen for t=tim))

    # Define the power balance constraint
    @constraint(el, sum(G[p, t=tim] for p=gen)+sum(W[n, t=tim]+PV[n, t=tim] for n=nod).== data["h_demand"][t=tim,:demand])

    # Solve statement
    solve(el)

    # return the optimal value of the objective function and its minimizers
    return getvalue(G), getvalue(W), getvalue(PV), getobjectivevalue(el)
end

# Solve the economic dispatch problem
(g_opt, w_opt, pv_opt, obj)=solve_el(data);

#Visualize Demand, residual and production of each powerplant

Dem=plot(data["h_demand"][:demand],label="Demand",lw=5)
Dem=plot!(data["h_demand"][:demand]-sum(pv_opt[n,:] for n=1:size(pv_opt[:,1],1))-sum(w_opt[n,:] for n=1:size(w_opt[:,1],1)),label="Residual",lw=5, color="LightBlue")
Dem=groupedbar!(transpose(g_opt[:,:]), bar_position = :stack, lw=0, label=reshape(data["plant_con"][:Plantname], 1, 98), colour=reshape(colormap("Blues", size(g_opt[:,:],1)),1,size(g_opt[:,:],1)), leg=false)



#Define Function to return the index of a certain Symbol(column) from paramter a in parameter b
function indx(symb, a, b)
    return indexin(data["$a"][Symbol(symb)],data["$b"][Symbol(symb)])
end
#Plot a little more
map=scatter(data["node_data"][indx("nodeno","plant_con","node_data"),:Long],data["node_data"][indx("nodeno","plant_con","node_data"),:Lat],ms=g_opt[:,1]./100,group=data["plant_con"][:fuel])
plot(Dem, loc, map, layout=(3,1))# This cell uses the package Interact defined above.
# In this cell we create a manipulator that solves the economic dispatch problem for different values of c_g1_scale.
