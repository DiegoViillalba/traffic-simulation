""" Dado una lista de carros y de carriles regresa dos arreglos que contiene el indice de los carros del arreglo uno corresponde al carril dos y el arreglo 2 correspondiente al carril 2, ademas estan ordenados de posicion mayor al menor"""

function ordenar_carriles(carros, en_carril)
    
    posiciones_y = [carros[i].posicion[2] for i in 1:length(carros)]
    
    # Inicializar listas para los índices de cada carril
    carril_1 = Int[]
    carril_2 = Int[]

    # Iterar sobre cada carro
    for i in 1:length(carros)
        if en_carril[i][2] == true # Si está en el carril 1
            push!(carril_1, i)
        end
        if en_carril[i][3] == true # Si está en el carril 2
            push!(carril_2, i)
        end
    end

    # Ordenar los índices según la posición en el eje "y"
    sort!(carril_1, by=i -> -posiciones_y[i])  # Orden descendente
    sort!(carril_2, by=i -> -posiciones_y[i])

    return carril_1, carril_2
end

""" funcion auxiliar que dado dos autos en el mismo carril nos regresa su separacion """
function separacion_dos_autos(auto1,auto2,L)
    # auto 2 es el del frente
    # Largo del carril
    y1 = auto1.posicion[2]
    y2 = auto2.posicion[2]
    l1 = auto1.largo
    l2 = auto2.largo
    if auto1 == auto2
        
        sep = L - l1
        
    else
        if (y2+l2/2) > y1 > (y2-l2/2)
            
            sep = 0
        end
        if (y1+l1/2) > y2 > (y1-l1/2)
            
            sep = 0
        end
  
        if y1 > y2
            

            sep = L - (y1 + l1/2) + (y2 - l2/2)
        else
            sep = (y2 - l2/2) - (y1 + l1/2)
        end
    end
    
    return abs(sep)
end

"""identifica cual es el indice de auto de adelante de cada fantasma en un carril y lo acomoda en un arreglo"""

function identifica_adelante(carril_1,fantasmas_1)
    indice_enfrente = zeros(Int,length(fantasmas_1))
        
    n = length(carril_1)
    

    for i in 1:n
        if i == 1
            j = carril_1[i]
            #k es el indice del carro del frente
            k = carril_1[n]
        else
            j = carril_1[i]
            k = carril_1[i-1]
        end
        
        
        
     indice_enfrente[Int(j)] =  Int(k)
    end 
    return indice_enfrente
    
end
    

""" calcula la separacion de los carros fantasmas de cada carril """

function separaciones_por_carriles(carril_1,fantasmas_1,L)
    
    sep_fantasmas_1 = zeros(length(fantasmas_1))
        
    n = length(carril_1)        
    for i in 1:n
        if i == 1
            j = carril_1[i]
            #k es el indice del carro del frente
            k = carril_1[n]
        else
            j = carril_1[i]
            k = carril_1[i-1]
        end
        j = Int(j)
        k = Int(k)
        
     sep_fantasmas_1[j] =  separacion_dos_autos(fantasmas_1[j],fantasmas_1[k],L)
    end  
    
    return sep_fantasmas_1
end

""" calcula la separaciones de los fantasmas  de los dos carriles """

function separaciones_por_carriles_dos(carril_1, carril_2,fantasmas_1,fantasmas_2,L)
    
    
    sep_fantasmas_1 = separaciones_por_carriles(carril_1,fantasmas_1,L)
    
    sep_fantasmas_2 = separaciones_por_carriles(carril_2,fantasmas_2,L)
    
    return sep_fantasmas_1,sep_fantasmas_2
end

""" calcula la velocidad segura del auto que le corresponde con el del frente"""

function condicion_precambio_velocidad_fantasmas(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,acel,fantasmas_1,j,k;v_error = 1e-7)
    y_j = fantasmas_1[j].velocidad[2]
    y_k = fantasmas_1[k].velocidad[2]
    l_j = fantasmas_1[j].largo
    l_k = fantasmas_1[k].largo
    
    if (y_k+l_k/2) > y_j > (y_k-l_k/2)
        
        fantasmas_1[j].velocidad[2] = 0
        fantasmas_1[j].velocidad[1] = 0
    end
    if (y_j+l_j/2) > y_k > (y_j-l_j/2)
        
        fantasmas_1[j].velocidad[2] = 0
        fantasmas_1[j].velocidad[1] = 0
    end
    fantasmas_1[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,fantasmas_1[k].velocidad[2],v_1,sep_fantasmas_1[j],colchon,acel)
    
