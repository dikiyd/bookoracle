extends RefCounted
## Evidence-based guessing. Missing sourced facts stay unknown, never become false.
const MAX_QUESTIONS := 32
const MIN_CONFIDENCE := 0.90
## H(0.98) + H(0.74): the two answer strengths already used by update_scores.
const KNOWN_RESPONSE_ENTROPY := 0.9681869150344387
const QUESTION_INTENTS := {"src_magic":"wizard", "src_student":"student", "src_animal":"animal", "src_cat":"cat", "src_dog":"dog", "src_pirate":"pirate", "src_noble":"noble", "src_child":"child", "src_captain":"captain", "src_doctor":"doctor", "src_strength":"strong", "lore_personal_follows_rabbit":"lore_rabbit_hole", "lore_personal_shrinks_drink":"lore_changes_size"}
const SPECIES_QUESTIONS := ["src_human", "src_animal", "src_hobbit", "src_elf", "src_dwarf", "src_giant", "src_vampire", "src_werewolf", "src_ghost", "src_demon", "src_deity", "src_robot", "src_toy", "src_dragon", "src_cat", "src_dog", "animal", "cat", "dog", "bear", "panther", "fish"]
const DISJOINT_NATURES := ["src_human", "src_animal", "src_hobbit", "src_elf", "src_dwarf", "src_robot"]
const ANIMAL_NATURES := ["src_animal", "animal", "src_cat", "cat", "src_dog", "dog", "bear", "panther", "fish", "src_dragon"]
const ROLE_QUESTIONS := ["src_royal", "src_noble", "noble", "src_soldier", "warrior", "src_commander", "src_knight", "src_swordsman", "src_archer", "src_investigator", "src_police", "src_spy", "src_criminal", "src_thief", "src_killer", "src_pirate", "pirate", "src_sailor", "src_captain", "captain", "src_servant", "src_guard", "src_doctor", "doctor", "src_teacher", "mentor", "src_student", "student", "src_scientist", "inventor", "src_writer", "poet", "src_artist", "src_merchant", "trader", "src_farmer", "src_craftsman", "craftsman", "src_hunter", "src_explorer", "traveler", "src_rebel", "src_politician", "src_lawyer", "clerk"]
const WORLD_QUESTIONS := ["magic", "journey", "dragon", "treasure", "ring", "school", "mystery", "dream", "animals", "space", "friendship", "forest", "theater", "smallworld", "city", "flying", "childhood", "adventure", "river", "island", "sea", "survival", "pirates", "science", "submarine", "detective", "satire", "love", "rescue", "office", "winter", "history", "war", "society", "circus", "philosophy", "jungle", "factory"]
var candidates: Array = []
var questions: Dictionary = {}
var _rules: Dictionary = {}
var _index: Dictionary = {}
var _signatures: Dictionary = {}
var _learned_by_key: Dictionary = {}
var _kind := "books"

func configure(db: Dictionary, kind: String) -> void:
	_kind = kind
	candidates = db[kind]
	questions.clear()
	_rules.clear()
	_index.clear()
	_signatures.clear()
	_learned_by_key.clear()
	var yes_by_key: Dictionary = {}
	var known_by_key: Dictionary = {}
	for i in candidates.size():
		_index[candidates[i].id] = i
		for key in candidates[i].get("learned_answers", {}):
			if not _learned_by_key.has(key): _learned_by_key[key] = []
			_learned_by_key[key].append([i, candidates[i].learned_answers[key]])
		var item: Dictionary = candidates[i]
		var keys: Array = item.facts.keys() if item.has("facts") else db.questions.keys()
		for key in keys:
			if not db.questions.has(key): continue
			if not item.has("facts") and str(key).begins_with("user_trait_"): continue
			if not known_by_key.has(key): known_by_key[key] = []
			known_by_key[key].append(i)
			var positive: bool = item.facts[key] if item.has("facts") else key in item.tags
			if positive:
				if not yes_by_key.has(key): yes_by_key[key] = []
				yes_by_key[key].append(i)
	for key in db.questions:
		if kind == "heroes" and (key in ["russian", "verse"] or str(key).begins_with("original_") or str(key).begins_with("form_")): continue
		var yes: Array = yes_by_key.get(key, [])
		var known: Array = known_by_key.get(key, [])
		var priority := 1.0
		if kind == "heroes":
			if str(key).begins_with("lore_") or str(key).begins_with("user_trait_"): priority = 2.5
			elif _is_world_question(str(key)): priority = 0.35
			else: priority = 1.3
		_add_rule(str(key), str(db.questions[key]), yes, known, priority)
	if kind == "books": _add_metadata(db, kind)

