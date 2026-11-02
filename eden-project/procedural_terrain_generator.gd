@tool
extends Node3D
class_name ProceduralTerrainGenerator

## Gerador Procedural de Terreno Infinito por Chunks
## Estética Técnica: HD Pixel Art 3D (David Holland Architecture)
## Biomas: Campina com Lago Turquesa -> Transição -> Floresta Profunda com Igarapé e Matacões

@export_group("Dimensões do Mundo")
## Tamanho horizontal de cada chunk em metros
@export var chunk_size: float = 16.0
## Resolução por metro (número de células por metro). 1.0 = células de 1x1m, 2.0 = células de 0.5m
@export var resolution: float = 2.0
## Coordenadas mínimas e máximas de chunks a gerar no teste (em chunks)
@export var chunk_range_x: Vector2i = Vector2i(-3, 3) # 7 chunks em X (-48m a +48m = 96m)
@export var chunk_range_z: Vector2i = Vector2i(-2, 2) # 5 chunks em Z (-32m a +32m = 64m)

@export_group("Elevação e Relevo")
@export var elevation_scale: float = 5.2
@export var base_noise_freq: float = 0.016
@export var ridge_noise_freq: float = 0.038
@export var warp_magnitude: float = 7.5
@export var snap_step: float = 0.25 # Quantização multi-angular 0.25m

@export_group("Hidrologia")
@export var water_level_campina: float = -0.35
@export var water_level_floresta: float = -0.45
@export var river_amplitude: float = 13.0
@export var river_wavelength: float = 85.0
@export var river_width: float = 6.2
@export var river_depth: float = 1.6
@export var lake_center: Vector2 = Vector2(-28.0, -1.0)
@export var lake_radius: float = 15.0
@export var lake_depth: float = 1.7

@export_group("Shaders e Materiais")
@export var mat_surface: ShaderMaterial = null
@export var mat_water: ShaderMaterial = null

var noise_base: FastNoiseLite
var noise_warp: FastNoiseLite
var noise_detail: FastNoiseLite

# Dicionário de chunks ativos: Vector2i -> Node3D
var active_chunks: Dictionary = {}

func _ready() -> void:
	init_noises()
	setup_default_materials()
	generate_world()

func init_noises() -> void:
	noise_base = FastNoiseLite.new()
	noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_base.seed = 104729
	noise_base.frequency = base_noise_freq
	noise_base.fractal_octaves = 4
	noise_base.fractal_gain = 0.5
	noise_base.fractal_lacunarity = 2.0

	noise_warp = FastNoiseLite.new()
	noise_warp.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_warp.seed = 239841
	noise_warp.frequency = 0.025

	noise_detail = FastNoiseLite.new()
	noise_detail.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_detail.seed = 981273
	noise_detail.frequency = ridge_noise_freq
	noise_detail.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN

func setup_default_materials() -> void:
	if not mat_surface:
		var shader_surf = load("res://pixel_surface.gdshader") as Shader
		if shader_surf:
			mat_surface = ShaderMaterial.new()
			mat_surface.shader = shader_surf
			mat_surface.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
			mat_surface.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
			mat_surface.set_shader_parameter("light_bands", 3)
			mat_surface.set_shader_parameter("dither_spread", 0.0)
			mat_surface.set_shader_parameter("use_top_texture", false)

	if not mat_water:
		var shader_wat = load("res://pixel_water.gdshader") as Shader
		if shader_wat:
			mat_water = ShaderMaterial.new()
			mat_water.shader = shader_wat
			mat_water.set_shader_parameter("pixel_grid_density", 52.0)
			mat_water.set_shader_parameter("wave_speed", 1.8)
			mat_water.set_shader_parameter("wave_height", 0.02)
			mat_water.set_shader_parameter("reflection_strength", 0.42)
			mat_water.set_shader_parameter("shallow_color", Color(0.18, 0.82, 0.78, 0.65))
			mat_water.set_shader_parameter("deep_color", Color(0.05, 0.38, 0.48, 0.90))
			mat_water.set_shader_parameter("depth_fade_distance", 1.10)
			mat_water.set_shader_parameter("shoreline_foam_dist", 0.26)

func generate_world() -> void:
	for child in get_children():
		child.queue_free()
	active_chunks.clear()

	for cx in range(chunk_range_x.x, chunk_range_x.y + 1):
		for cz in range(chunk_range_z.x, chunk_range_z.y + 1):
			var c_coord = Vector2i(cx, cz)
			var chunk_node = create_chunk(c_coord)
			add_child(chunk_node)
			active_chunks[c_coord] = chunk_node

