""" funcion que compila todas las funciones necesarias para el avance del carro i cuando su velocidad es diferente de cero"""
function condicion_velocidad_2_giro(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error = 1e-2)
    
    
  velocidad_un_fantasmas(carril_1,fantasmas_1,sep_fantasmas_1,i,indice_enfrente_1,δt,d_0_1,α,μ,g,T_reac,colchon,v_max,v_min,acel)
    velocidad_un_fantasmas(carril_2,fantasmas_2,sep_fantasmas_2,i,indice_enfrente_2,δt,d_0_2,α,μ,g,T_reac,colchon,v_max,v_min,acel)
  escoje_velocidad_real!(vehiculos,fantasmas_1, fantasmas_2,giro_nogiro,en_carril,i)

    actualizar_angulo_giro(sep_fantasmas_1,sep_fantasmas_2,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,indice_enfrente_1,indice_enfrente_2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carriles1;error)
    actualiza_comprobacion_giro(vehiculos,giro_nogiro,i;err= 1e-6)
    actualiza_cambio_de_carril_original(giro_nogiro,carriles_original,en_carril,i)    
   
    velocidad_angular_carro_correcion!(vehiculos[i],δt,θ_vec[i])
    limites_auto_carril(vehiculos[i],L)
    
end

""" funcion que compila todas las funciones necesarias para el avance del carro i(condiciones generales)"""
function avance_carros(vel_test,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error = 1e-2,err= 1e-6)
    

    condicion_velocidad_2_giro(i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriles1;error)
        
end


""" funcion que compila todas las funciones y arreglos que son necesarios para el avance de un carro i """
function avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error = 1e-2,err= 1e-6)
    en_carril = carros_i_carriles(vehiculos,carriless)
        fantasmas_1, fantasmas_2 = listas_carros_fantasmas(vehiculos)
        #carril_1, carril_2 = ordenar_carriles(vehiculos,en_carril)
        carril_1, carril_2 = ordenar_carriles!(vehiculos,en_carril,giro_nogiro)
        #carriles_original = cambio_de_carril_original(giro_nogiro,carriles_original,en_carril)
        indice_enfrente_1 = identifica_adelante(carril_1,fantasmas_1)
        indice_enfrente_2 = identifica_adelante(carril_2,fantasmas_2)
        sep_fantasmas_1,sep_fantasmas_2 = separaciones_por_carriles_dos(carril_1, carril_2,fantasmas_1,fantasmas_2,L)
        lista_carril1,lista_carril2 = listas_pregiro!(fantasmas_1,fantasmas_2,en_carril,giro_nogiro)
        vel_test = comprobacion_velocidad(vehiculos)
        
    avance_carros(vel_test,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriless;error,err)
end

""" funcion que compila todas las funciones y arreglos que son necesarios para el avance de todos los carros, ademas de los plots necesarios para la animacion """
function avance_dos_carriles_con_giro_para_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    
    indices_alternados = generar_indices_alternados(n, m)  
    #indices_alternados = indices_alternados_contrario(n, m)
    for i in indices_alternados
                avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
    end
    
    #fantasmas_1, fantasmas_2  = listas_carros_fantasmas(vehiculos)
    
    plot(vehiculos,key=false,ylim=(0,L) , xlim=(-1-carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[2][1]+1);kargs...)
    #plot(fantasmas_1,alpha = 0.2,key=false,ylim=(0,L) , xlim=(-1-carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[2][1]+1);kargs...)    
    #plot!(fantasmas_1,alpha = 0.2)
    #plot!(fantasmas_2,alpha = 0.2)
    
    vline!([carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[1][1], carriless[2].inicio_fin[2][1]], color = :black)
    plot!(show = :ijulia)
    
end