func _add_rule(key: String, text: String, yes: Array, known: Array, priority: float) -> void:
	# Corrections are applied only after the reader explicitly identifies the answer.
	# Keep the downloaded facts intact; local observations live in their own layer.
	for observation in _learned_by_key.get(key, []):
		var i: int = observation[0]
		if not i in known: known.append(i)
		if observation[1]:
			if not i in yes: yes.append(i)
		else:
			yes.erase(i)
	if _learned_by_key.has(key):
		yes.sort()
		known.sort()
	if known.is_empty() or yes.is_empty(): return
	if known.size() == candidates.size() and (yes.is_empty() or yes.size() == known.size()): return
	var signature := hash([yes, known])
	var all_known := known.size() == candidates.size()
	# Distinct lore facts can legitimately describe the same known characters;
	# retain them for confirmation and learning. Only metadata duplicates collapse.
	if key.begins_with("@") and _signatures.has(signature):
		var previous: Dictionary = _rules[_signatures[signature]]
		if previous.yes == yes and previous.all_known == all_known and (all_known or previous.known == known): return
	_signatures[signature] = key
	questions[key] = text
	var yes_set: Dictionary = {}
	var known_set: Dictionary = {}
	for i in yes: yes_set[i] = true
	if not all_known:
		for i in known: known_set[i] = true
	_rules[key] = {"yes":yes, "known":[] if all_known else known, "yes_set":yes_set, "known_set":known_set,
		"all_known":all_known, "priority":priority, "family":_question_family(key)}

func _normal(text: String) -> String:
	return text.to_lower().replace("ё", "е").strip_edges()

func _words(text: String) -> Array:
	var result: Array = []
	var word := ""
	var normalized := _normal(text)
	for i in normalized.length():
		var letter := normalized[i]
		if letter.to_upper() != letter or letter.is_valid_int():
			word += letter
		elif letter in ["-", "‑", "'", "’"] and not word.is_empty() and i + 1 < normalized.length() and normalized[i + 1].to_upper() != normalized[i + 1]:
			# Compound words and names such as Винни-Пух and Д'Артаньян stay whole.
			word += letter
		elif not word.is_empty():
			result.append(word)
			word = ""
	if not word.is_empty(): result.append(word)
	return result

