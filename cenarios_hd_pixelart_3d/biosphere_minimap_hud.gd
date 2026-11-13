@tool
class_name BiosphereMinimapHUD
extends Control

## =========================================================================
## BiosphereMinimapHUD - Minimapa Tático, Bússola e Telemetria em Tempo Real
## =========================================================================
## Desenvolvido para o Eden Project (HD Pixel Art 3D / David Holland Architecture)
##
## Implementa uma interface tática retro/pixel art com telemetria viva:
## 1. Radar vetorial 2D desenhado a 60 FPS via _draw()
## 2. Diferenciação cromática e morfológica dos animais da Amazônia:
##    🔴 Vermelho: Onça-Pintada / Jaguatirica (Predadores)
##    🟢 Verde claro: Capivara / Cutia (Herbívoros)
##    🟡 Amarelo: Jabuti-da-mata (Quelônios)
##    🔵 Ciano brilhante: Harpia Amazônica (Aéreos)
## 3. Bússola azimutal e octantes cardeais (N, NE, E, SE, S, SW, W, NW) sincronizados com o CameraPivot
## 4. Coordenadas métricas em tempo real e rastreamento de chunks do WorldStreamingManager100x100
## 5. Tecla 'M': Alterna entre Minimapa Normal (Canto), Expandido (Centro) e Oculto
## 6. mouse_filter = MOUSE_FILTER_IGNORE para preservar total mobilidade do jogador/câmera

enum DisplayMode {
	CORNER = 0,    # Canto superior direito (compacto)
	EXPANDED = 1,  # Centralizado na tela (expandido)
	HIDDEN = 2     # Oculto
}

# =========================================================================
# CONSTANTES DE ESPÉCIES (Alinhadas ao AmazonBiosphereSimulator)
# =========================================================================
const ID_CUTIA: int = 1
const ID_JAGUATIRICA: int = 10
const ID_ONCA: int = 11
const ID_CAPIVARA: int = 12
const ID_HARPIA: int = 30
const ID_JABUTI: int = 50

# =========================================================================
# REFERÊNCIAS DE SISTEMAS DO EDEN PROJECT
# =========================================================================
@export_group("Referências Centrais")
## Nó do CameraPivot (para ler posição global e rotação Y / azimute da câmera)
@export var target_camera_pivot: Node3D

## Nó do AmazonBiosphereSimulator (para ler lista de agentes e desenhar blips)
@export var target_simulator: AmazonBiosphereSimulator

## Nó do WorldStreamingManager100x100 (para ler chunk atual cx, cz)
@export var target_streaming: WorldStreamingManager100x100

# =========================================================================
# CONFIGURAÇÕES DO RADAR E MODOS
# =========================================================================
@export_group("Configurações do Radar")
@export var current_mode: DisplayMode = DisplayMode.CORNER
@export var corner_range_meters: float = 100.0
@export var expanded_range_meters: float = 200.0
@export var corner_size: Vector2 = Vector2(230.0, 330.0)
@export var expanded_size: Vector2 = Vector2(380.0, 500.0)
@export var margin_screen: float = 16.0
@export var radar_shape_circle: bool = true
@export var show_distance_rings: bool = true
@export var show_crosshair: bool = true
@export var show_vision_cone: bool = true
@export var vision_cone_fov_deg: float = 45.0
@export var enable_radar_sweep: bool = true
@export var sweep_speed_rad: float = 1.6

# =========================================================================
# PALETA DE CORES RETRO PIXEL ART TÉCNICO (David Holland Pedology & UI)
# =========================================================================
@export_group("Paleta de Cores")
@export var color_bg_panel: Color = Color(0.04, 0.06, 0.05, 0.88)       # Verde-militar profundo translúcido
@export var color_bg_radar: Color = Color(0.02, 0.035, 0.025, 0.95)     # Fundo do tubo de radar
@export var color_border_gold: Color = Color(0.72, 0.53, 0.18, 1.0)     # Ocre latão clássico (#B8862D)
@export var color_border_green: Color = Color(0.24, 0.48, 0.28, 0.95)   # Verde folha amazônica (#3E7A47)
@export var color_crosshair: Color = Color(0.25, 0.52, 0.35, 0.35)      # Grade interna
@export var color_rings: Color = Color(0.28, 0.58, 0.38, 0.45)          # Anéis concêntricos
@export var color_camera_arrow: Color = Color(0.98, 0.88, 0.25, 1.0)    # Seta direcional central
@export var color_vision_cone: Color = Color(0.95, 0.92, 0.40, 0.12)    # Cone translúcido
@export var color_sweep_beam: Color = Color(0.35, 0.90, 0.55, 0.28)     # Feixe giratório de varredura

