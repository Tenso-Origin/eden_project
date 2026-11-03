@tool
extends Node3D
class_name MundoProceduralFinalGeometry

## Gerador Procedural do Mundo Final (64x128m, Grade 1x1x1m, 32 Chunks de 16x16m)
## Topografia Oficial:
## - Norte (Z < -24m): Platô 16m com Floresta Tropical e Lago de Água Chá-Mate (Taninos/Igarapé)
## - Meio (Z in [-24m, +16m]): Desfiladeiro de Granito com Cascatas Verticais e Lagos em Vales Altos
## - Sul (Z > +16m): Campina Grande com Grande Lago de Águas Claras e Praias de Areia Quartzo
## Sem árvores (geologia, pedologia e hidrologia puras). Shaders HD Pixel Art 3D integrados.

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const TEX_SERRAPILHEIRA = preload("res://tex_serrapilheira.png")

const SNAP_V: float = 0.25 # Snap vertical estrito de 0.25m
const SNAP_H: float = 1.00 # Snap horizontal estrito de 1.00m

# Dimensões globais do mundo: 64m (X) x 128m (Z) = 32 chunks de 16x16m
const CHUNKS_X: int = 4 # cx in [-2, -1, 0, 1] -> X in [-32m, +32m]
const CHUNKS_Z: int = 8 # cz in [-4, -3, -2, -1, 0, 1, 2, 3] -> Z in [-64m, +64m]
const CHUNK_SIZE: int = 16

# =========================================================================
# PALETA GEOLÓGICA E PEDOLÓGICA OFICIAL (Kit de Biomas Tropicais HD Pixel Art)
# =========================================================================

# 1. Areia Quartzo (Espodossolo Quartzarênico Puro - Sul)
const COL_AREIA_LUZ    = Color(0.87, 0.85, 0.82) # Areia Branca iluminada (#DEDAD2)
const COL_AREIA_MID    = Color(0.72, 0.70, 0.66) # Areia Branca meia-luz (#B8B3A8)
const COL_AREIA_WET    = Color(0.55, 0.53, 0.49) # Areia úmida sob água clara (#8C877E)

# 2. Campina Grande (Gramíneas e Savana Aberta - Sul)
const COL_CAMPINA_LUZ  = Color(0.42, 0.58, 0.24) # Grama viva iluminada
const COL_CAMPINA_MID  = Color(0.35, 0.49, 0.20) # Grama verde média
const COL_CAMPINA_DRY  = Color(0.52, 0.55, 0.28) # Grama seca / borda de areia

# 3. Floresta Tropical (Húmus e Solos Orgânicos - Norte)
const COL_SERRA_BASE   = Color(0.17, 0.11, 0.08) # Chão orgânico base (#2B1D14)
const COL_SERRA_SECA   = Color(0.55, 0.23, 0.17) # Folhas secas avermelhadas (#8C3B2B)
const COL_SERRA_MUSGO  = Color(0.24, 0.36, 0.16) # Folhagem verde / musgo (#3E5C2A)
const COL_TERRA_TOPO   = Color(0.12, 0.10, 0.09) # Húmus superficial rico / Terra Preta (#1E1916)
const COL_TERRA_MID    = Color(0.16, 0.13, 0.12) # Camada média bioturbada (#29221E)

# 4. Latossolo Plíntico (Horizonte B / Laterita / Piçarra - Cortes Verticais)
const COL_LATO_MATRIZ  = Color(0.58, 0.24, 0.14) # Argila lixiviada avermelhada (#8F3A24)
const COL_LATO_CLARO   = Color(0.66, 0.27, 0.17) # Argila vermelha clara (#A8462B)
const COL_LATO_PICARRA = Color(0.29, 0.12, 0.09) # Nódulo de hematita (#4A1E17)

# 5. Granito / Basalto (Rocha Matriz do Desfiladeiro e Paredões)
const COL_GRAN_CLARO   = Color(0.43, 0.42, 0.40) # Granito cinza intemperizado (#6E6A66)
const COL_GRAN_ROSADO  = Color(0.52, 0.47, 0.44) # Feldspato rosado (#857870)
const COL_GRAN_VEIO    = Color(0.29, 0.28, 0.27) # Veios de quartzo/mica (#4A4745)
const COL_GRAN_ESCURO  = Color(0.18, 0.20, 0.22) # Basalto / Saprolito profundo (#2E3338)

var mat_surface: ShaderMaterial
var mat_water: ShaderMaterial

var noise_base: FastNoiseLite
var noise_warp: FastNoiseLite

func _ready() -> void:
	init_materials()
	init_noises()
	generate_world()

