using LinearAlgebra
"""
Calcula Δθ el movimiento es decir tres puntos que recorrera la esquina del auto sobre la cicunferencia y otros tres puntos de la circunferencia que hace el centro
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
Calcula el centro de la circunferencia dado tres puntos pertenecientes a ella
"""
function calcular_centro_circunferencia(p1,p2,p3)
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3

    # Matriz para verificar colinealidad
    A = [x1 y1 1;
         x2 y2 1;
         x3 y3 1]
    
    D = det(A)
    
    if isapprox(D, 0, atol=1e-10)
        error("Los puntos son colineales.")
    end

    # Matrices para calcular h, k y F (no C)
    A1 = [x1^2 + y1^2 y1 1;
          x2^2 + y2^2 y2 1;
          x3^2 + y3^2 y3 1]
    
    A2 = [x1^2 + y1^2 x1 1;
          x2^2 + y2^2 x2 1;
          x3^2 + y3^2 x3 1]
    
    A3 = [x1^2 + y1^2 x1 y1;
          x2^2 + y2^2 x2 y2;
          x3^2 + y3^2 x3 y3]
    
    Dx = det(A1)
    Dy = -det(A2)  # Signo corregido
    F = det(A3)    # No se niega

    h = Dx / (2D)
    k = Dy / (2D)
    r = sqrt(h^2 + k^2 - F/D)  # Usamos F en lugar de C

    return (h, k, r)
end

function circunferencia_vertical(p1, p2, p3)
    # Ordena por coordenada y
    puntos = sort([p1, p2, p3], by=p -> p[2])
    A, B, C = puntos
    
    # Centro aproximado (x promedio, y medio entre A y C)
    h = (A[1] + B[1] + C[1]) / 3
    k = (A[2] + C[2]) / 2
    
    # Radio (distancia máxima al centro)
    r = maximum([norm([h, k] - p) for p in puntos])
    return h, k, r
end

function calcular_centro_y_radio(p1, p2, p3; atol=1e-9)
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3

    # --- Verificación de colinealidad mejorada ---
    # Usamos el área del triángulo formado por los puntos (más estable numéricamente)
    area = abs((x2 - x1)*(y3 - y1) - (y2 - y1)*(x3 - x1))
    if area < atol
        error("Los puntos son colineales o están demasiado cerca para definir una circunferencia.")
    end

    # --- Cálculo del centro (h, k) ---
    # Usamos fórmulas algebraicas estables
    A = x1*(y2 - y3) - y1*(x2 - x3) + (x2*y3 - x3*y2)
    B = (x1^2 + y1^2)*(y3 - y2) + (x2^2 + y2^2)*(y1 - y3) + (x3^2 + y3^2)*(y2 - y1)
    C = (x1^2 + y1^2)*(x2 - x3) + (x2^2 + y2^2)*(x3 - x1) + (x3^2 + y3^2)*(x1 - x2)
    
    h = -B / (2*A)
    k = -C / (2*A)

    # --- Cálculo del radio ---
    r = sqrt((x1 - h)^2 + (y1 - k)^2)

    # --- Corrección para casos casi verticales ---
    # Si los puntos están casi alineados verticalmente, ajustamos numéricamente
    if abs(x1 - x2) < atol && abs(x2 - x3) < atol
        h = (x1 + x2 + x3) / 3  # Promedio de x para minimizar error
        k = (min(y1, y2, y3) + max(y1, y2, y3)) / 2  # Punto medio en y
        r = abs(max(y1, y2, y3) - min(y1, y2, y3)) / 2  # Radio como semidistancia vertical
    end

    return h, k, r
end


"""Dibuja una circunferencia"""
function dibujar_circunferencia(centro::Tuple{Float64, Float64}, radio::Float64,puntos::Int;kargs...)
    # Definir el ángulo en radianes
    θ = LinRange(0, 2π, puntos)
    
    # Calcular las coordenadas cartesianas de los puntos de la circunferencia
    x = centro[1] .+ radio .* cos.(θ)
    y = centro[2] .+ radio .* sin.(θ)
    
    # Dibujar la circunferencia
    plot(x, y, label="Circunferencia", legend=false, aspect_ratio=:equal;kargs...)
end
"""
Calcula las circunferencias de giro, la esquina derecha y el centro del auto
"""
function calcula_circunferencias(X,Y)
    h,k,r = calcular_centro_y_radio(X[1],X[2],X[3])
    h1,k1,r1 = calcular_centro_y_radio(Y[1],Y[2],Y[3])
    circunferncia_esquina = [h,k,r]
    circunferencia_centro = [h1,k1,r1]
    return circunferncia_esquina,circunferencia_centro
end

"""
Calcula la "yc" de interseccion de la circunerencia con la division de carril analiticamente
"""
function calcula_interseccion(h,k,r;d = 1)
    
    discriminante = r^2 - (d - h)^2
    
    if discriminante < 0
        error("No hay intersección: la recta x=$d no corta la circunferencia.")
    end
    
    y1 = k + sqrt(discriminante)
    y2 = k - sqrt(discriminante)
    
    # Devuelve ambas intersecciones (arriba y abajo del centro)
    return max(y1,y2)
end

"""
Calcula el tiempo de interseccion de la esquina ya sabiendo yc, es decir los pasos necesarios para avanzar a yc
"""
function tiempo_interseccion(x0,y0,x,y,r,h,k,v,δt)
    # Calcula ángulos respecto al centro (h, k)
    θ0 = atan(y0 - k, x0 - h)
    θ = atan(y - k, x - h)
    
    # Diferencia angular más corta (considera dirección horaria/antihoraria)
    Δθ = mod2pi(θ - θ0)
    Δθ = min(Δθ, 2π - Δθ)  # Toma el camino más corto
    
    # Longitud del arco = r * Δθ
    longitud_arco = r * Δθ
    
    # Tiempo continuo
    t = longitud_arco / v
    
    # Discretización (redondeo hacia arriba para asegurar llegar)
    pasos = ceil(t / δt)
    return pasos
