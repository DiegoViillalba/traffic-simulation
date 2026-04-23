"""
Implementa la condición de egoísmo de los conductores:
retorna true si el auto obliga al de detrás a frenar más de (1-egoismo)*v_0
"""
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

"""
Calcula la distribución óptima de n_total autos en dos carriles de longitud L.
Retorna (n_carril1, n_carril2, sobrantes, L_sugerido).
"""
function distribucion_optima_carros(n_total::Int, d_0::Float64, largo_carro::Float64, ancho_carro::Float64, L::Float64)
    espacio_por_carro = largo_carro + d_0
    max_por_carril = floor(Int, L / espacio_por_carro)
    if n_total <= max_por_carril
        n_carril1 = n_total
        n_carril2 = 0
        sobrantes = 0
        L_sugerido = L
    elseif n_total <= 2 * max_por_carril
        n_carril1 = min(n_total, max_por_carril)
        n_carril2 = n_total - n_carril1
        sobrantes = 0
        L_sugerido = L
    else
        n_carril1 = max_por_carril
        n_carril2 = max_por_carril
        sobrantes = n_total - 2 * max_por_carril
        L_necesario = (n_total * espacio_por_carro) / 2
        L_sugerido = ceil(L_necesario)
    end
    if L_sugerido > L + 2
        L_sugerido = L + 2
        max_por_carril_ajustado = floor(Int, L_sugerido / espacio_por_carro)
        n_carril1 = min(n_total, max_por_carril_ajustado)
        n_carril2 = min(n_total - n_carril1, max_por_carril_ajustado)
        sobrantes = n_total - n_carril1 - n_carril2
    end
    return n_carril1, n_carril2, sobrantes, L_sugerido
end

"""
Distribuye n_total autos en dos carriles y genera el arreglo de vehículos.
Imprime la distribución y avisa si no caben todos.
"""
function generar_distribucion_automatica(n_total::Int, d_0::Float64, largo_carro::Float64, ancho_carro::Float64, L::Float64)
    n_carril1, n_carril2, sobrantes, L_optimo = distribucion_optima_carros(n_total, d_0, largo_carro, ancho_carro, L)
    println("Distribución para n=$n_total, L=$L:")
    println("• Carril 1: $n_carril1 carros")
    println("• Carril 2: $n_carril2 carros")
    println("• Sobrantes: $sobrantes carros")
    println("• L sugerido: $L_optimo")
    if sobrantes > 0
        println("⚠️  No caben todos los carros. Considera usar L ≥ $L_optimo")
    end
    carros_vec = carros_dos_carriles(ancho_carro, largo_carro, L, d_0, d_0, n_carril1, n_carril2; xs=1/2)
    return carros_vec, n_carril1, n_carril2
end

"""
Calcula cuántos autos de n_total caben en un carril de longitud L.
Retorna (carros_acomodados, sobrantes, L_sugerido).
"""
function acomodar_un_carril(n_total::Int, d_0::Float64, largo_carro::Float64, L::Float64)
    espacio_por_carro = largo_carro + d_0
    max_carros = floor(Int, L / espacio_por_carro)
    if n_total <= max_carros
        carros_acomodados = n_total
        sobrantes = 0
        L_sugerido = L
    else
        carros_acomodados = max_carros
        sobrantes = n_total - max_carros
        L_sugerido = n_total * espacio_por_carro
    end
    return carros_acomodados, sobrantes, L_sugerido
end

"""
Genera un carril único con n_total autos. Si no caben, usa L óptimo.
"""
function generar_carril_unico(ancho::Float64, largo::Float64, L::Float64, d_0::Float64, n_total::Int; xs=1/2)
    n_acomodados, sobrantes, L_optimo = acomodar_un_carril(n_total, d_0, largo, L)
    println("Acomodo para $n_total carros en L=$L:")
    println("• Carros acomodados: $n_acomodados")
    println("• Carros sobrantes: $sobrantes")
    println("• L óptimo: $L_optimo")
    if sobrantes > 0
        println("⚠️  No caben todos los carros. Usar L ≥ $L_optimo")
        return carros(ancho, largo, L_optimo, d_0, n_total; xs=xs), n_total, L_optimo
    else
        return carros(ancho, largo, L, d_0, n_acomodados; xs=xs), n_acomodados, L
    end
end
