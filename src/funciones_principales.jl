"""
Funcion que calcula la sepracion de los carros que no estan en los extremos
δx=arreglo de la separacion entre el carro i y i+1
Y=arreglo que contiene solo las posiciones de los carros
l=largo del carro
i=indice de cada carro
"""
function condicion_basica_en_separacion(δx,Y,l,i)
    if Y[i+1] > Y[i]
        δx[i] =   Y[i+1] - Y[i] - l
    elseif Y[i+1] < Y[i]
        δx[i] = L - (Y[i]-Y[i+1]+l) 
    end
end

"""
Funcion que con carros de un solo carril, calcula toda las separaciones de los carros esta vez incluimos los extremos.
"""
function condiciones_en_la_separacion_1er_carril(δx,Y,l,i,n,L)
    if i == n
            if Y[1] > Y[i]
                δx[i] = Y[1] - Y[i] - l
            elseif Y[1] < Y[i]
                δx[i] = L - (Y[i]-Y[1]+l) 
            end
        else
            condicion_basica_en_separacion(δx,Y,l,i)
        end
end

"""
Funcion que en un carros distribuidos en dos carriles, calcula la separacion de los carros en el segundo carril, donde los carros en el segundo carril sus indies cumplen que n<i<=p, ya que n son los carros en el primer carril.
"""
function condiciones_en_la_separacion_2do_carril(δx,Y,l,i,n,p,L)
    if i == p
        if Y[n+1] > Y[i]
            δx[i] = Y[n+1] - Y[i] - l
        elseif Y[n+1] < Y[i]
            δx[i] = L - (Y[i]-Y[n+1]+l) 
        end
    else
        condicion_basica_en_separacion(δx,Y,l,i)
    end
end

"""
funcion que nos devuelve el arreglo con todas las sepraciones de los carros en un carril
L = longitud del carril
"""
function separacion_en_y(carros, L) 
    Y=[carros[i].posicion[2] for i in 1:length(carros)]
    l = carros[1].largo
    δx = zeros(length(carros))
    n= length(carros)
    for i in 1:length(carros)
       condiciones_en_la_separacion_1er_carril(δx,Y,l,i,n,L)
    end
    return δx
end

"""
funcion que nos devuelve el arreglo con todas las sepraciones de los carros en dos carriles
L = longitud de los dos carriles
"""
function separacion_en_y_doscarriles(carros, L,n,m) 
    
    Y=[carros[i].posicion[2] for i in 1:length(carros)]
    l = carros[1].largo
    p = n+m
    δx = zeros(length(carros))
    for i in 1:length(carros)
        if 1 <= i <= n
            condiciones_en_la_separacion_1er_carril(δx,Y,l,i,n,L)
        elseif n < i <= p
            condiciones_en_la_separacion_2do_carril(δx,Y,l,i,n,p,L)
        end
    end
    return δx
end

"""
Funcion que no da un arreglo con solo las veocidades de un arrglo de carros
"""
function velocidad_en_y_car(X)
    v = [X[i].velocidad[2] for i in 1:length(X)]
    return v
end

"""
Crea carros frontera que son solo esteticos para los plots, en un carril
"""
function carros_frontera(X,L)
    a = X[1].ancho
    l = X[1].largo
    Y = [X[i].posicion[2] for i in 1:length(X)]
    i = argmin(Y)
    j = argmax(Y)
    
    X_1 = [Auto(a,l,[X[i].posicion[1],L+Y[i]],i), Auto(a,l,[X[j].posicion[1],-L+Y[j]],j)]
    
    X_1[1].color = RGB(0.9,0,0)
    X_1[2].color = RGB(0.9,0,0)
    return X_1
end

"""
Funcion que calcula la distancia segura entre carros
"""
function Δx_s(d_0,α,μ,g,T_reac,v,colchon)
    return d_0 + (α*v^2)/(2*g*μ) + T_reac*v + colchon
end

"""
Funcion que calcula la velocidad minima segura entre los carros
"""
function v_i(δt ,d_0,α,μ,g,T_reac,v_0,v_1,separacion, colchon,acel)
    #v_0 velocidad enfrente 
    c = -(v_0 - v_1)*δt - separacion - (1/2)*acel*(δt^2) + d_0 - colchon
    a = α/(2*μ*g)
    b = T_reac
    if b^2 - 4*a*c >= 0
        v = (-b + sqrt(b^2 - 4*a*c))/(2*a)
    else
       
        v = 0
    end
    return v
end

"""
Funcion que calcula la aceleracion dependiendo de la velocidad minima segura asi como la separacion segura
"""
function aceleracion(δt ,d_0,α,μ,g,T_reac,v_0,v_1,separacion,colchon,v_i)
    acel = (2/(δt^2))*((v_0 - v_1)*δt + separacion - Δx_s(d_0,α,μ,g,T_reac,v_i,colchon))
    return acel
end

"""
Dado un arreglo podemos comprobar si un elemnto esta en el y nos devuelve su posicion, en este caso nos interesa el indice del coche

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
Dado un arreglo y un elemento que sabemos que esta en el,nos dice cuales son los numeros mas cercanos a el (el mayor y menor mas proximo), si en dado caso que el elemento es el menor de todos los elemntos nos devolvera como menor mas cercano al numero mas grande en dicho arreglo, y vicerversa si el numero es el mas grande nos devolvera como mayor mas proximo al numero mas chico del arreglo.
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

""" nos sive para calcular la velocidad promedio de un arreglo de autos en direccion y """
function velocidad_promedio_y(Autos)
    
    v = zeros(length(Autos))
    
    for i in 1:length(Autos)
        
        v[i] = Autos[i].velocidad[2]
        
        
    end
        
    return sum(v)/length(Autos)    
        
    
end

""" nos sive para calcular la velocidad promedio de un arreglo de autos"""
function velocidad_promedio(Autos)
    
    v = zeros(length(Autos))
    
    for i in 1:length(Autos)
        
        v[i] = norm(Autos[i].velocidad)
        
        
    end
        
    return sum(v)/length(Autos)    
        
    
end

""" nos sive para calcular la velocidad promedio de un arreglo de autos"""
function velocidad_promedio_y(Autos)
    
    v = zeros(length(Autos))
    
    for i in 1:length(Autos)
        
        v[i] = Autos[i].velocidad[2]
        
        
    end
        
    return sum(v)/length(Autos)    
        
    
end



