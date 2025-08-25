""" funcion que nos da arreglos de los fantasmas que son relvantes pra el cambio de carril """
function listas_pregiro(fantasmas_1,fantasmas_2,en_carril)
    
    
        
    #DERECHA
        lista_carril2 = Auto[]
    #IZQUIERDA
    
        lista_carril1 = Auto[]
    
    for i in 1:length(fantasmas_1)
        
        if en_carril[i][2] == true
            
            push!(lista_carril1, deepcopy(fantasmas_1[i]))
        end
            
        if en_carril[i][3] == true
                
            push!(lista_carril2, deepcopy(fantasmas_2[i]))
                    
        end
        
        
    end
    
    return lista_carril1,lista_carril2
    
end


""" Da un arreglo de las posicion en y de una lista de autos """
function posicion_y(Autos)
    return [Autos[i].posicion[2] for i in 1:length(Autos)]
end

"""Calcula el el angulo necesario para alcanzar la direccion [0,1] """
function angulo_mas_corto_hacia_arriba(v_normalizado)
    objetivo = [0.0, 1.0]
    
    # Calcular producto punto manualmente
    cosθ = v_normalizado[1] * objetivo[1] + v_normalizado[2] * objetivo[2]
    
    # Asegurar que cosθ ∈ [-1, 1] (por estabilidad numérica)
    cosθ = cosθ > 1.0 ? 1.0 : (cosθ < -1.0 ? -1.0 : cosθ)
    
    # Calcular el ángulo en radianes
    θ = acos(cosθ)
    
    # Determinar el ángulo más corto (≤ π/2)
    θ_corto = θ ≤ π/2 ? θ : π - θ
    
    return θ_corto
end

"""Calcula el el angulo necesario para alcanzar la direccion [0,1] """
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

""" correcion de direccion del auto"""
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



"""crea un arreglo correspondiente a los autos, si estos estan girando su valor corresponsiente es true si no esta girando sera false"""
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
    
"""Crea un arreglo para ver si los autos tienen velocidad, si estos estan parados su valor correspondiente sera false si estan avanzando sera true"""

function comprobacion_velocidad(Autos)
        vel = zeros(length(Autos))
    
    for i in 1:length(Autos)
        
        if norm(Autos[i].velocidad) != 0
            vel[i] = true
        end
        
    end
    
    return vel
end

""" corrige el angulo de giro theta del auto para no salirse de los carriles version derecha a izquierda"""
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

""" corrige el angulo de giro theta del auto para no salirse de los carriles version izquierda a derecha"""

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

""" corrige el angulo de giro theta del auto para no salirse de los carriles"""

function Angulo_giro_correcion(Auto,θ,test,carriles1;error = 1e-2)
    #giro de izquierda a derecha
    if test == false
        
        θ =  Angulo_giro_correcion_2(Auto,θ,carriles1;error)
    #giro de derecha a izquierda
    else
        θ =  Angulo_giro_correcion_1(Auto,θ,carriles1;error)
    end
    
    return θ
    
end

""" Crea un arreglo que nos dice cual es el carril original del que viene el auto, asigna false si viene de la izquierda, asigna true si viene de la derecha """
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

""" Crea un arreglo que nos dice cual es el carril nuevo al que el auto cambia , asigna false si viene de la derecha, asigna true si viene de la izquierda """

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


""" Regresa el auto si se pasa de una distancia L (largo del carril)"""

function limites_auto_carril(vocho::Auto,L)
    
 if vocho.posicion[2]>L
            vocho.posicion[2] = vocho.posicion[2] - L
            vocho.esquinas[1] = [vocho.esquinas[1][1],vocho.esquinas[1][2] - L ]
            vocho.esquinas[2] = [vocho.esquinas[2][1],vocho.esquinas[2][2] - L ]
            vocho.esquinas[3] = [vocho.esquinas[3][1],vocho.esquinas[3][2] - L ]
            vocho.esquinas[4] = [vocho.esquinas[4][1],vocho.esquinas[4][2] - L ]
    end
    
end


""" actualiza la velocidad del fantasma i, con velocidad segura """
function velocidad_un_fantasmas(carril,fantasmas,sep_fantasmas,i,indice_enfrente,δt,d_0,α,μ,g,T_reac,colchon,v_max,v_min,acel)
        
        k = indice_enfrente[i]
        
        if k != 0 
            v_1 = fantasmas[i].velocidad[2]
            
            actualiza_velocidad_f(δt,d_0,α,μ,g,T_reac,v_1,sep_fantasmas,colchon,fantasmas,i,k,v_max,v_min,acel)
            
        end
        
    
end

""" Si el auto no tiene velocidad, entonces la funcion hace que avance con una velocidad calculada con las condiciones seguras """

function condicion_vel_cero(vehiculos,θ_vec,i,fantasmas_1, fantasmas_2,indice_enfrente_1,indice_enfrente_2,en_carril,carril_1,sep_fantasmas_1,carril_2,sep_fantasmas_2,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    
    velocidad_un_fantasmas(carril_1,fantasmas_1,sep_fantasmas_1,i,indice_enfrente_1,δt,d_0_1,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    velocidad_un_fantasmas(carril_2,fantasmas_2,sep_fantasmas_2,i,indice_enfrente_2,δt,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
 escoje_velocidad_real(vehiculos,fantasmas_1, fantasmas_2,en_carril,i)
 velocidad_angular_carro_correcion!(vehiculos[i],δt,θ_vec[i])
 limites_auto_carril(vehiculos[i],L)
    
end
    
    
""" nos sive para calcular la velocidad promedio de un arreglo de autos en direccion "y" ala correcion que se le hace es para que el codigo no se rompa cuando Autos == []"""
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



    
    