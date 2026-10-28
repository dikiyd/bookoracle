extends VBoxContainer
## Explicit correction of a completed round. All storage stays local.
const UI = preload("res://ui_theme.gd")
const MAX_CHOICES := 4
var result_buttons: VBoxContainer
var oracle: Node
var learning: RefCounted
var book_search: LineEdit
var book_selection: OptionButton
var book_details: Label
var match_label: Label
var hero_name: LineEdit
var trait_toggle: Button
var trait_fields: VBoxContainer
var trait_prompt: LineEdit
var trait_answer: OptionButton
var save_button: Button
var cancel_button: Button
var replay_button: Button
var status_label: Label
var selected_book_id := ""
var saved_id := ""
var matches: Array = []
var _asked: Array = []
var _answers: Array = []

func setup(owner_oracle: Node, local_learning: RefCounted) -> void:
	oracle = owner_oracle
	learning = local_learning
	_asked = oracle.asked.duplicate()
	_answers = oracle.answers.duplicate()
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Выберите загаданную книгу." if oracle.mode == "books" else "Из какой книги ваш персонаж?", 34)
	book_search = _text_input("Название книги или автор", 240)
	book_search.name = "BookSearch"
	book_search.tooltip_text = "Поиск книги по названию или имени автора"
	book_selection = OptionButton.new()
	book_selection.name = "BookSelection"
	book_selection.custom_minimum_size = Vector2(0, 88)
	book_selection.fit_to_longest_item = false
	book_selection.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.style_button(book_selection, "secondary", 30, 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		book_selection.get_theme_stylebox(state).content_margin_left = 22
		book_selection.get_theme_stylebox(state).content_margin_right = 44
	book_selection.get_popup().add_theme_font_override("font", UI.body_font())
	book_selection.get_popup().add_theme_font_size_override("font_size", 28)
	add_child(book_selection)
	book_selection.hide()
	result_buttons = VBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 10)
	add_child(result_buttons)
	book_details = _label("", 28)
	book_details.visible = false
	match_label = _label("", 26)
	if oracle.mode == "heroes":
		_label("Как зовут персонажа?", 32)
		hero_name = _text_input("Имя персонажа", 160)
		hero_name.name = "HeroName"
		hero_name.tooltip_text = "Имя персонажа из выбранной книги"
		hero_name.text_changed.connect(func(_text): _update_save())
		_add_trait_controls()
	_label("Запомню подтверждённые ответы о признаках книги или героя. Обучение останется на этом компьютере.", 28)
	save_button = _button("Запомнить правильный ответ", save_answer, "primary")
	save_button.name = "SaveAnswer"
	status_label = _label("", 28)
	status_label.visible = false
	replay_button = _button("Сыграть ещё", oracle.home, "primary")
	replay_button.visible = false
	cancel_button = _button("Отмена", oracle.home, "secondary")
	book_search.text_changed.connect(filter_books)
	book_selection.item_selected.connect(select_book)
	filter_books("")
	book_search.grab_focus()

func _add_trait_controls() -> void:
	trait_toggle = Button.new()
	trait_toggle.text = "Добавить вопрос о герое"
	trait_toggle.toggle_mode = true
	trait_toggle.custom_minimum_size.y = 68
	UI.style_button(trait_toggle, "secondary", 28, 22)
	add_child(trait_toggle)
	trait_fields = VBoxContainer.new()
	trait_fields.add_theme_constant_override("separation", 12)
	add_child(trait_fields)
	trait_prompt = _text_input("Например: этот герой умеет летать?", 100)
	remove_child(trait_prompt)
	trait_fields.add_child(trait_prompt)
	trait_prompt.tooltip_text = "Необязательно: вопрос о характере, поступке или способности героя (до 100 знаков)"
	trait_answer = OptionButton.new()
	trait_answer.custom_minimum_size.y = 78
	UI.style_button(trait_answer, "secondary", 30, 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		trait_answer.get_theme_stylebox(state).content_margin_left = 22
		trait_answer.get_theme_stylebox(state).content_margin_right = 44
	trait_answer.get_popup().add_theme_font_override("font", UI.body_font())
	trait_answer.get_popup().add_theme_font_size_override("font_size", 28)
	trait_answer.add_item("Правильный ответ на этот вопрос…")
	trait_answer.add_item("Да")
	trait_answer.add_item("Нет")
	trait_fields.add_child(trait_answer)
	trait_fields.visible = false
	trait_toggle.toggled.connect(func(enabled):
		trait_fields.visible = enabled
		_update_save())
	trait_prompt.text_changed.connect(func(_text): _update_save())
	trait_answer.item_selected.connect(func(_index): _update_save())

func _label(text: String, points: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI.body_font())
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", UI.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label

func _text_input(placeholder: String, limit: int) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = limit
	input.custom_minimum_size = Vector2(0, 86)
	input.add_theme_font_override("font", UI.body_font())
	input.add_theme_font_size_override("font_size", 32)
	input.add_theme_color_override("font_color", UI.INK)
	input.add_theme_color_override("font_placeholder_color", UI.MUTED)
	var normal := UI.box(UI.CARD, 20, UI.CARD_EDGE, 2)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, 20, UI.AMBER, 3))
	add_child(input)
	if oracle.has_method("bind_keyboard"): oracle.bind_keyboard(input)
	return input

func _button(text: String, action: Callable, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 88)
	UI.style_button(button, kind, 32, 28)
	button.pressed.connect(action)
	add_child(button)
	return button

