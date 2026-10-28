extends RefCounted
## Local, explicitly confirmed observations. Never edits the shipped catalogue.
## A damaged/unknown-version file is read-only, so a repair cannot silently erase it.
const FORMAT_VERSION := 1
const DEFAULT_PATH := "user://oracle_learning.json"
const MAX_ANSWER_COUNT := 1000000000
var last_error := ""
var _path: String
var _library_path: String
var _state: Dictionary = {"version": FORMAT_VERSION, "observations": {}, "books": [], "heroes": [], "questions": {}}
var _writable := true
var _known_ids: Dictionary = {}
var _question_keys: Dictionary = {}

func _init(path: String = DEFAULT_PATH, library_path: String = "user://library_catalog.json") -> void:
	_path = path
	_library_path = library_path
	_read()

func _read() -> void:
	if not FileAccess.file_exists(_path): return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		_block("Не удалось прочитать сохранённое обучение.")
		return
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not _valid_state(parser.data):
		_block("Файл обучения повреждён или имеет другую версию. Он сохранён без изменений.")
		return
	_state = parser.data
	# Version 1 originally had no user-authored questions.
	if not _state.has("questions"): _state.questions = {}

func _block(message: String) -> void:
	_writable = false
	last_error = message

func _valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("version") != FORMAT_VERSION: return false
	if not value.get("observations") is Dictionary: return false
	if not value.get("books") is Array or not value.get("heroes") is Array: return false
	if not value.get("questions", {}) is Dictionary: return false
	for key in value.get("questions", {}):
		if not key is String or not _valid_text(value.questions[key], 100): return false
		if key != trait_key(value.questions[key]): return false
	var ids: Dictionary = {}
	for kind in ["books", "heroes"]:
		for item in value[kind]:
			if not item is Dictionary or not item.get("id") is String: return false
			if not item.id.begins_with("user_") or ids.has(item.id): return false
			ids[item.id] = true
			if kind == "books":
				if not _valid_text(item.get("title"), 240) or not _valid_text(item.get("author"), 160): return false
			else:
				if not _valid_text(item.get("name"), 160) or not _valid_text(item.get("book"), 160): return false
			if not item.get("tags") is Array or not item.get("facts") is Dictionary: return false
	for id in value.observations:
		if not id is String or not value.observations[id] is Dictionary: return false
		var observation: Dictionary = value.observations[id]
		if not observation.get("answers") is Dictionary: return false
		for key in observation.answers:
			if not key is String or not observation.answers[key] is bool: return false
		var counts = observation.get("answer_counts", {})
		if not counts is Dictionary: return false
		for key in counts:
			if not key is String or not observation.answers.has(key) or not counts[key] is Dictionary: return false
			var tally: Dictionary = counts[key]
			if not _valid_count(tally.get("yes")) or not _valid_count(tally.get("no")): return false
			if int(tally.yes) + int(tally.no) < 1: return false
			if int(tally.yes) > int(tally.no) and not observation.answers[key]: return false
			if int(tally.no) > int(tally.yes) and observation.answers[key]: return false
	return true

func _valid_count(value: Variant) -> bool:
	if not value is int and not value is float: return false
	return is_finite(float(value)) and float(value) >= 0.0 and float(value) <= MAX_ANSWER_COUNT and float(value) == floorf(float(value))

func _valid_text(value: Variant, limit: int) -> bool:
	if not value is String: return false
	var clean: String = value.strip_edges()
	if clean.length() < 1 or clean.length() > limit: return false
	for character in clean:
		if character.unicode_at(0) < 32: return false
	return true

func _normal(value: String) -> String:
	var result := value.strip_edges().to_lower().replace("ё", "е")
	while "  " in result: result = result.replace("  ", " ")
	return result

