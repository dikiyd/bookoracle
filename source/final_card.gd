extends Control
## The shared ending of every game: a book from the library's collection, where to find it
## and whom to ask. Games pass the book and up to two actions; the kiosk bar handles «Все игры».
const UI = preload("res://ui_theme.gd")
const Brand = preload("res://branding.gd")
const Guide = preload("res://book_guide.gd")
const Stats = preload("res://stats.gd")
const Ticket = preload("res://ticket.gd")
## Fixed places for the two actions, so games that hit-test by coordinates stay in step.
const ACTION_RECTS = [Rect2(160, 1450, 760, 96), Rect2(160, 1560, 760, 84)]
var data: Dictionary = {}
var action_buttons: Array[Button] = []
var library_book: Dictionary = {}

## data: game (header), ribbon (Color), eyebrow, title, author, reason, location, in_stock (bool),
## actions: [[label, Callable], …]. Logs the «final» event for the report.
static func create(info: Dictionary) -> Control:
	var card = load("res://final_card.gd").new()
	card.data = info
	Stats.log_event("final", str(info.get("game_id", "")), 0, str(info.get("title", "")))
	card.data["stamped"] = Ticket.award(str(info.get("game_id", "")))
	return card

func _ready() -> void:
	var catalogue = preload("res://library_store.gd").new()
	var identity = catalogue.identity(str(data.get("title","")), str(data.get("author","")))
	for book in catalogue.all():
		if catalogue.identity(str(book.title),str(book.author)) == identity:
			library_book = book
			break
	size = Vector2(1080, 1920)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := UI.Paper.new()
	paper.size = size
	add_child(paper)
	var ribbon := UI.Ribbon.new()
	ribbon.color = data.get("ribbon", UI.AMBER)
	ribbon.position = Vector2(1018, 0)
	ribbon.size = Vector2(44, 104)
	add_child(ribbon)
	text(Brand.header(str(data.get("game", ""))), Rect2(60, 40, 900, 46), 22, UI.TEAL, UI.mono_font())
	text(str(data.get("eyebrow", "ИГРА ПРОЙДЕНА")).to_upper(), Rect2(60, 100, 960, 44), 24, UI.AMBER_DEEP, UI.mono_font())
	text("Продолжение — в книге", Rect2(60, 140, 960, 84), 64, UI.INK, UI.display_font())
	if data.get("stamped", false):
		# A new stamp in the reader's ticket: a small amber pill with the count.
		var pill := Panel.new()
		# Sits between the title and the mascot, clear of top navigation in any game.
		pill.position = Vector2(620, 300); pill.size = Vector2(380, 52)
		pill.add_theme_stylebox_override("panel", UI.box(UI.AMBER, 26))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pill)
		var count := Label.new()
		count.text = "+ ШТАМП В БИЛЕТ  ·  %d из %d" % [Ticket.stamps.size(), Ticket.GOAL]
		count.size = pill.size; count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_override("font", UI.mono_font()); count.add_theme_font_size_override("font_size", 20); count.add_theme_color_override("font_color", UI.INK)
		pill.add_child(count)
	cover(Rect2(90, 250, 470, 560))
	if not str(library_book.get("description",data.get("description",""))).is_empty():
		var about := Button.new()
		about.text = "О книге"
		about.position = Vector2(125,740); about.size = Vector2(400,64)
		UI.style_button(about,"secondary",28,20)
		about.pressed.connect(show_description)
		add_child(about)
	var host := Guide.new()
	host.position = Vector2(590, 400)
	host.size = Vector2(440, 440)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	host.set_mood("happy")
	var reason := str(data.get("reason", ""))
	if not reason.is_empty():
		text(reason, Rect2(90, 830, 900, 90), 30, UI.INK.lightened(0.1), UI.body_font(), true)
	ticket(Rect2(60, 940, 960, 420))
	text("Наличие экземпляра уточни у %s." % Brand._genitive(Brand.value("keeper")), Rect2(60, 1372, 960, 44), 24, UI.MUTED, UI.body_font()).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions: Array = data.get("actions", [])
	for i in range(mini(actions.size(), ACTION_RECTS.size())):
		var b := Button.new()
		b.text = actions[i][0]
		b.position = ACTION_RECTS[i].position
		b.size = ACTION_RECTS[i].size
		UI.style_button(b, "primary" if i == 0 else "secondary", 36 if i == 0 else 30, 40)
		b.pressed.connect(actions[i][1])
		add_child(b)
		action_buttons.append(b)
	# The ending lifts in gently, like the catalogue screens.
	modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.3)
	position.y = 24.0
	t.tween_property(self, "position:y", 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	preload("res://game_layout.gd").install(self,"final")

func text(value: String, rect: Rect2, points: int, color: Color, face: Font, wrap := false) -> Label:
	var l := Label.new()
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", points)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func cover(rect: Rect2) -> void:
	var book = library_book.duplicate(true)
	book.title = str(data.get("title", "")); book.author = str(data.get("author", ""))
	if not book.has("cover"): book.cover = data.get("cover", "")
	var art = preload("res://book_cover.gd").new()
	art.position = rect.position; art.size = rect.size
	var has_image = preload("res://library_store.gd").cover_texture(str(book.cover)) != null
	if has_image: art.size.y -= 160
	art.update_book(book); add_child(art)
	if has_image:
		var caption=text(str(book.title),Rect2(rect.position+Vector2(0,402),Vector2(rect.size.x,84)),30,UI.INK,UI.body_font(true),true)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.max_lines_visible=2; caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS

func show_description() -> void:
	var dialog := CanvasLayer.new()
	dialog.name="BookDescription"; dialog.layer=95
	add_child(dialog)
	var veil=ColorRect.new(); veil.color=Color(0.05,0.09,0.08,.68)
	dialog.add_child(veil)
	var panel=PanelContainer.new(); dialog.add_child(panel)
	panel.add_theme_stylebox_override("panel",UI.box(UI.PAPER,28,UI.CARD_EDGE,2))
	var margin=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,35)
	panel.add_child(margin)
	var column=VBoxContainer.new(); column.add_theme_constant_override("separation",22); margin.add_child(column)
	var heading=Label.new(); heading.text=str(data.get("title","Книга"))
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_override("font",UI.display_font()); heading.add_theme_font_size_override("font_size",36)
	heading.add_theme_color_override("font_color",UI.INK); column.add_child(heading)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	var body = str(library_book.get("genre",""))
	var themes = str(library_book.get("themes",""))
	if not themes.is_empty(): body += "\nТемы и теги: " + themes
	body += "\n\n" + str(library_book.get("description",data.get("description","")))
	var description=Label.new(); description.text=body.strip_edges()
	description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_override("font",UI.body_font()); description.add_theme_font_size_override("font_size",30)
	description.add_theme_color_override("font_color",UI.INK); scroll.add_child(description)
	var close_button=Button.new(); close_button.text="← К книге"; close_button.custom_minimum_size.y=90
	UI.style_button(close_button,"primary",32,28); column.add_child(close_button)
	close_button.pressed.connect(dialog.queue_free)
	var arrange=func():
		var canvas=get_viewport_rect().size
		veil.size=canvas
		panel.size=Vector2(minf(940,canvas.x-80),minf(1080,canvas.y-160))
		panel.position=(canvas-panel.size)/2
	arrange.call()
	get_viewport().size_changed.connect(arrange)
	dialog.tree_exiting.connect(func():
		if get_viewport().size_changed.is_connected(arrange): get_viewport().size_changed.disconnect(arrange))