func init_materials() -> void:
	mat_surface = ShaderMaterial.new()
	mat_surface.shader = SHADER_SURFACE
	mat_surface.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
	mat_surface.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
	mat_surface.set_shader_parameter("light_bands", 3)
	mat_surface.set_shader_parameter("dither_spread", 0.0)
	mat_surface.set_shader_parameter("use_top_texture", true)
	mat_surface.set_shader_parameter("use_vertex_alpha_for_texture", true)
	mat_surface.set_shader_parameter("top_albedo_texture", TEX_SERRAPILHEIRA)
	mat_surface.set_shader_parameter("top_texture_scale", 0.35)

	mat_water = ShaderMaterial.new()
	mat_water.shader = SHADER_WATER
	mat_water.set_shader_parameter("enable_3way_blend", true)
	mat_water.set_shader_parameter("pixel_grid_density", 52.0)
	mat_water.set_shader_parameter("wave_speed", 1.8)
	mat_water.set_shader_parameter("wave_height", 0.02)
	mat_water.set_shader_parameter("voronoi_frequency", 1.35)
	mat_water.set_shader_parameter("wave_crest_foam_threshold", 0.94)
	mat_water.set_shader_parameter("reflection_strength", 0.45)
	mat_water.set_shader_parameter("shoreline_foam_dist", 0.30)
	mat_water.set_shader_parameter("shoreline_ripple_rings", 3)
	mat_water.set_shader_parameter("foam_color", Color(0.96, 0.98, 1.0))

	# Cores oficiais calibradas: Turquesa no Sul, Igarapé/Chá-Mate no Norte
	mat_water.set_shader_parameter("turquesa_shallow", Color(0.18, 0.82, 0.78, 0.50))
	mat_water.set_shader_parameter("turquesa_deep", Color(0.05, 0.38, 0.48, 0.90))
	mat_water.set_shader_parameter("turquesa_fade", 1.20)

	mat_water.set_shader_parameter("barrenta_shallow", Color(0.62, 0.47, 0.31, 0.85))
	mat_water.set_shader_parameter("barrenta_deep", Color(0.38, 0.26, 0.16, 0.98))
	mat_water.set_shader_parameter("barrenta_fade", 0.22)

	mat_water.set_shader_parameter("igarape_shallow", Color(0.38, 0.24, 0.11, 0.60))
	mat_water.set_shader_parameter("igarape_deep", Color(0.11, 0.06, 0.04, 0.96))
	mat_water.set_shader_parameter("igarape_fade", 0.55)

func init_noises() -> void:
	noise_base = FastNoiseLite.new()
	noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_base.seed = 104729
	noise_base.frequency = 0.025
	noise_base.fractal_octaves = 3

	noise_warp = FastNoiseLite.new()
	noise_warp.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_warp.seed = 239841
	noise_warp.frequency = 0.035

# =========================================================================
# 1. MODELO MATEMÁTICO DE HIDROLOGIA E BIOMAS
# =========================================================================

## Trajetória central do desfiladeiro e curso de água no plano (X, Z)
func get_canyon_center_x(wz: float) -> float:
	return 2.5 * sin(wz * 0.075) + 1.2 * cos(wz * 0.15)

## Pluma anisotrópica de amortecimento de turbulência gerada pelas cascatas em Z in {-26, -14, -1}
func get_waterfall_plume_turbulence(x: float, z: float, base_turb: float = 0.08) -> float:
	var cascades = [
		{"z": -26.0, "w_half": 2.8},
		{"z": -14.0, "w_half": 2.8},
		{"z": -1.0,  "w_half": 3.2}
	]
	var max_t = base_turb
	for c in cascades:
		var z_k: float = c.z
		var w_half: float = c.w_half
		var x_k: float = get_canyon_center_x(z_k)
		var dz: float = z - z_k
		var dx: float = abs(x - x_k)
		var dx_eff: float = max(0.0, dx - w_half)
		
		var u: float = 0.0
		if dz < 0.0:
			u = sqrt(pow(-dz / 0.4, 2.0) + pow(dx_eff / 1.2, 2.0))
		else:
			u = sqrt(pow(dz / 4.5, 2.0) + pow(dx_eff / 2.0, 2.0))
			
		if u < 1.0:
			var f_plume: float = (1.0 - u) * (1.0 - u) * (1.0 + 1.2 * u)
			var t_k: float = 0.08 + 0.87 * f_plume
			if t_k > max_t:
				max_t = t_k
	return max_t