@export_group("Cores da Fauna")
@export var color_blip_predator: Color = Color(1.0, 0.22, 0.22, 0.98)   # 🔴 Predadores (Onça / Jaguatirica)
@export var color_blip_herbivore: Color = Color(0.32, 0.95, 0.38, 0.98) # 🟢 Herbívoros (Capivara / Cutia)
@export var color_blip_chelonia: Color = Color(0.98, 0.85, 0.15, 0.98)  # 🟡 Quelônio (Jabuti)
@export var color_blip_avian: Color = Color(0.12, 0.88, 1.0, 0.98)     # 🔵 Aéreo (Harpia)
@export var color_blip_diving: Color = Color(0.20, 0.65, 1.0, 0.90)    # Halo animal em mergulho

# =========================================================================
# NÓS DE INTERFACE (UI)
# =========================================================================
@export_group("Labels de Telemetria (Auto-gerados se nulos)")
@export var label_header: Label
@export var label_compass: Label
@export var label_coords: Label
@export var label_chunk: Label
@export var label_fauna: Label
@export var label_hint: Label

# Elementos internos de controle
var _telemetry_panel: VBoxContainer
var _sweep_angle: float = 0.0
var _current_fauna_count: int = 0
var _current_cam_pos: Vector3 = Vector3.ZERO
var _current_cam_forward: Vector3 = Vector3(0, 0, -1)
var _current_cam_yaw_deg: float = 0.0
var _current_chunk: Vector2i = Vector2i.ZERO
var _search_retry_timer: float = 0.0

# =========================================================================
# CICLO DE VIDA DO GODOT
# =========================================================================

func _ready() -> void:
	# Garantir que o HUD nunca capture cliques do mouse (visão e seleção 3D livres)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_internal_telemetry_ui()
	_auto_discover_references()
	_apply_layout()

func _unhandled_input(event: InputEvent) -> void:
	_handle_toggle_input(event)

func _input(event: InputEvent) -> void:
	# Garante resposta à tecla 'M' caso o input chegue pré-filtrado
	_handle_toggle_input(event)

func _handle_toggle_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed() and not event.is_echo() and event.keycode == KEY_M:
			cycle_minimap_mode()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Atualização do ângulo do feixe de varredura
	if enable_radar_sweep:
		_sweep_angle = wrapf(_sweep_angle + sweep_speed_rad * delta, 0.0, TAU)

	# Tentativa periódica de auto-descoberta caso nós ainda estejam nulos
	if target_camera_pivot == null or target_simulator == null or target_streaming == null:
		_search_retry_timer += delta
		if _search_retry_timer >= 1.0:
			_search_retry_timer = 0.0
			_auto_discover_references()

	# Leitura de telemetria
	_poll_telemetry_data()

	# Atualização visual da telemetria textual
	if current_mode != DisplayMode.HIDDEN:
		_update_telemetry_labels()

	# Requisito obrigatório: atualização contínua e suave a 60 FPS
	queue_redraw()

# =========================================================================
# CONTROLE DE MODOS E LAYOUT
# =========================================================================

## Alterna ciclicamente entre Canto, Expandido e Oculto
func cycle_minimap_mode() -> void:
	match current_mode:
		DisplayMode.CORNER:
			set_mode(DisplayMode.EXPANDED)
		DisplayMode.EXPANDED:
			set_mode(DisplayMode.HIDDEN)
		DisplayMode.HIDDEN:
			set_mode(DisplayMode.CORNER)

func set_mode(new_mode: DisplayMode) -> void:
	current_mode = new_mode
	_apply_layout()
	queue_redraw()

