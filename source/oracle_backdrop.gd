extends "res://ui_theme.gd".Paper
## The oracle's stage: lavender paper, a soft spotlight where the mascot stands, the game's ribbon.
func _ready() -> void:
	super._ready()
	tint = Color("efeaf9")
	rule = Color("e3dcf2")

func _draw() -> void:
	super._draw()
	for k in range(7):
		draw_circle(Vector2(540,560),520-k*60,Color(1,1,1,0.07),true,-1.0,true)
	var ribbon_color: Color = preload("res://ui_theme.gd").RIBBONS[1]
	var shape := PackedVector2Array([Vector2(1018,0),Vector2(1062,0),Vector2(1062,104),Vector2(1040,84),Vector2(1018,104)])
	draw_colored_polygon(shape,ribbon_color)
	draw_polyline(shape+PackedVector2Array([shape[0]]),ribbon_color,1.5,true)
