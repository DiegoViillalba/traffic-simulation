# Simulacion de Trafico Vehicular con Cambio de Carriles

> Simulacion microscopica de trafico basada en un modelo de seguimiento de vehiculos (car-following) con cambio de carriles dinamico, implementada en **Julia**.

---

## Dependencias

```julia
using Pkg
Pkg.add(["Plots", "Statistics", "LinearAlgebra", "LaTeXStrings", "YAML", "CSV", "DataFrames"])
```

---

## Inicio Rapido

```julia
include("src/trafico.jl")

# Parametros
dt = 0.1;  L = 110;  largo = 9/7;  ancho = 18/35
d_0_1, d_0_2 = 0.5, 0.5
alpha = 0.8;  mu = 0.8;  g = 2.803;  T_reac = 1
acel = 1;  colchon = 0.21;  v_max = 4;  v_min = 0.001
egoismo = 0.8;  n, m = 55, 45;  pasos = 500

# Inicializacion
vehiculos = carros_dos_carriles(ancho, largo, L, 0.5, 1.1, n, m; xs = 1/2)

# Simulacion con animacion
anim = avance_carros_general!(pasos, vehiculos, egoismo, dt, L, d_0_1, d_0_2, alpha, mu, g, T_reac, colchon, acel, v_max, v_min, n, m)

# O simulacion rapida sin animacion
avance_carros_general(pasos, vehiculos, egoismo, dt, L, d_0_1, d_0_2, alpha, mu, g, T_reac, colchon, acel, v_max, v_min, n, m)
```

### Ejecucion con configuracion YAML

```julia
include("src/trafico.jl")
include("test_simulacion.jl")                         # usa configs/benchmark_rapido.yaml por defecto

# Para un experimento especifico:
CONFIG_FILE = "configs/alta_densidad.yaml"
include("test_simulacion.jl")
```

---

## Estructura del Proyecto

