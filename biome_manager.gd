extends Node

# Список всех биомов
const BIOMES = {
	"Forest": {
		"path": "res://roads/Forest/",
		"display_name": "Лес",
		"transition_chance": 0.05,
		"next_biomes": ["ConiferForest"]
	},
	"ConiferForest": {
		"path": "res://roads/ConiferForest/",
		"display_name": "Хвойный лес",
		"transition_chance": 0.05,
		"next_biomes": ["Forest"]
	}
}

var current_biome_key: String = "Forest"
var current_road_textures: Array[Texture2D] = []

@onready var road_manager = get_parent()  # ←←← ВОТ ГЛАВНОЕ ИЗМЕНЕНИЕ: родитель = Main = RoadManager
@onready var biome_label = get_parent().get_node("LeftPanel/BiomeLabel")

func _ready():
	load_biome(current_biome_key)
	update_biome_label()

func load_biome(biome_key: String):
	if not BIOMES.has(biome_key):
		push_error("Биом не найден: " + biome_key)
		return
	
	current_biome_key = biome_key
	var biome = BIOMES[biome_key]
	
	# Загружаем текстуры
	var dir = DirAccess.open(biome.path)
	if dir:
		current_road_textures.clear()
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["png", "jpg", "jpeg", "webp"]:
				var texture = load(biome.path + file_name)
				if texture:
					current_road_textures.append(texture)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if current_road_textures.is_empty():
		push_warning("Нет текстур в биоме: " + biome_key)
	else:
		print("Загружен биом: ", biome.display_name, " (", current_road_textures.size(), " текстур)")
	
	# Передаём массив текстур напрямую в переменную RoadManager (которая на Main)
	road_manager.road_textures = current_road_textures.duplicate()
	
	update_biome_label()

func update_biome_label():
	if biome_label:
		biome_label.text = " " + BIOMES[current_biome_key].display_name

func try_transition():
	var biome = BIOMES[current_biome_key]
	var biome_rng = RandomNumberGenerator.new()
	biome_rng.randomize()
	
	# Тестовый шанс 50%
	if biome_rng.randf() < 0.02:
		if not biome.next_biomes.is_empty():
			var next_key = biome.next_biomes[biome_rng.randi_range(0, biome.next_biomes.size() - 1)]
			if next_key != current_biome_key:
				# Сообщение в лог событий
				var event_label = get_parent().get_node("LeftPanel/EventLabel")
				if event_label:
					event_label.text += "\nТы вышел на новую тропу... Это " + BIOMES[next_key].display_name + "!"
				load_biome(next_key)
