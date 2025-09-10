function condicion_cambio_velocidad(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,acel,vehiculos,j)
    
    if j<length(vehiculos)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[j+1].velocidad[2],v_1,Sep[j],colchon,acel)
    elseif j == length(vehiculos)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[1].velocidad[2],v_1,Sep[j],colchon,acel)
    end
    
end

function condicion_cambio_velocidad_limite_superior(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_max)
    
    if j<length(vehiculos)
            a_max = aceleracion(δt ,d_0,α,μ,g,T_reac,vehiculos[j+1].velocidad[2],v_1,Sep[j],colchon,v_max)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[j+1].velocidad[2],v_1,Sep[j],colchon,a_max)
    elseif j == length(vehiculos)
            a_max = aceleracion(δt ,d_0,α,μ,g,T_reac,vehiculos[1].velocidad[2],v_1,Sep[j],colchon,v_max)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[1].velocidad[2],v_1,Sep[j],colchon,a_max)
    end
    return vehiculos[j].velocidad[2]
end



function condicion_cambio_velocidad_limite_inferior(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_min)
    
    if j<length(vehiculos)
            a_min = aceleracion(δt ,d_0,α,μ,g,T_reac,vehiculos[j+1].velocidad[2],v_1,Sep[j],colchon,v_min)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[j+1].velocidad[2],v_1,Sep[j],colchon,a_min)
        
    elseif j == length(vehiculos)
            a_min = aceleracion(δt ,d_0,α,μ,g,T_reac,vehiculos[1].velocidad[2],v_1,Sep[j],colchon,v_min)
            vehiculos[j].velocidad[2] = v_i(δt ,d_0,α,μ,g,T_reac,vehiculos[1].velocidad[2],v_1,Sep[j],colchon,a_min)
    end
    
end

function cond_vel_sup_in(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_max,v_min)
    if vehiculos[j].velocidad[2] > v_max
            
            condicion_cambio_velocidad_limite_superior(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_max)
            if vehiculos[j].velocidad[2] > v_max
                vehiculos[j].velocidad[2] = v_max
            end
            
    elseif vehiculos[j].velocidad[2] < 0
            
            condicion_cambio_velocidad_limite_inferior(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_min)
                
    end
end



function actualizar_posicion_un_carril(vehiculos,δt,L,j)
    δx = vehiculos[j].velocidad[2]*δt
    vehiculos[j].posicion[2] = vehiculos[j].posicion[2] + δx
    
    if vehiculos[j].posicion[2]>L
        vehiculos[j].posicion[2] = vehiculos[j].posicion[2] - L
    end
end

function actualizar_posicion_un_carril!(vehiculos,δt,L,j)
    δx = vehiculos[j].velocidad[2]*δt
    vehiculos[j].posicion[2] = vehiculos[j].posicion[2] + δx
    
    if vehiculos[j].posicion[2]>L
        test = true
        vehiculos[j].posicion[2] = vehiculos[j].posicion[2] - L
        return test
    end
    return false
end

function actualizar_esquinas_un_carril(vehiculos,j)
    for i in 1:4
        vehiculos[j].esquinas = [[vehiculos[j].posicion[1]-vehiculos[j].ancho/2,vehiculos[j].posicion[2]+vehiculos[j].largo/2],[vehiculos[j].posicion[1]+vehiculos[j].ancho/2,vehiculos[j].posicion[2]+vehiculos[j].largo/2],[vehiculos[j].posicion[1]+vehiculos[j].ancho/2,vehiculos[j].posicion[2]-vehiculos[j].largo/2],[vehiculos[j].posicion[1]-vehiculos[j].ancho/2,vehiculos[j].posicion[2]-vehiculos[j].largo/2]]
        
    end
end

""" Calcula las condiciones de avance de un carro en un solo carril"""

function avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    Sep = separacion_en_y(vehiculos, L)
            j = length(vehiculos)-i+1
            v_1 = vehiculos[j].velocidad[2]
          
            #calcula la velocidad
            
            condicion_cambio_velocidad(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,acel,vehiculos,j)
           
            # verifica si la velocidad no pasa el limite o se vuelve negativa
            cond_vel_sup_in(δt,d_0,α,μ,g,T_reac,v_1,Sep,colchon,vehiculos,j,v_max,v_min)
            
            #con la velocidad calculamos el nuevo desplazamiento
            actualizar_posicion_un_carril(vehiculos,δt,L,j)
            
            actualizar_esquinas_un_carril(vehiculos,j)
        
    
end


function avance_un_carril(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    
    for t in 1:ts
        for i in 1:length(vehiculos)
            avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
        end
    end
     
end
    
function avance_un_carril!(vehiculos,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min;kargs...)
    
    @animate  for t in 1:ts
    for i in 1:length(vehiculos)
        avance_carros_un_carril_individual(vehiculos,i,ts,d_0,δt,L,α,μ,g,T_reac,colchon,acel,v_max,v_min)
    end
        
    vehiculos_frontera = carros_frontera(vehiculos,L)
    
    plot(vehiculos,key=false;kargs...)
    plot!(vehiculos_frontera,key=false)
    plot!(vehiculos,key=false,ylim=(0,L) , xlim=(-1-vehiculos[1].ancho,vehiculos[1].ancho+1))
    vline!([0, 1],key=false, color = :black)
    end
        
end