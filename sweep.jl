#!/usr/bin/env julia
"""
sweep.jl — Barrido factorial del espacio de parámetros de la simulación.

Uso:
    julia [--threads=N] sweep.jl [opciones]

Opciones:
    --config ARCHIVO        Config factorial YAML (default: configs/barrido_factorial.yaml)
    --output DIR            Directorio de salida   (default: results/sweep_TIMESTAMP)
    --dry-run               Mostrar combinaciones sin ejecutar nada
    --continuar DIR         Continuar un barrido interrumpido desde DIR
    --max-corridas N        Ejecutar solo las primeras N corridas (para pruebas)
    --sin-interacciones     Omitir medición de entropía (mucho más rápido)
    -h, --help              Mostrar esta ayuda y salir

Ejemplos:
    julia --threads=auto sweep.jl --config configs/barrido_factorial.yaml
    julia sweep.jl --dry-run
    julia sweep.jl --max-corridas 10   # prueba rápida con 10 corridas
    julia sweep.jl --continuar results/factorial_01_20250506_220000
"""

# ─────────────────────────────────────────────────────────────────────────────
# 0. Entorno
# ─────────────────────────────────────────────────────────────────────────────
cd(@__DIR__)

using Pkg
Pkg.activate(@__DIR__; io=devnull)

using Statistics
using Dates
using YAML
using CSV
using DataFrames
using Random
using TraficoSimulacion

# ─────────────────────────────────────────────────────────────────────────────
# 1. Parseo de argumentos
# ─────────────────────────────────────────────────────────────────────────────

function parsear_args(args)
    p = Dict{String,Any}(
        "config"          => "configs/barrido_factorial.yaml",
        "output"          => nothing,
        "dry_run"         => false,
        "continuar"       => nothing,
        "max_corridas"    => nothing,
        "interacciones"   => true,
        "help"            => false,
    )
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg in ("-h", "--help")
            p["help"] = true
        elseif arg == "--dry-run"
            p["dry_run"] = true
        elseif arg == "--sin-interacciones"
            p["interacciones"] = false
        elseif arg in ("--config", "--output", "--continuar", "--max-corridas")
            i += 1
            val = args[i]
            if arg == "--config";       p["config"]       = val
            elseif arg == "--output";   p["output"]       = val
            elseif arg == "--continuar"; p["continuar"]   = val
            elseif arg == "--max-corridas"; p["max_corridas"] = parse(Int, val)
            end
        else
            println("Advertencia: argumento desconocido '$arg' ignorado.")
        end
        i += 1
    end
    return p
end

function mostrar_ayuda()
    println("""
    sweep.jl — Barrido factorial de parámetros

    Uso:
        julia [--threads=N] sweep.jl [opciones]

    Opciones:
        --config ARCHIVO        Config factorial YAML (default: configs/barrido_factorial.yaml)
        --output DIR            Directorio de salida
        --dry-run               Mostrar combinaciones sin ejecutar
        --continuar DIR         Retomar barrido interrumpido
        --max-corridas N        Ejecutar solo N corridas (para pruebas)
        --sin-interacciones     Omitir entropía (más rápido)
        -h, --help              Esta ayuda
    """)
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. Generar combinaciones del producto cartesiano
# ─────────────────────────────────────────────────────────────────────────────

