include("../helper/MatrixMF.jl")
include("../helper/PoissonMedianFunctions.jl")
using Distributions

struct MedianPoissonUnivariate <: MatrixMF
    N::Int64
    M::Int64
    a::Float64
    b::Float64
    D::Int64
end

# function evalulateLogLikelihood(model::MedianPoissonUnivariate, state, data, info, row, col)
#     Y = data["Y_NM"][row,col]
#     mu = state["mu"]
#     return logpmfMedianPoisson(Y,mu,model.D)
# end

function sample_prior(model::MedianPoissonUnivariate, info=nothing)
    mu = rand(Gamma(model.a, 1/model.b))
    state = Dict("mu" => mu)
    return state
end

function forward_sample(model::MedianPoissonUnivariate; state=nothing, info=nothing)
    if isnothing(state)
        state = sample_prior(model)
    end
    mu = state["mu"]
    @assert model.D % 2 == 1
    @assert model.M == 1

    Y_ND = rand(Poisson(mu), model.N, model.D)
    Z_N = sum(Y_ND,dims=2)
    Y_NM = reshape(median(Y_ND,dims=2),model.N,1)

    #Y_NM = rand(OrderStatistic(Poisson(mu), model.D, div(model.D,2) + 1), model.N, model.M)
    data = Dict("Y_NM" => copy(Y_NM))
    state = Dict("mu"=>mu,"Z_N"=>copy(Z_N))
    return data, state 
end

function backward_sample(model::MedianPoissonUnivariate, data, state, mask=nothing)
    #some housekeeping
    Y_NM = copy(data["Y_NM"])
    mu = copy(state["mu"])
    #Z_N = zeros(model.N)
    Z_N = copy(state["Z_N"])
    # println(Z_N)
    for n in 1:model.N
        @assert model.D == 3
        Z_N[n] = sampleSumGivenMedian3(Y_NM[n,1], Poisson(mu))
    end

    post_shape = model.a + sum(Z_N)
    post_rate = model.b + model.D*model.N
    mu = rand(Gamma(post_shape, 1/post_rate))
    state = Dict("mu" => mu,"Z_N"=>Z_N)
    return data, state
end