func _apply_layout() -> void:
	if current_mode == DisplayMode.HIDDEN:
		if _telemetry_panel:
			_telemetry_panel.visible = false
		return

	if _telemetry_panel:
		_telemetry_panel.visible = true

	match current_mode:
		DisplayMode.CORNER:
			# Ancorado no canto superior direito
			anchor_left = 1.0
			anchor_top = 0.0
			anchor_right = 1.0
			anchor_bottom = 0.0
			offset_left = -corner_size.x - margin_screen
			offset_top = margin_screen
			offset_right = -margin_screen
			offset_bottom = margin_screen + corner_size.y
			custom_minimum_size = corner_size
			size = corner_size

			if _telemetry_panel:
				var r_rad: float = minf(corner_size.x * 0.44, 75.0)
				var r_bottom: float = 14.0 + r_rad * 2.0 + 8.0
				_telemetry_panel.position = Vector2(8.0, r_bottom)
				_telemetry_panel.size = Vector2(corner_size.x - 16.0, corner_size.y - r_bottom - 8.0)

		DisplayMode.EXPANDED:
			# Centralizado na tela
			anchor_left = 0.5
			anchor_top = 0.5
			anchor_right = 0.5
			anchor_bottom = 0.5
			offset_left = -expanded_size.x * 0.5
			offset_top = -expanded_size.y * 0.5
			offset_right = expanded_size.x * 0.5
			offset_bottom = expanded_size.y * 0.5
			custom_minimum_size = expanded_size
			size = expanded_size

			if _telemetry_panel:
				var r_rad: float = minf(expanded_size.x * 0.42, 135.0)
				var r_bottom: float = 18.0 + r_rad * 2.0 + 10.0
				_telemetry_panel.position = Vector2(16.0, r_bottom)
				_telemetry_panel.size = Vector2(expanded_size.x - 32.0, expanded_size.y - r_bottom - 12.0)

# =========================================================================
# LEITURA DE TELEMETRIA
# =========================================================================

func _poll_telemetry_data() -> void:
	# 1. Posição e Orientação do CameraPivot
	if target_camera_pivot and is_instance_valid(target_camera_pivot):
		_current_cam_pos = target_camera_pivot.global_position
		var cam_basis: Basis = target_camera_pivot.global_transform.basis
		var forward_cand: Vector3 = -cam_basis.z
		if forward_cand.length_squared() > 0.0001:
			_current_cam_forward = forward_cand.normalized()
	elif get_viewport() and get_viewport().get_camera_3d():
		var cam_3d: Camera3D = get_viewport().get_camera_3d()
		_current_cam_pos = cam_3d.global_position
		_current_cam_forward = -cam_3d.global_transform.basis.z.normalized()

	# 2. Azimute / Bússola
	# No Godot 3D: Z negativo é NORTE (0, -1), X positivo é LESTE (1, 0)
	var azim_rad: float = atan2(_current_cam_forward.x, -_current_cam_forward.z)
	var azim_deg: float = rad_to_deg(azim_rad)
	if azim_deg < 0.0:
		azim_deg += 360.0
	_current_cam_yaw_deg = azim_deg

	# 3. Chunk do WorldStreamingManager
	if target_streaming and is_instance_valid(target_streaming):
		if "last_cam_chunk" in target_streaming and target_streaming.last_cam_chunk.x > -9000:
			_current_chunk = target_streaming.last_cam_chunk
		else:
			_current_chunk = Vector2i(int(floor(_current_cam_pos.x / 16.0)), int(floor(_current_cam_pos.z / 16.0)))
	else:
		_current_chunk = Vector2i(int(floor(_current_cam_pos.x / 16.0)), int(floor(_current_cam_pos.z / 16.0)))