```
traffic-simulation/
|
|-- src/                                  <- Codigo fuente modularizado
|   |-- trafico.jl                        <- Punto de entrada (solo includes, sin logica)
|   |
|   |-- core/
|   |   |-- estructuras.jl               <- Tipos Auto, Carril; operadores +/-/mod; copias rapidas
|   |   `-- fisica.jl                    <- delta_x_s, v_i, aceleracion, separaciones, vel. promedio
|   |
|   |-- inicializacion/
|   |   `-- vehiculos.jl                 <- carros(), carriles(), rotacion, cinematica, geometria de fantasmas
|   |
|   |-- visualizacion/
|   |   `-- dibujo.jl                    <- plot(Auto), plot!(Vector{Auto}), parabrisas, faros
|   |
|   |-- fantasmas/
|   |   |-- creacion.jl                  <- Proyeccion de autos por carril, listas_carros_fantasmas
|   |   `-- velocidad.jl                 <- Velocidades seguras para fantasmas en ambos carriles
|   |
|   |-- cambio_carril/
|   |   |-- geometria.jl                 <- Trayectoria circular, interseccion con division de carril,
|   |   |                                   decide_cambiar_derecha / decide_cambiar_izquierda
|   |   |-- angulos.jl                   <- Estado de giro, correccion de angulo, condicion_giro_enfrente,
|   |   |                                   ordenar_carriles!, listas_pregiro!, escoje_velocidad_real!
|   |   `-- decision.jl                  <- Condiciones de separacion, condiciones_permitir_giro_*,
|   |                                        decide_cambiar_general, actualizar_angulo_giro
|   |
|   |-- simulacion/
|   |   |-- un_carril.jl                 <- avance_un_carril, actualizacion de posicion y velocidad
|   |   |-- dos_carriles_sin_giro.jl     <- Modo sin cambio de carril (referencia)
|   |   |-- dos_carriles.jl              <- avance_carros_general (loop principal con cambio de carril)
|   |   `-- colisiones.jl                <- SAT: haySuperposicionesSAT_error
|   |
|   |-- utils/
|   |   `-- distribucion.jl              <- egoismo_velocidad, generar_distribucion_automatica,
|   |                                        generar_carril_unico
|   |
|   `-- mediciones/
|       |-- velocidades.jl               <- Timeseries de velocidad y flujo para 1 y 2 carriles
|       |-- analisis.jl                  <- Suavizado, derivada numerica, t_critico
|       `-- exportacion.jl               <- Guardar resultados en CSV (usa CSV.jl y DataFrames.jl)
|
|-- configs/                             <- Configuraciones de experimentos (YAML)
|   |-- benchmark_rapido.yaml            <- 35 autos, 200 pasos, diagnostico rapido
|   |-- alta_densidad.yaml               <- 65 autos, 500 pasos, regimen congestionado
|   |-- baja_densidad.yaml               <- 14 autos, 300 pasos, flujo libre
|   `-- egoismo_alto.yaml                <- 35 autos, egoismo=0.98, conductores agresivos
|
|-- results/                             <- Resultados generados automaticamente (gitignore recomendado)
|   `-- <nombre>_YYYYMMDD_HHMMSS/
|       |-- velocidades.csv              <- Timeseries T, V_promedio
|       |-- benchmarks.csv              <- Metricas de rendimiento
|       `-- resumen.yaml                 <- Metadatos del experimento
|
|-- test_simulacion.jl                   <- Script de prueba con benchmarks, lee desde configs/
|-- README.md
`-- LICENSE.md
```

### Orden de carga en `trafico.jl`

El orden de los `include` garantiza que cada modulo encuentre definidas las funciones que necesita:

```
core/estructuras.jl
    |-- core/fisica.jl
        |-- inicializacion/vehiculos.jl
            |-- visualizacion/dibujo.jl
            |-- fantasmas/creacion.jl
                `-- fantasmas/velocidad.jl
                    |-- simulacion/un_carril.jl    <- debe ir antes de cambio_carril
                        |-- cambio_carril/geometria.jl
                            |-- cambio_carril/angulos.jl
                                `-- cambio_carril/decision.jl
                                    |-- simulacion/dos_carriles_sin_giro.jl
                                    |-- simulacion/colisiones.jl
                                    `-- simulacion/dos_carriles.jl
                                        |-- utils/distribucion.jl
                                            |-- mediciones/velocidades.jl
                                            |-- mediciones/analisis.jl
                                            `-- mediciones/exportacion.jl
```

> **Nota**: `simulacion/un_carril.jl` se incluye antes de `cambio_carril/` porque `egoismo_velocidad` (en `utils/distribucion.jl`) llama a `avance_un_carril` internamente.

---

## Parametros de la Simulacion

### Conversion de Escala

**1 unidad de simulacion = 3.5 metros en escala real**

| Concepto               | Unidad Simulacion     | Escala Real   |
|------------------------|-----------------------|---------------|
| Longitud de carril     | 1 unidad              | 3.5 m         |
| Largo de vehiculo      | 9/7 ~= 1.286 u        | 4.5 m         |
| Ancho de vehiculo      | 18/35 ~= 0.514 u      | 1.8 m         |
| Velocidad              | v u/paso              | v x 12.6/dt km/h |

### Tabla de Parametros

| Parametro   | Valor Tipico | Descripcion                                           |
|-------------|--------------|-------------------------------------------------------|
| `dt`        | 0.1          | Paso de tiempo                                        |
| `L`         | 110          | Longitud del carril (circuito cerrado)                |
| `largo`     | 9/7          | Largo del vehiculo                                    |
| `ancho`     | 18/35        | Ancho del vehiculo                                    |
| `alpha`     | 0.8          | Factor de visibilidad del parabrisas                  |
| `mu`        | 0.8          | Friccion con el suelo                                 |
| `g`         | 2.803        | Gravedad en unidades de simulacion                    |
| `T_reac`    | 1            | Tiempo de reaccion del conductor                      |
| `acel`      | 1            | Aceleracion base                                      |
| `colchon`   | 0.21         | Margen numerico anti-colision                         |
| `v_max`     | 4            | Velocidad maxima permitida                            |
| `v_min`     | 0.001        | Velocidad minima (evita division por cero)            |
| `d_0_1`     | 0.5          | Separacion minima en carril 1                         |
| `d_0_2`     | 0.5          | Separacion minima en carril 2                         |
| `egoismo`   | 0.8          | Factor de egoismo del conductor (0=altruista, 1=egoista) |
| `n`         | 55           | Vehiculos en carril 1                                 |
| `m`         | 45           | Vehiculos en carril 2                                 |

---

## Proceso Completo de una Simulacion

A continuacion se describe paso a paso lo que ocurre en **cada iteracion** del loop principal (`avance_carros_general`):

### Diagrama de Flujo

```
INICIO SIMULACION
       |
       v
