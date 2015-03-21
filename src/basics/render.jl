export render

# render function takes a Tile and creates an Elem

function bestmime(val)
  for mime in ("text/html", "image/svg+xml", "image/png", "text/plain")
    mimewritable(mime, val) && return MIME(symbol(mime))
  end
  error("Cannot render $val.")
end

render(m::MIME"text/plain", x) = Elem(:div, stringmime(m, x))
render(m::MIME"text/html", x)  = Elem(:div, innerHTML=stringmime(m, x))
render(m::MIME"text/svg", x)   = Elem(:div, innerHTML=stringmime(m, x))
render(m::MIME"image/png", x)  = Elem(:img, src="data:image/png;base64," * stringmime(m, x))

# Catch-all render
function render(x)
    render(bestmime(x), x)
end

# e.g you can't float a tile up/down
render{T <: Tile}(x::T) =
    error("$T cannot be rendered.")

render(x::FloatingPoint) = @sprintf "%0.3f" x
render(x::Symbol) = string(x)
render(x::String) = x

render(x::Elem) = x
render(x::Leaf) = x.element
render(list::TileList, tag="div") = Elem(tag, map(render, list.tiles))
render(inl::Inline) =
    render(inl.tiles, "span")

render{T <: Tile}(s::Signal{T}) =
    render(value(s))

## Signal custom elements

render(tile::StopPropagation) =
    render(tile.tile) <<
        Elem("stop-propagation",
            attributes=[:name=>tile.name])

render(sig::SignalTransport) =
    render(sig.tile) <<
        Elem("signal-transport",
            attributes=[:name=>sig.name, :signalId => setup_transport(sig.signal)])

render(chan::ChanSend) =
    render(chan.tile) <<
        Elem("chan-send",
            attributes=[:name=>chan.chan, :attr=>chan.attr])

render(chan::ChanRecv) =
    render(chan.tile) <<
        Elem("chan-recv",
            attributes=[:name=>chan.chan, :attr=>chan.attr])

function render_window(window, socketurl, assets, tile; io=IOBuffer())
    write(io, """<!doctype html><html><head>""")
    Canvas.write_canvas_assets(io) # load the most essential html
    write(io, """</head> <body><div id="root" class="canvas-root"></div>""")
    write(io, """<script>new Canvasd($(JSON.json(socketurl)), "root");</script></body>""")
end


########## Layouts ##########

render(t::Empty) = Elem(:div)

# 0. height and width
render(t::Width{:natural}) = render(t.tile) & [:style => [:width => t.w]]
render(t::Height{:natural}) = render(t.tile) & [:style => [:height => t.h]]
render{bound}(t::Width{bound}) = render(t.tile) & [:style => [string(bound, "Width") => t.w]]
render{bound}(t::Height{bound}) = render(t.tile) & [:style => [string(bound, "Height") => t.h]]

# 1. Positioning

render_position(p::TopLeft, x, y) =
    [:top => y, :left => x]
render_position(p::MidTop, x, y) =
    [:left =>  50cent, :top => y,
     :transform => "translate(-50%)",
     :marginLeft => x]
render_position(p::TopRight, x, y) =
    [:top => x, :right => y]
render_position(p::MidLeft, x, y) =
    [:top => 50cent, :left => x,
     :marginTop => y,
     :transform => "translate(0, -50%)"]
render_position(p::Middle, x, y) =
    [:top => 50cent, :left=>50cent,
     :marginLeft => x, :marginTop => y,
     :transform => "translate(-50%, -50%)"]
render_position(p::MidRight, x, y) =
    [:top => 50cent,
    :transform => "translate(0, -50%)",
    :marginTop => y, :right => x]
render_position(p::BottomLeft, x, y) =
    [:bottom => y, :left => x]
render_position(p::MidBottom, x, y) =
    [:left => 50cent, :bottom => y,
     :marginLeft => x,
     :transform => "translate(-50%)"]
render_position(p::BottomRight, x, y) =
    [:bottom => y, :right => x]

render_position(c::Corner) = [:style => render_position(c, 0, 0)]
render_position{C <: Corner}(p::Relative{C}) =
    [:style => render_position(C(), p.x, p.y)]

function render(tile::Inset)
    outer = render(tile.containing)
    inner = render(tile.contained)

    outer &= [:style => [:position => :relative]]
    inner &= [:style => [:position => :absolute]]

    outer << (inner & render_position(tile.position))
end

# 2. Flow

