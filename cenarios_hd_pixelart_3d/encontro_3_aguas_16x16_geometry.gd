@tool
extends Node3D
class_name Encontro3Aguas16x16Geometry

## Geometria da Cena de Teste de Hidrologia 16x16m - Encontro das 3 Águas
## Estritamente focada no encontro de:
## 1. Água Turquesa Cristalina (Clearwater / Calcário)
## 2. Água Barrenta de Várzea (Whitewater / Sedimentos / Solimões)
## 3. Água Preta de Igarapé (Blackwater / Chá Mate / Rio Negro)
## Com faixas de mistura natural contínua, grade modular 1x1x1m e snapping vertical 0.25m
## Shaders: pixel_water.gdshader (enable_3way_blend) e pixel_surface.gdshader

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")

const SNAP_V: float = 0.25 # Snapping vertical estrito de 0.25m
const SNAP_H: float = 1.00 # Snapping horizontal estrito de 1.00m

# Paleta Geológica Oficial (David Holland / Kit de Biomas Tropicais)
const COL_WHITE_SAND_LIGHT = Color(0.88, 0.86, 0.82) # Areia Branca Luz
const COL_WHITE_SAND_MID   = Color(0.74, 0.71, 0.66) # Areia Branca Meia-Luz
const COL_WHITE_SAND_WET   = Color(0.60, 0.58, 0.53) # Leito de Areia molhada sob Turquesa
const COL_CALCARIO_LIGHT   = Color(0.82, 0.84, 0.80) # Calcário claro
const COL_CALCARIO_MID     = Color(0.65, 0.68, 0.64) # Calcário médio
const COL_SERRAPILHEIRA    = Color(0.18, 0.12, 0.09) # Tapete de húmus escuro (Floresta)
const COL_TERRA_PRETA      = Color(0.13, 0.11, 0.10) # Horizonte A / Leito sob Água Preta
const COL_LATERITA_CLAY    = Color(0.56, 0.23, 0.14) # Latossolo avermelhado / Leito sob Água Barrenta
const COL_GRANITO_MID      = Color(0.33, 0.31, 0.30) # Granito Tropical
const COL_GRANITO_DARK     = Color(0.18, 0.20, 0.22) # Basalto profundo

var terrain_instance: MeshInstance3D
var water_instance: MeshInstance3D

func _ready() -> void:
	generate_scene()

