# Líneas de Mejora Futuras

Este documento describe las extensiones de mayor impacto identificadas para el simulador,
organizadas por área. Las tres primeras secciones son las mejoras arquitecturales principales;
las restantes cubren rendimiento y calidad de código.

---

## 1. Número Arbitrario de Carriles

### Estado actual

El simulador está hardcodeado a exactamente 2 carriles. Las restricciones concretas son:

- `carriles(1, 2)` en `dos_carriles.jl` devuelve siempre 2 objetos `Carril`.
- El sistema de fantasmas crea exactamente 2 listas (`fantasmas_1`, `fantasmas_2`).
- La lógica de cambio de carril distingue solo `izquierda` vs `derecha` (binaria).
- La grilla espacial ya acepta `n_carriles` como parámetro (preparada para esto).
- Los índices de vehículos `1..n` (carril 1) y `n+1..n+m` (carril 2) no generalizan.

### Plan de implementación

**Paso 1 — Generalizar `Carril` y la función `carriles`**

```julia
# Actual
function carriles(ancho, n_carriles::Int=2)
    [Carril(ancho, [(k-1)*ancho, k*ancho], k) for k in 1:n_carriles]
end
```

**Paso 2 — Generalizar la indexación de vehículos**

Eliminar la dependencia en `n` y `m` como parámetros separados. Introducir un campo
`carril_actual::Int` en `Auto` o mantener un `Dict{Int,Int}` de `indice → carril`.

```julia
mutable struct Auto
    # ... campos existentes ...
    carril_actual ::Int   # ← nuevo campo
end
```

**Paso 3 — Generalizar el sistema de fantasmas**

Reemplazar `fantasmas_1`, `fantasmas_2` por un vector de vectores de longitud `K`:

```julia
fantasmas = [Vector{Auto}(undef, N) for k in 1:K]  # K carriles
```

**Paso 4 — Generalizar la decisión de cambio de carril**

La lógica binaria izquierda/derecha se convierte en: evaluar cambio a `carril_actual ± 1`,
con wraparound opcional para autopistas circulares.

**Paso 5 — Generalizar la inicialización**

```julia
function carros_multi_carriles(ancho, largo, L, d_0_vec::Vector, n_vec::Vector{Int}; xs=1/2)
    # d_0_vec[k] = separación mínima en carril k
    # n_vec[k]   = número de vehículos en carril k
    ...
end
```

**Paso 6 — Parámetros YAML**

```yaml
carretera:
  n_carriles: 4          # número de carriles
  d_0: [0.5, 0.5, 0.5, 0.5]   # separación mínima por carril
vehiculos:
  n_por_carril: [15, 20, 18, 12]  # vehículos por carril
```

### Impacto en el resto del código

| Módulo | Cambio requerido |
|--------|-----------------|
| `colisiones.jl` | Sólo cambiar `n_carriles` al construir `GrillaEspacial` |
| `angulos.jl` | `Angulo_giro_correcion` necesita conocer `K` carriles |
| `decision.jl` | Reemplazar funciones `_derecha`/`_izquierda` por `_carril_k` |
| `dos_carriles.jl` | Loop principal: iterar sobre `K` en lugar de 2 fijos |

---

## 2. Geometría de Carril Personalizada (basada en mapas)

### Estado actual

El simulador asume carriles rectos de longitud `L` con condición periódica. La coordenada `y`
es la posición a lo largo del carril y `x` es lateral. No existe soporte para curvatura,
pendientes o geometrías reales de calles.

### Arquitectura propuesta: coordenadas de arco (s, n)

La extensión más general es reemplazar el sistema de referencia cartesiano por **coordenadas
curvilíneas** de carretera:

```
s = distancia recorrida a lo largo del eje central de la vía
n = desviación lateral respecto al eje central (positivo = derecha)
```

Con este sistema, la lógica de car-following opera sobre `s` exactamente igual que sobre `y`,
y la geometría de la curva queda encapsulada en la transformación `(s, n) → (x, y)`.

**Paso 1 — Fuente de datos geométricos**

