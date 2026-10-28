extends Control
## A local cover image or the original teal book with text fitted into its frame.
const UI=preload("res://ui_theme.gd")
var title := ""
var author := ""
var image_path := ""
var title_label: Label
var author_label: Label
var title_area := Rect2()
var author_area := Rect2()
var signature := ""

func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(rebuild)
 rebuild()

func update_book(book: Dictionary):
 title=str(book.get("title","")); author=str(book.get("author","")); image_path=str(book.get("cover",""))
 if is_inside_tree(): rebuild()

func panel(rect: Rect2, fill: Color, edge: Color, thickness: int, radius: int):
 var p=Panel.new(); p.position=rect.position; p.size=rect.size
 p.add_theme_stylebox_override("panel",UI.box(fill,radius,edge,thickness))
 p.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(p)

func fitted(value: String, area: Rect2, maximum: int, face: Font, color: Color) -> Label:
 var label=Label.new(); label.text=value
 label.position=area.position; label.size=area.size
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_override("font",face); label.add_theme_color_override("font_color",color)
 var points=maxi(1,maximum)
 var flags=TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
 while points>1:
  var measured=face.get_multiline_string_size(value,HORIZONTAL_ALIGNMENT_CENTER,area.size.x,points,-1,flags)
  # Leave room for Label's interline spacing; never truncate a book's title.
  if measured.y<=area.size.y-4 and measured.x<=area.size.x+1: break
  points-=1
 label.add_theme_font_size_override("font_size",points)
 label.add_theme_constant_override("line_spacing",0)
 # Text initially gives Label a single-line minimum width. Reset after wrap/font setup.
 label.size=area.size
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(label)
 label.size=area.size
 return label

func rebuild():
 if size.x<=0 or size.y<=0: return
 for child in get_children(): remove_child(child); child.queue_free()
 title_label=null; author_label=null
 var texture=preload("res://library_store.gd").cover_texture(image_path)
 if texture!=null:
  var art=TextureRect.new(); art.texture=texture; art.size=size
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(art); return
 var factor=minf(size.x/470.0,size.y/560.0)
 panel(Rect2(Vector2.ZERO,size),UI.TEAL,UI.AMBER,maxi(1,roundi(4*factor)),maxi(2,roundi(18*factor)))
 var inset=Vector2(size.x*.055,size.y*.047)
 panel(Rect2(inset,size-inset*2),Color.TRANSPARENT,Color(UI.AMBER,.7),maxi(1,roundi(2*factor)),maxi(2,roundi(10*factor)))
 author_area=Rect2(size*Vector2(.10,.09),size*Vector2(.80,.19))
 title_area=Rect2(size*Vector2(.09,.31),size*Vector2(.82,.49))
 author_label=fitted(author,author_area,maxi(1,roundi(28*factor)),UI.body_font(true),UI.AMBER)
 title_label=fitted(title if not title.strip_edges().is_empty() else "Новая книга",title_area,maxi(1,roundi(46*factor)),UI.display_font(),UI.ON_TEAL)
 fitted("✦",Rect2(size*Vector2(.10,.83),size*Vector2(.80,.10)),maxi(1,roundi(38*factor)),UI.body_font(),UI.AMBER)
