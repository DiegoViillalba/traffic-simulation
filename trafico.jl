using Plots
using LinearAlgebra
using LaTeXStrings
using Plots.PlotMeasures
using JLD2

include("estructuras_trafico.jl")
include("funciones_iniciales.jl")
include("funciones_dibujo.jl")
include("funciones_principales.jl")
include("avance_en_un_carril.jl")
include("fantasmas_dos_carriles.jl")
include("velocidad_fantasmas_en_dos_carril.jl")
include("avance_carros_dos_carriles_sin_giro.jl")
include("funciones_extras.jl")
include("funciones_cambio_de_carril_hacia_la_derecha.jl")
include("funciones_cambio_de_carril_hacia_la_izquierda.jl")
include("Aux_dos_carriles_giro.jl")
include("Aux_dos_carriles_giro_2.jl")
include("avance_carros_dos_carriles_con_giro.jl")
include("funciones_de_mediciones.jl")



