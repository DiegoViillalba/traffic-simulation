#!/usr/bin/env julia
"""
launch.jl — Punto de entrada CLI para la simulacion de trafico vehicular.

Uso:
    julia [--threads=N] launch.jl [opciones]

Opciones:
    --config ARCHIVO        Archivo YAML de configuracion
                            (default: configs/benchmark_rapido.yaml)
    --animacion             Producir animacion GIF al terminar
    --fps N                 Fotogramas por segundo del GIF (default: 12)
    --calentamiento N       Pasos sin animacion antes de animar (default: 0)
    --pasos N               Sobreescribir el numero de pasos del config
    --benchmark             Ejecutar suite de benchmarks de rendimiento
    --sin-grilla            Desactivar grilla espacial (modo fuerza bruta O(n^2))
    --sin-interacciones     No medir interacciones/entropia (mas rapido)
    --d-interaccion X       Umbral de vecindad [u] para contar interacciones
                            (default: d_0 + largo_auto)
    --output DIR            Directorio base para resultados (default: results)
    --lista                 Listar configs disponibles y salir
    -h, --help              Mostrar esta ayuda y salir

Ejemplos:
    julia launch.jl
    julia launch.jl --config configs/alta_densidad.yaml
    julia launch.jl --config configs/alta_densidad.yaml --pasos 2000
    julia launch.jl --config configs/baja_densidad.yaml --animacion --fps 15
    julia launch.jl --config configs/benchmark_rapido.yaml --benchmark
    julia --threads=auto launch.jl --config configs/alta_densidad.yaml
    julia launch.jl --sin-interacciones   # omite medicion de entropia
    julia launch.jl --lista

Lanzamiento en servidor (modo desatendido):
    nohup julia --threads=auto launch.jl --config configs/alta_densidad.yaml \\
          --pasos 5000 --output results > logs/run.log 2>&1 &
    echo "PID: \$!"
"""

# ─────────────────────────────────────────────────────────────────────────────
# 0. Directorio de trabajo + activar entorno del proyecto
# ─────────────────────────────────────────────────────────────────────────────
cd(@__DIR__)

using Pkg
Pkg.activate(@__DIR__; io=devnull)

using Statistics
using Dates
using YAML
using CSV
using DataFrames
using TraficoSimulacion

# ─────────────────────────────────────────────────────────────────────────────
# 1. PARSEO DE ARGUMENTOS CLI
# ─────────────────────────────────────────────────────────────────────────────

function parsear_args(args)
    params = Dict{String,Any}(
        "config"            => "configs/benchmark_rapido.yaml",
        "animacion"         => false,
        "fps"               => 12,
        "calentamiento"     => 0,
        "pasos"             => nothing,
        "benchmark"         => false,
        "grilla"            => true,
        "interacciones"     => true,      # medir vecinos/entropia por defecto
        "d_interaccion"     => nothing,   # nothing = usar d_0 + largo_auto
        "output"            => "results",
        "lista"             => false,
        "help"              => false,
    )

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg in ("-h", "--help")
            params["help"] = true
        elseif arg == "--lista"
            params["lista"] = true
        elseif arg == "--animacion"
            params["animacion"] = true
        elseif arg == "--benchmark"
            params["benchmark"] = true
        elseif arg == "--sin-grilla"
            params["grilla"] = false
        elseif arg == "--sin-interacciones"
            params["interacciones"] = false
        elseif arg in ("--config", "--fps", "--calentamiento", "--pasos",
                       "--output", "--d-interaccion")
            if i >= length(args)
                println("Error: '$arg' requiere un valor.")
                exit(1)
            end
            i += 1
            val = args[i]
            if arg == "--config"
                params["config"] = val
            elseif arg == "--fps"
                params["fps"] = parse(Int, val)
            elseif arg == "--calentamiento"
                params["calentamiento"] = parse(Int, val)
            elseif arg == "--pasos"
                params["pasos"] = parse(Int, val)
            elseif arg == "--output"
                params["output"] = val
            elseif arg == "--d-interaccion"
                params["d_interaccion"] = parse(Float64, val)
            end
        else
            println("Advertencia: argumento desconocido '$arg' ignorado.")
        end
        i += 1
    end
    return params
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. AYUDA Y LISTADO
# ─────────────────────────────────────────────────────────────────────────────

