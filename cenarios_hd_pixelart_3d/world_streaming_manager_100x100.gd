@tool
class_name WorldStreamingManager100x100
extends Node3D

## WorldStreamingManager100x100 - Gerenciador de Streaming Procedural do Eden Project
## Mundo de 100x100 chunks de 16x16m (1.6 km x 1.6 km: X e Z de -800m a +800m)
## Estética Técnica: HD Pixel Art 3D (David Holland Architecture)
## Suporta streaming dinâmico contínuo com anel ativo em torno da câmera (9x9 = 81 chunks a 60 FPS)

# =========================================================================
# CONSTANTES OBRIGATÓRIAS DE DIMENSÕES
# =========================================================================
const CHUNK_SIZE: float = 16.0
const TOTAL_CHUNKS_X: int = 100 # cx de -50 a 49 (X de -800m a +800m)
const TOTAL_CHUNKS_Z: int = 100 # cz de -50 a 49 (Z de -800m a +800m)

const MIN_CHUNK_X: int = -50
const MAX_CHUNK_X: int = 49
const MIN_CHUNK_Z: int = -50
const MAX_CHUNK_Z: int = 49

const WORLD_MIN_X: float = MIN_CHUNK_X * CHUNK_SIZE # -800.0m
const WORLD_MAX_X: float = (MAX_CHUNK_X + 1) * CHUNK_SIZE # +800.0m
const WORLD_MIN_Z: float = MIN_CHUNK_Z * CHUNK_SIZE # -800.0m
const WORLD_MAX_Z: float = (MAX_CHUNK_Z + 1) * CHUNK_SIZE # +800.0m

# =========================================================================
# PALETA PEDOLÓGICA E ESTRATIGRÁFICA HD PIXEL ART (Canônica do Eden Project)
# =========================================================================
const COL_WHITE_SAND_LIGHT = Color(0.88, 0.86, 0.82) # Areia Branca Luz (#DEDAD2)
const COL_WHITE_SAND_MID   = Color(0.74, 0.71, 0.66) # Areia Branca Meia-Luz (#B8B3A8)
const COL_WHITE_SAND_WET   = Color(0.60, 0.58, 0.53) # Areia molhada do leito
const COL_SERRAPILHEIRA    = Color(0.18, 0.12, 0.09) # Tapete de húmus escuro (#2B1D14)
const COL_LEAF_RED         = Color(0.55, 0.23, 0.17) # Folha tropical vermelha (#8C3B2B)
const COL_LEAF_YELLOW      = Color(0.72, 0.53, 0.18) # Folha ocre seca (#B8862D)
const COL_LEAF_MOSS        = Color(0.24, 0.36, 0.16) # Folha verde musgo (#3E5C2A)
const COL_TERRA_PRETA      = Color(0.13, 0.11, 0.10) # Horizonte A escuro (#1E1916)
const COL_LATERITA_CLAY    = Color(0.56, 0.23, 0.14) # Matriz argilosa avermelhada (#8F3A24)
const COL_LATERITA_NODULE  = Color(0.29, 0.12, 0.09) # Pedrisco piçarra ferroso (#4A1E17)
const COL_GRANITO_LIGHT    = Color(0.44, 0.42, 0.40) # Granito tropical (#6E6A66)
const COL_GRANITO_MID      = Color(0.33, 0.31, 0.30) # Granito face lateral
const COL_GRANITO_DARK     = Color(0.18, 0.20, 0.22) # Basalto profundo (#2E3338)

# Shaders canônicos do projeto
const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")

# =========================================================================
# CONFIGURAÇÕES EXPORTADAS
# =========================================================================
@export_group("Streaming e Câmera")
## Raio de chunks ativos em torno da câmera (4 gera anel de 9x9 = 81 chunks, garantindo 60 FPS leves)
@export var active_radius_chunks: int = 4

## Referência para o nó CameraPivot (rastreamento contínuo da posição no mundo)
@export var target_camera_pivot: NodePath