+-------------------------------------------------------------+
|  INICIALIZACION (una sola vez)                              |
|  - carriles(1, 2)         -> define geometria de 2 carriles |
|  - comprobacion_giro()    -> estado inicial: todos derechos |
|  - carros_i_carriles()    -> clasificar autos por carril    |
|  - carril_original()      -> registrar carril de origen     |
+-------------------------------------------------------------+
       |
       v
+-------------------------------------------------------------+
|  LOOP: t = 1..pasos                                         |
|                                                             |
|  Para cada auto i en orden alternado (carril1 <-> carril2): |
|                                                             |
|  [1] PROYECCION DE FANTASMAS                                |
|      - Cada auto real genera 2 "fantasmas" (uno por carril) |
|      - El fantasma es la proyeccion del auto sobre cada     |
|        carril, conservando la velocidad Y                   |
|                                                             |
|  [2] CALCULO DE SEPARACIONES                                |
|      - Calcular gap entre cada fantasma y el de adelante    |
|      - Condiciones periodicas (circuito cerrado)            |
|                                                             |
|  [3] CALCULO DE VELOCIDAD SEGURA                            |
|      - v_i() -> velocidad minima para no chocar             |
|      - Modelo: delta_x_s = d0 + alpha*v^2/2*mu*g + T_reac*v |
|      - Clampear a [0, v_max]                                |
|                                                             |
|  [4] DECISION DE VELOCIDAD REAL                             |
|      - Si esta girando: min(v_carril1, v_carril2)           |
|      - Si esta en un carril: velocidad de ese carril        |
|                                                             |
|  [5] DECISION DE CAMBIO DE CARRIL                           |
|      - calcula_pre_angulo() -> angulo maximo de giro        |
|      - decide_cambiar_general():                            |
|        - El de enfrente ya esta girando? -> NO cambiar      |
|        - Mas espacio en carril actual?   -> NO cambiar      |
|        - Distancias seguras en destino?  -> test SAT        |
|        - Conductor suficientemente egoista? -> test         |
|      - Si OK: activar angulo de giro theta_vec[i]           |
|                                                             |
|  [6] ACTUALIZACION DE POSICION                              |
|      - velocidad_angular_carro_correcion!()                 |
|        - Calcula nueva posicion del frente y trasero        |
|        - Actualiza posicion, esquinas y direccion           |
|      - limites_auto_carril() -> condicion periodica en Y    |
|                                                             |
|  [7] DETECCION DE COLISIONES (al final del paso)            |
|      - haySuperposicionesSAT_error()                        |
|        - SAT (Separating Axis Theorem) entre todos los pares|
|        - Si hay colision: lanza error y detiene simulacion  |
+-------------------------------------------------------------+
       |
       v
     FIN