# =========================================================================
# FUNÇÕES MATEMÁTICAS ANALÍTICAS GLOBAIS (C0 e C1 Contínuas)
# =========================================================================

## Escalar de Bioma B(x, z) in [0.0, 1.0]: 0.0 = Campina, 1.0 = Floresta Profunda
func evaluate_biome(wx: float, wz: float) -> float:
	# Transição contínua entre X = -16m (Campina pura) e X = +16m (Floresta Profunda pura)
	var warp_val = noise_warp.get_noise_2d(wx * 0.4, wz * 0.4) * 6.5
	var norm_x = (wx + warp_val) / 32.0 # -16m -> -0.5, +16m -> +0.5
	var raw_b = clamp(norm_x + 0.5, 0.0, 1.0)
	# Quintic smoothstep S5(t) = 6t^5 - 15t^4 + 10t^3
	var t = raw_b
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

## Trajetória do Rio Meândrico: coordenada Z do talvegue
func evaluate_river_center_z(wx: float) -> float:
	var k1 = (2.0 * PI) / river_wavelength
	var k2 = k1 * 2.0
	return river_amplitude * sin(wx * k1) + (river_amplitude * 0.32) * sin(wx * k2 + 1.2)

## Campo de Distância Assinada (SDF) para o Rio
func evaluate_river_sdf(wx: float, wz: float) -> float:
	var r_z = evaluate_river_center_z(wx)
	return abs(wz - r_z)

## Relevo e Altitude Bruta
func evaluate_raw_height(wx: float, wz: float) -> float:
	var biome = evaluate_biome(wx, wz)
	
	# Domain Warping fracionário
	var qx = noise_warp.get_noise_2d(wx, wz) * warp_magnitude
	var qz = noise_warp.get_noise_2d(wx + 52.1, wz + 13.7) * warp_magnitude
	var warpx = wx + qx
	var warpz = wz + qz

	# Elevação Base (fBm)
	var elev_base = noise_base.get_noise_2d(warpx, warpz) * elevation_scale
	
	# Cristas e Matacões (Ridged Multifractal na Floresta)
	var ridge_sample = abs(noise_detail.get_noise_2d(warpx, warpz))
	var ridge_elev = (1.0 - ridge_sample) * (1.0 - ridge_sample) * (2.8 * biome)
	
	# Campina: relevo mais suave/plano com colinas ralas; Floresta: relevo com cristas e vales
	var terrain_h = elev_base * (0.55 + 0.85 * biome) + ridge_elev

	# =====================================================================
	# HIDROLOGIA: ESCAVAÇÃO DE LAGO (CAMPINA) E RIO MEÂNDRICO (FLORESTA)
	# =====================================================================
	# 1. Lago da Campina (Bacia Suave Elíptica na região X < -12)
	var dist_to_lake = Vector2(wx - lake_center.x, (wz - lake_center.y) * 1.25).length()
	var lake_factor = clamp(1.0 - (dist_to_lake / lake_radius), 0.0, 1.0)
	var lake_carve = lake_factor * lake_factor * (3.0 - 2.0 * lake_factor) # smoothstep
	var lake_mask = (1.0 - biome) * lake_carve

	# 2. Rio Meândrico (Desenvolve-se a partir da Campina em direção à Floresta)
	var river_sdf = evaluate_river_sdf(wx, wz)
	var r_width_local = river_width * (0.75 + 0.45 * biome)
	var river_norm = clamp(river_sdf / r_width_local, 0.0, 1.0)
	var river_carve = pow(1.0 - river_norm * river_norm, 2.0)
	var river_presence = clamp((wx + 12.0) / 28.0, 0.15, 1.0)
	var river_mask = river_carve * river_presence

	# Escavação combinada
	var total_carve = max(lake_mask * lake_depth, river_mask * river_depth)
	terrain_h -= total_carve * 1.5

	# Afunda o leito abaixo do nível d'água
	if lake_mask > 0.01:
		terrain_h = min(terrain_h, water_level_campina - 0.25 - (lake_mask * 0.95))
	if river_mask > 0.04:
		var talvegue_y = water_level_floresta - 0.30 - (river_mask * 0.90)
		terrain_h = min(terrain_h, talvegue_y)

	return terrain_h

