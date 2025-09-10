"""
Calcula Δθ el movimiento es decir tres puntos que recorrera la esquina del auto sobre la cicunferencia y otros tres puntos de la circunferencia que hace el centro (caso izquierdo)
"""

function Δθ_izquierda(a::Auto,δt,θ1)
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,50*δt,θ1)
    c = copia_auto_rapida(b)
    velocidad_angular_carro_correcion!(c,50*δt,θ1)
    d = copia_auto_rapida(c)
    velocidad_angular_carro_correcion!(d,50*δt,θ1)
    X = [b.esquinas[1],c.esquinas[1],d.esquinas[1]]
    Y = [b.posicion,c.posicion,d.posicion]
    
    return X,Y
    
end

"""
la siguiente funcion calculara el tiempo de interseccion de la esquina del carril con la separacion de carriles
"""

function posicion_tiempo_fantasma_izquierda(a::Auto,δt,θ1)
    
    x0 = a.esquinas[1][1]
    y0 = a.esquinas[1][2]
    x01 = a.posicion[1]
    y01 = a.posicion[2]
    v = norm(a.velocidad)
    X,Y = Δθ_izquierda(a,δt,θ1)
    circunferncia_esquina, circunferencia_centro = calcula_circunferencias(X,Y)
    h,k,r = circunferncia_esquina
    h1,k1,r1 = circunferencia_centro
    yc = calcula_interseccion(h,k,r;d=1)
    tc = tiempo_interseccion(x0,y0,1,yc,r,h,k,v,δt)
    
    yc1 = calcula_interseccion(h1,k1,r1;d=1/2)
    tc1 = tiempo_interseccion(x01,y01,1/2,yc1,r1,h1,k1,v,δt)
    
    yc_verdadero,tc_verdadero = calcula_interseccion_verdadero(tc,δt,v,h,k,x0,y0,r)
    yc_de_cambio, t_de_cambio = calcula_interseccion_verdadero(tc1,δt,v,h1,k1,x01,y01,r1)
    
    return yc_verdadero,tc_verdadero, t_de_cambio
    
end

"""
funcion que encuentra que dado la posicion predictiva nos devulve si es posible pasarse al otro carril, si los autos fantasmas no estan encimados
    
"""


function encuentra_vecinos_fantasma_izquierda(a::Auto,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    y1 = a.esquinas[1][2]
    arr = [lista_carril2[i].posicion[2] for i in 1:length(lista_carril2)]
    a,b = numeros_cercanos(arr, y1)
    i = encontrar_posicion(arr, a)
    j = encontrar_posicion(arr, b)
    test = fantasmas_encimados_test(yc,tc,δt,lista_carril2,i,j,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    return test,i,j
end
        

"""
Nos devuelve true si el auto les posible cambiarse de carril (del izquierdo al derecho), nos devuelve falso si no es posible
"""
    
function decide_cambiar_izquierda(a::Auto,lista_carril2,θ1,egoismo,δt,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if a.velocidad[2] <= v_min
        return false
    end
    
    #yc,tc, t_de_cambio = posicion_tiempo_fantasma_izquierda(a,δt,θ1)
    
    prepasos = 1 #ceil(T_reac / δt)
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,prepasos*δt,0)
    yc,tc = b.esquinas[1][2], prepasos*δt  
    
    test,i,j = encuentra_vecinos_fantasma_izquierda(a,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        
    if test
        return false
    end
    
    test2 = distancias_segura_ij(a,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,colchon)
        
    if  test2
        return false
    end
        
    test3 = egoismo_velocidad(a,egoismo,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,acel,colchon)
        
    if test3
        return false
    end
    
    return true
    
end
                
    
    