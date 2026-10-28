extends RefCounted
## «Читательский билет»: a visitor collects a stamp for each game they finish; three stamps
## earn the surprise. One visitor at a time — the ticket is cleared when the kiosk falls asleep.
## Staff can switch stamps off in the service menu (setting "stamps": "on" / "off").
const Brand = preload("res://branding.gd")
const GOAL := 3
static var stamps: Array = []

static func enabled() -> bool:
	return Brand.value("stamps") != "off"

## Returns true when this finish adds a new stamp to the ticket.
static func award(game_id: String) -> bool:
	if not enabled() or game_id.is_empty() or game_id in stamps or stamps.size() >= GOAL: return false
	stamps.append(game_id)
	return true

static func full() -> bool:
	return stamps.size() >= GOAL

static func reset() -> void:
	stamps.clear()

## Stamp art drawn by the art agent; games without their own stamp share the story one.
static func stamp_path(game_id: String) -> String:
	var path := "res://assets/stamps/stamp-%s.png" % game_id
	return path if ResourceLoader.exists(path) else "res://assets/stamps/stamp-story.png"
