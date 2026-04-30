# Referencia de Configuración YAML

Todos los experimentos se describen en archivos YAML dentro de `configs/`. El script
`launch.jl` los carga y expone cada parámetro como variable global antes de iniciar la
simulación.

## Estructura Completa

```yaml
experimento:
  nombre:      "nombre_del_experimento"  # string; usado para nombrar el directorio de resultados
  descripcion: "descripción libre"
  tipo:        "velocidades"             # ver tabla de tipos abajo

vehiculos:
  n:     20           # vehículos en carril 1
  m:     15           # vehículos en carril 2
  ancho: 0.5143       # ancho del vehículo [unidades de simulación]
  largo: 1.2857       # largo del vehículo [unidades de simulación]

carretera:
  L:     50.0         # longitud del circuito [unidades de simulación]
  d_0_1: 0.5          # separación mínima en reposo, carril 1
  d_0_2: 0.5          # separación mínima en reposo, carril 2

fisica:
  alpha:  0.8         # coeficiente de resistencia aerodinámica
  mu:     0.8         # coeficiente de rozamiento con el suelo
  g:      2.803       # gravedad efectiva [unidades de simulación]
  T_reac: 1.0         # tiempo de reacción del conductor [pasos]
  acel:   1.0         # aceleración base para el modelo de velocidad segura
  colchon: 0.21       # margen numérico anti-colisión
  v_max:  4.0         # velocidad máxima permitida [u/paso]
  v_min:  0.001       # velocidad mínima (evita división por cero) [u/paso]

comportamiento:
  egoismo: 0.8        # factor de egoísmo del conductor ∈ [0, 1]

simulacion:
  pasos: 200          # número de pasos de tiempo
  dt:    0.1          # intervalo de tiempo por paso
  benchmark_pasos_sat:  100   # pasos para benchmark de colisiones SAT
  benchmark_pasos_paso: 20    # pasos para benchmark del loop completo
  error: 1.0e-2       # tolerancia para corrección de ángulo de giro
  err:   1.0e-6       # tolerancia para detección de fin de giro

resultados:
  guardar_velocidades: true   # exportar velocidades.csv
  guardar_benchmarks:  true   # exportar benchmarks.csv
  guardar_csv:         false  # exportar datos completos adicionales
```

---

## Tipos de Experimento

| `tipo`           | Descripción                                                        |
|------------------|--------------------------------------------------------------------|
| `velocidades`    | Mide V̄(t): velocidad promedio en el tiempo                        |
| `flujo`          | Mide J(t) = ρ·V̄(t): flujo de tráfico                             |
| `desplazamiento` | Mide el desplazamiento total acumulado de los vehículos            |
| `benchmark`      | Ejecuta la suite completa de benchmarks de rendimiento             |

---

## Parámetros Detallados

### Vehículos

| Parámetro | Valor típico | Escala real | Notas |
|-----------|-------------|-------------|-------|
| `ancho`   | 18/35 ≈ 0.514 u | 1.8 m | Ancho de carril = 1.0 u → ancho vehículo ≈ 51% |
| `largo`   | 9/7 ≈ 1.286 u | 4.5 m | Diagonal máx ≈ 1.385 u → h_celda > 1.385 |

### Carretera

| Parámetro | Notas |
|-----------|-------|
| `L`       | Longitud del circuito. Recomendado `L ≥ (n+m)·(largo + d_0) / 2` para evitar solapamiento inicial. La función `generar_distribucion_automatica` calcula el `L` mínimo automáticamente. |
| `d_0_1/2` | Separaciones mínimas independientes por carril. Usar valores distintos para modelar diferencias en condiciones de cada carril. |

### Física

