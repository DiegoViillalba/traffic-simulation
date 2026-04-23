""" Genera índices alternados: [n, n+m, n-1, n+m-1, ..., 1, n+1] """
function generar_indices_alternados(n, m)
    indices = Int[]
    total = n + m
    segmento1 = n:-1:1
    segmento2 = (n+m):-1:(n+1)
    i = 1
    j = 1
    while i <= length(segmento1) || j <= length(segmento2)
        if i <= length(segmento1)
            push!(indices, segmento1[i])
            i += 1
        end
        if j <= length(segmento2)
            push!(indices, segmento2[j])
            j += 1
        end
    end
    return indices
end

""" Genera índices alternados en orden contrario: [1, n+1, 2, n+2, ..., n, n+m] """
function indices_alternados_contrario(n, m)
    indices = Int[]
    for i in 1:max(n, m)
        if i <= n
            push!(indices, i)
        end
        if i <= m
            push!(indices, n + i)
        end
    end
    return indices
end

""" Compila las funciones de velocidad para el avance del carro i (velocidad != 0) """
function condicion_velocidad_2_giro(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error = 1e-2)
    velocidad_un_fantasmas(carril_1,fantasmas_1,sep_fantasmas_1,i,indice_enfrente_1,δt,d_0_1,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    velocidad_un_fantasmas(carril_2,fantasmas_2,sep_fantasmas_2,i,indice_enfrente_2,δt,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    escoje_velocidad_real!(vehiculos,fantasmas_1, fantasmas_2,giro_nogiro,en_carril,i)
    actualizar_angulo_giro(sep_fantasmas_1,sep_fantasmas_2,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carriles1;error)
    actualiza_comprobacion_giro(vehiculos,giro_nogiro,i;err= 1e-6)
    actualiza_cambio_de_carril_original(giro_nogiro,carriles_original,en_carril,i)    
    velocidad_angular_carro_correcion!(vehiculos[i],δt,θ_vec[i])
end

""" Compila todas las funciones necesarias para el avance del carro i """
function avance_carros(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error = 1e-2,err= 1e-6)
    condicion_velocidad_2_giro(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error)
end

""" Compila las funciones y arreglos necesarios para avanzar un solo auto i """
function avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error = 1e-2,err= 1e-6)
    en_carril = carros_i_carriles(vehiculos,carriless)
    fantasmas_1, fantasmas_2 = listas_carros_fantasmas(vehiculos)
    carril_1, carril_2 = ordenar_carriles!(vehiculos,en_carril,giro_nogiro)
    indice_enfrente_1 = identifica_adelante(carril_1,fantasmas_1)
    indice_enfrente_2 = identifica_adelante(carril_2,fantasmas_2)
    sep_fantasmas_1,sep_fantasmas_2 = separaciones_por_carriles_dos(carril_1, carril_2,fantasmas_1,fantasmas_2,L)
    lista_carril1,lista_carril2 = listas_pregiro!(fantasmas_1,fantasmas_2,en_carril,giro_nogiro)
    avance_carros(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriless;error,err)
end

""" Avanza todos los carros con animación """
function avance_dos_carriles_con_giro_para_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    indices_alternados = generar_indices_alternados(n, m)  
    for i in indices_alternados
        avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
        limites_auto_carril(vehiculos[i],L)
    end
    plot(vehiculos,key=false,ylim=(0,L) , xlim=(-1-carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[2][1]+1);kargs...)
    vline!([carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[1][1], carriless[2].inicio_fin[2][1]], color = :black)
end

""" Avanza todos los carros SIN animación """
function avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    indices_alternados = generar_indices_alternados(n, m)   
    for i in indices_alternados
        avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
        limites_auto_carril(vehiculos[i],L)
    end
end

""" Función principal: avanza los carros en dos carriles (con giro, sin animación) """
function avance_carros_general(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,usar_grilla=true)
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    # Grilla espacial creada una sola vez antes del loop — O(n) por paso
    grilla = usar_grilla ? GrillaEspacial(Float64(L)) : nothing
    for t in 1:pasos
        avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error,err)
        haySuperposicionesSAT_error(vehiculos,t; grilla=grilla)
    end
end

""" Función principal: avanza los carros y crea una animación """
function avance_carros_general!(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    @animate  for t in 1:pasos
        avance_dos_carriles_con_giro_para_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error,err,kargs...)
    end
end