## Avalia a célula de água no ponto inteiro (wx, wz)
func evaluate_water_cell(wx: int, wz: int) -> Dictionary:
	var f_wx = float(wx)
	var f_wz = float(wz)
	var c_center_x = get_canyon_center_x(f_wz)
	var dist_canyon = abs(f_wx + 0.5 - c_center_x)

	var data = {
		"has_water": false,
		"is_waterfall": false,
		"water_y": 0.0,
		"waterfall_base_y": 0.0,
		"water_corners": [0.0, 0.0, 0.0, 0.0], # [y00, y10, y01, y11]
		"flow_dir": Vector2(0.0, 1.0),
		"turbulence": 0.05,
		"water_blend": 0.0 # 0.0 = Turquesa (Sul), 1.0 = Chá-Mate (Norte)
	}

	# -------------------------------------------------------------
	# A. NORTE: LAGO CHÁ-MATE NO PLATÔ 16M E CASCATA 1 (wz <= -27)
	# -------------------------------------------------------------
	if wz <= -27:
		# Lago amplo elíptico no platô
		var dx_lake = (f_wx - 0.5) / 12.5
		var dz_lake = (f_wz - (-47.0)) / 13.5
		var dist_lake_sq = dx_lake * dx_lake + dz_lake * dz_lake

		# Canal de sangria do lago rumo ao sul (-35 <= wz <= -27)
		var is_outlet = (wz >= -35 and wz <= -27 and dist_canyon <= 3.0)

		if dist_lake_sq <= 1.0 or is_outlet:
			data.has_water = true
			data.water_y = 15.50
			data.water_corners = [15.50, 15.50, 15.50, 15.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 0.18 if is_outlet else 0.05
			data.water_blend = 1.0 # 100% Chá-Mate / Igarapé

		# Cascata 1: Queda do Platô para o Lago Alto 1 (Degrau em wz == -27)
		if wz == -27 and dist_canyon <= 3.2:
			data.has_water = true
			data.is_waterfall = true
			data.water_y = 15.50
			data.waterfall_base_y = 11.50
			data.water_corners = [15.50, 15.50, 15.50, 15.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 1.00 # Espuma densa de cachoeira
			data.water_blend = 0.95
			return data

	# -------------------------------------------------------------
	# B. MEIO: DESFILADEIRO, CASCATAS E LAGOS EM VALES ALTOS (-26 <= wz <= 20)
	# -------------------------------------------------------------
	elif wz >= -26 and wz <= 20:

		# 1. Lago do Vale Alto 1 (wz in [-26, -16]): Y = 11.50m
		if wz >= -26 and wz <= -16:
			var max_w = 4.8 + 1.2 * sin(f_wz * 0.4)
			if dist_canyon <= max_w:
				data.has_water = true
				data.water_y = 11.50
				data.water_corners = [11.50, 11.50, 11.50, 11.50]
				data.flow_dir = Vector2(0.0, 1.0)
				data.turbulence = get_waterfall_plume_turbulence(f_wx + 0.5, f_wz + 0.5, 0.08)
				data.water_blend = 0.85

		# Cascata 2: Queda Intermediária do Desfiladeiro (em wz == -15)
		if wz == -15 and dist_canyon <= 3.2:
			data.has_water = true
			data.is_waterfall = true
			data.water_y = 11.50
			data.waterfall_base_y = 7.00
			data.water_corners = [11.50, 11.50, 11.50, 11.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 1.00
			data.water_blend = 0.70
			return data

		# 2. Lago do Vale Alto 2 (wz in [-14, -3]): Y = 7.00m
		elif wz >= -14 and wz <= -3:
			var max_w = 5.2 + 1.5 * cos(f_wz * 0.35)
			if dist_canyon <= max_w:
				data.has_water = true
				data.water_y = 7.00
				data.water_corners = [7.00, 7.00, 7.00, 7.00]
				data.flow_dir = Vector2(0.0, 1.0)
				data.turbulence = get_waterfall_plume_turbulence(f_wx + 0.5, f_wz + 0.5, 0.08)
				data.water_blend = 0.50 # Zona central de mistura natural

		# Cascata 3: Queda Inferior do Desfiladeiro (em wz == -2)
		if wz == -2 and dist_canyon <= 3.5:
			data.has_water = true
			data.is_waterfall = true
			data.water_y = 7.00
			data.waterfall_base_y = 3.50
			data.water_corners = [7.00, 7.00, 7.00, 7.00]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 1.00
			data.water_blend = 0.35
			return data

		# 3. Lago do Vale Alto 3 / Bacia de Abertura (wz in [-1, +11]): Y = 3.50m
		elif wz >= -1 and wz <= 11:
			var max_w = 5.8 + 1.8 * sin(f_wz * 0.3)
			if dist_canyon <= max_w:
				data.has_water = true
				data.water_y = 3.50
				data.water_corners = [3.50, 3.50, 3.50, 3.50]
				data.flow_dir = Vector2(0.0, 1.0)
				data.turbulence = get_waterfall_plume_turbulence(f_wx + 0.5, f_wz + 0.5, 0.10)
				data.water_blend = 0.20

		# 4. Corredeiras em Rampa descendo para a Planície (wz in [12, 20]):
		# Desce de Y = 3.50m até Y = 1.00m (degrau de 0.25m por metro)
		elif wz >= 12 and wz <= 20:
			var max_w = 4.2
			if dist_canyon <= max_w:
				data.has_water = true
				var step_y = 3.50 - float(wz - 11) * 0.25
				var next_y = max(1.00, step_y - 0.25)
				data.water_y = step_y
				data.water_corners = [step_y, step_y, next_y, next_y]
				data.flow_dir = Vector2(0.05, 1.0).normalized()
				data.turbulence = 0.45
				data.water_blend = 0.10

	# -------------------------------------------------------------
	# C. SUL: CAMPINA COM GRANDE LAGO DE ÁGUAS CLARAS (wz >= 21)
	# -------------------------------------------------------------
	else:
		# Grande Lago elíptico de águas claras no sul (wz in [22, 60])
		var dx_lake = (f_wx - 0.0) / 20.0
		var dz_lake = (f_wz - 41.0) / 18.0
		var dist_big_lake_sq = dx_lake * dx_lake + dz_lake * dz_lake

		# Canal de desembocadura vindo das corredeiras (wz in [21, 24])
		var is_mouth = (wz >= 21 and wz <= 25 and dist_canyon <= 5.0)

		if dist_big_lake_sq <= 1.0 or is_mouth:
			data.has_water = true
			data.water_y = 1.00
			data.water_corners = [1.00, 1.00, 1.00, 1.00]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 0.05 # Lâmina serena cristalina
			data.water_blend = 0.0 # 100% Água Turquesa Cristalina

	return data

# =========================================================================
# 2. MODELO DE ELEVAÇÃO DO RELEVO GEOLÓGICO (Snapping 1.0m / 0.25m)
# =========================================================================

func evaluate_snapped_height(wx: float, wz: float) -> float:
	var snap_x = round(wx)
	var snap_z = round(wz)
	var w_cell = evaluate_water_cell(int(snap_x), int(snap_z))

	# 1. Se a célula for ocupada por lâmina d'água: escavar o leito
	if w_cell.has_water:
		if w_cell.is_waterfall:
			return round(w_cell.waterfall_base_y / SNAP_V) * SNAP_V
		var depth = 1.25 # Profundidade padrão sob água
		if snap_z <= -28:
			depth = 1.50 # Lago Chá-Mate profundo
		elif snap_z >= 22:
			depth = 0.75 # Grande Lago raso e cristalino sobre areia quartzo
		var bed_y = w_cell.water_y - depth
		return round(bed_y / SNAP_V) * SNAP_V

	# 2. Relevo Emerso:
	var c_center_x = get_canyon_center_x(snap_z)
	var dist_canyon = abs(snap_x + 0.5 - c_center_x)
	var qx = noise_warp.get_noise_2d(snap_x, snap_z) * 1.5
	var qz = noise_warp.get_noise_2d(snap_x + 43.0, snap_z + 17.0) * 1.5
	var n_val = noise_base.get_noise_2d(snap_x + qx, snap_z + qz)

	var raw_h = 1.0

	# A. Platô Norte (wz <= -28): Cota 16.0m
	if snap_z <= -28:
		raw_h = 16.0 + n_val * 1.25
		# Rebordas montanhosas extremas que abraçam o platô
		var dist_edge = max(abs(snap_x) - 18.0, 0.0)
		if dist_edge > 0.0 or snap_z < -54.0:
			var lift = dist_edge * 0.45 + max(-54.0 - snap_z, 0.0) * 0.35
			raw_h += lift
		# Margens do Lago Chá-Mate
		var dx_lake = (snap_x - 0.5) / 12.5
		var dz_lake = (snap_z - (-47.0)) / 13.5
		var d_lake = sqrt(dx_lake * dx_lake + dz_lake * dz_lake)
		if d_lake < 1.4:
			raw_h = clamp(raw_h, 15.75, 16.50)

	# B. Desfiladeiro Central (-28 < wz <= 16):
	elif snap_z > -28 and snap_z <= 16:
		# Altitude regional do desfiladeiro descendo em degraus
		var regional_y = 12.0
		if snap_z <= -16:
			regional_y = 12.0
		elif snap_z <= -2:
			regional_y = 7.5
		elif snap_z <= 10:
			regional_y = 4.0
		else:
			regional_y = 2.0

		# Calha central do cânion
		if dist_canyon <= 6.5:
			raw_h = regional_y + 0.5 + n_val * 0.5
		else:
			# Paredões rochosos íngremes nas laterais (Paredões de Granito)
			var wall_t = clamp((dist_canyon - 6.5) / 7.0, 0.0, 1.0)
			# Altura do topo do platô lateral descendo gradualmente
			var top_cliff_y = 16.0 - (float(snap_z + 28) / 44.0) * 11.0 # De 16m no norte até 5m no sul
			raw_h = lerp(regional_y + 1.0, top_cliff_y + n_val * 1.5, wall_t)

	# C. Campina Sul (wz > 16): Cota 1.0m a 2.5m
	else:
		raw_h = 1.75 + n_val * 1.0
		# Margem suave do Grande Lago
		var dx_lake = (snap_x - 0.0) / 20.0
		var dz_lake = (snap_z - 41.0) / 18.0
		var d_lake = sqrt(dx_lake * dx_lake + dz_lake * dz_lake)
		if d_lake < 1.35:
			var beach_t = clamp((d_lake - 1.0) / 0.35, 0.0, 1.0)
			raw_h = lerp(1.25, 2.0, beach_t)

	return round(raw_h / SNAP_V) * SNAP_V

# =========================================================================
# 3. COLORIZAÇÃO ESTRATIGRÁFICA E PEDOLÓGICA DAS FACES
# =========================================================================

## Retorna a cor e propriedades de solo de um vértice/face
func get_surface_color(wx: float, wz: float, y_val: float, normal: Vector3, is_submerged: bool) -> Dictionary:
	var seed_val = int(wx) * 31 + int(wz) * 73 + int(y_val * 16.0) * 11
	var jitter = 0.96 + 0.08 * fposmod(sin(float(seed_val)) * 43758.5453, 1.0)

	# 1. Se estiver submerso sob a lâmina d'água:
	if is_submerged:
		if wz >= 20.0:
			# Leito sob o Grande Lago Turquesa: Areia Quartzo molhada
			return { "color": COL_AREIA_WET * jitter, "alpha": 0.0 }
		elif wz <= -27.0:
			# Leito sob o Lago Chá-Mate: Terra Preta / Húmus profundo
			return { "color": COL_TERRA_TOPO * jitter, "alpha": 0.0 }
		else:
			# Leito do Desfiladeiro: Granito / Cascalho basáltico
			var col = COL_GRAN_CLARO.lerp(COL_GRAN_VEIO, fposmod(float(seed_val), 1.0) * 0.4)
			return { "color": col * jitter, "alpha": 0.0 }

	# 2. Se for face quase vertical (Paredão de Rocha / Escarpa):
	if normal.y < 0.65:
		# Granito Tropical e Basalto com veios minerais
		var is_dark = fposmod(float(seed_val), 1.0) > 0.65
		var col = COL_GRAN_ESCURO if is_dark else COL_GRAN_CLARO.lerp(COL_GRAN_ROSADO, 0.3)
		return { "color": col * jitter, "alpha": 0.0 }

	# 3. Região Sul (wz >= 18.0): Campina Grande e Areia Quartzo
	if wz >= 18.0:
		var dx_lake = (wx - 0.0) / 20.0
		var dz_lake = (wz - 41.0) / 18.0
		var d_lake = sqrt(dx_lake * dx_lake + dz_lake * dz_lake)

		# Praias e dunas de Areia Quartzo puro em torno do lago
		if d_lake <= 1.38 or y_val <= 1.50:
			var col = COL_AREIA_LUZ if fposmod(float(seed_val), 1.0) > 0.45 else COL_AREIA_MID
			return { "color": col * jitter, "alpha": 0.0 }
		else:
			# Campina verdejante ondulada
			var col = COL_CAMPINA_LUZ.lerp(COL_CAMPINA_MID, fposmod(float(seed_val), 1.0) * 0.5)
			return { "color": col * jitter, "alpha": 0.0 }

	# 4. Região Norte (wz <= -26.0): Platô com Floresta Tropical
	if wz <= -26.0:
		# Topo plano de Serrapilheira (húmus com folhas secas e textura)
		var is_leaf = fposmod(float(seed_val), 1.0) > 0.75
		var col = COL_SERRA_SECA if is_leaf else COL_SERRA_BASE
		# Alpha = 0.85 ativa a textura tex_serrapilheira.png pelo shader
		return { "color": col * jitter, "alpha": 0.85 }

	# 5. Desfiladeiro Central (-26.0 < wz < 18.0): Transição Rocha, Terra e Latossolo
	var c_center_x = get_canyon_center_x(wz)
	var dist_canyon = abs(wx - c_center_x)
	if dist_canyon <= 7.0:
		# Fundo do vale: Granito e margens de cascalho/terra preta
		var col = COL_GRAN_CLARO.lerp(COL_TERRA_MID, 0.4)
		return { "color": col * jitter, "alpha": 0.15 }
	else:
		# Bordas altas do cânion com solo latossolo e rocha
		var col = COL_LATO_MATRIZ.lerp(COL_GRAN_ROSADO, 0.4)
		return { "color": col * jitter, "alpha": 0.20 }

## Cor dos estratos geológicos em cortes verticais de 90°
func get_wall_stratum_color(wx: float, wz: float, y_cur: float, y_top: float) -> Color:
	var seed_val = int(wx) * 47 + int(wz) * 83 + int(y_cur * 16.0) * 19
	var jitter = 0.95 + 0.10 * fposmod(sin(float(seed_val)) * 43758.5453, 1.0)

	# Região Sul: Paredes de areia quartzo e argila
	if wz >= 20.0:
		if y_cur >= y_top - 0.50:
			return COL_AREIA_MID * jitter
		else:
			return COL_LATO_MATRIZ * jitter

	# Cânion e Desfiladeiro: Estratos de Granito, Latossolo e Basalto
	if y_cur >= y_top - 0.50:
		# Topo: Terra Preta ou Húmus
		return COL_TERRA_TOPO * jitter
	elif y_cur >= y_top - 2.00:
		# Camada média: Latossolo Vermelho Plíntico
		var is_picarra = fposmod(float(seed_val), 1.0) > 0.65
		return (COL_LATO_PICARRA if is_picarra else COL_LATO_MATRIZ) * jitter
	else:
		# Base profunda: Granito / Basalto com veios
		var is_dark = fposmod(float(seed_val), 1.0) > 0.55
		return (COL_GRAN_ESCURO if is_dark else COL_GRAN_CLARO) * jitter

# =========================================================================
# 4. CONSTRUÇÃO PROCEDURAL DE CHUNKS (32 Chunks de 16x16m)
# =========================================================================

func generate_world() -> void:
	for child in get_children():
		child.queue_free()

	print("--- GERANDO MUNDO PROCEDURAL FINAL (64x128m, 32 CHUNKS 16x16M) ---")

	var chunk_count = 0
	# 4 chunks em X: cx in [-2, 1] -> X in [-32, +32]
	# 8 chunks em Z: cz in [-4, 3] -> Z in [-64, +64]
	for cz in range(-4, 4):
		for cx in range(-2, 2):
			build_chunk(cx, cz)
			chunk_count += 1

	print("Sucesso: %d Chunks construidos e integrados com sucesso!" % chunk_count)

func build_chunk(cx: int, cz: int) -> void:
	var chunk_node = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [cx, cz]
	add_child(chunk_node)

	var origin_x = cx * CHUNK_SIZE
	var origin_z = cz * CHUNK_SIZE

	# 1. Pré-computa a matriz de cantos 17x17 para garantir costura exata
	var corner_heights: Array = []
	for iz in range(CHUNK_SIZE + 1):
		var row: Array = []
		for ix in range(CHUNK_SIZE + 1):
			var wx = origin_x + ix * SNAP_H
			var wz = origin_z + iz * SNAP_H
			row.append(evaluate_snapped_height(wx, wz))
		corner_heights.append(row)

	# 2. Constrói a malha de Terreno
	var st_terr = SurfaceTool.new()
	st_terr.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 3. Constrói a malha de Água (se houver células de água)
	var st_wat = SurfaceTool.new()
	st_wat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chunk_has_water = false

	for iz in range(CHUNK_SIZE):
		for ix in range(CHUNK_SIZE):
			var lx0 = float(ix) * SNAP_H
			var lx1 = float(ix + 1) * SNAP_H
			var lz0 = float(iz) * SNAP_H
			var lz1 = float(iz + 1) * SNAP_H

			var wx0 = origin_x + lx0
			var wx1 = origin_x + lx1
			var wz0 = origin_z + lz0
			var wz1 = origin_z + lz1

			var y00 = corner_heights[iz][ix]
			var y10 = corner_heights[iz][ix + 1]
			var y01 = corner_heights[iz + 1][ix]
			var y11 = corner_heights[iz + 1][ix + 1]

			var v00 = Vector3(wx0, y00, wz0)
			var v10 = Vector3(wx1, y10, wz0)
			var v01 = Vector3(wx0, y01, wz1)
			var v11 = Vector3(wx1, y11, wz1)

			var w_info = evaluate_water_cell(int(wx0), int(wz0))
			var is_sub = w_info.has_water

			# --- FACES SUPERIORES DE TERRENO ---
			# Triângulo 1 (v00 -> v10 -> v01)
			var n1 = (v01 - v00).cross(v10 - v00).normalized()
			if n1.y < 0.0: n1 = -n1
			var sc1 = get_surface_color(wx0 + 0.25, wz0 + 0.25, (y00 + y10 + y01) / 3.0, n1, is_sub)
			var col1 = Color(sc1.color.r, sc1.color.g, sc1.color.b, sc1.alpha)

			st_terr.set_normal(n1)
			st_terr.set_color(col1)
			st_terr.set_uv(Vector2(wx0, wz0))
			st_terr.add_vertex(v00)

			st_terr.set_normal(n1)
			st_terr.set_color(col1)
			st_terr.set_uv(Vector2(wx1, wz0))
			st_terr.add_vertex(v10)

			st_terr.set_normal(n1)
			st_terr.set_color(col1)
			st_terr.set_uv(Vector2(wx0, wz1))
			st_terr.add_vertex(v01)

			# Triângulo 2 (v10 -> v11 -> v01)
			var n2 = (v01 - v10).cross(v11 - v10).normalized()
			if n2.y < 0.0: n2 = -n2
			var sc2 = get_surface_color(wx0 + 0.75, wz0 + 0.75, (y10 + y11 + v01.y) / 3.0, n2, is_sub)
			var col2 = Color(sc2.color.r, sc2.color.g, sc2.color.b, sc2.alpha)

			st_terr.set_normal(n2)
			st_terr.set_color(col2)
			st_terr.set_uv(Vector2(wx1, wz0))
			st_terr.add_vertex(v10)

			st_terr.set_normal(n2)
			st_terr.set_color(col2)
			st_terr.set_uv(Vector2(wx1, wz1))
			st_terr.add_vertex(v11)

			st_terr.set_normal(n2)
			st_terr.set_color(col2)
			st_terr.set_uv(Vector2(wx0, wz1))
			st_terr.add_vertex(v01)

			# --- PAREDÕES VERTICAIS DE 90° ENTRE DEGRAUS DE TERRENO ---
			_build_cell_walls(st_terr, origin_x, origin_z, ix, iz, lx0, lx1, lz0, lz1, y00, y10, y01, y11, corner_heights, cx, cz)

			# --- FACES DE ÁGUA MULTI-NÍVEL E CASCATAS ---
			if w_info.has_water:
				chunk_has_water = true
				_build_cell_water(st_wat, w_info, wx0, wx1, wz0, wz1)

	# Finaliza terreno
	var terr_mesh = st_terr.commit()
	if terr_mesh:
		var mi_terr = MeshInstance3D.new()
		mi_terr.name = "TerrainMesh"
		mi_terr.mesh = terr_mesh
		mi_terr.material_override = mat_surface
		chunk_node.add_child(mi_terr)

	# Finaliza água
	if chunk_has_water:
		var wat_mesh = st_wat.commit()
		if wat_mesh:
			var mi_wat = MeshInstance3D.new()
			mi_wat.name = "WaterMesh"
			mi_wat.mesh = wat_mesh
			mi_wat.material_override = mat_water
			chunk_node.add_child(mi_wat)

## Constrói os paredões verticais (degraus) entre a célula e suas vizinhas
func _build_cell_walls(st: SurfaceTool, origin_x: float, origin_z: float,
		ix: int, iz: int, lx0: float, lx1: float, lz0: float, lz1: float,
		y00: float, y10: float, y01: float, y11: float,
		corner_heights: Array, cx: int, cz: int) -> void:

	var wx0 = origin_x + lx0
	var wx1 = origin_x + lx1
	var wz0 = origin_z + lz0
	var wz1 = origin_z + lz1

	# Parede ao Sul (+Z):
	var s_y0 = 0.0
	var s_y1 = 0.0
	if iz < CHUNK_SIZE - 1:
		s_y0 = corner_heights[iz + 1][ix]
		s_y1 = corner_heights[iz + 1][ix + 1]
	else:
		s_y0 = evaluate_snapped_height(wx0, wz1 + SNAP_H)
		s_y1 = evaluate_snapped_height(wx1, wz1 + SNAP_H)

	# Saia exterior extrema Sul do mapa completo (cz == 3 e iz == 15)
	if cz == 3 and iz == CHUNK_SIZE - 1:
		s_y0 = 0.0
		s_y1 = 0.0

	if y01 > s_y0 + 0.001 or y11 > s_y1 + 0.001:
		_add_stratified_quad(st, wx0, wx1, wz1, y01, y11, s_y0, s_y1, Vector3.BACK)

	# Parede ao Norte (-Z):
	var n_y0 = 0.0
	var n_y1 = 0.0
	if iz > 0:
		n_y0 = corner_heights[iz - 1][ix]
		n_y1 = corner_heights[iz - 1][ix + 1]
	else:
		n_y0 = evaluate_snapped_height(wx0, wz0 - SNAP_H)
		n_y1 = evaluate_snapped_height(wx1, wz0 - SNAP_H)

	# Saia exterior extrema Norte do mapa completo (cz == -4 e iz == 0)
	if cz == -4 and iz == 0:
		n_y0 = 0.0
		n_y1 = 0.0

	if y00 > n_y0 + 0.001 or y10 > n_y1 + 0.001:
		_add_stratified_quad(st, wx1, wx0, wz0, y10, y00, n_y1, n_y0, Vector3.FORWARD)

	# Parede a Leste (+X):
	var e_y0 = 0.0
	var e_y1 = 0.0
	if ix < CHUNK_SIZE - 1:
		e_y0 = corner_heights[iz][ix + 1]
		e_y1 = corner_heights[iz + 1][ix + 1]
	else:
		e_y0 = evaluate_snapped_height(wx1 + SNAP_H, wz0)
		e_y1 = evaluate_snapped_height(wx1 + SNAP_H, wz1)

	# Saia exterior extrema Leste do mapa completo (cx == 1 e ix == 15)
	if cx == 1 and ix == CHUNK_SIZE - 1:
		e_y0 = 0.0
		e_y1 = 0.0

	if y10 > e_y0 + 0.001 or y11 > e_y1 + 0.001:
		_add_stratified_quad_x(st, wx1, wz1, wz0, y11, y10, e_y1, e_y0, Vector3.RIGHT)

	# Parede a Oeste (-X):
	var w_y0 = 0.0
	var w_y1 = 0.0
	if ix > 0:
		w_y0 = corner_heights[iz][ix - 1]
		w_y1 = corner_heights[iz + 1][ix - 1]
	else:
		w_y0 = evaluate_snapped_height(wx0 - SNAP_H, wz0)
		w_y1 = evaluate_snapped_height(wx0 - SNAP_H, wz1)

	# Saia exterior extrema Oeste do mapa completo (cx == -2 e ix == 0)
	if cx == -2 and ix == 0:
		w_y0 = 0.0
		w_y1 = 0.0

	if y00 > w_y0 + 0.001 or y01 > w_y1 + 0.001:
		_add_stratified_quad_x(st, wx0, wz0, wz1, y00, y01, w_y0, w_y1, Vector3.LEFT)

## Adiciona um quad de parede vertical ao longo do eixo X
func _add_stratified_quad(st: SurfaceTool, x0: float, x1: float, z: float,
		y_top0: float, y_top1: float, y_bot0: float, y_bot1: float, norm: Vector3) -> void:

	var steps = int(ceil(max(y_top0 - y_bot0, y_top1 - y_bot1) / SNAP_V))
	steps = max(steps, 1)

	var y_max_top = max(y_top0, y_top1)

	for s in range(steps):
		var t0 = float(s) / float(steps)
		var t1 = float(s + 1) / float(steps)

		var cur_top0 = lerp(y_top0, y_bot0, t0)
		var cur_top1 = lerp(y_top1, y_bot1, t0)
		var cur_bot0 = lerp(y_top0, y_bot0, t1)
		var cur_bot1 = lerp(y_top1, y_bot1, t1)

		var mid_y = (cur_top0 + cur_bot0) * 0.5
		var col = get_wall_stratum_color((x0 + x1) * 0.5, z, mid_y, y_max_top)

		var v_t0 = Vector3(x0, cur_top0, z)
		var v_t1 = Vector3(x1, cur_top1, z)
		var v_b0 = Vector3(x0, cur_bot0, z)
		var v_b1 = Vector3(x1, cur_bot1, z)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x0, cur_top0))
		st.add_vertex(v_t0)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x1, cur_top1))
		st.add_vertex(v_t1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x0, cur_bot0))
		st.add_vertex(v_b0)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x1, cur_top1))
		st.add_vertex(v_t1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x1, cur_bot1))
		st.add_vertex(v_b1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(x0, cur_bot0))
		st.add_vertex(v_b0)