## Resolução da malha por metro (1.0 = células de 1x1m, 16x16 por chunk)
@export var resolution: float = 1.0

## Cria colisores trimesh físicos em cada chunk ativo
@export var generate_collisions: bool = false

@export_group("Elevação e Relevo")
@export var elevation_scale: float = 6.4
@export var base_noise_freq: float = 0.0065
@export var ridge_noise_freq: float = 0.016
@export var warp_magnitude: float = 12.0
## Snap vertical das colinas e patamares (quantização contínua de 0.25m)
@export var snap_step: float = 0.25

@export_group("Hidrologia")
@export var water_level_campina: float = -0.35
@export var water_level_floresta: float = -0.45
@export var river_amplitude: float = 46.0
@export var river_wavelength: float = 230.0
@export var river_width: float = 10.5
@export var river_depth: float = 2.1
@export var lake_center: Vector2 = Vector2(-280.0, 35.0)
@export var lake_radius: float = 60.0
@export var lake_depth: float = 2.2

@export_group("Shaders e Materiais")
@export var mat_surface: ShaderMaterial = null
@export var mat_water: ShaderMaterial = null

@export_group("Elementos Cênicos")
@export var spawn_boulders: bool = true

# =========================================================================
# ESTADO INTERNO DO GERENCIADOR
# =========================================================================
## Dicionário de chunks ativos: Vector2i(cx, cz) -> Node3D
var active_chunks: Dictionary = {}
var last_cam_chunk: Vector2i = Vector2i(-99999, -99999)

var noise_base: FastNoiseLite
var noise_warp: FastNoiseLite
var noise_detail: FastNoiseLite
var noise_lake: FastNoiseLite

## Cache de materiais de água por faixa de bioma (evita duplicar materiais a cada chunk)
var _water_materials_cache: Dictionary = {}


func _ready() -> void:
	init_noises()
	setup_default_materials()
	init_water_material_cache()
	
	# Inicialização imediata do anel inicial de chunks
	var cam_pos: Vector3 = get_camera_pivot_position()
	var cam_cx: int = int(floor(cam_pos.x / CHUNK_SIZE))
	var cam_cz: int = int(floor(cam_pos.z / CHUNK_SIZE))
	last_cam_chunk = Vector2i(cam_cx, cam_cz)
	update_streaming(cam_cx, cam_cz)


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
	noise_warp.frequency = 0.012

	noise_detail = FastNoiseLite.new()
	noise_detail.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_detail.seed = 981273
	noise_detail.frequency = ridge_noise_freq
	noise_detail.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN

	noise_lake = FastNoiseLite.new()
	noise_lake.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_lake.seed = 714923
	noise_lake.frequency = 0.0055


func setup_default_materials() -> void:
	if not mat_surface:
		mat_surface = ShaderMaterial.new()
		mat_surface.shader = SHADER_SURFACE
		mat_surface.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
		mat_surface.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
		mat_surface.set_shader_parameter("light_bands", 3)
		mat_surface.set_shader_parameter("dither_spread", 0.0)
		mat_surface.set_shader_parameter("use_top_texture", false)

	if not mat_water:
		mat_water = ShaderMaterial.new()
		mat_water.shader = SHADER_WATER
		mat_water.set_shader_parameter("enable_3way_blend", false)
		mat_water.set_shader_parameter("use_voronoi", false)
		mat_water.set_shader_parameter("shallow_color", Color(0.18, 0.72, 0.82, 0.40))
		mat_water.set_shader_parameter("deep_color", Color(0.08, 0.32, 0.52, 0.70))
		mat_water.set_shader_parameter("depth_fade_distance", 1.20)
		mat_water.set_shader_parameter("pixel_grid_density", 64.0)
		mat_water.set_shader_parameter("wave_speed", 2.0)
		mat_water.set_shader_parameter("wave_height", 0.02)
		mat_water.set_shader_parameter("shoreline_foam_dist", 0.30)
		mat_water.set_shader_parameter("shoreline_ripple_rings", 3)
		mat_water.set_shader_parameter("contact_foam_threshold", 0.06)
		mat_water.set_shader_parameter("reflection_strength", 0.35)
		mat_water.set_shader_parameter("reflection_distortion_px", 1.8)
		mat_water.set_shader_parameter("wind_direction", Vector2(0.7071, 0.7071))
		mat_water.set_shader_parameter("wind_speed", 2.0)
		mat_water.set_shader_parameter("wind_strength", 1.0)
		mat_water.set_shader_parameter("refraction_strength", 4.0)
		mat_water.set_shader_parameter("dash_density", 0.55)
		mat_water.set_shader_parameter("dash_cycle_speed", 0.55)
		mat_water.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))


