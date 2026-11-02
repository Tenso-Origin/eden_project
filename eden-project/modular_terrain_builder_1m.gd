@tool
extends RefCounted
class_name ModularTerrainBuilder1m

## Módulo de Geração e Construção de Terreno e Hidrologia Modular na Grade 1x1x1m
## FASE 2: Hidrologia Modular Multi-Nível (Lagos de Altitude, Corredeiras em Rampa e Cachoeiras)
## Respeita a regra de Snapping Horizontal (1.0m) e Snapping Vertical (0.25m)
## Configuração Oficial: Lago elevado ao Norte (-Z, Y=3.5m), Cachoeira vertical (tau=1.0) e Rio em rampa ao Sul (+Z) até Y=0.5m
## Arquitetura Técnica: HD Pixel Art 3D (David Holland)

const SNAP_V: float = 0.25 # Quarto de metro estrito
const SNAP_H: float = 1.00 # Metro estrito

# Paleta Geológica Oficial do Kit de Bioma de Floresta Tropical
const COL_WHITE_SAND_LIGHT = Color(0.88, 0.86, 0.82) # Areia Branca Luz
const COL_WHITE_SAND_MID   = Color(0.74, 0.71, 0.66) # Areia Branca Meia-Luz
const COL_WHITE_SAND_WET   = Color(0.60, 0.58, 0.53) # Leito de Areia molhada
const COL_SERRAPILHEIRA    = Color(0.18, 0.12, 0.09) # Tapete de húmus escuro
const COL_TERRA_PRETA      = Color(0.13, 0.11, 0.10) # Horizonte A (0m a -1m)
const COL_LATERITA_CLAY    = Color(0.56, 0.23, 0.14) # Latossolo Plíntico avermelhado
const COL_GRANITO_MID      = Color(0.33, 0.31, 0.30) # Granito Tropical
const COL_GRANITO_DARK     = Color(0.18, 0.20, 0.22) # Basalto profundo

var noise_base: FastNoiseLite
var noise_warp: FastNoiseLite

var elevation_scale: float = 4.0

func _init() -> void:
	noise_base = FastNoiseLite.new()
	noise_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_base.seed = 104729
	noise_base.frequency = 0.025
	noise_base.fractal_octaves = 3

	noise_warp = FastNoiseLite.new()
	noise_warp.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_warp.seed = 239841
	noise_warp.frequency = 0.03

# =========================================================================
# 1. MODELO MATEMÁTICO DE RELEVO E HIDROLOGIA MULTI-NÍVEL (NORTE -> SUL)
# =========================================================================

## Escalar de Bioma Contínuo B in [0.0, 1.0] (0.0 = Campina, 1.0 = Floresta)
func evaluate_biome(wx: float, wz: float) -> float:
	var norm_x = wx / 32.0
	var raw_b = clamp(norm_x + 0.5, 0.0, 1.0)
	var t = raw_b
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

## Trajetória do Rio Modular no plano (X, Z): retorna X central da calha em função de Z
func evaluate_river_path_x(wz: float) -> float:
	var rel_z = fposmod(wz, 16.0)
	return 8.0 + 1.2 * sin(rel_z * 0.40)

