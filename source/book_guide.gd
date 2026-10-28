extends Control
const SHEET=preload("res://assets/book-guide.png")
var mood:="idle"
var elapsed:=0.0
const REGIONS=[Rect2(66,12,396,463),Rect2(563,8,416,467),Rect2(1086,10,418,467),Rect2(79,505,352,475),Rect2(498,505,550,476),Rect2(1095,512,391,469)]
const ANCHORS=[Vector2(264,475),Vector2(763,475),Vector2(1280,477),Vector2(255,980),Vector2(767,981),Vector2(1276,981)]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func set_mood(value: String) -> void:
	mood=value
	elapsed=0
	queue_redraw()
func _process(delta: float) -> void:
	elapsed+=delta
	queue_redraw()
func pose_at(seconds: float) -> int:
	match mood:
		"ask":
			if seconds<2.1: return 1 if int(seconds*4.5)%2==0 else 2
			return 5 if fmod(seconds,4.5)>4.32 else 0
		"think": return 3
		"happy": return 4 if seconds<2.3 else (5 if fmod(seconds,4.5)>4.32 else 0)
		_: return 4 if seconds<1.0 else (5 if fmod(seconds,4.5)>4.32 else 0)

func _draw() -> void:
	var height:=size.y-42.0
	var pose:=pose_at(elapsed)
	# Optical bounds measured separately, excluding hands from adjacent poses.
	var region: Rect2=REGIONS[pose]
	var scale_factor:=height/480.0
	var width:=height*.9
	var foot:=Vector2(size.x/2,size.y-24)
	draw_set_transform(foot+Vector2(0,6),0,Vector2(1,.16))
	draw_circle(Vector2.ZERO,width*.46,Color("b5c6bd"),true,-1.0,true)
	draw_set_transform(foot+Vector2(0,1),0,Vector2(1,.13))
	draw_circle(Vector2.ZERO,width*.46,Color("d0d9ca"),true,-1.0,true)
	draw_set_transform(foot+Vector2(0,-1),0,Vector2(1,.13))
	draw_circle(Vector2.ZERO,width*.30,Color(0.18,0.25,0.23,.18),true,-1.0,true)
	# Every pose uses its own sole anchor and the same scale. Ground stays fixed.
	var sway:=sin(Time.get_ticks_msec()*.001*1.15)*.009
	draw_set_transform_matrix(Transform2D(Vector2(1,0),Vector2(sway,1),foot))
	var local_position: Vector2=(region.position-ANCHORS[pose])*scale_factor
	draw_texture_rect_region(SHEET,Rect2(local_position,region.size*scale_factor),region)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
