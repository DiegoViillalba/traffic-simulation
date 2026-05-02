using LinearAlgebra: norm, det

"""
Calcula Δθ: tres puntos que recorrerá la esquina derecha del auto sobre la circunferencia
y tres puntos del centro.
"""
function Δθ_derecha(a::Auto,δt,θ1)
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,50*δt,θ1)
    c = copia_auto_rapida(b)
    velocidad_angular_carro_correcion!(c,50*δt,θ1)
    d = copia_auto_rapida(c)
    velocidad_angular_carro_correcion!(d,50*δt,θ1)
    X = [b.esquinas[2],c.esquinas[2],d.esquinas[2]]
    Y = [b.posicion,c.posicion,d.posicion]
    return X,Y
end

"""
Calcula Δθ: caso izquierdo (esquina izquierda del auto)
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
Calcula el centro de la circunferencia dado tres puntos pertenecientes a ella
"""
function calcular_centro_circunferencia(p1,p2,p3)
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3
    A = [x1 y1 1; x2 y2 1; x3 y3 1]
    D = det(A)
    if isapprox(D, 0, atol=1e-10)
        error("Los puntos son colineales.")
    end
    A1 = [x1^2 + y1^2 y1 1; x2^2 + y2^2 y2 1; x3^2 + y3^2 y3 1]
    A2 = [x1^2 + y1^2 x1 1; x2^2 + y2^2 x2 1; x3^2 + y3^2 x3 1]
    A3 = [x1^2 + y1^2 x1 y1; x2^2 + y2^2 x2 y2; x3^2 + y3^2 x3 y3]
    Dx = det(A1)
    Dy = -det(A2)
    F = det(A3)
    h = Dx / (2D)
    k = Dy / (2D)
    r = sqrt(h^2 + k^2 - F/D)
    return (h, k, r)
end

function calcular_centro_y_radio(p1, p2, p3; atol=1e-9)
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3
    area = abs((x2 - x1)*(y3 - y1) - (y2 - y1)*(x3 - x1))
    if area < atol
        error("Los puntos son colineales o están demasiado cerca para definir una circunferencia.")
    end
    A = x1*(y2 - y3) - y1*(x2 - x3) + (x2*y3 - x3*y2)
    B = (x1^2 + y1^2)*(y3 - y2) + (x2^2 + y2^2)*(y1 - y3) + (x3^2 + y3^2)*(y2 - y1)
    C = (x1^2 + y1^2)*(x2 - x3) + (x2^2 + y2^2)*(x3 - x1) + (x3^2 + y3^2)*(x1 - x2)
    h = -B / (2*A)
    k = -C / (2*A)
    r = sqrt((x1 - h)^2 + (y1 - k)^2)
    if abs(x1 - x2) < atol && abs(x2 - x3) < atol
        h = (x1 + x2 + x3) / 3
        k = (min(y1, y2, y3) + max(y1, y2, y3)) / 2
        r = abs(max(y1, y2, y3) - min(y1, y2, y3)) / 2
    end
    return h, k, r
end

""" Calcula las circunferencias de giro de la esquina y el centro del auto """
function calcula_circunferencias(X,Y)
    h,k,r = calcular_centro_y_radio(X[1],X[2],X[3])
    h1,k1,r1 = calcular_centro_y_radio(Y[1],Y[2],Y[3])
    circunferncia_esquina = [h,k,r]
    circunferencia_centro = [h1,k1,r1]
    return circunferncia_esquina,circunferencia_centro
end

"""
Calcula la "yc" de intersección de la circunferencia con la división de carril analíticamente
"""
function calcula_interseccion(h,k,r;d = 1)
    discriminante = r^2 - (d - h)^2
    if discriminante < 0
        error("No hay intersección: la recta x=$d no corta la circunferencia.")
    end
    y1 = k + sqrt(discriminante)
    y2 = k - sqrt(discriminante)
    return max(y1,y2)
end

"""
Calcula el tiempo de intersección de la esquina con la separación de carriles
"""
function tiempo_interseccion(x0,y0,x,y,r,h,k,v,δt)
    θ0 = atan(y0 - k, x0 - h)
    θ = atan(y - k, x - h)
    Δθ = mod2pi(θ - θ0)
    Δθ = min(Δθ, 2π - Δθ)
    longitud_arco = r * Δθ
    t = longitud_arco / v
    pasos = ceil(t / δt)
    return pasos
end

"""
Calcula "yc" de intersección basado en pasos δt y tc
"""
function calcula_interseccion_verdadero(tc,δt,v,h,k,x0,y0,r)
    θ0 = atan(y0 - k,x0 - h)
    t = tc*δt
    θ = θ0 - t*v/r
    yc = k + r*sin(θ)
    return yc,t
end

"""
Calcula tiempo de intersección de la esquina derecha del carril con la separación
"""
function posicion_tiempo_fantasma_derecha(a::Auto,δt,θ1)
    x0 = a.esquinas[2][1]
    y0 = a.esquinas[2][2]
    x01 = a.posicion[1]
    y01 = a.posicion[2]
    v = norm(a.velocidad)
    X,Y = Δθ_derecha(a,δt,θ1)
    circunferncia_esquina, circunferencia_centro = calcula_circunferencias(X,Y)
    h,k,r = circunferncia_esquina
    h1,k1,r1 = circunferencia_centro
    yc = calcula_interseccion(h,k,r;d=1)
    tc = tiempo_interseccion(x0,y0,1,yc,r,h,k,v,δt)
    yc1 = calcula_interseccion(h1,k1,r1;d=3/2)
    tc1 = tiempo_interseccion(x01,y01,3/2,yc1,r1,h1,k1,v,δt)
    yc_verdadero,tc_verdadero = calcula_interseccion_verdadero(tc,δt,v,h,k,x0,y0,r)
    yc_de_cambio, t_de_cambio = calcula_interseccion_verdadero(tc1,δt,v,h1,k1,x01,y01,r1)
    return yc_verdadero,tc_verdadero, t_de_cambio