func _update_telemetry_labels() -> void:
	var compass_cardinal: String = _get_cardinal_direction_name(_current_cam_yaw_deg)

	if label_compass:
		label_compass.text = "🧭 BÚSSOLA: %s" % compass_cardinal

	if label_coords:
		label_coords.text = "📍 COORDENADAS: X: %+06.1fm | Z: %+06.1fm | Y: %+05.1fm" % [
			_current_cam_pos.x,
			_current_cam_pos.z,
			_current_cam_pos.y
		]

	if label_chunk:
		label_chunk.text = "🗺️ CHUNK: [cx: %+03d, cz: %+03d] (Mundo 100x100)" % [
			_current_chunk.x,
			_current_chunk.y
		]

	if label_fauna:
		label_fauna.text = "🐾 FAUNA VISÍVEL: %d detectados no radar" % _current_fauna_count

	if label_hint:
		var mode_name: String = "CANTO" if current_mode == DisplayMode.CORNER else "EXPANDIDO"
		var rng: float = corner_range_meters if current_mode == DisplayMode.CORNER else expanded_range_meters
		label_hint.text = "[M] MODO: %s | ALCANCE: %dm" % [mode_name, int(rng)]

## Retorna a direção cardeal dominante e azimute preciso em graus
func _get_cardinal_direction_name(deg: float) -> String:
	var octant: int = int(round(deg / 45.0)) % 8
	var d_int: int = int(round(deg))
	match octant:
		0: return "NORTE [N - %03d°]" % d_int
		1: return "NORDESTE [NE - %03d°]" % d_int
		2: return "LESTE [E - %03d°]" % d_int
		3: return "SUDESTE [SE - %03d°]" % d_int
		4: return "SUL [S - %03d°]" % d_int
		5: return "SUDOESTE [SW - %03d°]" % d_int
		6: return "OESTE [W - %03d°]" % d_int
		7: return "NOROESTE [NW - %03d°]" % d_int
	return "NORTE [N - 000°]"

# =========================================================================
# RENDERIZAÇÃO VETORIAL DO RADAR (_draw)
# =========================================================================

func _draw() -> void:
	if current_mode == DisplayMode.HIDDEN:
		return

	var panel_rect: Rect2 = Rect2(Vector2.ZERO, size)

	# 1. Moldura e Fundo do Painel Retro Pixel Art
	_draw_retro_panel(panel_rect)

	# 2. Dimensões e Posição do Tubo de Radar
	var is_corner: bool = (current_mode == DisplayMode.CORNER)
	var radar_radius_px: float = minf(size.x * 0.44, 75.0) if is_corner else minf(size.x * 0.42, 135.0)
	var radar_center: Vector2 = Vector2(size.x * 0.5, (14.0 if is_corner else 18.0) + radar_radius_px)
	var world_range: float = corner_range_meters if is_corner else expanded_range_meters

	# 3. Fundo e Contorno do Radar
	if radar_shape_circle:
		draw_circle(radar_center, radar_radius_px, color_bg_radar)
		draw_arc(radar_center, radar_radius_px, 0.0, TAU, 64, color_border_gold, 2.0)
		draw_arc(radar_center, radar_radius_px - 2.0, 0.0, TAU, 64, color_border_green, 1.0)
	else:
		var r_box: Rect2 = Rect2(radar_center - Vector2(radar_radius_px, radar_radius_px), Vector2(radar_radius_px * 2.0, radar_radius_px * 2.0))
		draw_rect(r_box, color_bg_radar, true)
		draw_rect(r_box, color_border_gold, false, 2.0)
		draw_rect(r_box.grow(-2.0), color_border_green, false, 1.0)

	# 4. Grade Interna e Linhas de Mira (Crosshair)
	if show_crosshair:
		draw_line(Vector2(radar_center.x - radar_radius_px + 2.0, radar_center.y), Vector2(radar_center.x + radar_radius_px - 2.0, radar_center.y), color_crosshair, 1.0)
		draw_line(Vector2(radar_center.x, radar_center.y - radar_radius_px + 2.0), Vector2(radar_center.x, radar_center.y + radar_radius_px - 2.0), color_crosshair, 1.0)

	# 5. Anéis Concêntricos de Distância
	if show_distance_rings and radar_shape_circle:
		# Anel de 50% da distância
		draw_arc(radar_center, radar_radius_px * 0.5, 0.0, TAU, 48, color_rings, 1.0)
		if not is_corner:
			# Anéis auxiliares no modo expandido
			draw_arc(radar_center, radar_radius_px * 0.25, 0.0, TAU, 36, color_rings * Color(1, 1, 1, 0.5), 1.0)
			draw_arc(radar_center, radar_radius_px * 0.75, 0.0, TAU, 48, color_rings * Color(1, 1, 1, 0.5), 1.0)

	# 6. Indicadores Cardeais de Borda (N, S, L, O)
	_draw_cardinal_ticks(radar_center, radar_radius_px)

	# 7. Feixe Rotativo de Varredura (Sweep Beam)
	if enable_radar_sweep and radar_shape_circle:
		var sweep_dir: Vector2 = Vector2(cos(_sweep_angle), sin(_sweep_angle))
		draw_line(radar_center, radar_center + sweep_dir * (radar_radius_px - 2.0), color_sweep_beam, 1.5)

	# 8. Cone de Visão da Câmera (Field of View)
	# Mapeamento: Z negativo (Norte) = Y negativo na tela (Para cima)
	#             X positivo (Leste) = X positivo na tela (Para a direita)
	var cam_dir_2d: Vector2 = Vector2(_current_cam_forward.x, _current_cam_forward.z).normalized()
	if cam_dir_2d.length_squared() < 0.001:
		cam_dir_2d = Vector2(0.0, -1.0)

	if show_vision_cone:
		var cone_length: float = radar_radius_px * 0.78
		var half_fov_rad: float = deg_to_rad(vision_cone_fov_deg * 0.5)
		var v_left: Vector2 = cam_dir_2d.rotated(-half_fov_rad) * cone_length
		var v_right: Vector2 = cam_dir_2d.rotated(half_fov_rad) * cone_length

		var cone_pts: PackedVector2Array = PackedVector2Array([
			radar_center,
			radar_center + v_left,
			radar_center + cam_dir_2d * cone_length,
			radar_center + v_right
		])
		draw_colored_polygon(cone_pts, color_vision_cone)
		draw_line(radar_center, radar_center + v_left, Color(color_camera_arrow.r, color_camera_arrow.g, color_camera_arrow.b, 0.40), 1.0)
		draw_line(radar_center, radar_center + v_right, Color(color_camera_arrow.r, color_camera_arrow.g, color_camera_arrow.b, 0.40), 1.0)

	# 9. Seta Central Indicando a Orientação da Câmera
	_draw_camera_arrow(radar_center, cam_dir_2d)

	# 10. Blips Coloridos da Fauna em Tempo Real
	_draw_fauna_blips(radar_center, radar_radius_px, world_range)

