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
    if k == 0
        return false
    end
    
    if giro_nogiro[k] == 1
        return true
    end
    return false
end

function condicion_giro_enfrente!(i,indice_enfrente_1,indice_enfrente_2,giro_nogiro)


    if condicion_giro_enfrente(i,indice_enfrente_1,giro_nogiro) || condicion_giro_enfrente(i,indice_enfrente_2,giro_nogiro)
        return true
    end
    
    return false
end

""" funcion que implementa la condicion de egoismo de los conductores egoismo """

function egoismo_velocidad(a::Auto,egoismo,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,acel,colchon)
    
    pasos =  tc/δt
    lista_carril2_copia = copiar_lista_autos_rapida(lista_carril2)
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


""" encuentra los n_carril1, n_carril2 a partir del numero total de carros que se le da y te dice si no es posible acmodar en los dos carriles de tamaño L"""
function distribucion_optima_carros(n_total::Int, d_0::Float64, largo_carro::Float64, ancho_carro::Float64, L::Float64)
    # Calcular cuántos carros caben en un carril
    espacio_por_carro = largo_carro + d_0
    max_por_carril = floor(Int, L / espacio_por_carro)
    
    # Intentar distribuir en dos carriles
    if n_total <= max_por_carril
        # Todos caben en un solo carril
        n_carril1 = n_total
        n_carril2 = 0
        sobrantes = 0
        L_sugerido = L
        
    elseif n_total <= 2 * max_por_carril
        # Distribuir entre ambos carriles
        n_carril1 = min(n_total, max_por_carril)
        n_carril2 = n_total - n_carril1
        sobrantes = 0
        L_sugerido = L
        
    else
        # No caben todos, calcular L óptimo
        n_carril1 = max_por_carril
        n_carril2 = max_por_carril
        sobrantes = n_total - 2 * max_por_carril
        
        # Calcular L necesario para los sobrantes
        L_necesario = (n_total * espacio_por_carro) / 2
        L_sugerido = ceil(L_necesario)  # Redondear hacia arriba
    end
    
    # Ajustar para que no cambie mucho L (máximo 1-2 unidades)
    if L_sugerido > L + 2
        L_sugerido = L + 2
        # Recalcular con L ajustado
        max_por_carril_ajustado = floor(Int, L_sugerido / espacio_por_carro)
        n_carril1 = min(n_total, max_por_carril_ajustado)
        n_carril2 = min(n_total - n_carril1, max_por_carril_ajustado)
        sobrantes = n_total - n_carril1 - n_carril2
    end
    
    return n_carril1, n_carril2, sobrantes, L_sugerido
end


""" Distribuye el numero total de carros que se le da en dos carriles y te cre un array con estos ya acomodaos (te dice si no es posible acmodar en los dos carriles de tamaño L si no te sugiere un nuevo L)"""
function generar_distribucion_automatica(n_total::Int, d_0::Float64, largo_carro::Float64, ancho_carro::Float64, L::Float64)
    # Calcular distribución óptima
    n_carril1, n_carril2, sobrantes, L_optimo = distribucion_optima_carros(n_total, d_0, largo_carro, ancho_carro, L)
    
    println("Distribución para n=$n_total, L=$L:")
    println("• Carril 1: $n_carril1 carros")
    println("• Carril 2: $n_carril2 carros")
    println("• Sobrantes: $sobrantes carros")
    println("• L sugerido: $L_optimo")
    
    if sobrantes > 0
        println("⚠️  No caben todos los carros. Considera usar L ≥ $L_optimo")
    end
    
    # Generar los carros 
    carros = carros_dos_carriles(ancho_carro, largo_carro, L, d_0, d_0, n_carril1, n_carril2; xs=1/2)
    
    return carros,n_carril1,n_carril2
end

""" encuentra los n_carril1, partir del numero total de carros que se le da y te dice si no es posible acmodar en el carril de tamaño L"""
function acomodar_un_carril(n_total::Int, d_0::Float64, largo_carro::Float64, L::Float64)
    # Calcular cuántos carros caben en el carril
    espacio_por_carro = largo_carro + d_0
    max_carros = floor(Int, L / espacio_por_carro)
    
    # Verificar si caben todos
    if n_total <= max_carros
        carros_acomodados = n_total
        sobrantes = 0
        L_sugerido = L
    else
        carros_acomodados = max_carros
        sobrantes = n_total - max_carros
        # Calcular L necesario para todos los carros
        L_sugerido = n_total * espacio_por_carro
    end
    
    return carros_acomodados, sobrantes, L_sugerido
end

""" Distribuye el numero total de carros que se le da en un carril y te crea un array con estos ya acomodados (te dice si no es posible acmodar en el carril de tamaño L si no te sugiere un nuevo L optimo)"""
function generar_carril_unico(ancho::Float64, largo::Float64, L::Float64, d_0::Float64, n_total::Int; xs=1/2)
    # Calcular cuántos carros caben
    n_acomodados, sobrantes, L_optimo = acomodar_un_carril(n_total, d_0, largo, L)
    
    println("Acomodo para $n_total carros en L=$L:")
    println("• Carros acomodados: $n_acomodados")
    println("• Carros sobrantes: $sobrantes")
    println("• L óptimo: $L_optimo")
    
    if sobrantes > 0
        println("⚠️  No caben todos los carros. Usar L ≥ $L_optimo")
        # Usar L óptimo para acomodar todos
        return carros(ancho, largo, L_optimo, d_0, n_total; xs=xs), n_total, L_optimo
    else
        # Usar L original
        return carros(ancho, largo, L, d_0, n_acomodados; xs=xs), n_acomodados, L
    end
end