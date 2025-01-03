using Distributions
using QuadGK
using SpecialFunctions
using LogExpFunctions

function log_incomplete_beta2(a, b, x; precision=16)
    setprecision(BigFloat,precision)
    a = BigFloat(a)
    b = BigFloat(b)
    x = BigFloat(x)
    #result, _ = quadgk(t -> t^(a-1) * (1-t)^(b-1), BigFloat(0), x; rtol=1e-75)
    if a >= b
        result, _ = quadgk(t -> exp((a-1)*log(t) + (b-1)*log(1-t)), BigFloat(0), x; rtol=1e-50)
        return log(result) - log(beta(a,b))
    else
        result, _ = quadgk(t -> exp((b-1)*log(t) + (a-1)*log(1-t)), BigFloat(0), 1-x; rtol=1e-50)
        # println(result)
        # flush(stdout)
        return log1p(-1*result/beta(a,b))
    end
    return result
end

function logprobmaxnb(Y,r,p,D;precision=16)
    #setprecision(BigFloat,32)
    # Y = BigFloat(Y)
    # r = BigFloat(r)
    # p = BigFloat(p)
    # D = BigFloat(D)
    #first = D*(log(incomplete_beta2(r, Y+1, 1-p)) - log(beta(r,Y+1)))
    first =D*log_incomplete_beta2(r,Y+1,1-p,precision=precision)
    #println(first)
    #second = D*(log(incomplete_beta2(r, Y, 1-p)) - log(beta(r,Y)))
    second =D*log_incomplete_beta2(r,Y,1-p,precision=precision)
    #println(second)
    result = logsubexp(first, second)
    if isinf(result) || isnan(result)
        return logprobmaxnb(Y,r,p,D;precision=precision*5)
    else
        return Float64(result)
    end
end

function logprobMaxNegBin(Y,r,p,D)
    try
        llik = logpdf(OrderStatistic(NegativeBinomial(r,1-p), D, D), Y)
        # if isinf(llik) || isnan(llik)
        #     llik = logprob(Y,mu,D)
        # end
        if isinf(llik) || isnan(llik)
            llik = logprobmaxnb(Y,r,p,D)
        end
        return llik
    catch ex
        llik = logprobsymbolic(Y,r,p,D)
        return llik
    end
end

#need to do: implement median


function logprobMedianNegBin(Y,mu)
    #must set precision
    setprecision(BigFloat,precision)
    mu = big(mu)
    Y = big(Y)
    firstgammas = gamma_inc(Y+1,mu)
    secondgammas =gamma_inc(Y,mu)
    result = logsubexp(2*log(firstgammas[2]) + log(1+2*firstgammas[1]), 2*log(secondgammas[2]) + log(1+2*secondgammas[1]))
    if isinf(result) || isnan(result)
        return logprobMedian(Y,mu,precision=5*precision)
    else
        return Float64(result)
    end
end