function mostrar_ayuda()
    println("""
    launch.jl — Simulacion de Trafico Vehicular

    Uso:
        julia [--threads=N] launch.jl [opciones]

    Opciones:
        --config ARCHIVO        Archivo YAML de configuracion
                                (default: configs/benchmark_rapido.yaml)
        --animacion             Producir animacion GIF al terminar
        --fps N                 Fotogramas por segundo del GIF (default: 12)
        --calentamiento N       Pasos sin animacion antes de animar (default: 0)
        --pasos N               Sobreescribir el numero de pasos del config
        --benchmark             Ejecutar suite de benchmarks de rendimiento
        --sin-grilla            Desactivar grilla espacial (O(n^2) fuerza bruta)
        --sin-interacciones     No medir interacciones ni entropia (mas rapido)
        --d-interaccion X       Umbral de vecindad [u] para contar interacciones
        --output DIR            Directorio base para resultados (default: results)
        --lista                 Listar configs disponibles y salir
        -h, --help              Mostrar esta ayuda y salir

    Ejemplos:
        julia launch.jl
        julia launch.jl --config configs/alta_densidad.yaml --pasos 2000
        julia launch.jl --config configs/baja_densidad.yaml --animacion --fps 15
        julia launch.jl --benchmark
        julia --threads=auto launch.jl --config configs/alta_densidad.yaml
        julia launch.jl --sin-interacciones
        julia launch.jl --lista
    """)
end

function listar_configs()
    dir = "configs"
    archivos = filter(f -> endswith(f, ".yaml") || endswith(f, ".yml"),
                      readdir(dir, join=false))
    if isempty(archivos)
        println("No se encontraron archivos YAML en '$dir/'.")
        return
    end
    println("Configs disponibles en '$dir/':")
    println()
    for f in sort(archivos)
        ruta = joinpath(dir, f)
        try
            c = YAML.load_file(ruta)
            nombre = get(get(c, "experimento", Dict()), "nombre", f)
            desc   = get(get(c, "experimento", Dict()), "descripcion", "sin descripcion")
            tipo   = get(get(c, "experimento", Dict()), "tipo", "?")
            n      = get(get(c, "vehiculos",   Dict()), "n", "?")
            m      = get(get(c, "vehiculos",   Dict()), "m", "?")
            pasos  = get(get(c, "simulacion",  Dict()), "pasos", "?")
            println("  $(rpad(f, 32))  [$tipo]  $(n)+$(m) autos  $(pasos) pasos")
            println("  $(repeat(' ', 32))  $desc")
            println()
        catch
            println("  $f")
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. PROCESAMIENTO PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────

cli = parsear_args(ARGS)

if cli["help"];  mostrar_ayuda(); exit(0); end
if cli["lista"]; listar_configs(); exit(0); end

# ─────────────────────────────────────────────────────────────────────────────
# 4. VALIDAR Y CARGAR CONFIG
# ─────────────────────────────────────────────────────────────────────────────

config_path = cli["config"]
if !isfile(config_path)
    println("Error: archivo de config no encontrado: '$config_path'")
    println("Configs disponibles: julia launch.jl --lista")
    exit(1)
end

cfg = YAML.load_file(config_path)

_exp  = cfg["experimento"]
_veh  = cfg["vehiculos"]
_carr = cfg["carretera"]
_fis  = cfg["fisica"]
_comp = cfg["comportamiento"]
_sim  = cfg["simulacion"]
_res  = cfg["resultados"]

nombre_exp = _exp["nombre"]
tipo_exp   = get(_exp, "tipo", "velocidades")

n      = _veh["n"]
m      = _veh["m"]
ancho  = Float64(_veh["ancho"])
largo  = Float64(_veh["largo"])
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
δt      = Float64(_sim["dt"])
error_tol = Float64(_sim["error"])
err_dir   = Float64(_sim["err"])

pasos = isnothing(cli["pasos"]) ? _sim["pasos"] : cli["pasos"]

