""" escojemos la velocidad real del carro dado las dos velocidades de los fantasmas """
function escoje_velocidad_real(carros,fantasmas_1, fantasmas_2,en_carril,i)
    
        v1 = copy(fantasmas_1[i].velocidad[2])
        v2 = copy(fantasmas_2[i].velocidad[2])
    
        if en_carril[i][2] == true && en_carril[i][3] == true 
            carros[i].velocidad[2] = min(v1,v2)
            
        elseif en_carril[i][2] == true && en_carril[i][3] == false
            carros[i].velocidad[2] = v1
            
        elseif en_carril[i][2] == false && en_carril[i][3] == true 
            carros[i].velocidad[2] = v2
            
        end
    
end


""" actualiza las posiciones de los carros pero no se tiene en cuenta la posibilidad de giro """
function actualiza_dos_carriles_sin_giro(carros,fantasmas_1, fantasmas_2,δt,L)
    carriless = carriles(1,2)
    en_carril = carros_i_carriles(carros,carriless)
    
    for i in 1:length(carros)
        
        escoje_velocidad_real(carros,fantasmas_1, fantasmas_2,en_carril,i)
        actualizar_posicion_un_carril(carros,δt,L,i)
        actualizar_esquinas_un_carril(carros,i)
        
    end
    
    
end


""" avanza los carros en ts pasos y crea una animacion que tambien incluye los carros fantasmas"""
function avance_dos_carriles_sin_giro_f!(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel,ts;kargs...)
    @animate for t in 1:ts
    
        fantasmas_1,fantasmas_2 = velocidad_carros_dos_carriles(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
        actualiza_dos_carriles_sin_giro(vehiculos,fantasmas_1, fantasmas_2,δt,L)
        
        fantasmas_1,fantasmas_2 = listas_carros_fantasmas(vehiculos)
        #vehiculos_frontera = carros_frontera(vehiculos,L)
    
        plot(vehiculos,key=false;kargs...)
        #plot!(vehiculos_frontera,key=false)
        plot!(fantasmas_1, alpha = 0.3)
        plot!(fantasmas_2, alpha = 0.3)
        plot!(vehiculos,key=false,ylim=(0,L) , xlim = (-1,3))
            vline!([0,1,2], color = :black)
    
    end
end


""" avanza los carros en ts pasos y crea una animacion que no incluye los carros fantasmas"""
function avance_dos_carriles_sin_giro!(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel,ts;kargs...)
    @animate for t in 1:ts
    
        fantasmas_1,fantasmas_2 = velocidad_carros_dos_carriles(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
        actualiza_dos_carriles_sin_giro(vehiculos,fantasmas_1, fantasmas_2,δt,L)
        
        #actualizar otra vez los fantasmas solo es necesario para la animacion
        #fantasmas_1,fantasmas_2 = listas_carros_fantasmas(vehiculos)
        #vehiculos_frontera = carros_frontera(vehiculos,L)
    
        plot(vehiculos,key=false;kargs...)
        #plot!(vehiculos_frontera,key=false)
 
        plot!(vehiculos,key=false,ylim=(0,L) , xlim = (-1,3))
        vline!([0,1,2], color = :black)
    
    end
end


""" avanza los carros en ts pasos y no crea animacion para mayor eficiencia"""

function avance_dos_carriles_sin_giro(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel,ts)
    for t in 1:ts
    
        fantasmas_1,fantasmas_2 = velocidad_carros_dos_carriles(vehiculos,L,δt,d_0_1,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
        actualiza_dos_carriles_sin_giro(vehiculos,fantasmas_1, fantasmas_2,δt,L)
        
    end
end