render(t::Grow) =
    render(t.tile) & [:style => [:flexGrow => t.factor]]

render(t::Shrink) =
    render(t.tile) & [:style => [:flexShrink => t.factor]]

render(t::FlexBasis) =
    render(t.tile) & [:style => [:flexBasis => t.basis]]

getproperty(el::Elem, prop, default) =
    hasproperties(el) ? get(properties(el), prop, default) : default

classes(f::Flow{Horizontal, false}) = "flow horizontal"
classes(f::Flow{Vertical, false}) = "flow vertical"
classes(f::Flow{Horizontal, true}) = "flow horizontal flow-reverse"
classes(f::Flow{Vertical, true}) = "flow vertical flow-reverse"

classes(f::Wrap{false}) = "flex-wrap"
classes(f::Wrap{true}) = "flex-wrap-reverse"

classes(t::PackedItems{AxisStart}) = "pack-start"
classes(t::PackedItems{AxisEnd}) = "pack-end"
classes(t::PackedItems{AxisCenter}) = "pack-center"
classes(t::PackedItems{SpaceBetween}) = "pack-space-between"
classes(t::PackedItems{SpaceAround}) = "pack-space-around"

classes(t::PackedLines{AxisStart}) = "pack-lines-start"
classes(t::PackedLines{AxisEnd}) = "pack-lines-end"
classes(t::PackedLines{AxisCenter}) = "pack-lines-center"
classes(t::PackedLines{Stretch}) = "pack-lines-stretch"
classes(t::PackedLines{SpaceBetween}) = "pack-lines-space-between"
classes(t::PackedLines{SpaceAround}) = "pack-lines-space-around"

classes(t::PackedAcross{AxisStart}) = "pack-across-start"
classes(t::PackedAcross{AxisEnd}) = "pack-across-end"
classes(t::PackedAcross{AxisCenter}) = "pack-across-center"
classes(t::PackedAcross{Stretch}) = "pack-across-stretch"
classes(t::PackedAcross{Baseline}) = "pack-across-baseline"

addclasses(t, cs) =
    t & [:className => cs * " " * getproperty(t, :className, "")]

render(f::Flow) =
    addclasses(render(f.tiles), classes(f))

render(f::FlexContainer) =
    addclasses(render(f.tile), classes(f))

# 4. padding

render(cont::Container) = Elem(:div, render(cont.tile))

name(s::Left) = "Left"
name(s::Right) = "Right"
name(s::TopSide) = "Top"
name(s::Bottom) = "Bottom"

render(padded::Padded) =
    render(padded.tile) &
        (isempty(padded.sides) ? # Apply padding to all sides if none specified
                [:style => [:padding => padded.length]] :
                [:style => ["padding" * name(p) => padded.length for p=padded.sides]])

## Behaviour

render{attr}(t::WithState{attr}) =
    render(t.tile) << Elem("watch-state",
        attributes=[:name=>t.name, :attr=>attr, :trigger=>t.trigger])

render(c::Clickable) =
    render(c.tile) << Elem("clickable-behaviour", name=c.name,
                        buttons=string(map(button_number, c.buttons)))

render(sig::SignalSampler) =
    render(sig.tile) <<
        Elem("signal-sampler",
            name=sig.name,
            signals=sig.signals,
            triggers=sig.triggers)

# font type
classes(::WithFont{Serif}) = "font-serif"
classes(::WithFont{SansSerif}) = "font-sansserif"
classes(::WithFont{SlabSerif}) = "font-serif font-slab"
classes(::WithFont{Monospace}) = "font-monospace"

# font style
classes(::WithFont{Normal}) = "font-normal"
classes(::WithFont{Slanted}) = "font-slanted"
classes(::WithFont{Italic}) = "font-italic"

# font case
classes(::WithFont{Uppercase}) = "font-uppercase"
classes(::WithFont{Lowercase}) = "font-lowercase"

# font size
classes(::WithFont{XXSmall}) = "font-xx-small"
classes(::WithFont{XSmall}) = "font-x-small"
classes(::WithFont{Small}) = "font-small"
classes(::WithFont{Medium}) = "font-medium"
classes(::WithFont{Large}) = "font-large"
classes(::WithFont{XLarge}) = "font-x-large"
classes(::WithFont{XXLarge}) = "font-xx-large"

# font weight
classes(::WithFont{Bold}) = "font-bold"
classes(::WithFont{Bolder}) = "font-bolder"
classes(::WithFont{Lighter}) = "font-lighter"