Importar la geometría de la vía desde:
- **OpenStreetMap (OSM)**: vía la API Overpass o archivos `.osm.pbf`.
- **GeoJSON/Shapefile**: formato estándar GIS.

Cada segmento de vía se describe como una polilínea de puntos `(lon, lat)`.

Librerías Julia útiles:
```julia
using LightOSM     # descarga y parseo de OSM
using GeoInterface  # abstracción GIS
using Proj         # transformaciones de proyección cartográfica
```

**Paso 2 — Discretización del eje central**

```julia
struct EjeCentral
    puntos   ::Vector{Vector{Float64}}  # [(x₁,y₁), (x₂,y₂), ...] en metros planos
    arcos    ::Vector{Float64}          # s[i] = distancia acumulada hasta punto i
    longitud ::Float64                  # L = arcos[end]
    curvatura::Vector{Float64}          # κ[i] = 1/radio en el punto i
end
```

**Paso 3 — Transformación de coordenadas**

```julia
# (s, n) → (x, y) mediante interpolación sobre el eje central
function sn_a_xy(eje::EjeCentral, s::Float64, n::Float64) :: Vector{Float64}
    # 1. Encontrar segmento: i tal que arcos[i] ≤ s < arcos[i+1]
    # 2. Interpolar tangente y normal en s
    # 3. xy = xy_central(s) + n * normal(s)
end
```

**Paso 4 — Adaptación del modelo de car-following**

En coordenadas `(s, n)`:
- La separación entre vehículos es `Δs - largo`.
- La velocidad de seguimiento opera sobre `ds/dt`.
- El cambio de carril es un cambio en `n` de `±ancho_carril`.

**Paso 5 — Adaptación de la grilla espacial**

```julia
# Celda en coordenadas de arco
fila_i = floor(Int, s_i / h)
col_i  = floor(Int, (n_i + n_max) / ancho_carril)
```

### Conexión con datos reales

Un flujo completo para una vía real:

```julia
using LightOSM

# Descargar grafo OSM de una zona
g = graph_from_bbox(lat_min, lon_min, lat_max, lon_max; network_type=:drive)

# Seleccionar una vía y extraer su geometría
via_id = 12345678
puntos = osm_geometry(g, via_id)

# Construir eje central
eje = EjeCentral(proyectar_a_plano(puntos))

# Inicializar vehículos sobre ese eje
vehiculos = carros_sobre_eje(eje, n_vec, d_0_vec, ancho_carril)
```

---

## 3. Distribuciones de Egoísmo por Vehículo

### Estado actual

El parámetro `egoismo` es un escalar global aplicado igual a todos los vehículos. Esto implica
una población homogénea de conductores.

### Propuesta: campo `egoismo` en `Auto`

**Paso 1 — Extender la estructura `Auto`**

```julia
mutable struct Auto
    # ... campos existentes ...
    egoismo ::Float64   # ← nuevo campo; reemplaza el parámetro global
end
```

**Paso 2 — Actualizar el constructor**

```julia
function Auto(ancho, largo, posicion, indice, velocidad, egoismo::Float64=0.8)
    # ...
    Auto(ancho, largo, posicion, esquinas, velocidad, direccion, color, indice, egoismo)
end
```

**Paso 3 — Propagar `egoismo` individual en la cadena de llamadas**

Reemplazar en `egoismo_velocidad`, `decide_cambiar_derecha` y `decide_cambiar_izquierda`:

```julia
# Antes:
egoismo_velocidad(a, egoismo, ...)  # egoismo es global

# Después:
egoismo_velocidad(a, a.egoismo, ...)  # leído del propio vehículo
```

**Paso 4 — Distribuciones de inicialización**

