@tool
extends Node3D
class_name TransicaoSolos16x16Geometry

## Geometria da Cena de Teste de Transição de Solos 16x16m
## Foco: Areia Branca, Terra Preta, Serrapilheira (tex_serrapilheira.png), Latossolo Vermelho e Granito
## Topografia: Planos, Rampas Multi-Angulares (15°, 30°, 45°) e Cortes Verticais de 90°
## Grade: Modular 1x1x1m com Snapping Vertical estrito de 0.25m (Sem micro-voxels)
## Arquitetura Técnica: HD Pixel Art 3D (David Holland)

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const TEX_SERRAPILHEIRA = preload("res://tex_serrapilheira.png")

const SNAP_V: float = 0.25 # Snap vertical de 0.25m
const SNAP_H: float = 1.00 # Snap horizontal de 1.00m

# =========================================================================
# PALETA PEDOLÓGICA E GEOLÓGICA OFICIAL (Kit de Biomas Tropicais)
# =========================================================================

# 1. Areia Branca (Campinarana / Espodossolo Quartzarênico Lixiviado)
const COL_AREIA_LUZ    = Color(0.87, 0.85, 0.82) # Areia Branca iluminada (#DEDAD2)
const COL_AREIA_MID    = Color(0.72, 0.70, 0.66) # Areia Branca meia-luz (#B8B3A8)
const COL_AREIA_WET    = Color(0.55, 0.53, 0.49) # Areia úmida / sombra (#8C877E)

# 2. Terra Preta (Horizonte A / Humo Vegetal / Terra Preta de Índio)
const COL_TERRA_TOPO   = Color(0.12, 0.10, 0.09) # Húmus superficial rico (#1E1916)
const COL_TERRA_MID    = Color(0.16, 0.13, 0.12) # Camada média bioturbada (#29221E)
const COL_TERRA_TRANS  = Color(0.22, 0.16, 0.13) # Transição de horizonte (#382A22)

# 3. Serrapilheira (Horizonte O / Tapete de Folhas e Gravetos Úmidos)
const COL_SERRA_BASE   = Color(0.17, 0.11, 0.08) # Chão orgânico base (#2B1D14)
const COL_SERRA_SECA   = Color(0.55, 0.23, 0.17) # Folhas secas avermelhadas (#8C3B2B)
const COL_SERRA_OCRE   = Color(0.72, 0.53, 0.18) # Folhas ocre/amarelas (#B8862D)
const COL_SERRA_MUSGO  = Color(0.24, 0.36, 0.16) # Folhagem verde / musgo (#3E5C2A)

# 4. Latossolo Vermelho (Horizonte B / Laterita / Piçarra Ferrosa)
const COL_LATO_MATRIZ  = Color(0.58, 0.24, 0.14) # Argila lixiviada avermelhada (#8F3A24)
const COL_LATO_CLARO   = Color(0.66, 0.27, 0.17) # Argila vermelha clara/seca (#A8462B)
const COL_LATO_PICARRA = Color(0.29, 0.12, 0.09) # Nódulo de hematita endurecido (#4A1E17)
const COL_LATO_OCRE    = Color(0.76, 0.42, 0.16) # Ocre limonita (#C26B29)

# 5. Granito / Rocha Matriz (Horizonte C / Saprolito e Embasamento Cristalino)
const COL_GRAN_CLARO   = Color(0.43, 0.42, 0.40) # Granito cinza intemperizado (#6E6A66)
const COL_GRAN_ROSADO  = Color(0.52, 0.47, 0.44) # Feldspato rosado (#857870)
const COL_GRAN_VEIO    = Color(0.29, 0.28, 0.27) # Veios de mica/quartzo (#4A4745)
const COL_GRAN_ESCURO  = Color(0.18, 0.20, 0.22) # Basalto/Saprolito profundo (#2E3338)

var terrain_instance: MeshInstance3D

func _ready() -> void:
	generate_scene()

