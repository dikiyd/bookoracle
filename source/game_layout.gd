extends Node
## Reflow authored groups into two columns, preserving uniform text/art scaling.
## Original geometry is retained so rotation never resets an active game.
var profile := ""
var geometry: Dictionary = {}
var signature := ""

static func install(surface: Control, kind: String) -> void:
	var layout = load("res://game_layout.gd").new()
	layout.profile = kind
	layout.name = "ResponsiveLayout"
	surface.add_child(layout)

func _process(_delta: float) -> void:
	var surface := get_parent() as Control
	var canvas := surface.get_viewport().get_visible_rect().size
	var next := str(canvas)+":"+str(surface.get_child_count())
	if next == signature: return
	signature = next
	apply(surface, canvas)

func apply(surface: Control, canvas: Vector2) -> void:
	var wide := canvas.x > canvas.y
	surface.size = canvas if wide else Vector2(1080,1920)
	for child in surface.get_children():
		if not child is CanvasItem: continue
		if not (child is Control or child is Node2D): continue
		if child.get_script() == load("res://final_card.gd") or child.get_script() == load("res://detective_board.gd"):
			continue
		var id: int = child.get_instance_id()
		if not geometry.has(id):
			geometry[id] = {"position":child.position,"scale":child.scale,"size":child.size if child is Control else Vector2.ZERO,"pivot":child.pivot_offset if child is Control else Vector2.ZERO}
		var original: Dictionary = geometry[id]
		child.position = original.position
		child.scale = original.scale
		if child is Control:
			child.size = original.size
			child.pivot_offset = original.pivot
			child.set_meta("layout_scale",original.scale)
		if not wide: continue
		if child is Control and original.size == Vector2(1080,1920):
			child.size = canvas
			continue
		var point: Vector2 = original.position
		var factor := 0.84
		var origin := Vector2(980,40)
		var source_y := 0.0
		match profile:
			"modal":
				factor=0.76; source_y=310
				origin=Vector2((canvas.x-1080*factor)/2,80)
			"discovery":
				factor=0.9; source_y=440
				origin=Vector2((canvas.x-1080*factor)/2,100)
			"words":
				if child is Node2D:
					factor=0.84; origin=Vector2(24,-335)
				elif point.y >= 470 and point.y < 1500:
					origin=Vector2(24,60); source_y=470
				elif point.y >= 1500:
					origin.y=500; source_y=1500
			"craft":
				if point.y >= 236 and point.y < 1200:
					factor=0.88; origin=Vector2(20,60); source_y=236
				elif point.y >= 1200:
					origin.y=350; source_y=1200
			"stars":
				if point.y >= 300 and point.y < 1350:
					factor=0.86; origin=Vector2(15,40); source_y=310
				elif point.y >= 1350:
					origin.y=450; source_y=1350
			"detective":
				if point.y >= 400 and point.y < 1150:
					factor=0.9; origin=Vector2(0,100); source_y=405
				elif point.y >= 1150:
					origin.y=400; source_y=1150
			"final":
				if point.y < 830:
					origin=Vector2(20,110)
				else:
					origin=Vector2(980,140); source_y=830
			"summary":
				if point.y < 550:
					origin=Vector2(10,120)
				else:
					factor=0.75; origin=Vector2(1040,60); source_y=550
			"case_result":
				if point.y < 930:
					origin=Vector2(10,60)
				else:
					origin=Vector2(980,100); source_y=930
		child.position = origin + Vector2(point.x,point.y-source_y)*factor
		child.scale = original.scale*factor
		if child is Control:
			child.pivot_offset=Vector2.ZERO
			child.set_meta("layout_scale",child.scale)