## Quantização Multi-Angular 0.25m (Continuous Stepped Elevation)
func quantize_height(raw_y: float) -> float:
	var dh = snap_step
	var step_idx = floor(raw_y / dh)
	var frac = (raw_y / dh) - step_idx
	var s = 0.08
	var ramp = clamp((frac - (0.5 - s)) / (2.0 * s), 0.0, 1.0)
	var s3 = ramp * ramp * (3.0 - 2.0 * ramp)
	return (step_idx + s3) * dh

func get_height(wx: float, wz: float) -> float:
	return quantize_height(evaluate_raw_height(wx, wz))

# =========================================================================
# PIGMENTAÇÃO PEDOLÓGICA E ESTRATIGRAFIA HD PIXEL ART (ALBEDOCOL RGB)
# =========================================================================
const COL_WHITE_SAND_LIGHT = Color(0.88, 0.86, 0.82) # #DEDAD2 Areia Branca Luz
const COL_WHITE_SAND_MID   = Color(0.74, 0.71, 0.66) # #B8B3A8 Areia Branca Meia-Luz
const COL_WHITE_SAND_WET   = Color(0.60, 0.58, 0.53) # Areia molhada do leito
const COL_SERRAPILHEIRA    = Color(0.18, 0.12, 0.09) # #2B1D14 Tapete de húmus escuro
const COL_LEAF_RED         = Color(0.55, 0.23, 0.17) # #8C3B2B Folha tropical vermelha
const COL_LEAF_YELLOW      = Color(0.72, 0.53, 0.18) # #B8862D Folha ocre seca
const COL_LEAF_MOSS        = Color(0.24, 0.36, 0.16) # #3E5C2A Folha verde musgo
const COL_TERRA_PRETA      = Color(0.13, 0.11, 0.10) # #1E1916 Horizonte A escuro
const COL_LATERITA_CLAY    = Color(0.56, 0.23, 0.14) # #8F3A24 Matriz argilosa avermelhada
const COL_LATERITA_NODULE  = Color(0.29, 0.12, 0.09) # #4A1E17 Pedrisco piçarra ferroso
const COL_GRANITO_LIGHT    = Color(0.44, 0.42, 0.40) # #6E6A66 Granito tropical
const COL_GRANITO_MID      = Color(0.33, 0.31, 0.30) # Granito face lateral
const COL_GRANITO_DARK     = Color(0.18, 0.20, 0.22) # #2E3338 Basalto profundo

func evaluate_pedology_color(pos: Vector3, normal: Vector3, biome: float) -> Color:
	var is_top = (normal.y > 0.65)
	var is_steep = (normal.y < 0.40)
	var is_submerged = (pos.y < (water_level_campina if biome < 0.5 else water_level_floresta))
	
	var seed_val = sin(pos.x * 12.9898 + pos.z * 78.233 + pos.y * 37.719) * 43758.5453
	var jitter = 0.95 + 0.10 * fmod(abs(seed_val), 1.0)
	var leaf_hash = fmod(abs(seed_val * 7.5), 1.0)

	var col: Color = Color.WHITE

	if is_submerged:
		# Leito subaquático: areia branca lavada na campina vs lodo e seixos escuros na floresta
		var col_bed_campina = COL_WHITE_SAND_WET
		var col_bed_floresta = COL_TERRA_PRETA.lerp(COL_GRANITO_DARK, 0.40)
		col = col_bed_campina.lerp(col_bed_floresta, biome) * jitter

	elif is_top:
		# Topo do Terreno:
		# Campina = Areia Branca de Quartzo (Espodossolo de Campinarana)
		# Floresta = Serrapilheira orgânica densa com folhas coloridas caídas
		var col_campina = COL_WHITE_SAND_LIGHT if normal.y > 0.82 else COL_WHITE_SAND_MID
		
		var col_floresta: Color
		if leaf_hash < 0.24:
			col_floresta = COL_LEAF_RED
		elif leaf_hash < 0.46:
			col_floresta = COL_LEAF_YELLOW
		elif leaf_hash < 0.62:
			col_floresta = COL_LEAF_MOSS
		else:
			col_floresta = COL_SERRAPILHEIRA
			
		col = col_campina.lerp(col_floresta, biome) * jitter

	elif is_steep or pos.y < -1.6:
		# Encostas Íngremes, Paredões e Cotas Profundas:
		if pos.y < -2.2 or (is_steep and biome > 0.65 and leaf_hash < 0.45):
			# Matacão de granito / basalto exposto na clivagem
			col = COL_GRANITO_MID if normal.y > 0.1 else COL_GRANITO_DARK
		else:
			# Paredão de Latossolo Vermelho / Piçarra com seixos ferrosos salientes
			if leaf_hash < 0.32:
				col = COL_LATERITA_NODULE # Nódulo de hematita
			else:
				col = COL_LATERITA_CLAY   # Barro vermelho plíntico
				
		var col_campina_slope = COL_WHITE_SAND_MID.lerp(COL_LATERITA_CLAY, 0.30)
		col = col_campina_slope.lerp(col, biome) * jitter

	else:
		# Encosta Média (0.40 <= normal.y <= 0.65):
		var col_campina_sub = COL_WHITE_SAND_MID
		var col_floresta_sub = COL_TERRA_PRETA
		col = col_campina_sub.lerp(col_floresta_sub, biome) * jitter

	col.a = 1.0
	return col

