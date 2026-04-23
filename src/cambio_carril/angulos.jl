""" funcion que nos dice si el carro de enfrente está girando (debemos esperar) """
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

""" Da un arreglo de las posiciones en y de una lista de autos """
function posicion_y(Autos)
    return [Autos[i].posicion[2] for i in 1:length(Autos)]
end

"""Calcula el ángulo necesario para alcanzar la dirección [0,1] """
function angulo_mas_corto_hacia_arriba(v_normalizado)
    objetivo = [0.0, 1.0]
    cosθ = v_normalizado[1] * objetivo[1] + v_normalizado[2] * objetivo[2]
    cosθ = cosθ > 1.0 ? 1.0 : (cosθ < -1.0 ? -1.0 : cosθ)
    θ = acos(cosθ)
    θ_corto = θ ≤ π/2 ? θ : π - θ
    return θ_corto
end

"""Rota el auto hacia [0,1] (recto) """
function rotacion_carro_recto!(θ ,a::Auto;err = 1e-5)
    if a.direccion[1]<0
        θ = -abs(θ)
    end
    T = [cos(θ) -sin(θ);sin(θ) cos(θ)]
        for i in 1:4
            x_nuevo = a.esquinas[i] - a.posicion
            x_nuevo = T*x_nuevo
            a.esquinas[i] = x_nuevo + a.posicion
        end
        a.direccion = T*a.direccion
    return a
end

""" corrección de dirección del auto """
function direccion_correcion(a::Auto;err = 1e-6)
    test1,test2 = false,false
    if abs(a.direccion[1]) < err
        test1 = true
    end
    if abs(1 - a.direccion[2]) < err 
        test2 = true
    end
    return test1,test2
end

"""crea un arreglo: true si el auto está girando, false si no"""
function comprobacion_giro(Autos;err = 1e-6)
    giro_nogiro = zeros(length(Autos))
    for i in 1:length(Autos)
        test1,test2 = direccion_correcion(Autos[i];err)
        if test1 == false && test2 == false
            giro_nogiro[i] = true
        end
    end
    return giro_nogiro
end

"""Crea un arreglo: true si el auto tiene velocidad, false si está parado"""
function comprobacion_velocidad(Autos)
    vel = zeros(length(Autos))
    for i in 1:length(Autos)
        if norm(Autos[i].velocidad) != 0
            vel[i] = true
        end
    end
    return vel
end

""" corrige el ángulo de giro θ para no salirse de los carriles (derecha a izquierda) """
function Angulo_giro_correcion_1(Auto,θ,carriles1;error = 1e-2)
    if abs(Auto.posicion[1] - (carriles1[1].inicio_fin[2]-1/2)) < error
        θ_correcion = angulo_mas_corto_hacia_arriba(Auto.direccion)
        rotacion_carro_recto!(θ_correcion ,Auto)
        direccion_correcion(Auto;err = 1e-7)
        θ = 0
    else
        if  carriles1[1].inicio_fin[2] - sum(Auto.esquinas[1:2])[1]/2 > 0
            θ = -abs(θ)
        elseif carriles1[1].inicio_fin[2] - sum(Auto.esquinas[1:2])[1]/2 < 0 
            θ = abs(θ)
        end
    end
    return θ
end

""" corrige el ángulo de giro θ para no salirse de los carriles (izquierda a derecha) """
function Angulo_giro_correcion_2(Auto,θ,carriles1;error =1e-2)
    if abs(Auto.posicion[1] - (carriles1[1].inicio_fin[2]+1/2)) < error
        θ_correcion = angulo_mas_corto_hacia_arriba(Auto.direccion)
        rotacion_carro_recto!(θ_correcion ,Auto)
        direccion_correcion(Auto;err = 1e-7)
        θ = 0
    else
        if  carriles1[1].inicio_fin[2] - sum(Auto.esquinas[1:2])[1]/2 > 0
            θ = -abs(θ)
        elseif carriles1[1].inicio_fin[2] - sum(Auto.esquinas[1:2])[1]/2 < 0 
            θ = abs(θ)
        end
    end
    return θ
end

""" corrige el ángulo de giro θ para no salirse de los carriles """
function Angulo_giro_correcion(Auto,θ,test,carriles1;error = 1e-2)
    if test == false
        θ =  Angulo_giro_correcion_2(Auto,θ,carriles1;error)
    else
        θ =  Angulo_giro_correcion_1(Auto,θ,carriles1;error)
    end
    return θ
end

""" Crea arreglo del carril original de cada auto (false=izquierda, true=derecha) """
function carril_original(Autos,en_carril)
    carriles_original = zeros(length(Autos))
    for i in 1:length(Autos)
        if en_carril[i][2] == true
            carriles_original[i] = false
        end
        if en_carril[i][3] == true
            carriles_original[i] = true
        end
    end
    return carriles_original
end

""" Actualiza carriles_original cuando un auto completa un cambio de carril """
function cambio_de_carril_original(giro_nogiro,carriles_original,en_carril)
    for i in 1:length(giro_nogiro)
        if en_carril[i][2] == false && en_carril[i][3] == true && carriles_original[i] == 0 && giro_nogiro[i] == false
            carriles_original[i]  = 1
        elseif en_carril[i][2] == true && en_carril[i][3] == false && carriles_original[i] == 1 && giro_nogiro[i] == false
            carriles_original[i] = 0
        end
    end
    return carriles_original
end

