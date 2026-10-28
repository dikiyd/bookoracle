extends Control
## Searchable, bounded selector: typing never rebuilds the surrounding editor.
signal item_selected(index: int)
var items: Array[String] = []
var selected := -1:
 set(value):
  selected = value
  if is_instance_valid(edit): edit.text = items[value] if value >= 0 and value < items.size() else ""
var edit: LineEdit
var results: VBoxContainer
var page := 0
func _ready():
 edit = LineEdit.new()
 edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 edit.placeholder_text = "Введите название для поиска…"
 edit.add_theme_font_size_override("font_size", 28)
 edit.add_theme_color_override("font_color", Color("294c49"))
 edit.add_theme_stylebox_override("normal", preload("res://ui_theme.gd").box(Color("fffdf7"), 12))
 add_child(edit)
 edit.text = items[selected] if selected >= 0 and selected < items.size() else ""
 results = VBoxContainer.new()
 results.position = Vector2(0, 82)
 results.size.x = size.x
 results.z_index = 100
 add_child(results)
 edit.text_changed.connect(func(_text): page = 0; refresh())
 edit.focus_entered.connect(func(): page = 0; refresh())
func add_item(value: String): items.append(value)
func refresh():
 for child in results.get_children():
  results.remove_child(child)
  child.queue_free()
 var matches: Array[int] = []
 for i in items.size():
  if edit.text.strip_edges().is_empty() or edit.text.strip_edges().to_lower() in items[i].to_lower(): matches.append(i)
 for offset in range(page * 5, mini(page * 5 + 5, matches.size())):
  var index: int = matches[offset]
  var b = Button.new()
  b.text = items[index]
  b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  b.custom_minimum_size = Vector2(size.x, 72)
  preload("res://ui_theme.gd").style_button(b, "secondary", 26, 12)
  results.add_child(b)
  b.pressed.connect(func(): selected = index; results.hide(); item_selected.emit(index))
 if matches.size() > 5:
  var b = Button.new()
  b.text = "Ещё результаты →" if (page+1)*5 < matches.size() else "← В начало"
  b.custom_minimum_size = Vector2(size.x, 64)
  preload("res://ui_theme.gd").style_button(b, "primary", 26, 12)
  results.add_child(b)
  b.pressed.connect(func(): page = page + 1 if (page+1)*5 < matches.size() else 0; refresh())
 results.position.y = -float(mini(5,matches.size())*76 + (76 if matches.size()>5 else 0) + 16) if global_position.y > 1000 else 82
 results.show()