# =========================================================================
# CONSTRUÇÃO DE CHUNK (MESHBUILDER VIA SURFACETOOL COM SHADE FLAT)
# =========================================================================

func create_chunk(c_coord: Vector2i) -> Node3D:
	var chunk_root = Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [c_coord.x, c_coord.y]
	chunk_root.position = Vector3(c_coord.x * chunk_size, 0.0, c_coord.y * chunk_size)

	var cells_per_side = int(round(chunk_size * resolution))
	var step = chunk_size / float(cells_per_side)

	# 1. GERAÇÃO DA MALHA DO TERRENO (Shade Flat com Winding Order Correto e Normais Upward)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin_x = c_coord.x * chunk_size
	var origin_z = c_coord.y * chunk_size

	for iz in range(cells_per_side):
		for ix in range(cells_per_side):
			var lx0 = ix * step
			var lx1 = (ix + 1) * step
			var lz0 = iz * step
			var lz1 = (iz + 1) * step

			var wx0 = origin_x + lx0
			var wx1 = origin_x + lx1
			var wz0 = origin_z + lz0
			var wz1 = origin_z + lz1

			var y00 = get_height(wx0, wz0)
			var y10 = get_height(wx1, wz0)
			var y01 = get_height(wx0, wz1)
			var y11 = get_height(wx1, wz1)

			var v00 = Vector3(lx0, y00, lz0)
			var v10 = Vector3(lx1, y10, lz0)
			var v01 = Vector3(lx0, y01, lz1)
			var v11 = Vector3(lx1, y11, lz1)

			# Triângulo 1 (CCW): v00 -> v10 -> v01
			var n1 = (v01 - v00).cross(v10 - v00).normalized()
			var b1 = evaluate_biome(origin_x + (lx0 + lx1) * 0.5, origin_z + (lz0 + lz1) * 0.5)
			var c1 = evaluate_pedology_color((v00 + v10 + v01) / 3.0 + chunk_root.position, n1, b1)

			st.set_normal(n1)
			st.set_color(c1)
			st.set_uv(Vector2(lx0, lz0))
			st.add_vertex(v00)

			st.set_normal(n1)
			st.set_color(c1)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(n1)
			st.set_color(c1)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

			# Triângulo 2 (CCW): v10 -> v11 -> v01
			var n2 = (v01 - v10).cross(v11 - v10).normalized()
			var b2 = evaluate_biome(origin_x + (lx0 + lx1) * 0.5, origin_z + (lz0 + lz1) * 0.5)
			var c2 = evaluate_pedology_color((v10 + v11 + v01) / 3.0 + chunk_root.position, n2, b2)

			st.set_normal(n2)
			st.set_color(c2)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(n2)
			st.set_color(c2)
			st.set_uv(Vector2(lx1, lz1))
			st.add_vertex(v11)

			st.set_normal(n2)
			st.set_color(c2)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

	var terrain_mesh = st.commit()
	var terrain_mi = MeshInstance3D.new()
	terrain_mi.name = "Terrain_Mesh"
	terrain_mi.mesh = terrain_mesh
	terrain_mi.material_override = mat_surface
	terrain_mi.layers = 1
	chunk_root.add_child(terrain_mi)

	# 2. GERAÇÃO DA MALHA DE ÁGUA DO CHUNK
	var water_st = SurfaceTool.new()
	water_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_water = false

	var water_cells = cells_per_side / 2
	var water_step = chunk_size / float(water_cells)

	for iz in range(water_cells):
		for ix in range(water_cells):
			var lx0 = ix * water_step
			var lx1 = (ix + 1) * water_step
			var lz0 = iz * water_step
			var lz1 = (iz + 1) * water_step

			var wx_center = origin_x + (lx0 + lx1) * 0.5
			var wz_center = origin_z + (lz0 + lz1) * 0.5
			var b_center = evaluate_biome(wx_center, wz_center)

			var w_level = lerpf(water_level_campina, water_level_floresta, b_center)
			var ground_h = get_height(wx_center, wz_center)

			if ground_h < w_level:
				has_water = true
				var wv00 = Vector3(lx0, w_level, lz0)
				var wv10 = Vector3(lx1, w_level, lz0)
				var wv01 = Vector3(lx0, w_level, lz1)
				var wv11 = Vector3(lx1, w_level, lz1)

				var r_center_z = evaluate_river_center_z(wx_center)
				var river_dist = abs(wz_center - r_center_z)
				var is_river = (river_dist < river_width * 1.2 and wx_center > -10.0)

				var flow_dir = Vector2(1.0, 0.0)
				var turbulence = 0.05
				if is_river:
					var deriv_z = (evaluate_river_center_z(wx_center + 1.0) - evaluate_river_center_z(wx_center - 1.0)) * 0.5
					flow_dir = Vector2(1.0, deriv_z).normalized()
					turbulence = 0.45

				var flow_color = Color(
					flow_dir.x * 0.5 + 0.5,
					flow_dir.y * 0.5 + 0.5,
					turbulence,
					b_center # Canal Alpha transmite o bioma para interpolação contínua no shader
				)

				var wn = Vector3.UP

				# Triângulo 1: wv00 -> wv01 -> wv10
				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx0, lz0))
				water_st.add_vertex(wv00)

				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx0, lz1))
				water_st.add_vertex(wv01)

				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx1, lz0))
				water_st.add_vertex(wv10)

				# Triângulo 2: wv10 -> wv01 -> wv11
				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx1, lz0))
				water_st.add_vertex(wv10)

				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx0, lz1))
				water_st.add_vertex(wv01)

				water_st.set_normal(wn)
				water_st.set_color(flow_color)
				water_st.set_uv(Vector2(lx1, lz1))
				water_st.add_vertex(wv11)

	if has_water:
		var water_mesh = water_st.commit()
		var water_mi = MeshInstance3D.new()
		water_mi.name = "Water_Surface"
		water_mi.mesh = water_mesh
		
		var chunk_center_x = origin_x + chunk_size * 0.5
		var chunk_center_z = origin_z + chunk_size * 0.5
		var chunk_biome = evaluate_biome(chunk_center_x, chunk_center_z)
		
		var chunk_water_mat = mat_water.duplicate() as ShaderMaterial
		if chunk_biome < 0.35:
			# Preset 3: Água Turquesa Cristalina de Lago de Campina
			chunk_water_mat.set_shader_parameter("shallow_color", Color(0.18, 0.82, 0.78, 0.65))
			chunk_water_mat.set_shader_parameter("deep_color", Color(0.05, 0.38, 0.48, 0.90))
			chunk_water_mat.set_shader_parameter("depth_fade_distance", 1.20)
			chunk_water_mat.set_shader_parameter("reflection_strength", 0.38)
		elif chunk_biome > 0.65:
			# Preset 1: Água Preta de Igarapé da Floresta
			chunk_water_mat.set_shader_parameter("shallow_color", Color(0.38, 0.24, 0.11, 0.75))
			chunk_water_mat.set_shader_parameter("deep_color", Color(0.11, 0.06, 0.04, 0.96))
			chunk_water_mat.set_shader_parameter("depth_fade_distance", 0.55)
			chunk_water_mat.set_shader_parameter("reflection_strength", 0.48)
		else:
			# Transição suave
			var col_s = Color(0.18, 0.82, 0.78, 0.65).lerp(Color(0.38, 0.24, 0.11, 0.75), chunk_biome)
			var col_d = Color(0.05, 0.38, 0.48, 0.90).lerp(Color(0.11, 0.06, 0.04, 0.96), chunk_biome)
			chunk_water_mat.set_shader_parameter("shallow_color", col_s)
			chunk_water_mat.set_shader_parameter("deep_color", col_d)
			chunk_water_mat.set_shader_parameter("depth_fade_distance", lerpf(1.20, 0.55, chunk_biome))
			chunk_water_mat.set_shader_parameter("reflection_strength", lerpf(0.38, 0.48, chunk_biome))

		water_mi.material_override = chunk_water_mat
		water_mi.layers = 2
		chunk_root.add_child(water_mi)

	# 3. AFLORAMENTOS ROCHOSOS PROCEDURAIS (Matacões Graníticos Facetados de 2m a 4m)
	generate_chunk_boulders(chunk_root, c_coord)

	return chunk_root