""" Aplica condición de frontera periódica al auto (lo regresa si supera L) """
function limites_auto_carril(vocho::Auto,L)
    if vocho.posicion[2]>L
        desplazamiento = -L
        vocho.posicion = [vocho.posicion[1], vocho.posicion[2] + desplazamiento]
        for i in 1:4
            vocho.esquinas[i] = [vocho.esquinas[i][1], vocho.esquinas[i][2] + desplazamiento]
        end
    end
end

function limites_auto_carril!(vocho::Auto,L)
    if vocho.posicion[2]>L
        desplazamiento = -L
        vocho.posicion = [vocho.posicion[1], vocho.posicion[2] + desplazamiento]
        for i in 1:4
            vocho.esquinas[i] = [vocho.esquinas[i][1], vocho.esquinas[i][2] + desplazamiento]
        end
        return true
    end
    return false
end

""" actualiza la velocidad del fantasma i con velocidad segura """
function velocidad_un_fantasmas(carril,fantasmas,sep_fantasmas,i,indice_enfrente,δt,d_0,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    k = indice_enfrente[i]
    if k != 0 
        v_1 = fantasmas[i].velocidad[2]
        actualiza_velocidad_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas,colchon,fantasmas,i,k,v_max,v_min,acel)
    end
end

""" Si el auto no tiene velocidad, hace que avance con condiciones seguras """
function condicion_vel_cero(vehiculos,θ_vec,i,fantasmas_1, fantasmas_2,indice_enfrente_1,indice_enfrente_2,en_carril,carril_1,sep_fantasmas_1,carril_2,sep_fantasmas_2,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    velocidad_un_fantasmas(carril_1,fantasmas_1,sep_fantasmas_1,i,indice_enfrente_1,δt,d_0_1,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    velocidad_un_fantasmas(carril_2,fantasmas_2,sep_fantasmas_2,i,indice_enfrente_2,δt,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    escoje_velocidad_real(vehiculos,fantasmas_1, fantasmas_2,en_carril,i)
    velocidad_angular_carro_correcion!(vehiculos[i],δt,θ_vec[i])
    limites_auto_carril(vehiculos[i],L)
end

""" velocidad promedio en Y con corrección para lista vacía """
function velocidad_promedio_y_correcion(Autos,v_max)
    if Autos == []
        return v_max
    end
    v = zeros(length(Autos))
    for i in 1:length(Autos)
        v[i] = Autos[i].velocidad[2]
    end
    return sum(v)/length(Autos)    
end

""" escoge la velocidad real del carro dado las dos velocidades de los fantasmas (con giro) """
function escoje_velocidad_real!(carros,fantasmas_1, fantasmas_2,giro_nogiro,en_carril,i)
    v1 = fantasmas_1[i].velocidad[2]
    v2 = fantasmas_2[i].velocidad[2]
    if giro_nogiro[i] == true 
        carros[i].velocidad[2] = min(v1,v2)
    else
        if en_carril[i][2] == true && en_carril[i][3] == false
            carros[i].velocidad[2] = v1
        elseif en_carril[i][2] == false && en_carril[i][3] == true 
            carros[i].velocidad[2] = v2
        end
    end
end

""" ordena carriles con corrección para autos en giro """
function ordenar_carriles!(carros, en_carril,giro_nogiro)
    n = length(carros)
    carril_1 = Int[]
    carril_2 = Int[]
    sizehint!(carril_1, n)
    sizehint!(carril_2, n)
    posiciones_y = Vector{Float64}(undef, n)
    for i in 1:n
        posiciones_y[i] = carros[i].posicion[2]
    end
    for i in 1:n
        if giro_nogiro[i] == true
            push!(carril_1, i)
            push!(carril_2, i)
        else
            en_carril[i][2] && push!(carril_1, i)
            en_carril[i][3] && push!(carril_2, i)
        end
    end
    sort!(carril_1, by=i -> -posiciones_y[i])
    sort!(carril_2, by=i -> -posiciones_y[i])
    return carril_1, carril_2
end

""" da arreglos de fantasmas relevantes para el cambio de carril (con estado de giro) """
function listas_pregiro!(fantasmas_1,fantasmas_2,en_carril,giro_nogiro)
    n = Int(floor(1/2*length(fantasmas_1)))
    lista_carril1 = Auto[]
    lista_carril2 = Auto[]
    sizehint!(lista_carril1, n)
    sizehint!(lista_carril2, n)
    for i in 1:length(fantasmas_1)
        if giro_nogiro[i] == true
            push!(lista_carril1,  fantasmas_1[i])
            push!(lista_carril2, fantasmas_2[i])
        else
            if en_carril[i][2] == true
                push!(lista_carril1, fantasmas_1[i])
            end
            if en_carril[i][3] == true
                push!(lista_carril2, fantasmas_2[i])
            end
        end
    end
    return lista_carril1,lista_carril2
end

""" actualiza si el carro está girando o no """
function actualiza_comprobacion_giro(Autos,giro_nogiro,i;err= 1e-6)
    test1,test2 = direccion_correcion(Autos[i];err)
    if test1 == true && test2 == true
        giro_nogiro[i] = false
    else
        giro_nogiro[i] = true
    end
end

""" actualiza el carril original del auto """
function actualiza_cambio_de_carril_original(giro_nogiro,carriles_original,en_carril,i)
    if en_carril[i][2] == false && en_carril[i][3] == true && carriles_original[i] == 0 && giro_nogiro[i] == false
        carriles_original[i]  = 1
    elseif en_carril[i][2] == true && en_carril[i][3] == false && carriles_original[i] == 1 && giro_nogiro[i] == false
        carriles_original[i] = 0
    end
end
