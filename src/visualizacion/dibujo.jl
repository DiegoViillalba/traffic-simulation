import Plots.plot, Plots.plot!
using Plots.Colors: RGB

# ─────────────────────────────────────────────
#  Utilidades internas
# ─────────────────────────────────────────────

function _kargs_reducidos(; kargs...)
    excluir = Set([:color, :label, :fill])
    I = findall(k -> k ∉ excluir, keys(kargs))
    isempty(I) ? (;lw=0) : kargs[keys(kargs)[I]]
end

function _rotar(x, y, centro, θ)
    cosθ, sinθ = cos(θ), sin(θ)
    xc, yc = centro
    xr = @. cosθ * (x - xc) - sinθ * (y - yc) + xc
    yr = @. sinθ * (x - xc) + cosθ * (y - yc) + yc
    return xr, yr
end

# Ángulo de dirección del auto (apunta hacia arriba por convención)
_angulo(a::Auto) = atan(a.direccion[2], a.direccion[1]) - π/2


# ─────────────────────────────────────────────
#  Geometría del auto — proporciones mejoradas
# ─────────────────────────────────────────────
#
#  Convención local (antes de rotar):
#    eje x → ancho del auto   (half-width  = w = ancho/2)
#    eje y → largo del auto   (half-length = h = largo/2)
#    frente apunta hacia +y
#
#  Proporciones recomendadas: largo ≈ 2.1 × ancho
#  El struct Auto debe tener campos: posicion, direccion, ancho, largo, color, esquinas

function _rectangulo(a::Auto)
    x = [a.esquinas[mod1(i, 4)][1] for i in 1:5]
    y = [a.esquinas[mod1(i, 4)][2] for i in 1:5]
    return x, y
end

"""Devuelve (w, h, px, py) — parabrisas delantero."""
function _parabrisas_front(a::Auto)
    θ  = _angulo(a)
    cx, cy = a.posicion
    w  = a.ancho / 2          # half-width
    h  = a.largo / 2          # half-length

    # Franja entre y = 0.40h … 0.72h (zona delantera del techo)
    margin_x = 0.12w          # bisel lateral
    y_bot    = cy + 0.40h
    y_top    = cy + 0.72h

    px = [cx - w + margin_x,
          cx - w,
          cx + w,
          cx + w - margin_x,
          cx - w + margin_x]
    py = [y_bot, y_top, y_top, y_bot, y_bot]

    px, py = _rotar(px, py, a.posicion, θ)
    return w, h, px, py
end

"""Devuelve (tx, ty) — luneta trasera."""
function _parabrisas_rear(a::Auto, w, h)
    θ  = _angulo(a)
    cx, cy = a.posicion

    margin_x = 0.16w
    y_top    = cy - 0.50h
    y_bot    = cy - 0.75h

    tx = [cx - w + margin_x,
          cx - w,
          cx + w,
          cx + w - margin_x,
          cx - w + margin_x]
    ty = [y_top, y_bot, y_bot, y_top, y_top]

    tx, ty = _rotar(tx, ty, a.posicion, θ)
    return tx, ty
end

"""Ventanillas laterales (izquierda y derecha)."""
function _ventanas(a::Auto, w, h,
                   front_y_bot, front_y_top,
                   rear_y_top)
    θ  = _angulo(a)
    cx, cy = a.posicion

    gap  = 0.04w   # pilar entre parabrisas y ventanilla
    vy_bot = rear_y_top  + 0.06h   # alineado con luneta trasera
    vy_top = front_y_bot - 0.06h   # alineado con parabrisas front

    # Ventanilla derecha
    vr_x = [cx + w - 0.14w, cx + w,          cx + w,          cx + w - 0.14w, cx + w - 0.14w]
    vr_y = [vy_bot,          vy_bot + gap,    vy_top - gap,    vy_top,          vy_bot]
    vr_x, vr_y = _rotar(vr_x, vr_y, a.posicion, θ)

    # Ventanilla izquierda (simétrica)
    vl_x = [cx - w + 0.14w, cx - w,          cx - w,          cx - w + 0.14w, cx - w + 0.14w]
    vl_y = [vy_bot,          vy_bot + gap,    vy_top - gap,    vy_top,          vy_bot]
    vl_x, vl_y = _rotar(vl_x, vl_y, a.posicion, θ)

    return vr_x, vr_y, vl_x, vl_y