```julia
# Distribución uniforme
function asignar_egoismo_uniforme!(vehiculos, min=0.0, max=1.0)
    for v in vehiculos; v.egoismo = rand() * (max - min) + min; end
end

# Distribución normal truncada
function asignar_egoismo_normal!(vehiculos; μ=0.7, σ=0.15)
    dist = truncated(Normal(μ, σ), 0.0, 1.0)
    for v in vehiculos; v.egoismo = rand(dist); end
end

# Distribución beta (flexible, acotada en [0,1])
function asignar_egoismo_beta!(vehiculos; α=5.0, β=2.0)
    dist = Beta(α, β)
    for v in vehiculos; v.egoismo = rand(dist); end
end

# Distribución empírica desde datos de campo
function asignar_egoismo_empirico!(vehiculos, datos_campo::Vector{Float64})
    for (i, v) in enumerate(vehiculos)
        v.egoismo = datos_campo[mod1(i, length(datos_campo))]
    end
end
```

**Paso 5 — Configuración YAML**

```yaml
comportamiento:
  distribucion_egoismo:
    tipo:   "beta"       # uniforme | normal | beta | empirico | constante
    alpha:  5.0          # parámetros específicos según tipo
    beta:   2.0
    # Para "constante":    valor: 0.8
    # Para "uniforme":     min: 0.0,  max: 1.0
    # Para "normal":       mu: 0.7,   sigma: 0.15
    # Para "empirico":     archivo: "datos/egoismo_campo.csv"
```

**Paso 6 — Análisis de heterogeneidad**

Con `egoismo` por vehículo se pueden estudiar fenómenos nuevos:
- Cómo una minoría de conductores muy egoístas (cola pesada de la distribución) afecta el
  flujo global.
- Comparar `V_∞(ρ)` para poblaciones homogéneas vs heterogéneas con misma media de egoísmo.
- Correlacionar posición en el diagrama fundamental con la varianza de la distribución.

---

## 4. Rendimiento: Recálculo de Estructuras por Auto

### Problema

En `avance_dos_carriles_con_giro_sin_anim`, la función `avance_dos_carriles_con_giro_un_paso`
se llama `n + m` veces por paso. Dentro de ella, `carros_i_carriles` y `listas_carros_fantasmas`
se recalculan desde cero en cada llamada, aunque su resultado es idéntico para todos los
vehículos dentro del mismo paso.

**Coste estimado (n=35)**: ~15.7 ms/paso sólo en estas dos funciones.

### Solución

Calcular las estructuras una vez por paso y pasarlas a la función de avance individual:

```julia
function avance_dos_carriles_con_giro_sin_anim(...)
    # Calcular estructuras UNA VEZ
    en_carril_paso    = carros_i_carriles(vehiculos, carriless)
    fantasmas_1_paso, fantasmas_2_paso = listas_carros_fantasmas(vehiculos)
    carril_1_paso, carril_2_paso = ordenar_carriles!(vehiculos, en_carril_paso, giro_nogiro)

    for i in indices_alternados
        avance_carros(i, ..., en_carril_paso, fantasmas_1_paso, fantasmas_2_paso, ...)
        limites_auto_carril(vehiculos[i], L)
    end
end
```

**Ahorro estimado**: reducción de ~15 ms/paso → speedup de 2–3× en el loop principal.

**Nota**: este cambio altera la semántica de la simulación de "actualización secuencial con
estado compartido" a "actualización basada en snapshot del paso anterior". Para garantizar
comportamiento idéntico al actual, los fantasmas deben actualizarse desde el snapshot, no
desde el estado mutado dentro del mismo paso.

---

## 5. Rendimiento: Copias en la Decisión de Cambio de Carril

### Problema

`fantasmas_encimados_test` y `egoismo_velocidad` llaman a `copiar_lista_autos_rapida` y
`avance_un_carril` en cada evaluación de cambio de carril. Con `n + m = 35` vehículos:

- 2 copias de lista por vehículo = 70 copias/paso.
- Cada `avance_un_carril` con `tc/δt ≈ 5–10` pasos simula ~5–10 iteraciones internas.

**Coste estimado**: 1–3 ms/paso adicionales.

### Solución

Pre-asignar buffers reutilizables:

```julia
mutable struct BufferCambioCarril
    lista_copia_1 ::Vector{Auto}
    lista_copia_2 ::Vector{Auto}
end

function crear_buffer(n::Int)
    BufferCambioCarril(Vector{Auto}(undef, n), Vector{Auto}(undef, n))
end
```

