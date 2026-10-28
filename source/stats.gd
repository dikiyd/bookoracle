extends RefCounted
## Anonymous event counter for the library's monthly report. No names, no images:
## one CSV line per event — invitation answered, game started, ending shown, game left.
const FILE := "user://portal_stats.csv"
const HEADER := "дата;время;событие;игра;секунды;книга"
const MAX_BYTES := 5_000_000
const GAMES := {"story": "Собери историю", "oracle": "Книжный оракул", "weave": "Нити книги", "alchemy": "Алхимия книг", "constellations": "Книжные созвездия", "detective": "Книжный детектив"}
const GAME_IDS := ["story", "oracle", "weave", "alchemy", "constellations", "detective"]
## Only the installed game counts visitors; editor and test runs stay out of the report
## unless a test turns recording on and points it at its own file.
static var path := FILE
static var force := false

static func log_event(event: String, game := "", seconds := 0, book := "") -> void:
	if not (OS.has_feature("template") or force): return
	_rotate()
	var fresh := not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
	if file == null: return
	if fresh:
		file.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
		file.store_line(HEADER)
	file.seek_end()
	var now := Time.get_datetime_dict_from_system()
	file.store_line("%04d-%02d-%02d;%02d:%02d:%02d;%s;%s;%d;%s" % [now.year, now.month, now.day, now.hour, now.minute, now.second, event, game, seconds, book.replace(";", ",")])
	file.close()

static func _rotate() -> void:
	if FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ).get_length() > MAX_BYTES:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".old"))

## Raw rows for a month, as dictionaries.
static func rows(month: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path): return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var cells := line.strip_edges().trim_prefix("﻿").split(";")
		if cells.size() < 6 or not cells[0].begins_with(month): continue
		out.append({"date": cells[0], "time": cells[1], "event": cells[2], "game": cells[3], "seconds": int(cells[4]), "book": cells[5]})
	return out

## Monthly summary: invitations, starts, endings and average time per game, most shown books.
static func summary(month: String) -> Dictionary:
	var result := {"month": month, "invites": 0, "games": {}, "books": {}}
	for id in GAME_IDS: result.games[id] = {"starts": 0, "finals": 0, "seconds": 0, "ended": 0}
	for row in rows(month):
		var g: Dictionary = result.games.get(row.game, {})
		match row.event:
			"invite": result.invites += 1
			"start": if not g.is_empty(): g.starts += 1
			"final":
				if not g.is_empty(): g.finals += 1
				if not row.book.is_empty(): result.books[row.book] = int(result.books.get(row.book, 0)) + 1
			"recommend":
				if not row.book.is_empty(): result.books[row.book] = int(result.books.get(row.book, 0)) + 1
			"end":
				if not g.is_empty():
					g.ended += 1
					g.seconds += row.seconds
	return result

static func current_month() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d" % [now.year, now.month]

static func previous_month() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d" % [now.year - (1 if now.month == 1 else 0), 12 if now.month == 1 else now.month - 1]

## Writes the summary and the raw events as one CSV that opens in Excel or LibreOffice.
static func export_csv(month: String, target: String) -> bool:
	var s := summary(month)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
	file.store_line("Отчёт ПОРТАЛА за %s" % month)
	file.store_line("Приглашений (подошли к экрану);%d" % s.invites)
	file.store_line("Игра;Начато;Дошли до финала;Доля финалов, %;Средняя длительность, мин")
	for id in GAME_IDS:
		var g: Dictionary = s.games[id]
		file.store_line("%s;%d;%d;%d;%s" % [GAMES[id], g.starts, g.finals, roundi(100.0*g.finals/g.starts) if g.starts > 0 else 0, ("%.1f" % (g.seconds/60.0/g.ended)) if g.ended > 0 else "—"])
	file.store_line("")
	file.store_line("Книга в финале;Показов")
	for book in s.books: file.store_line("%s;%d" % [book, s.books[book]])
	file.store_line("")
	file.store_line(HEADER)
	for row in rows(month):
		file.store_line("%s;%s;%s;%s;%d;%s" % [row.date, row.time, row.event, GAMES.get(row.game, row.game), row.seconds, row.book])
	file.close()
	return true
