"""
TraficoSimulacion — Módulo principal de la simulación microscópica de tráfico.

Uso desde un notebook o script externo:

    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))   # raíz del proyecto
    using TraficoSimulacion

Todas las funciones y tipos de la API pública quedan disponibles directamente.
"""
module TraficoSimulacion

using Plots
using Plots.PlotMeasures
using LinearAlgebra
using Statistics
using LaTeXStrings
using Logging
using CSV
using DataFrames

# ── Core: estructuras de datos y física base ──────────────────────────────────
include("core/estructuras.jl")
include("core/fisica.jl")

# ── Inicialización: construcción de autos y carriles ─────────────────────────
include("inicializacion/vehiculos.jl")

# ── Visualización: plot(Auto), plot!(Vector{Auto}) ────────────────────────────
include("visualizacion/dibujo.jl")

# ── Fantasmas: proyección por carril y velocidades ────────────────────────────
include("fantasmas/creacion.jl")
include("fantasmas/velocidad.jl")

# ── Simulación un carril ──────────────────────────────────────────────────────
include("simulacion/un_carril.jl")

# ── Cambio de carril: geometría, estado de giro y decisión ───────────────────
include("cambio_carril/geometria.jl")
include("cambio_carril/angulos.jl")
include("cambio_carril/decision.jl")

# ── Simulación dos carriles ───────────────────────────────────────────────────
include("simulacion/dos_carriles_sin_giro.jl")
include("simulacion/colisiones.jl")
include("simulacion/dos_carriles.jl")

# ── Utilidades: distribución automática de autos ─────────────────────────────
include("utils/distribucion.jl")

# ── Mediciones: velocidades, análisis, interacciones y exportación CSV ───────
include("mediciones/velocidades.jl")
include("mediciones/analisis.jl")
include("mediciones/interacciones.jl")
include("mediciones/exportacion.jl")

# ─────────────────────────────────────────────────────────────────────────────
# API pública
# ─────────────────────────────────────────────────────────────────────────────

# Tipos de datos
export Auto, Carril, GrillaEspacial

# Construcción de carretera y vehículos
export carriles
export carros, carros_dos_carriles
export carros_i_carriles, carros_fantasmas, listas_carros_fantasmas

# Copia y actualización de vehículos
export copia_auto_rapida, copiar_lista_autos_rapida
export rotacion_carro!, actualiza_v!, velocidad_angular_carro_correcion!

# Física: separaciones, límites, velocidades
export separacion_en_y, velocidad_promedio_y
export limites_auto_carril, limites_auto_carril!
export v_i, aceleracion, delta_x_s

# Estado de simulación
export comprobacion_giro, carril_original

# Simulación dos carriles — nivel alto
export avance_carros_general, avance_carros_general!
export avance_dos_carriles_con_giro_sin_anim, avance_dos_carriles_con_giro_un_paso

# Simulación un carril
export avance_un_carril, avance_un_carril!
export avance_carros_un_carril_individual

# Detección de colisiones (SAT)
export haySuperposicionesSAT_error, seSuperponenSAT

# Medición de interacciones y entropía
export contar_vecinos_paso
export avance_dos_carril_velocidades_e_interacciones
export entropia_shannon, entropia_por_paso, entropia_global
export historial_interacciones_vehiculo, distribucion_interacciones
export guardar_interacciones_csv

# Medición de velocidades
export avance_dos_carril_valocidades_promedio
export medicion_velocidades_flujo_desplazamiento
export avance_un_carril_valocidades_promedio, avance_un_carril_valocidades_promedio!
export medicion_velocidades_densidad

# Análisis de series temporales
export media_movil_simple, encontrar_ventana_optima
export derivada_numerica, encontrar_t_critico, doble_suavizado_desde_tcritico

# Exportación a CSV
export guardarVelocidadesTiempos, guardarTiemposFlujo, guardardesplazamientoTiempos
export simular_y_guardar
export guardarVelocidadesTiempos_1carril, guardarTiemposFlujo_1carril
export simular_y_guardar_1carril

# Distribución automática de autos
export generar_distribucion_automatica, generar_carril_unico
export distribucion_optima_carros, acomodar_un_carril

end # module TraficoSimulacion
