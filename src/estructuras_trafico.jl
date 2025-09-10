mutable struct Auto
    ancho ::Union{Float64,Int64}
    largo ::Union{Float64,Int64}
    posicion ::Vector{Float64}
    esquinas ::Vector{Any}
    velocidad ::Vector{Float64}
    direccion ::Vector{Float64}
    color ::RGB
    indice ::Int64
    #carril_inicial ::Int64 #solo usable para dos carriles
end

mutable struct Carril
    ancho_carril ::Union{Float64,Int64}
    inicio_fin ::Vector{Float64}
    indice_carril ::Int64
end

#### esta no sé para qué sirve ### Checar en las funciones principales
function Carril(ancho_carril::Union{Float64,Int64},inicio_fin::Vector{Float64},posicion::Vector{Float64},indice_carril::Int64)
    carril(ancho_carril,inicio_fin,indice_carril)
end



function Auto(ancho::Union{Float64,Int64},largo::Union{Float64,Int64},posicion::Vector{Float64},indice::Int64,)
    esquinas = [[posicion[1]-ancho/2,posicion[2]+largo/2],[posicion[1]+ancho/2,posicion[2]+largo/2],[posicion[1]+ancho/2,posicion[2]-largo/2],[posicion[1]-ancho/2,posicion[2]-largo/2]]
    velocidad = [0,0]
    direccion = [0,1]
    color = RGB(rand(),rand(),rand())
    Auto(ancho,largo,posicion,esquinas,velocidad,direccion,color,indice)
end

function Auto(ancho::Union{Float64,Int64},largo::Union{Float64,Int64},posicion::Vector{Float64},indice::Int64,velocidad::Vector{Float64})
    a = Auto(ancho, largo, posicion, indice)
    a.velocidad = velocidad
    if norm(velocidad) != 0
        a.direccion = velocidad./norm(velocidad)
    end
    return a
end

import Base.+, Base.-, Base.mod
function +(a::Auto, x::Array)
    a.posicion .+= x
    a.esquinas = [a.esquinas[i] .+ x for i in 1:4]
    return a
end
+(x::Array, a::Auto) = +(a::Auto, x::Array)
function -(a::Auto, x::Array)
    a.posicion .-= x
    a.esquinas = [a.esquinas[i] .- x for i in 1:4]
    return a
end

function mod(a::Auto, x)
    factor = floor(a.posicion[2]/x)
    bp = a.posicion .- [0,x*factor]
    bes = [es .- [0,x*factor] for es in a.esquinas]
    b = Auto(a.ancho, a.largo, bp, bes, a.velocidad, a.direccion, a.color, a.indice)
    if sum([0 < b.esquinas[i][2] < x for i in 1:4]) == 4
        return b, true
    else
        return b, false
    end
end


function copia_auto_rapida(auto::Auto)
    # Crear nuevo Auto reutilizando algunos campos
    nuevo_auto = Auto(
        auto.ancho,
        auto.largo,
        copy(auto.posicion),      # Solo copiar lo necesario
        [copy(esquina) for esquina in auto.esquinas],#deepcopy(auto.esquinas),  # deepcopy solo para arrays complejos
        copy(auto.velocidad),
        copy(auto.direccion),
        auto.color,               # Inmutable, no necesita copy
        auto.indice
    )
    return nuevo_auto
end


function copiar_lista_autos_rapida(lista_autos::Vector{Auto})
    nueva_lista = Vector{Auto}(undef, length(lista_autos))
    
    for i in eachindex(lista_autos)
        nueva_lista[i] = copia_auto_rapida(lista_autos[i])
    end
    
    return nueva_lista
end