func generate_scene() -> void:
	for child in get_children():
		child.queue_free()

	var terrain_mesh = build_terrain_mesh()
	var water_mesh = build_water_mesh()

	if terrain_mesh:
		terrain_instance = MeshInstance3D.new()
		terrain_instance.name = "TerrainMesh16x16"
		terrain_instance.mesh = terrain_mesh

		var mat_surface = ShaderMaterial.new()
		mat_surface.shader = SHADER_SURFACE
		mat_surface.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
		mat_surface.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
		mat_surface.set_shader_parameter("light_bands", 3)
		mat_surface.set_shader_parameter("dither_spread", 0.0)

		var tex_serra = load("res://tex_serrapilheira.png")
		if tex_serra:
			mat_surface.set_shader_parameter("use_top_texture", true)
			mat_surface.set_shader_parameter("top_albedo_texture", tex_serra)
			mat_surface.set_shader_parameter("top_texture_scale", 0.35)
		else:
			mat_surface.set_shader_parameter("use_top_texture", false)

		terrain_instance.material_override = mat_surface
		# Centraliza 16x16m em [-8m, +8m]
		terrain_instance.position = Vector3(-8.0, 0.0, -8.0)
		add_child(terrain_instance)

	if water_mesh:
		water_instance = MeshInstance3D.new()
		water_instance.name = "WaterMesh16x16"
		water_instance.mesh = water_mesh

		var mat_water = ShaderMaterial.new()
		mat_water.shader = SHADER_WATER
		mat_water.set_shader_parameter("enable_3way_blend", true)
		mat_water.set_shader_parameter("pixel_grid_density", 64.0)
		mat_water.set_shader_parameter("wave_speed", 1.8)
		mat_water.set_shader_parameter("wave_height", 0.02)
		mat_water.set_shader_parameter("use_voronoi", false)
		mat_water.set_shader_parameter("wave_speed", 2.0)
		mat_water.set_shader_parameter("wave_height", 0.02)
		mat_water.set_shader_parameter("contact_foam_threshold", 0.06)
		mat_water.set_shader_parameter("reflection_strength", 0.35)
		mat_water.set_shader_parameter("reflection_distortion_px", 1.8)
		mat_water.set_shader_parameter("wind_direction", Vector2(0.7071, 0.7071))
		mat_water.set_shader_parameter("wind_speed", 2.0)
		mat_water.set_shader_parameter("wind_strength", 1.0)
		mat_water.set_shader_parameter("refraction_strength", 4.0)
		mat_water.set_shader_parameter("dash_density", 0.55)
		mat_water.set_shader_parameter("dash_cycle_speed", 0.55)
		mat_water.set_shader_parameter("shoreline_foam_dist", 0.30)
		mat_water.set_shader_parameter("shoreline_ripple_rings", 3)
		mat_water.set_shader_parameter("foam_color", Color(0.96, 0.98, 1.0))

		# Parâmetros oficiais calibrados para as 3 águas (transparência nítida sem opacidade leitosa)
		mat_water.set_shader_parameter("turquesa_shallow", Color(0.18, 0.82, 0.78, 0.50))
		mat_water.set_shader_parameter("turquesa_deep", Color(0.05, 0.38, 0.48, 0.90))
		mat_water.set_shader_parameter("turquesa_fade", 1.20)

		mat_water.set_shader_parameter("barrenta_shallow", Color(0.62, 0.47, 0.31, 0.85))
		mat_water.set_shader_parameter("barrenta_deep", Color(0.38, 0.26, 0.16, 0.98))
		mat_water.set_shader_parameter("barrenta_fade", 0.22)

		mat_water.set_shader_parameter("igarape_shallow", Color(0.38, 0.24, 0.11, 0.60))
		mat_water.set_shader_parameter("igarape_deep", Color(0.11, 0.06, 0.04, 0.96))
		mat_water.set_shader_parameter("igarape_fade", 0.55)

		water_instance.material_override = mat_water
		water_instance.position = Vector3(-8.0, 0.0, -8.0)
		add_child(water_instance)

	print("Cena de Encontro das 3 Águas 16x16m gerada com sucesso!")

# =========================================================================
# MODELO MATEMÁTICO DE HIDROLOGIA E CONFLUÊNCIA DAS 3 ÁGUAS
# =========================================================================

## Determina se uma célula (ix, iz) possui lâmina d'água
func is_water_cell(ix: int, iz: int) -> bool:
	# Zona Norte (iz <= 4): três tributários separados por penínsulas
	if iz <= 4:
		var ct_x = 3.0 + 0.40 * float(iz)   # Braço Turquesa
		var cb_x = 8.0                      # Braço Barrento
		var cp_x = 13.0 - 0.40 * float(iz)  # Braço Preto

		var dist_t = abs(float(ix) + 0.5 - ct_x)
		var dist_b = abs(float(ix) + 0.5 - cb_x)
		var dist_p = abs(float(ix) + 0.5 - cp_x)

		if dist_t <= 1.6: return true
		if dist_b <= 1.25: return true
		if dist_p <= 1.6: return true
		return false

	# Confluência e Rio Principal (iz >= 5)
	var bank_left = 2.0 + 0.4 * sin(float(iz) * 0.55)
	var bank_right = 14.0 + 0.4 * sin(float(iz) * 0.45 + 1.2)
	var cx = float(ix) + 0.5
	return cx >= bank_left and cx <= bank_right