func generate_chunk_boulders(chunk_root: Node3D, c_coord: Vector2i) -> void:
	var origin_x = c_coord.x * chunk_size
	var origin_z = c_coord.y * chunk_size
	var chunk_biome = evaluate_biome(origin_x + chunk_size * 0.5, origin_z + chunk_size * 0.5)

	# Densidade de matacões aumenta na floresta e em transições rochosas
	var boulder_count = int(round(chunk_biome * 3.5))
	if boulder_count <= 0:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = c_coord.x * 73856093 ^ c_coord.y * 19349663

	for i in range(boulder_count):
		var rx = rng.randf_range(2.0, chunk_size - 2.0)
		var rz = rng.randf_range(2.0, chunk_size - 2.0)
		var wx = origin_x + rx
		var wz = origin_z + rz
		var wy = get_height(wx, wz)

		var river_dist = evaluate_river_sdf(wx, wz)
		if wy < -0.3 or (river_dist < river_width * 0.6 and wx > -10.0):
			continue

		var b_radius = rng.randf_range(1.4, 2.8)
		var boulder_mi = create_procedural_boulder_mesh(b_radius, rng.randi())
		boulder_mi.name = "Boulder_%d" % i
		boulder_mi.position = Vector3(rx, wy - b_radius * 0.25, rz)
		boulder_mi.rotation.y = rng.randf_range(0.0, TAU)
		boulder_mi.material_override = mat_surface
		boulder_mi.layers = 1
		chunk_root.add_child(boulder_mi)