## Desenha a moldura tática do painel estilo HD Pixel Art
func _draw_retro_panel(rect: Rect2) -> void:
	# Fundo escuro translúcido
	draw_rect(rect, color_bg_panel, true)

	# Borda externa ocre/latão dourado (2px)
	draw_rect(rect, color_border_gold, false, 2.0)

	# Borda interna verde musgo (1px)
	draw_rect(rect.grow(-3.0), color_border_green, false, 1.0)

	# Chanfros / Rebites nos 4 cantos
	var corner_margin: float = 6.0
	var rivet_color: Color = color_border_gold
	var rivets: Array[Vector2] = [
		Vector2(corner_margin, corner_margin),
		Vector2(rect.size.x - corner_margin, corner_margin),
		Vector2(corner_margin, rect.size.y - corner_margin),
		Vector2(rect.size.x - corner_margin, rect.size.y - corner_margin)
	]
	for r_pos in rivets:
		draw_rect(Rect2(r_pos - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), rivet_color, true)

## Desenha marcações cardeais (N, S, L, O) no radar
func _draw_cardinal_ticks(center: Vector2, radius: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_sz: int = 10

	# Norte (N) - Topo
	draw_string(font, center + Vector2(-4.0, -radius + 13.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, color_border_gold)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -radius + 4.0), color_border_gold, 2.0)

	# Sul (S) - Base
	draw_string(font, center + Vector2(-3.5, radius - 4.0), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, color_border_green)
	draw_line(center + Vector2(0.0, radius), center + Vector2(0.0, radius - 4.0), color_border_green, 1.5)

	# Leste (L) - Direita
	draw_string(font, center + Vector2(radius - 12.0, 4.0), "L", HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, color_border_green)
	draw_line(center + Vector2(radius, 0.0), center + Vector2(radius - 4.0, 0.0), color_border_green, 1.5)

	# Oeste (O) - Esquerda
	draw_string(font, center + Vector2(-radius + 4.0, 4.0), "O", HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, color_border_green)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(-radius + 4.0, 0.0), color_border_green, 1.5)

