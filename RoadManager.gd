extends Control

# Папка с изображениями троп (положи туда свои .png/.jpg/.jpeg/.webp)
@export var roads_folder: String = "res://roads"
# Папка с изображениями гоблинши (положи туда свои .png/.jpg/.jpeg/.webp)
@export var goblins_folder: String = "res://goblins"

# Размер изображения и центр (по твоей спецификации)
@export var image_size: Vector2 = Vector2(786, 786)
@export var image_center: Vector2 = Vector2(816, 393)

# Шанс появления гоблинши (в процентах)
@export var goblin_spawn_chance: int = 12
# Отладочные опции — временно для тестирования
@export var debug_force_spawn: bool = false   # если true — при нажатии вперёд всегда будет старт боя
@export var debug_log: bool = true            # печатать отладочные сообщения
# Узлы интерфейса (они должны быть в сцене с такими именами)
@onready var road_texture_rect: TextureRect = $RoadTexture as TextureRect
@onready var event_label: Node = $LeftPanel/EventLabel
@onready var btn_move_forward: Button = $LeftPanel/btn_move_forward  # ← твоя кнопка
@onready var nothing_events: Node = $NothingEvents

# Ссылки на менеджеры/узлы — исправлено: используем python-style conditional expression
@onready var combat_manager: Node = get_node("CombatManager") if has_node("CombatManager") else null
@onready var living_beings: Node = get_node("LivingBeings") if has_node("LivingBeings") else null

var road_textures: Array[Texture2D] = []
var goblin_textures: Array[Texture2D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_road_textures()
	_load_goblin_textures()
	_setup_texture_rect()
	
	if event_label:
		event_label.text = ""
	_enter_new_room()
	if btn_move_forward:
		if not btn_move_forward.is_connected("pressed", Callable(self, "_on_move_forward")):
			btn_move_forward.pressed.connect(Callable(self, "_on_move_forward"))

func _load_road_textures() -> void:
	var dir = DirAccess.open(roads_folder)
	if dir == null:
		push_error("Не удалось открыть папку с дорогами: %s" % roads_folder)
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower = fname.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				var path = roads_folder + "/" + fname
				var tex = load(path)
				if tex and tex is Texture2D:
					road_textures.append(tex)
					print("Loaded road image:", path)
		fname = dir.get_next()
	dir.list_dir_end()
	if road_textures.is_empty():
		push_warning("В папке %s нет изображений форматов png/jpg/jpeg/webp." % roads_folder)

func _load_goblin_textures() -> void:
	var dir = DirAccess.open(goblins_folder)
	if dir == null:
		# это не фатально — просто не будет спавнов гоблинши
		print("Папка с гоблиншами не найдена:", goblins_folder)
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower = fname.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				var path = goblins_folder + "/" + fname
				var tex = load(path)
				if tex and tex is Texture2D:
					goblin_textures.append(tex)
					print("Loaded goblin image:", path)
		fname = dir.get_next()
	dir.list_dir_end()
	if goblin_textures.is_empty():
		print("В папке %s нет изображений гоблинш." % goblins_folder)

func _setup_texture_rect() -> void:
	# Позиционируем фон и оверлей (гоблинша)
	if road_texture_rect:
		road_texture_rect.size = image_size
		road_texture_rect.position = image_center - image_size * 0.5
		road_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _input(event: InputEvent) -> void:
	# Поддержка клавишного управления (W) — блокируем движение во время боя
	if event.is_action_pressed("move_forward"):
		_on_move_forward()

func _on_move_forward() -> void:
	# Если combat_manager присутствует и сообщает, что мы в бою — блокируем движение
	if combat_manager and combat_manager.has_method("is_in_combat"):
		if combat_manager.is_in_combat():
			if event_label:
				event_label.text += "\nНельзя убежать посреди боя!"
				return
	# fallback: если combat_manager не имеет метода is_in_combat (на всякий случай),
	# попробуем безопасно прочитать свойство (если доступно)
	if combat_manager:
		# попытка безопасного получения свойства через get (если оно есть)
		var ok := true
		var val = null
		# защищённый доступ: get() вернёт ошибку если свойства нет, поэтому use_assert=false not available;
		# проще — обойтися без ошибки, проверяя наличие метода выше. Здесь оставим движение.
		# Если хочется — можно добавить дополнительные проверки.
	# Если нет боя — движемся
	_enter_new_room()

func _enter_new_room() -> void:
	# Сбрасываем лог событий (лог боя сохраняется до перехода — как ты хотел)
	if event_label:
		event_label.text = ""
	# Меняем фон
	if not road_textures.is_empty():
		var idx = rng.randi_range(0, road_textures.size() - 1)
		road_texture_rect.texture = road_textures[idx]
	else:
		road_texture_rect.texture = null
	# Обычные ивенты (как было)
	_try_trigger_event()
	# Возможный спавн гоблинши
	_maybe_spawn_goblin()

func _try_trigger_event() -> void:
	var roll = rng.randi_range(1, 100)
	if roll <= 10:
		if event_label:
			event_label.text += "Ты наткнулся на старого торговца"
		return
	elif roll <= 25:
		if event_label:
			event_label.text += "Мимо пронеслись воришки"
		return
	elif roll <= 45:
		if event_label:
			event_label.text += "На тропе найдена странная метка"
		return
	else:
		# Используем твой NothingEvents — если он есть и предоставляет get_random_phrase()
		var phrase = ""
		if nothing_events and nothing_events.has_method("get_random_phrase"):
			phrase = nothing_events.get_random_phrase()
		else:
			phrase = "Ничего не случилось."
		if event_label:
			event_label.text += phrase

# Spawning logic
func _maybe_spawn_goblin() -> void:
	# Отладочная проверка: есть ли вообще загруженные текстуры гоблинш
	if debug_log:
		print("DEBUG: goblin_textures.size() = ", goblin_textures.size())
	# если нет текстур гоблинш — ничего не делать
	if goblin_textures.is_empty():
		if debug_log:
			print("DEBUG: нет текстур гоблинш, спавн пропущен")
		return

	# Если включён форсированный спавн — запускаем бой напрямую (для теста)
	if debug_force_spawn:
		if debug_log:
			print("DEBUG: debug_force_spawn=true -> форсим старт боя")
		if combat_manager and combat_manager.has_method("start_combat"):
			combat_manager.start_combat("goblin")
		else:
			if event_label:
				event_label.text += "\n(Отладка) На тропе нападает гоблинша!"
		return

	# Нормальный рандомный спавн
	var roll = rng.randi_range(1, 100)
	if debug_log:
		print("DEBUG: spawn roll=", roll, " chance=", goblin_spawn_chance, " combat_manager_exists=", combat_manager != null)
	if roll <= goblin_spawn_chance:
		if debug_log:
			print("DEBUG: roll <= chance -> пробуем стартовать бой")
		if combat_manager and combat_manager.has_method("start_combat"):
			combat_manager.start_combat("goblin")
		else:
			if event_label:
				event_label.text += "\nНа тропе нападает гоблинша!"
	else:
		if debug_log:
			print("DEBUG: roll > chance -> никаких гоблинш")
