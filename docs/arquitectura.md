# Arquitectura del Simulador de Tráfico

## Visión General

El simulador implementa un modelo **microscópico de tráfico** para una autopista de dos carriles
con condición de contorno periódica (circuito cerrado). Cada vehículo es una entidad autónoma
que actualiza su velocidad y posición basándose en el estado de sus vecinos más cercanos.

El proyecto está escrito íntegramente en **Julia**, aprovechando su sistema de tipos para
garantizar corrección y su compilación JIT para alcanzar rendimiento cercano a C.

---

## Mapa de Módulos

```
src/trafico.jl              ← punto de entrada; solo include() en orden de dependencias
│
├── core/
│   ├── estructuras.jl      ← tipos Auto, Carril; operadores +/−/mod
│   └── fisica.jl           ← modelo de car-following: Δx_s, v_i, aceleración, separaciones
│
├── inicializacion/
│   └── vehiculos.jl        ← distribución inicial de vehículos y definición de carriles
│
├── visualizacion/
│   └── dibujo.jl           ← plot(Auto), parabrisas, faros, líneas de carril
│
├── fantasmas/
│   ├── creacion.jl         ← proyección de cada vehículo en cada carril (fantasmas)
│   └── velocidad.jl        ← velocidad segura de cada fantasma; separacion_dos_autos
│
├── cambio_carril/
│   ├── geometria.jl        ← trayectoria circular, intersección con línea de carril,
│   │                          decide_cambiar_derecha / decide_cambiar_izquierda
│   ├── angulos.jl          ← estado de giro, corrección de ángulo, ordenar_carriles!
│   └── decision.jl         ← jerarquía de decisión completa, actualizar_angulo_giro
│
├── simulacion/
│   ├── un_carril.jl        ← avance sin cambio de carril (base de egoismo_velocidad)
│   ├── dos_carriles_sin_giro.jl  ← modo de referencia sin cambio de carril
│   ├── dos_carriles.jl     ← loop principal con cambio de carril
│   └── colisiones.jl       ← SAT + grilla espacial O(n)
│
├── utils/
│   └── distribucion.jl     ← egoismo_velocidad, distribución automática de vehículos
│
└── mediciones/
    ├── velocidades.jl      ← series temporales de velocidad y flujo
    ├── analisis.jl         ← suavizado, derivada numérica, t_crítico
    └── exportacion.jl      ← exportación CSV con CSV.jl / DataFrames.jl
```

El orden de los `include` en `trafico.jl` es determinista: cada módulo sólo ve los símbolos
de los módulos incluidos antes que él. Esta política elimina la necesidad de importaciones
explícitas dentro de cada archivo.

---

## Tipos Centrales

### `Auto` (`core/estructuras.jl`)

```julia
mutable struct Auto
    ancho     ::Union{Float64, Int64}
    largo     ::Union{Float64, Int64}
    posicion  ::Vector{Float64}          # centro del vehículo [x, y]
    esquinas  ::Vector{Vector{Float64}}  # 4 vértices del rectángulo (sentido antihorario)
    velocidad ::Vector{Float64}          # [vx, vy]
    direccion ::Vector{Float64}          # vector unitario de orientación
    color     ::RGB
    indice    ::Int64
end
```

Los operadores `+`, `−` y `mod` están sobrecargados para mover el rectángulo completo
(posición **y** esquinas) en una sola operación, manteniendo la coherencia geométrica.

### `Carril` (`core/estructuras.jl`)

```julia
mutable struct Carril
    ancho_carril  ::Union{Float64, Int64}
    inicio_fin    ::Vector{Float64}   # [x_min, x_max]
    indice_carril ::Int64
end
```

Los dos carriles tienen centros en `x = 0.5` (carril 1) y `x = 1.5` (carril 2), con ancho 1.0
cada uno.

---

## Flujo de Ejecución por Paso de Tiempo

Cada llamada a `avance_dos_carriles_con_giro_sin_anim` (o la versión animada) procesa los
`n + m` vehículos en **orden alternado** carril 1 / carril 2 de atrás hacia adelante. Para
cada vehículo `i`:

