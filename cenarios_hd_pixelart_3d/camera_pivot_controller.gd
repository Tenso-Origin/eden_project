extends Node3D

## Controlador de Movimentação e Zoom do Pivô da Câmera
## ATENÇÃO: Movimente SEMPRE este nó pai, e NUNCA o nó Camera3D diretamente!
## A Camera3D é filha deste nó e calcula o Texel Snapping e erro sub-pixel com base na posição deste pivô.

@export var move_speed: float = 6.0
@export var rotation_speed: float = 2.0
@export var min_zoom_size: float = 0.8
@export var max_zoom_size: float = 4.0
@export var zoom_speed: float = 1.5

@onready var _camera: Camera3D = get_node_or_null("Camera3D")

func _unhandled_input(event: InputEvent) -> void:
	# Alternar Fullscreen com F11 ou Alt+Enter
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var current_mode = DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Tecla 0 ou Home para resetar zoom
		elif event.keycode == KEY_0 or event.keycode == KEY_HOME:
			if _camera:
				_camera.size = 1.6

	# Zoom via Mouse Wheel
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(-0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(0.15)

func _adjust_zoom(delta_zoom: float) -> void:
	if not _camera:
		_camera = get_node_or_null("Camera3D")
	if _camera:
		_camera.size = clampf(_camera.size + delta_zoom, min_zoom_size, max_zoom_size)

func _process(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir += transform.basis.x
		
	# Teclas Q e E para rotacionar em torno do eixo Y
	if Input.is_key_pressed(KEY_Q):
		rotate_y(rotation_speed * delta)
	if Input.is_key_pressed(KEY_E):
		rotate_y(-rotation_speed * delta)
		
	# Movimento vertical suave com R e F
	if Input.is_key_pressed(KEY_R):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_F):
		input_dir.y -= 1.0

	# Zoom contínuo pelo teclado com Z (-) e C (+) ou teclado numérico
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_adjust_zoom(zoom_speed * delta)
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_KP_ADD):
		_adjust_zoom(-zoom_speed * delta)

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		global_position += input_dir * move_speed * delta