## Avalia a lâmina d'água modular em uma célula (X, Z)
## Layout:
## - Lago de Altitude ao Norte (-Z, rel_z <= 3): Y = 3.50m (tau = 0.05)
## - Degrau de Queda d'Água Vertical ao Norte (rel_z == 4): Y = 3.50m descendo a 2.00m (tau = 1.00)
## - Rio descendo em Rampa ao Sul (+Z, rel_z in [5, 10]): Y desce de 2.00m a 0.50m (tau = 0.50)
## - Bacia Inferior ao Sul (+Z, rel_z >= 11): Y = 0.50m (tau = 0.08)
func evaluate_water_cell(cx: int, cz: int) -> Dictionary:
	var rel_z = int(fposmod(float(cz), 16.0))
	var rel_x = float(fposmod(float(cx), 16.0))

	var r_center_x = 8.0 + 1.2 * sin(float(rel_z) * 0.40)
	var dist_river = abs(rel_x + 0.5 - r_center_x)

	var data = {
		"has_water": false,
		"is_waterfall": false,
		"water_y": 0.0,
		"water_corners": [0.0, 0.0, 0.0, 0.0], # [y00 (x0,z0), y10 (x1,z0), y01 (x0,z1), y11 (x1,z1)]
		"waterfall_base_y": 0.0,
		"flow_dir": Vector2(0.0, 1.0), # Flui para o Sul (+Z)
		"turbulence": 0.05
	}

	# Largura da calha ou lago
	var max_w_dist = 2.0
	if rel_z <= 3:
		max_w_dist = 3.6 # Lago elevado amplo (7m a 8m de diâmetro)
	elif rel_z == 4:
		max_w_dist = 2.2 # Garganta da cachoeira
	elif rel_z >= 11:
		max_w_dist = 2.8 # Foz / Bacia inferior calma

	if dist_river <= max_w_dist:
		data.has_water = true

		# 1. Platô Alto com Lago de Altitude ao Norte (rel_z <= 3): Y_água = 3.50m
		if rel_z <= 3:
			data.water_y = 3.50
			data.water_corners = [3.50, 3.50, 3.50, 3.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 0.05 # Água calma de lago

		# 2. Degrau de Cachoeira / Queda d'Água Vertical ao Norte (rel_z == 4):
		# Queda vertical abrupta de Y = 3.50m para Y = 2.00m (Desnível de 1.50m)
		elif rel_z == 4:
			data.water_y = 3.50
			data.waterfall_base_y = 2.00
			data.is_waterfall = true
			data.water_corners = [3.50, 3.50, 3.50, 3.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 1.00 # Turbulência máxima de cachoeira com espuma branca densa

		# 3. Corredeiras em Rampa Descendo ao Sul (rel_z de 5 a 10):
		# Desce de Y = 2.00m até Y = 0.50m em degraus exatos de 0.25m por metro
		elif rel_z in [5, 6, 7, 8, 9, 10]:
			var step_start_y = 2.00 - float(rel_z - 5) * 0.25
			var step_end_y = step_start_y - 0.25
			data.water_y = step_start_y
			# Rampa inclinada em direção a +Z (Sul)
			data.water_corners = [step_start_y, step_start_y, step_end_y, step_end_y]
			data.flow_dir = Vector2(0.05, 1.0).normalized()
			data.turbulence = 0.50 # Turbulência de corredeira em rampa

		# 4. Bacia Inferior ao Sul (rel_z >= 11): Y_água = 0.50m
		else:
			data.water_y = 0.50
			data.water_corners = [0.50, 0.50, 0.50, 0.50]
			data.flow_dir = Vector2(0.0, 1.0)
			data.turbulence = 0.08 # Leve marola plácida na foz

	return data

## Avalia a cota geológica do terreno (Snapping 1.0m horizontal e 0.25m vertical)
## Quando a célula possui água, o leito do terreno é escavado abaixo da água
func evaluate_snapped_height(wx: float, wz: float) -> float:
	var snap_x = round(wx)
	var snap_z = round(wz)
	var rel_z = int(fposmod(snap_z, 16.0))
	var rel_x = float(fposmod(snap_x, 16.0))

	var w_cell = evaluate_water_cell(int(snap_x), int(snap_z))
	if w_cell.has_water:
		# Leito escavado sob a lâmina d'água (0.75m no lago, 0.50m na rampa)
		var depth = 0.75 if rel_z <= 4 else 0.50
		var bed_y = w_cell.water_y - depth
		return round(bed_y / SNAP_V) * SNAP_V

	# Terreno emerso padrão
	var r_center_x = 8.0 + 1.2 * sin(float(rel_z) * 0.40)
	var dist_river = abs(rel_x + 0.5 - r_center_x)

	# Encosta regional descendo do Norte montanhoso (+4.5m) para o Sul plano (+0.75m)
	var regional_slope = 4.25 - (float(rel_z) / 15.0) * 3.25
	var qx = noise_warp.get_noise_2d(snap_x, snap_z) * 2.0
	var qz = noise_warp.get_noise_2d(snap_x + 31.0, snap_z + 17.0) * 2.0
	var raw_h = regional_slope + noise_base.get_noise_2d(snap_x + qx, snap_z + qz) * 1.5

	# As margens do rio sobem para conter o canal
	if dist_river < 4.5:
		var bank_lift = (4.5 - dist_river) * 0.35
		raw_h = max(raw_h, bank_lift + 0.5)

	# Platô alto que contém o lago ao Norte
	if rel_z <= 4 and dist_river >= 3.0:
		raw_h = max(raw_h, 4.25)

	return round(raw_h / SNAP_V) * SNAP_V

# =========================================================================
# 2. CONSTRUÇÃO DA MALHA MODULAR DE TERRENO (CHUNK MESH BATCH)
# =========================================================================

func build_chunk_mesh(c_coord: Vector2i, size_in_meters: int = 16) -> ArrayMesh:
	return build_terrain_mesh(c_coord, size_in_meters)

func build_terrain_mesh(c_coord: Vector2i, size_in_meters: int = 16) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin_x = c_coord.x * size_in_meters
	var origin_z = c_coord.y * size_in_meters

	var corner_heights: Array = []
	for iz in range(size_in_meters + 1):
		var row: Array = []
		for ix in range(size_in_meters + 1):
			var wx = origin_x + ix * SNAP_H
			var wz = origin_z + iz * SNAP_H
			row.append(evaluate_snapped_height(wx, wz))
		corner_heights.append(row)

	for iz in range(size_in_meters):
		for ix in range(size_in_meters):
			var lx0 = float(ix) * SNAP_H
			var lx1 = float(ix + 1) * SNAP_H
			var lz0 = float(iz) * SNAP_H
			var lz1 = float(iz + 1) * SNAP_H

			var wx_center = origin_x + lx0 + 0.5
			var wz_center = origin_z + lz0 + 0.5
			var biome = evaluate_biome(wx_center, wz_center)

			var y00 = corner_heights[iz][ix]
			var y10 = corner_heights[iz][ix + 1]
			var y01 = corner_heights[iz + 1][ix]
			var y11 = corner_heights[iz + 1][ix + 1]

			var v00 = Vector3(lx0, y00, lz0)
			var v10 = Vector3(lx1, y10, lz0)
			var v01 = Vector3(lx0, y01, lz1)
			var v11 = Vector3(lx1, y11, lz1)

			var w_info = evaluate_water_cell(int(origin_x + lx0), int(origin_z + lz0))
			var is_submerged = w_info.has_water

			# Triângulo 1 (CCW)
			var n1 = (v01 - v00).cross(v10 - v00).normalized()
			var c1 = _get_top_color(biome, n1, is_submerged)

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

			# Triângulo 2 (CCW)
			var n2 = (v01 - v10).cross(v11 - v10).normalized()
			var c2 = _get_top_color(biome, n2, is_submerged)

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

			# Paredões laterais estratificados (Cliff_Wall_90deg)
			_build_lateral_walls(st, origin_x, origin_z, ix, iz, lx0, lx1, lz0, lz1, y00, y10, y01, y11, biome)

	return st.commit()

# =========================================================================
# 3. CONSTRUÇÃO DA MALHA MODULAR DE ÁGUA MULTI-NÍVEL (Lagos, Rampas e Quedas)
# =========================================================================

func build_water_mesh(c_coord: Vector2i, size_in_meters: int = 16) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var origin_x = c_coord.x * size_in_meters
	var origin_z = c_coord.y * size_in_meters
	var has_any_water = false

	for iz in range(size_in_meters):
		for ix in range(size_in_meters):
			var cx = int(origin_x + ix)
			var cz = int(origin_z + iz)
			var w_data = evaluate_water_cell(cx, cz)

			if not w_data.has_water:
				continue

			has_any_water = true
			var lx0 = float(ix) * SNAP_H
			var lx1 = float(ix + 1) * SNAP_H
			var lz0 = float(iz) * SNAP_H
			var lz1 = float(iz + 1) * SNAP_H

			var biome = evaluate_biome(origin_x + lx0 + 0.5, origin_z + lz0 + 0.5)

			var wy00 = w_data.water_corners[0]
			var wy10 = w_data.water_corners[1]
			var wy01 = w_data.water_corners[2]
			var wy11 = w_data.water_corners[3]

			var wv00 = Vector3(lx0, wy00, lz0)
			var wv10 = Vector3(lx1, wy10, lz0)
			var wv01 = Vector3(lx0, wy01, lz1)
			var wv11 = Vector3(lx1, wy11, lz1)

			# Codificação de fluxo no atributo COLOR:
			# R, G = Direção da correnteza (0 a 1)
			# B = Turbulência (0.05 lago, 0.50 rampa, 1.00 cachoeira)
			# A = Bioma (para interpolação contínua no shader)
			var f_dir: Vector2 = w_data.flow_dir
			var flow_col = Color(
				f_dir.x * 0.5 + 0.5,
				f_dir.y * 0.5 + 0.5,
				w_data.turbulence,
				biome
			)

			# 1. Superfície Superior da Água (Plana ou em Rampa inclinada ao Sul)
			var wn1 = (wv01 - wv00).cross(wv10 - wv00).normalized()
			st.set_normal(wn1)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx0, lz0))
			st.add_vertex(wv00)

			st.set_normal(wn1)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(wv10)

			st.set_normal(wn1)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(wv01)

			var wn2 = (wv01 - wv10).cross(wv11 - wv10).normalized()
			st.set_normal(wn2)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(wv10)

			st.set_normal(wn2)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx1, lz1))
			st.add_vertex(wv11)

			st.set_normal(wn2)
			st.set_color(flow_col)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(wv01)

			# 2. Queda d'Água Vertical / Cachoeira ao Sul (Water_Fall_Vertical)
			# Cortina d'água vertical na aresta sul da célula (Z = lz1) voltada para o Sul (+Z)
			if w_data.is_waterfall:
				var fall_top_y = w_data.water_y
				var fall_bot_y = w_data.waterfall_base_y
				var fall_normal = Vector3.BACK # Flui e aponta em direção a +Z (Sul)

				var fall_col = Color(
					0.0 * 0.5 + 0.5,
					1.0 * 0.5 + 0.5,
					1.0, # Turbulência máxima absoluta (ativa espuma branca densa)
					biome
				)

				# Parede vertical de queda d'água na aresta sul Z = lz1
				var fv_top_0 = Vector3(lx0, fall_top_y, lz1)
				var fv_top_1 = Vector3(lx1, fall_top_y, lz1)
				var fv_bot_0 = Vector3(lx0, fall_bot_y, lz1)
				var fv_bot_1 = Vector3(lx1, fall_bot_y, lz1)

				# Triângulo 1 (CCW)
				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(fv_top_0)

				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(0, 1))
				st.add_vertex(fv_bot_0)

				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(1, 0))
				st.add_vertex(fv_top_1)

				# Triângulo 2 (CCW)
				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(1, 0))
				st.add_vertex(fv_top_1)

				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(0, 1))
				st.add_vertex(fv_bot_0)

				st.set_normal(fall_normal)
				st.set_color(fall_col)
				st.set_uv(Vector2(1, 1))
				st.add_vertex(fv_bot_1)

	if not has_any_water:
		return null

	return st.commit()

