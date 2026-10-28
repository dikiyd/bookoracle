extends CanvasLayer
const DATA=preload("res://oracle_data.json")
const UI=preload("res://ui_theme.gd")
const Brand=preload("res://branding.gd")
const FinalCard=preload("res://final_card.gd")
const OracleEngine=preload("res://oracle_engine.gd")
const Learning=preload("res://oracle_learning.gd")
var engine=OracleEngine.new()
var learning=Learning.new()
var final_card: Control
var display_font:=UI.display_font()
var body_font:=UI.body_font(true)
var db: Dictionary
var mode:="books"
var candidates: Array=[]
var scores: Dictionary={}
var asked: Array=[]
var answers: Array=[]
var excluded: Array=[]
var question:=""
var picked: Dictionary={}
var round_state:="home"
var suggested: Array=[]
const HERO_QUESTION_LIMIT=20
var panel: VBoxContainer
var surface: Control
var locations: Dictionary={}
var status: Label
var location_input: LineEdit
var guide: Control
var revision:=0
var busy:=false
var selection: Control
const CATALOG_PAGE_SIZE=6
var catalog_matches: Array=[]
var catalog_entries: Array=[]
var catalog_page:=0
var catalog_rows: VBoxContainer
var catalog_count: Label
var catalog_previous: Button
var catalog_next: Button
var keyboard: CanvasLayer
var horizontal_row: HBoxContainer
var original_order: Array[Control] = []

func _ready() -> void:
	db=learning.load_catalog(DATA.data)
	if FileAccess.file_exists("user://oracle_locations.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://oracle_locations.json"))
		if saved is Dictionary: locations=saved
	for book in db.books:
		if book.has("location"): locations[book.id] = book.location
	surface=Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(surface)
	var bg=preload("res://oracle_backdrop.gd").new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(bg)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(80,40)
	scroll.size=Vector2(920,1840)
	surface.add_child(scroll)
	panel=VBoxContainer.new()
	panel.custom_minimum_size=Vector2(890,1740)
	# Keep navigation at the top; each screen gives its actions their own breathing room.
	panel.alignment=BoxContainer.ALIGNMENT_BEGIN
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation",24)
	scroll.add_child(panel)
	var gestures := preload("res://touch_catalog.gd").new()
	gestures.enabled = func(): return round_state == "teaching"
	scroll.add_child(gestures)
	get_viewport().size_changed.connect(func(): call_deferred("reflow"))
	keyboard = preload("res://touch_keyboard.gd").new()
	add_child(keyboard)
	keyboard.changed.connect(func(): call_deferred("reflow"))
	home()

func bind_keyboard(edit: LineEdit) -> void:
	keyboard.bind(edit)

func hide_keyboard() -> void:
	if is_instance_valid(keyboard): keyboard.close()

func clear() -> void:
	hide_keyboard()
	revision+=1
	original_order.clear()
	horizontal_row=null
	call_deferred("reflow")
	if is_instance_valid(final_card): final_card.queue_free()
	busy=false
	guide=null
	panel.get_parent().scroll_vertical=0
	for node in panel.get_children():
		panel.remove_child(node)
		node.queue_free()

func reflow() -> void:
	if not is_inside_tree() or not is_instance_valid(panel): return
	var canvas := get_viewport().get_visible_rect().size
	var shell = get_parent().get_node_or_null("KioskShell")
	if shell != null and shell.staff_session: canvas = Vector2(1080,1920)
	var wide := canvas.x>canvas.y
	surface.size=canvas
	var scroll := panel.get_parent() as ScrollContainer
	scroll.position=Vector2(60,40) if wide else Vector2(80,40)
	scroll.size=canvas-Vector2(120,140) if wide else Vector2(920,1840)
	if is_instance_valid(keyboard) and keyboard.height > 0:
		scroll.size.y = canvas.y - keyboard.height - scroll.position.y - 20
	# Flatten a previous two-column arrangement before applying the new orientation.
	if is_instance_valid(horizontal_row):
		for item in original_order:
			if is_instance_valid(item): item.reparent(panel)
		panel.remove_child(horizontal_row); horizontal_row.queue_free(); horizontal_row=null
	original_order.clear()
	for item in panel.get_children():
		if item is Control: original_order.append(item)
	panel.custom_minimum_size=Vector2(0,0) if wide else Vector2(890,1740)
	for item in original_order:
		if item.has_meta("portrait_minimum"): item.custom_minimum_size=item.get_meta("portrait_minimum")
	if not wide: return
	var feature: Control=panel.get_node_or_null("Conversation")
	if feature==null and is_instance_valid(guide) and guide.get_parent()==panel: feature=guide
	if feature==null: return
	horizontal_row=HBoxContainer.new()
	horizontal_row.add_theme_constant_override("separation",60)
	panel.add_child(horizontal_row)
	var left:=VBoxContainer.new(); left.custom_minimum_size=Vector2(920,0)
	var right:=VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",20)
	horizontal_row.add_child(left); horizontal_row.add_child(right)
	for item in original_order:
		if not item.has_meta("portrait_minimum"): item.set_meta("portrait_minimum",item.custom_minimum_size)
		item.reparent(left if item==feature else right)
		if item==feature:
			item.custom_minimum_size.y=780 if item.name=="Conversation" else 740
		elif item.get_class()=="Control": item.custom_minimum_size.y=minf(item.custom_minimum_size.y,20)