## Adiciona um quad de parede vertical ao longo do eixo Z
func _add_stratified_quad_x(st: SurfaceTool, x: float, z0: float, z1: float,
		y_top0: float, y_top1: float, y_bot0: float, y_bot1: float, norm: Vector3) -> void:

	var steps = int(ceil(max(y_top0 - y_bot0, y_top1 - y_bot1) / SNAP_V))
	steps = max(steps, 1)

	var y_max_top = max(y_top0, y_top1)

	for s in range(steps):
		var t0 = float(s) / float(steps)
		var t1 = float(s + 1) / float(steps)

		var cur_top0 = lerp(y_top0, y_bot0, t0)
		var cur_top1 = lerp(y_top1, y_bot1, t0)
		var cur_bot0 = lerp(y_top0, y_bot0, t1)
		var cur_bot1 = lerp(y_top1, y_bot1, t1)

		var mid_y = (cur_top0 + cur_bot0) * 0.5
		var col = get_wall_stratum_color(x, (z0 + z1) * 0.5, mid_y, y_max_top)

		var v_t0 = Vector3(x, cur_top0, z0)
		var v_t1 = Vector3(x, cur_top1, z1)
		var v_b0 = Vector3(x, cur_bot0, z0)
		var v_b1 = Vector3(x, cur_bot1, z1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z0, cur_top0))
		st.add_vertex(v_t0)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z1, cur_top1))
		st.add_vertex(v_t1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z0, cur_bot0))
		st.add_vertex(v_b0)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z1, cur_top1))
		st.add_vertex(v_t1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z1, cur_bot1))
		st.add_vertex(v_b1)

		st.set_normal(norm)
		st.set_color(col)
		st.set_uv(Vector2(z0, cur_bot0))
		st.add_vertex(v_b0)