end

"""Faros delanteros y traseros (rectángulos en esquinas)."""
function _faros(a::Auto, w, h)
    θ  = _angulo(a)
    cx, cy = a.posicion

    fw = 0.28w   # ancho del faro
    fh = 0.09h   # alto  del faro
    indent = 0.08w  # separación del borde lateral

    function _faro_rect(ox, oy)
        fx = [ox, ox+fw, ox+fw, ox, ox]
        fy = [oy, oy,    oy+fh, oy+fh, oy]
        _rotar(fx, fy, a.posicion, θ)
    end

    # Delantero izquierdo
    dl_x, dl_y = _faro_rect(cx - w + indent,        cy + h - fh)
    # Delantero derecho
    dr_x, dr_y = _faro_rect(cx + w - indent - fw,   cy + h - fh)
    # Trasero izquierdo  (rojo)
    tl_x, tl_y = _faro_rect(cx - w + indent,        cy - h)
    # Trasero derecho    (rojo)
    tr_x, tr_y = _faro_rect(cx + w - indent - fw,   cy - h)

    return dl_x, dl_y, dr_x, dr_y, tl_x, tl_y, tr_x, tr_y
end


# ─────────────────────────────────────────────
#  Aplicar rotación horizontal
# ─────────────────────────────────────────────

"""
Rota 90° todas las coordenadas x,y de un plot alrededor del origen.
Útil para convertir la vista "vertical" (auto apuntando arriba)
en vista "horizontal" (auto apuntando a la derecha).
"""
function _rotar_plot_horizontal!(p)
    # Rotar cada serie del plot 90° en sentido antihorario
    # (x, y) → (-y, x)
    for s in p.series_list
        xs = copy(s[:x])
        ys = copy(s[:y])
        s[:x] = -ys
        s[:y] =  xs
    end
end


# ─────────────────────────────────────────────
#  API pública
# ─────────────────────────────────────────────

"""
    plot!(a::Auto; vidrios=true, faros=true, horizontal=false, minimal=false, kargs...)

Dibuja el auto `a` sobre el plot actual.

Kwargs:
- `vidrios`    : dibuja parabrisas y ventanillas (default: true)
- `faros`      : dibuja faros delanteros (amarillo) y traseros (rojo) (default: true)
- `horizontal` : si `true`, el auto se dibuja apuntando hacia la derecha en lugar de hacia arriba (default: false)
- `minimal`    : si `true`, dibuja solo el rectángulo de color y los faros, sin vidrios (default: false)
- Cualquier kwarg estándar de Plots (excepto `color` y `fill`, que se asignan internamente).
"""
function plot!(a::Auto; vidrios=true, faros=true, horizontal=false, minimal=false, kargs...)
    kargs2 = _kargs_reducidos(; kargs...)
    θ = _angulo(a)

    # Cuerpo
    x, y = _rectangulo(a)
    if minimal
        # Sin borde: linecolor igual al relleno y grosor 0
        plot!(x, y; fill=true, color=a.color, linecolor=a.color, linewidth=0, kargs...)
    else
        plot!(x, y; fill=true, color=a.color, kargs...)
    end

    w, h, px, py = _parabrisas_front(a)

    # Modo minimal: solo cuerpo + faros, sin vidrios ni detalles
    if minimal
        if faros
            dl_x, dl_y, dr_x, dr_y, tl_x, tl_y, tr_x, tr_y = _faros(a, w, h)
            plot!(dl_x, dl_y; fill=true, color=RGB(1.0, 0.95, 0.4), label=false, kargs2...)
            plot!(dr_x, dr_y; fill=true, color=RGB(1.0, 0.95, 0.4), label=false, kargs2...)
            plot!(tl_x, tl_y; fill=true, color=RGB(0.9, 0.1, 0.1),  label=false, kargs2...)
            plot!(tr_x, tr_y; fill=true, color=RGB(0.9, 0.1, 0.1),  label=false, kargs2...)
        end
        p = plot!()
        if horizontal
            _rotar_plot_horizontal!(p)
            plot!(aspect_ratio=:equal)
        end
        return p
    end

    if vidrios
        # Parabrisas delantero
        plot!(px, py; fill=true, color=RGB(0.55, 0.78, 0.95), label=false, kargs2...)

        # Luneta trasera
        tx, ty = _parabrisas_rear(a, w, h)
        plot!(tx, ty; fill=true, color=RGB(0.55, 0.78, 0.95), label=false, kargs2...)

        # front_y_bot / front_y_top en coordenadas locales (antes de rotar)
        cy = a.posicion[2]
        front_y_bot = cy + 0.40h
        front_y_top = cy + 0.72h
        rear_y_top  = cy - 0.50h

        vr_x, vr_y, vl_x, vl_y = _ventanas(a, w, h, front_y_bot, front_y_top, rear_y_top)
        plot!(vr_x, vr_y; fill=true, color=RGB(0.55, 0.78, 0.95), label=false, kargs2...)
        plot!(vl_x, vl_y; fill=true, color=RGB(0.55, 0.78, 0.95), label=false, kargs2...)
    end

    if faros
        dl_x, dl_y, dr_x, dr_y, tl_x, tl_y, tr_x, tr_y = _faros(a, w, h)
        color_front = RGB(1.0, 0.95, 0.4)   # amarillo cálido
        color_rear  = RGB(0.9, 0.1, 0.1)    # rojo

        plot!(dl_x, dl_y; fill=true, color=color_front, label=false, kargs2...)
        plot!(dr_x, dr_y; fill=true, color=color_front, label=false, kargs2...)
        plot!(tl_x, tl_y; fill=true, color=color_rear,  label=false, kargs2...)
        plot!(tr_x, tr_y; fill=true, color=color_rear,  label=false, kargs2...)
    end

    p = plot!()

    if horizontal
        _rotar_plot_horizontal!(p)
        plot!(aspect_ratio=:equal)
    end

    return p
