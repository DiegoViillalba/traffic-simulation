#!/usr/bin/env julia
"""
analisis.jl — Analisis y visualizacion de resultados de simulacion.

Parsea directorios de resultados generados por launch.jl y produce:
  1. Evolucion temporal de V(t) con t_critico y v_terminal anotados
  2. V_terminal vs densidad rho
  3. V_terminal vs parametro de egoismo
  4. Flujo J(t) = rho * V(t) en el tiempo

Uso:
    julia analisis.jl --dirs results/exp1 results/exp2
    julia analisis.jl --auto                  # usa todos los subdirs de results/
    julia analisis.jl --auto --tipo densidad
    julia analisis.jl --dirs results/exp1 results/exp2 --output analisis/ --formato pdf

Opciones:
    --dirs DIR...    Directorios de resultados a analizar
    --auto           Usar todos los subdirectorios de results/ automaticamente
    --tipo TIPO      velocidad | densidad | egoismo | flujo | todos  (default: todos)
    --output DIR     Directorio donde guardar los plots  (default: analisis/)
    --ventana N      Ventana de suavizado para t_critico (default: 30)
    --umbral F       Umbral de derivada para t_critico   (default: 0.001)
    --formato FMT    png | pdf | svg                     (default: png)
    -h, --help       Mostrar ayuda y salir
"""

cd(@__DIR__)

using Statistics
using Plots
using YAML
using CSV
using DataFrames
using Dates

gr()   # backend no interactivo, compatible con CLI

# ─────────────────────────────────────────────────────────────────────────────
# 1. PARSEO DE ARGUMENTOS
# ─────────────────────────────────────────────────────────────────────────────

function parsear_args(args)
    p = Dict{String,Any}(
        "dirs"    => String[],
        "auto"    => false,
        "tipo"    => "todos",
        "output"  => "analisis",
        "ventana" => 30,
        "umbral"  => 0.001,
        "formato" => "png",
        "help"    => false,
    )
    i = 1
    while i <= length(args)
        a = args[i]
        if a in ("-h", "--help")
            p["help"] = true
        elseif a == "--auto"
            p["auto"] = true
        elseif a in ("--tipo", "--output", "--ventana", "--umbral", "--formato")
            i += 1
            v = args[i]
            if a == "--tipo";    p["tipo"]    = v
            elseif a == "--output";  p["output"]  = v
            elseif a == "--ventana"; p["ventana"] = parse(Int, v)
            elseif a == "--umbral";  p["umbral"]  = parse(Float64, v)
            elseif a == "--formato"; p["formato"] = v
            end
        elseif a == "--dirs"
            i += 1
            while i <= length(args) && !startswith(args[i], "--")
                push!(p["dirs"], args[i])
                i += 1
            end
            continue
        else
            println("Advertencia: argumento desconocido '$a' ignorado.")
        end
        i += 1
    end
    return p
end

function mostrar_ayuda()
    println("""
    analisis.jl — Analisis de resultados de simulacion de trafico

    Uso:
        julia analisis.jl --dirs results/exp1 results/exp2 [opciones]
        julia analisis.jl --auto [opciones]

    Opciones:
        --dirs DIR...    Directorios de resultados
        --auto           Usar todos los subdirs de results/ automaticamente
        --tipo TIPO      velocidad | densidad | egoismo | flujo | todos (default: todos)
        --output DIR     Directorio de plots (default: analisis/)
        --ventana N      Ventana de suavizado para t_critico (default: 30)
        --umbral F       Umbral de derivada para t_critico  (default: 0.001)
        --formato FMT    png | pdf | svg (default: png)
        -h, --help       Esta ayuda

    Ejemplos:
        julia analisis.jl --auto
        julia analisis.jl --auto --tipo densidad --output figs/
        julia analisis.jl --dirs results/baja_densidad_* results/alta_densidad_*
    """)
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. CARGA DE UN EXPERIMENTO
# ─────────────────────────────────────────────────────────────────────────────