""" funcion que compila todas las funciones y arreglos que son necesarios para el avance de todos los carros, SIN los plots necesarios para la animacion """
function avance_dos_carriles_con_giro_sin_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6)
    
    indices_alternados = generar_indices_alternados(n, m)   
    for i in indices_alternados
         avance_dos_carriles_con_giro_un_paso(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
    end
    
    #fantasmas_1, fantasmas_2  = listas_carros_fantasmas(vehiculos)
    #plot(vehiculos,key=false,aspect_ratio=1,ylim=(0,L) , xlim = (-3,3))
        
    #plot!(fantasmas_1,alpha = 0.3)
    #plot!(fantasmas_2,alpha = 0.3)
    
    #vline!([carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[1][1], carriless[2].inicio_fin[2][1]], color = :black)
    #plot!(show = :ijulia)
    
end

""" avanza los carros y crea una animacion """
function avance_carros_general!(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    @animate  for t in 1:pasos
    
        avance_dos_carriles_con_giro_para_anim(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error,err,kargs...)
    
    end
    
end



""" funcion que compila todas las funciones y arreglos que son necesarios para el avance de un carro i """
function avance_dos_carriles_con_giro_un_paso_alt(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error = 1e-2,err= 1e-6)
    en_carril = carros_i_carriles(vehiculos,carriless)
        fantasmas_1, fantasmas_2 = listas_carros_fantasmas(vehiculos)
        carril_1, carril_2 = ordenar_carriles(vehiculos,en_carril)
        #carril_1, carril_2 = ordenar_carriles!(vehiculos,en_carril,giro_nogiro)
        #carriles_original = cambio_de_carril_original(giro_nogiro,carriles_original,en_carril)
        indice_enfrente_1 = identifica_adelante(carril_1,fantasmas_1)
        indice_enfrente_2 = identifica_adelante(carril_2,fantasmas_2)
        sep_fantasmas_1,sep_fantasmas_2 = separaciones_por_carriles_dos(carril_1, carril_2,fantasmas_1,fantasmas_2,L)
        lista_carril1,lista_carril2 = listas_pregiro!(fantasmas_1,fantasmas_2,en_carril,giro_nogiro)
        vel_test = comprobacion_velocidad(vehiculos)
        
    avance_carros(vel_test,i,θ_vec,giro_nogiro,vehiculos,carriles_original,lista_carril1,lista_carril2,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,carril_1,fantasmas_1,sep_fantasmas_1,indice_enfrente_1,carril_2,fantasmas_2,sep_fantasmas_2,indice_enfrente_2,en_carril,carriless;error,err)
end

""" funcion que compila todas las funciones y arreglos que son necesarios para el avance de todos los carros, ademas de los plots necesarios para la animacion """
function avance_dos_carriles_con_giro_para_anim_alt(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    
    indices_alternados = generar_indices_alternados(n, m)   
    for i in indices_alternados
    avance_dos_carriles_con_giro_un_paso_alt(i,vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min;error,err)
    end
    
    fantasmas_1, fantasmas_2  = listas_carros_fantasmas(vehiculos)
    
    plot(vehiculos,key=false,ylim=(0,L) , xlim=(-1-carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[2][1]+1);kargs...)
        
    plot!(fantasmas_1,alpha = 0.3)
    plot!(fantasmas_2,alpha = 0.3)
    
    vline!([carriless[1].inicio_fin[1][1],carriless[2].inicio_fin[1][1], carriless[2].inicio_fin[2][1]], color = :black)
    plot!(show = :ijulia)
    
end

""" avanza los carros y crea una animacion alternativa """
function avance_carros_general_alt!(pasos,vehiculos,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error = 1e-2,err= 1e-6,kargs...)
    carriless = carriles(1,2)
    giro_nogiro = comprobacion_giro(vehiculos)
    θ_vec = zeros(length(vehiculos))
    en_carril = carros_i_carriles(vehiculos,carriless)
    carriles_original = carril_original(vehiculos,en_carril)
    @animate  for t in 1:pasos
    
        avance_dos_carriles_con_giro_para_anim_alt(vehiculos,θ_vec,carriless,carriles_original,giro_nogiro,egoismo,δt,L,d_0_1,d_0_2,α,μ,g,T_reac,colchon,acel,v_max,v_min,n,m;error,err,kargs...)
    
    end
    
end