```
1. PROYECCIÓN DE FANTASMAS
   listas_carros_fantasmas(vehiculos)
   → fantasmas_1[i], fantasmas_2[i]  (proyecciones en carril 1 y 2)

2. SEPARACIONES Y VELOCIDADES SEGURAS
   separaciones_por_carriles_dos(...)
   velocidad_un_fantasmas(carril_1, fantasmas_1, ...)
   velocidad_un_fantasmas(carril_2, fantasmas_2, ...)

3. SELECCIÓN DE VELOCIDAD REAL
   escoje_velocidad_real!(...)
   → si gira: min(v1, v2)
   → si está en un carril: velocidad de ese carril

4. DECISIÓN DE CAMBIO DE CARRIL
   actualizar_angulo_giro(...)
   → calcula θ_vec[i] si se cumplen todas las condiciones

5. ACTUALIZACIÓN CINEMÁTICA
   velocidad_angular_carro_correcion!(vehiculos[i], δt, θ_vec[i])

6. CONDICIÓN PERIÓDICA
   limites_auto_carril(vehiculos[i], L)
   → si y > L: y -= L

7. DETECCIÓN DE COLISIONES (al final del paso completo)
   haySuperposicionesSAT_error(vehiculos, t; grilla=grilla)
```

---

## Sistema de Autos Fantasma

La técnica de **autos fantasma** es la pieza central para manejar vehículos en transición
entre carriles. Cuando un vehículo ocupa parcialmente dos carriles durante un giro, se crea
una proyección geométrica sobre cada carril. Cada fantasma:

- Comparte la velocidad en Y del vehículo real.
- Tiene largo 0 si el vehículo real sólo ocupa uno de los dos carriles.
- Permite calcular separaciones y velocidades seguras **independientemente por carril**.

```
Vehículo real (girando)         Carril 1        Carril 2
┌──────┐                        ┌──────┐        ┌──────┐
│  ╲   │         →              │fantas│   +    │fantas│
└───╲──┘                        └──────┘        └──────┘
```

---

## Grilla Espacial para Detección de Colisiones

La carretera se divide en celdas rectangulares de altura `h = 1.5 > diagonal_max ≈ 1.385`.
Cada vehículo se asigna a la celda de su posición central. La detección SAT sólo opera sobre
el vecindario 3×3 de cada celda, reduciendo la complejidad de O(n²) a O(n).

La frontera periódica en Y se gestiona con aritmética modular en el índice de fila, sin
estructuras adicionales.

```
┌────┬────┐  n_cols = 2 (un carril por columna)
│    │    │  n_filas = ceil(L / h)
├────┼────┤
│ i  │    │  auto i en celda (fila_c, col_c)
├────┼────┤  vecinos: (fila_c±1, col_c±1)
│    │    │
└────┴────┘
```

---

## Convenciones de Nomenclatura

| Convención | Significado |
|---|---|
| `!` al final | función que muta su primer argumento |
| `fantasmas_1` / `fantasmas_2` | proyecciones en carril 1 / carril 2 |
| `giro_nogiro[i]` | `1.0` si el vehículo i está girando, `0.0` si no |
| `carriles_original[i]` | carril de origen antes del giro (`0` = carril 1, `1` = carril 2) |
| `en_carril[i]` | tupla `(indice, en_carril_1::Bool, en_carril_2::Bool)` |
| `θ_vec[i]` | ángulo de giro asignado para el paso actual |
| `sep_fantasmas_k[i]` | separación del fantasma i con su líder en el carril k |

---

## Dependencias Externas

```julia
using Plots, Plots.PlotMeasures   # visualización y animación
using LinearAlgebra               # norm, dot, det
using Statistics                  # mean, std
using LaTeXStrings                # etiquetas de ejes
using YAML                        # carga de configuraciones
using CSV, DataFrames             # exportación de resultados
using Dates                       # timestamps de directorios de resultados
```
