extends Node

signal choice_made(index: int, text: String)

var choice_menu_scene: PackedScene = preload("res://scenes/ChoiceMenu.tscn")
var current_instance: Control = null

func show_choices(title: String, options: Array[String], callback: Callable):
	# Удаляем старое, если было
	if current_instance:
		current_instance.queue_free()
	
	# Создаём новое
	current_instance = choice_menu_scene.instantiate()
	get_tree().current_scene.add_child(current_instance)
	
	# Настраиваем
	var title_label = current_instance.get_node("BackgroundPanel/OptionsContainer/TitleLabel")
	title_label.text = title
	
	var container = current_instance.get_node("BackgroundPanel/OptionsContainer")
	
	# Очищаем старые кнопки
	for child in container.get_children():
		if child is Button:
			child.queue_free()
	
	# Добавляем новые кнопки
	for i in options.size():
		var btn = Button.new()
		btn.text = options[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 60
# ПРАВИЛЬНЫЙ СПОСОБ УСТАНОВКИ РАЗМЕРА ШРИФТА
		btn.add_theme_font_size_override("font_size", 24)
		container.add_child(btn)
		btn.pressed.connect(_on_option_pressed.bind(i, options[i]))
	
	# Центрируем меню
	current_instance.anchor_left = 0.5
	current_instance.anchor_top = 0.5
	current_instance.anchor_right = 0.5
	current_instance.anchor_bottom = 0.5
	current_instance.offset_left = -300
	current_instance.offset_right = 300
	current_instance.offset_top = -200
	current_instance.offset_bottom = 200
	
	# Z-index выше всего
	current_instance.z_index = 30
	
	# Подключаем коллбэк
	# Отключаем все предыдущие подключения к choice_made (на всякий случай)
	if choice_made.get_connections().size() > 0:
		for conn in choice_made.get_connections():
			choice_made.disconnect(conn.callable)

# Теперь безопасно подключаем новый
	if callback.is_valid():
		choice_made.connect(callback, CONNECT_ONE_SHOT)

func _on_option_pressed(index: int, text: String):
	if current_instance:
		current_instance.queue_free()
		current_instance = null
	choice_made.emit(index, text)

func hide_menu():
	if current_instance:
		current_instance.queue_free()
		current_instance = null
