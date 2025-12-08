extends Node

@export var templates: Dictionary = {
	"goblin": {
		"name": "Гоблинша",
		"hp": 10
	}
}

func has_template(key: String) -> bool:
	return templates.has(key)

func get_template(key: String) -> Dictionary:
	return templates.get(key, {}).duplicate()

func get_all_keys() -> Array:
	return templates.keys()
