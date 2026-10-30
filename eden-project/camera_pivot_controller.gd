extends Node3D

## Controlador de Movimentação e Zoom do Pivô da Câmera (HD Pixel Art 3D)
## ATENÇÃO: Movimente SEMPRE este nó pai, e NUNCA o nó Camera3D diretamente!
## A Camera3D calcula o Texel Snapping e erro sub-pixel com base na posição deste pivô.

@export var move_speed: float = 4.0
@export var rotation_speed: float = 2.0
@export var min_zoom_size: float = 0.8
@export var max_zoom_size: float = 4.0
@export var zoom_speed: float = 2.0
@export var default_pos: Vector3 = Vector3(0.15, 0.40, 0.0)
@export var default_size: float = 2.0

@onready var _camera: Camera3D = get_node_or_null("Camera3D")

var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not _camera:
		_camera = get_node_or_null("Camera3D")

func _unhandled_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _input(event: InputEvent) -> void:
	_handle_input_event(event)

func _handle_input_event(event: InputEvent) -> void:
	# Zoom via Mouse Wheel
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_zoom(-0.15)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_zoom(0.15)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				_is_dragging = true
				_drag_start_pos = event.position
		else:
			if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				_is_dragging = false

	# Pan por arrasto do mouse (Botão Direito ou Botão do Meio)
	elif event is InputEventMouseMotion and _is_dragging:
		if _camera:
			var factor: float = _camera.size / float(get_viewport().get_visible_rect().size.y)
			var motion_x: float = -event.relative.x * factor * 1.5
			var motion_y: float = event.relative.y * factor * 1.5
			global_position += transform.basis.x * motion_x + transform.basis.y * motion_y
			get_viewport().set_input_as_handled()

	# Tecla de Reset (0, Home ou Barra de Espaço)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_0 or event.keycode == KEY_HOME or event.keycode == KEY_SPACE:
			reset_camera()
			get_viewport().set_input_as_handled()

func _adjust_zoom(delta_zoom: float) -> void:
	if not _camera:
		_camera = get_node_or_null("Camera3D")
	if _camera:
		_camera.size = clampf(_camera.size + delta_zoom, min_zoom_size, max_zoom_size)

func reset_camera() -> void:
	global_position = default_pos
	if _camera:
		_camera.size = default_size

func _process(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO
	
	# Panning no plano de visão da câmera (W/S move verticalmente na tela, A/D move horizontalmente)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir += transform.basis.y
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir -= transform.basis.y
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir += transform.basis.x
		
	# Teclas Q e E para rotacionar em torno do eixo Y
	if Input.is_key_pressed(KEY_Q):
		rotate_y(rotation_speed * delta)
	if Input.is_key_pressed(KEY_E):
		rotate_y(-rotation_speed * delta)
		
	# Movimento de elevação vertical global com R e F
	if Input.is_key_pressed(KEY_R):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_F):
		input_dir.y -= 1.0

	# Zoom contínuo pelo teclado com Z (-) e C (+) ou teclado numérico (+/-)
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_adjust_zoom(zoom_speed * delta)
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_adjust_zoom(-zoom_speed * delta)

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		global_position += input_dir * move_speed * delta
