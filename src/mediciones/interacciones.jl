"""
interacciones.jl — Medición de vecinos inmediatos e interacciones por vehículo.

Para cada vehículo en cada paso de simulación se cuenta el número de vecinos
inmediatos (vehículos dentro del umbral de interacción en la coordenada y,
considerando la periodicidad del circuito).

Se usa un `Set{Int}` por vehículo para garantizar que cada vecino real se
cuenta exactamente una vez, incluso si puede aparecer por múltiples canales
(ghosts, proyecciones de carril, etc.).

A partir de la distribución de vecinos se calcula la entropía de Shannon
como medida de "desorden" en la dinámica de interacción.
"""

# ─────────────────────────────────────────────────────────────────────────────
# Conteo de vecinos con periodicidad y Set
# ─────────────────────────────────────────────────────────────────────────────

"""
    contar_vecinos_paso(vehiculos, L, d_interaccion) -> Vector{Int}

Para cada vehículo cuenta cuántos otros vehículos están dentro de
`d_interaccion` en la coordenada y, respetando la periodicidad del circuito
de longitud L.

Cada par (i, j) se evalúa una sola vez; ambos vehículos se agregan
mutuamente a su `Set{Int}` de vecinos. El resultado es el número de
vecinos únicos de cada vehículo.
"""
function contar_vecinos_paso(vehiculos::Vector{Auto}, L::Float64, d_interaccion::Float64)
    n = length(vehiculos)
    # Un Set por vehículo — garantiza índices únicos aunque el mismo
    # vehículo aparezca por múltiples rutas de interacción
    vecinos = [Set{Int}() for _ in 1:n]

    @inbounds for i in 1:n
        yi = mod(vehiculos[i].posicion[2], L)
        @inbounds for j in (i+1):n
            yj  = mod(vehiculos[j].posicion[2], L)
            dy  = abs(yi - yj)
            # Distancia mínima en circuito periódico
            dy_per = dy > L/2 ? L - dy : dy
            if dy_per <= d_interaccion
                push!(vecinos[i], j)
                push!(vecinos[j], i)
            end
        end
    end

    return [length(vecinos[i]) for i in 1:n]
end

# ─────────────────────────────────────────────────────────────────────────────
# Entropía de Shannon de la distribución de vecinos
# ─────────────────────────────────────────────────────────────────────────────

"""
    entropia_shannon(conteos) -> Float64

Entropía de Shannon H [bits] de la distribución de conteos de vecinos.

    H = −Σ_k  p(k) log₂ p(k)

donde p(k) es la fracción de vehículos que tienen exactamente k vecinos.
H = 0 cuando todos los vehículos tienen el mismo número de vecinos (estado
ordenado); H es máxima cuando los conteos están uniformemente distribuidos.
"""
function entropia_shannon(conteos::Vector{Int})
    n = length(conteos)
    n == 0 && return 0.0

    # Frecuencia de cada valor de k (sin dependencia de StatsBase)
    freq = Dict{Int,Int}()
    for k in conteos
        freq[k] = get(freq, k, 0) + 1
    end

    H = 0.0
    for (_, cnt) in freq
        p = cnt / n
        H -= p * log2(p)
    end
    return H
end

"""
    entropia_por_paso(N_int) -> Vector{Float64}

Calcula la entropía de Shannon en cada paso a partir de la matriz de
interacciones N_int (pasos × n_vehiculos).
"""
function entropia_por_paso(N_int::Matrix{Int})
    pasos = size(N_int, 1)
    H = zeros(pasos)
    for t in 1:pasos
        H[t] = entropia_shannon(N_int[t, :])
    end
    return H
end

# ─────────────────────────────────────────────────────────────────────────────
# Simulación con medición de velocidades e interacciones
# ─────────────────────────────────────────────────────────────────────────────

