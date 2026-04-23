"""
test_simulacion.jl
==================
Script de prueba configurable para la simulación de tráfico.
Lee un archivo YAML de `configs/`, ejecuta los benchmarks y guarda los
resultados en `results/<nombre_experimento>/`.

Uso:
    julia -e 'include("src/trafico.jl"); include("test_simulacion.jl")'

Para elegir un config distinto al por defecto:
    julia -e 'CONFIG_FILE="configs/alta_densidad.yaml"; include("src/trafico.jl"); include("test_simulacion.jl")'

O desde el REPL:
    include("src/trafico.jl")
    CONFIG_FILE = "configs/alta_densidad.yaml"
    include("test_simulacion.jl")
"""

using Statistics
using YAML
using CSV
using DataFrames
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# 1. CARGAR CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────

_config_path = isdefined(Main, :CONFIG_FILE) ? CONFIG_FILE : "configs/benchmark_rapido.yaml"

if !isfile(_config_path)
    error("❌ Archivo de config no encontrado: $_config_path\n" *
          "   Configs disponibles en configs/: " *
          join(basename.(filter(f -> endswith(f, ".yaml"), readdir("configs", join=true))), ", "))
end

cfg = YAML.load_file(_config_path)

# ── Extraer parámetros ────────────────────────────────────────────────────────
_exp     = cfg["experimento"]
_veh     = cfg["vehiculos"]
_carr    = cfg["carretera"]
_fis     = cfg["fisica"]
_comp    = cfg["comportamiento"]
_sim     = cfg["simulacion"]
_res     = cfg["resultados"]

nombre_exp  = _exp["nombre"]
tipo_exp    = _exp["tipo"]

n      = _veh["n"]
m      = _veh["m"]
ancho  = _veh["ancho"]
largo  = _veh["largo"]

L      = Float64(_carr["L"])
d_0_1  = Float64(_carr["d_0_1"])
d_0_2  = Float64(_carr["d_0_2"])

α      = Float64(_fis["alpha"])
μ      = Float64(_fis["mu"])
g      = Float64(_fis["g"])
T_reac = Float64(_fis["T_reac"])
acel   = Float64(_fis["acel"])
colchon = Float64(_fis["colchon"])
v_max  = Float64(_fis["v_max"])
v_min  = Float64(_fis["v_min"])

egoismo = Float64(_comp["egoismo"])

pasos       = _sim["pasos"]
δt          = Float64(_sim["dt"])
n_sat       = _sim["benchmark_pasos_sat"]
n_benchmark = _sim["benchmark_pasos_paso"]
error_tol   = Float64(_sim["error"])
err_dir     = Float64(_sim["err"])

guardar_vel  = _res["guardar_velocidades"]
guardar_bench = _res["guardar_benchmarks"]
guardar_csv  = _res["guardar_csv"]

# ─────────────────────────────────────────────────────────────────────────────
# 2. PREPARAR CARPETA DE RESULTADOS
# ─────────────────────────────────────────────────────────────────────────────

_timestamp   = Dates.format(now(), "yyyymmdd_HHMMSS")
_results_dir = joinpath("results", "$(nombre_exp)_$(_timestamp)")
mkpath(_results_dir)

# ─────────────────────────────────────────────────────────────────────────────
# 3. HEADER
# ─────────────────────────────────────────────────────────────────────────────

println("=" ^ 60)
println("  SIMULACIÓN DE TRÁFICO — $(uppercase(nombre_exp))")
println("=" ^ 60)
println("  Config:     $_config_path")
println("  Resultados: $_results_dir")
println()
println("📋 Parámetros del experimento:")
println("   Descripción: $(_exp["descripcion"])")
println("   Vehículos:   n=$n (carril 1), m=$m (carril 2) → $(n+m) total")
println("   Longitud:    L=$L  |  δt=$δt  |  pasos=$pasos")
println("   Tiempo sim.: $(round(pasos*δt, digits=1)) s  |  egoísmo=$egoismo")
println("   Velocidades: v_max=$v_max  |  v_min=$v_min")
println()

# ─────────────────────────────────────────────────────────────────────────────
# 4. INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────────────────────

println("🔧 Inicializando vehículos...")
t_init = @elapsed begin
    vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)