| Parámetro | Notas |
|-----------|-------|
| `alpha`   | Mayor valor → mayor distancia de frenado a velocidades altas. Representa resistencia aerodinámica. |
| `mu`      | Mayor valor → menor distancia de frenado (más agarre). |
| `g`       | No es la gravedad real. Es un factor de escala para el modelo cuadrático de frenado. Valor por defecto `2.803 ≈ g_real / 3.5` (escala de simulación). |
| `T_reac`  | En pasos de tiempo. Con `dt = 0.1`, `T_reac = 1` equivale a 0.1 s (muy bajo) o se interpreta directamente en la ecuación de movimiento como un paso de reacción. |
| `colchon` | Margen numérico para evitar que SAT detecte falsas colisiones por errores de punto flotante. |
| `v_max`   | Velocidad máxima en unidades de simulación. Con `dt = 0.1`, `v_max = 4` → `4 × 12.6 / 0.1 = 504 km/h`. Ajustar `dt` para escalar velocidades. |
| `v_min`   | Evita divisiones por cero en el modelo de egoísmo. Mantener en `0.001`. |

### Comportamiento

| Parámetro | Notas |
|-----------|-------|
| `egoismo` | `0.0` = completamente altruista (nunca molesta al de atrás). `1.0` = completamente egoísta (cambia sin considerar al de atrás). Valor `0.8` reproduce comportamiento de conductor promedio agresivo. |

### Simulación

| Parámetro | Notas |
|-----------|-------|
| `dt`      | Paso de tiempo. Reducir para mayor precisión; aumentar para mayor velocidad. La condición de estabilidad del modelo no está analíticamente garantizada para `dt` grandes. |
| `error`   | Tolerancia geométrica para detectar cuándo la esquina del vehículo ha llegado al centro del carril destino. Si es muy pequeño, el giro nunca termina; si es muy grande, el vehículo "salta" al otro carril. |
| `err`     | Tolerancia para detectar que el vector dirección es `[0, 1]` (vehículo recto). Debe ser más pequeño que `error`. |

---

## Configs Disponibles

| Archivo | Tipo | Vehículos | Pasos | Propósito |
|---------|------|-----------|-------|-----------|
| `benchmark_rapido.yaml` | benchmark | 20+15 | 200 | Diagnóstico rápido de rendimiento |
| `alta_densidad.yaml` | velocidades | 35+30 | 500 | Régimen congestionado |
| `baja_densidad.yaml` | velocidades | 8+6 | 300 | Flujo libre |
| `egoismo_alto.yaml` | velocidades | 20+15 | — | Conductores agresivos (egoismo=0.98) |
| `tesis_zuriel.yaml` | — | — | — | Experimento de tesis específico |

---

## Uso desde CLI (`launch.jl`)

```bash
# Experimento por defecto
julia launch.jl

# Config específico
julia launch.jl --config configs/alta_densidad.yaml

# Con animación GIF
julia launch.jl --config configs/baja_densidad.yaml --animacion --fps 15

# Sobrescribir número de pasos
julia launch.jl --config configs/alta_densidad.yaml --pasos 1000

# Benchmark de rendimiento
julia launch.jl --benchmark

# Desactivar grilla espacial (modo debug O(n²))
julia launch.jl --sin-grilla

# Fase de calentamiento antes de animar
julia launch.jl --calentamiento 500 --animacion

# Múltiples hilos Julia
julia --threads=auto launch.jl --config configs/alta_densidad.yaml

# Listar configs disponibles
julia launch.jl --lista
```

---

## Resultados Generados

Cada ejecución crea un directorio `results/<nombre>_YYYYMMDD_HHMMSS/` con:

| Archivo | Contenido |
|---------|-----------|
| `velocidades.csv` | Columnas `T`, `V`: serie temporal de velocidad promedio |
| `benchmarks.csv` | 15 métricas de rendimiento por función |
| `resumen.yaml` | Todos los parámetros del experimento + métricas finales |

---

## Conversión de Escala

**1 unidad de simulación = 3.5 metros**

| Magnitud | Fórmula de conversión |
|----------|-----------------------|
| Velocidad | `v [km/h] = v_sim × 3.5 × 3600 / (dt × 1000)` |
| Con dt=0.1 | `v [km/h] = v_sim × 126` |
| `v_max = 4` | ≈ 504 km/h (usar dt mayor para velocidades realistas) |
| `v_max = 4`, `dt=0.5` | ≈ 100 km/h |
| Distancia | `d [m] = d_sim × 3.5` |
| Largo vehículo 9/7 u | ≈ 4.5 m |
| Ancho vehículo 18/35 u | ≈ 1.8 m |
