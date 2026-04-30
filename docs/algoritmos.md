# Algoritmos y Modelos Matemáticos

## 1. Modelo de Car-Following

### Distancia segura

La separación mínima que debe mantener un vehículo respecto al que tiene delante se modela
como la suma de tres componentes físicas más un margen numérico:

```
Δx_s(v) = d₀ + (α·v²)/(2·μ·g) + T_reac·v + colchon
```

| Término | Significado |
|---|---|
| `d₀` | separación mínima en reposo (longitud de seguridad de parada) |
| `(α·v²)/(2·μ·g)` | distancia de frenado aerodinámica (energía cinética / fricción) |
| `T_reac·v` | distancia recorrida durante el tiempo de reacción del conductor |
| `colchon` | margen numérico anti-colisión |

### Velocidad segura

La velocidad que el vehículo `j` debe adoptar para no violar `Δx_s` en el próximo paso se
obtiene resolviendo la ecuación cuadrática implícita:

```
a·v² + b·v + c = 0

donde:
  a = α / (2·μ·g)
  b = T_reac
  c = −(v_del_frente − v_j)·δt − separacion − ½·acel·δt² + d₀ − colchon
```

La raíz físicamente relevante es la positiva:

```
v_i = [−T_reac + √(T_reac² − 4·a·c)] / (2·a)
```

Si el discriminante es negativo (situación de emergencia numérica), se devuelve `v = 0`.

### Límites de velocidad

La velocidad calculada se acota en `[0, v_max]` a través de dos pasos:
1. Si `v > v_max`: recalcular con `acel_max = 4` u/paso² (límite de aceleración realista).
2. Si sigue por encima: clampear a `v_max`.
3. Si `v < 0`: recalcular con `acel_min = −10` u/paso².

---

## 2. Sistema de Autos Fantasma

Cuando un vehículo está en mitad de un cambio de carril, su footprint físico ocupa parcialmente
ambos carriles. Para poder calcular separaciones y velocidades por carril de forma independiente
se crean dos **fantasmas**:

- **Fantasma en carril k**: proyección del vehículo real sobre el eje central del carril k.
  - Misma posición en Y que el vehículo real.
  - Posición X fija en el centro del carril k.
  - Misma velocidad Y que el vehículo real.
  - Largo = 0 si el vehículo real no intersecta ese carril.

La función `carros_fantasmas_2` garantiza que siempre se devuelven exactamente 2 fantasmas,
incluso si el vehículo está completamente dentro de un solo carril (el segundo fantasma tiene
largo 0 para no generar separación ficticia).

---

## 3. Detección de Colisiones: SAT

El **Separating Axis Theorem (SAT)** para dos polígonos convexos `A` y `B` establece que
no se solapan si y sólo si existe al menos un eje separador: una dirección en la que las
proyecciones de ambos polígonos no se intersectan.

Para rectángulos rotados en 2D, los ejes a testear son las 4 normales a las aristas de ambos
rectángulos (en total 4, pero para rectángulos alineados son 2 por polígono).

```
Para cada eje e en {normales(A) ∪ normales(B)}:
    proyA = proyectar A sobre e  → [min_A, max_A]
    proyB = proyectar B sobre e  → [min_B, max_B]
    si [min_A, max_A] ∩ [min_B, max_B] = ∅:
        retornar NO_COLISIÓN   ← eje separador encontrado

retornar COLISIÓN             ← ningún eje separador existe
```

### Optimización con grilla espacial

La grilla espacial reduce el número de pares a evaluar de O(n²) a O(n):

```
1. Asignar cada vehículo i a su celda (fila_i, col_i):
     fila_i = floor(mod(y_i, L) / h)   mod L: periodicidad del circuito
     col_i  = clamp(floor(x_i), 0, n_cols−1)

2. Para cada vehículo i, evaluar SAT sólo con vehículos j > i
   en las 9 celdas del vecindario (fila_i±1, col_i±1):
     si seSuperponenSAT(i, j): error()
```

**Garantía de correctitud**: `h = 1.5 > diagonal_max = √((9/7)² + (18/35)²) ≈ 1.385`,
de modo que dos vehículos en celdas no adyacentes no pueden solaparse físicamente.

---

## 4. Cinemática de Cambio de Carril

El cambio de carril se implementa como una **rotación angular progresiva** a velocidad
constante, siguiendo una trayectoria circular.

### Ángulo máximo de giro

El ángulo máximo que puede girar un vehículo en un paso depende de su velocidad actual:

```
θ_max(v) = (π/4) · √(1 / (0.5·v + 1))
```

