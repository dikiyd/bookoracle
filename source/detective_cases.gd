extends RefCounted
## Author-owned evidence and pair rules. Separate from the legacy spatial puzzles.
const PATH="user://detective_cases.json"
const TYPES=["Записка","Предмет","Показание","Документ"]
var items: Array=[]
var path: String
var error:=""
var writable:=true
func _init(override_path:=""):
	path=PATH if override_path.is_empty() else override_path
	items=defaults()
	if not FileAccess.file_exists(path): return
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:
		error="Файл дел повреждён. Он сохранён без изменений."; writable=false; return
	var data=parser.data
	error=validate_catalog(data)
	if not error.is_empty(): writable=false; return
	items=data

static func clue(title: String,body: String,type:="Документ") -> Dictionary:
	return {"title":title,"text":body,"type":type}
static func link(a: int,b: int,title: String,reason: String,hint: String) -> Dictionary:
	return {"a":a,"b":b,"title":title,"reason":reason,"hint":hint}
static func book(title: String,author: String) -> Dictionary:
	return {"title":title,"author":author,"id":"","location":"","stock":false}
static func empty_case() -> Dictionary:
	var out={"title":"","brief":"","resolution":"","evidence":[],"links":[],"book":book("Алиса в Стране чудес","Льюис Кэрролл")}
	for i in range(6): out.evidence.append(clue("","",TYPES[i%TYPES.size()]))
	for i in range(3): out.links.append(link(i*2,i*2+1,"","",""))
	return out
static func defaults() -> Array:
	return [
	{"title":"Тайна последней страницы","brief":"Перед чтением исчез последний лист. Осмотрите улики и выясните: что случилось, где оригинал и как прошло чтение?",
	"resolution":"Чай промочил последнюю страницу. Реставратор принял её на просушку, а чтец получил копию. Страницу не украли: её спасали. Историю удалось прочитать до конца.",
	"evidence":[
	clue("Чашка у книги","На блюдце засохли капли чая. Чашка стояла рядом с раскрытой книгой. На её дне — неровное кольцо.","Предмет"),
	clue("Промокший лист","От листа пахнет чаем. На пятне видно такое же неровное кольцо, как на дне чашки. Края целы: лист не вырывали.","Предмет"),
	clue("Записка реставратора","Я принял последний лист на просушку. Вложил в журнал зелёный талон приёма. Верну оригинал после высыхания.","Записка"),
	clue("Зелёный талон","Принято: один влажный лист, последний в книге. Работа: просушка. Место хранения: мастерская реставратора.","Документ"),
	clue("Пометка на афише","История должна прозвучать целиком. Для чтения подготовлен отдельный лист: финал, копия для чтеца.","Документ"),
	clue("Слова чтеца","Я дочитал историю с отдельного листа. Внизу было написано «Копия». Этот лист мне передал организатор чтения.","Показание")],
	"links":[
	link(0,1,"Причина — пролитый чай","След на листе совпадает с дном чашки, а запах подтверждает, что это чай.","Сравните предмет на столе и след на повреждённом листе."),
	link(2,3,"Оригинал на просушке","Записка и талон относятся к последнему влажному листу и указывают одну мастерскую.","Сопоставьте обещание реставратора с документом о приёме."),
	link(4,5,"Чтец использовал копию","Пометка описывает подготовленный лист, а чтец подтверждает, что именно его получил.","Сравните план чтения и то, что помнит чтец.")],
	"book":book("Алиса в Стране чудес","Льюис Кэрролл")},
	{"title":"Обложка с чужим именем","brief":"На выставку принесли книгу в обложке «Сказки». Но карточка каталога говорит о путешествии. Какая книга перед вами и откуда взялась ошибка?",
	"resolution":"Это «Вокруг света за восемьдесят дней». На книгу случайно надели многоразовую защитную обложку с прежней подписью. Ярлык заменят, а книгу можно поставить на выставку путешествий.",
	"evidence":[
	clue("Титульный лист","Внутри напечатано: «Вокруг света за восемьдесят дней. Жюль Верн». В нижнем углу — номер 148.","Документ"),
	clue("Карточка № 148","Номер 148: «Вокруг света за восемьдесят дней», Жюль Верн. На выставку передан один экземпляр.","Документ"),
	clue("Защитная обложка","Бумажная обложка свободно снимается. На сгибе осталось старое название «Сказки»; под ним заметен след другого ярлыка.","Предмет"),
	clue("Слова оформителя","Для выставки я взял защитные обложки из коробки повторного использования. Старые подписи ещё не успел заменить.","Показание"),
	clue("Список выставки","Раздел «Путешествия»: нужен экземпляр № 148. В разделе «Сказки» этот номер не указан.","Документ"),
	clue("Записка библиотекаря","На выставку берём книгу по номеру, а не по съёмной обложке. Номер внутри книги должен совпадать со списком раздела.","Записка")],
	"links":[
	link(0,1,"Книга — о кругосветном пути","Название, автор и номер на титуле совпадают с каталогом.","Сверьте внутреннюю страницу книги с карточкой по номеру."),
	link(2,3,"Ошибка на съёмной обложке","Старая подпись осталась на повторно использованной обложке.","Что в оформлении книги можно снять и использовать ещё раз?"),
	link(4,5,"Место — выставка путешествий","Правило отбора и номер в списке указывают нужный раздел.","Проверьте правило отбора и запись в списке выставки.")],
	"book":book("Вокруг света за восемьдесят дней","Жюль Верн")},
	{"title":"Письмо без подписи","brief":"В книге нашли письмо с рисунком звезды. Имени нет. Установите, кому оно предназначено, зачем вложено в книгу и нужно ли его возвращать отправителю.",
	"resolution":"Письмо адресовано участникам клуба «Звезда». Это приглашение к обсуждению, вложенное организатором по согласованию с библиотекой. Оно остаётся в клубном экземпляре, пока встреча не пройдёт.",
	"evidence":[
	clue("Начало письма","«Тем, кто собирается по четвергам под знаком звезды. Приходите обсудить историю после чтения». Имени человека нет.","Записка"),
	clue("Расписание клубов","Клуб «Звезда»: четверг, 17:00, обсуждение прочитанных книг. Другие клубы встречаются в другие дни.","Документ"),
	clue("Штамп на конверте","На конверте стоит штамп «Приглашение к обсуждению». Такой же знак есть на афише клуба.","Предмет"),
	clue("Слова организатора","Я приготовил приглашение для следующей встречи и вложил его в клубный экземпляр. Библиотекарь об этом знает.","Показание"),
	clue("Закладка библиотекаря","Клубный экземпляр. Согласованное приглашение оставить внутри до встречи. После встречи передать организатору.","Записка"),
	clue("Дата на афише","Встреча ещё впереди. Участникам предложено взять клубный экземпляр и прочитать вложенное приглашение.","Документ")],
	"links":[
	link(0,1,"Адресат — книжный клуб","День встречи и знак совпадают с расписанием клуба «Звезда».","Сопоставьте обращение в письме с расписанием."),
	link(2,3,"Это приглашение на обсуждение","Назначение конверта подтверждено организатором встречи.","Сравните пометку на конверте с объяснением организатора."),
	link(4,5,"Письмо пока остаётся в книге","Правило действует до встречи, а афиша показывает, что она ещё впереди.","Когда заканчивается срок, указанный библиотекарем?")],
	"book":book("Маленький принц","Антуан де Сент-Экзюпери")}
	]

