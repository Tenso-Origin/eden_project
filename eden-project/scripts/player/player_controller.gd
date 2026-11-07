@tool
extends CharacterBody3D
class_name PlayerController3D

## =========================================================================
## CONTROLADOR DO JOGADOR - PERSPECTIVA ORTOGRÁFICA (David Holland Architecture)
## =========================================================================
## Movimentação tridimensional alinhada aos eixos visuais da câmera isométrica,
## com estados cinemáticos de caminhada, corrida, vadeamento e natação.
## Integrado nativamente ao sistema de fisiologia (PlayerVitals).

@export_group("Velocidades de Locomoção (m/s)")
@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var wade_speed: float = 2.0
@export var swim_speed: float = 1.8
@export var rotation_speed: float = 12.0
@export var gravity: float = 24.0

@export_group("Referências de Nós")
@export var vitals: PlayerVitals
@export var visual_node: Node3D
@export var camera_pivot: Node3D

enum MoveState { IDLE, WALK, RUN, WADE, SWIM }
var current_state: MoveState = MoveState.IDLE

var is_sprinting: bool = false
var water_surface_y: float = -999.0 # Nível da água na posição atual

func _ready() -> void:
	if not vitals:
		vitals = get_node_or_null("PlayerVitals") as PlayerVitals
		if not vitals:
			vitals = PlayerVitals.new()
			vitals.name = "PlayerVitals"
			add_child(vitals)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if vitals and vitals.is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# 1. Leitura de Input com fallback inteligente (WASD / Setas / Ações de Projeto)
	var raw_input = _get_movement_input()
	is_sprinting = Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT)

	# 2. Conversão do Input para o espaço de visão alinhado à Câmera Ortográfica
	var move_dir = _calculate_view_aligned_direction(raw_input)

	# 3. Determinação de profundidade de água e Estado de Movimento
	var depth_in_water = 0.0
	if water_surface_y > -900.0:
		depth_in_water = maxf(0.0, water_surface_y - global_position.y)

	var target_speed = walk_speed

	if depth_in_water > 1.2:
		current_state = MoveState.SWIM
		target_speed = swim_speed
		if vitals:
			vitals.is_swimming = true
			vitals.is_running = false
	elif depth_in_water > 0.3:
		current_state = MoveState.WADE
		target_speed = wade_speed
		if vitals:
			vitals.is_swimming = false
			vitals.is_running = false
	else:
		if vitals:
			vitals.is_swimming = false

		if move_dir.length_squared() > 0.01:
			if is_sprinting and vitals and vitals.current_stamina > 5.0:
				current_state = MoveState.RUN
				target_speed = run_speed
				if vitals:
					vitals.is_running = true
			else:
				current_state = MoveState.WALK
				target_speed = walk_speed
				if vitals:
					vitals.is_running = false
		else:
			current_state = MoveState.IDLE
			if vitals:
				vitals.is_running = false

	# 4. Aplicação de Velocidade Horizontal
	if move_dir.length_squared() > 0.01:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed

		# Rotação suave do modelo visual em direção ao vetor de deslocamento
		if visual_node:
			var target_rot_y = atan2(-move_dir.x, -move_dir.z)
			visual_node.rotation.y = lerp_angle(visual_node.rotation.y, target_rot_y, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, target_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * 10.0 * delta)

	# 5. Gravidade e Flutuação
	if current_state == MoveState.SWIM:
		# Flutuação na linha d'água
		var target_y = water_surface_y - 0.9
		velocity.y = (target_y - global_position.y) * 5.0
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1

	move_and_slide()

	# 6. Atualização fisiológica
	if vitals:
		vitals.update_vitals(delta, 28.0, current_state == MoveState.SWIM, false)

	# 7. Sincronização de Câmera (mantém o pivô centralizado no player)
	if camera_pivot:
		camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, 10.0 * delta)

func _get_movement_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input.x += 1.0
	return input.normalized()

func _calculate_view_aligned_direction(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO

	# Rotação isométrica canônica de 45 graus (câmera olhando a noroeste/sudeste)
	# Garante que W mova para "cima-direita" na tela isométrica ou frente no view-space
	var dir := Vector3.ZERO
	if camera_pivot:
		var cam_basis = camera_pivot.global_transform.basis
		var forward = -cam_basis.z
		var right = cam_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		dir = (right * input.x + forward * (-input.y)).normalized()
	else:
		# Fallback com rotação canônica de 45 graus
		var iso_x = (input.x - input.y) * 0.707107
		var iso_z = (input.x + input.y) * 0.707107
		dir = Vector3(iso_x, 0.0, iso_z).normalized()

	return dir

func set_water_surface(y_level: float) -> void:
	water_surface_y = y_level

func clear_water_surface() -> void:
	water_surface_y = -999.0