## Desenha a seta central com estilo bússola militar
func _draw_camera_arrow(center: Vector2, dir_2d: Vector2) -> void:
	var arrow_len: float = 12.0
	var perp: Vector2 = Vector2(-dir_2d.y, dir_2d.x)

	var p_tip: Vector2 = center + dir_2d * arrow_len
	var p_left: Vector2 = center - dir_2d * (arrow_len * 0.45) + perp * (arrow_len * 0.55)
	var p_notch: Vector2 = center - dir_2d * (arrow_len * 0.15)
	var p_right: Vector2 = center - dir_2d * (arrow_len * 0.45) - perp * (arrow_len * 0.55)

	var arrow_poly: PackedVector2Array = PackedVector2Array([p_tip, p_left, p_notch, p_right])
	draw_colored_polygon(arrow_poly, color_camera_arrow)
	draw_polyline(PackedVector2Array([p_tip, p_left, p_notch, p_right, p_tip]), Color(0.1, 0.12, 0.1, 0.95), 1.0)

## Desenha os blips dos animais ativos detectados no raio do radar
func _draw_fauna_blips(center: Vector2, radar_radius_px: float, world_range: float) -> void:
	_current_fauna_count = 0

	if target_simulator == null or not is_instance_valid(target_simulator):
		return

	# Acessa os agentes da simulação
	var ag_list: Array = []
	if "agents" in target_simulator and target_simulator.agents is Array:
		ag_list = target_simulator.agents

	if ag_list.is_empty():
		return

	var scale_factor: float = radar_radius_px / world_range

	for ag in ag_list:
		if ag == null:
			continue

		# Leitura flexível e segura dos atributos do agente
		var a_px: float = ag.pos_x if "pos_x" in ag else 0.0
		var a_pz: float = ag.pos_z if "pos_z" in ag else 0.0
		var a_sp: int = ag.species_id if "species_id" in ag else 1
		var a_hp: float = ag.health if "health" in ag else 100.0
		var a_state: int = ag.state if "state" in ag else 0
		var a_diving: bool = ag.is_diving if "is_diving" in ag else false

		# Ignorar animais mortos
		if a_hp <= 0.0 or a_state == 6: # STATE_DEAD = 6
			continue

		# Cálculo de distância euclidiana relativa ao centro da câmera
		var dx: float = a_px - _current_cam_pos.x
		var dz: float = a_pz - _current_cam_pos.z
		var dist: float = sqrt(dx * dx + dz * dz)

		# Filtrar por alcance do radar
		if dist > world_range:
			continue

		_current_fauna_count += 1

		# Coordenadas no espaço 2D do radar:
		# dx positivo (+X, Leste) -> desloca para a direita (+X tela)
		# dz negativo (-Z, Norte) -> desloca para cima (-Y tela)
		# dz positivo (+Z, Sul)   -> desloca para baixo (+Y tela)
		var blip_screen_pos: Vector2 = center + Vector2(dx, dz) * scale_factor

		# Garantir que o blip não transborde o disco caso esteja no limite
		if radar_shape_circle:
			var offset_from_center: Vector2 = blip_screen_pos - center
			if offset_from_center.length() > radar_radius_px - 3.0:
				blip_screen_pos = center + offset_from_center.normalized() * (radar_radius_px - 3.0)

		# Desenhar blip específico por guilda trófica / espécie
		match a_sp:
			ID_ONCA, ID_JAGUATIRICA:
				# 🔴 Vermelho: Predadores (Losango de perigo)
				var d_size: float = 4.2
				var diamond: PackedVector2Array = PackedVector2Array([
					blip_screen_pos + Vector2(0.0, -d_size),
					blip_screen_pos + Vector2(d_size, 0.0),
					blip_screen_pos + Vector2(0.0, d_size),
					blip_screen_pos + Vector2(-d_size, 0.0)
				])
				draw_colored_polygon(diamond, color_blip_predator)
				draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0.2, 0.05, 0.05, 0.9), 1.0)

			ID_CAPIVARA, ID_CUTIA:
				# 🟢 Verde claro: Herbívoros (Círculo biomassa)
				draw_circle(blip_screen_pos, 3.2, color_blip_herbivore)
				draw_arc(blip_screen_pos, 3.2, 0.0, TAU, 16, Color(0.05, 0.25, 0.1, 0.9), 1.0)

			ID_JABUTI:
				# 🟡 Amarelo: Quelônio (Quadrado carapaça)
				var sq_half: float = 2.8
				var sq_rect: Rect2 = Rect2(blip_screen_pos - Vector2(sq_half, sq_half), Vector2(sq_half * 2.0, sq_half * 2.0))
				draw_rect(sq_rect, color_blip_chelonia, true)
				draw_rect(sq_rect, Color(0.25, 0.20, 0.05, 0.9), false, 1.0)

			ID_HARPIA:
				# 🔵 Ciano brilhante: Aéreo (Glifo alado / silhueta de voo)
				var wing: float = 4.8
				var wing_pts: PackedVector2Array = PackedVector2Array([
					blip_screen_pos + Vector2(0.0, -wing),
					blip_screen_pos + Vector2(wing, wing * 0.7),
					blip_screen_pos + Vector2(0.0, wing * 0.25),
					blip_screen_pos + Vector2(-wing, wing * 0.7)
				])
				draw_colored_polygon(wing_pts, color_blip_avian)
				draw_polyline(PackedVector2Array([wing_pts[0], wing_pts[1], wing_pts[2], wing_pts[3], wing_pts[0]]), Color(0.05, 0.2, 0.3, 0.9), 1.0)

			_:
				# Padrão para outras espécies futuras
				draw_circle(blip_screen_pos, 2.5, Color.WHITE)

		# Indicador de mergulho aquático (anel pulsante/ciano)
		if a_diving:
			draw_arc(blip_screen_pos, 5.5, 0.0, TAU, 16, color_blip_diving, 1.2)