func create_procedural_boulder_mesh(radius: float, seed_val: int) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var lat_segs = 6
	var lon_segs = 8

	for lat in range(lat_segs):
		var theta0 = float(lat) / float(lat_segs) * PI
		var theta1 = float(lat + 1) / float(lat_segs) * PI

		for lon in range(lon_segs):
			var phi0 = float(lon) / float(lon_segs) * TAU
			var phi1 = float(lon + 1) / float(lon_segs) * TAU

			var calc_p = func(th: float, ph: float) -> Vector3:
				var sp = Vector3(
					sin(th) * cos(ph),
					cos(th) * 0.75,
					sin(th) * sin(ph)
				)
				var n_disp = 1.0 + 0.25 * sin(ph * 3.0 + th * 2.0)
				return sp * (radius * n_disp)

			var p00 = calc_p.call(theta0, phi0)
			var p10 = calc_p.call(theta1, phi0)
			var p01 = calc_p.call(theta0, phi1)
			var p11 = calc_p.call(theta1, phi1)

			# Triângulo 1
			var n1 = (p01 - p00).cross(p10 - p00).normalized()
			var c1 = COL_GRANITO_LIGHT.lerp(COL_GRANITO_MID, rng.randf_range(0.2, 0.8))
			if n1.y < -0.1:
				c1 = COL_GRANITO_DARK

			st.set_normal(n1)
			st.set_color(c1)
			st.add_vertex(p00)
			st.set_normal(n1)
			st.set_color(c1)
			st.add_vertex(p01)
			st.set_normal(n1)
			st.set_color(c1)
			st.add_vertex(p10)

			# Triângulo 2
			var n2 = (p01 - p10).cross(p11 - p10).normalized()
			var c2 = COL_GRANITO_LIGHT.lerp(COL_GRANITO_MID, rng.randf_range(0.2, 0.8))
			if n2.y < -0.1:
				c2 = COL_GRANITO_DARK

			st.set_normal(n2)
			st.set_color(c2)
			st.add_vertex(p10)
			st.set_normal(n2)
			st.set_color(c2)
			st.add_vertex(p01)
			st.set_normal(n2)
			st.set_color(c2)
			st.add_vertex(p11)

	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi
