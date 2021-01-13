
"""
    $(TYPEDEF)
An abstract class for a divergence of a function. This expects
that a subtype has a field with an EHTImage object and a flux type.
The struct is then assumed to be a **functor** and have a function
that computes the divergence of the image and a filter.

For example
```julia
    struct MyDiv{T,F,S} <: AbstractDivergence
        img::EHTImage{T,F}
        flux::S
    end
    function (bh::MyDiv)(θ::AbstractFilter)
        ...
    end
```

"""
abstract type AbstractDivergence end

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
struct Bhattacharyya{T<:EHTImage,S} <: AbstractDivergence
    """
    Abstract image class
    """
    img::T
    flux::S
end
function Bhattacharyya(img::T) where {T<:EHTImage}
    Bhattacharyya(img, flux(img))
end
function (bh::Bhattacharyya)(θ::T) where {T<:AbstractFilter}
    @unpack img, flux = bh
    bsum = zero(eltype(img.img))
    filter_norm = zero(eltype(img.img))
    xstart = (-img.nx*img.psize_x + img.psize_x)/2.0
    ystart = (-img.ny*img.psize_y + img.psize_y)/2.0
    for i in 1:img.nx
        for j in 1:img.ny
            x = xstart + img.psize_x*(i-1)
            y = ystart + img.psize_y*(j-1)
            filter_value = abs(θ(x,y))
            @inbounds bsum += sqrt(filter_value*img.img[j,i])
            filter_norm += filter_value
        end
    end
    return -log(bsum/sqrt(filter_norm*flux))
end






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
struct KullbackLeibler{T,S} <: AbstractDivergence
    """
    Abstract image class
    """
    img::T
    flux::S
end
function KullbackLeibler(img::T) where {T<:EHTImage}
    KullbackLeibler(img, flux(img))
end


function (kl::KullbackLeibler)(θ::T) where {T<:AbstractFilter}
    @unpack img, flux = kl
    klsum = zero(eltype(img.img))
    filter_norm = zero(eltype(img.img))
    xstart = (-img.nx*img.psize_x + img.psize_x)/2.0
    ystart = (-img.ny*img.psize_y + img.psize_y)/2.0

    @inbounds for i in 1:img.nx
        @simd for j in 1:img.ny
            x = xstart + img.psize_x*(i-1)
            y = ystart + img.psize_y*(j-1)
            filter_value = θ(x,y)+1e-12
            klsum += filter_value*log(filter_value/(img.img[j,i]+1e-12))
            filter_norm += filter_value
        end
    end
    return (klsum/filter_norm - log(filter_norm/flux))
end
