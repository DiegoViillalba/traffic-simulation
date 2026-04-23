using CSV
using DataFrames

""" Guarda velocidades y tiempos en CSV (dos carriles) """
function guardarVelocidadesTiempos(tiempos::Vector{Float64}, velocidades::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    if length(tiempos) != length(velocidades)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    nombre_archivo = "velocidad_c_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    df = DataFrame(tiempo = tiempos, velocidad = velocidades)
    CSV.write(nombre_archivo, df)
    println("✅ Velocidades guardadas en: $nombre_archivo")
    println("📊 Registros: $(length(tiempos)), ρ = $rho, ε = $epsilon")
    return nombre_archivo
end

""" Guarda tiempos de flujo en CSV (dos carriles) """
function guardarTiemposFlujo(tiempos_flujo::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    if isempty(tiempos_flujo)
        @warn "El array de tiempos de flujo está vacío"
    end
    nombre_archivo = "flujo_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    df = DataFrame(tiempo_Flujo = tiempos_flujo)
    CSV.write(nombre_archivo, df)
    println("✅ Tiempos de flujo guardados en: $nombre_archivo")
    println("📊 Eventos de flujo: $(length(tiempos_flujo)), ρ = $rho, ε = $epsilon")
    return nombre_archivo
end

""" Guarda desplazamiento en CSV (dos carriles) """
function guardardesplazamientoTiempos(tiempos::Vector{Float64}, desplazamiento::Vector{Float64},desplazamiento_y::Vector{Float64}, rho::Real, epsilon::Real; directorio::String="")
    if length(tiempos) != length(desplazamiento)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    nombre_archivo = "desplazamiento_rho$(round(Int, 100*rho))_epsilon$(round(Int, 100*epsilon)).csv"
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    df = DataFrame(tiempo = tiempos, desplazamiento = desplazamiento, desplazamiento_y = desplazamiento_y)
    CSV.write(nombre_archivo, df)
    println("✅ Desplazamiento guardadas en: $nombre_archivo")
    println("📊 Registros: $(length(tiempos)), ρ = $rho, ε = $epsilon")
    return nombre_archivo
end

""" Función para simular y guardar todos los datos (dos carriles) """
function simular_y_guardar(pasos, egoismo,ancho, largo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min,n_total;
        tol=1e-2, err= 1e-6)
    vehiculos,n,m = generar_distribucion_automatica(n_total, d_0_1, largo, ancho, L)
    T, V, tiempos_cruce, desplazamiento, desplazamiento_y = medicion_velocidades_flujo_desplazamiento(
        pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        error=tol, err=err)
    guardarVelocidadesTiempos(T, V, (n_total*(largo+d_0_1))/(2*L) , egoismo)
    guardarTiemposFlujo(tiempos_cruce, (n_total*(largo+d_0_1))/(2*L), egoismo)
    guardardesplazamientoTiempos(T, desplazamiento,desplazamiento_y, (n_total*(largo+d_0_1))/(2*L) , egoismo)
    return T, V, tiempos_cruce, desplazamiento, desplazamiento_y
end

# ── Un carril ──────────────────────────────────────────────────────────────────

""" Guarda velocidades y tiempos en CSV (un carril, sin epsilon) """
function guardarVelocidadesTiempos_1carril(tiempos::Vector{Float64}, velocidades::Vector{Float64}, rho::Real; directorio::String="")
    if length(tiempos) != length(velocidades)
        error("Los arrays de tiempos y velocidades deben tener el mismo tamaño")
    end
    nombre_archivo = "velocidad_1carril_rho$(round(Int, 100*rho)).csv"
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    df = DataFrame(tiempo = tiempos, velocidad = velocidades)
    CSV.write(nombre_archivo, df)
    println("✅ Velocidades guardadas en: $nombre_archivo")
    println("📊 Registros: $(length(tiempos)), ρ = $rho")
    return nombre_archivo
end

""" Guarda tiempos de flujo en CSV (un carril) """
function guardarTiemposFlujo_1carril(tiempos_flujo::Vector{Float64}, rho::Real; directorio::String="")
    if isempty(tiempos_flujo)
        @warn "El array de tiempos de flujo está vacío"
    end
    nombre_archivo = "flujo_1carril_rho$(round(Int, 100*rho)).csv"
    if !isempty(directorio)
        if !endswith(directorio, "/")
            directorio *= "/"
        end
        nombre_archivo = directorio * nombre_archivo
    end
    df = DataFrame(tiempo_Flujo = tiempos_flujo)
    CSV.write(nombre_archivo, df)
    println("✅ Tiempos de flujo guardados en: $nombre_archivo")
    println("📊 Eventos de flujo: $(length(tiempos_flujo)), ρ = $rho")
    return nombre_archivo
end

""" Función para simular y guardar todos los datos para UN carril """
function simular_y_guardar_1carril(ts, ancho, largo, δt, L, d_0, α, μ, g, T_reac, colchon, acel, v_max, v_min, n_total; directorio="")
    vehiculos, n_acomodados, L_usado = generar_carril_unico(ancho, largo, L, d_0, n_total)
    densidad = (n_acomodados * (largo + d_0)) / L_usado
    println("🚗 Simulando 1 carril:")
    println("• Carros acomodados: $n_acomodados/$n_total")
    println("• Densidad: $densidad")
    println("• L usado: $L_usado")
    T, V, tiempos_cruce = medicion_un_carril_tiempo_vel_flujo(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    guardarVelocidadesTiempos_1carril(T, V, densidad; directorio=directorio)
    guardarTiemposFlujo_1carril(tiempos_cruce, densidad; directorio=directorio)
    return T, V, tiempos_cruce
end