# =========================================================================
# CRIAÇÃO AUTOMÁTICA E ESTILIZAÇÃO DOS LABELS DE TELEMETRIA
# =========================================================================

func _setup_internal_telemetry_ui() -> void:
	if _telemetry_panel != null:
		return

	_telemetry_panel = VBoxContainer.new()
	_telemetry_panel.name = "TelemetryContainer"
	_telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telemetry_panel.add_theme_constant_override("separation", 2)
	add_child(_telemetry_panel)

	# Header tático
	if label_header == null:
		label_header = Label.new()
		label_header.name = "LblHeader"
		label_header.text = "🛰️ BIOSFERA RADAR HUD"
		label_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_header, color_border_gold, 11, true)
		_telemetry_panel.add_child(label_header)

	# Separador discreto
	var sep1: HSeparator = HSeparator.new()
	sep1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep1.modulate = Color(color_border_green.r, color_border_green.g, color_border_green.b, 0.5)
	_telemetry_panel.add_child(sep1)

	# 1. Bússola
	if label_compass == null:
		label_compass = Label.new()
		label_compass.name = "LblCompass"
		label_compass.text = "🧭 BÚSSOLA: NORTE [N - 000°]"
		label_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_compass, Color(0.92, 0.95, 0.88), 10, true)
		_telemetry_panel.add_child(label_compass)

	# 2. Coordenadas
	if label_coords == null:
		label_coords = Label.new()
		label_coords.name = "LblCoords"
		label_coords.text = "📍 COORDENADAS: X: +000.0m | Z: +000.0m | Y: +00.0m"
		label_coords.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_coords, Color(0.85, 0.92, 0.82), 10, false)
		_telemetry_panel.add_child(label_coords)

	# 3. Chunk
	if label_chunk == null:
		label_chunk = Label.new()
		label_chunk.name = "LblChunk"
		label_chunk.text = "🗺️ CHUNK: [cx: +00, cz: +00] (Mundo 100x100)"
		label_chunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_chunk, Color(0.85, 0.92, 0.82), 10, false)
		_telemetry_panel.add_child(label_chunk)

	# 4. Fauna Visível
	if label_fauna == null:
		label_fauna = Label.new()
		label_fauna.name = "LblFauna"
		label_fauna.text = "🐾 FAUNA VISÍVEL: 0 detectados no radar"
		label_fauna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_fauna, Color(0.4, 0.95, 0.55), 10, true)
		_telemetry_panel.add_child(label_fauna)

	# Separador inferior
	var sep2: HSeparator = HSeparator.new()
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep2.modulate = Color(color_border_green.r, color_border_green.g, color_border_green.b, 0.4)
	_telemetry_panel.add_child(sep2)

	# Legenda Rápida de Cores da Fauna
	var lbl_legend: Label = Label.new()
	lbl_legend.name = "LblLegend"
	lbl_legend.text = "🔴 Pred | 🟢 Herb | 🟡 Jabuti | 🔵 Harpia"
	lbl_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_style(lbl_legend, Color(0.70, 0.75, 0.70), 9, false)
	_telemetry_panel.add_child(lbl_legend)

	# Dica de Tecla [M]
	if label_hint == null:
		label_hint = Label.new()
		label_hint.name = "LblHint"
		label_hint.text = "[M] MODO: CANTO | ALCANCE: 100m"
		label_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label_hint, Color(0.95, 0.80, 0.30), 9, false)
		_telemetry_panel.add_child(label_hint)