func label(text: String, size:=32) -> Label:
	var l=Label.new()
	l.text=text
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_font_override("font",display_font if size>=45 else (UI.mono_font() if size<=25 else body_font))
	l.add_theme_color_override("font_color",UI.TEAL if size<=25 else UI.INK)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	return l

func button(text: String, action: Callable, kind:="secondary") -> Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(0,104)
	UI.style_button(b,kind,34,32)
	b.get_theme_stylebox("normal").border_width_bottom=6
	b.pressed.connect(action)
	panel.add_child(b)
	return b

## Akinator-like answers: strong green «Да», red «Нет», softer tones for the in-between ones.
const ANSWER_COLORS := {"Да":Color("3f9a5f"),"Нет":Color("c4513d"),"Я не знаю":Color("d9cfbb"),"Возможно / частично":Color("a8d39a"),"Скорее нет / не совсем":Color("efb1a1")}

func paint(b: Button, fill: Color) -> void:
	# Strong green and red take white text; the pale in-between answers take ink.
	var text_color: Color = Color.WHITE if fill.get_luminance() < 0.6 else UI.INK
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		b.add_theme_color_override(state,text_color)
	var normal := UI.box(fill,40,Color.TRANSPARENT,0,7)
	normal.border_color=fill.darkened(0.25)
	b.add_theme_stylebox_override("normal",normal)
	var hover := UI.box(fill.lightened(0.08),40,Color.TRANSPARENT,0,7)
	hover.border_color=fill.darkened(0.25)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",UI.box(fill.darkened(0.12),40))

func back_pill() -> void:
	var shell=get_parent().get_node_or_null("KioskShell")
	var staff: bool=shell!=null and shell.staff_session
	var b := button("← Настройки игры" if staff else "← Сначала",shell.return_to_service if staff else home)
	b.custom_minimum_size=Vector2(260,72)
	b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size",26)

## How sure the oracle is: the share of the leading candidate among all remaining ones.
func confidence() -> float:
	return engine.confidence(scores,excluded)

func confidence_meter() -> void:
	var share:=confidence()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	panel.add_child(row)
	var cap := Label.new()
	cap.text="УВЕРЕННОСТЬ %d%%" % roundi(share*100)
	cap.add_theme_font_override("font",UI.mono_font()); cap.add_theme_font_size_override("font_size",22); cap.add_theme_color_override("font_color",Color("5b4f9a"))
	row.add_child(cap)
	var bar := ProgressBar.new()
	bar.show_percentage=false
	bar.min_value=0; bar.max_value=100; bar.value=share*100
	bar.custom_minimum_size=Vector2(0,22)
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background",UI.box(Color("dcd4f2"),11))
	bar.add_theme_stylebox_override("fill",UI.box(Color("7d72c2"),11))
	row.add_child(bar)

func heading(title: String) -> void:
	back_pill()
	label("КНИЖНЫЙ ОРАКУЛ",25)
	label(title,51)
	add_guide("idle",215)