usar_grilla         = cli["grilla"]
hacer_benchmark     = cli["benchmark"] || tipo_exp == "benchmark"
hacer_animacion     = cli["animacion"]
medir_interacciones = cli["interacciones"] && !hacer_animacion
fps_gif             = cli["fps"]
pasos_calentamiento = cli["calentamiento"]
output_dir          = cli["output"]

# Umbral de interacción: CLI > YAML > default (d_0_1 + largo_auto)
d_int_yaml = get(_sim, "d_interaccion", nothing)
d_interaccion = if !isnothing(cli["d_interaccion"])
    Float64(cli["d_interaccion"])
elseif !isnothing(d_int_yaml)
    Float64(d_int_yaml)
else
    nothing   # calculado tras inicializar vehiculos
end

# ─────────────────────────────────────────────────────────────────────────────
# 5. HEADER
# ─────────────────────────────────────────────────────────────────────────────

timestamp   = Dates.format(now(), "yyyymmdd_HHMMSS")
results_dir = joinpath(output_dir, "$(nombre_exp)_$(timestamp)")
mkpath(results_dir)
mkpath(joinpath(output_dir, "logs"))

sep60 = "=" ^ 60
sep50 = "-" ^ 50

println(sep60)
println("  SIMULACION DE TRAFICO — $(uppercase(nombre_exp))")
println(sep60)
println("  Config       : $config_path")
println("  Resultados   : $results_dir")
println("  Hilos        : $(Threads.nthreads())")
println("  Grilla SAT   : $(usar_grilla ? "activada O(n)" : "desactivada O(n^2)")")
println("  Interacciones: $(medir_interacciones ? "si" : "no")")
println()
println("Parametros:")
println("  Descripcion : $(_exp["descripcion"])")
println("  Vehiculos   : n=$n (carril 1), m=$m (carril 2) = $(n+m) total")
println("  Carretera   : L=$L  |  dt=$δt  |  pasos=$pasos")
println("  Tiempo sim. : $(round(pasos*δt, digits=1)) s  |  egoismo=$egoismo")
println("  Animacion   : $(hacer_animacion ? "si (fps=$fps_gif, calentamiento=$pasos_calentamiento)" : "no")")
println()

# ─────────────────────────────────────────────────────────────────────────────
# 6. MODULO YA CARGADO
# ─────────────────────────────────────────────────────────────────────────────

println("Modulo TraficoSimulacion cargado.")

# ─────────────────────────────────────────────────────────────────────────────
# 7. INICIALIZAR VEHICULOS
# ─────────────────────────────────────────────────────────────────────────────

println("Inicializando vehiculos...")
t_init = @elapsed begin
    vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)
end
println("  $(length(vehiculos)) vehiculos creados en $(round(t_init*1000, digits=1)) ms")

# Resolver umbral de interaccion ahora que tenemos largo del vehiculo
if isnothing(d_interaccion)
    d_interaccion = d_0_1 + vehiculos[1].largo
end
medir_interacciones && println("  Umbral de interaccion: d_int = $(round(d_interaccion, digits=3)) u")
println()

# ─────────────────────────────────────────────────────────────────────────────
# 8. MODO BENCHMARK
# ─────────────────────────────────────────────────────────────────────────────

bench_results = Dict{String,Any}()

