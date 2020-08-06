"""
Vector of a judiVector and a judiWeight
"""
mutable struct judiVStack{vDT<:Number}
    m::Integer
    n::Integer
    components::Array{Any, 1}
end

function vcat(x::judiVector, y::judiWeights)
    components = Array{Any}(undef, 2)
    components[1] = x
    components[2] = y
    m = length(x)+length(y)
    n = 1
    return judiVStack{Float32}(m, n, components)
end

function vcat(x::judiWeights, y::judiVector)
    components = Array{Any}(undef, 2)
    components[1] = x
    components[2] = y
    m = length(x)+length(y)
    n = 1
    return judiVStack{Float32}(m, n, components)
end

function vcat(x::judiVStack, y::Union{judiWeights, judiVector})
    components = Array{Any}(undef, length(x.components) + 1)
    for i=1:length(x.components)
        components[i] = x.components[i]
    end
    components[end] = y
    m = x.m+length(y)
    n = 1
    return judiVStack{Float32}(m, n, components)
end

function vcat(x::Union{judiWeights, judiVector}, y::judiVStack)
    components = Array{Any}(undef, length(y.components) + 1)
    components[1] = x
    for i=2:length(y.components)+1
        components[i] = y.components[i-1]
    end
    m = y.m + length(x)
    n = 1
    return judiVStack{Float32}(m, n, components)
end

function vcat(x::judiVStack, y::judiVStack)
    nx = length(x.components)
    ny = length(y.components)
    components = Array{Any}(undef, nx+ny)
    for i=1:nx
        components[i] = x.components[i]
    end
    for i=nx+1:nx+ny
        components[i] = y.components[i-nx]
    end
    m = x.m + y.m
    n = 1
    return judiVStack{Float32}(m, n, components)
end

function *(F::joAbstractLinearOperator, v::judiVStack)
    return sum(F.fop[i]*v[i] for i=1:length(v.components))
end

############################################################
## overloaded Base functions

# conj(jo)
conj(a::judiVStack{vDT}) where vDT =
    judiVStack{vDT}(a.m,a.n,a.components)

# transpose(jo)
transpose(a::judiVStack{vDT}) where vDT =
    judiVStack{vDT}(a.n,a.m,a.components)

# adjoint(jo)
adjoint(a::judiVStack{vDT}) where vDT =
    judiVStack{vDT}(a.n,a.m,a.components)

##########################################################
# Utilities

size(x::judiVStack) = (x.m, x.n)
size(x::judiVStack, ind::Integer) = (x.m, x.n)[ind]

length(x::judiVStack) = x.m

eltype(v::judiVStack{vDT}) where {vDT} = vDT

similar(x::judiVStack) = judiVStack{Float32}(x.m, x.n, 0f0 .* x.components)

similar(x::judiVStack,  element_type::DataType, dims::Union{AbstractUnitRange, Integer}...) = similar(x)

getindex(x::judiVStack, a) = x.components[a]

firstindex(x::judiVStack) = 1

lastindex(x::judiVStack) = length(x.components)

dot(x::judiVStack, y::judiVStack) = sum(dot(x[i],y[i]) for i=1:length(x.components))

function norm(x::judiVStack, order::Real=2)
    if order == Inf
        return max([norm(x[i], Inf) for i=1:length(x.components)]...)
    end
    sum(norm(x[i], order)^order for i=1:length(x.components))^(1/order)
end

iterate(S::judiVStack, state::Integer=1) = state > length(S.components) ? nothing : (S.components[state], state+1)

##########################################################


# minus
function -(a::judiVStack{avDT}) where {avDT}
    c = deepcopy(a)
    for j=1:length(a.components)
        c.components[j] = -c.components[j]
    end
    return c
end

function +(a::judiVStack, b::judiVStack)
    size(a) == size(b) || throw(judiWeightsException("dimension mismatch"))
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = a.components[i] + b.components[i]
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

function +(a::judiVStack, b::Number)
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = a.components[i] + b
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

function -(a::judiVStack, b::judiVStack)
    size(a) == size(b) || throw(judiWeightsException("dimension mismatch"))
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = a.components[i] - b.components[i]
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

