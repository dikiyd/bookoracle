extends Control
const UI=preload("res://ui_theme.gd")
const Cases=preload("res://detective_cases.gd")
var host: Node
var case: Dictionary
var index:=0
var preview:=false
var on_exit: Callable
var opened: Array=[]
var selected: Array=[]
var solved: Array=[]
var root_ui: Control
var modal: Control
var status: Label
var connect_button: Button
var card_buttons: Array=[]
var conclusion_buttons: Array=[]
var threads: Control
var scroller: ScrollContainer
var scroll_y:=0
var note:="Читайте улики и выберите две, которые вместе дают вывод."
var order: Array=[]
var number_font:=UI.mono_font()

func _ready() -> void:
	size=Vector2(1080,1920); mouse_filter=Control.MOUSE_FILTER_IGNORE
	order=range(case.evidence.size()); order.shuffle()
	show_board()
func base() -> void:
	if is_instance_valid(root_ui): remove_child(root_ui); root_ui.queue_free()
	modal=null
	root_ui=Control.new(); root_ui.size=size; add_child(root_ui)
	preload("res://game_layout.gd").install(root_ui,"detective")
	var paper=UI.Paper.new(); paper.size=size; root_ui.add_child(paper)
func label(value: String,rect: Rect2,points:=28,color:=UI.INK,display:=false,parent: Node=null) -> Label:
	var out=Label.new(); out.text=value; out.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	out.add_theme_font_override("font",UI.display_font() if display else UI.body_font())
	out.add_theme_font_size_override("font_size",points); out.add_theme_color_override("font_color",color)
	out.position=rect.position; out.size=rect.size; out.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(parent if parent!=null else root_ui).add_child(out)
	fit_label(out,rect.size,points)
	return out
static func fit_label(out: Label,bounds: Vector2,points: int) -> void:
	out.clip_text=true
	for font_size in range(points,20,-1):
		out.add_theme_font_size_override("font_size",font_size); out.size=bounds
		if out.get_line_count()*out.get_line_height()<=bounds.y: break
	out.size=bounds
func scroll_text(value: String,rect: Rect2,parent: Node,points:=30) -> void:
	var scroll=ScrollContainer.new(); scroll.position=rect.position; scroll.size=rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(scroll)
	var content=Label.new(); content.text=value; content.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.custom_minimum_size=Vector2(rect.size.x-24,0)
	content.add_theme_font_override("font",UI.body_font()); content.add_theme_font_size_override("font_size",points)
	content.add_theme_color_override("font_color",UI.INK); scroll.add_child(content)
func button(value: String,rect: Rect2,callback: Callable,style:="secondary",points:=28,parent: Node=null) -> Button:
	var out=Button.new(); out.text=value; out.position=rect.position; out.size=rect.size
	UI.style_button(out,style,points,22); out.pressed.connect(callback)
	(parent if parent!=null else root_ui).add_child(out); return out
func plate(rect: Rect2,color: Color,parent: Node=null) -> Panel:
	var out=Panel.new(); out.position=rect.position; out.size=rect.size
	out.mouse_filter=Control.MOUSE_FILTER_IGNORE; out.add_theme_stylebox_override("panel",UI.box(color,24,UI.CARD_EDGE,2))
	(parent if parent!=null else root_ui).add_child(out); return out
