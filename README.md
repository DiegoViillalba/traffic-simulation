# 🚦 Simulación de Tráfico Vehicular con Cambio de Carriles

## 📦 Dependencias

Asegúrate de tener instalados estos paquetes de Julia:

```julia
using Pkg
Pkg.add(["Plots", "Statistics", "LinearAlgebra"])
```
## 🚀 Inicio Rápido

Para comenzar una simulación, ejecuta:

```julia
include("trafico.jl")
```

### 🔄 Conversión de Escala
**Todas las medidas en la simulación usan la siguiente equivalencia:**
1 unidad de simulación = 3.5 metros en escala real

### 📏 Tabla de Conversiones
| Concepto | Unidad Simulación | Escala Real | Conversión |
|----------|-------------------|-------------|------------|
| Longitud de carril | 1 unidad | 3.5 metros | × 3.5 |
| Longitud de vehículo | 9/7 ≈ 1.286 unidades | 4.5 metros | (9/7) × 3.5 |
| Ancho de vehículo | 18/35 ≈ 0.514 unidades | 1.8 metros | (18/35) × 3.5 |
| Separación entre vehículos | d unidades | d × 3.5 metros | × 3.5 |
| Velocidad | v unidades/paso | v × 3.5 × (3.6/δt) km/h | × (12.6/δt) |

⚙️ Parámetros de Simulación
Valores Necesarios para Configuración


```julia
# Paso de tiempo de la simulación
δt = 0.1

# Separaciones de carriles sin movimiento (distancias seguras)
d_0_1, d_0_2 = 0.5, 0.5

# Dimensiones de los vehículos
largo = 9/7      # Longitud del carro (unidades de simulación)
ancho = 18/35    # Ancho del carro (unidades de simulación)

# Parámetros de comportamiento
α = 0.8          # Factor de aceleración (tiene que ver con la vilisibilidad en el parabrisas)
μ = 0.8          # Friccion con el suelo
g = 2.803        # Aceleracion de la gravedad (unidades de simulación)
T_reac = 1       # Tiempo de reacción
acel = 1         # Aceleración base

# Parámetro de seguridad numérica
colchon = 0.21   # Margen para errores numéricos y prevención de colisiones
                 # (valor seguro para δt = 0.1)

# Límites de velocidad
v_max = 4        # Velocidad máxima
v_min = 0.001    # Velocidad mínima (evita división por cero)

# Configuración de la vía
L = 110          # Longitud del carril (unidades de simulación)

# Separaciones iniciales por carril
d1, d2 = 0.5, 1.1  # Distancias entre vehículos en carril 1 y 2

# Densidad vehicular
n, m = 55, 45     # Número de vehículos en carril 1 y 2

# Factor de comportamiento
egoismo = 0.8     # Nivel de comportamiento egoísta en cambios de carril (0 a 1)

# Tiempo de simulación
pasos = 10000     # Número de pasos de simulación (para gif tal vez es muy alto)
```


## 🚗 Inicialización de Vehículos

### 🛣️ Configuración de Carriles
Los vehículos se distribuyen en dos carriles con las siguientes coordenadas:
- **Carril 1**: Posición Y = 0 (eje inferior)
- **Carril 2**: Posición Y = 1 (eje superior)

### 📦 Creación de la Flota Vehicular
Para inicializar los vehículos en ambos carriles:
```julia
vehiculos = carros_dos_carriles(ancho, largo, L, d1, d2, n, m; xs = 1/2)
```
**Parámetros:**
- `ancho`: Ancho de cada vehículo
- `largo`: Largo de cada vehículo  
- `L`: Longitud total del carril
- `d1`: Separación inicial entre vehículos en carril 1
- `d2`: Separación inicial entre vehículos en carril 2
- `n`: Número de vehículos en carril 1 (Y=0)
- `m`: Número de vehículos en carril 2 (Y=1)
- `xs`: Posición horizontal inicial (centrado por defecto con 1/2)

## 🎯 Modos de Ejecución

### 🎥 Simulación con Animación (Visualización en Tiempo Real)
Para realizar una simulación con animación gráfica, usar:
```julia
avance_carros_general!(pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m; error = 1e-2, err = 1e-6,kargs...)
```
**⚠️ IMPORTANTE:** Para una compilación rápida con animación, se recomienda NO usar más de 1000 pasos.

### ⚡ Simulación Rápida (Sin Animación)
Para avanzar los autos rápidamente sin visualización, usar:
```julia
avance_carros_general(pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m; error = 1e-2, err = 1e-6)
```
**✅ Este modo es más rápido y permite mayor número de pasos**