## Constrói a geometria de água da célula
func _build_cell_water(st: SurfaceTool, w_data: Dictionary,
		wx0: float, wx1: float, wz0: float, wz1: float) -> void:

	var wy00 = w_data.water_corners[0]
	var wy10 = w_data.water_corners[1]
	var wy01 = w_data.water_corners[2]
	var wy11 = w_data.water_corners[3]

	var wv00 = Vector3(wx0, wy00, wz0)
	var wv10 = Vector3(wx1, wy10, wz0)
	var wv01 = Vector3(wx0, wy01, wz1)
	var wv11 = Vector3(wx1, wy11, wz1)

	var f_dir: Vector2 = w_data.flow_dir
	var blend_val = w_data.water_blend # 1.0 = Chá-Mate (Norte), 0.0 = Turquesa (Sul)

	# Atributo COLOR para pixel_water.gdshader:
	# R, G: Direção do fluxo normalizada para [0, 1]
	# B: Turbulência contínua por vértice (amortecimento suave da pluma de cascata)
	# A: Fator de mistura
	var t00 = w_data.turbulence
	var t10 = w_data.turbulence
	var t01 = w_data.turbulence
	var t11 = w_data.turbulence
	if not w_data.is_waterfall and w_data.turbulence < 0.99:
		var base_t = 0.08
		if wz0 >= -1.0:
			base_t = 0.10
		t00 = get_waterfall_plume_turbulence(wx0, wz0, base_t)
		t10 = get_waterfall_plume_turbulence(wx1, wz0, base_t)
		t01 = get_waterfall_plume_turbulence(wx0, wz1, base_t)
		t11 = get_waterfall_plume_turbulence(wx1, wz1, base_t)
		if w_data.turbulence > 0.15:
			t00 = max(t00, w_data.turbulence)
			t10 = max(t10, w_data.turbulence)
			t01 = max(t01, w_data.turbulence)
			t11 = max(t11, w_data.turbulence)

	var col00 = Color(f_dir.x * 0.5 + 0.5, f_dir.y * 0.5 + 0.5, t00, blend_val)
	var col10 = Color(f_dir.x * 0.5 + 0.5, f_dir.y * 0.5 + 0.5, t10, blend_val)
	var col01 = Color(f_dir.x * 0.5 + 0.5, f_dir.y * 0.5 + 0.5, t01, blend_val)
	var col11 = Color(f_dir.x * 0.5 + 0.5, f_dir.y * 0.5 + 0.5, t11, blend_val)

	# UV2: canal direto para o 3-way blend do shader:
	# X = peso Turquesa, Y = peso Barrenta (0.0). Se sum > 0.001, igarape = 1.0 - sum
	var w_turquesa = clamp(1.0 - blend_val, 0.0001, 1.0)
	var uv2_data = Vector2(w_turquesa, 0.0)

	# 1. Superfície Superior da Lâmina d'Água:
	var wn1 = (wv01 - wv00).cross(wv10 - wv00).normalized()
	if wn1.y < 0.0: wn1 = -wn1

	st.set_normal(wn1)
	st.set_color(col00)
	st.set_uv(Vector2(wx0, wz0))
	st.set_uv2(uv2_data)
	st.add_vertex(wv00)

	st.set_normal(wn1)
	st.set_color(col10)
	st.set_uv(Vector2(wx1, wz0))
	st.set_uv2(uv2_data)
	st.add_vertex(wv10)

	st.set_normal(wn1)
	st.set_color(col01)
	st.set_uv(Vector2(wx0, wz1))
	st.set_uv2(uv2_data)
	st.add_vertex(wv01)

	var wn2 = (wv01 - wv10).cross(wv11 - wv10).normalized()
	if wn2.y < 0.0: wn2 = -wn2

	st.set_normal(wn2)
	st.set_color(col10)
	st.set_uv(Vector2(wx1, wz0))
	st.set_uv2(uv2_data)
	st.add_vertex(wv10)

	st.set_normal(wn2)
	st.set_color(col11)
	st.set_uv(Vector2(wx1, wz1))
	st.set_uv2(uv2_data)
	st.add_vertex(wv11)

	st.set_normal(wn2)
	st.set_color(col01)
	st.set_uv(Vector2(wx0, wz1))
	st.set_uv2(uv2_data)
	st.add_vertex(wv01)

	# 2. Queda d'Água Vertical (Cascata / Cachoeira voltada para o Sul +Z)
	if w_data.is_waterfall:
		var fall_top = w_data.water_y
		var fall_bot = w_data.waterfall_base_y
		var fall_norm = Vector3.BACK # Face voltada para o Sul (+Z)

		var fall_col = Color(
			0.5,
			1.0, # Fluxo acelerado para baixo / sul
			1.0, # Turbulência máxima absoluta (ativa densa espuma branca no shader)
			blend_val
		)

		var fv_tl = Vector3(wx0, fall_top, wz1)
		var fv_tr = Vector3(wx1, fall_top, wz1)
		var fv_bl = Vector3(wx0, fall_bot, wz1)
		var fv_br = Vector3(wx1, fall_bot, wz1)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx0, fall_top))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_tl)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx1, fall_top))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_tr)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx0, fall_bot))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_bl)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx1, fall_top))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_tr)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx1, fall_bot))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_br)

		st.set_normal(fall_norm)
		st.set_color(fall_col)
		st.set_uv(Vector2(wx0, fall_bot))
		st.set_uv2(uv2_data)
		st.add_vertex(fv_bl)
