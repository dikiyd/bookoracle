extends RefCounted
## Names and staff settings shown to visitors. Layers, later wins:
## res://settings.json (shipped) → settings.json next to the EXE (installer) → user://portal_settings.json
## (changed by staff in the service menu). Renaming never needs a rebuild.
const DEFAULTS := {"name": "ПОРТАЛ", "library": "", "keeper": "Хранитель", "service_code": "1234", "shelf": "", "stamps": "on", "ticket_prize": "Подойдите к Хранителю — вас ждёт сюрприз", "hidden_games": [], "greetings": GREETINGS, "events": [], "events_set": "no"}
## What the mascot says on the invitation screen, one line at a time; staff edit the list.
const GREETINGS := ["Здравствуйте! Заглянете в книгу?", "Одна загадка? Коснитесь экрана!", "У каждой книги есть своя игра.", "Загадайте книгу — я попробую угадать.", "Сочиним историю с драконом?", "Здесь слова прячутся между строк.", "Пять минут — и новая книга в руках.", "Я знаю, какая книга вам понравится.", "Пушкин, Гоголь, Чехов… Сыграем?", "Кто сказал: «Карету мне, карету!»?", "Соедините буквы — и найдётся книга.", "Тайна плюс история — что получится?", "Ждёте? Давайте поиграем!", "Каждая игра заканчивается книгой.", "Покажу, где стоит интересная книга.", "Проверим, кто лучше знает классику?", "Дракон взял чужую книгу. Поможете?", "Коснитесь меня — я не кусаюсь!", "Сегодня отличный день для чтения.", "Я помню все книги этого зала."]
const STAFF_FILE := "user://portal_settings.json"
const HOME_DEFAULTS := {"show_day":"on"}
static var _values: Dictionary = {}
static var last_error := ""

static func valid_service_code(code: String) -> bool:
	if code.length() < 4 or code.length() > 8: return false
	for character in code:
		if not character in "0123456789": return false
	return true

## Only plain JSON values with the shapes used by the UI are accepted.
static func _valid_setting(key: String, data: Variant) -> bool:
	if key == "service_code": return data is String and valid_service_code(data)
	if key == "hidden_games":
		if not data is Array: return false
		var seen := {}
		for value in data:
			if not (value is int or value is float): return false
			if value != int(value) or value < 0 or value >= 6: return false
			seen[int(value)] = true
		return seen.size() < 6
	if key == "greetings":
		if not data is Array: return false
		for value in data:
			if not value is String or value.strip_edges().is_empty(): return false
		return not data.is_empty()
	if key == "events":
		if not data is Array: return false
		for entry in data:
			if not entry is Dictionary: return false
			for field in ["month", "day", "days", "game"]:
				var value = entry.get(field)
				if not (value is int or value is float) or value != int(value): return false
			if entry.month < 1 or entry.month > 12 or entry.day < 1: return false
			if entry.day > [31,29,31,30,31,30,31,31,30,31,30,31][int(entry.month)-1]: return false
			if entry.days < 1 or entry.days > 366 or entry.game < 0 or entry.game >= 6: return false
			if not entry.get("title") is String or not entry.get("text") is String: return false
		return true
	if not data is String: return false
	if key in ["stamps", "show_day"]: return data in ["on", "off"]
	if key == "events_set": return data in ["yes", "no"]
	return key in ["library", "shelf"] or not data.strip_edges().is_empty()

static func value(key: String) -> String:
	if _values.is_empty(): reload()
	return str(_values.get(key, DEFAULTS.get(key, "")))

static func hidden_games() -> Array:
	if _values.is_empty(): reload()
	return _values.get("hidden_games", [])

static func greetings() -> Array:
	if _values.is_empty(): reload()
	var lines: Array = _values.get("greetings", [])
	return lines if not lines.is_empty() else GREETINGS