if hacer_benchmark
    n_sat       = get(_sim, "benchmark_pasos_sat",  50)
    n_paso_reps = get(_sim, "benchmark_pasos_paso", 10)

    println(sep50)
    println("BENCHMARK 1: Costo de un paso de simulacion")
    println(sep50)

    carriless     = carriles(1, 2)
    giro_nogiro   = comprobacion_giro(vehiculos)
    θ_vec         = zeros(length(vehiculos))
    en_carril_ini = carros_i_carriles(vehiculos, carriless)
    carriles_orig = carril_original(vehiculos, en_carril_ini)

    t_jit = @elapsed avance_dos_carriles_con_giro_sin_anim(
        vehiculos, θ_vec, carriless, carriles_orig, giro_nogiro,
        egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m)
    println("  Primer paso (con JIT): $(round(t_jit*1000, digits=1)) ms")

    vehiculos     = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)
    giro_nogiro   = comprobacion_giro(vehiculos)
    θ_vec         = zeros(length(vehiculos))
    en_carril_ini = carros_i_carriles(vehiculos, carriless)
    carriles_orig = carril_original(vehiculos, en_carril_ini)

    tiempos_paso = Float64[]
    for _ in 1:n_paso_reps
        t = @elapsed avance_dos_carriles_con_giro_sin_anim(
            vehiculos, θ_vec, carriless, carriles_orig, giro_nogiro,
            egoismo, δt, L, d_0_1, d_0_2, α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m)
        push!(tiempos_paso, t)
    end
    t_mean = mean(tiempos_paso) * 1000
    t_std  = std(tiempos_paso) * 1000
    println("  Paso promedio (post-JIT): $(round(t_mean, digits=2)) +/- $(round(t_std, digits=2)) ms")
    println("  Proyeccion $pasos pasos : ~$(round(t_mean * pasos / 1000, digits=1)) s")
    bench_results["paso_mean_ms"] = round(t_mean, digits=4)
    bench_results["paso_std_ms"]  = round(t_std, digits=4)
    bench_results["proyeccion_s"] = round(t_mean * pasos / 1000, digits=2)

    println()
    println(sep50)
    println("BENCHMARK 2: SAT O(n^2) vs Grilla O(n)")
    println(sep50)
    pares = div((n+m)*((n+m)-1), 2)
    println("  Pares O(n^2): $pares")

    t_bruto  = @elapsed for _ in 1:n_sat; haySuperposicionesSAT_error(vehiculos, 0); end
    t_bruto_ms = t_bruto / n_sat * 1000
    g_bench  = GrillaEspacial(Float64(L))
    t_grilla = @elapsed for _ in 1:n_sat; haySuperposicionesSAT_error(vehiculos, 0; grilla=g_bench); end
    t_grilla_ms = t_grilla / n_sat * 1000
    speedup  = t_bruto_ms / max(t_grilla_ms, 1e-9)

    println("  SAT fuerza bruta : $(round(t_bruto_ms, digits=3)) ms  ($(round(t_bruto_ms/t_mean*100,digits=1))% del paso)")
    println("  SAT con grilla   : $(round(t_grilla_ms, digits=3)) ms  ($(round(t_grilla_ms/t_mean*100,digits=1))% del paso)")
    println("  Speedup          : $(round(speedup, digits=1))x")
    bench_results["sat_bruto_ms"]  = round(t_bruto_ms, digits=4)
    bench_results["sat_grilla_ms"] = round(t_grilla_ms, digits=4)
    bench_results["sat_speedup"]   = round(speedup, digits=2)

    println()
    println(sep50)
    println("BENCHMARK 3: Recalculo de estructuras por auto")
    println(sep50)
    t_ci  = @elapsed for _ in 1:1000; carros_i_carriles(vehiculos, carriless); end
    t_ci_ms = t_ci / 1000 * 1000
    t_fan = @elapsed for _ in 1:100; listas_carros_fantasmas(vehiculos); end
    t_fan_ms = t_fan / 100 * 1000
    println("  carros_i_carriles (1 llamada)    : $(round(t_ci_ms,  digits=3)) ms")
    println("  listas_carros_fantasmas (1 llam) : $(round(t_fan_ms, digits=3)) ms")
    bench_results["carros_i_carriles_ms"]        = round(t_ci_ms,  digits=4)
    bench_results["listas_fantasmas_ms"]         = round(t_fan_ms, digits=4)
    bench_results["costo_ci_por_paso_ms"]        = round(t_ci_ms  * (n+m), digits=3)
    bench_results["costo_fantasmas_por_paso_ms"] = round(t_fan_ms * (n+m), digits=3)

    if get(_res, "guardar_benchmarks", true)
        bench_rows = [(metrica=k, valor=v) for (k,v) in bench_results]
        df_bench = DataFrame(metrica=[r.metrica for r in bench_rows],
                             valor  =[r.valor   for r in bench_rows])
        CSV.write(joinpath(results_dir, "benchmarks.csv"), df_bench)
        println("\n  benchmarks.csv guardado.")
    end

    vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)
end