func show_board() -> void:
	base()
	label("БЮРО КНИЖНЫХ ТАЙН  ·  "+("ПРОБА ДЕЛА" if preview else "ДЕЛО %02d"%(index+1)),Rect2(60,35,960,45),23,UI.TEAL)
	label(case.title,Rect2(60,100,960,135),52,UI.INK,true)
	label(case.brief,Rect2(60,240,960,112),28)
	label("Осмотрено %d / %d   ·   Выводов %d / 3" % [opened.size(),case.evidence.size(),solved.size()],Rect2(60,350,960,40),23,UI.MUTED)
	var art=BoardWood.new(); art.position=Vector2(40,405); art.size=Vector2(1000,740); root_ui.add_child(art)
	scroller=ScrollContainer.new(); scroller.position=Vector2(65,430); scroller.size=Vector2(950,690)
	scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root_ui.add_child(scroller)
	var canvas=Control.new(); canvas.custom_minimum_size=Vector2(930,ceili(case.evidence.size()/2.0)*230)
	scroller.add_child(canvas)
	threads=ThreadMap.new(); threads.size=canvas.custom_minimum_size; canvas.add_child(threads)
	card_buttons=[]; card_buttons.resize(case.evidence.size())
	for slot in order.size():
		var i: int=order[slot]
		var card=EvidenceCard.new(); card.data=case.evidence[i]; card.number=slot+1
		card.position=Vector2(12+(slot%2)*470,8+int(slot/2)*230); card.size=Vector2(440,210)
		card.active=i in selected; card.seen=i in opened
		card.pressed.connect(func(): inspect(i)); canvas.add_child(card); card_buttons[i]=card
	for rule_index in solved:
		var rule=case.links[rule_index]
		threads.paths.append([card_buttons[int(rule.a)].position+Vector2(220,14),card_buttons[int(rule.b)].position+Vector2(220,14),UI.TEAL])
	if selected.size()==2: threads.paths.append([card_buttons[selected[0]].position+Vector2(220,14),card_buttons[selected[1]].position+Vector2(220,14),Color("a45b44")])
	scroller.set_deferred("scroll_vertical",scroll_y)
	scroller.get_v_scroll_bar().value_changed.connect(func(value): scroll_y=int(value))
	var pair_text="Выбрано: "+(" и ".join(selected.map(func(v): return "№ %d"%(order.find(v)+1))) if not selected.is_empty() else "коснитесь улики, чтобы прочитать")
	label(pair_text,Rect2(60,1170,960,54),26,UI.TEAL)
	conclusion_buttons=[]
	for i in range(3):
		var found=i in solved
		var control=button(("✓ Вывод " if found else "· Вывод ")+str(i+1),Rect2(60+i*326,1240,308,62),func(): show_conclusion(i),"primary" if found else "secondary",24)
		control.disabled=not found; conclusion_buttons.append(control)
	status=label(note,Rect2(60,1320,960,90),27)
	connect_button=button("К раскрытому делу →" if solved.size()==3 else "Связать две улики",Rect2(60,1440,960,100),show_result if solved.size()==3 else connect_pair,"accent",34)
	connect_button.disabled=selected.size()!=2 and solved.size()!=3
	button("Подсказка",Rect2(60,1565,465,85),hint)
	button("Другое дело →",Rect2(555,1565,465,85),next_case)
	if preview:
		button("← Вернуться к редактору",Rect2(60,1710,960,92),on_exit,"primary",28)
	else:
		label("ДВЕ УЛИКИ → ОДИН ВЫВОД · БЕЗ ШТРАФОВ ЗА ОШИБКУ",Rect2(60,1710,960,58),20,UI.MUTED)

func inspect(which: int) -> void:
	if not which in opened: opened.append(which)
	show_board()
	var evidence=case.evidence[which]
	var sheet=open_sheet("УЛИКА № %d · %s" % [order.find(which)+1,evidence.type],evidence.title,evidence.text)
	var action=button("Убрать из связки" if which in selected else "Выбрать для связи",Rect2(50,810,820,90),func(): choose(which),"primary",30,sheet)
	action.set_meta("choose_evidence",which)
	button("Закрыть",Rect2(50,925,820,74),close_modal,"secondary",28,sheet)
func open_sheet(eyebrow: String,title: String,body: String) -> Panel:
	close_modal()
	modal=Control.new(); modal.size=size; modal.mouse_filter=Control.MOUSE_FILTER_STOP; root_ui.add_child(modal)
	var shade=ColorRect.new(); shade.size=size; shade.color=Color(.08,.13,.11,.48); modal.add_child(shade)
	var sheet=Panel.new(); sheet.position=Vector2(80,310); sheet.size=Vector2(920,1080)
	preload("res://game_layout.gd").install(modal,"modal")
	sheet.add_theme_stylebox_override("panel",UI.box(UI.CARD,30,UI.AMBER,3)); modal.add_child(sheet)
	label(eyebrow,Rect2(50,30,820,58),23,UI.AMBER_DEEP,false,sheet)
	label(title,Rect2(50,110,820,138),42,UI.INK,true,sheet)
	scroll_text(body,Rect2(50,280,820,475),sheet,32)
	return sheet