static func reload() -> void:
	_values = DEFAULTS.duplicate(true)
	_values.merge(HOME_DEFAULTS)
	_merge("res://settings.json")
	if OS.has_feature("template"):
		_merge(OS.get_executable_path().get_base_dir().path_join("settings.json"))
	_merge(STAFF_FILE)

static func _merge(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return
	var data = parser.data
	if not data is Dictionary: return
	for key in DEFAULTS.merged(HOME_DEFAULTS):
		if not data.has(key) or not _valid_setting(key, data[key]): continue
		if key == "hidden_games":
			# JSON numbers come back as floats; game indices are compared as ints.
			if data.get(key) is Array: _values[key] = data[key].map(func(v): return int(v))
		elif key == "events":
			# Calendar entries; JSON numbers come back as floats, dates are ints.
			if data.get(key) is Array:
				_values[key] = data[key].filter(func(v): return v is Dictionary).map(func(v):
					var e: Dictionary = v.duplicate()
					for k in ["month", "day", "days", "game"]: e[k] = int(e.get(k, 1 if k == "days" else 0))
					return e)
		elif key == "greetings":
			if data.get(key) is Array: _values[key] = data[key].filter(func(v): return v is String and not v.strip_edges().is_empty())
		elif data.get(key) is String and (key in ["library", "shelf"] or not data[key].strip_edges().is_empty()):
			_values[key] = data[key].strip_edges()

## Saves staff changes; only the given keys are written to user://.
static func save(changes: Dictionary) -> bool:
	last_error = ""
	var stored: Dictionary = {}
	if FileAccess.file_exists(STAFF_FILE):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(STAFF_FILE)) != OK or not parser.data is Dictionary:
			last_error = "Файл настроек повреждён. Он сохранён без изменений; нужна проверка специалиста."
			return false
		stored = parser.data
	for key in changes:
		if not key in DEFAULTS.merged(HOME_DEFAULTS) or not _valid_setting(key, changes[key]):
			last_error = "Проверьте значение настройки: " + str(key)
			return false
		stored[key] = changes[key]
	for key in DEFAULTS.merged(HOME_DEFAULTS):
		if stored.has(key) and not _valid_setting(key, stored[key]):
			last_error = "В файле настроек неверное значение: " + str(key) + ". Исходный файл сохранён."
			return false
	# A failed write must leave the previous settings intact.
	var file := FileAccess.open(STAFF_FILE + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать настройки. Проверьте доступ к папке данных."
		return false
	file.store_string(JSON.stringify(stored, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "Ошибка записи настроек. Прежние настройки сохранены."
		return false
	if FileAccess.file_exists(STAFF_FILE) and DirAccess.copy_absolute(STAFF_FILE, STAFF_FILE + ".bak") != OK:
		last_error = "Не удалось создать резервную копию настроек. Изменения не записаны."
		return false
	if DirAccess.rename_absolute(STAFF_FILE + ".tmp", STAFF_FILE) != OK:
		last_error = "Не удалось заменить настройки. Прежний файл сохранён."
		return false
	reload()
	return true

## Product name for headers: «ПОРТАЛ».
static func title() -> String:
	return value("name")

## Header line: «ПОРТАЛ · НИТИ КНИГИ».
static func header(section := "") -> String:
	return title().to_upper() + ("" if section.is_empty() else " · " + section)

## «Спроси эту книгу у Хранителя» — the keeper word is configurable per library.
static func ask_keeper(what := "эту книгу") -> String:
	return "Спроси %s у %s" % [what, _genitive(value("keeper"))]

static func _genitive(word: String) -> String:
	# Covers the usual choices: Хранитель → Хранителя, библиотекарь → библиотекаря, сотрудник → сотрудника.
	if word.ends_with("ь"): return word.left(word.length()-1) + "я"
	if word.ends_with("а"): return word.left(word.length()-1) + "ы"
	if word.ends_with("й"): return word.left(word.length()-1) + "я"
	return word + "а"
