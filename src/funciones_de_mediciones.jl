""" funciones que nos da dos arreglos uno de velocidad promedio y el otro de tiempo T,V """

function avance_un_carril_valocidades_promedio(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    T = [ t*δt for t in 1:ts]
    
    V = zeros(ts)
    for t in 1:ts
        for i in 1:length(vehiculos)
            avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        end
        
        
        V[t] = 3.5*velocidad_promedio_y(vehiculos)
    end
    
        return T,V
end

""" funciones que nos da UN PLOT de dos arreglos uno de velocidad promedio y el otro de tiempo T,V """

function avance_un_carril_valocidades_promedio!(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min;kargs...)
    
    T = [t*δt for t in 1:ts]
    
    V = zeros(ts)
    for t in 1:ts
        for i in 1:length(vehiculos)
            avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        end
        
        
        V[t] = 3.5*velocidad_promedio_y(vehiculos)
    end
    
    plot(T,V;kargs...)
end

""" funcion que nos dara la velocidad promedio en funcion de las densidades un carril"""

function medicion_velocidades_densidad(ts,t_critico,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min,n_max)
    ρ = [n/(3.5*L) for n in 1:n_max]
    v_promedio_de_promedio = zeros(n_max)
    
    for n in 1:n_max
        
        largo = 9/7
        ancho = 18/35
        Δx = 0.8
        
        vehiculos = carros(ancho,largo,L,Δx,n;xs = 1/2)
        
        T,V = avance_un_carril_valocidades_promedio(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        
        v_promedio_de_promedio[n] = sum(V[t_critico:end])/length(V[t_critico:end])
        
        
    end
    return ρ,v_promedio_de_promedio
    
end
      
""" funcion que nos regresa un arreglo de tiempos y velocidades promedios dos carriles"""   
function avance_dos_carril_valocidades_promedio(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    
    T = [t*δt for t in 1:pasos]
    V = zeros(pasos)
    
    for t in 1:pasos
    
      avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
        
       V[t] = 3.5*velocidad_promedio(vehiculos)
    end
    
    return T,V
end


""" funcion que nos regresa un arreglo de tiempos y velocidades promedios dos carriles"""   
function avance_dos_carril_valocidades_promedio_2(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    
    #T = [t*δt for t in 1:pasos]
    V = zeros(pasos)
    
    for t in 1:pasos
    
      avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
        
       V[t] = 3.5*velocidad_promedio(vehiculos)
    end
    
    return V
end


""" funcion que nos regresa un arreglo de tiempos y velocidades promedios en y dos carriles"""   
function avance_dos_carril_valocidades_promedio_y(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    
    T = [t*δt for t in 1:pasos]
    V = zeros(pasos)
    
    for t in 1:pasos
    
      avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
        
       V[t] = 3.5*velocidad_promedio_y(vehiculos)
    end
    
    return T,V
end

""" funcion que nos regresa un arreglo de velocidades peomedio de promedios y egoismos despues de un tiempo critico a densidad fija dos carriles"""     


function medicion_velocidades_egoismo_avance(pasos,t,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    t_critico = Int(ceil(t/δt))
        
        iteraciones = 0:0.1:1
    p = length(iteraciones)
    
    V = zeros(p)
    E = zeros(p)  
       
    i = 1
    
    for e in iteraciones
        @show i
        egoismo = e
        vehiculos = carros_dos_carriles(ancho,largo,L,d1,d2,n,m; xs = 1/2)
    V1 = avance_dos_carril_valocidades_promedio_2(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
        
     V[i]  = sum(V1[t_critico:end])/length(V1[t_critico:end])
     E[i] = e
        
     i += 1   
        
    end
    
    return E,V
    
    
end  
    
""" funcion que mide la distancia entre dos puntos diferenetes en el tiempo  de un auto (el desplazamiento debe ser pequeño)   """


function desplazamiento_auto(pos_actual,pos_nueva,L)
    
    if (L  - pos_actual[2] ) < (L  - pos_nueva[2] )
        
        pos_nueva[2] = L + pos_nueva[2]
        
        return norm(pos_nueva - pos_actual)
    end
    
    return norm(pos_nueva - pos_actual) 
end

""" funcion que mide la distancia en "y" entre dos puntos diferenetes en el tiempo  de un auto (el desplazamiento debe ser pequeño)   """


function desplazamiento_auto_y(pos_actual,pos_nueva,L)
    
    if (L  - pos_actual[2] ) < (L  - pos_nueva[2] )
        
        pos_nueva[2] = L + pos_nueva[2]
        
        return abs(pos_nueva[2] - pos_actual[2])
    end
    
    return abs(pos_nueva[2] - pos_actual[2]) 
end

""" funcion que nos da el desplazmiento de un auto en un instante t, da el desplazamiento general y el desplazamiento en "y" """

function avance_dos_carriles_con_giro_desplazamiento(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    
    desplazamiento = zeros(length(vehiculos))
    desplazamiento_y = zeros(length(vehiculos))
    
    indices_alternados = generar_indices_alternados(n, m)   
    for i in indices_alternados
        
       pos_actual = copy(vehiculos[i].posicion) 
         avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
        
        
        pos_nueva = copy(vehiculos[i].posicion)
        
        desplazamiento[i] = desplazamiento_auto(pos_actual,pos_nueva,L)
        desplazamiento_y[i] = desplazamiento_auto_y(pos_actual,pos_nueva,L)
        
    end
    
    
    return desplazamiento,desplazamiento_y

end
    
    
""" funcion que nos da el desplazamiento de los autos"""

function avance_dos_carril_desplazamiento_promedio_normalizado(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    
    
    des = zeros(length(vehiculos))
    des_y = zeros(length(vehiculos))
    
    for t in 1:pasos
        
  
    
  desplazamiento, desplazamiento_y =    avance_dos_carriles_con_giro_desplazamiento(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error ,err)
        
        des += 3.5*desplazamiento
        des_y += 3.5*desplazamiento_y
       
    end
    
    des_prom = sum(des)/length(des)
    des_prom_y = sum(des_y)/length(des_y)
    
    return des_prom/des_prom_y
end
    
    
function medicion_desplazamiento_egoismo(pasos,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
        
        iteraciones = 0:0.1:1
    p = length(iteraciones)
    
    D = zeros(p)
    E = zeros(p)  
       
    i = 1
    
    for e in iteraciones
        
        @show i
        egoismo = e
        vehiculos = carros_dos_carriles(ancho,largo,L,d1,d2,n,m; xs = 1/2)
        
    D[i] = avance_dos_carril_desplazamiento_promedio_normalizado(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error ,err)
        
     
     E[i] = e
        
     i += 1   
        
    end
    
    return E,D
    
    
end     
    
    
    
    
    
    
    