## Avalia continuamente o fator de mistura das 3 águas em uma coordenada exata (x, z)
## Retorna Dictionary com blend_t [0=Turquesa, 0.5=Barrenta, 1.0=Preta], UV2 e flow_dir
func evaluate_water_blend_at(x: float, z: float) -> Dictionary:
	var result = {
		"blend_t": 0.0,
		"uv2": Vector2(1, 0),
		"flow_dir": Vector2(0, 1),
		"turbulence": 0.10
	}

	# 1. ZONA NORTE (z <= 4.8): Três tributários convergentes
	if z <= 4.8:
		var ct_x = 3.0 + 0.40 * z
		var cb_x = 8.0
		var cp_x = 13.0 - 0.40 * z

		if x <= ct_x + 1.5:
			result.blend_t = 0.0
			result.uv2 = Vector2(1.0, 0.0)
			result.flow_dir = Vector2(0.35, 0.94).normalized()
			result.turbulence = 0.10
			return result

		if x >= cp_x - 1.5:
			result.blend_t = 1.0
			result.uv2 = Vector2(0.0, 0.0)
			result.flow_dir = Vector2(-0.35, 0.94).normalized()
			result.turbulence = 0.08
			return result

		# Região entre Turquesa e Barrenta
		if x < cb_x:
			var p = clamp((x - (ct_x + 1.2)) / 1.6, 0.0, 1.0)
			var t = (p * p * (3.0 - 2.0 * p)) * 0.5
			result.blend_t = t
			result.uv2 = Vector2(1.0 - t * 2.0, t * 2.0)
			result.flow_dir = Vector2(0.15, 0.98).normalized()
			result.turbulence = 0.14
			return result

		# Região entre Barrenta e Preta
		var p2 = clamp((x - cb_x) / 1.8, 0.0, 1.0)
		var t2 = 0.5 + (p2 * p2 * (3.0 - 2.0 * p2)) * 0.5
		result.blend_t = t2
		result.uv2 = Vector2(0.0, 1.0 - (t2 - 0.5) * 2.0)
		result.flow_dir = Vector2(-0.15, 0.98).normalized()
		result.turbulence = 0.12
		return result

	# 2. CONFLUÊNCIA E CANAL PRINCIPAL (z > 4.8)
	var bank_left = 2.0 + 0.4 * sin(z * 0.55)
	var bank_right = 14.0 + 0.4 * sin(z * 0.45 + 1.2)
	var u = clamp((x - bank_left) / (bank_right - bank_left), 0.0, 1.0)

	# Meandro orgânico contínuo das faixas de correnteza
	var meander = 0.038 * sin(z * 0.75 + x * 0.3) + 0.022 * cos(z * 1.3 - x * 0.2)
	var u_fluid = clamp(u + meander, 0.0, 1.0)

	# Faixas transversais contínuas:
	# u in [0.00, 0.28] -> Água Turquesa pura
	# u in [0.28, 0.48] -> Faixa de Mistura Contínua Turquesa <-> Barrenta
	# u in [0.48, 0.54] -> Núcleo de Água Barrenta pura
	# u in [0.54, 0.74] -> Faixa de Mistura Contínua Barrenta <-> Preta
	# u in [0.74, 1.00] -> Água Preta pura
	var t: float = 0.0
	if u_fluid <= 0.28:
		t = 0.0
	elif u_fluid < 0.48:
		var p = (u_fluid - 0.28) / (0.48 - 0.28)
		t = (p * p * (3.0 - 2.0 * p)) * 0.5
	elif u_fluid <= 0.54:
		t = 0.5
	elif u_fluid < 0.74:
		var p = (u_fluid - 0.54) / (0.74 - 0.54)
		t = 0.5 + (p * p * (3.0 - 2.0 * p)) * 0.5
	else:
		t = 1.0

	result.blend_t = t
	if t <= 0.5:
		result.uv2 = Vector2(1.0 - t * 2.0, t * 2.0)
	else:
		result.uv2 = Vector2(0.0, 1.0 - (t - 0.5) * 2.0)

	result.flow_dir = Vector2(0.04 * sin(z * 0.5), 1.0).normalized()
	result.turbulence = 0.09
	return result

