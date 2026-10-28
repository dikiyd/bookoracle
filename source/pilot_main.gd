extends Control
var oracle_open := true
func _ready() -> void:
	add_child(preload("res://pilot.gd").new())
func show_menu() -> void:
	pass
