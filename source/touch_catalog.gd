extends Node
## Own the complete gesture: a card activates only after a stationary release.
var scroll: ScrollContainer
var pointer := -2
var origin := Vector2.ZERO
var last := Vector2.ZERO
var moved := false
var candidate: BaseButton
var velocity := 0.0
var offset := 0.0
var last_time := 0
var enabled: Callable

func _ready() -> void:
	scroll = get_parent()
	get_window().focus_exited.connect(cancel)

func cancel() -> void:
	if is_instance_valid(candidate): candidate.set_pressed_no_signal(false)
	candidate = null
	pointer = -2
	velocity = 0.0

func _input(event: InputEvent) -> void:
	if enabled.is_valid() and not enabled.call(): return
	var viewport := get_viewport()
	var id := -1
	var point: Vector2
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		id = event.index; point = event.position; press = event.pressed; release = not press
	elif event is InputEventScreenDrag:
		id = event.index; point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position; press = event.pressed; release = not press
	elif event is InputEventMouseMotion:
		point = event.position
	else: return
	if pointer != -2 and id != pointer: return
	if press:
		if not scroll.get_global_rect().has_point(point): return
		if scroll.get_v_scroll_bar().get_global_rect().has_point(point): return
		if needs_native_input(scroll, point): return
		cancel()
		pointer = id; origin = point; last = point; moved = false
		offset = scroll.scroll_vertical; last_time = Time.get_ticks_msec()
		candidate = button_at(scroll, point)
		if is_instance_valid(candidate): candidate.set_pressed_no_signal(true)
	elif pointer == -2: return
	elif release:
		var button := candidate
		var activate := not moved and is_instance_valid(button) and button.get_global_rect().has_point(point)
		if is_instance_valid(button): button.set_pressed_no_signal(false)
		candidate = null; pointer = -2
		if event is InputEventScreenTouch and event.canceled: activate = false; velocity = 0.0
		if Time.get_ticks_msec() - last_time > 100: velocity = 0.0
		if activate and not button.disabled: button.pressed.emit()
	else:
		if not moved and point.distance_to(origin) > 14.0:
			moved = true
			if is_instance_valid(candidate): candidate.set_pressed_no_signal(false)
		if moved:
			var now := Time.get_ticks_msec()
			var dy := last.y - point.y
			offset += dy
			scroll.scroll_vertical = roundi(offset)
			offset = scroll.scroll_vertical
			velocity = lerpf(velocity, dy / maxf(0.008, (now-last_time)/1000.0), 0.65)
			last_time = now
		last = point
	viewport.set_input_as_handled()

func button_at(node: Node, point: Vector2) -> BaseButton:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			var found := button_at(child, point)
			if found != null: return found
	if node is BaseButton and node.get_global_rect().has_point(point): return node
	return null

func needs_native_input(node: Node, point: Vector2) -> bool:
	if node is Control and not node.is_visible_in_tree(): return false
	if (node is LineEdit or node is OptionButton or (node is BaseButton and node.toggle_mode)) and node.get_global_rect().has_point(point): return true
	for child in node.get_children():
		if needs_native_input(child, point): return true
	return false

func _process(delta: float) -> void:
	if enabled.is_valid() and not enabled.call():
		cancel()
		return
	if pointer != -2 or absf(velocity) < 8.0: return
	var before := scroll.scroll_vertical
	offset += velocity * delta
	scroll.scroll_vertical = roundi(offset)
	if before == scroll.scroll_vertical: velocity = 0.0
	else: velocity *= exp(-6.5 * delta)