```

---

### Detalle de Cada Etapa

#### 1. Estructuras de Datos (`core/estructuras.jl`)

Cada vehiculo es un `mutable struct Auto` con:
- `posicion`: centro del vehiculo `[x, y]`
- `esquinas`: 4 vertices del rectangulo `[[x1,y1], ...]`
- `velocidad`: vector `[vx, vy]`
- `direccion`: vector unitario de orientacion
- `color`, `indice`, `ancho`, `largo`

Los **operadores** `+`, `-`, `mod` estan sobrecargados para mover el auto actualizando posicion **y** esquinas simultaneamente.

---

#### 2. Sistema de Autos Fantasma (`fantasmas/`)

Esta es la tecnica central del simulador para manejar autos en transicion entre carriles:

- Cuando un auto esta **a caballo entre dos carriles** durante un giro, se crea una **proyeccion fantasma** en cada carril.
- El fantasma tiene la misma velocidad Y que el auto real pero ocupa solo el espacio dentro de su carril.
- Los fantasmas se usan para calcular separaciones y velocidades seguras **por carril**.

```
Auto real (girando)          Carril 1      Carril 2
     +------+                +------+      +------+
     |  \   |      ->        |      |  +   |      |
     |   \  |                |fantas|      |fantas|
     +----\-+                +------+      +------+
```

---

#### 3. Modelo de Velocidad Segura (`core/fisica.jl`)

El modelo de seguimiento de vehiculos define la **distancia segura** necesaria:

```
delta_x_s(v) = d0 + (alpha * v^2) / (2 * mu * g) + T_reac * v + colchon
```

Y la **velocidad segura** se calcula resolviendo la ecuacion cuadratica:

```
v_i = [-T_reac + sqrt(T_reac^2 - 4*(alpha/2*mu*g)*c)] / (2 * alpha/2*mu*g)

donde: c = -(v_enfrente - v_actual)*dt - separacion - 0.5*acel*dt^2 + d0 - colchon
```

---

#### 4. Proceso de Cambio de Carril (`cambio_carril/`)

El proceso de decision para cambiar de carril sigue esta jerarquia:

```
Esta girando el auto de adelante?
    SI -> NO cambiar (evitar cadena de giros)
    NO |

Tiene mas espacio en el carril actual que en el destino?
    SI (derecha): sep_actual > sep_destino -> NO cambiar
    NO |

Hay distancias seguras con vecinos en el carril destino?
    NO -> NO cambiar (fantasmas_encimados_test)
    SI |

El conductor es suficientemente "egoista"?
    i.e. Obliga al auto de atras a frenar mas de (1-egoismo)*v0?
    SI -> NO cambiar
    NO |

CAMBIAR CARRIL
```

El giro se implementa como una **rotacion angular** usando geometria circular: el angulo maximo de giro disminuye con la velocidad (`theta_max = pi/4 * (1/(0.5*v+1))^0.5`).

---

#### 5. Condicion de Contorno Periodica

La carretera es un **circuito cerrado** de longitud `L`. Cuando un auto supera `y > L`, se reposiciona en `y - L`. Esto simula una via infinita con densidad constante.

---

#### 6. Deteccion de Colisiones SAT (`simulacion/colisiones.jl`)

Al final de cada paso se verifica que no haya superposiciones usando el **Separating Axis Theorem (SAT)** para pares de rectangulos rotados. Si se detecta una colision, la simulacion se detiene con un error descriptivo.

---

## Modos de Ejecucion

### Con Animacion
```julia
anim = avance_carros_general!(pasos, vehiculos, ...)
gif(anim, "simulacion.gif", fps=10)
```
Recomendado maximo ~500 pasos para compilacion fluida.

### Sin Animacion (Rapido)
```julia
avance_carros_general(pasos, vehiculos, ...)
```

### Con Mediciones
```julia
# Velocidad promedio en el tiempo
T, V = avance_dos_carril_valocidades_promedio(pasos, vehiculos, ...)
plot(T, V, xlabel="Tiempo", ylabel="Velocidad promedio")