func load_catalog(base_db: Dictionary) -> Dictionary:
	var db := base_db.duplicate(true)
	# Starting descriptions are separate from inference facts; staff overrides win below.
	var metadata: Dictionary = preload("res://data/library_metadata.json").data
	for book in db.books:
		if metadata.has(str(book.id)):
			for key in metadata[str(book.id)]:
				if str(book.get(key, "")).is_empty(): book[key] = metadata[str(book.id)][key]
	# Library cards override metadata while preserving the oracle's facts and identities.
	if not _library_path.is_empty() and FileAccess.file_exists(_library_path):
		var library = JSON.parse_string(FileAccess.get_file_as_string(_library_path))
		if library is Dictionary and library.get("books") is Dictionary:
			var valid := {}
			for id in library.books:
				var row = library.books[id]
				if row is Dictionary and row.get("id") == id and row.get("title") is String and row.get("author") is String and row.get("tags") is Array and row.get("facts") is Dictionary:
					valid[id] = row
			library.books = valid
			var found := {}
			for book in db.books:
				found[str(book.id)] = true
				if library.books.has(str(book.id)):
					var saved: Dictionary = library.books[str(book.id)]
					var starting = book.duplicate(true)
					book.merge(saved, true)
					# Old editor saved empty fields before starting descriptions existed.
					# New cards mark intentional blanks and retain them on subsequent loads.
					if not saved.has("metadata_version"):
						for key in ["genre","themes","description"]:
							if str(book.get(key,"")).is_empty(): book[key]=starting.get(key,"")
			for id in library.books:
				if not found.has(id): db.books.append(library.books[id].duplicate(true))
	_known_ids.clear()
	if not db.has("questions"): db.questions = {}
	for key in _state.questions: db.questions[key] = _state.questions[key]
	_question_keys = db.get("questions", {}).duplicate()
	for kind in ["books", "heroes"]:
		if not db.has(kind): db[kind] = []
		for item in db[kind]: _known_ids[str(item.id)] = true
	for kind in ["books", "heroes"]:
		for item in _state[kind]:
			if _known_ids.has(item.id): continue
			# A deleted/missing source book must not produce a dangling character.
			if kind == "heroes" and not _known_ids.has(item.book): continue
			db[kind].append(item.duplicate(true))
			_known_ids[item.id] = true
	for kind in ["books", "heroes"]:
		for item in db[kind]:
			if not _state.observations.has(item.id): continue
			var learned: Dictionary = {}
			for key in _state.observations[item.id].answers:
				if _question_keys.has(key) and not str(key).begins_with("@"):
					learned[key] = _state.observations[item.id].answers[key]
			if not learned.is_empty():
				item["learned_answers"] = learned
				item["learning_source"] = "user_confirmed"
	return db

func record_confirmation(item_id: String, question_keys: Array, answers: Array) -> bool:
	if not _can_write(): return false
	if not _known_ids.has(item_id): return _fail("Сначала выберите книгу или персонажа из каталога.")
	if question_keys.size() != answers.size(): return _fail("Не удалось сопоставить вопросы и ответы.")
	var next := _state.duplicate(true)
	var observation: Dictionary = next.observations.get(item_id, {"answers": {}, "confirmations": 0})
	if not observation.has("answer_counts"): observation["answer_counts"] = {}
	var seen := {}
	for i in question_keys.size():
		var key := str(question_keys[i])
		# Metadata is derived from the catalogue; uncertain answers do not become facts.
		if key.begins_with("@") or not _question_keys.has(key): continue
		if seen.has(key): return _fail("Один вопрос нельзя учитывать дважды в подтверждённом раунде.")
		seen[key] = true
		if not answers[i] is float and not answers[i] is int: continue
		var answer := float(answers[i])
		if answer != 1.0 and answer != -1.0: continue
		var tally: Dictionary = observation.answer_counts.get(key, {"yes": 0, "no": 0})
		# Older v1 saves contain only the last confirmed value. Preserve it as
		# one observation; the item-level confirmation total cannot date each fact.
		if not observation.answer_counts.has(key) and observation.answers.has(key):
			tally["yes" if observation.answers[key] else "no"] = 1
		var side := "yes" if answer > 0.0 else "no"
		if int(tally[side]) >= MAX_ANSWER_COUNT: return _fail("Счётчик подтверждений достиг допустимого предела.")
		tally[side] = int(tally[side]) + 1
		observation.answer_counts[key] = tally
		# Keep the previous value at a tie; one contrary answer cannot replace
		# an established majority. Uncertain answers never enter these counts.
		if int(tally.yes) > int(tally.no): observation.answers[key] = true
		elif int(tally.no) > int(tally.yes): observation.answers[key] = false
	observation["confirmations"] = int(observation.get("confirmations", 0)) + 1
	observation["source"] = "user_confirmed"
	next.observations[item_id] = observation
	return _commit(next)

