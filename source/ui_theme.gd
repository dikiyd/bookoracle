extends RefCounted
## Shared look «Читательский билет»: ruled paper, deep teal plates, amber stamps, genre ribbons.
const PAPER = Color("f6efe1")
const RULE = Color("e9dfcb")
const CARD = Color("fffaf0")
const CARD_EDGE = Color("e4d8bf")
const INK = Color("1f2d2b")
const TEAL = Color("1f4f49")
const TEAL_LIGHT = Color("2c6a62")
const TEAL_SOFT = Color("a9c9bf")
const AMBER = Color("e2a64b")
const AMBER_DEEP = Color("c7812c")
const MUTED = Color("7a6f5d")
const ON_TEAL = Color("f3ead6")
const RIBBONS = [Color("9aae5b"), Color("7d72c2"), Color("2f9c8d"), Color("d98a4e"), Color("c8aa6b"), Color("6f8872")]
const COVERS = [Color("c7d49c"), Color("c9c3ec"), Color("b9e0d6"), Color("f3cfa6"), Color("d2d8ea"), Color("d9d2b9")]

static func display_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia"])
	f.font_weight = 700
	return f

static func body_font(heavy := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI"])
	f.font_weight = 700 if heavy else 400
	return f

static func mono_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New"])
	f.font_weight = 700
	return f

static func box(color: Color, radius := 22, border := Color.TRANSPARENT, thickness := 0, shadow := 0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(radius)
	st.border_color = border
	st.set_border_width_all(thickness)
	if shadow > 0:
		# A flat "lifted paper" edge under the card, as on the mockups.
		if thickness == 0: st.border_color = CARD_EDGE
		st.border_width_bottom = shadow
	return st

## Paints a primary (teal pill), secondary (card) or accent (amber) button.
static func style_button(b: Button, kind := "primary", points := 28, radius := 40) -> void:
	var fill: Color = TEAL if kind == "primary" else (AMBER if kind == "accent" else CARD)
	var text: Color = ON_TEAL if kind == "primary" else INK
	var edge: Color = Color.TRANSPARENT if kind != "secondary" else CARD_EDGE
	b.add_theme_font_override("font", body_font(true))
	b.add_theme_font_size_override("font_size", points)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, text)
	b.add_theme_color_override("font_pressed_color", INK if kind == "primary" else TEAL)
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
	b.add_theme_stylebox_override("normal", box(fill, radius, edge, 2 if kind == "secondary" else 0))
	b.add_theme_stylebox_override("hover", box(fill.lightened(0.08), radius, edge, 2 if kind == "secondary" else 0))
	b.add_theme_stylebox_override("pressed", box(AMBER if kind == "primary" else TEAL_SOFT, radius))
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, radius, AMBER, 3))
	b.add_theme_stylebox_override("disabled", box(Color(CARD_EDGE, 0.7), radius))
	animate_press(b)

## Shared press feedback: the button sinks slightly while held and springs back.
static func animate_press(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size/2)
	b.pivot_offset = b.size/2
	b.button_down.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", b.get_meta("layout_scale",Vector2.ONE)*0.96, 0.08).set_ease(Tween.EASE_OUT))
	b.button_up.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", b.get_meta("layout_scale",Vector2.ONE), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## Ruled-paper background for a full screen.
class Paper extends Control:
	var tint := PAPER
	var rule := RULE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), tint)
		var y := 64.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), rule, 2)
			y += 64.0

## Ribbon bookmark hanging from the top edge of a card.
class Ribbon extends Control:
	var color := Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var shape := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x/2, size.y*0.8), Vector2(0, size.y)])
		draw_colored_polygon(shape, color)
		# Polygons are not antialiased; a thin smooth outline softens the notch.
		draw_polyline(shape + PackedVector2Array([shape[0]]), color, 1.5, true)
