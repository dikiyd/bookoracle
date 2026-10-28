extends RefCounted
## Curated local puzzles; no network or generated facts at runtime.
var kind: String
var path: String
var items: Array = []
var error := ""
var writable := true
func _init(game: String, override_path := ""):
 kind = game
 path = override_path if not override_path.is_empty() else "user://"+kind+"_puzzles.json"
 items = defaults(kind)
 if FileAccess.file_exists(path):
  var parser=JSON.new()
  parser.parse(FileAccess.get_file_as_string(path))
  var data = parser.data
  if not data is Array or data.is_empty(): error = "Файл заданий повреждён. Исходный файл сохранён."
  else:
   for item in data:
    error = validate(kind,item)
    if not error.is_empty(): break
   if error.is_empty(): items = data
  writable = error.is_empty()
static func book(title: String, author: String) -> Dictionary:
 return {"title":title,"author":author,"id":"","location":""}
static func group(caption: String, cards: Array, title: String, author: String, reason: String) -> Dictionary:
 return {"name":caption,"cards":cards,"book":book(title,author),"reason":reason}
static func defaults(game: String) -> Array:
 if game=="constellations":
  return [
   {"title":"Знакомые незнакомцы","groups":[
    group("Бейкер-стрит",["Холмс","Ватсон","Мориарти"],"Приключения Шерлока Холмса","Артур Конан Дойл","Три героя историй о знаменитом сыщике."),
    group("Страна чудес",["Алиса","Шляпник","Чеширский Кот"],"Алиса в Стране чудес","Льюис Кэрролл","Все трое встречаются в удивительном мире Алисы."),
    group("Путь к Одинокой горе",["Бильбо","Гэндальф","Торин"],"Хоббит, или Туда и обратно","Джон Р. Р. Толкин","Участники путешествия к Одинокой горе.") ]},
   {"title":"Вещи рассказывают","groups":[
    group("Золушка",["Туфелька","Тыква-карета","Полночь"],"Золушка","Шарль Перро","Эти детали помогают узнать сказку о Золушке."),
    group("Маленький принц",["Роза","Астероид","Барашек в ящике"],"Маленький принц","Антуан де Сент-Экзюпери","Планета, любимый цветок и необычный рисунок."),
    group("Буратино",["Золотой ключик","Холст с очагом","Театр Карабаса"],"Золотой ключик, или Приключения Буратино","Алексей Толстой","Следы приключений деревянного мальчика.") ]},
   {"title":"По следам сказок","groups":[
    group("Волшебник Изумрудного города",["Элли","Страшила","Железный Дровосек"],"Волшебник Изумрудного города","Александр Волков","Друзья идут по дороге из жёлтого кирпича."),
    group("Маугли",["Багира","Балу","Шер-Хан"],"Маугли","Редьярд Киплинг","Обитатели джунглей, где вырос Маугли."),
    group("Винни-Пух",["Пятачок","Ослик Иа","Кролик"],"Винни-Пух и все-все-все","Алан Милн","Соседи медвежонка, который любит мёд.") ]}
  ]
 return [
  {"title":"След на подоконнике","people":["Лиса","Сова","Заяц"],"places":["Читальный зал","Мастерская","Зимний сад"],"clues":[{"person":0,"place":1,"yes":true},{"person":1,"place":2,"yes":false},{"person":2,"place":0,"yes":false}],"target":2,"book":book("Алиса в Стране чудес","Льюис Кэрролл")},
  {"title":"Закладка с пером","people":["Сова","Барсук","Лиса"],"places":["Архив","Зал сказок","Оранжерея"],"clues":[{"person":0,"place":0,"yes":false},{"person":1,"place":2,"yes":true},{"person":2,"place":1,"yes":false}],"target":0,"book":book("Приключения Шерлока Холмса","Артур Конан Дойл")},
  {"title":"Письмо из атласа","people":["Заяц","Лиса","Барсук"],"places":["Зал карт","Мастерская","Архив"],"clues":[{"person":0,"place":2,"yes":true},{"person":1,"place":1,"yes":false},{"person":2,"place":0,"yes":false}],"target":1,"book":book("Вокруг света за восемьдесят дней","Жюль Верн")}
 ]