## Altura única e plana de cada célula [16 x 16] do terreno (Estilo Voxel 1x1x1m com Snapping 0.25m)
func evaluate_cell_height(ix: int, iz: int) -> float:
	var is_water = is_water_cell(ix, iz)
	if is_water:
		# Leito do rio escavado sob a lâmina d'água (Y_water = 1.00m fixo)
		# Barrenta no centro é ligeiramente mais rasa (0.50m) devido a assoreamento
		var blend_info = evaluate_water_blend_at(float(ix) + 0.5, float(iz) + 0.5)
		var t = blend_info.blend_t
		if t >= 0.40 and t <= 0.60:
			return 0.50 # 0.50m sob a água
		return 0.25     # 0.75m sob a água (leito profundo transparente ou âmbar)

	# Terreno Emerso: Terraços horizontais escalonados
	# 1. Zona Norte (iz <= 4): Penínsulas entre os rios
	if iz <= 4:
		if ix >= 4 and ix <= 6:
			# Península 1 (Turquesa <-> Barrenta): desce de 1.75m para 1.25m
			return 1.25 if iz >= 3 else 1.50
		if ix >= 9 and ix <= 11:
			# Península 2 (Barrenta <-> Preta): desce de 1.75m para 1.25m
			return 1.25 if iz >= 3 else 1.50

	# 2. Margem Oeste (ix < 4): Campina de Areia Branca e Calcário
	if ix <= 3:
		if ix == 0: return 2.25
		if ix == 1: return 2.00
		return 1.50

	# 3. Margem Leste (ix > 12): Morro de Floresta Tropical e Serrapilheira
	if ix >= 12:
		if ix == 15: return 2.50
		if ix == 14: return 2.25
		return 1.50

	return 1.25

# =========================================================================
# CONSTRUÇÃO DA MALHA DO TERRENO (BLOCO A BLOCO 1x1x1m COM PAREDÕES 90°)
# =========================================================================

func build_terrain_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Matriz de alturas de células 16x16
	var cell_h: Array = []
	for iz in range(16):
		var row: Array = []
		for ix in range(16):
			row.append(evaluate_cell_height(ix, iz))
		cell_h.append(row)

	# 2. Gera os topos planos horizontais e paredes verticais de cada bloco
	for iz in range(16):
		for ix in range(16):
			var h = cell_h[iz][ix]
			var lx0 = float(ix) * SNAP_H
			var lx1 = float(ix + 1) * SNAP_H
			var lz0 = float(iz) * SNAP_H
			var lz1 = float(iz + 1) * SNAP_H

			var is_submerged = is_water_cell(ix, iz)
			var blend_info = evaluate_water_blend_at(lx0 + 0.5, lz0 + 0.5)
			var top_col = _get_cell_top_color(ix, iz, is_submerged, blend_info.blend_t)

			# Topo perfeitamente horizontal (Normal = UP)
			var v00 = Vector3(lx0, h, lz0)
			var v10 = Vector3(lx1, h, lz0)
			var v01 = Vector3(lx0, h, lz1)
			var v11 = Vector3(lx1, h, lz1)

			# Triângulo 1 (CCW)
			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx0, lz0))
			st.add_vertex(v00)

			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

			# Triângulo 2 (CCW)
			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx1, lz1))
			st.add_vertex(v11)

			st.set_normal(Vector3.UP)
			st.set_color(top_col)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

			# 3. Paredes verticais de desnível com os 4 vizinhos (Degraus exatos de 90°)
			# Vizinho Norte (Z - 1)
			var h_north = cell_h[iz - 1][ix] if iz > 0 else 0.0
			if h > h_north:
				_build_wall_rect(st, Vector3(lx0, h_north, lz0), Vector3(lx1, h_north, lz0),
					Vector3(lx0, h, lz0), Vector3(lx1, h, lz0), Vector3.FORWARD, ix)

			# Vizinho Sul (Z + 1)
			var h_south = cell_h[iz + 1][ix] if iz < 15 else 0.0
			if h > h_south:
				_build_wall_rect(st, Vector3(lx1, h_south, lz1), Vector3(lx0, h_south, lz1),
					Vector3(lx1, h, lz1), Vector3(lx0, h, lz1), Vector3.BACK, ix)

			# Vizinho Oeste (X - 1)
			var h_west = cell_h[iz][ix - 1] if ix > 0 else 0.0
			if h > h_west:
				_build_wall_rect(st, Vector3(lx0, h_west, lz1), Vector3(lx0, h_west, lz0),
					Vector3(lx0, h, lz1), Vector3(lx0, h, lz0), Vector3.LEFT, ix)

			# Vizinho Leste (X + 1)
			var h_east = cell_h[iz][ix + 1] if ix < 15 else 0.0
			if h > h_east:
				_build_wall_rect(st, Vector3(lx1, h_east, lz0), Vector3(lx1, h_east, lz1),
					Vector3(lx1, h, lz0), Vector3(lx1, h, lz1), Vector3.RIGHT, ix)

	# 4. Adiciona rochas proeminentes de destaque para reflexos e anéis de espuma
	_add_prominent_river_rocks(st)

	return st.commit()

