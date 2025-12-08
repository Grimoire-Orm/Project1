extends Node

# CombatManager — обновлённая версия с синхронизацией оверлея врага
# (гарантирует точное совпадение GoblinTexture с RoadTexture).
# Вставь этот файл вместо существующего CombatManager.gd.

@export var left_panel_name: String = "LeftPanel"
@export var event_label_rel_path: String = "LeftPanel/EventLabel"
@export var goblin_texture_name: String = "GoblinTexture"
@export var living_beings_name: String = "LivingBeings"

# Папка с картинками гоблинш (можно изменить в инспекторе)
@export var goblins_folder: String = "res://goblins"

var left_panel: Node = null
var event_label: Node = null
var goblin_texture: TextureRect = null

var attack_button: Button = null
var attack_list: ItemList = null

var _attack_button_orig_parent: Node = null
var _attack_button_orig_pos: Vector2 = Vector2.ZERO
var _attack_list_orig_parent: Node = null
var _attack_list_orig_pos: Vector2 = Vector2.ZERO

var living_beings: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Состояние боя
var in_combat: bool = false
var player_hp: int = 20
var npc_hp: int = 0
var npc_name: String = "Враг"

var player_attacks = [
	{"name":"удар с вертушки", "min":1, "max":5},
	{"name":"удар кулаком", "min":2, "max":3}
]
var npc_attacks = [
	{"name":"полоснуть кинжалом", "min":2, "max":4},
	{"name":"укусить", "min":0, "max":5}
]

func _ready() -> void:
	rng.randomize()

	# Получаем корень текущей сцены
	var scene_root = get_tree().get_current_scene()
	if scene_root == null:
		scene_root = get_tree().get_root()

	# Попытка найти основные узлы в корне сцены
	if scene_root:
		if scene_root.has_node(left_panel_name):
			left_panel = scene_root.get_node(left_panel_name)
		if scene_root.has_node(event_label_rel_path):
			event_label = scene_root.get_node(event_label_rel_path)
		elif scene_root.has_node(left_panel_name) and left_panel and left_panel.has_node("EventLabel"):
			event_label = left_panel.get_node("EventLabel")
		if scene_root.has_node(goblin_texture_name):
			goblin_texture = scene_root.get_node(goblin_texture_name) as TextureRect
		if scene_root.has_node(living_beings_name):
			living_beings = scene_root.get_node(living_beings_name)

	# Фоллбек: поиск относительно родителя CombatManager (на случай другой иерархии)
	if not left_panel and get_parent() and get_parent().has_node(left_panel_name):
		left_panel = get_parent().get_node(left_panel_name)
	if not event_label and left_panel and left_panel.has_node("EventLabel"):
		event_label = left_panel.get_node("EventLabel")
	if not goblin_texture and get_parent() and get_parent().has_node(goblin_texture_name):
		goblin_texture = get_parent().get_node(goblin_texture_name) as TextureRect
	if not living_beings and get_parent() and get_parent().has_node(living_beings_name):
		living_beings = get_parent().get_node(living_beings_name)

	# Получаем UI атак (если есть)
	if left_panel:
		if left_panel.has_node("AttackButton"):
			attack_button = left_panel.get_node("AttackButton") as Button
		if left_panel.has_node("AttackList"):
			attack_list = left_panel.get_node("AttackList") as ItemList

	# Подпишемся на сигналы
	if attack_list and not attack_list.is_connected("item_activated", Callable(self, "_on_attack_selected")):
		attack_list.item_activated.connect(Callable(self, "_on_attack_selected"))
	if attack_button and not attack_button.is_connected("pressed", Callable(self, "_on_attack_button_pressed")):
		attack_button.pressed.connect(Callable(self, "_on_attack_button_pressed"))

	# Синхронизируем параметры оверлея с RoadTexture (чтобы не было смещения)
	_sync_overlay_to_road(scene_root)

	# Отладочная строка
	print("CombatManager ready: left_panel=", left_panel != null, " event_label=", event_label != null, " goblin_texture=", goblin_texture != null, " living_beings=", living_beings != null)

	_hide_attack_ui()