func init_water_material_cache() -> void:
	_water_materials_cache.clear()
	# Cria 5 presets interpolados de material para cobrir todas as transições de bioma
	for i in range(5):
		var b_factor = float(i) / 4.0
		var wm: ShaderMaterial = mat_water.duplicate() as ShaderMaterial
		if b_factor < 0.35:
			# Preset: Água Turquesa Cristalina (Campina)
			wm.set_shader_parameter("shallow_color", Color(0.18, 0.82, 0.78, 0.65))
			wm.set_shader_parameter("deep_color", Color(0.05, 0.38, 0.48, 0.90))
			wm.set_shader_parameter("depth_fade_distance", 1.20)
			wm.set_shader_parameter("reflection_strength", 0.38)
		elif b_factor > 0.65:
			# Preset: Água Preta de Igarapé com Taninos (Floresta Profunda)
			wm.set_shader_parameter("shallow_color", Color(0.38, 0.24, 0.11, 0.75))
			wm.set_shader_parameter("deep_color", Color(0.11, 0.06, 0.04, 0.96))
			wm.set_shader_parameter("depth_fade_distance", 0.55)
			wm.set_shader_parameter("reflection_strength", 0.48)
		else:
			# Transição suave
			var col_s = Color(0.18, 0.82, 0.78, 0.65).lerp(Color(0.38, 0.24, 0.11, 0.75), b_factor)
			var col_d = Color(0.05, 0.38, 0.48, 0.90).lerp(Color(0.11, 0.06, 0.04, 0.96), b_factor)
			wm.set_shader_parameter("shallow_color", col_s)
			wm.set_shader_parameter("deep_color", col_d)
			wm.set_shader_parameter("depth_fade_distance", lerpf(1.20, 0.55, b_factor))
			wm.set_shader_parameter("reflection_strength", lerpf(0.38, 0.48, b_factor))
		_water_materials_cache[i] = wm


func get_water_material_for_biome(b_val: float) -> ShaderMaterial:
	var idx = clampi(int(round(b_val * 4.0)), 0, 4)
	if _water_materials_cache.has(idx):
		return _water_materials_cache[idx]
	return mat_water


# =========================================================================
# LOOP DE STREAMING CONTÍNUO (_process)
# =========================================================================
func _process(_delta: float) -> void:
	if not is_inside_tree():
		return

	var cam_pos: Vector3 = get_camera_pivot_position()
	var cam_cx: int = int(floor(cam_pos.x / CHUNK_SIZE))
	var cam_cz: int = int(floor(cam_pos.z / CHUNK_SIZE))
	var current_cam_chunk: Vector2i = Vector2i(cam_cx, cam_cz)

	# Se a câmera cruzou a borda de um chunk ou active_chunks está vazio, dispara atualização
	if current_cam_chunk != last_cam_chunk or active_chunks.is_empty():
		last_cam_chunk = current_cam_chunk
		update_streaming(cam_cx, cam_cz)