static func solutions(item: Dictionary) -> Array:
 var out: Array=[]
 for a in 3:
  for b in 3:
   for c in 3:
    if a==b or b==c or a==c: continue
    var candidate=[a,b,c]
    var valid=true
    for clue in item.clues:
     if (candidate[int(clue.person)]==int(clue.place)) != clue.yes: valid=false; break
    if valid: out.append(candidate)
 return out
static func valid_book(value: Variant) -> bool:
 return value is Dictionary and value.get("title") is String and not value.title.strip_edges().is_empty() and value.get("author") is String and not value.author.strip_edges().is_empty()
static func validate(game: String, item: Variant) -> String:
 if not item is Dictionary or not item.get("title") is String or item.title.strip_edges().is_empty() or item.title.length()>60: return "Название задания: от 1 до 60 знаков."
 if game=="constellations":
  if not item.get("groups") is Array or item.groups.size()!=3: return "Нужны три группы."
  var seen: Array=[]
  for g in item.groups:
   if not g is Dictionary or not g.get("name") is String or g.name.strip_edges().is_empty() or g.name.length()>60: return "Назовите каждую группу (до 60 знаков)."
   if not g.get("cards") is Array or g.cards.size()!=3: return "В каждой группе должно быть три карточки."
   if not g.get("reason") is String or g.reason.length()>180: return "Объяснение: до 180 знаков."
   if not valid_book(g.get("book")): return "Выберите книгу для каждой группы."
   for card in g.cards:
    if not card is String or card.strip_edges().is_empty() or card.length()>32: return "Карточка: от 1 до 32 знаков."
    var key=card.strip_edges().to_lower().replace("ё","е")
    if key in seen: return "Карточки не должны повторяться."
    seen.append(key)
 else:
  for key in ["people","places"]:
   if not item.get(key) is Array or item[key].size()!=3: return "Нужны три персонажа и три места."
   var seen: Array=[]
   for value in item[key]:
    if not value is String or value.strip_edges().is_empty() or value.length()>24: return "Имена и места: от 1 до 24 знаков."
    if value.to_lower() in seen: return "Имена и места не должны повторяться."
    seen.append(value.to_lower())
  if not item.get("clues") is Array or item.clues.size()<2 or item.clues.size()>5: return "Нужно от двух до пяти улик."
  for clue in item.clues:
   if not clue is Dictionary or not clue.get("person") is float and not clue.get("person") is int: return "Укажите персонажа в улике."
   if not clue.get("place") is float and not clue.get("place") is int: return "Укажите место в улике."
   if int(clue.person)<0 or int(clue.person)>2 or int(clue.place)<0 or int(clue.place)>2 or not clue.get("yes") is bool: return "Неверная улика."
  if not item.get("target") is float and not item.get("target") is int: return "Укажите место находки."
  if int(item.target)<0 or int(item.target)>2 or not valid_book(item.get("book")): return "Выберите место находки и книгу."
  var count=solutions(item).size()
  if count==0: return "Улики противоречат друг другу. Решений нет."
  if count>1: return "Улик недостаточно: решений %d. Добавьте или уточните улику." % count
 return ""
func save(next: Array) -> bool:
 if not writable: return false
 error=""
 if next.is_empty(): error="Оставьте хотя бы одно задание."; return false
 for item in next:
  error=validate(kind,item)
  if not error.is_empty(): return false
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null: error="Не удалось записать задания."; return false
 file.store_string(JSON.stringify(next,"\t")); file.close()
 if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK: error="Не удалось создать резервную копию."; return false
 if DirAccess.rename_absolute(path+".tmp",path)!=OK: error="Не удалось заменить файл."; return false
 items=next.duplicate(true)
 return true
static func resolve_book(reference: Dictionary) -> Dictionary:
 var books=preload("res://library_store.gd").new().all()
 for b in books:
  if (not str(reference.get("id","")).is_empty() and b.id==reference.id) or (str(b.title).to_lower()==str(reference.title).to_lower() and str(b.author).to_lower()==str(reference.author).to_lower()): return b
 return reference
static func clue_text(item: Dictionary, clue: Dictionary) -> String:
 return "%s — %s«%s»." % [item.people[int(clue.person)],"в месте " if clue.yes else "не в месте ",item.places[int(clue.place)]]