"""
Genera todas las combinaciones del producto cartesiano de los factores
definidos en el bloque `factores` del YAML. Devuelve un Vector de Dict.
"""
function generar_combinaciones(cfg::Dict)
    factores = cfg["factores"]
    fijos    = cfg["fijos"]

    # Extraer listas de niveles para cada factor
    niveles_densidad = factores["densidad"]   # lista de {n: ..., m: ...}
    niveles_egoismo  = factores["egoismo"]    # lista de Float
    niveles_T_reac   = factores["T_reac"]     # lista de Float
    niveles_v_max    = factores["v_max"]      # lista de Float

    combinaciones = Dict{String,Any}[]
    id = 1
    for dens in niveles_densidad
        for ego in niveles_egoismo
            for tr in niveles_T_reac
                for vm in niveles_v_max
                    c = Dict{String,Any}(
                        "run_id"  => id,
                        # Factor 1: densidad
                        "n"       => Int(dens["n"]),
                        "m"       => Int(dens["m"]),
                        # Factor 2
                        "egoismo" => Float64(ego),
                        # Factor 3
                        "T_reac"  => Float64(tr),
                        # Factor 4
                        "v_max"   => Float64(vm),
                        # Parámetros fijos
                        "L"           => Float64(fijos["L"]),
                        "d_0_1"       => Float64(fijos["d_0_1"]),
                        "d_0_2"       => Float64(fijos["d_0_2"]),
                        "ancho"       => Float64(fijos["ancho"]),
                        "largo"       => Float64(fijos["largo"]),
                        "alpha"       => Float64(fijos["alpha"]),
                        "mu"          => Float64(fijos["mu"]),
                        "g"           => Float64(fijos["g"]),
                        "acel"        => Float64(fijos["acel"]),
                        "colchon"     => Float64(fijos["colchon"]),
                        "v_min"       => Float64(fijos["v_min"]),
                        "dt"          => Float64(fijos["dt"]),
                        "pasos"       => Int(fijos["pasos"]),
                        "error"       => Float64(fijos["error"]),
                        "err"         => Float64(fijos["err"]),
                        "d_interaccion" => Float64(fijos["d_interaccion"]),
                    )
                    push!(combinaciones, c)
                    id += 1
                end
            end
        end
    end
    return combinaciones
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. Ejecutar una corrida individual
# ─────────────────────────────────────────────────────────────────────────────

"""
Ejecuta una sola corrida con los parámetros del dict `c`.
Devuelve un Dict con las métricas (o estado="error" + mensaje).
"""
function ejecutar_corrida(c::Dict, medir_interacciones::Bool, frac_estable::Float64)
    n      = c["n"];       m      = c["m"]
    L      = c["L"];       d_0_1  = c["d_0_1"];  d_0_2 = c["d_0_2"]
    ancho  = c["ancho"];   largo  = c["largo"]
    α      = c["alpha"];   μ      = c["mu"];      g     = c["g"]
    T_reac = c["T_reac"];  acel   = c["acel"];    colchon = c["colchon"]
    v_max  = c["v_max"];   v_min  = c["v_min"]
    egoismo = c["egoismo"]
    δt     = c["dt"];      pasos  = c["pasos"]
    error  = c["error"];   err    = c["err"]
    d_int  = c["d_interaccion"]

    resultado = Dict{String,Any}(
        "run_id"          => c["run_id"],
        "n"               => n,
        "m"               => m,
        "rho"             => round((n + m) / (2.0 * L), digits=5),
        "egoismo"         => egoismo,
        "T_reac"          => T_reac,
        "v_max"           => v_max,
        "estado"          => "ok",
        "error_msg"       => "",
        "tiempo_computo_s" => 0.0,
        # métricas (se rellenan si la sim tiene éxito)
        "v_estable"       => NaN,
        "flujo_estable"   => NaN,
        "H_media"         => NaN,
        "H_global"        => NaN,
        "K_media"         => NaN,
    )

    try
        vehiculos = carros_dos_carriles(ancho, largo, L, d_0_1, d_0_2 + 0.6, n, m; xs = 1/2)

        t_comp = @elapsed begin
            if medir_interacciones
                T_sim, V, N_int, H_vec, K_mean = avance_dos_carril_velocidades_e_interacciones(
                    pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
                    α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
                    d_interaccion = d_int, error = error, err = err)

                inicio_estable = max(1, round(Int, (1.0 - frac_estable) * pasos))
                v_est = mean(V[inicio_estable:end])
                H_med = mean(H_vec[inicio_estable:end])
                H_gl  = entropia_global(N_int)
                K_med = mean(K_mean[inicio_estable:end])

                resultado["v_estable"]     = round(v_est, digits=5)
                resultado["flujo_estable"] = round((n+m)/(2.0*L) * v_est, digits=5)
                resultado["H_media"]       = round(H_med,  digits=5)
                resultado["H_global"]      = round(H_gl,   digits=5)
                resultado["K_media"]       = round(K_med,  digits=5)
            else
                T_sim, V = avance_dos_carril_valocidades_promedio(
                    pasos, vehiculos, egoismo, δt, L, d_0_1, d_0_2,
                    α, μ, g, T_reac, colchon, acel, v_max, v_min, n, m;
                    error = error, err = err)

                inicio_estable = max(1, round(Int, (1.0 - frac_estable) * pasos))
                v_est = mean(V[inicio_estable:end])

                resultado["v_estable"]     = round(v_est, digits=5)
                resultado["flujo_estable"] = round((n+m)/(2.0*L) * v_est, digits=5)
            end
        end

        resultado["tiempo_computo_s"] = round(t_comp, digits=3)

    catch e
        resultado["estado"]    = "error"
        resultado["error_msg"] = string(e)
    end

    return resultado
