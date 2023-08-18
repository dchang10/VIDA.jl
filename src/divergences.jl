
"""
    $(TYPEDEF)
An abstract class for a divergence of a function. This expects
that a subtype has a field with an EHTImage object and a flux type.
The struct is then assumed to be a **functor** and have a function
that computes the divergence of the image and a template.

For example
```julia
    struct MyDiv{T,F,S} <: AbstractDivergence
        img::EHTImage{T,F}
        flux::S
    end
    function (bh::MyDiv)(θ::AbstractTemplate)
        ...
    end
```

"""
abstract type AbstractDivergence end



@inline function divergence(d::AbstractDivergence, m::M) where {M<:AbstractModel}
    _divergence(d, m)
end

# @inline function _divergence(::IsAnalytic, d::AbstractDivergence, m::AbstractModel)
#     return divergence_analytic(d, m)
# end

# @inline function _divergence(::NotAnalytic, d::AbstractDivergence, m::AbstractModel)
#     return divergence_numeric(d, m)
# end


# function _divergence(d::AbstractDivergence, m::AbstractModel)
#     (;img) = d
#     g = CB.imagegrid(img)
#     div, fm = mapreduce(.+, zip(g, img)) do (p, I)
#         Imod = CB.intensity_point(m, p)
#         return divergence_point(d, I, Imod), Imod
#     end
#     return normalize_div(d, div, fm)
# end

function _divergence(d::AbstractDivergence, m::AbstractModel)
    (;img) = d
    img_model = CB.intensitymap!(d.mimg, m)
    fm = flux(img_model)
    div  = sum(zip(img, mimg)) do (ii, im)
        return divergence_point(d, ii, im/fm)
    end
    return div
end



"""
    $(TYPEDEF)
Type for the Bhattacharyya divergence. It constructed from an `EHTImage` i.e. data.
Additionally to evaluate the divergence we use a functor approach where if θ
is your
### Details
This computes the Bhattacharyya divergence which is related to Hellinger distance between
two distributions. In fact, they are both minimized at the same point. The Bhattacharyya
divergence is defined as

```math
Bh(f_\\theta||\\hat{I}) = -\\log\\int \\sqrt{f_\\theta(x,y)\\hat{I}(x,y)}dxdy,
```
where ``\\hat{I}`` is defined as the image normalized to unit flux.

"""
struct Bhattacharyya{T<:IntensityMap} <: AbstractDivergence
    img::T
    mimg::T
end
function Bhattacharyya(img::T) where {T<:IntensityMap}
    Bhattacharyya(img./flux(img), copy(mimg))
end


@inline function divergence_point(::Bhattacharyya, p, q)
    return sqrt(p*abs(q)), q
end

# @inline normalize_div(::Bhattacharyya, div, fm) = -log(div/sqrt(fm))


"""
    $(TYPEDEF)
Type for the KL divergence. It constructed from an `EHTImage` i.e. data.
Additionally to evaluate the divergence we use a functor approach where if θ
is your
### Details
This computes the KL divergence which is related to Hellinger distance between
two distributions. In fact, they are both minimized at the same point. The Bhattacharyya
divergence is defined as

```math
KL(f_\\theta||\\hat{I}) = -\\log\\int f_{\\theta}(x,y)\\log
        \\left(\\frac{f_{\\theta}(x,y)}{\\hat{I}(x,y)}\\right)dxdy,
```
where ``\\hat{I}`` is defined as the image normalized to unit flux.

This struct is also a functor.
"""
struct KullbackLeibler{T<:IntensityMap} <: AbstractDivergence
    img::T
    mimg::T
end
function KullbackLeibler(img::T) where {T<:IntensityMap}
    KullbackLeibler(img./flux(img))
end

@inline divergence_point(::KullbackLeibler, p, q) = q*log(q/(p+eps(typeof(p))))
# @inline normalize_div(::KullbackLeibler, div, fm) = div/fm - log(fm)


struct Renyi{T,S} <: AbstractDivergence
    """
    Abstract image class
    """
    img::T
    flux::S
    α::Float64
end

"""
    Renyi(img::EHTImage, α)
Construct the Renyi divergence with parameter α. It constructed from an `EHTImage` i.e. data.

### Details
This computes the KL divergence which is related to Hellinger distance between
two distributions. In fact, they are both minimized at the same point. The Bhattacharyya
divergence is defined as

```math
Ry(f_\\theta||\\hat{I}) = \\frac{1}{α-1}\\log\\int log
        \\left(\\frac{f_{\\theta}(x,y)^\\alpha}{\\hat{I}(x,y)^{\\alpha-1}}\\right)dxdy,
```
where ``\\hat{I}`` is defined as the image normalized to unit flux.

This is a very flexible divergence that reduces to many of the other divergences implemented.
 - `α = 1` corresponds to the KL divergence
 - `α = 1/2` corresponds to the Bhattacharyya divergence up to a multiplicative factor of 2

Typically we find that `α=1.5` works well, as it focusses on the bright regions of the images
moreso than the Bh and KL divergence. For `α>2` the measure tends to devolve in something
akin the to sup norm and fails to match the image structure.
"""
function Renyi(img::T, α) where {T<:IntensityMap}
    @assert !(α-1 ≈ 0) "α=1 is the KL divergence use that instead"
    f = flux(img)
    Renyi{T,typeof(f)}(img./flux(img), α)
end

@inline divergence_point(d::Renyi, p, q) = p*(q/p)^d.α, q
# @inline function normalize_div(d::Renyi, div, fm)
#     α = d.α
#     return inv(α-1)*log(div*(fm)^(-α))
# end



"""
    $(TYPEDEF)
Type for the least squares divergence. It constructed from an `EHTImage` i.e. data.
Additionally to evaluate the divergence we use a functor approach where if θ
is your
### Details
This computes the squared 2 norm between your image and template, both of which
are normalized to unit flux.

To construct this just pass it an image object
```julia
ls = LeastSquares(img::EHTImage)
```

# Notes
We have a template internal matrix the prevents internal allocations during computation
This is a internal feature that the user does not need to worry about.
"""
struct LeastSquares{T} <: AbstractDivergence
    img::T
    mimg::T
end

function LeastSquares(img::T) where {T<:EHTImage}
    LeastSquares(img, flux(img), zeros(size(img)))
end

function divergence_point(::LeastSquares, p, q)
    return abs2(p - q)
end
