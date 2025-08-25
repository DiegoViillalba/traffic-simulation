"""
carros(a,l,L,Δx,n; xs = 1/2)
acomoda n autos en una carretera de largo L, separando los autos Δx, el primero lo pone en la posicion l/2.
a = ancho de carro
l= largo de carro
L = largo de carretera
Δx = sepracion de carros
n = numero de coches
xs = posición en x del carril
"""
function carros(a,l,L,Δx,n;xs = 1/2)
    if n*l+(n-1)*Δx > L
        throw("No hay espacio suficiente para los autos")
    end
    Y = [l/2+(i-1)*(l+Δx) for i in 1:n] 
    carros = [Auto(a,l,[xs,Y[i]],i) for i in 1:n]
    return carros
end


"""
carriles(A,N)
construye N carriles de ancho A
A=ancho de carril
N=NUMERO DE CARRILES QUE SE QUIERE
"""
carriles(A,N) = [Carril(A,[A*(i-1),A*i],i) for i in 1:N]

"""
carros_i_carriles(carros,carriles)
arroja un arreglo de arreglos, donde el primer elemento de cada arreglo es el índice del auto, y los demás son true o false, dependiendo de si el auto se encuentra o no en el carril. 
"""
function carros_i_carriles(carros::Array{Auto},carriles::Array{Carril})
    esquinasx = [[carros[i].esquinas[j][1] for j in 1:4]  for i in 1:length(carros)]
    M = [maximum(carriles[j].inicio_fin[1].< esquinasx[i] .<= carriles[j].inicio_fin[2]) 
        for i in 1:length(carros), j in 1:length(carriles)]
    carros_y_carriles = [[j == 1 ? carros[i].indice : M[i,j-1]  for j in 1:length(carriles) + 1] for i in 1:length(carros)]
end

function carros_i_carriles(carro::Auto,carriles::Array{Carril})
    esquinasx = [carro.esquinas[j][1] for j in 1:4]
    M = [carriles[j].inicio_fin[1].< esquinasx .<= carriles[j].inicio_fin[2] for j in 1:length(carriles)]
end

"""
carros_dos_carriles(a,l,L,Δx,Δx1,n,m; xs = 1/2)
acomoda n autos en una carretera de largo L, separando los autos Δx, el primero lo pone en la posicion [1/2,l/2].
despues acomoda m autos en una carretera de largo L, separados Δx2, el primero lo pone en la posición  [1/2+a*1.5,l/2]
L = largo de carretera
a = ancho de carro
l= largo de carro
Δx = sepracion de carros en carril 1
Δx1 = sepracion de carros en carril 2
n = numero de coches en carril 1
m = numero de coches en carril 2
xs = posicion en x del primer carril
"""
function carros_dos_carriles(a,l,L,Δx,Δx1,n,m; xs = 1/2)
    carros0 = carros(a,l,L,Δx,n, xs = xs)
    carros1 = carros(a,l,L,Δx1,m, xs = xs + 1)
    return vcat(carros0,carros1)
end

"""
rotacion_carro!(θ,a::Auto)
rota a un ángulo θ, es decir, rota tanto las esquinas, como la dirección. 
"""
function rotacion_carro!(θ,a::Auto)
    T = [cos(θ) -sin(θ);sin(θ) cos(θ)]
    for i in 1:4
        x_nuevo = a.esquinas[i] - a.posicion
        x_nuevo = T*x_nuevo
        a.esquinas[i] = x_nuevo + a.posicion
    end
    a.direccion = T*a.direccion
    return a
end

"""
actualiza_v!(a::Auto, v)
actualiza la velocidad y dirección del automovil. 
"""
function actualiza_v!(a::Auto, v)
    v0 = copy(a.direccion)
    a.velocidad = v
    if norm(v) > 0
        v1 = v./norm(v)
        θ1 = atan(v1[2],v1[1])
        θ0 = atan(v0[2],v0[1])
        rotacion_carro!(θ1-θ0, a)
        return a
    else
        return a
    end
end

"""
velocidad_angular_carro!(a::Auto,t,θ,v)
actualiza la velocidad y posición de a. La velocidad la calcula con θ como el ángulo y v su norma. 
la posición la actualiza poniendo moviendo a con su nueva velocidad un tiempo t. 
"""
function velocidad_angular_carro!(a::Auto,t,θ1)
    θ0 = atan(a.direccion[2],a.direccion[1])
    θ = pi-θ1
    θ2 = θ0-θ1
    L = a.largo
    back = sum(a.esquinas[3:4])./2
    front = sum(a.esquinas[1:2])./2
    v = norm(a.velocidad)
    x = L-cos(θ)*v*t - sqrt(L^2 -sin(θ)^2*v^2 * t^2)
    front .+= v*t*[cos(θ2), sin(θ2)] 
    back .+= x*a.direccion
    
    dx = (front+back)./2 .-a.posicion
    a + dx
    vnew = v*(front - back)./L
    actualiza_v!(a, vnew)
    return a