function -(a::judiVStack, b::Number)
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = a.components[i] .- b
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

function -(a::Number, b::judiVStack)
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = b .- a.components[i]
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

function *(a::judiVStack, b::Number)
    components = Array{Any}(undef, length(a.components))
    for i=1:length(a.components)
        components[i] = a.components[i] .* b
    end
    return judiVStack{Float32}(a.m, a.n,components)
end

*(a::Number, b::judiVStack) = b * a
+(a::Number, b::judiVStack) = b + a

/(a::judiVStack, b::Number) = judiVStack{Float32}(a.m, a.n, a.components ./ b)

##########################################################

BroadcastStyle(::Type{judiVStack}) = Base.Broadcast.DefaultArrayStyle{1}()

broadcasted(::typeof(+), x::judiVStack, y::judiVStack) = x + y
broadcasted(::typeof(-), x::judiVStack, y::judiVStack) = x - y
broadcasted(::typeof(+), x::judiVStack, y::Number) = x + y
broadcasted(::typeof(-), x::judiVStack, y::Number) = x - y
broadcasted(::typeof(+), y::Number, x::judiVStack) = x + y
broadcasted(::typeof(-), y::Number, x::judiVStack) = x - y

function broadcasted(::typeof(*), x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    z = deepcopy(x)
    for j=1:length(x.components)
        z.components[j] = x.components[j] .* y.components[j]
    end
    return z
end

function broadcasted!(::typeof(*), x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    z = deepcopy(x)
    for j=1:length(x.components)
        z.components[j] = x.components[j] .* y.components[j]
    end
    return z
end

function broadcasted(::typeof(/), x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    z = deepcopy(x)
    for j=1:length(x.components)
        z.components[j] = x.components[j] ./ y.components[j]
    end
    return z
end

function broadcasted(::typeof(*), x::judiVStack, y::Number)
    z = deepcopy(x)
    for j=1:length(x.components)
        z.components[j] .*= y
    end
    return z
end

broadcasted(::typeof(*), y::Number, x::judiVStack) = x .* y

function broadcasted(::typeof(/), x::judiVStack, y::Number)
    z = deepcopy(x)
    for j=1:length(x.components)
        z.components[j] ./= y
    end
    return z
end

function materialize!(x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    for j=1:length(x.components)
        try
            x.components[j].data .= y.components[j].data
        catch e
            x.components[j].weights .= y.components[j].weights
        end
    end
    return x
end

function broadcast!(identity, x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    copy!(x,y)
end

function broadcast!(identity, x::judiVStack, a::Number, y::judiVStack, z::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    size(x) == size(z) || throw(judiWeightsException("dimension mismatch"))
    scale!(y,a)
    copy!(x, y + z)
end

function copy!(x::judiVStack, y::judiVStack)
    size(x) == size(y) || throw(judiWeightsException("dimension mismatch"))
    for j=1:length(x.components)
        try
            x.components[j].data .= y.components[j].data
        catch e
            x.components[j].weights .= y.components[j].weights
        end
    end
end

function isapprox(x::judiVStack, y::judiVStack; rtol::Real=sqrt(eps()), atol::Real=0)
    x.m == y.m || throw("Shape error")
    all(isapprox(xx, yy; rtol=rtol, atol=atol) for (xx, yy)=zip(x.components, y.components))
end

############################################################

function A_mul_B!(x::judiWeights, F::joCoreBlock, y::judiVStack)
    F.m == size(y, 1) ? z = adjoint(F)*y : z = F*y
    x.weights = z.weights
end

function A_mul_B!(x::judiVStack, F::joCoreBlock, y::judiWeights)
    F.m == size(y, 1) ? z = adjoint(F)*y : z = F*y
    for j=1:length(x.components)
        try
            x.components[j].data .= z.components[j].data
        catch e
            x.components[j].weights .= z.components[j].weights
        end
    end
end

mul!(x::judiWeights, J::joCoreBlock, y::judiVStack) = A_mul_B!(x, J, y)
mul!(x::judiVStack, J::joCoreBlock, y::judiWeights) = A_mul_B!(x, J, y)