# =========================================================================
# 4. COLORIZAÇÃO E ESTRATIGRAFIA GEOLÓGICA
# =========================================================================

func _get_top_color(biome: float, normal: Vector3, is_submerged: bool) -> Color:
	if is_submerged:
		# Leito de areia/sedimento molhado sob a lâmina d'água
		return COL_WHITE_SAND_WET.lerp(COL_TERRA_PRETA, biome * 0.7)

	var col_campina = COL_WHITE_SAND_LIGHT if normal.y > 0.85 else COL_WHITE_SAND_MID
	var col_floresta = COL_SERRAPILHEIRA
	return col_campina.lerp(col_floresta, biome)

func _get_wall_color(biome: float, depth_from_top: float) -> Color:
	if depth_from_top <= 0.5:
		return COL_WHITE_SAND_MID.lerp(COL_TERRA_PRETA, biome)
	elif depth_from_top <= 2.5:
		return COL_WHITE_SAND_MID.lerp(COL_LATERITA_CLAY, biome)
	else:
		return COL_GRANITO_MID

func _build_lateral_walls(st: SurfaceTool, origin_x: float, origin_z: float, ix: int, iz: int,
		lx0: float, lx1: float, lz0: float, lz1: float,
		y00: float, y10: float, y01: float, y11: float, biome: float) -> void:

	var neighbor_y_x0 = evaluate_snapped_height(origin_x + lx1 + 1.0, origin_z + lz0)
	var neighbor_y_x1 = evaluate_snapped_height(origin_x + lx1 + 1.0, origin_z + lz1)
	var bot_y0 = min(y10, neighbor_y_x0)
	var bot_y1 = min(y11, neighbor_y_x1)

	if y10 > neighbor_y_x0 or y11 > neighbor_y_x1:
		_add_quad_wall(st,
			Vector3(lx1, y10, lz0), Vector3(lx1, y11, lz1),
			Vector3(lx1, bot_y0, lz0), Vector3(lx1, bot_y1, lz1),
			Vector3.RIGHT, biome)

	var neighbor_y_nx0 = evaluate_snapped_height(origin_x + lx0 - 1.0, origin_z + lz0)
	var neighbor_y_nx1 = evaluate_snapped_height(origin_x + lx0 - 1.0, origin_z + lz1)
	var nbot_y0 = min(y00, neighbor_y_nx0)
	var nbot_y1 = min(y01, neighbor_y_nx1)

	if y00 > neighbor_y_nx0 or y01 > neighbor_y_nx1:
		_add_quad_wall(st,
			Vector3(lx0, y01, lz1), Vector3(lx0, y00, lz0),
			Vector3(lx0, nbot_y1, lz1), Vector3(lx0, nbot_y0, lz0),
			Vector3.LEFT, biome)

	var neighbor_y_z0 = evaluate_snapped_height(origin_x + lx0, origin_z + lz1 + 1.0)
	var neighbor_y_z1 = evaluate_snapped_height(origin_x + lx1, origin_z + lz1 + 1.0)
	var zbot_y0 = min(y01, neighbor_y_z0)
	var zbot_y1 = min(y11, neighbor_y_z1)

	if y01 > neighbor_y_z0 or y11 > neighbor_y_z1:
		_add_quad_wall(st,
			Vector3(lx1, y11, lz1), Vector3(lx0, y01, lz1),
			Vector3(lx1, zbot_y1, lz1), Vector3(lx0, zbot_y0, lz1),
			Vector3.BACK, biome)

	var neighbor_y_nz0 = evaluate_snapped_height(origin_x + lx0, origin_z + lz0 - 1.0)
	var neighbor_y_nz1 = evaluate_snapped_height(origin_x + lx1, origin_z + lz0 - 1.0)
	var nzbot_y0 = min(y00, neighbor_y_nz0)
	var nzbot_y1 = min(y10, neighbor_y_nz1)

	if y00 > neighbor_y_nz0 or y10 > neighbor_y_nz1:
		_add_quad_wall(st,
			Vector3(lx0, y00, lz0), Vector3(lx1, y10, lz0),
			Vector3(lx0, nzbot_y0, lz0), Vector3(lx1, nzbot_y1, lz0),
			Vector3.FORWARD, biome)

func _add_quad_wall(st: SurfaceTool, top_left: Vector3, top_right: Vector3,
		bot_left: Vector3, bot_right: Vector3, normal: Vector3, biome: float) -> void:
	if top_left.is_equal_approx(bot_left) and top_right.is_equal_approx(bot_right):
		return

	var col = _get_wall_color(biome, 1.2)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(top_left)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(top_right)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(bot_left)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(top_right)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(bot_right)

	st.set_normal(normal)
	st.set_color(col)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(bot_left)
