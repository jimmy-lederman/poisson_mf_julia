include("../helper/MatrixMF.jl")
include("../helper/PoissonMaxFunctions.jl")
using Distributions

struct MaxPoissonMixture <: MatrixMF
    N::Int64 #number of data points
    M::Int64 #always set to 1
    K::Int64
    a::Float64 
    b::Float64
    D::Int64
end

function evalulateLogLikelihood(model::MaxPoissonMixture, state, data, info, row, col)
    Y = data["Y_NM"][row,col]
    mu = state["mu"]
    return logpdf(Poisson(mu), Y)
end

function sample_prior(model::MaxPoissonMixture, info=nothing)
    Z_N = rand(Categorical(model.K), model.N)


    mu_K = rand(Gamma(model.a, 1/model.b), model.K)
    state = Dict("mu_K" => mu_K, "Z_N" => Z_N)
    return state
end

function forward_sample(model::MaxPoissonMixture; state=nothing, info=nothing)
    @assert model.M == 1
    Y_NM = zeros(model.N,model.M)
    if isnothing(state)
        state = sample_prior(model)
    end
    mu_K = state["mu_K"]
    Z_N = Int.(state["Z_N"])
    Y_N = rand.(OrderStatistic.(Poisson.(mu_K[Z_N]),model.D,model.D))
    Y_NM = Int.(reshape(Y_N, model.N, model.M))
    data = Dict("Y_NM" => Y_NM)
    return data, state 
end

function backward_sample(model::MaxPoissonMixture, data, state, mask=nothing)
    #some housekeeping
    Y_NM = copy(data["Y_NM"])
    mu_K = copy(state["mu_K"])
    Z_N = Int.(copy(state["Z_N"]))

    latents_N = zeros(model.N)
    @assert model.M == 1

     #update latent poissons
    for n in 1:model.N
        if Y_NM[n, 1] > 0
            latents_N[n] = sampleSumGivenMax(Y_NM[n, 1], model.D, Poisson(mu_K[Z_N[n]]))
        end
    end

   # update Z_N
    for n in 1:model.N
        #calc categorical probabilities
        logprobvec_K = logpdf.(Poisson.(model.D*mu_K), latents_N[n])
        #sample categorical using Gumbel trick
        g_K = rand(Gumbel(0,1), model.K)
        Z_N[n] = argmax(g_K + logprobvec_K)
    end

    for k in 1:model.K
        subcounts = Y_NM[Z_N .== k, 1]
        post_shape = model.a + sum(subcounts) 
        post_rate = model.b + model.D*length(subcounts)
        mu_K[k] = rand(Gamma(post_shape, 1/post_rate))
    end

    state = Dict("mu_K" => mu_K, "Z_N" => Z_N)
    return data, state
end