end

# ─────────────────────────────────────────────────────────────────────────────
# 4. Utilidades de progreso y ETA
# ─────────────────────────────────────────────────────────────────────────────

function fmt_duracion(segundos::Float64)
    s = round(Int, segundos)
    h, rem = divrem(s, 3600)
    m, ss  = divrem(rem, 60)
    h > 0 ? "$(h)h $(m)m $(ss)s" : m > 0 ? "$(m)m $(ss)s" : "$(ss)s"
end

function barra_progreso(done::Int, total::Int; ancho=30)
    frac  = done / total
    lleno = round(Int, frac * ancho)
    vacio = ancho - lleno
    bar   = "[" * "█"^lleno * "░"^vacio * "]"
    pct   = lpad(round(Int, frac * 100), 3)
    return "$bar $pct%  ($done/$total)"
end

function imprimir_progreso(done, total, t_inicio, tiempos_corridas)
    elapsed   = time() - t_inicio
    eta_str   = if length(tiempos_corridas) >= 3
        t_med = mean(tiempos_corridas[max(1,end-9):end])   # media de las 10 últimas
        eta   = t_med * (total - done)
        fmt_duracion(eta)
    else
        "calculando…"
    end
    bar = barra_progreso(done, total)
    print("\r  $bar  |  elapsed: $(fmt_duracion(elapsed))  |  ETA: $eta_str          ")
    flush(stdout)
end

# ─────────────────────────────────────────────────────────────────────────────
# 5. Checkpoint: guardar / cargar IDs ya completados
# ─────────────────────────────────────────────────────────────────────────────

function cargar_completados(output_dir::String)::Set{Int}
    path = joinpath(output_dir, "master_results.csv")
    !isfile(path) && return Set{Int}()
    df = CSV.read(path, DataFrame)
    hasproperty(df, :run_id) ? Set{Int}(df.run_id) : Set{Int}()
end

# ─────────────────────────────────────────────────────────────────────────────
# 6. MAIN
# ─────────────────────────────────────────────────────────────────────────────

cli = parsear_args(ARGS)
cli["help"] && (mostrar_ayuda(); exit(0))

# ── Cargar config factorial ──────────────────────────────────────────────────
config_path = cli["config"]
if !isfile(config_path)
    println("Error: no se encontró el archivo '$config_path'")
    exit(1)
end
cfg = YAML.load_file(config_path)

nombre_barrido = cfg["barrido"]["nombre"]
mezclar        = get(cfg["barrido"], "mezclar", true)
seed           = get(cfg["barrido"], "seed_aleatorio", 42)
frac_estable   = Float64(get(get(cfg, "metricas", Dict()), "fraccion_estable", 0.4))
medir_int      = cli["interacciones"]

# ── Generar combinaciones ────────────────────────────────────────────────────
combinaciones = generar_combinaciones(cfg)
n_total       = length(combinaciones)

if mezclar
    rng = Random.MersenneTwister(seed)
    shuffle!(rng, combinaciones)
end