# ─────────────────────────────────────────────────────────────────────────────
# 9. SIMULACION PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────

println()
println(sep60)
println("  SIMULACION  ($pasos pasos, $(n+m) autos)")
println(sep60)

if hacer_animacion && pasos_calentamiento > 0
    println("Calentamiento: $pasos_calentamiento pasos (sin animacion)...")
    t_cal = @elapsed avance_carros_general(
        pasos_calentamiento, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
        α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
        error=error_tol, err=err_dir, usar_grilla=usar_grilla)
    println("  Calentamiento completado en $(round(t_cal, digits=2)) s")
    println()
end

# ── variables que se rellenan en cualquier rama ───────────────────────────────
T = Float64[]; V = Float64[]
N_int  = Matrix{Int}(undef, 0, 0)
H_vec  = Float64[]; K_mean = Float64[]
interacciones_medidas = false

if hacer_animacion
    pasos_anim = pasos - pasos_calentamiento
    println("Ejecutando simulacion con animacion ($pasos_anim pasos, fps=$fps_gif)...")
    t_total = @elapsed begin
        anim = avance_carros_general!(
            pasos_anim, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
            α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
            error=error_tol, err=err_dir)
    end
    gif_path = joinpath(results_dir, "simulacion.gif")
    gif(anim, gif_path, fps=fps_gif)
    println("  Completada en $(round(t_total, digits=2)) s")
    println("  GIF guardado en: $gif_path")

elseif medir_interacciones
    # ── Simulacion con velocidades + interacciones/entropia ──────────────────
    println("Ejecutando simulacion con medicion de interacciones ($pasos pasos)...")
    println("  d_interaccion = $(round(d_interaccion, digits=3)) u")
    t_total = @elapsed begin
        T, V, N_int, H_vec, K_mean = avance_dos_carril_velocidades_e_interacciones(
            pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
            α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
            d_interaccion = d_interaccion,
            error = error_tol, err = err_dir)
    end
    interacciones_medidas = true

    rho1 = round(n / (1.0 * L), digits=4)
    rho2 = round(m / (1.0 * L), digits=4)
    mitad = div(pasos, 2)

    println("  Completada en $(round(t_total, digits=2)) s")
    println()
    println("Velocidades:")
    println("  V inicial        : $(round(V[1],           digits=4)) u/s")
    println("  V final          : $(round(V[end],         digits=4)) u/s")
    println("  V media          : $(round(mean(V),        digits=4)) u/s")
    println("  V media estable  : $(round(mean(V[mitad:end]), digits=4)) u/s  (2da mitad)")
    println("  Densidad rho1    : $rho1  |  rho2: $rho2")
    println()
    println("Interacciones (d_int=$(round(d_interaccion,digits=3))):")
    println("  Vecinos medio    : $(round(mean(K_mean),   digits=3))")
    println("  Vecinos inicio   : $(round(K_mean[1],      digits=3))")
    println("  Vecinos final    : $(round(K_mean[end],    digits=3))")
    println("  Entropia H media : $(round(mean(H_vec),    digits=4)) bits")
    println("  Entropia H inicio: $(round(H_vec[1],       digits=4)) bits")
    println("  Entropia H final : $(round(H_vec[end],     digits=4)) bits")
    println("  Entropia H global: $(round(entropia_global(N_int), digits=4)) bits")

else
    # ── Simulacion solo velocidades (rapida, sin interacciones) ───────────────
    println("Ejecutando simulacion ($pasos pasos, sin medicion de interacciones)...")
    t_total = @elapsed begin
        T, V = avance_dos_carril_valocidades_promedio(
            pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
            α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
            error=error_tol, err=err_dir)
    end

    rho1 = round(n / (1.0 * L), digits=4)
    rho2 = round(m / (1.0 * L), digits=4)
    println("  Completada en $(round(t_total, digits=2)) s")
    println("  V inicial : $(round(V[1],   digits=4)) u/s")
    println("  V final   : $(round(V[end], digits=4)) u/s")
    println("  V media   : $(round(mean(V),digits=4)) u/s")
    println("  rho1=$rho1  |  rho2=$rho2")
end