func generate_scene() -> void:
	for child in get_children():
		child.queue_free()

	var terrain_mesh = build_terrain_mesh()
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

		# Ativação do mapeamento de Serrapilheira via Alpha dos Vértices
		mat_surface.set_shader_parameter("use_top_texture", true)
		mat_surface.set_shader_parameter("use_vertex_alpha_for_texture", true)
		mat_surface.set_shader_parameter("top_albedo_texture", TEX_SERRAPILHEIRA)
		mat_surface.set_shader_parameter("top_texture_scale", 0.40)

		terrain_instance.material_override = mat_surface
		# Centraliza a malha 16x16m em [-8m, +8m]
		terrain_instance.position = Vector3(-8.0, 0.0, -8.0)
		add_child(terrain_instance)

	print("Cena de Transição de Solos 16x16m gerada com sucesso!")

# =========================================================================
# MODELO TOPOGRÁFICO DAS ALTURAS DE CÉLULAS (Planos, Rampas e Falésias)
# =========================================================================

## Retorna os 4 cantos de altura [y00, y10, y01, y11] da célula (ix, iz)
## Garantia: todas as cotas são estritamente quantizadas em múltiplos de 0.25m
func get_cell_corners(ix: int, iz: int) -> Array[float]:
	# =============================================================
	# 1. PISTA 1: RAMPA SUAVE DE 15° (ix in [0, 3])
	# Teste: Areia Branca -> Terra Preta -> Serrapilheira
	# =============================================================
	if ix <= 3:
		# iz in [0, 6]: Terraço Noroeste de Planos em Y = 1.00m
		if iz <= 6:
			return [1.00, 1.00, 1.00, 1.00]
		# iz == 7: Patamar em Y = 1.25m
		elif iz == 7:
			return [1.25, 1.25, 1.25, 1.25]
		# iz == 8: Rampa 15° descendo para o Sul (1.25 -> 1.00m)
		elif iz == 8:
			return [1.25, 1.25, 1.00, 1.00]
		# iz == 9: Rampa 15° descendo para o Sul (1.00 -> 0.75m)
		elif iz == 9:
			return [1.00, 1.00, 0.75, 0.75]
		# iz == 10: Rampa 15° descendo para o Sul (0.75 -> 0.50m)
		elif iz == 10:
			return [0.75, 0.75, 0.50, 0.50]
		# iz in [11, 15]: Base plana em Y = 0.50m
		else:
			return [0.50, 0.50, 0.50, 0.50]

	# =============================================================
	# 2. PISTA 2: RAMPA MÉDIA DE 30° (ix in [4, 7])
	# Teste: Terra Preta -> Serrapilheira -> Latossolo Vermelho
	# =============================================================
	elif ix <= 7:
		# iz in [0, 5]: Terraço Noroeste de Planos em Y = 1.00m
		if iz <= 5:
			return [1.00, 1.00, 1.00, 1.00]
		# iz == 6: Patamar em Y = 1.50m
		elif iz == 6:
			return [1.50, 1.50, 1.50, 1.50]
		# iz == 7: Patamar em Y = 2.00m
		elif iz == 7:
			return [2.00, 2.00, 2.00, 2.00]
		# iz == 8: Rampa 30° descendo para o Sul (2.00 -> 1.50m)
		elif iz == 8:
			return [2.00, 2.00, 1.50, 1.50]
		# iz == 9: Rampa 30° descendo para o Sul (1.50 -> 1.00m)
		elif iz == 9:
			return [1.50, 1.50, 1.00, 1.00]
		# iz == 10: Rampa 30° descendo para o Sul (1.00 -> 0.50m)
		elif iz == 10:
			return [1.00, 1.00, 0.50, 0.50]
		# iz in [11, 15]: Base plana em Y = 0.50m
		else:
			return [0.50, 0.50, 0.50, 0.50]

	# =============================================================
	# 3. PISTA 3: RAMPA ÍNGREME DE 45° (ix in [8, 11])
	# Teste: Latossolo Vermelho -> Granito / Rocha Matriz
	# =============================================================
	elif ix <= 11:
		# iz in [0, 7]: Platô Superior em Y = 2.50m
		if iz <= 7:
			return [2.50, 2.50, 2.50, 2.50]
		# iz == 8: Rampa 45° descendo para o Sul (2.50 -> 1.50m)
		elif iz == 8:
			return [2.50, 2.50, 1.50, 1.50]
		# iz == 9: Rampa 45° descendo para o Sul (1.50 -> 0.50m)
		elif iz == 9:
			return [1.50, 1.50, 0.50, 0.50]
		# iz in [10, 15]: Base plana em Y = 0.50m
		else:
			return [0.50, 0.50, 0.50, 0.50]

	# =============================================================
	# 4. PISTA 4: CORTES VERTICAIS DE 90° E DEGRAUS (ix in [12, 15])
	# Teste: Falésias de Granito e Degraus Modulares 1x1x1m
	# =============================================================
	else:
		# iz in [0, 7]: Platô Superior Alto de Granito
		if iz <= 7:
			if ix <= 13:
				return [2.75, 2.75, 2.75, 2.75]
			else:
				return [3.00, 3.00, 3.00, 3.00]
		# iz in [8, 9]: Degrau Modular 1 em Y = 1.50m
		# (Corte vertical de 1.25m em iz = 7 -> 8)
		elif iz <= 9:
			return [1.50, 1.50, 1.50, 1.50]
		# iz in [10, 15]: Base plana em Y = 0.50m
		# (Corte vertical de 1.00m em iz = 9 -> 10)
		else:
			return [0.50, 0.50, 0.50, 0.50]