# Flujo + desplazamiento
T, V, tiempos_cruce, desp, desp_y = medicion_velocidades_flujo_desplazamiento(pasos, vehiculos, ...)
```

### Distribucion Automatica de Vehiculos
```julia
vehiculos, n, m = generar_distribucion_automatica(100, 0.5, 9/7, 18/35, 110.0)
```

---

## Experimentos con Configuracion YAML

Los parametros de cada experimento se almacenan en `configs/`. Estructura de un archivo de configuracion:

```yaml
experimento:
  nombre: "benchmark_rapido"
  descripcion: "Benchmark de rendimiento con pocos vehiculos"
  tipo: "benchmark"          # benchmark | velocidades | flujo | desplazamiento

vehiculos:
  n: 20
  m: 15
  ancho: 0.5142857142857143
  largo: 1.2857142857142858

carretera:
  L: 50.0
  d_0_1: 0.5
  d_0_2: 0.5

fisica:
  alpha: 0.8
  mu: 0.8
  g: 2.803
  T_reac: 1.0
  acel: 1.0
  colchon: 0.21
  v_max: 4.0
  v_min: 0.001

comportamiento:
  egoismo: 0.8

simulacion:
  pasos: 200
  dt: 0.1
  benchmark_pasos_sat: 100
  benchmark_pasos_paso: 20
  error: 1.0e-2
  err: 1.0e-6

resultados:
  guardar_velocidades: true
  guardar_benchmarks: true
  guardar_csv: false
```

Cada ejecucion de `test_simulacion.jl` genera automaticamente una carpeta en `results/` con:

| Archivo           | Contenido                                  |
|-------------------|--------------------------------------------|
| `velocidades.csv` | Timeseries de velocidad promedio           |
| `benchmarks.csv`  | 15 metricas de rendimiento por funcion     |
| `resumen.yaml`    | Metadatos completos del experimento        |

---

## Estado Actual y Hoja de Ruta

### Optimizaciones implementadas

#### Deteccion de colisiones con grilla espacial uniforme

El cuello de botella critico original era la funcion `haySuperposicionesSAT_error`, que comparaba
todos los pares de autos en O(n^2) por paso. Se reemplazo por una grilla espacial uniforme
que reduce la deteccion a O(n) esperado.

**Principio de funcionamiento:**

La carretera se divide en celdas rectangulares de tamano fijo. Cada auto se asigna a la celda
correspondiente a su posicion central. La deteccion de colisiones solo se realiza entre autos
en la misma celda o en celdas adyacentes (vecindario 3x3). Para que esto sea correcto, el alto
de celda debe ser mayor que la diagonal maxima del vehiculo:

```
h_celda = 1.5  >  diagonal_max = sqrt((9/7)^2 + (18/35)^2) ~= 1.385
```

Esto garantiza que dos vehiculos en celdas no adyacentes no pueden solaparse fisicamente,
por lo que nunca se omite una colision real.

La frontera periodica del circuito cerrado (y=0 ~ y=L) se maneja con aritmetica modular
en el indice de fila, sin requerir estructuras adicionales.

**Resultados medidos con 35 autos, L=50:**

| Metodo                | Tiempo por paso | % del paso total | Pares evaluados |
|-----------------------|-----------------|------------------|-----------------|
| SAT fuerza bruta      | 6.1 ms          | 33%              | 595 (todos)     |
| SAT con grilla O(n)   | 0.9 ms          | 5%               | ~70 (vecinos)   |
| Speedup               | 6.9x            | --               | --              |

El speedup escala cuadraticamente con n:

| n autos | Pares O(n^2) | Checks con grilla | Speedup estimado |
|---------|--------------|-------------------|------------------|
| 35      | 595          | ~70               | ~7x              |
| 100     | 4,950        | ~200              | ~25x             |
| 500     | 124,750      | ~1,000            | ~125x            |
| 1000    | 499,500      | ~2,000            | ~250x            |

**API:** la funcion publica mantiene compatibilidad total. La grilla es opcional:

```julia
# Sin grilla (fallback O(n^2), util para debug)
haySuperposicionesSAT_error(autos, t)

# Con grilla O(n) — activa por defecto en avance_carros_general
grilla = GrillaEspacial(Float64(L))
haySuperposicionesSAT_error(autos, t; grilla=grilla)