func close_modal() -> void:
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal); modal.queue_free()
	modal=null
func choose(which: int) -> void:
	if which in selected: selected.erase(which)
	elif selected.size()<2: selected.append(which)
	else:
		close_modal(); note="В связке уже две улики. Откройте выбранную, чтобы убрать её или заменить."; show_board(); return
	note="Теперь выберите вторую улику." if selected.size()==1 else "Что доказывают эти две улики вместе?"
	show_board()
func connect_pair() -> void:
	if selected.size()!=2: return
	var result=Cases.find_link(case,selected[0],selected[1])
	if result<0:
		note="Эта пара пока не даёт общего вывода. Сравните содержание улик или замените одну."
		show_board(); return
	if result in solved:
		note="Эта связь уже найдена. Поищите доказательства другого вывода."; selected=[]; show_board(); return
	solved.append(result); selected=[]; note=case.links[result].title+". "+case.links[result].reason
	if solved.size()==3:
		if not preview and is_instance_valid(host): host.completed=true; host.record_finish()
		show_result()
	else: show_board()
func show_conclusion(which: int) -> void:
	if not which in solved: return
	var sheet=open_sheet("НАЙДЕННЫЙ ВЫВОД %d"%(which+1),case.links[which].title,case.links[which].reason)
	button("К доске улик",Rect2(50,900,820,90),close_modal,"primary",30,sheet)
func hint() -> void:
	for i in range(3):
		if not i in solved:
			note="Подсказка: "+case.links[i].hint; status.text=note; return
func next_case() -> void:
	if preview:
		note="В пробе показано текущее дело. Вернитесь в редактор, чтобы выбрать другое."; status.text=note
	elif is_instance_valid(host): host.start(host.current+1)
func show_result() -> void:
	base()
	root_ui.get_node("ResponsiveLayout").profile="case_result"
	label("ДЕЛО РАСКРЫТО  ·  3 ВЫВОДА",Rect2(60,40,960,48),24,UI.TEAL)
	label(case.title,Rect2(60,115,960,150),54,UI.INK,true)
	for i in range(3):
		var rule=case.links[i]
		var which=i
		button("",Rect2(60,320+i*190,960,170),func(): show_conclusion(which),"secondary")
		label("✓  "+rule.title,Rect2(90,330+i*190,900,64),31,UI.TEAL,true)
		label(rule.reason,Rect2(90,397+i*190,900,78),25)
	plate(Rect2(60,930,960,370),Color("e4e8d9"))
	label("ВОТ ЧТО ПРОИЗОШЛО",Rect2(90,950,900,48),23,UI.TEAL)
	scroll_text(case.resolution,Rect2(90,1010,900,265),root_ui,29)
	button("Продолжение — в книге →",Rect2(60,1370,960,100),show_book,"primary",34)
	button("Ещё раз посмотреть улики",Rect2(60,1500,960,86),show_board,"secondary",28)
	button("← К редактору" if preview else "Следующее дело →",Rect2(60,1620,960,86),on_exit if preview else next_case,"secondary",28)
	label("Проба не сохраняет прохождения и штампы." if preview else "Выводы найдены вами. Теперь можно открыть книгу.",Rect2(60,1750,960,55),22,UI.MUTED)
func show_book() -> void:
	if solved.size()!=3: return
	var book=preload("res://puzzle_data.gd").resolve_book(case.book)
	if not preview and is_instance_valid(host) and not host.recommended.has(book.title):
		var shell=host.get_parent().get_node_or_null("KioskShell")
		if shell==null or not shell.staff_session: preload("res://stats.gd").log_event("recommend","detective",0,book.title)
		host.recommended[book.title]=true
	base()
	var card=load("res://final_card.gd").new()
	card.data={"game":"КНИЖНЫЙ ДЕТЕКТИВ","title":book.title,"author":book.author,"reason":"Книга для продолжения раскрытого дела.","location":book.get("location",""),"in_stock":bool(book.get("stock",false)),"actions":[["← К раскрытому делу",show_result],["К редактору" if preview else "Следующее дело →",on_exit if preview else next_case]]}
	root_ui.add_child(card)