# =========================================================================
# MODELO PEDOLÓGICO: ATRIBUIÇÃO DE SOLOS E ATRIBUTOS DE VÉRTICE
# =========================================================================

## Retorna { "color": Color, "alpha": float, "soil": String }
## O canal Alpha determina o peso da textura tex_serrapilheira.png no topo
func get_cell_soil_info(ix: int, iz: int, tri_idx: int) -> Dictionary:
	var seed_val = ix * 37 + iz * 101 + tri_idx * 13
	var jitter = 0.95 + 0.10 * fposmod(sin(float(seed_val)) * 43758.5453, 1.0)

	# -------------------------------------------------------------
	# 1. ZONA NORTE: TERRAÇO DOS PLANOS (iz <= 6 e ix <= 7)
	# -------------------------------------------------------------
	if iz <= 6 and ix <= 7:
		if ix <= 1:
			# Areia Branca pura
			var col = COL_AREIA_LUZ.lerp(COL_AREIA_MID, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Areia Branca" }
		elif ix == 2:
			# Transição Areia Branca -> Terra Preta
			var col = COL_AREIA_MID.lerp(COL_TERRA_TRANS, 0.55)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Transição Areia-Terra" }
		elif ix == 3:
			# Terra Preta pura
			var col = COL_TERRA_TOPO.lerp(COL_TERRA_MID, fposmod(float(seed_val), 1.0) * 0.4)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Terra Preta" }
		elif ix == 4:
			# Transição Terra Preta -> Serrapilheira (folhas começando a cobrir)
			var col = COL_TERRA_MID.lerp(COL_SERRA_BASE, 0.5)
			return { "color": col * jitter, "alpha": 0.65, "soil": "Transição Terra-Serrapilheira" }
		elif ix == 5:
			# Serrapilheira densa (100% folhas no topo)
			return { "color": COL_SERRA_BASE * jitter, "alpha": 1.0, "soil": "Serrapilheira" }
		elif ix == 6:
			# Transição Serrapilheira -> Latossolo Vermelho
			var col = COL_SERRA_BASE.lerp(COL_LATO_MATRIZ, 0.5)
			return { "color": col * jitter, "alpha": 0.45, "soil": "Transição Serrapilheira-Latossolo" }
		else:
			# ix == 7: Latossolo Vermelho puro
			var col = COL_LATO_MATRIZ.lerp(COL_LATO_CLARO, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Latossolo Vermelho" }

	# -------------------------------------------------------------
	# 2. PLATÔ ALTO NORDESTE (iz <= 7 e ix >= 8)
	# -------------------------------------------------------------
	if iz <= 7 and ix >= 8:
		if ix <= 9:
			# Serrapilheira de Platô Alto
			return { "color": COL_SERRA_BASE * jitter, "alpha": 1.0, "soil": "Serrapilheira Alto" }
		elif ix <= 11:
			# Latossolo Vermelho com nódulos de piçarra
			var is_nodule = fposmod(float(seed_val), 1.0) > 0.65
			var col = COL_LATO_PICARRA if is_nodule else COL_LATO_MATRIZ
			return { "color": col * jitter, "alpha": 0.0, "soil": "Latossolo Plíntico" }
		elif ix <= 13:
			# Granito Nível 1
			var col = COL_GRAN_CLARO.lerp(COL_GRAN_ROSADO, fposmod(float(seed_val), 1.0) * 0.4)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Granito" }
		else:
			# Granito Nível 2 (Pico rochoso)
			var col = COL_GRAN_ROSADO.lerp(COL_GRAN_VEIO, fposmod(float(seed_val), 1.0) * 0.35)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Granito Pico" }

	# -------------------------------------------------------------
	# 3. PISTA 1: RAMPAS E BASE (ix <= 3, iz >= 7)
	# -------------------------------------------------------------
	if ix <= 3:
		if iz == 7:
			return { "color": COL_SERRA_BASE * jitter, "alpha": 1.0, "soil": "Serrapilheira Patamar" }
		elif iz == 8:
			var col = COL_SERRA_BASE.lerp(COL_TERRA_MID, 0.5)
			return { "color": col * jitter, "alpha": 0.50, "soil": "Rampa 15° Serrapilheira-Terra" }
		elif iz == 9:
			var col = COL_TERRA_TOPO.lerp(COL_TERRA_MID, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Rampa 15° Terra Preta" }
		elif iz == 10:
			var col = COL_TERRA_TRANS.lerp(COL_AREIA_MID, 0.5)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Rampa 15° Terra-Areia" }
		else:
			# iz in [11, 15]: Base plana de Areia Branca
			var col = COL_AREIA_LUZ.lerp(COL_AREIA_MID, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Base Areia Branca" }

	# -------------------------------------------------------------
	# 4. PISTA 2: RAMPAS E BASE (ix in [4, 7], iz >= 6)
	# -------------------------------------------------------------
	elif ix <= 7:
		if iz == 6:
			var col = COL_SERRA_BASE.lerp(COL_LATO_MATRIZ, 0.4)
			return { "color": col * jitter, "alpha": 0.65, "soil": "Patamar 30° Serrapilheira" }
		elif iz == 7:
			var is_nodule = fposmod(float(seed_val), 1.0) > 0.65
			var col = COL_LATO_PICARRA if is_nodule else COL_LATO_MATRIZ
			return { "color": col * jitter, "alpha": 0.0, "soil": "Patamar 30° Latossolo" }
		elif iz == 8:
			var col = COL_LATO_MATRIZ.lerp(COL_LATO_CLARO, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Rampa 30° Latossolo" }
		elif iz == 9:
			var col = COL_LATO_MATRIZ.lerp(COL_SERRA_BASE, 0.5)
			return { "color": col * jitter, "alpha": 0.50, "soil": "Rampa 30° Latossolo-Serrapilheira" }
		elif iz == 10:
			var col = COL_SERRA_BASE.lerp(COL_TERRA_TOPO, 0.5)
			return { "color": col * jitter, "alpha": 0.30, "soil": "Rampa 30° Serrapilheira-Terra" }
		else:
			# iz in [11, 15]: Base plana de Terra Preta
			var col = COL_TERRA_TOPO.lerp(COL_TERRA_MID, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Base Terra Preta" }

	# -------------------------------------------------------------
	# 5. PISTA 3: RAMPAS E BASE (ix in [8, 11], iz >= 8)
	# -------------------------------------------------------------
	elif ix <= 11:
		if iz == 8:
			var col = COL_GRAN_CLARO.lerp(COL_LATO_MATRIZ, 0.4)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Rampa 45° Granito-Latossolo" }
		elif iz == 9:
			var col = COL_GRAN_CLARO.lerp(COL_GRAN_VEIO, 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Rampa 45° Granito" }
		else:
			# iz in [10, 15]: Base plana de Latossolo Vermelho
			var col = COL_LATO_MATRIZ.lerp(COL_LATO_CLARO, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Base Latossolo" }

	# -------------------------------------------------------------
	# 6. PISTA 4: CORTES VERTICAIS E DEGRAUS (ix in [12, 15], iz >= 8)
	# -------------------------------------------------------------
	else:
		if iz <= 9:
			# Degrau 1 em Y = 1.50m: Granito Tropical
			var col = COL_GRAN_CLARO.lerp(COL_GRAN_ROSADO, fposmod(float(seed_val), 1.0) * 0.4)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Degrau Granito" }
		else:
			# Base plana em Y = 0.50m: Granito / Basalto escuro
			var col = COL_GRAN_ESCURO.lerp(COL_GRAN_VEIO, fposmod(float(seed_val), 1.0) * 0.3)
			return { "color": col * jitter, "alpha": 0.0, "soil": "Base Granito/Basalto" }

# =========================================================================
# COLORIZAÇÃO ESTRATIGRÁFICA DE PAREDÕES VERTICAIS (Cortes 90°)
# =========================================================================

## Retorna a cor do estrato geológico na parede vertical baseado na cota Y e posição
func get_wall_stratum_color(ix: int, iz: int, y_cur: float, y_top: float) -> Color:
	var seed_val = ix * 43 + iz * 89 + int(y_cur * 16.0) * 17
	var jitter = 0.95 + 0.10 * fposmod(sin(float(seed_val)) * 43758.5453, 1.0)

	# Se for na zona pura de Granito (ix >= 12)
	if ix >= 12:
		var is_vein = fposmod(float(seed_val), 1.0) > 0.70
		var col = COL_GRAN_VEIO if is_vein else COL_GRAN_CLARO
		return col * jitter

	# Se for na zona de Areia Branca (ix <= 2)
	if ix <= 2:
		if y_cur >= y_top - 0.50:
			return COL_AREIA_MID * jitter
		elif y_cur >= y_top - 1.75:
			return COL_LATO_MATRIZ * jitter
		else:
			return COL_GRAN_CLARO * jitter

	# Estratigrafia Padrão de Floresta Tropical:
	# 1. Camada Superior (0.0 a -0.50m do topo): Terra Preta (Horizonte A)
	if y_cur >= y_top - 0.50:
		return COL_TERRA_TOPO.lerp(COL_TERRA_MID, fposmod(float(seed_val), 1.0) * 0.3) * jitter

	# 2. Camada Média (-0.50m a -1.75m do topo): Latossolo Vermelho Plíntico (Horizonte B)
	elif y_cur >= y_top - 1.75:
		var is_picarra = fposmod(float(seed_val), 1.0) > 0.65
		var col = COL_LATO_PICARRA if is_picarra else COL_LATO_MATRIZ
		return col * jitter

	# 3. Camada Profunda (> -1.75m do topo): Granito / Rocha Matriz (Horizonte C / Saprolito)
	else:
		var is_dark = fposmod(float(seed_val), 1.0) > 0.60
		var col = COL_GRAN_ESCURO if is_dark else COL_GRAN_CLARO
		return col * jitter

# =========================================================================
# CONSTRUÇÃO DA MALHA MODULAR (SURFACE TOOL)
# =========================================================================

func build_terrain_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Mapeia as alturas dos cantos de todas as 16x16 células
	var cell_corners_grid: Array = []
	for iz in range(16):
		var row: Array = []
		for ix in range(16):
			row.append(get_cell_corners(ix, iz))
		cell_corners_grid.append(row)

	# 2. Gera os topos (Faces Superiores) das 16x16 células
	for iz in range(16):
		for ix in range(16):
			var corners: Array[float] = cell_corners_grid[iz][ix]
			var y00 = corners[0]
			var y10 = corners[1]
			var y01 = corners[2]
			var y11 = corners[3]

			var lx0 = float(ix) * SNAP_H
			var lx1 = float(ix + 1) * SNAP_H
			var lz0 = float(iz) * SNAP_H
			var lz1 = float(iz + 1) * SNAP_H

			var v00 = Vector3(lx0, y00, lz0)
			var v10 = Vector3(lx1, y10, lz0)
			var v01 = Vector3(lx0, y01, lz1)
			var v11 = Vector3(lx1, y11, lz1)

			# Triângulo 1 (CCW: v00 -> v10 -> v01)
			var n1 = (v01 - v00).cross(v10 - v00).normalized()
			if n1.y < 0.0: n1 = -n1
			var s_info1 = get_cell_soil_info(ix, iz, 1)
			var col1 = Color(s_info1.color.r, s_info1.color.g, s_info1.color.b, s_info1.alpha)

			st.set_normal(n1)
			st.set_color(col1)
			st.set_uv(Vector2(lx0, lz0))
			st.add_vertex(v00)

			st.set_normal(n1)
			st.set_color(col1)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(n1)
			st.set_color(col1)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

			# Triângulo 2 (CCW: v10 -> v11 -> v01)
			var n2 = (v11 - v10).cross(v01 - v10).normalized()
			if n2.y < 0.0: n2 = -n2
			var s_info2 = get_cell_soil_info(ix, iz, 2)
			var col2 = Color(s_info2.color.r, s_info2.color.g, s_info2.color.b, s_info2.alpha)

			st.set_normal(n2)
			st.set_color(col2)
			st.set_uv(Vector2(lx1, lz0))
			st.add_vertex(v10)

			st.set_normal(n2)
			st.set_color(col2)
			st.set_uv(Vector2(lx1, lz1))
			st.add_vertex(v11)

			st.set_normal(n2)
			st.set_color(col2)
			st.set_uv(Vector2(lx0, lz1))
			st.add_vertex(v01)

			# -------------------------------------------------------------
			# 3. PAREDÕES E CORTES VERTICAIS ENTRE CÉLULAS VIZINHAS (90°)
			# -------------------------------------------------------------

			# A. Parede ao Sul (+Z): se esta célula for mais alta que a vizinha do sul em lz1
			if iz < 15:
				var s_corners: Array[float] = cell_corners_grid[iz + 1][ix]
				var bot_y0 = s_corners[0] # canto norte-oeste do vizinho
				var bot_y1 = s_corners[1] # canto norte-leste do vizinho
				if y01 > bot_y0 + 0.001 or y11 > bot_y1 + 0.001:
					_build_stratified_wall(st, ix, iz,
						Vector3(lx0, y01, lz1), Vector3(lx1, y11, lz1),
						Vector3(lx0, bot_y0, lz1), Vector3(lx1, bot_y1, lz1),
						Vector3.BACK)
			else:
				# Borda extrema Sul do mapa: saia vertical até Y = 0.0m
				_build_stratified_wall(st, ix, iz,
					Vector3(lx0, y01, lz1), Vector3(lx1, y11, lz1),
					Vector3(lx0, 0.0, lz1), Vector3(lx1, 0.0, lz1),
					Vector3.BACK)

			# B. Parede ao Norte (-Z): se esta célula for mais alta que a vizinha do norte em lz0
			if iz > 0:
				var n_corners: Array[float] = cell_corners_grid[iz - 1][ix]
				var n_bot_y0 = n_corners[2] # canto sul-oeste do vizinho
				var n_bot_y1 = n_corners[3] # canto sul-leste do vizinho
				if y00 > n_bot_y0 + 0.001 or y10 > n_bot_y1 + 0.001:
					_build_stratified_wall(st, ix, iz,
						Vector3(lx1, y10, lz0), Vector3(lx0, y00, lz0),
						Vector3(lx1, n_bot_y1, lz0), Vector3(lx0, n_bot_y0, lz0),
						Vector3.FORWARD)
			else:
				# Borda extrema Norte do mapa: saia vertical até Y = 0.0m
				_build_stratified_wall(st, ix, iz,
					Vector3(lx1, y10, lz0), Vector3(lx0, y00, lz0),
					Vector3(lx1, 0.0, lz0), Vector3(lx0, 0.0, lz0),
					Vector3.FORWARD)

			# C. Parede a Leste (+X): se esta célula for mais alta que a vizinha do leste em lx1
			if ix < 15:
				var e_corners: Array[float] = cell_corners_grid[iz][ix + 1]
				var e_bot_y0 = e_corners[0] # canto norte-oeste do vizinho
				var e_bot_y1 = e_corners[2] # canto sul-oeste do vizinho
				if y10 > e_bot_y0 + 0.001 or y11 > e_bot_y1 + 0.001:
					_build_stratified_wall(st, ix, iz,
						Vector3(lx1, y11, lz1), Vector3(lx1, y10, lz0),
						Vector3(lx1, e_bot_y1, lz1), Vector3(lx1, e_bot_y0, lz0),
						Vector3.RIGHT)
			else:
				# Borda extrema Leste do mapa: saia vertical até Y = 0.0m
				_build_stratified_wall(st, ix, iz,
					Vector3(lx1, y11, lz1), Vector3(lx1, y10, lz0),
					Vector3(lx1, 0.0, lz1), Vector3(lx1, 0.0, lz0),
					Vector3.RIGHT)

			# D. Parede a Oeste (-X): se esta célula for mais alta que a vizinha do oeste em lx0
			if ix > 0:
				var w_corners: Array[float] = cell_corners_grid[iz][ix - 1]
				var w_bot_y0 = w_corners[1] # canto norte-leste do vizinho
				var w_bot_y1 = w_corners[3] # canto sul-leste do vizinho
				if y00 > w_bot_y0 + 0.001 or y01 > w_bot_y1 + 0.001:
					_build_stratified_wall(st, ix, iz,
						Vector3(lx0, y00, lz0), Vector3(lx0, y01, lz1),
						Vector3(lx0, w_bot_y0, lz0), Vector3(lx0, w_bot_y1, lz1),
						Vector3.LEFT)
			else:
				# Borda extrema Oeste do mapa: saia vertical até Y = 0.0m
				_build_stratified_wall(st, ix, iz,
					Vector3(lx0, y00, lz0), Vector3(lx0, y01, lz1),
					Vector3(lx0, 0.0, lz0), Vector3(lx0, 0.0, lz1),
					Vector3.LEFT)

	return st.commit()

## Constrói um paredão vertical fatiado em estratos geológicos quantizados em 0.25m
func _build_stratified_wall(st: SurfaceTool, ix: int, iz: int,
		top_left: Vector3, top_right: Vector3,
		bot_left: Vector3, bot_right: Vector3,
		normal: Vector3) -> void:

	var h_top = max(top_left.y, top_right.y)
	var h_bot = min(bot_left.y, bot_right.y)

	if h_top <= h_bot + 0.001:
		return

	# Fatiamento vertical em bandas de 0.25m para revelar estratos nítidos
	var steps = int(round((h_top - h_bot) / SNAP_V))
	steps = max(steps, 1)

	for s in range(steps):
		var y_sub_top = h_top - float(s) * SNAP_V
		var y_sub_bot = max(h_bot, h_top - float(s + 1) * SNAP_V)
		if y_sub_top <= y_sub_bot + 0.001:
			continue

		var y_mid = (y_sub_top + y_sub_bot) * 0.5
		var col = get_wall_stratum_color(ix, iz, y_mid, h_top)
		# Alpha = 0.0 na parede (não recebe textura de folhas no plano vertical)
		var wall_col = Color(col.r, col.g, col.b, 0.0)

		# Interpolação geométrica dos 4 vértices do sub-quad
		var p_tl = Vector3(top_left.x, y_sub_top, top_left.z)
		var p_tr = Vector3(top_right.x, y_sub_top, top_right.z)
		var p_bl = Vector3(bot_left.x, y_sub_bot, bot_left.z)
		var p_br = Vector3(bot_right.x, y_sub_bot, bot_right.z)

		# Triângulos da parede vertical (front-facing)
		_add_triangle(st, p_tl, p_tr, p_bl, normal, wall_col)
		_add_triangle(st, p_tr, p_br, p_bl, normal, wall_col)

func _add_triangle(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, n: Vector3, c: Color) -> void:
	st.set_normal(n)
	st.set_color(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)

	st.set_normal(n)
	st.set_color(c)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(v1)

	st.set_normal(n)
	st.set_color(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(v2)