end

"""
    plot(a::Auto; kargs...)

Crea un nuevo plot con el auto `a`. Acepta los mismos kwargs que `plot!`.
"""
function plot(a::Auto; vidrios=true, faros=true, horizontal=false, minimal=false, kargs...)
    plot()
    plot!(a; vidrios=vidrios, faros=faros, horizontal=horizontal, minimal=minimal, kargs...)
end

"""
    plot(carros::Vector{Auto}; kargs...)

Dibuja un arreglo de autos en un nuevo plot.
"""
function plot(carros::Vector{Auto}; vidrios=true, faros=true, horizontal=false, minimal=false, kargs...)
    plot()
    for a in carros
        plot!(a; vidrios=vidrios, faros=faros, horizontal=false, minimal=minimal, label="", kargs...)
    end
    p = plot!()
    if horizontal
        _rotar_plot_horizontal!(p)
        plot!(aspect_ratio=:equal)
    end
    return p
end

"""
    plot!(carros::Vector{Auto}; kargs...)

Dibuja un arreglo de autos sobre el plot actual.
"""
function plot!(carros::Vector{Auto}; vidrios=true, faros=true, horizontal=false, minimal=false, kargs...)
    for a in carros
        plot!(a; vidrios=vidrios, faros=faros, horizontal=false, minimal=minimal, label="", kargs...)
    end
    p = plot!()
    if horizontal
        _rotar_plot_horizontal!(p)
        plot!(aspect_ratio=:equal)
    end
    return p
end

"""
    graficar_vector_normalizado!(vector, centro; kargs...)

Grafica un vector normalizado desde `centro`. Lanza advertencia si el vector no está normalizado.
"""
function graficar_vector_normalizado!(vector::Vector{Float64}, centro::Vector{Float64}; kargs...)
    norma = sqrt(sum(vector .^ 2))
    if !isapprox(norma, 1.0; atol=1e-5)
        @warn "Vector no normalizado (norma=$norma). Se normalizará automáticamente."
        vector = vector ./ norma
    end
    pf = centro .+ vector
    plot!([centro[1], pf[1]], [centro[2], pf[2]]; kargs...)
    scatter!([centro[1]], [centro[2]]; color=:red, label=false)
end