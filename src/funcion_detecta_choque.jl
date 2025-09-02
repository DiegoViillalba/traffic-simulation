function proyectarEnEje(esquinas::Vector{Any}, eje::Vector{Float64})
    min_proj = Inf
    max_proj = -Inf
    
    for esquina in esquinas
        proj = dot(esquina, eje)
        min_proj = min(min_proj, proj)
        max_proj = max(max_proj, proj)
    end
    
    return (min_proj, max_proj)
end

""" Función para verificar si dos intervalos se superponen"""
function intervalosSeSuperponen(a_min::Float64, a_max::Float64, b_min::Float64, b_max::Float64)
    return !(a_max < b_min || b_max < a_min)
end

# Función para obtener ejes normales de un polígono
function obtenerEjes(esquinas::Vector{Any})
    n = length(esquinas)
    ejes = Vector{Vector{Float64}}()
    
    for i in 1:n
        j = i % n + 1
        # Vector de arista
        arista = [esquinas[j][1] - esquinas[i][1], esquinas[j][2] - esquinas[i][2]]
        # Vector normal (perpendicular)
        normal = [-arista[2], arista[1]]
        # Normalizar
        magnitud = sqrt(normal[1]^2 + normal[2]^2)
        if magnitud > 0
            push!(ejes, [normal[1]/magnitud, normal[2]/magnitud])
        end
    end
    
    return ejes
end

""" Función principal para verificar superposición usando SAT"""
function seSuperponenSAT(auto1::Auto, auto2::Auto)
    esquinas1 = auto1.esquinas
    esquinas2 = auto2.esquinas
    
    # Obtener todos los ejes a probar
    ejes = vcat(obtenerEjes(esquinas1), obtenerEjes(esquinas2))
    
    for eje in ejes
        # Proyectar ambos polígonos en el eje actual
        min1, max1 = proyectarEnEje(esquinas1, eje)
        min2, max2 = proyectarEnEje(esquinas2, eje)
        
        # Si hay un eje donde las proyecciones no se superponen, no hay colisión
        if !intervalosSeSuperponen(min1, max1, min2, max2)
            return false
        end
    end
    
    # Si todas las proyecciones se superponen en todos los ejes, hay colisión
    return true
end

""" funcion que detecta el choque de cualquier auto y detiene la simulacion """
function haySuperposicionesSAT_error(autos::Vector{Auto},t)
    n = length(autos)
    
    for i in 1:n
        for j in (i+1):n
            if seSuperponenSAT(autos[i], autos[j])
                println("❌ ERROR: Auto $i y Auto $j se superponen")
                println("paso $t")
                println("   Auto $i esquinas: ", autos[i].esquinas)
                println("   Auto $j esquinas: ", autos[j].esquinas)
                error("Superposición detectada - Simulación detenida")
            end
        end
    end
    
    #println("✅ No se detectaron superposiciones")
    #return false
end