render(t::WithFont) =
    addclasses(render(t.tile), classes(t))

render{n}(t::WithFont{NumericFontWeight{n}}) =
    render(t.tile) & [:style => [:fontWeight => n]]

render(t::WithFont{AbsFontSize}) =
    render(t.tile) & [:style => [:fontSize => t.prop.size]]

render(t::WithFont{FontFamily}) =
    render(t.tile) & [:style => [:fontFamily => t.prop.family]]

render(t::AlignText{RaggedRight}) =
    render(t.tile) & [:style => [:textAlign => :left]]
render(t::AlignText{RaggedLeft}) =
    render(t.tile) & [:style => [:textAlign => :right]]
render(t::AlignText{JustifyText}) =
    render(t.tile) & [:style => [:textAlign => :justify]]
render(t::AlignText{CenterText}) =
    render(t.tile) & [:style => [:textAlign => :center]]

render{tag, class}(p::TextClass{tag, class}) =
    addclasses(Elem(tag, render(p.tile)), string(class))

render(x::Code) = Elem(:code, x.code)

## Borders

render_color(c) = string("#" * hex(c))

propname(::StrokeStyle) = "Style"
propname(::StrokeWidth) = "Width"
propname(::BorderColor) = "Color"

name(::NoStroke) = "none"
name(::Solid) = "solid"
name(::Dotted) = "dotted"
name(::Dashed) = "dashed"

name(p::StrokeWidth) = p.thickness
name(p::BorderColor) = render_color(p.color)

render(t::WithBorder) =
    render(t.tile) &
        (isempty(t.sides) ? # Apply padding to all sides if none specified
                [:style => ["border" * propname(t.prop) => name(t.prop)]] :
                [:style => ["border" * name(s) * propname(t.prop) => name(t.prop) for s=t.sides]])

## RoundedRect

render{C <: Corner}(::C) = string(C)

render(t::RoundedRect) =
    render(t.tile) &
        (isempty(t.corners) ? # Apply padding to all sides if none specified
                [:style => ["borderRadius" => t.radius]] :
                [:style => ["borderRadius" * name(c) => t.radius for c=t.corners]])

render(t::FillColor) =
    render(t.tile) & [:style => [:backgroundColor => render_color(t.color)]]
### Widgets

button_number(::LeftButton) = 1
button_number(::RightButton) = 2
button_number(::ScrollButton) = 3

render(s::Slider) =
    Elem("paper-slider",
        min=first(s.range),
        max=last(s.range),
        step=step(s.range),
        value=s.value,
        editable=s.editable,
        disabled=s.disabled,
        secondaryProgress=s.secondaryprogress)

render(b::Button) =
    Elem("paper-button", render(b.label),
        raised=boolattr(b.raised, "raised"), noink=boolattr(b.raised, "raised"))

render(c::BoolWidget{:checkbox}) =
    Elem("paper-checkbox",
        checked=c.value,
        disabled=boolattr(c.disabled, "disabled"))

render(t::BoolWidget{:toggle}) =
    Elem("paper-toggle-button",
        checked=t.value,
        disabled=boolattr(t.disabled, "disabled"))

render(t::TextInput) =
    Elem("paper-input",
        label=t.label,
        value=t.value,
        floatingLabel=boolattr(t.floatinglabel, "floatingLabel"),
        disabled=boolattr(t.disabled, "disabled"))

render(t::SelectionItem) =
    Elem("paper-item", render(t.tile), value=t.value)

render(d::Dropdown) =
    Elem("paper-dropdown-menu",
        value=d.value,
        label=d.label,
        floatingLabel=boolattr(d.floatinglabel, "floatingLabel"),
        disabled=boolattr(d.disabled, "disabled")) |>
    (wrap -> reduce(<<, wrap, map(render, d.items)))

render(l::LaTeX) =
    Elem("ka-tex", source=l.source)

## Selection

render(pages::Pages) =
    render(pages.tiles, "core-pages")

render(tabs::Tabs) =
    Elem("paper-tabs",
        map(t -> Elem("paper-tab", render(t)), tabs.tiles.tiles))

render(m::Menu) =
    render(m.tiles, "core-menu")

render(m2::SubMenu) =
    render(m2.tiles, "core-submenu")

render(i::Item) =
    Elem("core-item", icon=i.icon, label=i.label)

render(s::Selected) =
    render(s.tile) & ["selected" => s.selected]