# ─────────────────────────────────────────────────────────────────────────────
# 10. GUARDAR RESULTADOS CSV
# ─────────────────────────────────────────────────────────────────────────────

if !hacer_animacion && length(T) > 0
    println()
    println(sep50)
    println("Guardando resultados...")

    # ── velocidades.csv ───────────────────────────────────────────────────────
    if get(_res, "guardar_velocidades", true)
        df_vel = DataFrame(tiempo=T, velocidad_promedio=V)
        path_vel = joinpath(results_dir, "velocidades.csv")
        CSV.write(path_vel, df_vel)
        println("  velocidades.csv          ($(length(T)) filas)")
    end

    # ── interacciones_series.csv ──────────────────────────────────────────────
    # Columnas: tiempo | velocidad_promedio | vecinos_promedio | entropia_shannon
    if interacciones_medidas && get(_res, "guardar_interacciones", true)
        df_int = DataFrame(
            tiempo             = T,
            velocidad_promedio = V,
            vecinos_promedio   = K_mean,
            entropia_shannon   = H_vec,
        )
        path_int = joinpath(results_dir, "interacciones_series.csv")
        CSV.write(path_int, df_int)
        println("  interacciones_series.csv ($(length(T)) filas)")

        # ── interacciones_vehiculos.csv ───────────────────────────────────────
        # Matriz N_int transpuesta: cada columna es un vehículo, cada fila un paso.
        # Solo se guarda si el config lo pide (puede ser grande).
        if get(_res, "guardar_interacciones_vehiculos", false)
            n_veh = size(N_int, 2)
            col_names = ["auto_$i" for i in 1:n_veh]
            df_nint = DataFrame(N_int, col_names)
            insertcols!(df_nint, 1, :tiempo => T)
            path_nint = joinpath(results_dir, "interacciones_vehiculos.csv")
            CSV.write(path_nint, df_nint)
            println("  interacciones_vehiculos.csv ($(pasos) pasos × $(n_veh) autos)")
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 11. RESUMEN YAML
# ─────────────────────────────────────────────────────────────────────────────

metricas_int = if interacciones_medidas
    Dict(
        "d_interaccion"      => round(d_interaccion, digits=4),
        "vecinos_media"      => round(mean(K_mean),  digits=4),
        "vecinos_inicio"     => round(K_mean[1],     digits=4),
        "vecinos_final"      => round(K_mean[end],   digits=4),
        "entropia_H_media"   => round(mean(H_vec),   digits=4),
        "entropia_H_inicio"  => round(H_vec[1],      digits=4),
        "entropia_H_final"   => round(H_vec[end],    digits=4),
        "entropia_H_global"  => round(entropia_global(N_int), digits=4),
    )
else
    Dict{String,Any}()
end

metricas_vel = if length(V) > 0
    mitad = div(length(V), 2)
    Dict(
        "v_inicial"    => round(V[1],             digits=4),
        "v_final"      => round(V[end],           digits=4),
        "v_media"      => round(mean(V),          digits=4),
        "v_estable"    => round(mean(V[mitad:end]),digits=4),
        "rho1"         => round(n / (1.0 * L),   digits=4),
        "rho2"         => round(m / (1.0 * L),   digits=4),
        "flujo_estable" => round((n+m)/(2.0*L) * mean(V[mitad:end]), digits=4),
    )
else
    Dict{String,Any}()
end

summary = Dict(
    "experimento"         => nombre_exp,
    "config_usado"        => config_path,
    "timestamp"           => timestamp,
    "n_vehiculos"         => n + m,
    "pasos"               => pasos,
    "pasos_calentamiento" => pasos_calentamiento,
    "tiempo_simulado_s"   => pasos * δt,
    "tiempo_computo_s"    => round(t_total, digits=3),
    "hilos"               => Threads.nthreads(),
    "grilla_espacial"     => usar_grilla,
    "animacion"           => hacer_animacion,
    "velocidades"         => metricas_vel,
    "interacciones"       => metricas_int,
    "benchmarks"          => bench_results,
)
YAML.write_file(joinpath(results_dir, "resumen.yaml"), summary)

println()
println(sep60)
println("Completado. Resultados en: $results_dir")
println(sep60)
