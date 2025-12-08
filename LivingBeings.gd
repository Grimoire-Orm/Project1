extends Node

# LivingBeings — центральное хранилище шаблонов живых существ.
# Сюда удобно добавлять новые типы NPC (goblin, wolf и т.д.).
# CombatManager будет запрашивать шаблон через get_template("goblin").

# Формат templates:
# templates = {
#   "goblin": {"name":"Гоблинша", "hp":10, "sprite_scale": Vector2(1,1), ...},
#   ...
# }

@export var templates: Dictionary = {
	"goblin": {
		"name": "Гоблинша",
		"hp": 10
	}
}

# Возвращает копию шаблона (чтобы не менять сам шаблон при арифметике)
func get_template(key: String) -> Dictionary:
	if templates.has(key):
		# shallow copy (ok для простых типов)
		var t = templates[key]
		var copy = {}
		for k in t.keys():
			copy[k] = t[k]
		return copy
	return {}

# Удобный метод — проверяет, есть ли шаблон
func has_template(key: String) -> bool:
	return templates.has(key)