end
println("   ✅ $(length(vehiculos)) vehículos creados en $(round(t_init*1000, digits=2)) ms")

# ─────────────────────────────────────────────────────────────────────────────
# 5. BENCHMARKS
# ─────────────────────────────────────────────────────────────────────────────

bench_results = Dict{String, Any}()

# ── BENCHMARK 1: Un solo paso completo ────────────────────────────────────────
println("\n" * "─" ^ 50)
println("🔴 BENCHMARK 1: Costo de un solo paso de simulación")
println("─" ^ 50)

carriless     = carriles(1, 2)
giro_nogiro   = comprobacion_giro(vehiculos)
θ_vec         = zeros(length(vehiculos))
en_carril_ini = carros_i_carriles(vehiculos, carriless)
carriles_orig = carril_original(vehiculos, en_carril_ini)

t_paso_jit = @elapsed avance_dos_carriles_con_giro_sin_anim(
    vehiculos, θ_vec, carriless, carriles_orig, giro_nogiro,
    egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon,
    acel, v_max, v_min, n, m
)
println("   Primer paso (con JIT): $(round(t_paso_jit*1000, digits=2)) ms")

vehiculos     = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)
giro_nogiro   = comprobacion_giro(vehiculos)
θ_vec         = zeros(length(vehiculos))
en_carril_ini = carros_i_carriles(vehiculos, carriless)
carriles_orig = carril_original(vehiculos, en_carril_ini)

tiempos_paso = Float64[]
for _ in 1:n_benchmark
    t = @elapsed avance_dos_carriles_con_giro_sin_anim(
        vehiculos, θ_vec, carriless, carriles_orig, giro_nogiro,
        egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon,
        acel, v_max, v_min, n, m
    )
    push!(tiempos_paso, t)
end
t_paso_mean = mean(tiempos_paso) * 1000
t_paso_std  = std(tiempos_paso) * 1000
println("   Paso promedio (post-JIT, n=$(n+m)): $(round(t_paso_mean, digits=2)) ± $(round(t_paso_std, digits=2)) ms")
println("   Proyección $pasos pasos: ~$(round(t_paso_mean * pasos / 1000, digits=1)) s")

bench_results["paso_mean_ms"]   = round(t_paso_mean, digits=4)
bench_results["paso_std_ms"]    = round(t_paso_std, digits=4)
bench_results["paso_jit_ms"]    = round(t_paso_jit*1000, digits=4)
bench_results["proyeccion_s"]   = round(t_paso_mean * pasos / 1000, digits=2)

# ── BENCHMARK 2: SAT — O(n²) fuerza bruta vs Grilla O(n) ────────────────────
println("\n" * "─" ^ 50)
println("BENCHMARK 2: Deteccion de colisiones — O(n^2) vs Grilla O(n)")
println("─" ^ 50)

n_total = n + m
pares   = div(n_total * (n_total - 1), 2)
println("   Total de autos: $n_total  |  Pares O(n^2): $pares")

# Fuerza bruta
t_sat_bruto = @elapsed for _ in 1:n_sat
    haySuperposicionesSAT_error(vehiculos, 0)
end
t_sat_bruto_ms = t_sat_bruto / n_sat * 1000

# Con grilla espacial
grilla_bench = GrillaEspacial(Float64(L))
t_sat_grilla = @elapsed for _ in 1:n_sat
    haySuperposicionesSAT_error(vehiculos, 0; grilla=grilla_bench)
end
t_sat_grilla_ms = t_sat_grilla / n_sat * 1000

speedup_sat = t_sat_bruto_ms / max(t_sat_grilla_ms, 1e-9)
println("   SAT fuerza bruta : $(round(t_sat_bruto_ms, digits=3)) ms  ($(round(t_sat_bruto_ms/t_paso_mean*100,digits=1))% del paso)")
println("   SAT con grilla   : $(round(t_sat_grilla_ms, digits=3)) ms  ($(round(t_sat_grilla_ms/t_paso_mean*100,digits=1))% del paso)")
println("   Speedup          : $(round(speedup_sat, digits=1))x")

bench_results["sat_bruto_ms"]    = round(t_sat_bruto_ms, digits=4)
bench_results["sat_grilla_ms"]   = round(t_sat_grilla_ms, digits=4)
bench_results["sat_speedup"]     = round(speedup_sat, digits=2)
bench_results["sat_pct_total"]   = round(t_sat_bruto_ms / t_paso_mean * 100, digits=2)
bench_results["pares_comparados"] = pares