func _add_metadata(db: Dictionary, kind: String) -> void:
	var heroes := kind == "heroes"
	var books: Dictionary = {}
	for book in db.books: books[book.id] = book
	var all: Array = range(candidates.size())
	var groups: Dictionary = {}
	var texts: Dictionary = {}
	var priorities: Dictionary = {}
	var years_known: Array = []
	var years: Dictionary = {}
	for cutoff in [1700, 1800, 1850, 1900, 1925, 1950, 1975, 2000, 2010]: years[cutoff] = []
	for i in candidates.size():
		var item: Dictionary = candidates[i]
		var book: Dictionary = books.get(item.get("book", ""), {}) if heroes else item
		var linked_books: Array = []
		if heroes:
			var linked_ids: Array = item.get("books", item.get("book_ids", [item.get("book", "")]))
			for book_id in linked_ids:
				if books.has(book_id): linked_books.append(books[book_id])
		else:
			linked_books.append(item)
		var title := _normal(str(item.get("name", "")) if heroes else str(item.title))
		var words := _words(title)
		for linked_book in linked_books:
			var author := _normal(str(linked_book.get("author", "")))
			if not author.is_empty():
				_group(groups, texts, priorities, "@author:" + author, ("Герой есть в книге автора %s?" if heroes else "Автор — %s?") % linked_book.author, i, 0.85)
			if heroes:
				var book_title := str(linked_book.title)
				if book_title.length() <= 40:
					_group(groups, texts, priorities, "@book:" + str(linked_book.id), "Герой встречается в книге «%s»?" % book_title, i, 0.90)
				for word in _words(book_title):
					if word.length() >= 3 and word.length() <= 24:
						_group(groups, texts, priorities, "@bookword:" + word, "Он есть в книге со словом «%s» в названии?" % word, i, 0.75)
		for word in words:
			if word.length() >= 3 and word.length() <= 24:
				_group(groups, texts, priorities, "@word:" + word, ("В имени героя есть «%s»?" if heroes else "В названии есть слово «%s»?") % word, i, 0.72)
		if not words.is_empty():
			var first: String = words[0].left(1)
			var first_text := "Е или Ё" if first == "е" else first.to_upper()
			_group(groups, texts, priorities, "@letter:" + first, ("Имя героя начинается на %s?" if heroes else "Название начинается на %s?") % first_text, i, 0.65)
			var alphabet := "0123456789abcdefghijklmnopqrstuvwxyzабвгдежзийклмнопрстуфхцчшщъыьэюя"
			# Natural contiguous letter ranges provide useful broad splits before single words.
			for bounds in [["а", "к"], ["л", "я"], ["а", "д"], ["е", "к"], ["л", "р"], ["с", "я"]]:
				if alphabet.find(first) >= alphabet.find(bounds[0]) and alphabet.find(first) <= alphabet.find(bounds[1]):
					var key: String = "@letters:" + bounds[0] + bounds[1]
					_group(groups, texts, priorities, key, ("Первая буква имени — от %s до %s?" if heroes else "Первая буква названия — от %s до %s?") % [bounds[0].to_upper(), bounds[1].to_upper()], i, 0.65)
		for count in [1, 2, 3, 5]:
			if words.size() <= count:
				_group(groups, texts, priorities, "@words:%d" % count, ("Имя героя состоит максимум из %d слов?" if heroes else "В названии не больше %d слов?") % count, i, 0.65)
		# Prefix/suffix checks are honest even for unusually long titles, and fit the bubble.
		_group(groups, texts, priorities, "@prefix:" + title.left(28), ("Имя героя начинается с «%s»?" if heroes else "Название начинается с «%s»?") % title.left(28), i, 0.35)
		_group(groups, texts, priorities, "@suffix:" + title.right(28), ("Имя героя заканчивается на «%s»?" if heroes else "Название заканчивается на «%s»?") % title.right(28), i, 0.35)
		var year := int(book.get("year", 0))
		if heroes:
			for linked_book in linked_books:
				var other_year := int(linked_book.get("year", 0))
				if other_year == 0:
					year = 0
					break
				year = mini(year, other_year) if year != 0 else other_year
		if year != 0:
			years_known.append(i)
			for cutoff in years:
				if year < cutoff: years[cutoff].append(i)
	for key in groups:
		if str(texts[key]).length() <= 80:
			_add_rule(key, texts[key], groups[key], all, priorities[key])
	for cutoff in years:
		_add_rule("@year:%d" % cutoff, ("Герой есть в книге, изданной до %d года?" if heroes else "Книга впервые издана до %d года?") % cutoff, years[cutoff], years_known, 0.9)

func _group(groups: Dictionary, texts: Dictionary, priorities: Dictionary, key: String, text: String, index: int, priority: float) -> void:
	if not groups.has(key):
		groups[key] = []
		texts[key] = text
		priorities[key] = priority
	if not index in groups[key]: groups[key].append(index)

func answer_for(item: Dictionary, key: String) -> float:
	if not _rules.has(key) or not _index.has(item.id): return 0.0
	var rule: Dictionary = _rules[key]
	var index: int = _index[item.id]
	if not rule.all_known and not rule.known_set.has(index): return 0.0
	return 1.0 if rule.yes_set.has(index) else -1.0

func ranked(scores: Dictionary, excluded: Array) -> Array:
	var list := candidates.filter(func(c): return not c.id in excluded)
	list.sort_custom(func(a, b):
		if scores.get(a.id, 0.0) == scores.get(b.id, 0.0): return str(a.id) < str(b.id)
		return scores.get(a.id, 0.0) > scores.get(b.id, 0.0))
	return list

func confidence(scores: Dictionary, excluded: Array) -> float:
	var top := _top_score(scores, excluded)
	if top == -INF: return 0.0
	var total := 0.0
	for item in candidates:
		if not item.id in excluded: total += exp(float(scores.get(item.id, 0.0)) - top)
	return 1.0 / total

func _top_score(scores: Dictionary, excluded: Array) -> float:
	var top := -INF
	for item in candidates:
		if not item.id in excluded: top = maxf(top, float(scores.get(item.id, 0.0)))
	return top