Pasar el buffer a `egoismo_velocidad` y `fantasmas_encimados_test` para escribir en él
en lugar de alocar nuevo.

---

## 6. Rendimiento: `encontrar_posicion` y `numeros_cercanos`

### Problema

- `encontrar_posicion` usa `findfirst` con una lambda → O(n) por llamada.
- `numeros_cercanos` hace dos pasadas O(n) sobre el arreglo.
- Ambas se invocan O(n) veces por paso → O(n²) total.

### Solución

Los arreglos de posiciones Y ya están ordenados (los carriles se ordenan en `ordenar_carriles!`).
Reemplazar por búsqueda binaria:

```julia
using Base: searchsortedfirst, searchsortedlast

# En lugar de numeros_cercanos(arr, y):
idx = searchsortedfirst(arr_ordenado, y)
vecino_adelante = arr_ordenado[min(idx, end)]
vecino_atras    = arr_ordenado[max(idx-1, 1)]
```

**Ahorro**: O(n²) → O(n log n) en las funciones de separación de decisión.

---

## 7. Calidad de Código: Dependencias Implícitas en Globales

### Problema

Varias funciones acceden a variables definidas como globales en `launch.jl` sin recibirlas
como parámetros explícitos:

| Función | Variables implícitas |
|---------|---------------------|
| `egoismo_velocidad` | `v_max`, `v_min` |
| `distancias_segura_ij` | `acel`, `v_max`, `v_min` |
| `condiciones_permitir_giro_izquierda` | `d_0_1` |
| `fantasmas_encimados_test` | (hereda de sus llamadas) |

Esto impide ejecutar las funciones de forma aislada (tests unitarios, notebooks Jupyter,
llamadas desde scripts que no definen esas variables globales).

### Solución

Añadir los parámetros faltantes a las firmas de las funciones afectadas y actualizar todos
los call sites. Ejemplo para `egoismo_velocidad`:

```julia
# Antes:
function egoismo_velocidad(a, egoismo, yc, tc, δt, lista_carril2, i, j, L, d_0, α, μ, g, T_reac, acel, colchon)
    avance_un_carril(..., acel, v_max, v_min)  # v_max, v_min son globales

# Después:
function egoismo_velocidad(a, egoismo, yc, tc, δt, lista_carril2, i, j, L, d_0, α, μ, g, T_reac, acel, colchon, v_max, v_min)
    avance_un_carril(..., acel, v_max, v_min)  # recibidas como argumento
```

---

## 8. Paralelización con Julia Threads

Una vez resueltos los cuellos de botella de rendimiento serial, el paso natural es paralelizar
el loop de detección de colisiones. La grilla espacial ya está diseñada para soportarlo:

```julia
# Partición del trabajo por franjas de filas
Threads.@threads for bloque in dividir_filas(grilla, Threads.nthreads())
    for i in autos_en_bloque(bloque, grilla)
        for j in candidatos_vecinos(i, autos, grilla)
            seSuperponenSAT(autos[i], autos[j]) && error(...)
        end
    end
end
```

La actualización de posiciones requiere un esquema de **coloración de celdas** para evitar
condiciones de carrera entre hilos que modifican vehículos adyacentes simultáneamente.

---

## Resumen de Prioridades

| # | Mejora | Impacto | Complejidad |
|---|--------|---------|-------------|
| 1 | Número arbitrario de carriles | Alto (generalidad) | Media |
| 2 | Geometría desde mapas | Alto (realismo) | Alta |
| 3 | Egoísmo por vehículo | Medio (riqueza del modelo) | Baja |
| 4 | Recálculo de estructuras por auto | Alto (rendimiento ~3×) | Baja |
| 5 | Pre-asignación de buffers | Medio (rendimiento) | Baja |
| 6 | Búsqueda binaria en separaciones | Medio (rendimiento) | Baja |
| 7 | Eliminar dependencias en globales | Bajo (testabilidad) | Baja |
| 8 | Paralelización con Threads | Alto (escala) | Media |