end

"""
Calcula tiempo de intersección de la esquina izquierda del carril
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

""" condiciones de posición para los tres carros relevantes en el cambio de carril """
function condiciones_tres_car(a,b,yc1,lista_carril2,i,j,L)
    if  b < yc1 < a
        if a - lista_carril2[i].largo/2 <= yc1 <= a || b <= yc1 <= b + lista_carril2[j].largo/2
            s = true
        else 
            s = false
        end
    elseif a < b < yc1
        if  L-lista_carril2[i].largo/2<= yc1-a <= L || b <= yc1 <= b + lista_carril2[j].largo/2
            s = true
        else 
            s = false
        end
    elseif yc1 < a < b
        if a-lista_carril2[i].largo/2 <= yc1 <= a || -L<= yc1-b <= -L+lista_carril2[j].largo/2
            s = true
        else 
            s = false
        end
    else
        s = true
    end
    return s
end

"""
Actualiza las posiciones de los autos cercanos con tc pasos y verifica si yc se encima con ellos
"""
function fantasmas_encimados_test(yc,tc,δt,lista_carril2,i,j,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    pasos =  tc/δt
    lista_carril2_copia = copiar_lista_autos_rapida(lista_carril2)
    avance_un_carril(lista_carril2_copia,pasos,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    a = lista_carril2_copia[i].posicion[2]
    b = lista_carril2_copia[j].posicion[2]
    if yc > L
        y = floor(yc/L)
        yc1 = yc - y*L
        s = condiciones_tres_car(a,b,yc1,lista_carril2_copia,i,j,L)
    elseif yc < L
        s = condiciones_tres_car(a,b,yc,lista_carril2_copia,i,j,L)
    end
    return s
end

"""
Dado la posición predictiva, devuelve si es posible pasarse al otro carril (derecha)
"""
function encuentra_vecinos_fantasma_derecha(a::Auto,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    y1 = a.esquinas[2][2]
    arr = [lista_carril2[i].posicion[2] for i in 1:length(lista_carril2)]
    a,b = numeros_cercanos(arr, y1)
    i = encontrar_posicion(arr, a)
    j = encontrar_posicion(arr, b)
    test = fantasmas_encimados_test(yc,tc,δt,lista_carril2,i,j,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    return test,i,j
end

"""
Dado la posición predictiva, devuelve si es posible pasarse al otro carril (izquierda)
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

""" da la distancia segura del auto dependiendo de su velocidad """
function distancia_segura(a::Auto,d_0,α,μ,g,T_reac;colchon = 0.2)
    v = a.velocidad[2]
    Δx_s(d_0,α,μ,g,T_reac,v,colchon)
end

"""
Calcula si las distancias seguras son suficientes para cambiar de carril
"""
function distancias_segura_ij(a::Auto,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    pasos =  tc/δt
    lista_carril2_copia = copiar_lista_autos_rapida(lista_carril2)
    if yc > L
        y = floor(yc/L)
        yc = yc - y*L
    end
    avance_un_carril(lista_carril2_copia,pasos,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    fantasma =  Auto(a.ancho,0,[lista_carril2_copia[i].posicion[1],yc],1,a.velocidad)
    d_segura_auto_con_i = distancia_segura(fantasma,d_0,α,μ,g,T_reac)
    d_auto = separacion_dos_autos(fantasma,lista_carril2_copia[i],L)
    if d_segura_auto_con_i > d_auto
        return true
    else
        return false
    end
end

"""
Devuelve true si el auto puede cambiarse al carril derecho, false si no es posible
"""
function decide_cambiar_derecha(a::Auto,lista_carril2,θ1,egoismo,δt,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if a.velocidad[2] <= v_min
        return false
    end
    prepasos = 1
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,prepasos*δt,0)
    yc,tc = b.esquinas[2][2], prepasos*δt 
    test,i,j = encuentra_vecinos_fantasma_derecha(a,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if test
        return false
    end
    test2 = distancias_segura_ij(a,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if  test2
        return false
    end
    test3 = egoismo_velocidad(a,egoismo,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,acel,colchon,v_max,v_min)
    if test3
        return false
    end
    return true
end

"""
Devuelve true si el auto puede cambiarse al carril izquierdo, false si no es posible
"""
function decide_cambiar_izquierda(a::Auto,lista_carril2,θ1,egoismo,δt,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if a.velocidad[2] <= v_min
        return false
    end
    prepasos = 1
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,prepasos*δt,0)
    yc,tc = b.esquinas[1][2], prepasos*δt
    test,i,j = encuentra_vecinos_fantasma_izquierda(a,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if test
        return false
    end
    test2 = distancias_segura_ij(a,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    if  test2
        return false
    end
    test3 = egoismo_velocidad(a,egoismo,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,acel,colchon,v_max,v_min)
    if test3
        return false
    end
    return true
end