func _apply_label_style(lbl: Label, text_color: Color, font_size: int, _is_bold: bool) -> void:
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_font_size_override("font_size", font_size)

# =========================================================================
# AUTO-DESCOBERTA DE REFERÊNCIAS (Zero-Configuration Self-Healing)
# =========================================================================

func _auto_discover_references() -> void:
	if not is_inside_tree():
		return

	var root_node: Node = get_tree().root

	# 1. Localizar CameraPivot
	if target_camera_pivot == null or not is_instance_valid(target_camera_pivot):
		var cam_nodes: Array[Node] = get_tree().get_nodes_in_group("camera_pivot")
		if not cam_nodes.is_empty() and cam_nodes[0] is Node3D:
			target_camera_pivot = cam_nodes[0] as Node3D
		else:
			target_camera_pivot = root_node.find_child("CameraPivot", true, false) as Node3D
			if target_camera_pivot == null:
				target_camera_pivot = root_node.find_child("camera_pivot", true, false) as Node3D
			if target_camera_pivot == null:
				var active_cam: Camera3D = get_viewport().get_camera_3d()
				if active_cam:
					if active_cam.get_parent() is Node3D and active_cam.get_parent() != root_node:
						target_camera_pivot = active_cam.get_parent() as Node3D
					else:
						target_camera_pivot = active_cam

	# 2. Localizar AmazonBiosphereSimulator
	if target_simulator == null or not is_instance_valid(target_simulator):
		var sim_nodes: Array[Node] = get_tree().get_nodes_in_group("biosphere_simulator")
		if not sim_nodes.is_empty() and sim_nodes[0] is AmazonBiosphereSimulator:
			target_simulator = sim_nodes[0] as AmazonBiosphereSimulator
		else:
			target_simulator = root_node.find_child("AmazonBiosphereSimulator", true, false) as AmazonBiosphereSimulator
			if target_simulator == null:
				target_simulator = root_node.find_child("BiosphereSimulator", true, false) as AmazonBiosphereSimulator
			if target_simulator == null:
				target_simulator = root_node.find_child("BiosphereController", true, false) as AmazonBiosphereSimulator

	# 3. Localizar WorldStreamingManager100x100
	if target_streaming == null or not is_instance_valid(target_streaming):
		var str_nodes: Array[Node] = get_tree().get_nodes_in_group("world_streaming")
		if not str_nodes.is_empty() and str_nodes[0] is WorldStreamingManager100x100:
			target_streaming = str_nodes[0] as WorldStreamingManager100x100
		else:
			target_streaming = root_node.find_child("WorldStreamingManager", true, false) as WorldStreamingManager100x100
			if target_streaming == null:
				target_streaming = root_node.find_child("WorldStreamingManager100x100", true, false) as WorldStreamingManager100x100
