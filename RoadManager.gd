extends Control

@export var roads_folder: String = "res://roads"
@export var image_size: Vector2 = Vector2(786, 786)
@export var image_center: Vector2 = Vector2(816, 393)

@onready var road_texture_rect: TextureRect = $RoadTexture
@onready var event_label: RichTextLabel = $LeftPanel/EventLabel
@onready var hp_bar: RichTextLabel = $LeftPanel/HPBar  # HPBar
@onready var btn_move_forward: Button = $LeftPanel/btn_move_forward
@onready var nothing_events: Node = $NothingEvents
@onready var combat_manager: Node = $CombatManager

var road_textures: Array[Texture2D] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load_road_textures()
	_setup_texture_rect()
	_enter_new_room()
	btn_move_forward.pressed.connect(_on_move_forward)
	_update_hp_bar()  # ← Начальное HP

func _load_road_textures() -> void:
	road_textures.clear()
	for file in DirAccess.get_files_at(roads_folder):
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			var tex = load(roads_folder.path_join(file)) as Texture2D
			if tex:
				road_textures.append(tex)

func _setup_texture_rect() -> void:
	road_texture_rect.size = image_size
	var top_left = image_center - image_size * 0.5
	road_texture_rect.position = top_left
	road_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_move_forward() -> void:
	if combat_manager.in_combat:
		_append_log("Ты не можешь сбежать из боя, как трус!")
		return
	_enter_new_room()

func _enter_new_room() -> void:
	event_label.text = ""
	
	if road_textures.is_empty():
		road_texture_rect.texture = null
	else:
		road_texture_rect.texture = road_textures[rng.randi_range(0, road_textures.size() - 1)]
	
	if rng.randi_range(1, 100) <= 15:
		combat_manager.start_combat("goblin")
	else:
		event_label.text = nothing_events.get_random_phrase()
	
	_update_hp_bar()  # ← Обновляем после шага

# Функция для HPBar (использует combat_manager.player_hp)
func _update_hp_bar() -> void:
	if not hp_bar:
		return
	var hp_text = "[center][color=#ff0000]%d/%d[/color][/center]" % [combat_manager.player_hp, combat_manager.MAX_PLAYER_HP]
	hp_bar.text = hp_text

func _append_log(text: String) -> void:
	if not event_label:
		print("[LOG] " + text)
		return
	if event_label.text == "":
		event_label.text = text
	else:
		event_label.text += "\n" + text
	if event_label is RichTextLabel:
		event_label.scroll_to_line(event_label.get_line_count() - 1)
