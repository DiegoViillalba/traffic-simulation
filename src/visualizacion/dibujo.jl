import Plots.plot, Plots.plot!
using Plots.Colors: RGB

#### funciones pre-eliminares ######

function kargs_reducidos(;kargs...)
    I = findall(x-> x != :color && x != :label && x != :fill, keys(kargs))
    if length(I)  > 0
        kargs2 = kargs[keys(kargs)[I]]
        return kargs2
    end
    return kargs_reducidos(lw = 0)
end

function rotate_datos(x,y, centro, θ)
    R = [cos(θ) -sin(θ);sin(θ) cos(θ)]
    rotados = [R*[x[i]-centro[1],y[i]-centro[2]] for i in 1:length(x)]
    xr = [rotados[i][1]+centro[1] for i in 1:length(x)]
    yr = [rotados[i][2]+centro[2] for i in 1:length(x)]
    return xr, yr
end

function rectangulo_d(a::Auto)
    x = [a.esquinas[mod1(i,4)][1] for i in 1:5]
    y = [a.esquinas[mod1(i,4)][2] for i in 1:5]
    return x, y
end

function parabrisas_d(a::Auto)
    θ = atan(a.direccion[2],a.direccion[1])-pi/2
    centro = a.posicion
    c= a.ancho/2
    d= a.largo/2
    p1_1 = a.posicion[1] - 0.95*c
    p1_2 = a.posicion[1] + 0.95*c
    p2_1 = a.posicion[2] + 2*d/5
    p2_2 = a.posicion[2] + 4*d/5
    p_x = [p1_1 + 0.1*c ,p1_1,p1_2,p1_2- 0.1*c,p1_1 + 0.1*c]
    p_y = [p2_1,p2_2,p2_2,p2_1,p2_1]
    p_x, p_y = rotate_datos(p_x, p_y, centro, θ)
    return c,d, p1_1, p1_2, p2_1, p2_2,p_x, p_y
end

function parabrisas_trasero_d(a::Auto, c, d)
    θ = atan(a.direccion[2],a.direccion[1])-pi/2
    centro = a.posicion
    t1_1 = a.posicion[1] - 0.9*c
    t1_2 = a.posicion[1] + 0.9*c
    t2_1 = a.posicion[2] - 9*d/10
    t2_2 = a.posicion[2] - 3*d/5 
    t_x = [t1_1 ,t1_1+ 0.15*c,t1_2- 0.15*c,t1_2,t1_1]
    t_y = [t2_1,t2_2,t2_2,t2_1,t2_1]
    t_x, t_y = rotate_datos(t_x, t_y, centro, θ)
    return t1_1,t1_2,t2_1,t2_2, t_x, t_y
end

function ventanas_d(a::Auto, p1_1,p1_2, p2_1, p2_2, t2_1, t2_2, c, d)
    θ = atan(a.direccion[2],a.direccion[1])-pi/2
    centro = a.posicion
    v1_1 = p1_2 - 0.1*c
    v1_2 = p1_2
    v2_2 = p2_1 - 0.15*d
    v2_3= p2_2 - 0.15*d
    v2_4= t2_1 + 0.1*d
    v2_1 = t2_2+ 0.1*d  
    v_x = [v1_1,v1_1,v1_2,v1_2,v1_1]
    v_y = [v2_1,v2_2,v2_3,v2_4,v2_1]
    v_x, v_y = rotate_datos(v_x, v_y, centro, θ)
    b1_1 = p1_1 
    b1_2 = p1_1 + 0.1*c   
    b_x = [b1_2,b1_1,b1_1,b1_2,b1_2] 
    b_y = [v2_1,v2_4,v2_3,v2_2,v2_1]
    b_x, b_y = rotate_datos(b_x, b_y, centro, θ)
    return v_x, v_y, b_x, b_y 
end

