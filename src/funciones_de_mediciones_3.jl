# Función para guardar velocidades y tiempos (sin epsilon)
function guardarVelocidadesTiempos_1carril(tiempos::Vector{Float64}, velocidades::Vector{Float64}, rho::Real; directorio::String="")
    # Verificar que los arrays tengan el mismo tamaño
    if length(tiempos) != length(velocidades)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    
    # Crear el nombre del archivo con el formato especificado (sin epsilon)
    nombre_archivo = "velocidad_1carril_rho$(round(Int, 100*rho)).csv"
    
    # Agregar directorio si se especifica
    if !isempty(directorio)
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
    println("📊 Registros: $(length(tiempos)), ρ = $rho")
    
    return nombre_archivo
end

# Función para guardar tiempos de flujo (sin epsilon)
function guardarTiemposFlujo_1carril(tiempos_flujo::Vector{Float64}, rho::Real; directorio::String="")
    # Verificar que el array no esté vacío
    if isempty(tiempos_flujo)
        @warn "El array de tiempos de flujo está vacío"
    end
    
    # Crear el nombre del archivo con el formato especificado (sin epsilon)
    nombre_archivo = "flujo_1carril_rho$(round(Int, 100*rho)).csv"
    
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
    println("📊 Eventos de flujo: $(length(tiempos_flujo)), ρ = $rho")
    
    return nombre_archivo
end



""" Función para simular y guardar todos los datos para UN carril"""
function simular_y_guardar_1carril(ts, ancho, largo, δt, L, d_0, α, μ, g, T_reac, colchon, acel, v_max, v_min, n_total; directorio="")
    
    # Generar vehículos para un solo carril
    vehiculos, n_acomodados, L_usado = generar_carril_unico(ancho, largo, L, d_0, n_total)
    
    # Calcular densidad real (para un carril)
    densidad = (n_acomodados * (largo + d_0)) / L_usado
    
    println("🚗 Simulando 1 carril:")
    println("• Carros acomodados: $n_acomodados/$n_total")
    println("• Densidad: $densidad")
    println("• L usado: $L_usado")
    
    # Ejecutar simulación (con m=0 para indicar un solo carril)
    T, V, tiempos_cruce = medicion_un_carril_tiempo_vel_flujo(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    # Guardar todos los datos (sin parámetro de egoísmo)
    guardarVelocidadesTiempos_1carril(T, V, densidad; directorio=directorio)
    guardarTiemposFlujo_1carril(tiempos_cruce, densidad; directorio=directorio)
    
    return T, V, tiempos_cruce
end