## Obtém a posição mundial da câmera com fallbacks resilientes
func get_camera_pivot_position() -> Vector3:
	if not target_camera_pivot.is_empty():
		var node = get_node_or_null(target_camera_pivot)
		if node is Node3D:
			return (node as Node3D).global_position

	# Fallback 1: Nó irmão nomeado "CameraPivot"
	var parent_node = get_parent()
	if parent_node:
		var sibling_pivot = parent_node.get_node_or_null("CameraPivot")
		if sibling_pivot is Node3D:
			return (sibling_pivot as Node3D).global_position

	# Fallback 2: Câmera 3D ativa da viewport
	var viewport = get_viewport()
	if viewport:
		var cam = viewport.get_camera_3d()
		if cam:
			return cam.global_position

	return global_position


## Executa o descarregamento de chunks distantes e carregamento incremental de novos chunks
func update_streaming(cam_cx: int, cam_cz: int) -> void:
	var needed_coords: Dictionary = {}
	var r: int = active_radius_chunks

	for dx in range(-r, r + 1):
		var cx: int = cam_cx + dx
		if cx < MIN_CHUNK_X or cx > MAX_CHUNK_X:
			continue
		for dz in range(-r, r + 1):
			var cz: int = cam_cz + dz
			if cz < MIN_CHUNK_Z or cz > MAX_CHUNK_Z:
				continue
			needed_coords[Vector2i(cx, cz)] = true

	# 1. Descarrega chunks que ficaram para trás fora do anel ativo
	var to_remove: Array[Vector2i] = []
	for coord in active_chunks.keys():
		if not needed_coords.has(coord):
			to_remove.append(coord)

	for coord in to_remove:
		var chunk_node = active_chunks[coord]
		active_chunks.erase(coord)
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()

	# 2. Carrega novos chunks que entraram no anel ativo
	for coord in needed_coords.keys():
		if not active_chunks.has(coord):
			var chunk_node = create_chunk(coord)
			add_child(chunk_node)
			active_chunks[coord] = chunk_node


# =========================================================================
# FUNÇÕES MATEMÁTICAS ANALÍTICAS GLOBAIS (C0 e C1 Contínuas no Mundo 1.6 km)
# =========================================================================

## Escalar contínuo de Bioma B(x, z) in [0.0, 1.0]: 0.0 = Campina, 1.0 = Floresta Profunda
func evaluate_biome(wx: float, wz: float) -> float:
	var warp_val = noise_warp.get_noise_2d(wx * 0.003, wz * 0.003) * 14.0
	var norm_x = (wx + warp_val + wz * 0.20) / 1000.0
	var raw_b = clampf(norm_x + 0.5, 0.0, 1.0)
	var t = raw_b
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Trajetória do Rio Meândrico: coordenada Z do talvegue atravessando os 1.6 km
func evaluate_river_center_z(wx: float) -> float:
	var k1 = (2.0 * PI) / river_wavelength
	var k2 = k1 * 2.14
	var k3 = k1 * 0.43
	var warp_meander = noise_warp.get_noise_1d(wx * 0.012) * 22.0
	return river_amplitude * sin(wx * k1) + (river_amplitude * 0.35) * sin(wx * k2 + 1.2) + (river_amplitude * 0.48) * sin(wx * k3 - 0.7) + warp_meander


## Campo de Distância Assinada (SDF) para o Rio
func evaluate_river_sdf(wx: float, wz: float) -> float:
	var r_z = evaluate_river_center_z(wx)
	return abs(wz - r_z)


## Nível hidrológico da água em função do bioma
func evaluate_water_level(wx: float, wz: float) -> float:
	var b = evaluate_biome(wx, wz)
	return lerpf(water_level_campina, water_level_floresta, b)