# ── Modo dry-run ─────────────────────────────────────────────────────────────
if cli["dry_run"]
    println("═"^60)
    println("  DRY RUN — $(nombre_barrido)")
    println("═"^60)
    println("  Total de corridas : $n_total")
    println("  Config            : $config_path")
    println("  Mezclar           : $mezclar (seed=$seed)")
    println()
    println("  Primeras 12 combinaciones:")
    println("  $(lpad("id",4))  $(lpad("n",4))  $(lpad("m",4))  $(lpad("ego",5))  $(lpad("T_reac",6))  $(lpad("v_max",5))  $(lpad("rho",6))")
    println("  " * "─"^46)
    for c in combinaciones[1:min(12, end)]
        rho = round((c["n"]+c["m"]) / (2.0*c["L"]), digits=3)
        println("  $(lpad(c["run_id"],4))  $(lpad(c["n"],4))  $(lpad(c["m"],4))  " *
                "$(lpad(c["egoismo"],5))  $(lpad(c["T_reac"],6))  $(lpad(c["v_max"],5))  $(lpad(rho,6))")
    end
    n_total > 12 && println("  … y $(n_total-12) más.")
    println()
    exit(0)
end

# ── Directorio de salida ─────────────────────────────────────────────────────
timestamp  = Dates.format(now(), "yyyymmdd_HHMMSS")
output_dir = if !isnothing(cli["output"])
    cli["output"]
elseif !isnothing(cli["continuar"])
    cli["continuar"]
else
    joinpath("results", "$(nombre_barrido)_$(timestamp)")
end
mkpath(output_dir)

# ── Modo --continuar: cargar ya completados ──────────────────────────────────
completados = isnothing(cli["continuar"]) ? Set{Int}() : cargar_completados(output_dir)
pendientes  = filter(c -> c["run_id"] ∉ completados, combinaciones)

if !isnothing(cli["max_corridas"])
    pendientes = pendientes[1:min(cli["max_corridas"], end)]
end

n_pend    = length(pendientes)
n_ya_done = n_total - length(filter(c -> c["run_id"] ∉ completados, combinaciones))

# ── Cabecera ─────────────────────────────────────────────────────────────────
sep = "═"^62
println(sep)
println("  BARRIDO FACTORIAL — $(uppercase(nombre_barrido))")
println(sep)
println("  Config        : $config_path")
println("  Salida        : $output_dir")
println("  Hilos Julia   : $(Threads.nthreads())")
println("  Total corridas: $n_total   |   pendientes: $n_pend   |   ya hechas: $n_ya_done")
println("  Medir entropía: $(medir_int ? "sí" : "no (--sin-interacciones)")")
println("  Frac. estable : $(frac_estable*100)% final")
println()

# ── Columnas del master CSV ───────────────────────────────────────────────────
CSV_COLS = [:run_id, :n, :m, :rho, :egoismo, :T_reac, :v_max,
            :v_estable, :flujo_estable, :H_media, :H_global, :K_media,
            :estado, :error_msg, :tiempo_computo_s]

master_path = joinpath(output_dir, "master_results.csv")
log_path    = joinpath(output_dir, "sweep.log")

# Si el archivo no existe, escribir cabecera
if !isfile(master_path)
    df_cabecera = DataFrame([col => [] for col in CSV_COLS])
    CSV.write(master_path, df_cabecera)
end

# ── Calentar JIT con la primera corrida silenciosamente ───────────────────────
println("Calentando JIT con corrida piloto…")
c_jit = pendientes[1]
_ = ejecutar_corrida(c_jit, medir_int, frac_estable)
println("  JIT listo.")
println()

# ── Bucle principal ──────────────────────────────────────────────────────────
println("Ejecutando $n_pend corridas…")
println()

tiempos_corridas = Float64[]
t_inicio         = time()
errores          = 0