# публичный метод для проверки состояния боя
func is_in_combat() -> bool:
	return in_combat

# start_combat: запускает бой по шаблону npc_type из LivingBeings
func start_combat(npc_type: String) -> void:
	if in_combat:
		_append_log("Уже в бою.")
		return

	_clear_event_log()

	var tpl: Dictionary = {}
	if living_beings and living_beings.has_method("get_template") and living_beings.has_template(npc_type):
		tpl = living_beings.get_template(npc_type)
	else:
		_append_log("Внимание: LivingBeings/шаблон не найден, используем дефолтные параметры.")
		tpl = {"name":"Гоблинша", "hp":10}

	npc_name = str(tpl["name"]) if tpl.has("name") else npc_type
	npc_hp = int(tpl["hp"]) if tpl.has("hp") else 10
	if tpl.has("attacks") and tpl["attacks"] is Array:
		npc_attacks = tpl["attacks"]

	player_hp = 20

	# Синхронизируем overlay с RoadTexture прямо перед показом (чтобы убрать любые рассинхроны)
	var scene_root = get_tree().get_current_scene()
	if scene_root == null:
		scene_root = get_tree().get_root()
	_sync_overlay_to_road(scene_root)

	# Установка текстуры для goblin_texture:
	var texture_assigned: bool = false
	if goblin_texture:
		# 1) texture_path из шаблона (если есть)
		if tpl.has("texture_path"):
			var tex = load(tpl["texture_path"])
			if tex and tex is Texture2D:
				goblin_texture.texture = tex
				texture_assigned = true
				print("CombatManager: loaded texture from template:", tpl["texture_path"])
			else:
				print("CombatManager: ошибка загрузки texture_path из шаблона:", tpl["texture_path"])

		# 2) fallback — случайная картинка из папки goblins_folder
		if not texture_assigned:
			var dir = DirAccess.open(goblins_folder)
			if dir:
				dir.list_dir_begin()
				var files := []
				var fname = dir.get_next()
				while fname != "":
					if not dir.current_is_dir():
						var lower = fname.to_lower()
						if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
							files.append(goblins_folder + "/" + fname)
					fname = dir.get_next()
				dir.list_dir_end()
				if files.size() > 0:
					var idx = rng.randi_range(0, files.size() - 1)
					var path = files[idx]
					var tex2 = load(path)
					if tex2 and tex2 is Texture2D:
						goblin_texture.texture = tex2
						texture_assigned = true
						print("CombatManager: loaded random goblin texture:", path)
					else:
						print("CombatManager: не удалось load() файл:", path)
				else:
					print("CombatManager: папка", goblins_folder, "пустая или не содержит изображений.")
			else:
				print("CombatManager: не удалось открыть папку", goblins_folder)

		# теперь делаем overlay видимым
		goblin_texture.visible = true

	in_combat = true
	_reparent_attack_ui_to_overlay(true)
	_populate_attack_list()
	_show_attack_ui()
	_append_log("На тропе нападает %s!" % npc_name)

func _on_attack_selected(index: int) -> void:
	if not in_combat:
		return
	if not attack_list:
		return
	if index < 0 or index >= player_attacks.size():
		return

	var attack = player_attacks[index]
	var dmg = rng.randi_range(attack["min"], attack["max"])
	npc_hp -= dmg
	_append_log("Я попытался сделать %s и нанёс %d урона" % [attack["name"], dmg])

	if npc_hp <= 0:
		_append_log("%s повержена!" % npc_name)
		_end_combat()
		return

	_npc_turn()

func _on_attack_button_pressed() -> void:
	if not attack_list:
		return
	attack_list.visible = not attack_list.visible

func _npc_turn() -> void:
	if not in_combat:
		return
	var idx = rng.randi_range(0, npc_attacks.size() - 1)
	var atk = npc_attacks[idx]
	var dmg = rng.randi_range(atk["min"], atk["max"])
	player_hp -= dmg
	_append_log("%s пытается %s и наносит мне %d урона" % [npc_name, atk["name"], dmg])
	if player_hp <= 0:
		_append_log("Ты пал в бою...")
		get_tree().quit()