## «Читательский билет» with where the book is and whom to ask.
func ticket(rect: Rect2) -> void:
	var sheet := Panel.new()
	sheet.position = rect.position
	sheet.size = rect.size
	sheet.add_theme_stylebox_override("panel", UI.box(UI.CARD, 28, Color.TRANSPARENT, 0, 7))
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	var in_stock: bool = data.get("in_stock", true)
	text("ЭТА КНИГА ЕСТЬ В ФОНДЕ" if in_stock else "ПРИМЕР КНИГИ · НАЛИЧИЕ НЕ ПОДТВЕРЖДЕНО", Rect2(rect.position + Vector2(40, 24), Vector2(880, 40)), 22, UI.TEAL, UI.mono_font())
	text("Где найти", Rect2(rect.position + Vector2(40, 74), Vector2(880, 40)), 26, UI.MUTED, UI.body_font())
	var place := str(data.get("location", "")).strip_edges()
	if place.is_empty(): place = Brand.value("shelf")
	text(place if not place.is_empty() else "Полку подскажет %s" % Brand.value("keeper"), Rect2(rect.position + Vector2(40, 112), Vector2(880, 130)), 40, UI.INK, UI.display_font(), true)
	var keeper := Panel.new()
	keeper.position = rect.position + Vector2(32, 270)
	keeper.size = Vector2(rect.size.x-64, 116)
	keeper.add_theme_stylebox_override("panel", UI.box(UI.TEAL, 24))
	keeper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keeper)
	var ask := Label.new()
	ask.text = Brand.ask_keeper() + " — покажет, где она"
	ask.position = Vector2(30, 0)
	ask.size = keeper.size - Vector2(60, 0)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.add_theme_font_override("font", UI.body_font(true))
	ask.add_theme_font_size_override("font_size", 32)
	ask.add_theme_color_override("font_color", UI.ON_TEAL)
	keeper.add_child(ask)
