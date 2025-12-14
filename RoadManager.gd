extends Control

@export var image_size: Vector2 = Vector2(786, 786)
@export var image_center: Vector2 = Vector2(816, 393)

@onready var road_texture_rect: TextureRect = $RoadTexture
@onready var event_label: RichTextLabel = $LeftPanel/EventLabel
@onready var hp_bar: RichTextLabel = $LeftPanel/HPBar  # HPBar
@onready var btn_move_forward: Button = $LeftPanel/btn_move_forward
@onready var nothing_events: Node = $NothingEvents
@onready var combat_manager: Node = $CombatManager
@onready var biome_manager: Node = $BiomeManager

const SAFE_STEPS: int = 10  # Первые N шагов без боёв (меняй здесь!)


var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var steps_taken: int = 0
# Массив текстур теперь будет перезаписываться BiomeManager'ом
var road_textures: Array[Texture2D] = []

func _ready() -> void:
	rng.randomize()
	_setup_texture_rect()
	_enter_new_room()
	btn_move_forward.pressed.connect(_on_move_forward)
	_update_hp_bar()  # ← Начальное HP


func _setup_texture_rect() -> void:
	road_texture_rect.size = image_size
	var top_left = image_center - image_size * 0.5
	road_texture_rect.position = top_left
	road_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_move_forward():  # ←←← Обратите внимание: функция с подчёркиванием!
	steps_taken += 1
	
	# Загружаем случайную картинку из текущего биома
	if road_textures.is_empty():
		road_texture_rect.texture = null
		event_label.text = "Кругом тьма... Ты потерялся."
	else:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var random_index = rng.randi_range(0, road_textures.size() - 1)
		road_texture_rect.texture = road_textures[random_index]
		
		# Шанс боя (только после safe steps)
		if rng.randi_range(1, 100) <= 15 and steps_taken > SAFE_STEPS:
			combat_manager.start_combat("goblin")
			return  # Бой начался — дальше ничего не делаем
		
		# Обычное событие
		event_label.text = nothing_events.get_random_phrase()
	
	# Попытка смены биома после шага
	biome_manager.try_transition()

func _enter_new_room() -> void:
	steps_taken += 1
	event_label.text = ""
	
	if road_textures.is_empty():
		road_texture_rect.texture = null
	else:
		road_texture_rect.texture = road_textures[rng.randi_range(0, road_textures.size() - 1)]
	
	if rng.randi_range(1, 100) <= 15 and steps_taken > SAFE_STEPS:
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

#окно\фулскрин
func _input(event):
	if event.is_action_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