## Relevo e Altitude Bruta contínua antes da quantização
func evaluate_raw_height(wx: float, wz: float) -> float:
	var biome = evaluate_biome(wx, wz)

	# Domain Warping fracionário
	var qx = noise_warp.get_noise_2d(wx, wz) * warp_magnitude
	var qz = noise_warp.get_noise_2d(wx + 73.1, wz + 29.4) * warp_magnitude
	var warpx = wx + qx
	var warpz = wz + qz

	# Elevação Base (fBm Simplex Smooth)
	var elev_base = noise_base.get_noise_2d(warpx, warpz) * elevation_scale

	# Cristas e Matacões (Ridged Multifractal na Floresta)
	var ridge_sample = abs(noise_detail.get_noise_2d(warpx, warpz))
	var ridge_elev = (1.0 - ridge_sample) * (1.0 - ridge_sample) * (3.0 * biome)

	# Terreno composto
	var terrain_h = elev_base * (0.60 + 0.75 * biome) + ridge_elev

	# =========================================================================
	# HIDROLOGIA: ESCAVAÇÃO DO RIO MEÂNDRICO E LAGOS / IGARAPÉS SECUNDÁRIOS
	# =========================================================================
	# 1. Rio Meândrico contínuo (atravessando todo o mapa de -800m a +800m)
	var river_sdf = evaluate_river_sdf(wx, wz)
	var r_width_local = river_width * (0.80 + 0.40 * biome)
	var river_norm = clampf(river_sdf / r_width_local, 0.0, 1.0)
	var river_carve = pow(1.0 - river_norm * river_norm, 2.0)

	# 2. Lago da Campina (Grande bacia elíptica)
	var dist_to_lake = Vector2(wx - lake_center.x, (wz - lake_center.y) * 1.25).length()
	var lake_factor = clampf(1.0 - (dist_to_lake / lake_radius), 0.0, 1.0)
	var lake_campina_carve = lake_factor * lake_factor * (3.0 - 2.0 * lake_factor)

	# 3. Lagoas e Igarapés secundários distribuídos por ruído Perlin
	var lake_sample = noise_lake.get_noise_2d(wx, wz)
	var lake_noise_carve = 0.0
	if lake_sample > 0.36:
		var lk_norm = clampf((lake_sample - 0.36) / 0.32, 0.0, 1.0)
		lake_noise_carve = lk_norm * lk_norm * (3.0 - 2.0 * lk_norm)

	var total_lake_carve = maxf(lake_campina_carve * lake_depth, lake_noise_carve * (river_depth * 0.90))
	var total_carve = maxf(river_carve * river_depth, total_lake_carve)
	terrain_h -= total_carve * 1.5

	# Afunda o leito abaixo do nível d'água
	var w_level = evaluate_water_level(wx, wz)
	if river_carve > 0.03:
		var talvegue_y = w_level - 0.35 - (river_carve * 0.95)
		terrain_h = minf(terrain_h, talvegue_y)
	if total_lake_carve > 0.02:
		var lake_bed_y = w_level - 0.30 - (total_lake_carve * 0.85)
		terrain_h = minf(terrain_h, lake_bed_y)

	return terrain_h


## Quantização Multi-Angular de 0.25m para colinas, patamares e platôs
func quantize_height(raw_y: float) -> float:
	var dh = snap_step
	var step_idx = floor(raw_y / dh)
	var frac = (raw_y / dh) - step_idx
	var s = 0.08
	var ramp = clampf((frac - (0.5 - s)) / (2.0 * s), 0.0, 1.0)
	var s3 = ramp * ramp * (3.0 - 2.0 * ramp)
	return (step_idx + s3) * dh


# =========================================================================
# CONSULTAS PÚBLICAS DE RELEVO E HIDROLOGIA (Para a Biosfera e Agentes)
# =========================================================================

## Retorna a cota de altitude do relevo (ground Y) com snap de 0.25m no mundo
func get_height_at(wx: float, wz: float) -> float:
	return quantize_height(evaluate_raw_height(wx, wz))


## Retorna a cota Y da superfície da água se houver corpo d'água no ponto (wx, wz),
## ou -999.0 se o terreno estiver emerso (seco).
func get_water_at(wx: float, wz: float) -> float:
	var gh = get_height_at(wx, wz)
	var wl = evaluate_water_level(wx, wz)
	if gh < wl:
		return wl
	return -999.0


## Retorna true se houver lâmina d'água na coordenada
func has_water_at(wx: float, wz: float) -> bool:
	return get_water_at(wx, wz) > -500.0


