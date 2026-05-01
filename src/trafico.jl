"""
trafico.jl — Punto de entrada de la simulación de tráfico vehicular.

Carga todos los módulos en el orden correcto de dependencias:
  core → inicializacion → visualizacion → fantasmas →
  simulacion/un_carril → cambio_carril → simulacion/dos_carriles →
  utils → mediciones
"""

using Plots
using Plots.PlotMeasures
using LinearAlgebra
using Statistics
using LaTeXStrings
using Logging

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

# ── Simulación un carril (debe estar antes de cambio_carril por egoismo_velocidad) ──
include("simulacion/un_carril.jl")

# ── Cambio de carril: geometría, estado de giro y decisión ───────────────────
include("cambio_carril/geometria.jl")
include("cambio_carril/angulos.jl")
include("cambio_carril/decision.jl")

# ── Simulación dos carriles ───────────────────────────────────────────────────
include("simulacion/dos_carriles_sin_giro.jl")
include("simulacion/colisiones.jl")
include("simulacion/dos_carriles.jl")

# ── Utilidades: egoísmo y distribución de autos ───────────────────────────────
include("utils/distribucion.jl")

# ── Mediciones: velocidades, análisis y exportación CSV ──────────────────────
include("mediciones/velocidades.jl")
include("mediciones/analisis.jl")
include("mediciones/exportacion.jl")
