""" calcula el pre-angulo de giro de un auto que tien angulo cero"""
function calcula_pre_angulo(vehiculos,carriles_original,i,carriles1;error = 1e-2)
    
    pre_θ = maximo_giro(vehiculos[i])/100
    test = carriles_original[i]
    pre_θ = Angulo_giro_correcion(vehiculos[i],pre_θ,test,carriles1;error)
    
    return pre_θ
    
    
end

""" comprueba si la velocidad del otro carril es mayor que en donde se encuntra el auto (queremos comprobar que v_derecha > v_izquierda para permitir el cambio) """
function velocidades_test_derecha(lista_carril1,lista_carril2,v_max,a::Auto)
    v1 = a.velocidad[2]
    v2 = velocidad_promedio_y_correcion(lista_carril2,v_max)
    if v1 > v2
        
        s = true
    end
    
        s = false
    return s
end

""" comprueba si la velocidad del otro carril es mayor que en donde se encuentra el auto (queremos comprobar que v_derecha < v_izquierda para permitir el cambio)"""
function velocidades_test_izquierda(lista_carril1,lista_carril2,v_max,a::Auto)
    
    v1 = velocidad_promedio_y_correcion(lista_carril1,v_max)
    v2 = a.velocidad[2]
    if v2 > v1
        s = true
    end
        s = false
    return s
end

""" calcula la separacion que tienen en un instante...""" 
function condicion_de_separacion_derecha(a::Auto,lista_carril1,lista_carril2,L)
    
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
""" calcula la separacion que tienen en un instante...""" 
function condicion_de_separacion_izquierda(a::Auto,lista_carril1,lista_carril2,L)
    
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