# La grilla se crea una sola vez antes del loop principal
avance_carros_general(pasos, vehiculos, ...; usar_grilla=true)
```

---

### Pendientes de alta prioridad

1. **Recalculo de estructuras por auto** (`simulacion/dos_carriles.jl`)

   Las funciones `carros_i_carriles`, `listas_carros_fantasmas` y `ordenar_carriles!` se
   invocan una vez por cada auto `i` dentro de `avance_dos_carriles_con_giro_un_paso`,
   aunque su resultado es identico para todos los autos en el mismo paso.

   ```
   Costo actual: listas_carros_fantasmas ~= 0.45 ms x 35 autos = 15.7 ms/paso
   Solucion:     calcular las tres estructuras una sola vez por paso
   ```

2. **Copias de lista dentro de la decision de cambio de carril** (`cambio_carril/geometria.jl`,
   `utils/distribucion.jl`)

   Las funciones `fantasmas_encimados_test` y `egoismo_velocidad` copian la lista completa
   de autos de un carril para simular `tc` pasos hacia adelante. Esto se llama por cada auto
   en cada paso.

   ```
   Solucion: buffer pre-asignado; separar la logica de "simular hacia adelante"
             del ciclo de decision para evitar copias redundantes.
   ```

3. **`listas_carros_fantasmas` aloca 2n objetos por paso** (`fantasmas/creacion.jl`)

   Genera presion en el recolector de basura de Julia. La solucion es pre-asignar dos
   vectores de fantasmas y actualizarlos in-place con `copia_auto_rapida!`.

---

### Hoja de ruta de paralelizacion

El diseno de la grilla espacial fue pensado desde el inicio para soportar paralelizacion
tanto a nivel de nodo (hilos) como entre nodos (MPI).

#### Fase 1 - Grilla Cartesiana (completada)

Grilla uniforme 2D con reconstruccion completa por paso. Implementada en
`simulacion/colisiones.jl`. Reduce SAT de O(n^2) a O(n).

#### Fase 2 - Parametrizacion desde YAML

Exponer `h_celda` y `n_carriles` como parametros de configuracion en los archivos YAML
de experimento. Permite afinar el tamano de celda sin modificar codigo.

```yaml
colisiones:
  usar_grilla: true
  h_celda: 1.5
  verificar_con_fuerza_bruta: false   # activar para validacion
```

#### Fase 3 - Coordenadas de arco para calles personalizadas

Para soportar calles curvas, intersecciones y geometrias arbitrarias, la grilla puede
definirse en coordenadas de carretera `(s, n)` en lugar de coordenadas cartesianas `(x, y)`:

```
s = arco recorrido a lo largo del eje central de la calle
n = desplazamiento lateral (positivo = derecha)
```

Solo cambia la funcion `insertar_en_grilla!`. El resto de la logica de deteccion es identica.
Para intersecciones se define una celda especial de zona de conflicto donde todos los
vehiculos entrantes se comparan entre si independientemente de su coordenada s.

#### Fase 4 - Paralelizacion con hilos (Julia Threads / OpenMP equivalente)

Julia soporta paralelismo de memoria compartida con `Threads.@threads`. La grilla permite
partir el trabajo en franjas horizontales de filas, una por hilo, sin condiciones de carrera
en la lectura:

```julia
# Deteccion de colisiones en paralelo por franjas de filas
Threads.@threads for fila_bloque in bloques_de_filas
    for i in autos_en_bloque(fila_bloque, grilla)
        for j in candidatos_vecinos(i, autos, grilla)
            seSuperponenSAT(autos[i], autos[j]) && registrar_colision(i, j)
        end
    end