func should_guess(scores: Dictionary, answers: Array, excluded: Array, asked: Array = []) -> bool:
	var evidence := 0
	for answer in answers:
		if answer != 0.0: evidence += 1
	if evidence < 3 or confidence(scores, excluded) < MIN_CONFIDENCE: return false
	if _kind == "heroes":
		var list := ranked(scores, excluded)
		if list.is_empty() or evidence_for(list[0], asked, answers).positive < 3: return false
	return true

func evidence_for(item: Dictionary, asked: Array, answers: Array) -> Dictionary:
	var positive := 0
	var mismatches := 0
	for i in mini(asked.size(), answers.size()):
		if str(asked[i]).begins_with("@"): continue
		var truth := answer_for(item, str(asked[i]))
		if answers[i] == 1.0 and truth == 1.0: positive += 1
		if absf(float(answers[i])) == 1.0 and truth != 0.0 and float(answers[i]) * truth < 0.0: mismatches += 1
	return {"positive":positive, "mismatches":mismatches}

func supported_candidates(scores: Dictionary, asked: Array, answers: Array, excluded: Array, limit: int = 3) -> Array:
	var supported: Array = []
	for item in ranked(scores, excluded):
		var evidence := evidence_for(item, asked, answers)
		if evidence.positive >= 2 and evidence.mismatches <= 1: supported.append(item)
	if limit <= 0: return []
	# Do not arbitrarily pick three names out of a large equally plausible group.
	if supported.size() > limit and float(scores.get(supported[0].id, 0.0)) - float(scores.get(supported[limit].id, 0.0)) < 1.0: return []
	var chosen := supported.slice(0, limit)
	if supported.size() > limit:
		var boundary := float(scores.get(supported[limit].id, 0.0))
		while not chosen.is_empty() and is_equal_approx(float(scores.get(chosen[-1].id, 0.0)), boundary): chosen.pop_back()
	return chosen

func choose_question(scores: Dictionary, asked: Array, excluded: Array, answers: Array = []) -> String:
	var top := _top_score(scores, excluded)
	if top == -INF: return ""
	var weights := PackedFloat64Array()
	weights.resize(candidates.size())
	var total := 0.0
	for item in candidates:
		if item.id in excluded: continue
		var weight := exp(float(scores.get(item.id, 0.0)) - top)
		weights[_index[item.id]] = weight
		total += weight
	var already_asked: Dictionary = {}
	var asked_intents: Dictionary = {}
	for key in asked:
		already_asked[key] = true
		asked_intents[QUESTION_INTENTS.get(key, key)] = true
	var unknown_families: Dictionary = {}
	for i in mini(asked.size(), answers.size()):
		if answers[i] == 0.0:
			var family := _question_family(str(asked[i]))
			if not family.is_empty(): unknown_families[family] = int(unknown_families.get(family, 0)) + 1
	var best := ""
	var best_value := 0.0
	var story_best := ""
	var story_value := 0.0
	var prefer_story := _kind == "heroes" and asked.size() >= 2 and _is_world_question(str(asked[-1])) and _is_world_question(str(asked[-2]))
	var resolved_natures: Dictionary = {}
	if _kind == "heroes":
		for nature_key in SPECIES_QUESTIONS:
			if _nature_already_resolved(nature_key, asked, answers): resolved_natures[nature_key] = true
	for key in _rules:
		if already_asked.has(key): continue
		if asked_intents.has(QUESTION_INTENTS.get(key, key)): continue
		if resolved_natures.has(key): continue
		# If a reader cannot date the work, asking eight more dates wastes their turn.
		var family: String = _rules[key].family
		if int(unknown_families.get(family, 0)) >= (2 if family in ["world", "role", "relations"] else 1): continue
		var rule: Dictionary = _rules[key]
		var yes := 0.0
		for index in rule.yes: yes += weights[index]
		var known := total if rule.all_known else 0.0
		if not rule.all_known:
			for index in rule.known: known += weights[index]
		# Unknown entries contribute uncertainty, not invented negative facts. A
		# positive-only sourced trait can still teach us something about its bearers.
		var unknown := maxf(0.0, total - known)
		var information := expected_information_gain(yes, maxf(0.0, known - yes), unknown)
		var value := information * float(rule.priority)
		if prefer_story and _is_story_question(key) and yes / total >= 0.005 and value > story_value + 0.00000001:
			story_best = key
			story_value = value
		if value > best_value + 0.00000001:
			best = key
			best_value = value
	return story_best if not story_best.is_empty() else best

