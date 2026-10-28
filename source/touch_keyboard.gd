extends CanvasLayer
## Local kiosk keyboard. Buttons keep the editor's focus and caret.
const UI = preload("res://ui_theme.gd")
signal changed
var target: Control
var panel: Panel
var rows: VBoxContainer
var preview: Label
var latin := false
var upper := false
var symbols := false
var height := 0.0
var manage_occlusion := false
var enabled: Callable
var shifted: Control
var shift_origin := Vector2.ZERO
var resized_scroll: ScrollContainer
var scroll_height := 0.0

func _ready() -> void:
	layer = 100
	get_viewport().size_changed.connect(layout)
	panel = Panel.new(); panel.hide(); add_child(panel)
	panel.add_theme_stylebox_override("panel", UI.box(UI.PAPER, 28, UI.CARD_EDGE, 2, 10))
	rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 10); panel.add_child(rows)
	build()

func bind(edit: Control) -> void:
	if edit.has_meta("touch_keyboard"): return
	edit.set_meta("touch_keyboard", self)
	edit.virtual_keyboard_enabled = false
	edit.focus_entered.connect(func(): open(edit))
	edit.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: open(edit)
		elif event is InputEventScreenTouch and event.pressed: open(edit))
	if edit is LineEdit: edit.text_changed.connect(func(_text): update_preview())
	else: edit.text_changed.connect(update_preview)

func watch(node: Node) -> void:
	if node is LineEdit or node is TextEdit: call_deferred("bind_if_available", node)

func bind_if_available(edit: Control) -> void:
	if is_instance_valid(edit) and edit.is_inside_tree() and edit.get_viewport() == get_viewport(): bind(edit)

func _process(_delta: float) -> void:
	# Reflow reparents fields; tree_exiting also fires during that temporary move.
	if panel.visible and (not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree() or (enabled.is_valid() and not enabled.call())): close()

func _input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close(); get_viewport().set_input_as_handled()

func open(edit: Control) -> void:
	if not edit.editable or (enabled.is_valid() and not enabled.call()): return
	if target == edit and panel.visible: return
	restore_form()
	target = edit; panel.show(); build(); layout(); update_preview(); changed.emit()
	call_deferred("reveal")

func reveal() -> void:
	if not panel.visible or not is_instance_valid(target) or not target.is_inside_tree(): return
	if manage_occlusion: restore_form()
	var node: Node = target.get_parent()
	while node != null:
		if node is ScrollContainer:
			if manage_occlusion:
				resized_scroll = node; scroll_height = node.size.y
				var top: float = node.get_global_rect().position.y
				var scale_y: float = node.get_global_transform().y.length()
				node.size.y = minf(scroll_height, maxf(100, (panel.position.y-top-24)/scale_y))
			node.ensure_control_visible(target)
			scroll_after_layout(node, target)
			return
		node = node.get_parent()
	if manage_occlusion:
		var surface: Control = target
		while surface.get_parent() is Control: surface = surface.get_parent()
		var overlap := target.get_global_rect().end.y - panel.position.y + 30
		if overlap > 0:
			shifted = surface; shift_origin = surface.position
			surface.position.y -= overlap

func scroll_after_layout(scroll: ScrollContainer, edit: Control) -> void:
	# The smaller viewport updates its scroll range during container layout.
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(edit) and target == edit and panel.visible:
		scroll.ensure_control_visible(edit)

func restore_form() -> void:
	if is_instance_valid(shifted): shifted.position = shift_origin
	if is_instance_valid(resized_scroll): resized_scroll.size.y = scroll_height
	shifted = null; resized_scroll = null

func close() -> void:
	restore_form()
	target = null; panel.hide(); height = 0.0; changed.emit()

func layout() -> void:
	if not is_inside_tree() or not is_instance_valid(panel): return
	var canvas := get_viewport().get_visible_rect().size
	var shell = get_tree().current_scene.get_node_or_null("KioskShell") if get_tree().current_scene != null else null
	if shell != null and (shell.service_open or shell.staff_session) and get_viewport() == shell.get_viewport():
		canvas = Vector2(1080,1920)
	height = (430.0 if canvas.x > canvas.y else 540.0) if panel.visible else 0.0
	panel.position = Vector2(0, canvas.y-height); panel.size = Vector2(canvas.x, height)
	rows.position = Vector2(20, 16); rows.size = Vector2(canvas.x-40, height-32)
	if panel.visible: call_deferred("reveal")

func key(row: HBoxContainer, caption: String, action: Callable, weight := 1.0) -> void:
	var button := Button.new(); button.text = caption; button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = weight
	UI.style_button(button, "secondary", 28, 12)
	button.pressed.connect(action); row.add_child(button)

func build() -> void:
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 12); rows.add_child(header)
	preview = Label.new(); preview.custom_minimum_size.y = 52
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.add_theme_font_override("font", UI.body_font()); preview.add_theme_font_size_override("font_size", 28)
	preview.add_theme_color_override("font_color", UI.INK); preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(preview)
	var dismiss := Button.new(); dismiss.text = "⌄"; dismiss.tooltip_text = "Скрыть клавиатуру"
	dismiss.custom_minimum_size = Vector2(90, 52); dismiss.focus_mode = Control.FOCUS_NONE
	UI.style_button(dismiss, "secondary", 32, 12); dismiss.pressed.connect(close); header.add_child(dismiss)
	var lines := ["йцукенгшщзхъ", "фывапролджэ", "ячсмитьбюё"] if not latin else ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
	if symbols: lines = [".,!?;:—-()", "«»\"'[]{}|/", "@#№%+*=\\_&"]
	lines.push_front("1234567890")
	for line in lines:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 7)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL; rows.add_child(row)
		for letter in line:
			var value: String = letter.to_upper() if upper else letter
			key(row, value, func(): insert(value))
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 10)
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL; rows.add_child(actions)
	key(actions, "АБВ" if upper else "абв", func(): upper = not upper; build())
	key(actions, "EN" if not latin else "РУС", func(): latin = not latin; build())
	key(actions, "АБВ" if symbols else "?!#", func(): symbols = not symbols; build())
	key(actions, "Пробел", func(): insert(" "), 2.4)
	if target is TextEdit: key(actions, "↵", func(): insert("\n"))
	key(actions, "⌫", erase, 1.2)
	key(actions, "Готово", close, 1.6)
	update_preview()

func insert(value: String) -> void:
	if not is_instance_valid(target) or not target.editable: close(); return
	if target is TextEdit:
		target.insert_text_at_caret(value); update_preview(); return
	if target.has_selection():
		var at: int = target.get_selection_from_column()
		target.delete_text(at, target.get_selection_to_column())
		target.deselect()
		target.caret_column = at
	target.insert_text_at_caret(value)
	target.text_changed.emit(target.text)
	update_preview()

func erase() -> void:
	if not is_instance_valid(target) or not target.editable: close(); return
	if target is TextEdit:
		target.backspace(); update_preview(); return
	if target.has_selection():
		var at: int = target.get_selection_from_column()
		target.delete_text(at, target.get_selection_to_column())
		target.deselect(); target.caret_column = at
	elif target.caret_column > 0:
		var at: int = target.caret_column
		target.delete_text(at-1, at); target.caret_column = at-1
	target.text_changed.emit(target.text); update_preview()

func update_preview() -> void:
	if is_instance_valid(preview):
		preview.text = (target.text if not target.text.is_empty() else target.placeholder_text) if is_instance_valid(target) else ""
		if target is LineEdit and target.secret: preview.text = "●".repeat(target.text.length())
		preview.text = preview.text.replace("\n", "  ↵  ")