""" funcion que tiene un conjunto de condiciones para permitir el cambio a la derecha """
function condiciones_permitir_giro_derecha(Auto,sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    test1 = velocidades_test_derecha(lista_carril1,lista_carril2,v_max,Auto) # condicion de velocidades
    if test1 #condicion de velocidad
        return false
    end
    
    #if length(lista_carril1) < length(lista_carril2)  # condicion densidad de autos por carril condicion
        #return false
    #end
    
   if sep1 > sep2 # condicion de espacio con el del enfrente
        return false
   end
        
    if lista_carril2 != []  # condicion de velocidades seguras y egoismo
        test = decide_cambiar_derecha(Auto,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    else
        test = true
    end
    return test
    
end

""" funcion que tiene un conjunto de condiciones para permitir el cambio a la izquierda """
function condiciones_permitir_giro_izquierda(Auto,sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    test1 = velocidades_test_izquierda(lista_carril1,lista_carril2,v_max,Auto)
    
    if test1 #condicion de velocidad
        return false
    end
    
    #if length(lista_carril2) < length(lista_carril1)  # condicion densidad de autos por carril condicion
        #return false
    #end
    
    if sep1 < sep2 # condicion de espacio con el del enfrente
        return false
    end
        
    if lista_carril1 != []
        test = decide_cambiar_izquierda(Auto,lista_carril1,θ1,egoismo,δt,L,d_0_1,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    else
        test = true
    end   
    return test
end


""" funcion que tiene un conjunto de condiciones para permitir el cambio  cual sea el carril """
function decide_cambiar_general(Autos,i,sep_fantasmas_1,sep_fantasmas_2,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,giro_nogiro,θ1,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)

    
    if θ1 < 0 # giro derecha
        
        test = condicion_giro_enfrente(i,indice_enfrente_1,giro_nogiro)
        if test
            return false
        end
        sep1,sep2 = condicion_de_separacion_derecha(Autos[i],lista_carril1,lista_carril2,L)
        
        test = condiciones_permitir_giro_derecha(Autos[i],sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        
    elseif θ1 >  0 # giro izquierda
        
        test = condicion_giro_enfrente(i,indice_enfrente_2,giro_nogiro)
        if test
            return false
        end
            
        sep1,sep2 = condicion_de_separacion_izquierda(Autos[i],lista_carril1,lista_carril2,L)
        test = condiciones_permitir_giro_izquierda(Autos[i],sep1,sep2,lista_carril1,lista_carril2,θ1,egoismo,δt,L,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min)    
    end
    return test

end

""" cambia el angulo de giro """
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

""" funcion que actualiza si el carro esta en el estado girando o no(funcion para ahorrar recursos) """
function actualiza_comprobacion_giro(Autos,giro_nogiro,i;err= 1e-6)
    
    test1,test2 = direccion_correcion(Autos[i];err)
        
        
        if test1 == true && test2 == true
            giro_nogiro[i] = false
        else
            giro_nogiro[i] = true
        end
        
end

""" funcion que actualiza el carril original del auto(funcion para ahorrar recursos) """
function actualiza_cambio_de_carril_original(giro_nogiro,carriles_original,en_carril,i)
    

    if en_carril[i][2] == false && en_carril[i][3] == true && carriles_original[i] == 0 && giro_nogiro[i] == false
            
        carriles_original[i]  = 1
            
    elseif en_carril[i][2] == true && en_carril[i][3] == false && carriles_original[i] == 1 && giro_nogiro[i] == false
            
        carriles_original[i] = 0
    end
   
    
end

""" escojemos la velocidad real del carro dado las dos velocidades de los fantasmas (corregido para dos carriles con giro) """
function escoje_velocidad_real!(carros,fantasmas_1, fantasmas_2,giro_nogiro,en_carril,i)
    
        v1 = copy(fantasmas_1[i].velocidad[2])
        v2 = copy(fantasmas_2[i].velocidad[2])
    
        if giro_nogiro[i] == true 
        
            carros[i].velocidad[2] = min(v1,v2)
            #carros[i].velocidad[1] = 0
        
        else
            
            if en_carril[i][2] == true && en_carril[i][3] == false
                carros[i].velocidad[2] = v1
                #carros[i].velocidad[1] = 0
            
            elseif en_carril[i][2] == false && en_carril[i][3] == true 
                carros[i].velocidad[2] = v2
                #carros[i].velocidad[1] = 0
            end
            
        end
    
end

""" Dado una lista de carros y de carriles regresa dos arreglos que contiene el indice de los carros del arreglo uno corresponde al carril dos y el arreglo 2 correspondiente al carril 2, ademas estan ordenados de posicion mayor al menor(corregido para dos carriles con giro)"""
function ordenar_carriles!(carros, en_carril,giro_nogiro)
    
    posiciones_y = [carros[i].posicion[2] for i in 1:length(carros)]
    
    # Inicializar listas para los índices de cada carril
    carril_1 = Int[]
    carril_2 = Int[]

    # Iterar sobre cada carro
    for i in 1:length(carros)
        if giro_nogiro[i] == true
            push!(carril_1, i)
            push!(carril_2, i)
        else
            if en_carril[i][2] == true # Si está en el carril 1
                push!(carril_1, i)
            end
            if en_carril[i][3] == true # Si está en el carril 2
                push!(carril_2, i)
            end
        end
    end

    # Ordenar los índices según la posición en el eje "y"
    sort!(carril_1, by=i -> -posiciones_y[i])  # Orden descendente
    sort!(carril_2, by=i -> -posiciones_y[i])

    return carril_1, carril_2
end

""" funcion que nos da arreglos de los fantasmas que son relvantes pra el cambio de carril """
function listas_pregiro!(fantasmas_1,fantasmas_2,en_carril,giro_nogiro)
    
    
        
    #DERECHA
        lista_carril2 = Auto[]
    #IZQUIERDA
    
        lista_carril1 = Auto[]
    
    for i in 1:length(fantasmas_1)
        
        if giro_nogiro == true
            push!(lista_carril1, deepcopy(fantasmas_1[i]))
            push!(lista_carril2, deepcopy(fantasmas_2[i]))
            
        else
            
            if en_carril[i][2] == true
            
                push!(lista_carril1, deepcopy(fantasmas_1[i]))
            end
            
            if en_carril[i][3] == true
                
                push!(lista_carril2, deepcopy(fantasmas_2[i]))
                    
            end
        end
        
        
    end
    
    return lista_carril1,lista_carril2
    
end

