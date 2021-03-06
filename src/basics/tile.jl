export Tile, render

@doc """
A `Tile` is the basic currency in Escher.
Most of the functions in the Escher API take `Tile`s
among other things as arguments, and return a `Tile` as the result.

Tiles are immutable: once created there is no way to mutate them.
""" ->
abstract Tile

render{T <: Tile}(x::T) =
    error("$T cannot be rendered.")

immutable Leaf <: Tile
    element::Elem
end
render(x::Elem) = x
render(x::Leaf) = x.element

convert(::Type{Tile}, x::String) = Leaf(Elem(:span, x))
convert{ns, tag}(::Type{Tile}, x::Elem{ns, tag}) = Leaf(x)

bestmime(val) = begin
  for mime in ("text/html", "image/svg+xml", "image/png", "text/plain")
    mimewritable(mime, val) && return MIME(symbol(mime))
  end
  error("Cannot render $val.")
end

render_fallback(m::MIME"text/plain", x) = Elem(:div, stringmime(m, x))
render_fallback(m::MIME"text/html", x) = Elem(:div, innerHTML=stringmime(m, x))
render_fallback(m::MIME"text/svg", x) = Elem(:div, innerHTML=stringmime(m, x))
render_fallback(m::MIME"image/png", x) =
    Elem(:img, src="data:image/png;base64," * stringmime(m, x))

render(x::FloatingPoint) = @sprintf "%0.3f" x
render(x::Symbol) = string(x)
render(x::String) = Elem(:span, x)
render(xs::AbstractArray, tag="div") = Elem(tag, map(render, xs))

immutable AnyWrap <: Tile
    value
end

render{T}(x::T) =
    # Try to convert first
    method_exists(convert, (Type{Tile}, T)) ?
        render(convert(Tile, x)) :
        render(AnyWrap(x))

# Catch-all render
render(x::AnyWrap) = render_fallback(bestmime(x.value), x.xvalue)

@doc """
`Empty` is handy tile that is well... Empty.
use `empty` constant exported by Escher in your code.
""" ->
immutable Empty <: Tile
end

@doc """
An Empty element.
""" ->
const empty = Empty()

render(t::Empty) = Elem(:div)

writemime(io::IO, m::MIME"text/html", x::Tile) =
    writemime(io, m, Elem(:div, Escher.render(x), className="escherRoot"))

writemime{T <: Tile}(io::IO, m::MIME"text/html", x::Signal{T}) =
    writemime(io, m, lift(Escher.render, Patchwork.Elem, x))

render{T <: Tile}(s::Signal{T}) =
    render(value(s))

# Note a TileList is NOT a Tile
immutable TileList
    tiles::AbstractArray
end

convert(::Type{TileList}, xs::AbstractArray) =
    TileList(xs)
convert(::Type{TileList}, xs::Tuple) =
    TileList([x for x in xs])
convert(::Type{TileList}, x) =
    TileList([x])

render(t::TileList) =
    map(render, t.tiles)

render(t::TileList, wrap) =
    Elem(wrap, map(render, t.tiles))