A velocidades altas el ángulo máximo decrece, garantizando trayectorias más suaves.

### Detección de fin del cambio de carril

El vehículo considera completado el cambio cuando su dirección converge a `[0, 1]`:

```julia
|direccion[1]| < err     # componente X pequeña
|1 − direccion[2]| < err  # componente Y ≈ 1
```

con `err = 1e-6` por defecto.

### Cálculo de la posición de cruce (`yc`, `tc`)

Para evaluar si el cambio de carril es seguro, se predice dónde cruzará la esquina frontal del
vehículo la línea divisoria de carriles (`x = 1`):

1. **Simular** 3 posiciones intermedias del vehículo con `velocidad_angular_carro_correcion!`.
2. **Ajustar** la circunferencia de giro pasando por esos 3 puntos.
3. **Resolver analíticamente** la intersección de esa circunferencia con `x = 1` → `yc`.
4. **Calcular** el tiempo `tc` como longitud de arco / velocidad.

`(yc, tc)` se usan luego en `fantasmas_encimados_test` y `egoismo_velocidad`.

---

## 5. Jerarquía de Decisión de Cambio de Carril

```
decide_cambiar_general(i, θ_propuesto, ...)
│
├─ [Bloqueo 1] ¿El vehículo de delante está girando?
│               → NO cambiar (evita cadenas de giros en cascada)
│
├─ [Bloqueo 2] ¿El carril actual tiene más espacio que el destino?
│  derecha:     sep_actual > sep_destino → NO cambiar
│  izquierda:   sep_actual < sep_destino → NO cambiar
│
├─ [Bloqueo 3] ¿Los vecinos en el carril destino estarán demasiado cerca en tc pasos?
│               fantasmas_encimados_test(yc, tc, ...) → NO cambiar si solapan
│
├─ [Bloqueo 4] ¿La distancia segura no se cumple con el vehículo de adelante en destino?
│               distancias_segura_ij(yc, tc, ...) → NO cambiar si no hay espacio
│
└─ [Bloqueo 5] ¿El cambio obliga al vehículo de atrás a frenar más de (1−egoismo)·v₀?
                egoismo_velocidad(...) → NO cambiar si el conductor no es suficientemente egoísta
                → CAMBIAR si pasa todos los filtros
```

### Modelo de egoísmo

El egoísmo de un conductor controla qué tan dispuesto está a forzar al vehículo de atrás a
frenar. El parámetro `egoismo ∈ [0, 1]`:

- `egoismo = 0`: completamente altruista; nunca cambia si obliga a frenar al de atrás.
- `egoismo = 1`: completamente egoísta; cambia sin importar el impacto en el de atrás.

La condición se evalúa simulando `tc/δt` pasos del carril destino hacia adelante y calculando
la velocidad segura que tendría el vehículo trasero con el nuevo intruso:

```
egoismo_velocidad = true   si   (1 − egoismo) > v_segura_trasero / v₀_trasero
```

Si `egoismo_velocidad = true`, el conductor rechaza el cambio (demasiado impacto en los demás).

---

## 6. Condición de Contorno Periódica

La carretera es un **circuito cerrado** de longitud `L`. La condición periódica se aplica en
dos niveles:

1. **Posiciones**: `limites_auto_carril` — si `y > L`, aplicar `y -= L`.
2. **Separaciones**: en `separacion_dos_autos` y `condiciones_en_la_separacion_*`,
   si el vehículo de adelante tiene `y < y_actual`, la separación se calcula como
   `L − (y_actual + l/2) + (y_adelante − l/2)`.
3. **Grilla**: el índice de fila se calcula con `mod(fila, n_filas)`, haciendo que la fila 0
   y la fila `n_filas−1` sean adyacentes.

---

## 7. Métricas de Tráfico

### Velocidad promedio

```
V̄(t) = (1/N) · Σᵢ |vᵢ(t)|
```

### Flujo de tráfico

```
J(t) = ρ · V̄(t)

donde ρ = N / (2·L)  (densidad lineal en ambos carriles)
```

### Velocidad terminal

La velocidad terminal `V_∞` se estima como la media de `V̄(t)` para `t > t_crítico`, donde
`t_crítico` es el tiempo en que la derivada `dV̄/dt` cae por debajo de un umbral.

### Diagrama fundamental

Para diferentes densidades `ρ`, la gráfica `J vs ρ` (o `V_∞ vs ρ`) es el diagrama fundamental
del tráfico. El simulador puede barrerse automáticamente sobre distintos valores de `n`, `m`
y `egoismo` para construirlo.