func _get_cell_top_color(ix: int, iz: int, is_submerged: bool, blend_t: float) -> Color:
	if is_submerged:
		if blend_t <= 0.5:
			return COL_WHITE_SAND_WET.lerp(COL_LATERITA_CLAY, blend_t * 2.0)
		else:
			return COL_LATERITA_CLAY.lerp(COL_TERRA_PRETA, (blend_t - 0.5) * 2.0)

	var norm_x = float(ix) / 15.0
	if norm_x <= 0.30:
		return COL_WHITE_SAND_LIGHT if ix <= 1 else COL_WHITE_SAND_MID
	elif norm_x <= 0.70:
		var p = (norm_x - 0.30) / 0.40
		return COL_WHITE_SAND_MID.lerp(COL_SERRAPILHEIRA, p)
	else:
		return COL_SERRAPILHEIRA

func _build_wall_rect(st: SurfaceTool, b0: Vector3, b1: Vector3, t0: Vector3, t1: Vector3, normal: Vector3, ix: int) -> void:
	var norm_x = float(ix) / 15.0
	var col_wall = COL_GRANITO_MID
	if norm_x > 0.35 and norm_x < 0.65:
		col_wall = COL_LATERITA_CLAY
	elif norm_x >= 0.65:
		col_wall = COL_TERRA_PRETA.lerp(COL_GRANITO_DARK, 0.4)
	else:
		col_wall = COL_CALCARIO_MID

	# Triângulo 1 (CCW)
	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(b0)

	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(b1)

	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(t0)

	# Triângulo 2 (CCW)
	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(b1)

	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(t1)

	st.set_normal(normal)
	st.set_color(col_wall)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(t0)

func _add_prominent_river_rocks(st: SurfaceTool) -> void:
	# 1. Rocha saliente no raso da Água Turquesa (lx=2.8, lz=7.5) -> reflexo puro em água cristalina
	_add_block_rock(st, Vector3(2.8, 0.25, 7.5), Vector3(0.7, 1.0, 0.7), COL_CALCARIO_LIGHT)
	# 2. Rocha na ponta de terra entre Turquesa e Barrenta (lx=5.5, lz=4.8) -> marca o 1º encontro
	_add_block_rock(st, Vector3(5.5, 0.50, 4.8), Vector3(0.8, 0.8, 0.8), COL_GRANITO_MID)
	# 3. Rocha na ponta de terra entre Barrenta e Preta (lx=10.2, lz=4.8) -> marca o 2º encontro
	_add_block_rock(st, Vector3(10.2, 0.50, 4.8), Vector3(0.8, 0.8, 0.8), COL_GRANITO_MID)
	# 4. Rocha escura saliente na margem da Água Preta (lx=13.2, lz=9.0) -> reflexo na água espelhada
	_add_block_rock(st, Vector3(13.2, 0.25, 9.0), Vector3(0.75, 1.0, 0.75), COL_GRANITO_DARK)

func _add_block_rock(st: SurfaceTool, pos: Vector3, size: Vector3, col: Color) -> void:
	var hx = size.x * 0.5
	var hz = size.z * 0.5
	var y0 = pos.y
	var y1 = pos.y + size.y

	var p00 = pos + Vector3(-hx, 0, -hz)
	var p10 = pos + Vector3(hx, 0, -hz)
	var p01 = pos + Vector3(-hx, 0, hz)
	var p11 = pos + Vector3(hx, 0, hz)

	var t00 = Vector3(p00.x, y1, p00.z)
	var t10 = Vector3(p10.x, y1, p10.z)
	var t01 = Vector3(p01.x, y1, p01.z)
	var t11 = Vector3(p11.x, y1, p11.z)

	var b00 = Vector3(p00.x, y0, p00.z)
	var b10 = Vector3(p10.x, y0, p10.z)
	var b01 = Vector3(p01.x, y0, p01.z)
	var b11 = Vector3(p11.x, y0, p11.z)

	# Face Superior
	st.set_normal(Vector3.UP); st.set_color(col)
	st.add_vertex(t00); st.add_vertex(t10); st.add_vertex(t01)
	st.add_vertex(t10); st.add_vertex(t11); st.add_vertex(t01)

	# Paredes Laterais
	st.set_normal(Vector3.FORWARD); st.set_color(col * 0.85)
	st.add_vertex(b10); st.add_vertex(b00); st.add_vertex(t10)
	st.add_vertex(b00); st.add_vertex(t00); st.add_vertex(t10)

	st.set_normal(Vector3.BACK); st.set_color(col * 0.85)
	st.add_vertex(b01); st.add_vertex(b11); st.add_vertex(t01)
	st.add_vertex(b11); st.add_vertex(t11); st.add_vertex(t01)

	st.set_normal(Vector3.LEFT); st.set_color(col * 0.75)
	st.add_vertex(b00); st.add_vertex(b01); st.add_vertex(t00)
	st.add_vertex(b01); st.add_vertex(t01); st.add_vertex(t00)

	st.set_normal(Vector3.RIGHT); st.set_color(col * 0.75)
	st.add_vertex(b11); st.add_vertex(b10); st.add_vertex(t11)
	st.add_vertex(b10); st.add_vertex(t10); st.add_vertex(t11)

