

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
    
    # Calcular la frecuencia dominante aproximada
    diff_vel = diff(velocidades)
    variacion_media = mean(abs.(diff_vel))
    
    # Ventana basada en la variación (empírico)
    if variacion_media > 0.1 * std(velocidades)
        ventana = min(100, n ÷ 100)  # Mucha variación → ventana pequeña
    else
        ventana = min(500, n ÷ 20)   # Poca variación → ventana grande
    end
    
    # Asegurar que sea impar para algunos filtros
    ventana = iseven(ventana) ? ventana + 1 : ventana
    
    println("Ventana recomendada: $ventana puntos (", round(ventana/n*100, digits=1), "%)")
    return ventana
end


function derivada_numerica(tiempo, valores)
    n = length(valores)
    derivada = zeros(n)
    
    # Puntos interiores (diferencias centradas)
    for i in 2:n-1
        derivada[i] = (valores[i+1] - valores[i-1]) / (tiempo[i+1] - tiempo[i-1])
    end
    
    # Bordes (diferencias hacia adelante/atrás)
    derivada[1] = (valores[2] - valores[1]) / (tiempo[2] - tiempo[1])
    derivada[n] = (valores[n] - valores[n-1]) / (tiempo[n] - tiempo[n-1])
    
    return derivada
end

function encontrar_t_critico(tiempo, velocidades_suavizadas; umbral=0.001)
    # Calcular derivada numérica
    derivada = derivada_numerica(tiempo, velocidades_suavizadas)
    
    # Encontrar donde la derivada es cercana a cero (estabilización)
    indices_estables = findall(x -> abs(x) < umbral, derivada)
    
    if isempty(indices_estables)
        println("No se encontró estabilización clara")
        return nothing, nothing, derivada
    end
    
    # Buscar el primer bloque estable de al menos 50 puntos consecutivos
    for i in 1:(length(indices_estables)-50)
        if all(diff(indices_estables[i:i+49]) .== 1)
            t_critico_idx = indices_estables[i]
            t_critico = tiempo[t_critico_idx]
            velocidad_constante = velocidades_suavizadas[t_critico_idx]
            return t_critico, velocidad_constante, derivada
        end
    end
    
    # Si no encuentra bloque, tomar el primer punto estable
    t_critico_idx = indices_estables[1]
    t_critico = tiempo[t_critico_idx]
    velocidad_constante = velocidades_suavizadas[t_critico_idx]
    
    return t_critico, velocidad_constante
end

"""
    Aplica un segundo suavizado a las velocidades desde el t crítico
    
    Args:
        tiempo: Array de tiempos original
        t_critico: Tiempo crítico donde comienza la estabilización
        velocidades_suavizadas: Array de velocidades ya suavizadas
        ventana_segundo_suavizado: Tamaño de ventana para el segundo suavizado
    
    Returns:
        tiempo_nuevo: Tiempos desde t_critico
        velocidades_doble_suave: Velocidades doblemente suavizadas
    """
function doble_suavizado_desde_tcritico(tiempo, t_critico, velocidades_suavizadas)

    
    # Encontrar el índice correspondiente al t_critico
    idx_critico = findfirst(t -> t >= t_critico, tiempo)
    
    if isnothing(idx_critico)
        error("t_critico $t_critico no encontrado en el array de tiempos")
    end
    
    # Extraer datos desde t_critico
    tiempo_nuevo = tiempo[idx_critico:end]
    velocidades_desde_critico = velocidades_suavizadas[idx_critico:end]
    ventana_segundo_suavizado = encontrar_ventana_optima(velocidades_desde_critico)
    # Aplicar segundo suavizado
    velocidades_doble_suave = media_movil_simple(velocidades_desde_critico, ventana_segundo_suavizado)
    
    # Asegurar que tengan la misma longitud
    @assert length(tiempo_nuevo) == length(velocidades_doble_suave)
    
    return tiempo_nuevo, velocidades_doble_suave
end


using CSV
using DataFrames

# Función para guardar velocidades y tiempos
function guardarVelocidadesTiempos(tiempos::Vector{Float64}, velocidades::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    # Verificar que los arrays tengan el mismo tamaño
    if length(tiempos) != length(velocidades)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    
    # Crear el nombre del archivo con el formato especificado
    nombre_archivo = "velocidad_c_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    
    # Agregar directorio si se especifica
    if !isempty(directorio)
        # Asegurar que el directorio termina con /
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    
    # Crear DataFrame
    df = DataFrame(
        tiempo = tiempos,
        velocidad = velocidades
    )
    
    # Guardar en CSV
    CSV.write(nombre_archivo, df)
    
    println("✅ Velocidades guardadas en: $nombre_archivo")
    println("📊 Registros: $(length(tiempos)), ρ = $rho, ε = $epsilon")
    
    return nombre_archivo
end

# Función para guardar tiempos de flujo
function guardarTiemposFlujo(tiempos_flujo::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    # Verificar que el array no esté vacío
    if isempty(tiempos_flujo)
        @warn "El array de tiempos de flujo está vacío"
    end
    
    # Crear el nombre del archivo con el formato especificado
    nombre_archivo = "flujo_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    
    # Agregar directorio si se especifica
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    
    # Crear DataFrame
    df = DataFrame(tiempo_Flujo = tiempos_flujo)
    
    # Guardar en CSV
    CSV.write(nombre_archivo, df)
    
    println("✅ Tiempos de flujo guardados en: $nombre_archivo")
    println("📊 Eventos de flujo: $(length(tiempos_flujo)), ρ = $rho, ε = $epsilon")
    
    return nombre_archivo
end


function guardardesplazamientoTiempos(tiempos::Vector{Float64}, desplazamiento::Vector{Float64},desplazamiento_y::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    # Verificar que los arrays tengan el mismo tamaño
    if length(tiempos) != length(desplazamiento)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    
    # Crear el nombre del archivo con el formato especificado
    nombre_archivo = "desplazamiento_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    
    # Agregar directorio si se especifica
    if !isempty(directorio)
        # Asegurar que el directorio termina con /
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    
    # Crear DataFrame
    df = DataFrame(
        tiempo = tiempos,
        desplazamiento = desplazamiento,
        desplazamiento_y = desplazamiento_y
        
    )
    
    # Guardar en CSV
    CSV.write(nombre_archivo, df)
    
    println("✅ Desplazamiento guardadas en: $nombre_archivo")
    println("📊 Registros: $(length(tiempos)), ρ = $rho, ε = $epsilon")
    
    return nombre_archivo
end




""" Función para simular y guardar todos los datos"""
function simular_y_guardar(pasos, egoismo,ancho, largo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min,n_total;
        tol=1e-2, err= 1e-6)

    vehiculos,n,m = generar_distribucion_automatica(n_total, d_0_1, largo, ancho, L)
    
    # Ejecutar simulación
    T, V, tiempos_cruce, desplazamiento, desplazamiento_y = medicion_velocidades_flujo_desplazamiento(
        pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        error=tol, err=err)
    
    # Guardar todos los datos
    guardarVelocidadesTiempos(T, V, (n_total*(largo+d_0_1))/(2*L) , egoismo)
    guardarTiemposFlujo(tiempos_cruce, (n_total*(largo+d_0_1))/(2*L), egoismo)
    guardardesplazamientoTiempos(T, desplazamiento,desplazamiento_y, (n_total*(largo+d_0_1))/(2*L) , egoismo)
    
    return T, V, tiempos_cruce, desplazamiento, desplazamiento_y
end
