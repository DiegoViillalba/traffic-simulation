""" Nos crea un arreglo de [n, n+m,n-1,n+m-1 ..., 1, n+1]"""
function generar_indices_alternados(n, m)
    indices = Int[]
    total = n + m
    
    # Índices del primer segmento en orden descendente
    segmento1 = n:-1:1
    
    # Índices del segundo segmento en orden descendente
    segmento2 = (n+m):-1:(n+1)
    
    # Alternar entre segmentos hasta que ambos se acaben
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
""" Nos crea un arreglo de [1, n+1, 2, n+2, ..., n, n+m]"""
function indices_alternados_contrario(n, m)
    indices = Int[]
    
    for i in 1:max(n, m)
        if i <= n
            push!(indices, i)  # Del primer segmento
        end
        if i <= m
            push!(indices, n + i)  # Del segundo segmento
        end
    end
    
    return indices
end

""" funcion que nos dice que si el carro de enfrente esta girando entonces debemos esperara que termine de girar,para poder girar el auto """
function condicion_giro_enfrente(i,indice_enfrente_1,giro_nogiro)
    k = indice_enfrente_1[i]
    if giro_nogiro[k] == 1
        return true
    end
    return false
end

""" funcion que implementa la condicion de egoismo de los conductores egoismo """

function egoismo_velocidad(a::Auto,egoismo,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,acel,colchon)
    
    pasos =  tc/δt
    lista_carril2_copia = deepcopy(lista_carril2)
    if yc > L
        y = floor(yc/L)
        yc = yc - y*L
    end
   
    avance_un_carril(lista_carril2_copia,pasos,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    fantasma =  Auto(a.ancho,0,[lista_carril2_copia[j].posicion[1],yc],1,a.velocidad)
    d_j = separacion_dos_autos(lista_carril2_copia[j],fantasma,L)
    v_0 = lista_carril2_copia[j].velocidad[2]
    
    
    v = v_i(δt ,d_0,α,μ,g,T_reac,v_0,fantasma.velocidad[2],d_j,colchon,acel)
    
    v_porcentaje = v/v_0
    
    if 1 - egoismo > v_porcentaje
        return true
    end
    return false
end
    