func _is_story_question(key: String) -> bool:
	return not _is_world_question(key) and not key.begins_with("@")

func _is_world_question(key: String) -> bool:
	return key in WORLD_QUESTIONS or key.begins_with("genre_") or key.begins_with("context_auto_")

func _binary_entropy(probability: float) -> float:
	if probability <= 0.0 or probability >= 1.0: return 0.0
	return -(probability * log(probability) + (1.0 - probability) * log(1.0 - probability)) / log(2.0)

func expected_information_gain(yes_mass: float, no_mass: float, unknown_mass: float) -> float:
	var total := yes_mass + no_mass + unknown_mass
	if total <= 0.0: return 0.0
	# A normalized five-answer model consistent with update_scores: strong
	# answers (.98/.02), softer answers (.74/.26), and neutral "don't know".
	# Each pair has mass 1/3; neutral has mass 1/3 for every candidate. Missing
	# facts give .5/.5 in each pair, never a made-up No. Within-group entropy
	# cancels, so this equals a full posterior simulation without per-item loops.
	var strong_yes := (0.98 * yes_mass + 0.02 * no_mass + 0.5 * unknown_mass) / total
	var soft_yes := (0.74 * yes_mass + 0.26 * no_mass + 0.5 * unknown_mass) / total
	var conditional := ((yes_mass + no_mass) * KNOWN_RESPONSE_ENTROPY + 2.0 * unknown_mass) / total
	return maxf(0.0, (_binary_entropy(strong_yes) + _binary_entropy(soft_yes) - conditional) / 3.0)

func _question_family(key: String) -> String:
	if key.begins_with("src_direct_"):
		for prop in ["P106", "P39", "P108"]:
			if key.begins_with("src_direct_" + prop + "_"): return "role"
		for prop in ["P40", "P26", "P22", "P25", "P3373"]:
			if key.begins_with("src_direct_" + prop + "_"): return "relations"
	if _kind == "heroes" and key in SPECIES_QUESTIONS: return "species"
	if _kind == "heroes" and _is_world_question(key): return "world"
	if _kind == "heroes" and key in ROLE_QUESTIONS: return "role"
	if _kind == "heroes" and key in ["src_has_children", "src_has_siblings", "src_married"]: return "relations"
	for prefix in ["@year:", "original_", "form_"]:
		if key.begins_with(prefix): return prefix
	if key.begins_with("@author:"): return "author"
	for prefix in ["@word:", "@letter:", "@letters:", "@words:", "@prefix:", "@suffix:"]:
		if key.begins_with(prefix): return "title"
	return ""

func _nature_already_resolved(key: String, asked: Array, answers: Array) -> bool:
	if _kind != "heroes": return false
	for i in mini(asked.size(), answers.size()):
		# A hesitant answer is not a logical assertion. Do not score implied No's;
		# simply leave redundant questions out of the visitor's limited turns.
		if answers[i] != 1.0: continue
		var known := str(asked[i])
		if known in ["src_cat", "cat", "src_dog", "dog", "bear", "panther", "fish", "src_dragon"] and key in ["src_animal", "animal"]: return true
		if known in ["animal", "src_cat", "cat", "src_dog", "dog", "bear", "panther", "fish", "src_dragon"]: known = "src_animal"
		if known in DISJOINT_NATURES:
			if key in DISJOINT_NATURES and key != known: return true
			if known != "src_animal" and key in ANIMAL_NATURES: return true
	return false

func update_scores(scores: Dictionary, key: String, value: float) -> void:
	if value == 0.0 or not _rules.has(key): return
	var strength := clampf(absf(value), 0.0, 1.0)
	var match_delta := log((0.5 + 0.48 * strength) / 0.5)
	var mismatch_delta := log((0.5 - 0.48 * strength) / 0.5)
	var rule: Dictionary = _rules[key]
	var indices: Array = range(candidates.size()) if rule.all_known else rule.known
	for index in indices:
		var id: String = candidates[index].id
		var agrees: bool = rule.yes_set.has(index) == (value > 0.0)
		scores[id] = float(scores.get(id, 0.0)) + (match_delta if agrees else mismatch_delta)

func rebuild_scores(scores: Dictionary, asked: Array, answers: Array) -> void:
	scores.clear()
	for item in candidates: scores[item.id] = 0.0
	for i in mini(asked.size(), answers.size()): update_scores(scores, asked[i], answers[i])