func trait_key(prompt: String) -> String:
	var normalized := _normal(prompt).trim_suffix("?").strip_edges()
	while "  " in normalized: normalized = normalized.replace("  ", " ")
	return "user_trait_" + normalized.sha256_text().left(24)

func validate_trait(prompt: String) -> bool:
	if not _valid_text(prompt, 100): return _fail("Напишите вопрос о герое: до 100 знаков, без переводов строки.")
	if _normal(prompt).trim_suffix("?").strip_edges().length() < 5:
		return _fail("Добавьте понятный вопрос о поступке, характере или способности героя.")
	return true

func record_trait(item_id: String, prompt: String, value: bool) -> bool:
	if not _can_write(): return false
	if not _known_ids.has(item_id): return _fail("Сначала выберите книгу или персонажа из каталога.")
	if not validate_trait(prompt): return false
	var key := trait_key(prompt)
	var next := _state.duplicate(true)
	next.questions[key] = prompt.strip_edges()
	var observation: Dictionary = next.observations.get(item_id, {"answers": {}, "confirmations": 0})
	observation.answers[key] = value
	if not observation.has("answer_counts"): observation["answer_counts"] = {}
	# An explicitly authored trait starts its own observed answer, independent
	# of confirmations of other questions in this character's history.
	observation.answer_counts[key] = {"yes": 1 if value else 0, "no": 0 if value else 1}
	observation["source"] = "user_confirmed"
	next.observations[item_id] = observation
	if not _commit(next): return false
	_question_keys[key] = prompt.strip_edges()
	return true

func add_hero(hero_name: String, book_id: String, base_db: Dictionary) -> String:
	if not _can_write(): return ""
	if not _valid_text(hero_name, 160):
		_fail("Введите имя персонажа (до 160 знаков, без переводов строки).")
		return ""
	var db := load_catalog(base_db)
	var source_book: Dictionary = {}
	for book in db.books:
		if book.id == book_id: source_book = book
	if source_book.is_empty():
		_fail("Выберите книгу, в которой встречается персонаж.")
		return ""
	for hero in db.heroes:
		var book_ids: Array = hero.get("book_ids", [hero.get("book", "")])
		var works: Array = hero.get("books", [])
		if not (book_id == hero.get("book", "") or book_id in book_ids or book_id in works): continue
		var names: Array = hero.get("aliases", []).duplicate()
		names.append(str(hero.name))
		for known_name in names:
			if _normal(str(known_name)) == _normal(hero_name): return str(hero.id)
	var id := "user_hero_" + (_normal(hero_name) + "|" + book_id).sha256_text().left(24)
	var next := _state.duplicate(true)
	next.heroes.append({"id": id, "name": hero_name.strip_edges(), "book": book_id,
		"book_ids": [book_id], "books": [book_id], "tags": [], "facts": {}, "source": "user_confirmed"})
	if not _commit(next): return ""
	_known_ids[id] = true
	return id

func add_book(title: String, author: String, base_db: Dictionary) -> String:
	if not _can_write(): return ""
	if not _valid_text(title, 240) or not _valid_text(author, 160):
		_fail("Введите название книги и автора без переводов строки.")
		return ""
	var db := load_catalog(base_db)
	for book in db.books:
		if _normal(str(book.title)) == _normal(title) and _normal(str(book.author)) == _normal(author): return str(book.id)
	var id := "user_book_" + (_normal(title) + "|" + _normal(author)).sha256_text().left(24)
	var next := _state.duplicate(true)
	next.books.append({"id": id, "title": title.strip_edges(), "author": author.strip_edges(),
		"location": "", "tags": [], "facts": {}, "source": "user_confirmed"})
	if not _commit(next): return ""
	_known_ids[id] = true
	return id

func forget(item_id: String) -> bool:
	if not _can_write(): return false
	var next := _state.duplicate(true)
	next.observations.erase(item_id)
	return _commit(next)

func _can_write() -> bool:
	if not _writable: return false
	last_error = ""
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false

func _commit(next: Dictionary) -> bool:
	var absolute_path := ProjectSettings.globalize_path(_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK: return _fail("Не удалось открыть папку обучения.")
	var temporary_path := absolute_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null: return _fail("Не удалось записать обучение.")
	file.store_string(JSON.stringify(next, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary_path)
		return _fail("Не удалось сохранить обучение полностью.")
	# Rename only after a complete write; original file survives a write failure.
	if DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return _fail("Не удалось заменить файл обучения.")
	_state = next
	return true