class BoardWood extends Control:
	func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw():
		draw_style_box(UI.box(Color("795e47"),28,Color("624b38"),3),Rect2(Vector2.ZERO,size))
		draw_style_box(UI.box(Color("c3a477"),18,Color("a98a60"),2),Rect2(Vector2(13,13),size-Vector2(26,26)))
		for i in range(150):
			var p=Vector2(24+fmod(i*137.7,size.x-48),24+fmod(i*79.3,size.y-48))
			draw_line(p,p+Vector2(3,1),Color(.35,.24,.13,.12),1,true)
class ThreadMap extends Control:
	var paths: Array=[]
	func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw():
		for path in paths:
			draw_line(path[0]+Vector2(2,3),path[1]+Vector2(2,3),Color(.2,.1,.05,.18),5,true)
			draw_line(path[0],path[1],path[2],3,true)
class EvidenceCard extends Button:
	var data: Dictionary
	var number:=0
	var active:=false
	var seen:=false
	func _ready():
		for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var type=Label.new(); type.text="%02d  ·  %s" % [number,str(data.type).to_upper()]
		type.position=Vector2(24,18); type.size=Vector2(392,32); type.add_theme_font_override("font",UI.mono_font())
		type.add_theme_font_size_override("font_size",20); type.add_theme_color_override("font_color",UI.TEAL)
		type.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(type)
		var title=Label.new(); title.text=data.title; title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_override("font",UI.display_font()); title.add_theme_font_size_override("font_size",31)
		title.add_theme_color_override("font_color",UI.INK); title.position=Vector2(24,52); title.size=Vector2(392,90)
		title.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(title)
		title.clip_text=true
		for points in range(31,20,-1):
			title.add_theme_font_size_override("font_size",points); title.size=Vector2(392,90)
			if title.get_line_count()*title.get_line_height()<=90: break
		var teaser=Label.new(); teaser.text=data.text
		teaser.clip_text=true; teaser.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		teaser.position=Vector2(24,146); teaser.size=Vector2(392,25)
		teaser.add_theme_font_override("font",UI.body_font()); teaser.add_theme_font_size_override("font_size",22)
		teaser.add_theme_color_override("font_color",UI.MUTED); teaser.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(teaser)
		var state=Label.new(); state.text="✓ В связке" if active else ("Прочитано · открыть" if seen else "Коснитесь, чтобы прочитать")
		state.position=Vector2(24,171); state.size=Vector2(392,30); state.add_theme_font_override("font",UI.body_font(true))
		state.add_theme_font_size_override("font_size",22); state.add_theme_color_override("font_color",UI.TEAL if active else UI.MUTED)
		state.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(state)
	func _draw():
		var paper=Color("fff3cc") if data.type=="Записка" else (Color("e8eddb") if data.type=="Показание" else UI.CARD)
		var style=UI.box(paper,12,UI.TEAL if active else Color("d6c4a1"),4 if active else 2)
		style.shadow_size=5; style.shadow_offset=Vector2(2,5); style.shadow_color=Color(.2,.12,.06,.16)
		draw_style_box(style,Rect2(Vector2(0,4),size-Vector2(0,6)))
		draw_circle(Vector2(size.x/2,10),7,Color("9c5c42"),true,-1,true)
		draw_circle(Vector2(size.x/2-2,8),2,Color("d6946d"),true,-1,true)
		var p=Vector2(size.x-37,32)
		var icon=Color(UI.TEAL,.55)
		match data.type:
			"Предмет":
				draw_arc(p,9,0,TAU,32,icon,2,true); draw_line(p+Vector2(7,7),p+Vector2(17,17),icon,4,true)
			"Показание":
				draw_style_box(UI.box(Color.TRANSPARENT,5,icon,2),Rect2(p-Vector2(14,10),Vector2(28,20)))
				draw_polyline(PackedVector2Array([p+Vector2(-5,10),p+Vector2(-9,17),p+Vector2(4,10)]),icon,2,true)
			_:
				draw_rect(Rect2(p-Vector2(10,14),Vector2(21,28)),icon,false,2)
				for i in range(3): draw_line(p+Vector2(-5,-6+i*6),p+Vector2(6,-6+i*6),icon,1.5,true)
