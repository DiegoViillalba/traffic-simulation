""" Devuelve arreglos T (tiempo) y V (velocidad promedio) para simulación de un carril """
function avance_un_carril_valocidades_promedio(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    T = [ t*δt for t in 1:ts]
    V = zeros(ts)
    for t in 1:ts
        for i in 1:length(vehiculos)
            avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        end
        V[t] = velocidad_promedio_y(vehiculos)
    end
    return T,V
end

""" Genera un plot de velocidad promedio vs tiempo para un carril """
function avance_un_carril_valocidades_promedio!(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min;kargs...)
    T = [t*δt for t in 1:ts]
    V = zeros(ts)
    for t in 1:ts
        for i in 1:length(vehiculos)
            avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        end
        V[t] = velocidad_promedio_y(vehiculos)
    end
    plot(T,V;kargs...)
end

""" Mide velocidad promedio en función de la densidad para un carril """
function medicion_velocidades_densidad(ts,t_critico,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min,n_max)
    ρ = [n/(3.5*L) for n in 1:n_max]
    v_promedio_de_promedio = zeros(n_max)
    for n in 1:n_max
        largo = 9/7
        ancho = 18/35
        Δx = 0.8
        vehiculos = carros(ancho,largo,L,Δx,n;xs = 1/2)
        T,V = avance_un_carril_valocidades_promedio(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        v_promedio_de_promedio[n] = sum(V[t_critico:end])/length(V[t_critico:end])
    end
    return ρ,v_promedio_de_promedio
end

""" Devuelve arreglos T y V de velocidades promedio para dos carriles """
function avance_dos_carril_valocidades_promedio(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    T = [t*δt for t in 1:pasos]
    V = zeros(pasos)
    for t in 1:pasos
        avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
        V[t] = velocidad_promedio_y(vehiculos)
    end
    return T,V
end

""" Mide la distancia entre dos posiciones de un auto (desplazamiento total) """
function desplazamiento_auto(pos_actual,pos_nueva,L)
    if (L  - pos_actual[2] ) < (L  - pos_nueva[2] )
        return norm([pos_nueva[1],L + pos_nueva[2]] - pos_actual)
    end
    return norm(pos_nueva - pos_actual) 
end

""" Mide la distancia en Y entre dos posiciones de un auto """
function desplazamiento_auto_y(pos_actual,pos_nueva,L)
    if (L  - pos_actual[2] ) < (L  - pos_nueva[2] )
        return abs(L + pos_nueva[2] - pos_actual[2])
    end
    return abs(pos_nueva[2] - pos_actual[2]) 
end

""" Simula dos carriles y mide velocidad, tiempos de cruce y desplazamiento """
function medicion_velocidades_flujo_desplazamiento(pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m; error=1e-2, err=1e-6)
    carriless = carriles(1, 2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos, carriless)
    carriles_original = carril_original(vehiculos, en_carril)
    desplazamiento = zeros(pasos)
    desplazamiento_y = zeros(pasos)
    T = [t * δt for t in 1:pasos]
    V = zeros(pasos)
    estimado = length(vehiculos) * pasos * 2
    tiempos_cruce = Vector{Float64}(undef, estimado)
    count = 0
    posiciones_iniciales = [copy(vehiculos[i].posicion) for i in 1:length(vehiculos)]
    for t in 1:pasos
        indices_alternados = generar_indices_alternados(n, m)  
        des = zeros(length(vehiculos))
        des_y = zeros(length(vehiculos))
        for i in indices_alternados
            posiciones_iniciales[i] = copy(vehiculos[i].posicion)
        end
        for i in indices_alternados
            avance_dos_carriles_con_giro_un_paso(i, vehiculos, θ_vec, carriless, carriles_original, giro_nogiro, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min; error, err)
            test = limites_auto_carril!(vehiculos[i], L)
            if test
                count += 1
                tiempos_cruce[count] = t * δt
            end
        end
        for i in indices_alternados
            des[i] = desplazamiento_auto(posiciones_iniciales[i], vehiculos[i].posicion, L)
            des_y[i] = desplazamiento_auto_y(posiciones_iniciales[i], vehiculos[i].posicion, L)
        end
        desplazamiento[t] = sum(des) / length(des)
        desplazamiento_y[t] = sum(des_y) / length(des_y)
        V[t] = velocidad_promedio_y(vehiculos)
    end
    return T, V, tiempos_cruce[1:count], desplazamiento, desplazamiento_y
end

""" Simula un carril y mide velocidad y tiempos de cruce """
function medicion_un_carril_tiempo_vel_flujo(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    T = [t * δt for t in 1:ts]
    V = zeros(ts)
    estimado = length(vehiculos) * ts * 2
    tiempos_cruce = Vector{Float64}(undef, estimado)
    count = 0
    for t in 1:ts
        for i in 1:length(vehiculos)
            Sep = separacion_en_y(vehiculos, L)
            j = length(vehiculos)-i+1
            v_1 = vehiculos[j].velocidad[2]
            condicion_cambio_velocidad(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,acel,vehiculos,j)
            cond_vel_sup_in(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_max,v_min)
            test = actualizar_posicion_un_carril!(vehiculos,δt,L,j)
            actualizar_esquinas_un_carril(vehiculos,j)
            if test
                count += 1
                tiempos_cruce[count] = t * δt
            end
        end
        V[t] = velocidad_promedio_y(vehiculos)
    end
    return T, V, tiempos_cruce[1:count]
end
