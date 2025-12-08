extends Node

@export var left_panel_name: String = "LeftPanel"
@export var event_label_rel_path: String = "LeftPanel/EventLabel"
@export var goblin_texture_name: String = "GoblinTexture"
@export var living_beings_name: String = "LivingBeings"
@export var goblins_folder: String = "res://goblins"

@onready var root: Node = get_tree().current_scene
@onready var left_panel: Control = root.get_node_or_null(left_panel_name)
@onready var event_label: RichTextLabel = root.get_node_or_null(event_label_rel_path)
@onready var goblin_texture: TextureRect = root.get_node_or_null(goblin_texture_name)
@onready var living_beings: Node = root.get_node_or_null(living_beings_name)
@onready var attack_button: Button = left_panel.get_node_or_null("AttackButton")
@onready var attack_list: ItemList = left_panel.get_node_or_null("AttackList")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var in_combat: bool = false
var player_hp: int = 0
var npc_hp: int = 0
var npc_name: String = ""
var player_attacks: Array = []  # ← УБРАЛ [Dictionary] — Godot 4.3 ругается!
var npc_attacks: Array = []     # ← То же самое

var _attack_button_orig_parent: Node = null
var _attack_button_orig_pos: Vector2 = Vector2.ZERO
var _attack_list_orig_parent: Node = null
var _attack_list_orig_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	rng.randomize()
	_connect_attack_signals()
	_sync_overlay_to_road()
	_hide_attack_ui()

func _connect_attack_signals() -> void:
	if attack_list:
		attack_list.item_activated.connect(_on_attack_selected)
	if attack_button:
		attack_button.pressed.connect(_on_attack_button_pressed)

func start_combat(npc_type: String) -> void:
	if in_combat:
		return
	_clear_event_log()
	
	var tpl = living_beings.get_template(npc_type) if living_beings else {"name": "Гоблинша", "hp": 10}
	
	npc_name = tpl.get("name", npc_type)
	npc_hp = tpl.get("hp", 10)
	
	# ИСПРАВЛЕНО: Безопасно берём атаки
	var default_attacks = [
		{"name": "полоснуть кинжалом", "min": 2, "max": 4},
		{"name": "укусить", "min": 0, "max": 5}
	]
	npc_attacks = tpl.get("attacks", default_attacks).duplicate()
	
	player_hp = 20
	player_attacks = [
		{"name": "удар с вертушки", "min": 1, "max": 5},
		{"name": "удар кулаком", "min": 2, "max": 3}
	]
	
	_sync_overlay_to_road()
	_set_random_goblin_texture(tpl)
	if goblin_texture:
		goblin_texture.visible = true
	in_combat = true
	_reparent_attack_ui(true)
	_populate_attack_list()
	_show_attack_ui()
	_append_log("На тропе нападает %s!" % npc_name)

func _set_random_goblin_texture(tpl: Dictionary) -> void:
	var texture_assigned := false
	if tpl.has("texture_path"):
		var tex = load(tpl["texture_path"]) as Texture2D
		if tex and goblin_texture:
			goblin_texture.texture = tex
			texture_assigned = true
	
	if not texture_assigned and goblin_texture:
		var dir = DirAccess.open(goblins_folder)
		if dir:
			dir.list_dir_begin()
			var files: Array[String] = []
			var fname := dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					var ext = fname.get_extension().to_lower()
					if ext in ["png", "jpg", "jpeg", "webp"]:
						files.append(goblins_folder.path_join(fname))
				fname = dir.get_next()
			dir.list_dir_end()
			if files.size() > 0:
				var path = files[rng.randi_range(0, files.size() - 1)]
				var tex = load(path) as Texture2D
				if tex:
					goblin_texture.texture = tex

func _on_attack_selected(index: int) -> void:
	if not in_combat or index < 0 or index >= player_attacks.size():
		return
	var attack = player_attacks[index] as Dictionary
	var dmg = rng.randi_range(attack["min"], attack["max"])
	npc_hp -= dmg
	_append_log("Я попытался сделать %s и нанёс %d урона" % [attack["name"], dmg])
	if npc_hp <= 0:
		_append_log("%s повержена!" % npc_name)
		_end_combat()
		return
	_npc_turn()

func _on_attack_button_pressed() -> void:
	if attack_list:
		attack_list.visible = not attack_list.visible

func _npc_turn() -> void:
	if not in_combat or npc_attacks.is_empty():
		return
	var atk = npc_attacks[rng.randi_range(0, npc_attacks.size() - 1)] as Dictionary
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
	_reparent_attack_ui(false)
	_hide_attack_ui()
	_append_log("Бой окончен.")

func _reparent_attack_ui(to_overlay: bool) -> void:
	if to_overlay:
		if attack_button:
			_attack_button_orig_parent = attack_button.get_parent()
			_attack_button_orig_pos = attack_button.position
			attack_button.reparent(goblin_texture)
			attack_button.position = Vector2(16, goblin_texture.size.y - 80)
		if attack_list:
			_attack_list_orig_parent = attack_list.get_parent()
			_attack_list_orig_pos = attack_list.position
			attack_list.reparent(goblin_texture)
			attack_list.position = Vector2(16, goblin_texture.size.y - 220)
	else:
		if attack_button and _attack_button_orig_parent:
			attack_button.reparent(_attack_button_orig_parent)
			attack_button.position = _attack_button_orig_pos
			_attack_button_orig_parent = null
		if attack_list and _attack_list_orig_parent:
			attack_list.reparent(_attack_list_orig_parent)
			attack_list.position = _attack_list_orig_pos
			_attack_list_orig_parent = null

func _show_attack_ui() -> void:
	if attack_button: attack_button.visible = true
	if attack_list:   attack_list.visible = true

func _hide_attack_ui() -> void:
	if attack_button: attack_button.visible = false
	if attack_list:   attack_list.visible = false

func _populate_attack_list() -> void:
	if not attack_list:
		return
	attack_list.clear()
	for a in player_attacks:
		var attack = a as Dictionary
		attack_list.add_item(attack["name"])

func _append_log(text: String) -> void:
	if not event_label:
		print("[Combat LOG] " + text)
		return
	if event_label.text == "":
		event_label.text = text
	else:
		event_label.text += "\n" + text
	if event_label is RichTextLabel:
		event_label.scroll_to_line(event_label.get_line_count() - 1)

func _clear_event_log() -> void:
	if event_label:
		event_label.text = ""

func _sync_overlay_to_road() -> void:
	if not goblin_texture or not root.has_node("RoadTexture"):
		return
	var road_tex = root.get_node("RoadTexture") as TextureRect
	if road_tex:
		goblin_texture.size = road_tex.size
		goblin_texture.position = road_tex.position.round()
		goblin_texture.stretch_mode = road_tex.stretch_mode