# ── BENCHMARK 3: Recálculo de estructuras ─────────────────────────────────────
println("\n" * "─" ^ 50)
println("🔴 BENCHMARK 3: Recálculo de estructuras en avance_un_paso")
println("─" ^ 50)

t_carros_i = @elapsed for _ in 1:1000
    carros_i_carriles(vehiculos, carriless)
end
t_ci_ms = t_carros_i / 1000 * 1000
println("   carros_i_carriles (por llamada): $(round(t_ci_ms, digits=3)) ms")
println("   Se llama $(n+m) veces por paso → $(round(t_ci_ms*(n+m), digits=2)) ms/paso")

t_fantasmas = @elapsed for _ in 1:100
    listas_carros_fantasmas(vehiculos)
end
t_fan_ms = t_fantasmas / 100 * 1000
println("   listas_carros_fantasmas (por llamada): $(round(t_fan_ms, digits=3)) ms")
println("   Se llama $(n+m) veces por paso → $(round(t_fan_ms*(n+m), digits=2)) ms/paso")
println()
println("   ⚠️  CUELLO DE BOTELLA: Recalculan para CADA auto i dentro del loop")
println("      → Calcular una sola vez por paso y pasar como argumento")

bench_results["carros_i_carriles_ms"]      = round(t_ci_ms, digits=4)
bench_results["listas_fantasmas_ms"]       = round(t_fan_ms, digits=4)
bench_results["costo_ci_por_paso_ms"]      = round(t_ci_ms*(n+m), digits=3)
bench_results["costo_fantasmas_por_paso_ms"] = round(t_fan_ms*(n+m), digits=3)

# ── BENCHMARK 4: Copias de listas ─────────────────────────────────────────────
println("\n" * "─" ^ 50)
println("🟡 BENCHMARK 4: copiar_lista_autos_rapida en decisión de carril")
println("─" ^ 50)

lista_test = vehiculos[1:n]
t_copy = @elapsed for _ in 1:10000
    copiar_lista_autos_rapida(lista_test)
end
t_copy_ms = t_copy / 10000 * 1000
println("   Copia de lista ($n autos): $(round(t_copy_ms, digits=4)) ms por llamada")
println("   2 copias por auto por paso → $(round(t_copy_ms * 2 * (n+m), digits=2)) ms/paso")
println()
println("   ⚠️  CUELLO DE BOTELLA: Copia + simulación interna en decisión de carril")

bench_results["copia_lista_ms"]        = round(t_copy_ms, digits=5)
bench_results["costo_copias_por_paso"] = round(t_copy_ms * 2 * (n+m), digits=3)

# ── BENCHMARK 5: separacion_en_y ─────────────────────────────────────────────
println("\n" * "─" ^ 50)
println("🟡 BENCHMARK 5: separacion_en_y en avance_carros_un_carril_individual")
println("─" ^ 50)

t_sep = @elapsed for _ in 1:10000
    separacion_en_y(vehiculos[1:n], L)
end
t_sep_ms = t_sep / 10000 * 1000
println("   separacion_en_y ($n autos): $(round(t_sep_ms, digits=4)) ms por llamada")
println("   Se llama $n veces → $(round(t_sep_ms * n, digits=2)) ms por paso")
println()
println("   ⚠️  CUELLO DE BOTELLA (menor): Calcular una vez por paso, no por auto")

bench_results["separacion_en_y_ms"]        = round(t_sep_ms, digits=5)
bench_results["costo_separacion_por_paso"] = round(t_sep_ms * n, digits=4)

# ─────────────────────────────────────────────────────────────────────────────
# 6. SIMULACIÓN COMPLETA
# ─────────────────────────────────────────────────────────────────────────────

println("\n" * "=" ^ 50)
println("▶️  SIMULACIÓN COMPLETA ($pasos pasos, $(n+m) autos)")
println("=" ^ 50)

vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)

t_total = @elapsed begin
    T, V = avance_dos_carril_valocidades_promedio(
        pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
        α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        error=error_tol, err=err_dir
    )
end