open(log_path, "a") do log_io
    for (idx, c) in enumerate(pendientes)
        # omitir si ya fue completado (por si se cargó un checkpoint parcial)
        c["run_id"] ∈ completados && continue

        res   = ejecutar_corrida(c, medir_int, frac_estable)
        push!(tiempos_corridas, res["tiempo_computo_s"])

        # Guardar fila en master CSV (append)
        fila = DataFrame(
            run_id          = [res["run_id"]],
            n               = [res["n"]],
            m               = [res["m"]],
            rho             = [res["rho"]],
            egoismo         = [res["egoismo"]],
            T_reac          = [res["T_reac"]],
            v_max           = [res["v_max"]],
            v_estable       = [res["v_estable"]],
            flujo_estable   = [res["flujo_estable"]],
            H_media         = [res["H_media"]],
            H_global        = [res["H_global"]],
            K_media         = [res["K_media"]],
            estado          = [res["estado"]],
            error_msg       = [res["error_msg"]],
            tiempo_computo_s= [res["tiempo_computo_s"]],
        )
        CSV.write(master_path, fila; append=true)

        # Registrar en log
        ts_log = Dates.format(now(), "HH:MM:SS")
        println(log_io, "[$ts_log]  run $(lpad(res["run_id"],4))  estado=$(res["estado"])  " *
                "v_est=$(res["v_estable"])  H=$(res["H_media"])  t=$(res["tiempo_computo_s"])s")
        flush(log_io)

        res["estado"] == "error" && (errores += 1)

        imprimir_progreso(idx, n_pend, t_inicio, tiempos_corridas)
    end
end

# ── Resumen final ─────────────────────────────────────────────────────────────
println()
println()
t_total = time() - t_inicio

df_master = CSV.read(master_path, DataFrame)
n_ok  = count(==("ok"),    df_master.estado)
n_err = count(==("error"), df_master.estado)

println(sep)
println("  BARRIDO COMPLETADO")
println(sep)
println("  Corridas OK      : $n_ok")
println("  Corridas con error: $n_err")
println("  Tiempo total     : $(fmt_duracion(t_total))")
println("  Tiempo/corrida   : $(fmt_duracion(t_total / max(n_pend, 1)))")
println("  Master CSV       : $master_path  ($(nrow(df_master)) filas)")
println("  Log              : $log_path")
println()

# ── Estadísticas rápidas del espacio explorado ───────────────────────────────
df_ok = filter(row -> row.estado == "ok", df_master)
if nrow(df_ok) > 0
    println("Resumen de métricas (corridas OK):")
    for col in [:v_estable, :flujo_estable, :H_media, :H_global, :K_media]
        if hasproperty(df_ok, col)
            vals = dropmissing(df_ok, col)[!, col]
            filter!(!isnan, vals)
            if !isempty(vals)
                println("  $(lpad(string(col),16))  " *
                        "min=$(round(minimum(vals),digits=4))  " *
                        "med=$(round(median(vals), digits=4))  " *
                        "max=$(round(maximum(vals),digits=4))")
            end
        end
    end
    println()

    # Correlaciones rápidas entre parámetros y v_estable / H_media
    println("Top 3 combinaciones por entropía H_media más alta (caos):")
    if hasproperty(df_ok, :H_media)
        df_sort = sort(df_ok, :H_media; rev=true)
        for row in eachrow(df_sort[1:min(3,nrow(df_sort)), :])
            println("  run $(lpad(row.run_id,4))  n=$(row.n)+$(row.m)  " *
                    "ego=$(row.egoismo)  T_reac=$(row.T_reac)  " *
                    "v_max=$(row.v_max)  → H=$(round(row.H_media,digits=4))  " *
                    "v=$(round(row.v_estable,digits=4))")
        end
        println()
        println("Top 3 combinaciones por velocidad más alta (flujo libre):")
        df_sort2 = sort(df_ok, :v_estable; rev=true)
        for row in eachrow(df_sort2[1:min(3,nrow(df_sort2)), :])
            println("  run $(lpad(row.run_id,4))  n=$(row.n)+$(row.m)  " *
                    "ego=$(row.egoismo)  T_reac=$(row.T_reac)  " *
                    "v_max=$(row.v_max)  → v=$(round(row.v_estable,digits=4))  " *
                    "H=$(round(row.H_media,digits=4))")
        end
    end
    println()
end

println(sep)
println("  Para analizar: cargar $master_path en Julia o Python.")
println("  Ejemplo Julia:")
println("    using CSV, DataFrames")
println("    df = CSV.read(\"$master_path\", DataFrame)")
println("    # Agrupar por T_reac y ver efecto en v_estable:")
println("    combine(groupby(df, :T_reac), :v_estable => mean)")
println(sep)
