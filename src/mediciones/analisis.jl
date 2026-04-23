using Statistics: mean, std

function media_movil_simple(velocidades, ventana::Int)
    n = length(velocidades)
    suavizada = similar(velocidades)
    for i in 1:n
        inicio = max(1, i - ventana ÷ 2)
        fin = min(n, i + ventana ÷ 2)
        suavizada[i] = mean(velocidades[inicio:fin])
    end
    return suavizada
end

function encontrar_ventana_optima(velocidades; max_ventana=1000)
    n = length(velocidades)
    diff_vel = diff(velocidades)
    variacion_media = mean(abs.(diff_vel))
    if variacion_media > 0.1 * std(velocidades)
        ventana = min(100, n ÷ 100)
    else
        ventana = min(500, n ÷ 20)
    end
    ventana = iseven(ventana) ? ventana + 1 : ventana
    println("Ventana recomendada: $ventana puntos (", round(ventana/n*100, digits=1), "%)")
    return ventana
end

function derivada_numerica(tiempo, valores)
    n = length(valores)
    derivada = zeros(n)
    for i in 2:n-1
        derivada[i] = (valores[i+1] - valores[i-1]) / (tiempo[i+1] - tiempo[i-1])
    end
    derivada[1] = (valores[2] - valores[1]) / (tiempo[2] - tiempo[1])
    derivada[n] = (valores[n] - valores[n-1]) / (tiempo[n] - tiempo[n-1])
    return derivada
end

function encontrar_t_critico(tiempo, velocidades_suavizadas; umbral=0.001)
    derivada = derivada_numerica(tiempo, velocidades_suavizadas)
    indices_estables = findall(x -> abs(x) < umbral, derivada)
    if isempty(indices_estables)
        println("No se encontró estabilización clara")
        return nothing, nothing, derivada
    end
    for i in 1:(length(indices_estables)-50)
        if all(diff(indices_estables[i:i+49]) .== 1)
            t_critico_idx = indices_estables[i]
            t_critico = tiempo[t_critico_idx]
            velocidad_constante = velocidades_suavizadas[t_critico_idx]
            return t_critico, velocidad_constante, derivada
        end
    end
    t_critico_idx = indices_estables[1]
    t_critico = tiempo[t_critico_idx]
    velocidad_constante = velocidades_suavizadas[t_critico_idx]
    return t_critico, velocidad_constante
end

"""
Aplica un segundo suavizado a las velocidades desde el t crítico.
"""
function doble_suavizado_desde_tcritico(tiempo, t_critico, velocidades_suavizadas)
    idx_critico = findfirst(t -> t >= t_critico, tiempo)
    if isnothing(idx_critico)
        error("t_critico $t_critico no encontrado en el array de tiempos")
    end
    tiempo_nuevo = tiempo[idx_critico:end]
    velocidades_desde_critico = velocidades_suavizadas[idx_critico:end]
    ventana_segundo_suavizado = encontrar_ventana_optima(velocidades_desde_critico)
    velocidades_doble_suave = media_movil_simple(velocidades_desde_critico, ventana_segundo_suavizado)
    @assert length(tiempo_nuevo) == length(velocidades_doble_suave)
    return tiempo_nuevo, velocidades_doble_suave
end