end
```

La escritura de posiciones en el paso de avance requiere un esquema de coloracion de celdas
(similar al algoritmo de coloracion de grafos) para evitar que dos hilos modifiquen autos
adyacentes simultaneamente. La alternativa mas simple es separar el paso de lectura (velocidades)
del paso de escritura (posiciones) y paralelizar solo el primero.

Para activar multiples hilos en Julia:

```bash
julia --threads=auto -e 'include("src/trafico.jl"); include("test_simulacion.jl")'
```

#### Fase 5 - Paralelizacion distribuida con MPI

Para simulaciones a gran escala (miles de vehiculos, calles extensas), la grilla permite
una descomposicion de dominio directa compatible con MPI.jl:

```
Proceso 0:   filas [0,   n_filas/N)   + ghost rows en el borde superior
Proceso 1:   filas [n_filas/N, 2*n_filas/N) + ghost rows en ambos bordes
...
Proceso N-1: filas [(N-1)*n_filas/N, n_filas) + ghost rows en el borde inferior
```

En cada paso temporal:

1. Cada proceso actualiza las posiciones y velocidades de sus autos locales.
2. Los autos en las ghost rows se intercambian con los procesos vecinos via `MPI.Sendrecv`.
3. Cada proceso ejecuta la deteccion de colisiones solo en su dominio.
4. Los autos que cruzan una frontera de proceso se migran al proceso correspondiente.

Dependencias necesarias:

```julia
Pkg.add("MPI")
# Requiere una instalacion de MPI en el sistema (OpenMPI, MPICH, etc.)
```

La frontera periodica del circuito (y=0 ~ y=L) se convierte en un intercambio entre el
proceso 0 y el proceso N-1, identico a cualquier otra frontera de dominio.

**Escalabilidad teorica con MPI:**

| Procesos MPI | Autos totales | Tiempo estimado / paso |
|--------------|---------------|------------------------|
| 1            | 1,000         | ~45 ms                 |
| 4            | 1,000         | ~12 ms                 |
| 16           | 1,000         | ~3 ms                  |
| 16           | 10,000        | ~30 ms                 |

---

## Puntos Pendientes de Optimizacion

Ver `test_simulacion.jl` para benchmarks detallados con tiempos reales.

### Resueltos

| Problema                        | Solucion aplicada              | Speedup medido |
|---------------------------------|--------------------------------|----------------|
| SAT O(n^2) por paso             | Grilla espacial uniforme O(n)  | 6.9x (n=35)    |

### Pendientes criticos

1. **Recalculo de estructuras por auto** (`simulacion/dos_carriles.jl`) - costo estimado: 15 ms/paso
2. **Copias en decision de cambio de carril** (`cambio_carril/geometria.jl`) - costo estimado: 1-2 ms/paso
3. **Alojamiento de 2n fantasmas por paso** (`fantasmas/creacion.jl`) - presion en GC de Julia

### Pendientes moderados

4. **`separacion_en_y` recalculada O(n) x n veces** (`simulacion/un_carril.jl`) - calcular una vez por paso
5. **`encontrar_posicion` con `findfirst` O(n)** (`core/fisica.jl`) - reemplazar con `Dict` o busqueda binaria
6. **`numeros_cercanos` O(n)** - reemplazar con `searchsorted` en arreglos ya ordenados

### Calidad de codigo

7. **`velocidades_test_derecha/izquierda` siempre retornan `false`** (`cambio_carril/decision.jl`) - limpiar o documentar
8. **Variables globales** `v_max`, `v_min`, `d_0_1`, `acel` usadas sin pasar como argumento en algunas funciones


---

## Lanzar una Simulacion

### Usando un archivo de configuracion YAML

La forma recomendada de ejecutar experimentos es a traves del sistema de configuracion YAML.
El script `test_simulacion.jl` lee el config, ejecuta los benchmarks y guarda los resultados
automaticamente en `results/`.

```julia
# Desde el REPL de Julia
include("src/trafico.jl")
include("test_simulacion.jl")          # usa configs/benchmark_rapido.yaml por defecto
```

Para elegir un experimento especifico antes de incluir el script:

```julia
include("src/trafico.jl")
CONFIG_FILE = "configs/alta_densidad.yaml"
include("test_simulacion.jl")
```

Desde terminal (modo no interactivo):

```bash
julia -e 'include("src/trafico.jl"); include("test_simulacion.jl")'