## Retorna a profundidade da lâmina d'água em metros (0.0 se solo seco)
func get_water_depth_at(wx: float, wz: float) -> float:
	var wy = get_water_at(wx, wz)
	if wy > -500.0:
		return maxf(0.0, wy - get_height_at(wx, wz))
	return 0.0


## Retorna a altitude Y de contato (superfície da água se flutuando/nadando, ou solo emerso)
func get_ground_or_water_y(wx: float, wz: float) -> float:
	var wy = get_water_at(wx, wz)
	if wy > -500.0:
		return wy
	return get_height_at(wx, wz)


# =========================================================================
# PIGMENTAÇÃO PEDOLÓGICA E ESTRATIGRAFIA HD PIXEL ART
# =========================================================================

func evaluate_pedology_color(pos: Vector3, normal: Vector3, biome: float) -> Color:
	var is_top = (normal.y > 0.65)
	var is_steep = (normal.y < 0.40)
	var w_level = lerpf(water_level_campina, water_level_floresta, biome)
	var is_submerged = (pos.y < w_level)

	var seed_val = sin(pos.x * 12.9898 + pos.z * 78.233 + pos.y * 37.719) * 43758.5453
	var jitter = 0.95 + 0.10 * fmod(abs(seed_val), 1.0)
	var leaf_hash = fmod(abs(seed_val * 7.5), 1.0)

	var col: Color = Color.WHITE

	if is_submerged:
		var col_bed_campina = COL_WHITE_SAND_WET
		var col_bed_floresta = COL_TERRA_PRETA.lerp(COL_GRANITO_DARK, 0.40)
		col = col_bed_campina.lerp(col_bed_floresta, biome) * jitter

	elif is_top:
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
		if pos.y < -2.2 or (is_steep and biome > 0.65 and leaf_hash < 0.45):
			col = COL_GRANITO_MID if normal.y > 0.1 else COL_GRANITO_DARK
		else:
			if leaf_hash < 0.32:
				col = COL_LATERITA_NODULE
			else:
				col = COL_LATERITA_CLAY
		var col_campina_slope = COL_WHITE_SAND_MID.lerp(COL_LATERITA_CLAY, 0.30)
		col = col_campina_slope.lerp(col, biome) * jitter

	else:
		var col_campina_sub = COL_WHITE_SAND_MID
		var col_floresta_sub = COL_TERRA_PRETA
		col = col_campina_sub.lerp(col_floresta_sub, biome) * jitter

	col.a = 1.0
	return col


# =========================================================================
# CONSTRUÇÃO DE CHUNK (SURFACETOOL COM SHADE FLAT E MALHA DE ÁGUA)
# =========================================================================