func _normal(text: String) -> String:
	return text.to_lower().replace("ё", "е").strip_edges()

func filter_books(text: String) -> void:
	if not saved_id.is_empty(): return
	selected_book_id = ""
	book_details.visible = false
	matches.clear()
	result_buttons.show()
	book_selection.clear()
	for child in result_buttons.get_children():
		result_buttons.remove_child(child); child.queue_free()
	book_selection.add_item("Выберите книгу из списка…")
	book_selection.set_item_metadata(0, "")
	var query := _normal(text)
	for book in oracle.db.books:
		if query.length() >= 2 and query in _normal(str(book.title) + " " + str(book.author)):
			matches.append(book)
	for index in mini(matches.size(), MAX_CHOICES):
		var book: Dictionary = matches[index]
		var caption := str(book.title) + " · " + str(book.author)
		book_selection.add_item(caption if caption.length() <= 48 else caption.left(47) + "…")
		book_selection.set_item_metadata(index + 1, str(book.id))
		book_selection.set_item_tooltip(index + 1, caption)
		var result := Button.new()
		result.text = caption
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size.y = 78
		result.focus_mode = Control.FOCUS_NONE
		UI.style_button(result, "secondary", 27, 18)
		result.pressed.connect(func(): select_book(index + 1))
		result_buttons.add_child(result)
	book_selection.select(0)
	book_selection.disabled = matches.is_empty()
	if query.length() < 2:
		match_label.text = "Введите хотя бы две буквы названия или фамилии автора."
	elif matches.is_empty():
		match_label.text = "Книга не найдена. Попробуйте часть названия или фамилию автора."
	elif matches.size() > MAX_CHOICES:
		match_label.text = "Найдено %d. Уточните поиск; в списке первые %d." % [matches.size(), MAX_CHOICES]
	else:
		match_label.text = "Найдено книг: %d" % matches.size()
	_update_save()

func select_book(index: int) -> void:
	if not saved_id.is_empty(): return
	if index >= 0 and index < book_selection.item_count: book_selection.select(index)
	selected_book_id = str(book_selection.get_item_metadata(index)) if index >= 0 and index < book_selection.item_count else ""
	book_details.visible = not selected_book_id.is_empty()
	for book in matches:
		if str(book.id) == selected_book_id:
			book_search.text = str(book.title)
			book_search.caret_column = book_search.text.length()
			book_details.text = str(book.title) + "\n" + str(book.author)
			break
	if not selected_book_id.is_empty():
		result_buttons.hide()
		if oracle.has_method("hide_keyboard"): oracle.hide_keyboard()
	_update_save()

func _update_save() -> void:
	if not is_instance_valid(save_button): return
	save_button.disabled = selected_book_id.is_empty() or (is_instance_valid(hero_name) and hero_name.text.strip_edges().is_empty())
	if _has_trait():
		save_button.disabled = save_button.disabled or trait_prompt.text.strip_edges().length() < 5 or trait_answer.selected <= 0

func _has_trait() -> bool:
	return is_instance_valid(trait_toggle) and trait_toggle.button_pressed

func save_answer() -> void:
	if selected_book_id.is_empty() or not saved_id.is_empty(): return
	if _has_trait():
		if trait_answer.selected <= 0:
			_show_status("Выберите правильный ответ на ваш вопрос: «Да» или «Нет».")
			return
		if not learning.validate_trait(trait_prompt.text):
			_show_status(learning.last_error)
			return
	var item_id := selected_book_id
	if oracle.mode == "heroes":
		if hero_name.text.strip_edges().is_empty(): return
		item_id = learning.add_hero(hero_name.text, selected_book_id, oracle.db)
		if item_id.is_empty():
			_show_status(learning.last_error)
			return
	if not learning.record_confirmation(item_id, _asked, _answers):
		_show_status(("Персонаж уже есть в каталоге, но ответы сохранить не удалось. " if oracle.mode == "heroes" else "") + learning.last_error)
		oracle.db = learning.load_catalog(oracle.DATA.data)
		return
	if _has_trait() and not learning.record_trait(item_id, trait_prompt.text, trait_answer.selected == 1):
		_show_status("Ответы уже сохранены, но новый вопрос сохранить не удалось. " + learning.last_error + " Попробуйте ещё раз.")
		oracle.db = learning.load_catalog(oracle.DATA.data)
		return
	saved_id = item_id
	oracle.db = learning.load_catalog(oracle.DATA.data)
	book_search.editable = false
	book_selection.disabled = true
	if is_instance_valid(hero_name): hero_name.editable = false
	if is_instance_valid(trait_toggle):
		trait_toggle.disabled = true
		trait_prompt.editable = false
		trait_answer.disabled = true
	save_button.visible = false
	cancel_button.visible = false
	replay_button.visible = true
	var learned_count:=0
	for i in mini(_asked.size(),_answers.size()):
		if not str(_asked[i]).begins_with("@") and absf(float(_answers[i]))==1.0: learned_count+=1
	if _has_trait():
		_show_status("Запомнил новый вопрос о герое и правильный ответ. Учту их в следующих играх.")
	elif learned_count>0:
		_show_status("Запомнил! В следующей игре учту ваши ответы.")
	else:
		_show_status("Персонаж добавлен в каталог. Для угадывания нужны сведения о его признаках." if oracle.mode=="heroes" else "Ответ подтверждён. Новых уточнений о признаках книги в этой игре не было.")
	replay_button.grab_focus()

func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = true
