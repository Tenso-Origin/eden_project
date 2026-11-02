extends Camera3D

## Pixel-Perfect Orthographic Camera (David Holland Architecture)
## Trava a câmera 3D na grade de texels no espaço de visão (view space)
## e compensa o erro sub-pixel enviando o offset fracionário para o shader 2D de upscale.

@export var display_item: CanvasItem
@export var target_resolution: Vector2i = Vector2i(240, 135)
@export var distance_from_pivot: float = 20.0

var _texel_size: float = 0.0

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	# Garante que a SubViewport tenha 2 pixels extras de margem para o deslocamento sub-pixel
	var svp := get_viewport() as SubViewport
	if svp:
		svp.size = target_resolution + Vector2i(2, 2)
		if not display_item and svp.get_parent() is CanvasItem:
			display_item = svp.get_parent() as CanvasItem

func _process(_delta: float) -> void:
	var parent_node := get_parent_node_3d()
	if not parent_node:
		return

	# Calcula o tamanho exato de 1 pixel no espaço 3D com base no 'size' ortográfico
	_texel_size = size / float(target_resolution.y)

	# 1. Pega a posição desejada do pivô pai e converte para o espaço alinhado à rotação da câmera
	var desired_pos: Vector3 = parent_node.global_position
	var cam_basis: Basis = global_transform.basis
	var view_space_pos: Vector3 = desired_pos * cam_basis

	# 2. Faz o Snap para a grade de texels apenas nos eixos X e Y da visão
	var snapped_view_pos: Vector3 = view_space_pos
	snapped_view_pos.x = round(view_space_pos.x / _texel_size) * _texel_size
	snapped_view_pos.y = round(view_space_pos.y / _texel_size) * _texel_size
	snapped_view_pos.z = view_space_pos.z + distance_from_pivot

	# 3. Calcula o erro sub-pixel (em frações de -0.5 a 0.5 texel)
	var subpixel_error: Vector2 = Vector2(
		(view_space_pos.x - snapped_view_pos.x) / _texel_size,
		(view_space_pos.y - snapped_view_pos.y) / _texel_size
	)

	# 4. Aplica a posição travada na câmera de volta ao World Space
	global_position = cam_basis * snapped_view_pos

	# 5. Envia o deslocamento sub-pixel para o shader 2D deslizar a imagem suavemente
	if display_item and display_item.material is ShaderMaterial:
		var mat := display_item.material as ShaderMaterial
		mat.set_shader_parameter("cam_offset", subpixel_error)