# =========================================================================
# CONSTRUÇÃO DA MALHA DA ÁGUA COM SUBDIVISÃO 2X2 POR TILE (0.5m)
# =========================================================================

func build_water_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var has_water = false
	var sub: int = 2 # Subdivisão 2x2 por metro (passo 0.5m) para mistura contínua suave
	var step_size = 1.0 / float(sub)
	var water_y = 1.00 # Lâmina d'água perfeitamente unificada e calma em Y = 1.00m

	for iz in range(16):
		for ix in range(16):
			if not is_water_cell(ix, iz):
				continue

			has_water = true

			for sy in range(sub):
				for sx in range(sub):
					var x0 = float(ix) + float(sx) * step_size
					var x1 = x0 + step_size
					var z0 = float(iz) + float(sy) * step_size
					var z1 = z0 + step_size

					var wv00 = Vector3(x0, water_y, z0)
					var wv10 = Vector3(x1, water_y, z0)
					var wv01 = Vector3(x0, water_y, z1)
					var wv11 = Vector3(x1, water_y, z1)

					# Avalia atributos de fluxo e blend nos 4 vértices
					var b00 = evaluate_water_blend_at(x0, z0)
					var b10 = evaluate_water_blend_at(x1, z0)
					var b01 = evaluate_water_blend_at(x0, z1)
					var b11 = evaluate_water_blend_at(x1, z1)

					var c00 = Color(b00.flow_dir.x * 0.5 + 0.5, b00.flow_dir.y * 0.5 + 0.5, b00.turbulence, b00.blend_t)
					var c10 = Color(b10.flow_dir.x * 0.5 + 0.5, b10.flow_dir.y * 0.5 + 0.5, b10.turbulence, b10.blend_t)
					var c01 = Color(b01.flow_dir.x * 0.5 + 0.5, b01.flow_dir.y * 0.5 + 0.5, b01.turbulence, b01.blend_t)
					var c11 = Color(b11.flow_dir.x * 0.5 + 0.5, b11.flow_dir.y * 0.5 + 0.5, b11.turbulence, b11.blend_t)

					var normal_up = Vector3.UP

					# Triângulo 1 (CCW)
					st.set_normal(normal_up); st.set_color(c00); st.set_uv(Vector2(x0, z0)); st.set_uv2(b00.uv2); st.add_vertex(wv00)
					st.set_normal(normal_up); st.set_color(c10); st.set_uv(Vector2(x1, z0)); st.set_uv2(b10.uv2); st.add_vertex(wv10)
					st.set_normal(normal_up); st.set_color(c01); st.set_uv(Vector2(x0, z1)); st.set_uv2(b01.uv2); st.add_vertex(wv01)

					# Triângulo 2 (CCW)
					st.set_normal(normal_up); st.set_color(c10); st.set_uv(Vector2(x1, z0)); st.set_uv2(b10.uv2); st.add_vertex(wv10)
					st.set_normal(normal_up); st.set_color(c11); st.set_uv(Vector2(x1, z1)); st.set_uv2(b11.uv2); st.add_vertex(wv11)
					st.set_normal(normal_up); st.set_color(c01); st.set_uv(Vector2(x0, z1)); st.set_uv2(b01.uv2); st.add_vertex(wv01)

	if not has_water:
		return null

	return st.commit()
