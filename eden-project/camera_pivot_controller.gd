extends Node3D

## Controlador de Movimentação do Pivô da Câmera
## ATENÇÃO: Movimente SEMPRE este nó pai, e NUNCA o nó Camera3D diretamente!
## A Camera3D é filha deste nó e calcula o Texel Snapping e erro sub-pixel com base na posição deste pivô.

@export var move_speed: float = 6.0
@export var rotation_speed: float = 2.0

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

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		global_position += input_dir * move_speed * delta