func create_chunk(c_coord: Vector2i) -> Node3D:
	var chunk_root = Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [c_coord.x, c_coord.y]
	chunk_root.position = Vector3(c_coord.x * CHUNK_SIZE, 0.0, c_coord.y * CHUNK_SIZE)

	var cells_per_side = int(round(CHUNK_SIZE * resolution))
	var step = CHUNK_SIZE / float(cells_per_side)

	var origin_x = c_coord.x * CHUNK_SIZE
	var origin_z = c_coord.y * CHUNK_SIZE

	# 1. GERAÇÃO DA MALHA DO TERRENO
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

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

			var y00 = get_height_at(wx0, wz0)
			var y10 = get_height_at(wx1, wz0)
			var y01 = get_height_at(wx0, wz1)
			var y11 = get_height_at(wx1, wz1)

			var v00 = Vector3(lx0, y00, lz0)
			var v10 = Vector3(lx1, y10, lz0)
			var v01 = Vector3(lx0, y01, lz1)
			var v11 = Vector3(lx1, y11, lz1)

			# Triângulo 1: v00 -> v10 -> v01
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

			# Triângulo 2: v10 -> v11 -> v01
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

	if generate_collisions:
		terrain_mi.create_trimesh_collision()

	# 2. GERAÇÃO DA MALHA DE ÁGUA DO CHUNK
	var water_st = SurfaceTool.new()
	water_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_water = false

	var water_cells = maxi(1, cells_per_side / 2)
	var water_step = CHUNK_SIZE / float(water_cells)

	for iz in range(water_cells):
		for ix in range(water_cells):
			var lx0 = ix * water_step
			var lx1 = (ix + 1) * water_step
			var lz0 = iz * water_step
			var lz1 = (iz + 1) * water_step

			var wx_center = origin_x + (lx0 + lx1) * 0.5
			var wz_center = origin_z + (lz0 + lz1) * 0.5
			var b_center = evaluate_biome(wx_center, wz_center)

			var w_level = evaluate_water_level(wx_center, wz_center)
			var ground_h = get_height_at(wx_center, wz_center)

			if ground_h < w_level:
				has_water = true
				var wv00 = Vector3(lx0, w_level, lz0)
				var wv10 = Vector3(lx1, w_level, lz0)
				var wv01 = Vector3(lx0, w_level, lz1)
				var wv11 = Vector3(lx1, w_level, lz1)

				var r_center_z = evaluate_river_center_z(wx_center)
				var river_dist = abs(wz_center - r_center_z)
				var is_river = (river_dist < river_width * 1.2)

				var flow_dir = Vector2(1.0, 0.0)
				var turbulence = 0.05
				if is_river:
					var deriv_z = (evaluate_river_center_z(wx_center + 1.0) - evaluate_river_center_z(wx_center - 1.0)) * 0.5
					flow_dir = Vector2(1.0, deriv_z).normalized()
					turbulence = 0.40

				var flow_color = Color(
					flow_dir.x * 0.5 + 0.5,
					flow_dir.y * 0.5 + 0.5,
					turbulence,
					b_center
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

		var chunk_center_x = origin_x + CHUNK_SIZE * 0.5
		var chunk_center_z = origin_z + CHUNK_SIZE * 0.5
		var chunk_biome = evaluate_biome(chunk_center_x, chunk_center_z)

		water_mi.material_override = get_water_material_for_biome(chunk_biome)
		water_mi.layers = 2
		chunk_root.add_child(water_mi)

	# 3. AFLORAMENTOS ROCHOSOS PROCEDURAIS (Matacões Graníticos)
	if spawn_boulders:
		generate_chunk_boulders(chunk_root, c_coord)

	return chunk_root


func generate_chunk_boulders(chunk_root: Node3D, c_coord: Vector2i) -> void:
	var origin_x = c_coord.x * CHUNK_SIZE
	var origin_z = c_coord.y * CHUNK_SIZE
	var chunk_biome = evaluate_biome(origin_x + CHUNK_SIZE * 0.5, origin_z + CHUNK_SIZE * 0.5)

	# Densidade de matacões aumenta em áreas florestais e de transição
	var boulder_count = int(round(chunk_biome * 3.2))
	if boulder_count <= 0:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = c_coord.x * 73856093 ^ c_coord.y * 19349663

	for i in range(boulder_count):
		var rx = rng.randf_range(2.0, CHUNK_SIZE - 2.0)
		var rz = rng.randf_range(2.0, CHUNK_SIZE - 2.0)
		var wx = origin_x + rx
		var wz = origin_z + rz
		var wy = get_height_at(wx, wz)

		var river_dist = evaluate_river_sdf(wx, wz)
		if wy < -0.3 or (river_dist < river_width * 0.6):
			continue

		var b_radius = rng.randf_range(1.3, 2.6)
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

	var lat_segs = 5
	var lon_segs = 7

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
				var n_disp = 1.0 + 0.22 * sin(ph * 3.0 + th * 2.0)
				return sp * (radius * n_disp)

			var p00 = calc_p.call(theta0, phi0)
			var p10 = calc_p.call(theta1, phi0)
			var p01 = calc_p.call(theta0, phi1)
			var p11 = calc_p.call(theta1, phi1)

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
