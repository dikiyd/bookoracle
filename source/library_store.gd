extends RefCounted
const PATH = "user://library_catalog.json"
var error := ""
var records: Dictionary = {}
var writable := true
func _init(path: String = PATH):
 storage_path = path
 if FileAccess.file_exists(path):
  var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
  if not parsed is Dictionary or not parsed.get("books") is Dictionary:
   error = "Файл библиотечного каталога повреждён. Он не будет перезаписан."
  else:
   for id in parsed.books:
    var row = parsed.books[id]
    if not row is Dictionary or row.get("id") != id or not row.get("title") is String or not row.get("author") is String or not row.get("tags") is Array or not row.get("facts") is Dictionary:
     error = "Повреждена карточка книги. Каталог не будет перезаписан."
     break
   if error.is_empty(): records = parsed.books
 writable = error.is_empty()
var storage_path: String
func all() -> Array:
 var db = preload("res://oracle_learning.gd").new("user://oracle_learning.json", storage_path).load_catalog(preload("res://oracle_data.json").data)
 var result: Array = db.books.duplicate(true)
 var ids := {}
 for i in result.size():
  ids[str(result[i].id)] = true
 for id in records:
  if not ids.has(id): result.append(records[id].duplicate(true))
 var locations = JSON.parse_string(FileAccess.get_file_as_string("user://oracle_locations.json")) if FileAccess.file_exists("user://oracle_locations.json") else {}
 for row in result:
  if locations is Dictionary and locations.has(row.id) and not records.has(row.id): row["location"] = locations[row.id]
 return result
func save_rows(rows: Array) -> bool:
 if not writable: return false
 error = ""
 var next := records.duplicate(true)
 for row in rows:
  if str(row.get("title", "")).strip_edges().is_empty() or str(row.get("author", "")).strip_edges().is_empty():
   error = "У каждой книги должны быть название и автор."
   return false
  next[str(row.id)] = row.duplicate(true)
 var f = FileAccess.open(storage_path + ".tmp", FileAccess.WRITE)
 if f == null: error = "Не удалось записать каталог."; return false
 f.store_string(JSON.stringify({"books": next}, "\t")); f.close()
 if FileAccess.file_exists(storage_path):
  if DirAccess.copy_absolute(storage_path, storage_path + ".bak") != OK:
   error = "Не удалось создать резервную копию."; return false
 if DirAccess.rename_absolute(storage_path + ".tmp", storage_path) != OK:
  error = "Не удалось заменить каталог."; return false
 records = next
 return true
static func identity(title: String, author: String) -> String:
 return (title.strip_edges().to_lower().replace("ё", "е") + "|" + author.strip_edges().to_lower().replace("ё", "е"))
static func new_book(title: String, author: String) -> Dictionary:
 return {"id": "library_" + identity(title, author).sha256_text().left(20), "title": title, "author": author, "tags": [], "facts": {}, "location": "", "genre": "", "themes": "", "lists": "", "description": "", "cover": ""}

static func tokens(value: String) -> PackedStringArray:
 var result := PackedStringArray()
 for part in value.replace(";", ",").split(",", false):
  var clean = part.strip_edges()
  if not clean.is_empty() and not clean in result: result.append(clean)
 return result

static func cover_texture(path: String) -> Texture2D:
 if path.is_empty() or not FileAccess.file_exists(path): return null
 var image := Image.new()
 if image.load(path) != OK or image.is_empty(): return null
 return ImageTexture.create_from_image(image)

func import_cover(path: String) -> String:
 error = ""
 if not path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
  error = "Выберите изображение PNG, JPG или WEBP."; return ""
 var file = FileAccess.open(path, FileAccess.READ)
 if file == null: error = "Не удалось открыть обложку."; return ""
 if file.get_length() > 20 * 1024 * 1024: error = "Обложка больше 20 МБ. Выберите изображение поменьше."; return ""
 file.close()
 var picture := Image.new()
 if picture.load(path) != OK or picture.is_empty(): error = "Не удалось прочитать изображение обложки."; return ""
 if maxi(picture.get_width(), picture.get_height()) > 1600:
  var factor = 1600.0 / maxi(picture.get_width(), picture.get_height())
  picture.resize(maxi(1,roundi(picture.get_width()*factor)),maxi(1,roundi(picture.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
 var bytes = picture.save_png_to_buffer()
 var hash = HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes)
 var folder = storage_path.get_base_dir().path_join("book_covers")
 if DirAccess.make_dir_recursive_absolute(folder) != OK: error = "Не удалось создать папку обложек."; return ""
 var destination = folder.path_join(hash.finish().hex_encode()+".png")
 var output = FileAccess.open(destination,FileAccess.WRITE)
 if output == null: error = "Не удалось сохранить обложку."; return ""
 output.store_buffer(bytes); output.close()
 return destination