end

"""
Calcula "yc" de interseccion de la circunferencia con la division de carril otra vez, pero basado en los pasos δt y tc
"""
function calcula_interseccion_verdadero(tc,δt,v,h,k,x0,y0,r)
    θ0 = atan(y0 - k,x0 - h)
    t = tc*δt
    θ = θ0 - t*v/r
    yc = k + r*sin(θ)
    return yc,t
end

"""
la siguiente funcion calculara el tiempo de interseccion de la esquina del carril con la separacion de carriles
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
Dado un arreglo podemos comprobar si un elemento esta en el y nos devuelve su posicion, en este caso nos interesa el indice del coche

"""

function encontrar_posicion(arr::Vector, elemento)
    posicion = findfirst(x -> x == elemento, arr)
    if posicion == nothing
        println("El elemento no se encuentra en el arreglo.")
    else
        return posicion
    end
end

"""
Dado un arreglo de numeros y un elemento (no necesariamente en el arreglo),nos dice cuales son los numeros mas cercanos a el (el mayor y menor mas proximo), si en dado caso que el elemento es el menor de todos los elementos nos devolvera como menor mas cercano al numero mas grande en dicho arreglo, y vicerversa si el numero es el mas grande nos devolvera como mayor mas proximo al numero mas chico del arreglo.
a = numero mayor cercano, b = numero menor cercano
"""

function numeros_cercanos(arr::Vector, elemento)
    # Inicializar las variables para el número mayor más cercano y el número menor más cercano
    numero_mayor_cercano = Inf
    numero_menor_cercano = -Inf

    for num in arr
        if num > elemento && num < numero_mayor_cercano
            numero_mayor_cercano = num
        end

        if num < elemento && num > numero_menor_cercano
            numero_menor_cercano = num
        end
    end

    # Verificar si se encontraron números cercanos
    if numero_mayor_cercano == Inf
        a = minimum(arr)
    else
        a = numero_mayor_cercano
    end

    if numero_menor_cercano == -Inf
        b = maximum(arr)
    else
        b = numero_menor_cercano
    end
    return a,b
end


""" 
funcion quenos dice las condiciones que deben cumplir la posicion de los tres carros relevantes para el cambio de carril
""" 
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
ya teniendo el tiempo de interseccion y yc de interseccion actualizamos la posicion de los autos cercanos con tc para ver si yc se encima con ellos
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
        
        #if yc1 < b < a
            #return true
        #end
        
        s = condiciones_tres_car(a,b,yc1,lista_carril2_copia,i,j,L)
        
    elseif yc < L
        
        s = condiciones_tres_car(a,b,yc,lista_carril2_copia,i,j,L)
        
    end
    return s
end

"""
funcion que encuentra que dado la posicion predictiva nos devuelve si es posible pasarse al otro carril, si los autos fantasmas no estan encimados
    
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
simplemnte da la distancia segura del auto dependiendo de su velocidad
"""
function distancia_segura(a::Auto,d_0,α,μ,g,T_reac;colchon = 0.2 )
    v = a.velocidad[2]
    Δx_s(d_0,α,μ,g,T_reac,v,colchon)
end


"""
    La funcion calcula si la distancia segura es sufuciente para poder cambiar el carril   
"""
function distancias_segura_ij(a::Auto,yc,tc,δt,lista_carril2,i,j,L,d_0,α,μ,g,T_reac,colchon)
    pasos =  tc/δt
    lista_carril2_copia = copiar_lista_autos_rapida(lista_carril2)
    if yc > L
        y = floor(yc/L)
        yc = yc - y*L
    end
   
    avance_un_carril(lista_carril2_copia,pasos,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    fantasma =  Auto(a.ancho,0,[lista_carril2_copia[i].posicion[1],yc],1,a.velocidad)
    
    d_segura_auto_con_i = distancia_segura(fantasma,d_0,α,μ,g,T_reac)
    d_segura_dej_con_auto = distancia_segura(lista_carril2_copia[j],d_0,α,μ,g,T_reac)
    
    d_auto = separacion_dos_autos(fantasma,lista_carril2_copia[i],L)
    
    d_j = separacion_dos_autos(lista_carril2_copia[j],fantasma,L)
    
    if d_segura_auto_con_i > d_auto #|| d_segura_dej_con_auto > d_j
        return true
    else
        return false
    end
    
end

"""
Nos devuelve true si el auto les posible cambiarse de carril (del izquierdo al derecho), nos devuelve falso si no es posible, recordar que si la velocidad inicial es cero no podra elgir ni false o true
"""
    
function decide_cambiar_derecha(a::Auto,lista_carril2,θ1,egoismo,δt,L,d_0,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    if a.velocidad[2] <= v_min
        return false
    end
    
    #yc,tc, t_de_cambio = posicion_tiempo_fantasma_derecha(a,δt,θ1)
    
    prepasos = 1 # ceil(T_reac / δt)
    b = copia_auto_rapida(a)
    velocidad_angular_carro_correcion!(b,prepasos*δt,0)
    yc,tc = b.esquinas[2][2], prepasos*δt 
    
    test,i,j = encuentra_vecinos_fantasma_derecha(a,yc,tc,δt,lista_carril2,d_0,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        
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


        