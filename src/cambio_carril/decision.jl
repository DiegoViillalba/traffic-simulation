""" calcula el pre-ángulo de giro de un auto que tiene ángulo cero """
function calcula_pre_angulo(vehiculos,carriles_original,i,carriles1;error = 1e-2)
    pre_θ = maximo_giro(vehiculos[i])/100
    test = carriles_original[i]
    pre_θ = Angulo_giro_correcion(vehiculos[i],pre_θ,test,carriles1;error)
    return pre_θ
end

""" comprueba si la velocidad del carril derecho es mayor (siempre retorna false — condición desactivada) """
function velocidades_test_derecha(lista_carril1,lista_carril2,v_max,a::Auto)
    # Condición de velocidades desactivada intencionalmente
    return false
end

""" comprueba si la velocidad del carril izquierdo es mayor (siempre retorna false — condición desactivada) """
function velocidades_test_izquierda(lista_carril1,lista_carril2,v_max,a::Auto)
    # Condición de velocidades desactivada intencionalmente
    return false
end

""" calcula la separación instantánea entre el auto y sus vecinos (caso derecha) """
function condicion_de_separacion_derecha(a::Auto,lista_carril1,lista_carril2,L)
    if lista_carril2 != []
        y1 = a.posicion[2]
        arr1 = [lista_carril1[i].posicion[2] for i in 1:length(lista_carril1)]
        a1,b1 = numeros_cercanos(arr1, y1)
        i = encontrar_posicion(arr1, a1)
        sep1 = separacion_dos_autos(a,lista_carril1[i],L)
        y2 = a.esquinas[2][2]
        arr2 = [lista_carril2[i].posicion[2] for i in 1:length(lista_carril2)]
        a2,b2 = numeros_cercanos(arr2, y2)
        i = encontrar_posicion(arr2, a2)
        fantasma =  Auto(a.ancho,0,[lista_carril2[i].posicion[1],y2],1,a.velocidad)
        sep2 = separacion_dos_autos(fantasma,lista_carril2[i],L)
        return sep1,sep2
    end
    y1 = a.posicion[2]
    arr1 = [lista_carril1[i].posicion[2] for i in 1:length(lista_carril1)]
    a1,b1 = numeros_cercanos(arr1, y1)
    i = encontrar_posicion(arr1, a1)
    sep1 = separacion_dos_autos(a,lista_carril1[i],L)    
    return sep1,Inf
end

""" calcula la separación instantánea entre el auto y sus vecinos (caso izquierda) """
function condicion_de_separacion_izquierda(a::Auto,lista_carril1,lista_carril2,L)
    if lista_carril1 != []
        y1 = a.posicion[2]
        arr1 = [lista_carril2[i].posicion[2] for i in 1:length(lista_carril2)]
        a1,b1 = numeros_cercanos(arr1, y1)
        i = encontrar_posicion(arr1, a1)
        sep2 = separacion_dos_autos(a,lista_carril2[i],L)
        y2 = a.esquinas[1][2]
        arr2 = [lista_carril1[i].posicion[2] for i in 1:length(lista_carril1)]
        a2,b2 = numeros_cercanos(arr2, y2)
        i = encontrar_posicion(arr2, a2)
        fantasma =  Auto(a.ancho,0,[lista_carril1[i].posicion[1],y2],1,a.velocidad)
        sep1 = separacion_dos_autos(fantasma,lista_carril1[i],L)
        return sep1,sep2
    end
    y1 = a.posicion[2]
    arr1 = [lista_carril2[i].posicion[2] for i in 1:length(lista_carril2)]
    a1,b1 = numeros_cercanos(arr1, y1)
    i = encontrar_posicion(arr1, a1)
    sep2 = separacion_dos_autos(a,lista_carril2[i],L)
    return Inf,sep2
end

""" conjunto de condiciones para permitir el cambio a la derecha """
function condiciones_permitir_giro_derecha(Auto,sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    test1 = velocidades_test_derecha(lista_carril1,lista_carril2,v_max,Auto)
    if test1
        return false
    end
    if sep1 > sep2
        return false
    end
    if lista_carril2 != []
        test = decide_cambiar_derecha(Auto,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    else
        test = true
    end
    return test
end

""" conjunto de condiciones para permitir el cambio a la izquierda """
function condiciones_permitir_giro_izquierda(Auto,sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_1,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    test1 = velocidades_test_izquierda(lista_carril1,lista_carril2,v_max,Auto)
    if test1
        return false
    end
    if sep1 < sep2
        return false
    end
    if lista_carril1 != []
        test = decide_cambiar_izquierda(Auto,lista_carril1,θ1,egoismo,δt,L,d_0_1,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    else
        test = true
    end
    return test
end

""" condiciones generales para decidir el cambio de carril (derecha o izquierda) """
function decide_cambiar_general(Autos,i,sep_fantasmas_1,sep_fantasmas_2,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,giro_nogiro,θ1,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if θ1 < 0 # giro derecha
        test1 = condicion_giro_enfrente(i,indice_enfrente_1,giro_nogiro)
        if test1
            return false
        end
        sep1,sep2 = condicion_de_separacion_derecha(Autos[i],lista_carril1,lista_carril2,L)
        test = condiciones_permitir_giro_derecha(Autos[i],sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    elseif θ1 >  0 # giro izquierda
        test1 = condicion_giro_enfrente(i,indice_enfrente_2,giro_nogiro)
        if test1
            return false
        end
        sep1,sep2 = condicion_de_separacion_izquierda(Autos[i],lista_carril1,lista_carril2,L)
        test = condiciones_permitir_giro_izquierda(Autos[i],sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)    
    end
    return test
end

""" actualiza el ángulo de giro θ_vec[i] para el paso actual """
function actualizar_angulo_giro(sep_fantasmas_1,sep_fantasmas_2,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carriles1;error = 1e-2)
    if giro_nogiro[i] == false
        pre_θ = calcula_pre_angulo(vehiculos,carriles_original,i,carriles1;error)
        test = decide_cambiar_general(vehiculos,i,sep_fantasmas_1,sep_fantasmas_2,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,giro_nogiro,pre_θ,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        if test == true
            θ_vec[i] = pre_θ
        end
    else
        test = carriles_original[i]
        θ_vec[i] = maximo_giro(vehiculos[i])/100
        θ_vec[i] = Angulo_giro_correcion(vehiculos[i],θ_vec[i],test,carriles1;error) 
    end
end
