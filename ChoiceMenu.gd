extends ScrollContainer

@onready var vbox: VBoxContainer = $VBoxContainer

func _ready() -> void:
	# Авто-фикс warning: устанавливаем min size для child
	vbox.custom_minimum_size = Vector2(0, 0)  # Подгони, если нужно больше/меньше

func show_choices(choices: Array, actions: Array) -> void:  # ← Убрали типы [String] и [Callable]
	visible = true
	# Очищаем старые кнопки
	for child in vbox.get_children():
		child.queue_free()
	
	# Создаем новые кнопки динамически по количеству choices
	for i in range(choices.size()):
		var button = Button.new()
		button.text = choices[i]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD  # ← Для мультилайн (2-3 строки)
		button.pressed.connect(func():
			actions[i].call()  # Вызываем действие
			visible = false  # Скрываем меню после выбора
		)
		vbox.add_child(button)
	
	# Автоматически скроллим к верху
	scroll_vertical = 0