static func valid_text(value: Variant,limit: int,allow_empty:=false) -> bool:
	return value is String and (allow_empty or not value.strip_edges().is_empty()) and value.length()<=limit
static func validate(item: Variant) -> String:
	if not item is Dictionary: return "Неверный формат дела."
	for spec in [["title",60,"Название дела"],["brief",240,"Завязка"],["resolution",600,"Развязка"]]:
		if not valid_text(item.get(spec[0]),spec[1]): return "%s: от 1 до %d знаков." % [spec[2],spec[1]]
	if not item.get("evidence") is Array or item.evidence.size()<4 or item.evidence.size()>8: return "В деле нужно от 4 до 8 улик."
	var titles: Array=[]
	for evidence in item.evidence:
		if not evidence is Dictionary or not valid_text(evidence.get("title"),48) or not valid_text(evidence.get("text"),450): return "У каждой улики нужны название (до 48) и текст (до 450 знаков)."
		if not evidence.get("type") in TYPES: return "Выберите тип каждой улики."
		var key=evidence.title.strip_edges().to_lower().replace("ё","е")
		if key in titles: return "Названия улик не должны повторяться."
		titles.append(key)
	if not item.get("links") is Array or item.links.size()!=3: return "Нужны три связи с выводами."
	var pairs: Array=[]
	for rule in item.links:
		if not rule is Dictionary: return "Неверный формат связи."
		for field in ["a","b"]:
			var value=rule.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)) or value<0 or value>=item.evidence.size(): return "В каждой связи выберите две существующие улики."
		if rule.a==rule.b: return "Улика не может быть связана сама с собой."
		var pair=pair_key(int(rule.a),int(rule.b))
		if pair in pairs: return "Одна пара улик не должна давать два разных вывода."
		pairs.append(pair)
		for spec in [["title",70],["reason",240],["hint",180]]:
			if not valid_text(rule.get(spec[0]),spec[1]): return "У каждой связи нужны вывод, объяснение и подсказка."
	if not preload("res://puzzle_data.gd").valid_book(item.get("book")): return "Выберите книгу в финале."
	return ""
static func validate_catalog(data: Variant) -> String:
	if not data is Array or data.is_empty(): return "В каталоге должно остаться хотя бы одно дело."
	var names: Array=[]
	for item in data:
		var problem=validate(item)
		if not problem.is_empty(): return problem
		var key=item.title.strip_edges().to_lower().replace("ё","е")
		if key in names: return "Названия дел не должны повторяться."
		names.append(key)
	return ""
static func pair_key(a: int,b: int) -> String:
	return "%d:%d" % [mini(a,b),maxi(a,b)]
static func find_link(item: Dictionary,a: int,b: int) -> int:
	for i in item.links.size():
		if pair_key(a,b)==pair_key(int(item.links[i].a),int(item.links[i].b)): return i
	return -1
func save(next: Array) -> bool:
	if not writable: return false
	error=validate_catalog(next)
	if not error.is_empty(): return false
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: error="Не удалось записать дела."; return false
	file.store_string(JSON.stringify(next,"\t")); file.close()
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK: error="Не удалось создать резервную копию."; return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: error="Не удалось заменить файл дел."; return false
	items=next.duplicate(true)
	return true