"""
    avance_dos_carril_velocidades_e_interacciones(
        pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
        α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        d_interaccion = nothing,
        error = 1e-2,
        err   = 1e-6
    ) -> (T, V, N_int, H, K_mean)

Simulación de dos carriles con medición simultánea de velocidad promedio e
interacciones por vehículo en cada paso.

# Argumento opcional
- `d_interaccion` : umbral de vecindad en y [u]. Por defecto se usa
  `d_0_1 + largo_auto`, que aproxima la distancia mínima de seguimiento.
  También puede pasarse `Δx_s(d_0_1, α, μ, g, T_reac, v_ref, colchon)`
  para un umbral físicamente informado.

# Salidas
| Variable  | Tipo                   | Descripción                                      |
|-----------|------------------------|--------------------------------------------------|
| `T`       | `Vector{Float64}`      | Tiempos [s], longitud `pasos`                    |
| `V`       | `Vector{Float64}`      | Velocidad promedio del sistema por paso          |
| `N_int`   | `Matrix{Int}`          | Vecinos por vehículo por paso (pasos × n_veh)   |
| `H`       | `Vector{Float64}`      | Entropía de Shannon de la distribución de k [bits] |
| `K_mean`  | `Vector{Float64}`      | Número medio de vecinos por paso                 |
"""
function avance_dos_carril_velocidades_e_interacciones(
        pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
        α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        d_interaccion = nothing,
        error         = 1e-2,
        err           = 1e-6)

    carriless        = carriles(1, 2)
    giro_nogiro      = comprobacion_giro(vehiculos)
    θ_vec            = zeros(length(vehiculos))
    en_carril_ini    = carros_i_carriles(vehiculos, carriless)
    carriles_original = carril_original(vehiculos, en_carril_ini)

    n_veh  = length(vehiculos)
    T      = [t * δt for t in 1:pasos]
    V      = zeros(pasos)
    N_int  = zeros(Int, pasos, n_veh)
    H      = zeros(pasos)
    K_mean = zeros(pasos)

    # Umbral de interacción: longitud del auto + distancia mínima de seguridad.
    # El usuario puede pasar su propio valor (p.ej. Δx_s(...) para un umbral
    # basado en velocidad de referencia).
    d_int = isnothing(d_interaccion) ?
                (d_0_1 + vehiculos[1].largo) :
                Float64(d_interaccion)

    for t in 1:pasos
        # Avanzar un paso de simulación
        avance_dos_carriles_con_giro_sin_anim(
            vehiculos, θ_vec, carriless, carriles_original, giro_nogiro,
            egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel,
            v_max, v_min, n, m; error, err)

        # Velocidad promedio del sistema
        V[t] = velocidad_promedio_y(vehiculos)

        # Conteo de vecinos por vehículo (con Sets para unicidad)
        conteos        = contar_vecinos_paso(vehiculos, Float64(L), d_int)
        N_int[t, :]   .= conteos
        K_mean[t]      = mean(conteos)
        H[t]           = entropia_shannon(conteos)
    end

    return T, V, N_int, H, K_mean
end

# ─────────────────────────────────────────────────────────────────────────────
# Helpers de análisis post-simulación
# ─────────────────────────────────────────────────────────────────────────────

"""
    historial_interacciones_vehiculo(N_int, indice) -> Vector{Int}

Devuelve la serie temporal de número de vecinos para el vehículo `indice`.
"""
historial_interacciones_vehiculo(N_int::Matrix{Int}, indice::Int) = N_int[:, indice]

"""
    distribucion_interacciones(N_int) -> Dict{Int,Float64}

Distribución marginal del número de vecinos sobre todos los pasos y vehículos.
Las claves son el número de vecinos k; los valores son las probabilidades p(k).
"""
function distribucion_interacciones(N_int::Matrix{Int})
    vals  = vec(N_int)
    n     = length(vals)
    freq  = Dict{Int,Int}()
    for k in vals
        freq[k] = get(freq, k, 0) + 1
    end
    return Dict(k => cnt/n for (k, cnt) in freq)
end

"""
    entropia_global(N_int) -> Float64

Entropía de Shannon de la distribución marginal de vecinos
(integrando sobre todos los pasos y vehículos).
"""
function entropia_global(N_int::Matrix{Int})
    dist = distribucion_interacciones(N_int)
    H = 0.0
    for (_, p) in dist
        p > 0 && (H -= p * log2(p))
    end
    return H
end

"""
    guardar_interacciones_csv(T, V, H, K_mean, rho, epsilon; directorio="")

Guarda las series temporales de velocidad e interacciones en un CSV.
Columnas: tiempo, velocidad_promedio, entropia_shannon, vecinos_promedio.
"""
function guardar_interacciones_csv(
        T::Vector{Float64}, V::Vector{Float64},
        H::Vector{Float64}, K_mean::Vector{Float64},
        rho::Real, epsilon::Real; directorio::String="")

    nombre = "interacciones_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    isempty(directorio) || (nombre = joinpath(directorio, nombre))

    df = DataFrame(
        tiempo            = T,
        velocidad_promedio = V,
        entropia_shannon  = H,
        vecinos_promedio  = K_mean,
    )
    CSV.write(nombre, df)
    println("✅ Interacciones guardadas en: $nombre")
    println("📊 Pasos: $(length(T)), ρ = $rho, ε = $epsilon")
    return nombre
end
