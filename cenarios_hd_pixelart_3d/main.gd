extends Control

## Gerenciador Principal da Janela e Entrada
## Repassa todos os eventos de entrada (mouse, teclado, rolagem) para a SubViewport
## para que o CameraPivot e a cena 3D respondam perfeitamente.

@onready var sub_viewport: SubViewport = $SubViewport

func _unhandled_input(event: InputEvent) -> void:
	if sub_viewport:
		sub_viewport.push_input(event)

func _input(event: InputEvent) -> void:
	# Garante que eventos de rolagem de mouse (wheel) e atalhos globais cheguem à SubViewport
	if event is InputEventMouseButton:
		if sub_viewport:
			sub_viewport.push_input(event)
	elif event is InputEventKey:
		# Atalho global de Fullscreen
		if event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
				var current_mode := DisplayServer.window_get_mode()
				if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				get_viewport().set_input_as_handled()

