using LinearAlgebra: dot

# ─────────────────────────────────────────────────────────────────────────────
# SAT primitivas (sin cambios)
# ─────────────────────────────────────────────────────────────────────────────

function proyectarEnEje(esquinas::Vector{Any}, eje::Vector{Float64})
    min_proj = Inf
    max_proj = -Inf
    for e in esquinas
        proj = dot(e, eje)
        min_proj = min(min_proj, proj)
        max_proj = max(max_proj, proj)
    end
    return (min_proj, max_proj)
end

function intervalosSeSuperponen(a_min::Float64, a_max::Float64, b_min::Float64, b_max::Float64)
    return !(a_max < b_min || b_max < a_min)
end

function obtenerEjes(esquinas::Vector{Any})
    n = length(esquinas)
    ejes = Vector{Vector{Float64}}(undef, n)
    for i in 1:n
        j = i % n + 1
        arista = [esquinas[j][1] - esquinas[i][1], esquinas[j][2] - esquinas[i][2]]
        normal = [-arista[2], arista[1]]
        mag = sqrt(normal[1]^2 + normal[2]^2)
        ejes[i] = mag > 0 ? [normal[1]/mag, normal[2]/mag] : [0.0, 0.0]
    end
    return ejes
end

function seSuperponenSAT(a1::Auto, a2::Auto)
    e1, e2 = a1.esquinas, a2.esquinas
    for eje in vcat(obtenerEjes(e1), obtenerEjes(e2))
        mn1, mx1 = proyectarEnEje(e1, eje)
        mn2, mx2 = proyectarEnEje(e2, eje)
        !intervalosSeSuperponen(mn1, mx1, mn2, mx2) && return false
    end
    return true
end

# ─────────────────────────────────────────────────────────────────────────────
# Grilla Espacial Uniforme — O(n) por paso
#
# Garantia de correctitud:
#   h_celda = 1.5  >  diagonal_max_vehiculo = sqrt((9/7)^2 + (18/35)^2) ~= 1.385
#   => dos vehiculos en celdas NO adyacentes NO pueden solaparse.
#   => verificar el vecindario 3x3 de la celda de cada vehiculo es suficiente.
#
# Frontera periodica en Y:
#   La carretera es un circuito cerrado. Las celdas en fila 0 y fila n_filas-1
#   son adyacentes. Se usa mod() para el indice de fila.
#
# MPI (futuro):
#   Cada proceso puede poseer un rango de filas. Las filas en la frontera
#   se convierten en "ghost rows" intercambiadas via MPI.Sendrecv.
# ─────────────────────────────────────────────────────────────────────────────

mutable struct GrillaEspacial
    h        ::Float64             # altura de celda en Y
    L        ::Float64             # longitud del circuito (periodicidad)
    n_filas  ::Int                 # numero de filas en Y
    n_cols   ::Int                 # numero de columnas en X (= n_carriles)
    n_celdas ::Int                 # total de celdas = n_filas * n_cols
    celdas   ::Vector{Vector{Int}} # celdas[k] = indices de autos en celda k
end

"""
    GrillaEspacial(L; n_carriles=2, h=1.5)

Construye una grilla espacial para un circuito de longitud L con `n_carriles`
carriles de ancho 1.0 cada uno. `h` debe ser mayor que la diagonal maxima del
vehiculo mas grande para garantizar correctitud.
"""
function GrillaEspacial(L::Float64; n_carriles::Int=2, h::Float64=1.5)
    n_filas  = ceil(Int, L / h)
    n_cols   = n_carriles
    n_celdas = n_filas * n_cols
    celdas   = [sizehint!(Int[], 4) for _ in 1:n_celdas]
    return GrillaEspacial(h, L, n_filas, n_cols, n_celdas, celdas)
end

# Vacia todas las celdas en O(n_celdas) — llamar al inicio de cada paso
function limpiar_grilla!(g::GrillaEspacial)
    for k in 1:g.n_celdas
        empty!(g.celdas[k])
    end
end

# Inserta el auto i en su celda usando el centro del auto
@inline function insertar_en_grilla!(g::GrillaEspacial, autos::Vector{Auto}, i::Int)
    x, y = autos[i].posicion
    fila = mod(floor(Int, mod(y, g.L) / g.h), g.n_filas)
    col  = clamp(floor(Int, x), 0, g.n_cols - 1)
    push!(g.celdas[fila * g.n_cols + col + 1], i)
end

# Reconstruye la grilla completa en O(n)
function actualizar_grilla!(g::GrillaEspacial, autos::Vector{Auto})
    limpiar_grilla!(g)
    for i in 1:length(autos)
        insertar_en_grilla!(g, autos, i)
    end
end

# Devuelve todos los j > i en las 3x3 celdas vecinas del auto i
function candidatos_vecinos(i::Int, autos::Vector{Auto}, g::GrillaEspacial)
    x, y = autos[i].posicion
    fila_c = mod(floor(Int, mod(y, g.L) / g.h), g.n_filas)
    col_c  = clamp(floor(Int, x), 0, g.n_cols - 1)

    buf = Int[]
    @inbounds for df in -1:1
        fila_v = mod(fila_c + df, g.n_filas)          # periodicidad en Y
        for dc in -1:1
            col_v = col_c + dc
            (0 <= col_v < g.n_cols) || continue        # borde fisico en X
            k = fila_v * g.n_cols + col_v + 1
            for j in g.celdas[k]
                j > i && push!(buf, j)
            end
        end
    end
    return unique!(buf)
end

# ─────────────────────────────────────────────────────────────────────────────
# API publica — misma firma que antes; grilla es opcional
# ─────────────────────────────────────────────────────────────────────────────

"""
    haySuperposicionesSAT_error(autos, t; grilla=nothing)

Detecta colisiones entre todos los pares de autos.
- Sin grilla: O(n^2) fuerza bruta (compatible con codigo existente).
- Con grilla: O(n) esperado usando la GrillaEspacial.
"""
function haySuperposicionesSAT_error(autos::Vector{Auto}, t; grilla::Union{GrillaEspacial,Nothing}=nothing)
    if isnothing(grilla)
        # Fuerza bruta O(n^2) — fallback / modo debug
        n = length(autos)
        for i in 1:n
            for j in (i+1):n
                if seSuperponenSAT(autos[i], autos[j])
                    error("Superposicion detectada: auto $i y auto $j en paso $t")
                end
            end
        end
        return
    end

    # O(n) con grilla espacial
    actualizar_grilla!(grilla, autos)
    for i in 1:length(autos)
        for j in candidatos_vecinos(i, autos, grilla)
            if seSuperponenSAT(autos[i], autos[j])
                error("Superposicion detectada: auto $i y auto $j en paso $t")
            end
        end
    end
end