ρ₁ = round(n / (3.5 * L), digits=4)
ρ₂ = round(m / (3.5 * L), digits=4)
v_inicial = round(V[1], digits=4)
v_final   = round(V[end], digits=4)
v_global  = round(mean(V), digits=4)

println("   ✅ Simulación completada en $(round(t_total, digits=2)) s")
println("   Velocidad promedio inicial: $v_inicial u/paso")
println("   Velocidad promedio final:   $v_final u/paso")
println("   Velocidad promedio global:  $v_global u/paso")
println("   Densidad carril 1: ρ₁ = $ρ₁ veh/m")
println("   Densidad carril 2: ρ₂ = $ρ₂ veh/m")

# ─────────────────────────────────────────────────────────────────────────────
# 7. GUARDAR RESULTADOS
# ─────────────────────────────────────────────────────────────────────────────

println("\n💾 Guardando resultados en '$_results_dir'...")

# ── 7a. Timeseries de velocidades ─────────────────────────────────────────────
if guardar_vel
    df_vel = DataFrame(tiempo = T, velocidad_promedio = V)
    _path_vel = joinpath(_results_dir, "velocidades.csv")
    CSV.write(_path_vel, df_vel)
    println("   ✅ velocidades.csv  ($(length(T)) filas)")
end

# ── 7b. Benchmarks ────────────────────────────────────────────────────────────
if guardar_bench
    bench_rows = [(metrica=k, valor=v) for (k,v) in bench_results]
    df_bench = DataFrame(metrica = [r.metrica for r in bench_rows],
                         valor   = [r.valor   for r in bench_rows])
    _path_bench = joinpath(_results_dir, "benchmarks.csv")
    CSV.write(_path_bench, df_bench)
    println("   ✅ benchmarks.csv  ($(length(bench_rows)) métricas)")
end

# ── 7c. Resumen de experimento (YAML legible) ─────────────────────────────────
_summary = Dict(
    "experimento" => nombre_exp,
    "config_usado" => _config_path,
    "timestamp" => _timestamp,
    "n_vehiculos" => n + m,
    "pasos" => pasos,
    "tiempo_simulado_s" => pasos * δt,
    "tiempo_computo_s" => round(t_total, digits=3),
    "v_inicial" => v_inicial,
    "v_final"   => v_final,
    "v_global"  => v_global,
    "densidad_carril1" => ρ₁,
    "densidad_carril2" => ρ₂,
    "benchmarks" => bench_results
)
_path_summary = joinpath(_results_dir, "resumen.yaml")
YAML.write_file(_path_summary, _summary)
println("   ✅ resumen.yaml")

# ─────────────────────────────────────────────────────────────────────────────
# 8. TABLA DE CUELLOS DE BOTELLA
# ─────────────────────────────────────────────────────────────────────────────

println("\n" * "=" ^ 60)
println("📊 RESUMEN DE PUNTOS A OPTIMIZAR")
println("=" ^ 60)
println("""
┌───────────┬────────────────────────────────────────────┬──────────┐
│ Prioridad │ Problema                                   │ Impacto  │
├───────────┼────────────────────────────────────────────┼──────────┤
│ 🔴 ALTA   │ SAT O(n²) por paso                         │ Crítico  │
│ 🔴 ALTA   │ Recálculo de estructuras por auto          │ Crítico  │
│ 🔴 ALTA   │ copias+simulación en decisión carril       │ Alto     │
│ 🟡 MEDIA  │ separacion_en_y recalculada O(n) × n       │ Moderado │
│ 🟡 MEDIA  │ listas_carros_fantasmas aloca n objetos    │ Moderado │
│ 🟡 MEDIA  │ encontrar_posicion O(n) con closure        │ Moderado │
│ 🟢 BAJA   │ variables globales en egoismo_velocidad    │ Limpieza │
│ 🟢 BAJA   │ velocidades_test_* siempre false           │ Limpieza │
└───────────┴────────────────────────────────────────────┴──────────┘
""")

println("Archivos clave para optimizar:")
println("  • src/simulacion/dos_carriles.jl       (loop principal, recálculos)")
println("  • src/simulacion/colisiones.jl         (SAT O(n²))")
println("  • src/cambio_carril/geometria.jl       (copias en decisión)")
println("  • src/utils/distribucion.jl            (egoismo_velocidad)")
println()
println("✅ Test completado. Resultados en: $_results_dir")
