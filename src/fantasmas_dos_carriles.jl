""" funcion que crea un carro de longitud cero cuando pre carros solo tiene un elemento con esto obtemos los autos fantasmas correctos"""

function carros_largo_cero(pre_carros,auto::Auto, carriless::Array{Carril})
    en_carril = carros_i_carriles(pre_carros,carriless)
    
     if en_carril[1][2] == true # Si está en el carril 1
            
         a_fantasma = Auto(auto.ancho, 0 ,[3/2,auto.esquinas[2][2]], 0)
         carros = [pre_carros[1],a_fantasma]
        
     elseif en_carril[1][3] == true # Si está en el carril 2
        
         a_fantasma = Auto(auto.ancho, 0 ,[1/2,auto.esquinas[1][2]], 0)
         carros = [a_fantasma,pre_carros[1]]
        
     end
    return carros
end


""" nos regresa un arreglo de dos carros fantasmas ahora si con carros que oueden tener largo cero """

function carros_fantasmas_2(auto::Auto, carriless::Array{Carril})
    
    pre_carros = carros_fantasmas(auto, carriless)
 
    en_carril = carros_i_carriles(pre_carros,carriless)
    n = length(pre_carros)
    v = copy(auto.velocidad[2])
    if n==1
        
        carros = carros_largo_cero(pre_carros,auto, carriless) 
        
          
        carros[1].velocidad[2] = v
        carros[1].velocidad[1] = 0
        carros[2].velocidad[2] = v
        carros[2].velocidad[1] = 0
        
        return carros
    else
        
        
        
        pre_carros[1].velocidad[2] = v
        pre_carros[1].velocidad[1] = 0
        pre_carros[2].velocidad[2] = v
        pre_carros[2].velocidad[1] = 0
       
        return pre_carros
    end
    
end

""" Dado una lasta de carros crea la lista de los fantasmas correspondiente a cada carril es decir dos arreglos para cada carril"""

function listas_carros_fantasmas(carros)
    fantasmas_1 = Auto[]
    fantasmas_2 = Auto[]
    
    for i in 1:length(carros)
        
        fantasmas = carros_fantasmas_2(carros[i], carriles(1,2))

        
        
        push!(fantasmas_1, fantasmas[1])
        push!(fantasmas_2, fantasmas[2])
        
        
        
    end
    
    return fantasmas_1, fantasmas_2 
    
end