func home() -> void:
	round_state="home"
	clear()
	var masthead=label(Brand.header(),24)
	masthead.custom_minimum_size.y=72
	masthead.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label("Книжный оракул",60)
	add_guide("idle",640)
	spacer(40)
	label("Загадай книгу или героя —\nя угадаю по твоим ответам.",36)
	spacer(100)
	button("Загадать книгу",func(): start("books"),"primary").custom_minimum_size.y=120
	button("Загадать персонажа",func(): start("heroes"),"accent").custom_minimum_size.y=120
	button("Каталог книг и героев",catalog)
	label("В КАТАЛОГЕ: КНИГ — %d · ГЕРОЕВ — %d" % [db.books.size(),db.heroes.size()],22)

func spacer(height: float) -> void:
	var gap=Control.new()
	gap.custom_minimum_size.y=height
	gap.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(gap)

func close() -> void:
	get_parent().oracle_open=false
	get_parent().show_menu()
	queue_free()

func start(kind: String) -> void:
	db=learning.load_catalog(DATA.data)
	mode=kind
	picked={}
	suggested=[]
	engine.configure(db,kind)
	candidates=engine.candidates
	scores.clear()
	asked.clear()
	answers.clear()
	excluded.clear()
	for item in candidates: scores[item.id]=0.0
	next_question()

func ranked() -> Array:
	return engine.ranked(scores,excluded)

func choose_question() -> String:
	return engine.choose_question(scores,asked,excluded,answers)

func question_limit() -> int:
	return HERO_QUESTION_LIMIT if mode=="heroes" else OracleEngine.MAX_QUESTIONS

func next_question() -> void:
	var list=ranked()
	if list.is_empty(): no_match(); return
	if engine.should_guess(scores,answers,excluded,asked):
		guess()
		return
	if asked.size()>=question_limit():
		finish_uncertain()
		return
	question=choose_question()
	if question=="":
		finish_uncertain()
		return
	round_state="question"
	clear()
	back_pill()
	label("ВОПРОС %d" % (asked.size()+1),25)
	confidence_meter()
	var conversation=Control.new()
	conversation.name="Conversation"
	conversation.custom_minimum_size=Vector2(0,1060)
	panel.add_child(conversation)
	add_guide("ask",650)
	panel.remove_child(guide)
	conversation.add_child(guide)
	# The speech sits above and to the right, outside every animated pose.
	guide.position=Vector2(0,350)
	guide.custom_minimum_size=Vector2(0,0)
	guide.size=Vector2(450,560)
	var bubble=PanelContainer.new()
	bubble.name="QuestionBubble"
	bubble.position=Vector2(360,20)
	bubble.size=Vector2(560,300)
	bubble.custom_minimum_size=Vector2(560,300)
	var paper=StyleBoxFlat.new()
	paper.bg_color=UI.CARD
	paper.border_color=UI.CARD_EDGE
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(24)
	paper.set_content_margin_all(30)
	bubble.add_theme_stylebox_override("panel",paper)
	conversation.add_child(bubble)
	var tail=Polygon2D.new()
	tail.name="SpeechTail"
	tail.polygon=PackedVector2Array([Vector2(70,298),Vector2(20,330),Vector2(130,298)])
	tail.color=paper.bg_color
	tail.antialiased=true
	bubble.add_child(tail)
	var question_label=Label.new()
	question_label.name="Question"
	question_label.text=engine.questions[question]
	question_label.autowrap_mode=TextServer.AUTOWRAP_WORD
	question_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	question_label.add_theme_font_override("font",display_font)
	question_label.add_theme_font_size_override("font_size",question_font_size(question_label.text))
	question_label.add_theme_color_override("font_color",UI.INK)
	bubble.add_child(question_label)
	var responses=PanelContainer.new()
	responses.name="Responses"
	responses.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	panel.add_child(responses)
	var responses_list=VBoxContainer.new()
	responses_list.add_theme_constant_override("separation",14)
	responses.add_child(responses_list)
	# «Да» and «Нет» side by side and big; the three softer answers below.
	var main_row:=HBoxContainer.new()
	main_row.add_theme_constant_override("separation",14)
	responses_list.add_child(main_row)
	for pair in [["Да",1.0],["Нет",-1.0],["Я не знаю",0.0],["Возможно / частично",0.5],["Скорее нет / не совсем",-0.5]]:
		var answer_button:=button(pair[0],answer_clicked.bind(pair[1]))
		panel.remove_child(answer_button)
		paint(answer_button,ANSWER_COLORS[pair[0]])
		if pair[1]==1.0 or pair[1]==-1.0:
			answer_button.custom_minimum_size=Vector2(0,132)
			answer_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			answer_button.add_theme_font_size_override("font_size",44)
			main_row.add_child(answer_button)
		else:
			answer_button.custom_minimum_size.y=92
			answer_button.add_theme_font_size_override("font_size",30)
			responses_list.add_child(answer_button)