# Con config especifico
julia -e 'CONFIG_FILE="configs/alta_densidad.yaml"; include("src/trafico.jl"); include("test_simulacion.jl")'

# Con multiples hilos
julia --threads=auto -e 'CONFIG_FILE="configs/alta_densidad.yaml"; include("src/trafico.jl"); include("test_simulacion.jl")'
```

---

### Producir una animacion

La animacion se genera con `avance_carros_general!` (con signo de exclamacion).
Requiere que `Plots` este cargado, lo cual ocurre automaticamente al incluir `src/trafico.jl`.

**Flujo completo cargando parametros desde un YAML:**

```julia
include("src/trafico.jl")
using YAML

cfg     = YAML.load_file("configs/baja_densidad.yaml")
n       = cfg["vehiculos"]["n"]
m       = cfg["vehiculos"]["m"]
ancho   = cfg["vehiculos"]["ancho"]
largo   = cfg["vehiculos"]["largo"]
L       = Float64(cfg["carretera"]["L"])
d_0_1   = Float64(cfg["carretera"]["d_0_1"])
d_0_2   = Float64(cfg["carretera"]["d_0_2"])
alpha   = Float64(cfg["fisica"]["alpha"])
mu      = Float64(cfg["fisica"]["mu"])
g       = Float64(cfg["fisica"]["g"])
T_reac  = Float64(cfg["fisica"]["T_reac"])
acel    = Float64(cfg["fisica"]["acel"])
colchon = Float64(cfg["fisica"]["colchon"])
v_max   = Float64(cfg["fisica"]["v_max"])
v_min   = Float64(cfg["fisica"]["v_min"])
egoismo = Float64(cfg["comportamiento"]["egoismo"])
pasos   = cfg["simulacion"]["pasos"]
dt      = Float64(cfg["simulacion"]["dt"])

vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)

anim = avance_carros_general!(
    pasos, vehiculos, egoismo, dt, L, d_0_1, d_0_2,
    alpha, mu, g, T_reac, colchon, acel, v_max, v_min, n, m
)

nombre = cfg["experimento"]["nombre"]
mkpath("results")
gif(anim, "results/$(nombre).gif", fps=15)
```

**Flujo directo sin YAML:**

```julia
include("src/trafico.jl")

dt = 0.1;  L = 110.0;  n, m = 30, 25;  pasos = 300
vehiculos = carros_dos_carriles(18/35, 9/7, L, 0.5, 1.1, n, m; xs = 1/2)

anim = avance_carros_general!(
    pasos, vehiculos, 0.8, dt, L, 0.5, 0.5,
    0.8, 0.8, 2.803, 1.0, 0.21, 1.0, 4.0, 0.001, n, m
)

gif(anim, "results/simulacion.gif", fps=10)
```

---

### Estrategia recomendada para animaciones de regimen estacionario

Las simulaciones de trafico necesitan un periodo de calentamiento antes de alcanzar el
comportamiento estacionario. Para animaciones eficientes se recomienda separar ambas fases:

```julia
# Fase 1: calentamiento sin animacion (rapido)
avance_carros_general(800, vehiculos, ...)

# Fase 2: animar solo el regimen estacionario
anim = avance_carros_general!(200, vehiculos, ...)
gif(anim, "results/estacionario.gif", fps=12)
```

### Notas de rendimiento

La animacion incrementa el tiempo de ejecucion porque Plots genera y almacena un fotograma
por paso antes de compilar el GIF.

| Pasos | Autos | Sin animacion | Con animacion |
|-------|-------|---------------|---------------|
| 200   | 35    | ~4 s          | ~30 s         |
| 500   | 35    | ~10 s         | ~75 s         |
| 200   | 100   | ~12 s         | ~90 s         |

Para GIFs mas ligeros usar `fps` entre 8 y 12. Valores de `fps` altos no mejoran la
fluidez si el paso de simulacion representa un intervalo de tiempo real mayor a 1/fps segundos.