function faros_d(a::Auto, x,y, c,d)
    θ = atan(a.direccion[2],a.direccion[1])-pi/2
    deltax0 = [c/10,c/10+c/5,c/10+c/5,c/10,c/10]
    deltay0 = [0,0,-c/5,-c/5,0]
    deltax, deltay = rotate_datos(deltax0,deltay0, [0,0.], θ)
    deltax2, deltay2 = rotate_datos(deltax0,deltay0, [0,0.], -θ)
    f1_x = [[x[j] for i in 1:5].+ [1,0,-1][j]*deltax for j in 1:2:3]
    f1_y = [[y[j] for i in 1:5].+ [1,0,-1][j]*deltay for j in 1:2:3]
    f2_x = [[x[j] for i in 1:5].+ [-1,0,1][j-1]*deltax2 for j in 2:2:4]
    f2_y = [[y[j] for i in 1:5].+ [1,0,-1][j-1]*deltay2 for j in 2:2:4]
    return f1_x[1], f1_y[1],f2_x[1],f2_y[1],f1_x[2],f1_y[2],f2_x[2],f2_y[2]
end

### funciones importantes
    
"""
plot!(a, kargs...) dibuja el auto a.
kargs: vidrios = true, faros = true, y kargs usuales de plot excepto color y fill.
"""
function plot!(a::Auto; vidrios = true, faros = true, kargs...)
    kargs2 = kargs_reducidos(;kargs...)
    x, y = rectangulo_d(a)
    plot!(x,y,fill=true,color = a.color;kargs...)
    if vidrios
        c,d, p1_1, p1_2, p2_1, p2_2,p_x, p_y = parabrisas_d(a)
        plot!(p_x,p_y,fill=true,color = RGB(0,0,0.5),label=false; kargs2...)
        t1_1,t1_2,t2_1,t2_2, t_x, t_y = parabrisas_trasero_d(a, c,d)
        plot!(t_x,t_y,fill=true,color = RGB(0,0,0.5),label=false; kargs2...)
        v_x, v_y, b_x, b_y = ventanas_d(a, p1_1,p1_2, p2_1, p2_2, t2_1, t2_2, c, d)
        plot!(v_x,v_y,fill=true,color = RGB(0,0,0.5),label=false; kargs2...)
        plot!(b_x,b_y,fill=true,color = RGB(0,0,0.5),label=false; kargs2...)
    end 
    if faros
        f1_x, f1_y, f2_x, f2_y, f3_x, f3_y, f4_x, f4_y = faros_d(a, x, y, c,d)
        plot!(f1_x,f1_y,fill=true,color = RGB(0.9,1,0),label=false; kargs2...)
        plot!(f2_x,f2_y,fill=true,color = RGB(0.9,1,0),label=false; kargs2...)
        plot!(f3_x,f3_y,fill=true,color = RGB(0.9,0,0),label=false; kargs2...)
        plot!(f4_x,f4_y,fill=true,color = RGB(0.9,0,0),label=false; kargs2...)
    end
    plot!()
end

"""
plot(a, kargs...) dibuja el auto a.
"""
function plot(a::Auto; vidrios = true, faros = true, kargs...)
    plot()
    plot!(a, vidrios = vidrios, faros = faros; kargs...)
end

"""
plot(cars, kargs...) dibuja un arreglo de autos.
"""
function plot(carros::Vector{Auto};vidrios = true, faros = true, kargs...)
    plot()
    for i in 1:length(carros)
        plot!(carros[i],vidrios = vidrios, faros = faros, label = "";kargs...) 
    end
    plot!()
end

"""
plot!(cars, kargs...) dibuja un arreglo de autos sobre el plot actual.
"""
function plot!(carros::Vector{Auto};vidrios = true, faros = true,kargs...)
    for i in 1:length(carros)
        plot!(carros[i],vidrios = vidrios, faros = faros, label = "";kargs...) 
    end
    plot!()
end

""" grafica vector normalizado """
function graficar_vector_normalizado!(vector::Vector{Float64}, centro::Vector{Float64}; kargs...)
    norma = sqrt(sum(vector.^2))
    if !isapprox(norma, 1.0, atol=1e-5)
        @warn "El vector proporcionado no está normalizado (norma = $norma). Se normalizará automáticamente."
        vector = vector ./ norma
    end
    punto_final = centro .+ vector
    plot!([centro[1], punto_final[1]], [centro[2], punto_final[2]]; kargs...)
    scatter!([centro[1]], [centro[2]], color=:red, key = false)
end