func question_font_size(text: String) -> int:
	for points in [42,40,38,36,34,32,30,28]:
		var fits=true
		for word in text.split(" "):
			if display_font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x>500: fits=false
		if fits and display_font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,500,points).y<=240:
			return points
	return 28

func add_guide(mood: String, height: float) -> void:
	guide=preload("res://book_guide.gd").new()
	guide.custom_minimum_size=Vector2(0,height)
	panel.add_child(guide)
	guide.set_mood(mood)

func answer_clicked(value: float) -> void:
	if busy: return
	busy=true
	var ticket:=revision
	if is_instance_valid(guide): guide.set_mood("think")
	await get_tree().create_timer(.55).timeout
	if ticket!=revision: return
	respond(value)

func respond(value: float) -> void:
	if question.is_empty(): return
	asked.append(question)
	answers.append(value)
	engine.update_scores(scores,question,value)
	next_question()

func undo() -> void:
	if asked.is_empty(): return
	asked.pop_back()
	answers.pop_back()
	engine.rebuild_scores(scores,asked,answers)
	next_question()

func guess() -> void:
	var list=ranked()
	if list.is_empty(): no_match(); return
	picked=list[0]
	round_state="guess"
	question=""
	clear()
	back_pill()
	label("Я ДУМАЮ, ЭТО…",28)
	add_guide("happy",480)
	var reveal:=PanelContainer.new()
	var plate:=UI.box(UI.TEAL,30,UI.AMBER,4)
	plate.set_content_margin_all(36)
	reveal.add_theme_stylebox_override("panel",plate)
	panel.add_child(reveal)
	var words:=VBoxContainer.new(); words.add_theme_constant_override("separation",10); reveal.add_child(words)
	var name_label:=Label.new(); name_label.text=picked.get("title",picked.get("name","")); name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font",display_font); name_label.add_theme_font_size_override("font_size",64); name_label.add_theme_color_override("font_color",UI.ON_TEAL)
	words.add_child(name_label)
	var sub:=Label.new(); sub.text=("Из книги «%s»" % book_for(picked).title) if mode=="heroes" else picked.author
	if mode=="heroes" and books_for(picked).size()>1: sub.text="Встречается в нескольких книгах каталога"
	sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font",body_font); sub.add_theme_font_size_override("font_size",32); sub.add_theme_color_override("font_color",UI.AMBER)
	words.add_child(sub)
	# The plate pops in like a card being revealed.
	reveal.pivot_offset=Vector2(445,150); reveal.scale=Vector2.ONE*0.85; reveal.modulate.a=0.0
	var t:=reveal.create_tween().set_parallel(true)
	t.tween_property(reveal,"scale",Vector2.ONE,0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(reveal,"modulate:a",1.0,0.25)
	label("Я угадал?",40)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",14); panel.add_child(row)
	for pair in [["Да, угадал!",show_book,"Да"],["Нет, попробуй ещё",reject,"Нет"]]:
		var b:=button(pair[0],pair[1])
		panel.remove_child(b)
		paint(b,ANSWER_COLORS[pair[2]])
		b.custom_minimum_size=Vector2(0,120); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(b)
	button("Указать правильный ответ",teach)

func reject() -> void:
	excluded.append(picked.id)
	picked={}
	if excluded.size()>=3: no_match()
	else: next_question()

func finish_uncertain() -> void:
	suggested=engine.supported_candidates(scores,asked,answers,excluded,3)
	if suggested.is_empty():
		no_match()
		return
	round_state="shortlist"
	question=""
	picked={}
	clear()
	heading("Давай проверим догадку" if suggested.size()==1 else "Похоже на одного из них")
	guide.set_mood("think")
	if mode=="books":
		label("Совпало несколько признаков. Это твоя книга?" if suggested.size()==1 else "Есть несколько совпадений. Твоя книга среди них?",36)
	else:
		label("Совпало несколько признаков. Это твой герой?" if suggested.size()==1 else "Есть несколько совпадений. Твой герой среди них?",36)
	for item in suggested:
		if mode=="books":
			var choice=button("",confirm_suggestion.bind(item),"primary")
			choice.custom_minimum_size.y=160
			var title_label=Label.new()
			title_label.text=item.title
			title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			title_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			title_label.offset_left=24; title_label.offset_right=-24
			title_label.offset_top=16; title_label.offset_bottom=-16
			title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			title_label.add_theme_font_override("font",body_font)
			title_label.add_theme_font_size_override("font_size",32)
			title_label.add_theme_color_override("font_color",UI.ON_TEAL)
			choice.add_child(title_label)
			choice.button_down.connect(func(): title_label.add_theme_color_override("font_color",UI.INK))
			choice.button_up.connect(func(): title_label.add_theme_color_override("font_color",UI.ON_TEAL))
		else:
			button(item.name,confirm_suggestion.bind(item),"primary")
	button("Никого из них — научить хранителя",teach)
	button("Сыграть ещё",home)

func confirm_suggestion(item: Dictionary) -> void:
	picked=item
	show_book()

func no_match() -> void:
	round_state="no_match"
	picked={}
	suggested=[]
	question=""
	clear()
	heading("Пока не удалось угадать")
	guide.set_mood("think")
	label("Возможно, этой книги или героя пока нет в моём наборе, либо ответов недостаточно.",38)
	button("Научить хранителя",teach,"primary")
	button("Посмотреть доступные книги и героев",catalog)
	button("Попробовать снова",home)

func book_for(item: Dictionary) -> Dictionary:
	if item.has("title"): return item
	for b in db.books:
		if b.id==item.book: return b
	return {}

func books_for(item: Dictionary) -> Array:
	if item.has("title"): return [item]
	var ids: Array=item.get("books",[item.get("book","")])
	return db.books.filter(func(book): return book.id in ids)

func teach() -> void:
	round_state="teaching"
	clear()
	heading("Подскажи правильный ответ")
	var form=load("res://oracle_teaching.gd").new()
	form.name="TeachingForm"
	panel.add_child(form)
	form.setup(self,learning)

func show_book() -> void:
	round_state="confirmed"
	# The confirmation button is the learning boundary; an unconfirmed guess is never saved.
	if not asked.is_empty(): learning.record_confirmation(picked.id,asked,answers)
	var choices=books_for(picked)
	if choices.size()>1:
		clear()
		heading("В какой книге ты его загадал?")
		label(picked.name,40)
		var selection_books=OptionButton.new()
		selection_books.custom_minimum_size=Vector2(0,90)
		selection_books.add_theme_font_override("font",UI.body_font())
		selection_books.add_theme_font_size_override("font_size",28)
		for book in choices: selection_books.add_item(book.title)
		panel.add_child(selection_books)
		button("Показать книгу",func(): show_book_card(choices[selection_books.selected]))
		return
	show_book_card(book_for(picked))

func show_book_card(b: Dictionary) -> void:
	clear()
	final_card=FinalCard.create({"game":"КНИЖНЫЙ ОРАКУЛ","game_id":"oracle","ribbon":UI.RIBBONS[1],"eyebrow":"Оракул угадал","title":b.title,"author":b.get("author",""),
		"location":str(locations.get(b.id,"")),"actions":[["Сыграть ещё  →",home]]})
	surface.add_child(final_card)

func catalog() -> void:
	clear()
	heading("Книги и герои в каталоге")
	label("Ищи по названию, автору или имени героя.",27)
	var names_by_book: Dictionary={}
	for hero in db.heroes:
		for id in hero.get("books",[hero.book]):
			if not names_by_book.has(id): names_by_book[id]=[]
			names_by_book[id].append(hero.name)
	catalog_entries=[]
	for book in db.books:
		var names: Array=names_by_book.get(book.id,[])
		var text=book.title+"\n"+book.author
		catalog_entries.append({"text":text,"names":names,"search":(text+"\n"+", ".join(names)).to_lower().replace("ё","е")})
	var search=LineEdit.new()
	search.name="CatalogSearch"
	search.custom_minimum_size=Vector2(0,80)
	search.placeholder_text="Название, автор или имя героя"
	search.add_theme_font_override("font",UI.body_font())
	search.add_theme_font_size_override("font_size",30)
	search.add_theme_color_override("font_color",UI.INK)
	search.add_theme_color_override("font_placeholder_color",UI.MUTED)
	var search_paper=UI.box(UI.CARD,20,UI.CARD_EDGE,2)
	search_paper.content_margin_left=22
	search_paper.content_margin_right=22
	search.add_theme_stylebox_override("normal",search_paper)
	search.add_theme_stylebox_override("focus",UI.box(Color.TRANSPARENT,20,UI.AMBER,3))
	panel.add_child(search)
	bind_keyboard(search)
	catalog_count=label("",24)
	catalog_rows=VBoxContainer.new()
	catalog_rows.name="CatalogRows"
	catalog_rows.add_theme_constant_override("separation",22)
	panel.add_child(catalog_rows)
	var pager=HBoxContainer.new()
	pager.add_theme_constant_override("separation",24)
	panel.add_child(pager)
	catalog_previous=button("← Предыдущие",func(): change_catalog_page(-1))
	catalog_next=button("Следующие →",func(): change_catalog_page(1))
	for b in [catalog_previous,catalog_next]:
		panel.remove_child(b)
		b.custom_minimum_size.y=84
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		pager.add_child(b)
	search.text_changed.connect(filter_catalog)
	filter_catalog("")

func filter_catalog(query: String) -> void:
	var needle=query.strip_edges().to_lower().replace("ё","е")
	catalog_matches=[]
	for entry in catalog_entries:
		if not needle.is_empty() and not needle in entry.search: continue
		var text: String=entry.text
		var names: Array=entry.names
		if not needle.is_empty():
			var matching_names=names.filter(func(value): return needle in str(value).to_lower().replace("ё","е"))
			if not matching_names.is_empty(): names=matching_names
		if not names.is_empty():
			text+="\nГерои: "+", ".join(names.slice(0,5))
			if names.size()>5: text+=" · ещё %d" % (names.size()-5)
		catalog_matches.append(text)
	catalog_page=0
	refresh_catalog_page()

func change_catalog_page(direction: int) -> void:
	catalog_page=clampi(catalog_page+direction,0,maxi(0,ceili(catalog_matches.size()/float(CATALOG_PAGE_SIZE))-1))
	refresh_catalog_page()
	panel.get_parent().scroll_vertical=0

func refresh_catalog_page() -> void:
	for child in catalog_rows.get_children():
		catalog_rows.remove_child(child)
		child.queue_free()
	var first=catalog_page*CATALOG_PAGE_SIZE
	var last=mini(first+CATALOG_PAGE_SIZE,catalog_matches.size())
	catalog_count.text="Ничего не найдено" if catalog_matches.is_empty() else "%d–%d ИЗ %d" % [first+1,last,catalog_matches.size()]
	for index in range(first,last):
		var entry=label(catalog_matches[index],28)
		entry.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		panel.remove_child(entry)
		catalog_rows.add_child(entry)
	catalog_previous.disabled=catalog_page==0
	catalog_next.disabled=last>=catalog_matches.size()

func editor() -> void:
	clear()
	heading("Расположение книг")
	label("Выбери книгу и укажи реальный адрес: зал, стеллаж, полка. Данные сохраняются на этом компьютере.",29)
	selection=preload("res://search_picker.gd").new()
	selection.custom_minimum_size=Vector2(0,90)
	selection.add_theme_font_size_override("font_size",24)
	for b in db.books: selection.add_item(b.title)
	panel.add_child(selection)
	bind_keyboard(selection.edit)
	selection.selected=0
	location_input=LineEdit.new()
	location_input.custom_minimum_size=Vector2(0,90)
	location_input.add_theme_font_size_override("font_size",28)
	location_input.placeholder_text="Например: зал 2, стеллаж 5, полка 3"
	location_input.max_length=180
	panel.add_child(location_input)
	bind_keyboard(location_input)
	selection.item_selected.connect(load_location)
	load_location(0)
	button("Сохранить расположение",save_location)
	status=label("",26)
	label("Адреса полок сохраняются отдельно от каталога и остаются после обновления игры.",26)

func load_location(index: int) -> void:
	location_input.text=str(locations.get(db.books[index].id,""))


func save_location() -> void:
	if selection.selected < 0: status.text="Выберите книгу из результатов поиска."; return
	var library=preload("res://library_store.gd").new()
	var book: Dictionary=db.books[selection.selected].duplicate(true)
	book["location"]=location_input.text.strip_edges()
	if library.save_rows([book]):
		locations[book.id]=book.location
		db.books[selection.selected]=book
		status.text="Сохранено. Полка обновлена в общем каталоге книг."
	else: status.text=library.error