end

function velocidad_angular_carro_correcion!(a::Auto,t,θ1)
    θ0 = atan(a.direccion[2],a.direccion[1])
    θ = pi-θ1
    θ2 = θ0-θ1
    L = a.largo
    back = sum(a.esquinas[3:4])./2
    front = sum(a.esquinas[1:2])./2
    v = norm(a.velocidad)
    x = L - cos(θ)*v*t - sqrt(L^2 -sin(θ)^2*v^2 * t^2)
    front .+= x*a.direccion
    back .+= v*t*[cos(θ2), sin(θ2)]
    
    dx = (front+back)./2 .-a.posicion
    a + dx
    vnew = v*(front - back)./L
    actualiza_v!(a, vnew)
    return a
end

"""
maximo_giro(auto::Auto)
El máximo ángulo de giro permitido. Depende únicamente de la norma de la velocidad del automovil. 
Esta función hay que revisarla con cuidado. 
"""
function maximo_giro(auto::Auto)
    v = norm(auto.velocidad)
    θ = π/4*(1/(0.5*v+1))^(1/2)
end

########## inicia función carros_fantasma #########

function intersecta_recta(x1,x2,c)
    m = (x1[2]-x2[2])/(x1[1]-x2[1])
    b = x1[2]-m*x1[1]
    [c, m*c+b]
end
    
function intersecta_rectangulo(e, x0)
    posibles_lugares = [e[i][1]<=x0<=e[mod1(i+1,4)][1] || e[i][1]>=x0>=e[mod1(i+1,4)][1] for i in 1:4]
    intersecciones = []
    for i in 1:4
        if posibles_lugares[i]
            push!(intersecciones, intersecta_recta(e[i], e[mod1(i+1,4)], x0))
        end
    end
    return intersecciones
end 

function encuentra_intersección_auto_carril(auto::Auto, carriless::Array{Carril})
    carros_y_carriles = carros_i_carriles(auto,carriless)
    I = findall(x-> sum(x)> 0, carros_y_carriles)
    
    if length(I)  <= 1
        return I, [], [auto.esquinas]
    else
        I = minimum(I):maximum(I)
        return I, [carriless[I[i]].inicio_fin[2] for i in 1:length(I)-1], [carros_y_carriles[I[i]] for i in 1:length(I)]
    end  
end

function calcula_intersección_auto_carril(auto::Auto, carriless::Array{Carril})
    e = auto.esquinas
    I, x_int,es_s = encuentra_intersección_auto_carril(auto, carriless)
    if length(x_int) == 0
        return I, [], es_s
    end
    
    ps = [intersecta_rectangulo(auto.esquinas, x) for x in x_int]
    return I, ps, [e[es] for es in es_s]
end  
function min_max(es)
    ey = [es[i][2] for i in 1:length(es)]
    ymin = minimum(ey)
    ymax = maximum(ey)
    return [ymin,ymax]
end
function obten_min_max(auto::Auto, carriless::Array{Carril})
    I, ps, es = calcula_intersección_auto_carril(auto, carriless)
    if length(ps) != 0
        intervals = []
        for i in 1:length(ps)
            append!(es[i], ps[i])
            append!(es[i+1], ps[i])
        end
        for e in es
            interval = min_max(e)
            push!(intervals, interval)
        end
        return I, intervals
    else
        interval = min_max(es[1])
        return I, [interval]
    end  
end  
"""
carros_fantasmas(auto::Auto,carriless::Array{Carril})
genera los autos fantasma en la dirección del carril. 
"""
function carros_fantasmas(auto::Auto, carriless::Array{Carril})
    I, intervals = obten_min_max(auto, carriless)
    fantasmas_t = Auto[]
    for i in 1:length(I)
     
            a_fantasma = Auto(auto.ancho, intervals[i][2]-intervals[i][1],[sum(carriless[I[i]].inicio_fin)/2,(intervals[i][2]+intervals[i][1])/2], 0)
       
        a_fantasma.velocidad = [0,auto.velocidad[2]]
        a_fantasma.color = auto.color
        push!(fantasmas_t, a_fantasma)
    end
    return fantasmas_t
end 
    
########## termina función carros_fantasma #########