end

""" funcion auxiliar para el limite superior de la velocidad """
function condicion_cambio_velocidad_limite_superior_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_max;a_realista_max = 4, a_realista_min = -10)
    

    a_max = aceleracion(δt ,d_0,α,μ,g,T_reac,fantasmas_1[k].velocidad[2],v_1,sep_fantasmas_1[j],colchon,v_max)
    if a_max > a_realista_max
        a_max = a_realista_max
    elseif a_max < a_realista_min
        a_max = a_realista_min
    end
    
    fantasmas_1[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,fantasmas_1[k].velocidad[2],v_1,sep_fantasmas_1[j],colchon,a_max)
 
end

""" funcion auxiliar para el limite inferior de la velocidad """
function condicion_cambio_velocidad_limite_inferior_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_min;a_realista_max = 4, a_realista_min = -10)
    
    a_min = aceleracion(δt ,d_0,α,μ,g,T_reac,fantasmas_1[k].velocidad[2],v_1,sep_fantasmas_1[j],colchon,v_min)
    
    if a_min > a_realista_max
        a_min = a_realista_max
    elseif a_min < a_realista_min
        a_min = a_realista_min
    end
    
    fantasmas_1[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,fantasmas_1[k].velocidad[2],v_1,sep_fantasmas_1[j],colchon,a_min)

    
end


""" Dado la velocidad pre actualizada del carro vemos si esta es negativa o supera el limite de velocidad dependiendo el caso cambiamos una nueva velocidad que se adapte a las reglas establecidas si no se queda igual a la pre actualizada"""

function cond_vel_sup_in_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_max,v_min)
    if fantasmas_1[j].velocidad[2] > v_max
            
        condicion_cambio_velocidad_limite_superior_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_max)
        if fantasmas_1[j].velocidad[2] > v_max
            fantasmas_1[j].velocidad[2] = v_max
        end
            
    elseif fantasmas_1[j].velocidad[2] < 0
            
        condicion_cambio_velocidad_limite_inferior_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_min)
                
    end
end


""" funcion que actualiza la velocidad del fantasma en un carril """

function actualiza_velocidad_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_max,v_min,acel)
    
    #v_1 = fantasmas_1[j].velocidad[2]
    
    condicion_precambio_velocidad_fantasmas(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,acel,fantasmas_1,j,k)
    cond_vel_sup_in_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas_1,colchon,fantasmas_1,j,k,v_max,v_min)
    
    
end

""" actualiza la velocidad fantasma solo los que son relevantes en su carril """

function velocidad_todos_fantasmas(carril,fantasmas,sep_fantasmas,δt,d_0,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    indice_enfrente = identifica_adelante(carril,fantasmas)
    
    for i in 1:length(fantasmas)
        
        k = indice_enfrente[i]
        
        if k != 0 
            v_1 = fantasmas[i].velocidad[2]
            
            actualiza_velocidad_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas,colchon,fantasmas,i,k,v_max,v_min,acel)
            
        end
        
    end
    
end
""" actualiza la velocidad para los fantasmas en los dos carriles """

function velocidad_fantasmas_dos_carriles(carril_1,fantasmas_1,carril_2,fantasmas_2,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
    sep_fantasmas_1,sep_fantasmas_2 = separaciones_por_carriles_dos(carril_1, carril_2,fantasmas_1,fantasmas_2,L)
    
    velocidad_todos_fantasmas(carril_1,fantasmas_1,sep_fantasmas_1,δt,d_0_1,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
    velocidad_todos_fantasmas(carril_2,fantasmas_2,sep_fantasmas_2,δt,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
end

function velocidad_carros_dos_carriles(carros,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
    carriless = carriles(1,2)
    en_carril = carros_i_carriles(carros,carriless)
    fantasmas_1, fantasmas_2 = listas_carros_fantasmas(carros)
    carril_1, carril_2 = ordenar_carriles(carros, en_carril)
    
    velocidad_fantasmas_dos_carriles(carril_1,fantasmas_1,carril_2,fantasmas_2,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
    return fantasmas_1, fantasmas_2
end
    