func _end_combat() -> void:
	in_combat = false
	if goblin_texture:
		goblin_texture.visible = false
	_reparent_attack_ui_to_overlay(false)
	_hide_attack_ui()
	_append_log("Бой окончен.")

# Лог (добавление и автопрокрутка)
func _append_log(text: String) -> void:
	if not event_label:
		print("[Combat LOG] " + text)
		return
	if event_label.text == "":
		event_label.text = text
	else:
		event_label.text += "\n" + text

	# автопрокрутка — RichTextLabel preferred
	if event_label.has_method("scroll_to_line"):
		var lines = 0
		if event_label.has_method("get_line_count"):
			lines = event_label.get_line_count()
		else:
			lines = event_label.text.split("\n").size()
		var target = max(0, lines - 1)
		event_label.scroll_to_line(target)
	elif event_label.has_method("set_v_scroll"):
		if event_label.has_method("get_v_scroll_max"):
			var mv = event_label.get_v_scroll_max()
			event_label.set_v_scroll(mv)

func _clear_event_log() -> void:
	if not event_label:
		print("[Combat LOG] очистка лога (event_label отсутствует)")
		return
	event_label.text = ""

# --- UI: reparent AttackButton и AttackList на goblin_texture (overlay) ---
func _reparent_attack_ui_to_overlay(to_overlay: bool) -> void:
	if not attack_button and not attack_list:
		return

	var overlay_size: Vector2 = Vector2(786, 786)
	if goblin_texture:
		overlay_size = goblin_texture.size

	if to_overlay:
		if attack_button and _attack_button_orig_parent == null:
			_attack_button_orig_parent = attack_button.get_parent()
			_attack_button_orig_pos = (attack_button.position if attack_button is Control else Vector2.ZERO)
		if attack_list and _attack_list_orig_parent == null:
			_attack_list_orig_parent = attack_list.get_parent()
			_attack_list_orig_pos = (attack_list.position if attack_list is Control else Vector2.ZERO)

		if goblin_texture:
			if attack_button:
				var curp = attack_button.get_parent()
				if curp:
					curp.remove_child(attack_button)
				goblin_texture.add_child(attack_button)
				attack_button.position = Vector2(16, overlay_size.y - 80)
			if attack_list:
				var curp2 = attack_list.get_parent()
				if curp2:
					curp2.remove_child(attack_list)
				goblin_texture.add_child(attack_list)
				attack_list.position = Vector2(16, overlay_size.y - 220)
	else:
		if attack_button and _attack_button_orig_parent:
			var curp = attack_button.get_parent()
			if curp:
				curp.remove_child(attack_button)
			_attack_button_orig_parent.add_child(attack_button)
			if attack_button is Control:
				attack_button.position = _attack_button_orig_pos
			_attack_button_orig_parent = null
		if attack_list and _attack_list_orig_parent:
			var curp2 = attack_list.get_parent()
			if curp2:
				curp2.remove_child(attack_list)
			_attack_list_orig_parent.add_child(attack_list)
			if attack_list is Control:
				attack_list.position = _attack_list_orig_pos
			_attack_list_orig_parent = null

func _show_attack_ui() -> void:
	if attack_button:
		attack_button.visible = true
	if attack_list:
		attack_list.visible = true

func _hide_attack_ui() -> void:
	if attack_button:
		attack_button.visible = false
	if attack_list:
		attack_list.visible = false

func _populate_attack_list() -> void:
	if not attack_list:
		return
	attack_list.clear()
	for a in player_attacks:
		attack_list.add_item(a["name"])

# Вспомогательная: синхронизировать GoblinTexture с RoadTexture (size/position/stetch_mode)
func _sync_overlay_to_road(scene_root: Node) -> void:
	if scene_root == null:
		return
	if not goblin_texture:
		return
	if not scene_root.has_node("RoadTexture"):
		return
	var road_tex := scene_root.get_node("RoadTexture") as TextureRect
	if not road_tex:
		return
	# Синхронизируем размер/позицию/режим растяжения и округляем позицию для pixel-perfect
	goblin_texture.size = road_tex.size
	goblin_texture.position = road_tex.position.round()
	goblin_texture.stretch_mode = road_tex.stretch_mode
