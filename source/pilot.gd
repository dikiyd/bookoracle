extends "res://oracle.gd"
var pilot_active := false

func emit_event(type: String, extra: Dictionary = {}) -> void:
	if not OS.has_feature("web"): return
	var payload := {"channel":"book-oracle", "type":type}
	payload.merge(extra)
	JavaScriptBridge.eval("window.parent.postMessage(" + JSON.stringify(payload) + ",window.location.origin)")

func home() -> void:
	if pilot_active: emit_event("home")
	pilot_active=false
	super.home()
	label("ТЕСТОВАЯ ВЕРСИЯ · ОТЗЫВ — ПОД ИГРОЙ",22)

func close() -> void:
	home()

func back_pill() -> void:
	var b := button("Сначала",home)
	b.custom_minimum_size=Vector2(260,72)
	b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size",26)

func start(kind: String) -> void:
	pilot_active=true
	emit_event("start",{"mode":kind})
	super.start(kind)

func next_question() -> void:
	super.next_question()
	if round_state=="question":
		emit_event("question",{"question":question,"text":engine.questions[question]})
	elif round_state in ["guess","shortlist","no_match"]:
		var choices: Array=[]
		if not picked.is_empty(): choices.append(picked.id)
		for item in suggested: choices.append(item.id)
		emit_event(round_state,{"ids":choices})

func respond(value: float) -> void:
	emit_event("answer",{"question":question,"value":value})
	super.respond(value)

func undo() -> void:
	if not asked.is_empty(): emit_event("undo")
	super.undo()

func reject() -> void:
	emit_event("reject",{"ids":[picked.id]})
	super.reject()

func teach() -> void:
	emit_event("feedback")
	clear()
	heading("Спасибо за помощь")
	label("Укажи книгу и героя в форме отзыва под игрой.",38)
	button("Продолжить игру",home,"primary")

func show_book() -> void:
	round_state="confirmed"
	var book=book_for(picked)
	emit_event("confirmed",{"ids":[picked.id],"bookId":book.get("id",""),
		"bookTitle":book.get("title",""),"character":picked.get("name","")})
	clear()
	heading("Угадал!")
	label(picked.get("name",picked.get("title","")),54)
	label(book.get("title",""),34)
	label("Помоги сделать Оракула лучше: отправь отзыв под игрой.",32)
	button("Сыграть ещё",home,"primary")