"""
Carga todos los datos de un directorio de resultados.
Retorna un Dict con metadatos, series temporales y parametros calculados.
Retorna nothing si el directorio no tiene los archivos minimos.
"""
function cargar_experimento(dir::String; ventana::Int=30, umbral::Float64=0.001)
    resumen_path = joinpath(dir, "resumen.yaml")
    vel_path     = joinpath(dir, "velocidades.csv")

    if !isfile(resumen_path)
        @warn "Sin resumen.yaml en '$dir' — omitido."
        return nothing
    end
    if !isfile(vel_path)
        @warn "Sin velocidades.csv en '$dir' — omitido (experimento tipo benchmark)."
        return nothing
    end

    res = YAML.load_file(resumen_path)
    df  = CSV.read(vel_path, DataFrame)

    T = Float64.(df.tiempo)
    V = Float64.(df.velocidad_promedio)

    # Leer config original para obtener egoismo (puede no estar en resumen)
    cfg_path = get(res, "config_usado", "")
    egoismo  = 0.0
    v_max    = 4.0
    n_veh    = get(res, "n_vehiculos", 0)
    L        = 50.0
    if isfile(cfg_path)
        cfg    = YAML.load_file(cfg_path)
        egoismo = Float64(get(get(cfg, "comportamiento", Dict()), "egoismo", 0.0))
        v_max   = Float64(get(get(cfg, "fisica",         Dict()), "v_max",   4.0))
        n_veh   = get(get(cfg, "vehiculos", Dict()), "n", 0) +
                  get(get(cfg, "vehiculos", Dict()), "m", 0)
        L       = Float64(get(get(cfg, "carretera",      Dict()), "L", 50.0))
    end

    # Densidades almacenadas en resumen
    rho1  = Float64(get(res, "densidad_carril1", 0.0))
    rho2  = Float64(get(res, "densidad_carril2", 0.0))
    rho   = rho1 + rho2   # densidad total [veh/m]

    # Flujo vehicular J = rho * V  (en cada instante)
    J = rho .* V

    # Deteccion de t_critico con suavizado + derivada (logica de analisis.jl)
    V_suave = media_movil(V, ventana)
    t_crit_idx, v_term = encontrar_t_critico_local(T, V_suave; umbral=umbral)

    nombre = get(res, "experimento", basename(dir))
    label  = "$(nombre)  rho=$(round(rho, digits=3))  ego=$(round(egoismo, digits=2))"

    return Dict{String,Any}(
        "dir"       => dir,
        "nombre"    => nombre,
        "label"     => label,
        "T"         => T,
        "V"         => V,
        "V_suave"   => V_suave,
        "J"         => J,
        "rho"       => rho,
        "rho1"      => rho1,
        "rho2"      => rho2,
        "egoismo"   => egoismo,
        "v_max"     => v_max,
        "v_term"    => v_term,
        "t_crit"    => isnothing(t_crit_idx) ? nothing : T[t_crit_idx],
        "t_crit_idx"=> t_crit_idx,
        "n_veh"     => n_veh,
        "L"         => L,
        "pasos"     => get(res, "pasos", length(T)),
        "resumen"   => res,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. ALGORITMOS DE ANALISIS (auto-contenidos, sin depender de src/)
# ─────────────────────────────────────────────────────────────────────────────

function media_movil(v::Vector{Float64}, w::Int)
    n = length(v)
    s = similar(v)
    for i in 1:n
        a = max(1, i - w ÷ 2)
        b = min(n, i + w ÷ 2)
        s[i] = mean(v[a:b])
    end
    return s
end

function derivada_central(T::Vector{Float64}, V::Vector{Float64})
    n = length(V)
    d = zeros(n)
    for i in 2:n-1
        d[i] = (V[i+1] - V[i-1]) / (T[i+1] - T[i-1])
    end
    d[1] = (V[2] - V[1]) / max(T[2] - T[1], 1e-12)
    d[n] = (V[n] - V[n-1]) / max(T[n] - T[n-1], 1e-12)
    return d
end

"""
Detecta t_critico como el primer indice donde la derivada de V_suavizada
se mantiene por debajo de 'umbral' durante al menos 'racha' pasos consecutivos.
Retorna (indice, v_terminal) o (nothing, mean(V[end-racha:end])).
"""
function encontrar_t_critico_local(T::Vector{Float64}, V_suave::Vector{Float64};
                                    umbral::Float64=0.001, racha::Int=30)
    d = abs.(derivada_central(T, V_suave))
    n = length(d)
    for i in 1:(n - racha)
        if all(d[i:i+racha-1] .< umbral)
            v_term = mean(V_suave[i:end])
            return i, v_term
        end
    end
    # Fallback: ultima mitad
    mitad = div(n, 2)
    return mitad, mean(V_suave[mitad:end])
end

# ─────────────────────────────────────────────────────────────────────────────
# 4. FUNCIONES DE PLOT
# ─────────────────────────────────────────────────────────────────────────────

palette_custom = [:steelblue, :crimson, :darkorange, :seagreen,
                  :mediumpurple, :saddlebrown, :deeppink, :teal]

function plot_evolucion_temporal(data::Vector{<:Dict}; fmt, outdir)
    p = plot(
        xlabel = "Tiempo [pasos]",
        ylabel = "Velocidad promedio [u/paso]",
        title  = "Evolucion temporal de la velocidad promedio",
        legend = :bottomright,
        size   = (900, 500),
        dpi    = 150,
        grid   = true,
        gridalpha = 0.3,
    )

    for (k, e) in enumerate(exps)
        col = palette_custom[mod1(k, length(palette_custom))]
        T, V = e["T"], e["V"]
        V_s  = e["V_suave"]

        # Serie original atenuada
        plot!(p, T, V, label="", alpha=0.25, color=col, linewidth=1)
        # Serie suavizada
        plot!(p, T, V_s, label=e["label"], color=col, linewidth=2)

        # Anotar t_critico
        tc = e["t_crit"]
        if !isnothing(tc)
            vline!(p, [tc], color=col, linestyle=:dash, alpha=0.7, label="")
            vt = e["v_term"]
            hline!(p, [vt], color=col, linestyle=:dot, alpha=0.5, label="")
            annotate!(p, tc, vt * 1.04,
                text("v_t=$(round(vt,digits=3))", col, :left, 7))
        end
    end

    path = joinpath(outdir, "evolucion_temporal.$fmt")
    savefig(p, path)
    println("  evolucion_temporal.$fmt")
    return path
end

function plot_v_terminal_vs_densidad(exps::Vector{Dict}; fmt="png", outdir="analisis")
    # Agrupar por egoismo para series distintas
    egos = sort(unique(round.(e["egoismo"] for e in exps), digits=3))

    p = plot(
        xlabel = "Densidad rho [veh/m]",
        ylabel = "Velocidad terminal v_term [u/paso]",
        title  = "Velocidad terminal vs densidad",
        legend = :topright,
        size   = (800, 500),
        dpi    = 150,
        grid   = true,
        gridalpha = 0.3,
    )

    for (k, ego) in enumerate(egos)
        col   = palette_custom[mod1(k, length(palette_custom))]
        grupo = filter(e -> round(e["egoismo"], digits=3) == ego, exps)
        sort!(grupo, by = e -> e["rho"])
        if isempty(grupo); continue; end
        rhos  = [e["rho"]    for e in grupo]
        vterms = [e["v_term"] for e in grupo]
        plot!(p, rhos, vterms,
              marker=:circle, markersize=6,
              label="egoismo=$(round(ego, digits=2))",
              color=col, linewidth=2)
    end

    path = joinpath(outdir, "v_terminal_vs_densidad.$fmt")
    savefig(p, path)
    println("  v_terminal_vs_densidad.$fmt")
    return path
end

function plot_v_terminal_vs_egoismo(exps::Vector{Dict}; fmt="png", outdir="analisis")
    # Agrupar por densidad (redondeada a 2 decimales)
    rhos = sort(unique(round.(e["rho"] for e in exps), digits=2))

    p = plot(
        xlabel = "Parametro de egoismo",
        ylabel = "Velocidad terminal v_term [u/paso]",
        title  = "Velocidad terminal vs egoismo",
        legend = :bottomright,
        size   = (800, 500),
        dpi    = 150,
        grid   = true,
        gridalpha = 0.3,
    )

    for (k, rho) in enumerate(rhos)
        col   = palette_custom[mod1(k, length(palette_custom))]
        grupo = filter(e -> round(e["rho"], digits=2) == rho, exps)
        sort!(grupo, by = e -> e["egoismo"])
        if isempty(grupo); continue; end
        ego_vals = [e["egoismo"] for e in grupo]
        vterms   = [e["v_term"]  for e in grupo]
        plot!(p, ego_vals, vterms,
              marker=:circle, markersize=6,
              label="rho=$(round(rho, digits=2))",
              color=col, linewidth=2)
    end

    path = joinpath(outdir, "v_terminal_vs_egoismo.$fmt")
    savefig(p, path)
    println("  v_terminal_vs_egoismo.$fmt")
    return path
end

function plot_flujo_temporal(exps::Vector{<:Dict}; fmt="png", outdir="analisis")
    p = plot(
        xlabel = "Tiempo [pasos]",
        ylabel = "Flujo J = rho * V [veh/(m*paso)]",
        title  = "Flujo vehicular en el tiempo",
        legend = :bottomright,
        size   = (900, 500),
        dpi    = 150,
        grid   = true,
        gridalpha = 0.3,
    )

    for (k, e) in enumerate(exps)
        col = palette_custom[mod1(k, length(palette_custom))]
        J_suave = media_movil(e["J"], 30)
        plot!(p, e["T"], e["J"],  label="", alpha=0.2, color=col, linewidth=1)
        plot!(p, e["T"], J_suave, label=e["label"], color=col, linewidth=2)

        tc = e["t_crit"]
        if !isnothing(tc)
            vline!(p, [tc], color=col, linestyle=:dash, alpha=0.6, label="")
        end
    end

    path = joinpath(outdir, "flujo_temporal.$fmt")
    savefig(p, path)
    println("  flujo_temporal.$fmt")
    return path
end

function plot_panel_completo(exps::Vector{Dict}; fmt="png", outdir="analisis")
    # 2x2 panel con los 4 plots
    p1 = plot(title="V(t)", xlabel="Tiempo", ylabel="V [u/paso]",
              legend=:bottomright, size=(500,350))
    p2 = plot(title="V_term vs rho", xlabel="rho [veh/m]", ylabel="V_term",
              legend=:topright, size=(500,350))
    p3 = plot(title="V_term vs egoismo", xlabel="egoismo", ylabel="V_term",
              legend=:bottomright, size=(500,350))
    p4 = plot(title="Flujo J(t)", xlabel="Tiempo", ylabel="J [veh/m*paso]",
              legend=:bottomright, size=(500,350))

    egos = sort(unique(round.(e["egoismo"] for e in exps), digits=3))
    rhos = sort(unique(round.(e["rho"]     for e in exps), digits=2))

    for (k, e) in enumerate(exps)
        col = palette_custom[mod1(k, length(palette_custom))]
        V_s = e["V_suave"]

        plot!(p1, e["T"], e["V"], label="", alpha=0.2, color=col)
        plot!(p1, e["T"], V_s,   label=e["label"], color=col, linewidth=1.5)
        !isnothing(e["t_crit"]) && vline!(p1, [e["t_crit"]], color=col, ls=:dash, label="")

        J_s = media_movil(e["J"], 30)
        plot!(p4, e["T"], e["J"], label="", alpha=0.2, color=col)
        plot!(p4, e["T"], J_s,   label=e["label"], color=col, linewidth=1.5)
    end

    for (k, ego) in enumerate(egos)
        col   = palette_custom[mod1(k, length(palette_custom))]
        grupo = sort(filter(e -> round(e["egoismo"],digits=3)==ego, exps), by=e->e["rho"])
        isempty(grupo) && continue
        plot!(p2, [e["rho"] for e in grupo], [e["v_term"] for e in grupo],
              marker=:circle, markersize=5, label="ego=$(round(ego,digits=2))",
              color=col, linewidth=2)
    end

    for (k, rho) in enumerate(rhos)
        col   = palette_custom[mod1(k, length(palette_custom))]
        grupo = sort(filter(e -> round(e["rho"],digits=2)==rho, exps), by=e->e["egoismo"])
        isempty(grupo) && continue
        plot!(p3, [e["egoismo"] for e in grupo], [e["v_term"] for e in grupo],
              marker=:circle, markersize=5, label="rho=$(round(rho,digits=2))",
              color=col, linewidth=2)
    end

    panel = plot(p1, p2, p3, p4, layout=(2,2), size=(1100, 750), dpi=150)
    path  = joinpath(outdir, "panel_completo.$fmt")
    savefig(panel, path)
    println("  panel_completo.$fmt")
    return path
end

# ─────────────────────────────────────────────────────────────────────────────
# 5. MAIN
# ─────────────────────────────────────────────────────────────────────────────

cli = parsear_args(ARGS)

if cli["help"]
    mostrar_ayuda()
    exit(0)
end

# Resolver directorios
dirs = String[]
if cli["auto"]
    base = "results"
    if !isdir(base)
        println("Error: directorio '$base' no existe. Ejecuta primero una simulacion.")
        exit(1)
    end
    dirs = filter(isdir, [joinpath(base, d) for d in readdir(base)])
    isempty(dirs) && (println("No hay resultados en '$base/'."); exit(0))
elseif !isempty(cli["dirs"])
    dirs = cli["dirs"]
else
    println("Error: especifica --dirs DIR... o usa --auto.")
    println("       julia analisis.jl --help")
    exit(1)
end

outdir  = cli["output"]
tipo    = cli["tipo"]
fmt     = cli["formato"]
ventana = cli["ventana"]
umbral  = cli["umbral"]

mkpath(outdir)

# ── Cargar experimentos ───────────────────────────────────────────────────────
println("Cargando $(length(dirs)) experimento(s)...")
exps = filter(!isnothing, [cargar_experimento(d; ventana=ventana, umbral=umbral) for d in dirs])

if isempty(exps)
    println("Ninguno de los directorios contenia velocidades.csv. Verifica que los experimentos no sean solo benchmarks.")
    exit(1)
end

println()
println("Experimentos cargados:")
println("  $(lpad("Nombre", 25))  $(lpad("rho", 8))  $(lpad("egoismo", 8))  $(lpad("v_term", 8))  t_crit")
println("  " * "-"^70)
for e in exps
    tc = isnothing(e["t_crit"]) ? "  --" : "  t=$(round(e["t_crit"], digits=1))"
    println("  $(lpad(e["nombre"], 25))  " *
            "$(lpad(round(e["rho"],     digits=4), 8))  " *
            "$(lpad(round(e["egoismo"], digits=3), 8))  " *
            "$(lpad(round(e["v_term"],  digits=4), 8))  $tc")
end
println()

# ── Generar plots ─────────────────────────────────────────────────────────────
println("Guardando plots en '$outdir/'...")
println()

generados = String[]

if tipo in ("velocidad", "todos")
    push!(generados, plot_evolucion_temporal(exps; fmt=fmt, outdir=outdir))
end

if tipo in ("densidad", "todos") && length(exps) >= 2
    push!(generados, plot_v_terminal_vs_densidad(exps; fmt=fmt, outdir=outdir))
elseif tipo == "densidad"
    println("  (densidad: se necesitan al menos 2 experimentos con distintas densidades)")
end

if tipo in ("egoismo", "todos") && length(exps) >= 2
    push!(generados, plot_v_terminal_vs_egoismo(exps; fmt=fmt, outdir=outdir))
elseif tipo == "egoismo"
    println("  (egoismo: se necesitan al menos 2 experimentos con distintos valores de egoismo)")
end

if tipo in ("flujo", "todos")
    push!(generados, plot_flujo_temporal(exps; fmt=fmt, outdir=outdir))
end

if tipo == "todos" && length(exps) >= 2
    push!(generados, plot_panel_completo(exps; fmt=fmt, outdir=outdir))
end

println()
println("Completado. $(length(generados)) plot(s) guardados en '$outdir/'.")
