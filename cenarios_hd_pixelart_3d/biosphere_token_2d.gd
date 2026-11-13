class_name BiosphereToken2D
extends Sprite3D

## BiosphereToken2D - Componente Visual 2.5D de Fauna / Token HD Pixel Art 3D
##
## Representa animais individuais da simulação em um plano vertical billboard (Y-Fixed),
## gerando proceduralmente texturas circulares 32x32 em pixel art com contorno contrastante
## e ícones/cores canônicas para as espécies da biosfera.
##
## Inclui micro-indicadores em Label3D, atenuação alfa para estados de mergulho
## e sombra projetada no solo para predadores aéreos (Harpia).

# --- IDENTIFICADORES DE ESPÉCIES (Alinhados com SpeciesCatalog.cs) ---
const ID_CUTIA: int = 1
const ID_JAGUATIRICA: int = 10
const ID_ONCA: int = 11
const ID_CAPIVARA: int = 12
const ID_HARPIA: int = 30
const ID_JABUTI: int = 50

# --- ESCALAS CANÔNICAS POR ESPÉCIE ---
const SPECIES_SCALES: Dictionary = {
	ID_CUTIA: 0.8,
	ID_JAGUATIRICA: 1.1,
	ID_ONCA: 1.5,
	ID_CAPIVARA: 1.4,
	ID_HARPIA: 1.6,
	ID_JABUTI: 0.9,
}

# --- CACHE ESTÁTICO DE TEXTURAS (Zero Re-alocação) ---
static var _texture_cache: Dictionary = {}
static var _shadow_texture: ImageTexture = null

# --- PROPRIEDADES EXPORTADAS E ESTADO ---
@export var species_id: int = ID_CUTIA: set = set_species_id
@export var interp_speed: float = 8.0

var target_position: Vector3 = Vector3.ZERO
var ground_y_level: float = 0.0
var is_first_update: bool = true

var status_label: Label3D = null
var shadow_sprite: Sprite3D = null


func _ready() -> void:
	# 1. Configurações canônicas de renderização 3D do Token
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	double_sided = true
	pixel_size = 0.02 # Escala de 1m a 64 PPU calibrada

	# 2. Inicializar textura e escala da espécie
	_apply_species_visuals()

	# 3. Adicionar nó filho Label3D flutuante para micro-indicadores
	_setup_status_label()

	# 4. Configurar sombra no solo se for ave de grande porte (Harpia)
	_setup_aerial_shadow_if_needed()


func _process(delta: float) -> void:
	# Interpolação suave de posição no espaço 3D (lerp)
	if not is_first_update:
		global_position = global_position.lerp(target_position, clamp(interp_speed * delta, 0.0, 1.0))

	# Atualizar sombra no solo para espécies aéreas
	if shadow_sprite and is_instance_valid(shadow_sprite):
		shadow_sprite.global_position = Vector3(global_position.x, ground_y_level + 0.02, global_position.z)


func _exit_tree() -> void:
	# Limpeza segura do nó top_level da sombra se existir
	if shadow_sprite and is_instance_valid(shadow_sprite) and not shadow_sprite.is_queued_for_deletion():
		shadow_sprite.queue_free()


## Define a espécie do token e reaplica textura/escala
func set_species_id(new_id: int) -> void:
	species_id = new_id
	if is_inside_tree():
		_apply_species_visuals()
		_setup_aerial_shadow_if_needed()


## Atualização contínua de telemetria vinda da simulação (Ecosystem / Agents)
func update_token(
	pos_x: float,
	pos_z: float,
	ground_y: float,
	state_enum: int,
	is_diving_bool: bool,
	hunger_val: float,
	health_val: float,
	alert_bool: bool
) -> void:
	ground_y_level = ground_y

	# Cálculo da altitude Y:
	# - Harpia voa alto (+3.5m acima do relevo)
	# - Mergulho afunda levemente (-0.30m abaixo da lâmina d'água)
	# - Fauna terrestre normal apoia no solo (+0.32m raio da base)
	var desired_y: float = ground_y
	if species_id == ID_HARPIA:
		desired_y += 3.5
	elif is_diving_bool:
		desired_y -= 0.30
	else:
		desired_y += 0.32

	var new_target: Vector3 = Vector3(pos_x, desired_y, pos_z)

	if is_first_update:
		if is_inside_tree():
			global_position = new_target
		else:
			position = new_target
		target_position = new_target
		is_first_update = false
	else:
		target_position = new_target
		# Teleporte imediato em caso de deslocamento anômalo (> 25m)
		if is_inside_tree() and global_position.distance_to(target_position) > 25.0:
			global_position = target_position

	# Efeito de opacidade para imersão aquática / mergulho
	if is_diving_bool:
		modulate.a = 0.45
	else:
		modulate.a = 1.0

	# Atualização do Micro-indicador flutuante (Label3D)
	_update_micro_indicator(state_enum, is_diving_bool, hunger_val, health_val, alert_bool)


## Atualiza o Label3D com símbolos canônicos de alta nitidez
func _update_micro_indicator(state_enum: int, is_diving_bool: bool, hunger_val: float, health_val: float, alert_bool: bool) -> void:
	if not status_label:
		return

	# Prioridade 1: Alerta / Fuga (Estado 2 = Fleeing ou flag alert ativa)
	if alert_bool or state_enum == 2:
		status_label.text = "!"
		status_label.modulate = Color(1.0, 0.15, 0.15, 1.0) # Vermelho vibrante
	# Prioridade 2: Mergulho sob a lâmina d'água
	elif is_diving_bool:
		status_label.text = "🌊"
		status_label.modulate = Color(0.35, 0.85, 1.0, 1.0) # Azul aquático
	# Prioridade 3: Sono / Descanso (Estado 4 = Resting)
	elif state_enum == 4:
		status_label.text = "zZz"
		status_label.modulate = Color(0.65, 0.85, 1.0, 1.0) # Azul celeste suave
	# Prioridade 4: Acasalamento (Estado 3 = Mating)
	elif state_enum == 3:
		status_label.text = "❤️"
		status_label.modulate = Color(1.0, 0.35, 0.55, 1.0) # Rosa coração
	# Prioridade 5: Caça ou Fome severa (Estado 1 = Hunting ou hunger > 0.8)
	elif state_enum == 1 or hunger_val > 0.80:
		status_label.text = "🍖"
		status_label.modulate = Color(1.0, 0.70, 0.25, 1.0) # Âmbar alimento
	# Estado Normal: Forrageando / Neutro
	else:
		status_label.text = ""


## Configura e anexa o Label3D flutuante para ícones
func _setup_status_label() -> void:
	if status_label:
		return

	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	status_label.position = Vector3(0.0, 0.75, 0.0)
	status_label.pixel_size = 0.007
	status_label.font_size = 36
	status_label.outline_size = 8
	status_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.90)
	status_label.no_depth_test = true
	status_label.render_priority = 2
	status_label.text = ""
	add_child(status_label)


## Configura sombra projetada para a Harpia
func _setup_aerial_shadow_if_needed() -> void:
	if species_id == ID_HARPIA:
		if not shadow_sprite:
			shadow_sprite = Sprite3D.new()
			shadow_sprite.name = "GroundShadow"
			shadow_sprite.top_level = true
			shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			shadow_sprite.axis = Vector3.AXIS_Y
			shadow_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			shadow_sprite.double_sided = true
			shadow_sprite.pixel_size = 0.03
			shadow_sprite.texture = _get_or_create_shadow_texture()
			shadow_sprite.modulate = Color(0.0, 0.0, 0.0, 0.55)
			add_child(shadow_sprite)
		shadow_sprite.visible = true
	else:
		if shadow_sprite:
			shadow_sprite.visible = false


## Aplica a textura procedural e a escala da espécie
func _apply_species_visuals() -> void:
	texture = get_or_create_token_texture(species_id)
	var target_scale: float = SPECIES_SCALES.get(species_id, 1.0)
	scale = Vector3(target_scale, target_scale, target_scale)


# ==============================================================================
# GERAÇÃO PROCEDURAL DE TEXTURAS 32x32 EM PIXEL ART (GDScript)
# ==============================================================================

## Retorna a textura em cache ou gera uma nova proceduralmente
static func get_or_create_token_texture(id: int) -> ImageTexture:
	if _texture_cache.has(id):
		return _texture_cache[id]

	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center: Vector2 = Vector2(15.5, 15.5)
	var border_color: Color = Color(0.10, 0.08, 0.06, 1.0) # Borda contrastante escura

	# 1. Traçar disco base circular com borda contrastante
	for y in range(32):
		for x in range(32):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= 14.2 and dist >= 12.0:
				img.set_pixel(x, y, border_color)

	# 2. Desenhar iconografia interna de cada espécie
	match id:
		ID_CUTIA:
			_draw_cutia_pixels(img, center)
		ID_JAGUATIRICA:
			_draw_jaguatirica_pixels(img, center)
		ID_ONCA:
			_draw_onca_pixels(img, center)
		ID_CAPIVARA:
			_draw_capivara_pixels(img, center)
		ID_JABUTI:
			_draw_jabuti_pixels(img, center)
		ID_HARPIA:
			_draw_harpia_pixels(img, center)
		_:
			_draw_generic_pixels(img, center)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_texture_cache[id] = tex
	return tex


## Retorna textura de sombra elíptica suave projetada no solo
static func _get_or_create_shadow_texture() -> ImageTexture:
	if _shadow_texture:
		return _shadow_texture

	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(32):
		for x in range(32):
			var dx: float = (float(x) - 15.5) / 13.0
			var dy: float = (float(y) - 15.5) / 9.0
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < 1.0:
				var alpha: float = (1.0 - dist) * 0.75
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))

	_shadow_texture = ImageTexture.create_from_image(img)
	return _shadow_texture


# --- DESENHADORES ESPECÍFICOS DE ESPÉCIES EM 32x32 ---

static func _draw_cutia_pixels(img: Image, center: Vector2) -> void:
	var base_ocre: Color = Color(0.72, 0.46, 0.22, 1.0)
	var belly_color: Color = Color(0.86, 0.65, 0.40, 1.0)
	var ear_color: Color = Color(0.52, 0.28, 0.12, 1.0)
	var dark_color: Color = Color(0.12, 0.08, 0.06, 1.0)
	var eye_shine: Color = Color(1.0, 1.0, 1.0, 1.0)

	# Fundo corporal
	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				if y >= 19:
					img.set_pixel(x, y, belly_color)
				else:
					img.set_pixel(x, y, base_ocre)

	# Orelhas de roedor
	for y in range(5, 9):
		for x in range(9, 13):
			img.set_pixel(x, y, ear_color)
		for x in range(19, 23):
			img.set_pixel(x, y, ear_color)

	# Olhos pretos com brilho
	img.set_pixel(11, 13, dark_color)
	img.set_pixel(12, 13, dark_color)
	img.set_pixel(11, 12, eye_shine)

	img.set_pixel(19, 13, dark_color)
	img.set_pixel(20, 13, dark_color)
	img.set_pixel(19, 12, eye_shine)

	# Focinho e nariz
	img.set_pixel(15, 17, dark_color)
	img.set_pixel(16, 17, dark_color)
	img.set_pixel(15, 18, dark_color)
	img.set_pixel(16, 18, dark_color)


static func _draw_jaguatirica_pixels(img: Image, center: Vector2) -> void:
	var gold_yellow: Color = Color(0.92, 0.74, 0.28, 1.0)
	var muzzle_cream: Color = Color(0.96, 0.90, 0.72, 1.0)
	var spots_dark: Color = Color(0.18, 0.12, 0.06, 1.0)
	var feline_eyes: Color = Color(0.68, 0.85, 0.25, 1.0)
	var nose_pink: Color = Color(0.85, 0.48, 0.52, 1.0)

	# Preenchimento base
	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				if y >= 18 and abs(x - 15.5) <= 6.0:
					img.set_pixel(x, y, muzzle_cream)
				else:
					img.set_pixel(x, y, gold_yellow)

	# Orelhas felinas pontudas
	for y in range(4, 9):
		for x in range(8, 12):
			img.set_pixel(x, y, spots_dark)
		for x in range(20, 24):
			img.set_pixel(x, y, spots_dark)

	# Manchas / Pintas felinas
	var spot_coords: Array[Vector2i] = [
		Vector2i(15, 8), Vector2i(16, 8), Vector2i(14, 10), Vector2i(17, 10),
		Vector2i(8, 15), Vector2i(9, 16), Vector2i(22, 16), Vector2i(23, 15),
		Vector2i(10, 21), Vector2i(21, 21), Vector2i(15, 23)
	]
	for p in spot_coords:
		if p.x >= 0 and p.x < 32 and p.y >= 0 and p.y < 32:
			img.set_pixel(p.x, p.y, spots_dark)

	# Olhos verdes amendoados
	img.set_pixel(11, 13, feline_eyes)
	img.set_pixel(12, 13, spots_dark) # Pupila
	img.set_pixel(19, 13, spots_dark) # Pupila
	img.set_pixel(20, 13, feline_eyes)

	# Nariz felino
	img.set_pixel(15, 17, nose_pink)
	img.set_pixel(16, 17, nose_pink)


static func _draw_onca_pixels(img: Image, center: Vector2) -> void:
	var tawny_ochre: Color = Color(0.88, 0.52, 0.14, 1.0)
	var muzzle_color: Color = Color(0.92, 0.75, 0.50, 1.0)
	var rosette_rim: Color = Color(0.12, 0.08, 0.05, 1.0)
	var rosette_center: Color = Color(0.68, 0.36, 0.10, 1.0)
	var amber_eyes: Color = Color(0.98, 0.82, 0.18, 1.0)

	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				if y >= 18 and abs(x - 15.5) <= 5.5:
					img.set_pixel(x, y, muzzle_color)
				else:
					img.set_pixel(x, y, tawny_ochre)

	# Orelhas arredondadas com contorno escuro
	for y in range(5, 9):
		for x in range(7, 11):
			img.set_pixel(x, y, rosette_rim)
		for x in range(21, 25):
			img.set_pixel(x, y, rosette_rim)

	# Rosetas características (anel escuro com centro ocre escuro)
	var rosettes: Array[Vector2i] = [
		Vector2i(15, 8), Vector2i(8, 15), Vector2i(23, 15),
		Vector2i(11, 22), Vector2i(20, 22)
	]
	for r in rosettes:
		# Desenha pequena roseta em cruz
		img.set_pixel(r.x, r.y, rosette_center)
		img.set_pixel(r.x - 1, r.y, rosette_rim)
		img.set_pixel(r.x + 1, r.y, rosette_rim)
		img.set_pixel(r.x, r.y - 1, rosette_rim)
		img.set_pixel(r.x, r.y + 1, rosette_rim)

	# Olhos âmbar felinos robustos
	for y in range(13, 15):
		for x in range(10, 13):
			img.set_pixel(x, y, amber_eyes)
		for x in range(19, 22):
			img.set_pixel(x, y, amber_eyes)

	# Pupila preta central
	img.set_pixel(11, 14, rosette_rim)
	img.set_pixel(20, 14, rosette_rim)

	# Focinho largo
	img.set_pixel(15, 17, rosette_rim)
	img.set_pixel(16, 17, rosette_rim)
	img.set_pixel(15, 18, rosette_rim)
	img.set_pixel(16, 18, rosette_rim)


static func _draw_capivara_pixels(img: Image, center: Vector2) -> void:
	var dark_brown: Color = Color(0.44, 0.30, 0.20, 1.0)
	var snout_brown: Color = Color(0.52, 0.36, 0.24, 1.0)
	var nostril_black: Color = Color(0.12, 0.08, 0.05, 1.0)

	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				# Bloco largo e quadrado do focinho
				if y >= 14 and y <= 23 and x >= 11 and x <= 20:
					img.set_pixel(x, y, snout_brown)
				else:
					img.set_pixel(x, y, dark_brown)

	# Orelhas arredondadas no topo
	for y in range(6, 9):
		for x in range(8, 11):
			img.set_pixel(x, y, nostril_black)
		for x in range(21, 24):
			img.set_pixel(x, y, nostril_black)

	# Olhos escuros laterais calmos
	img.set_pixel(9, 12, nostril_black)
	img.set_pixel(10, 12, nostril_black)
	img.set_pixel(21, 12, nostril_black)
	img.set_pixel(22, 12, nostril_black)

	# Narinas largas e achatadas características
	img.set_pixel(13, 20, nostril_black)
	img.set_pixel(14, 20, nostril_black)
	img.set_pixel(17, 20, nostril_black)
	img.set_pixel(18, 20, nostril_black)


static func _draw_jabuti_pixels(img: Image, center: Vector2) -> void:
	var olive_green: Color = Color(0.40, 0.50, 0.20, 1.0)
	var plate_rim: Color = Color(0.16, 0.20, 0.10, 1.0)
	var plate_center: Color = Color(0.78, 0.65, 0.22, 1.0)
	var head_color: Color = Color(0.30, 0.38, 0.16, 1.0)

	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				img.set_pixel(x, y, olive_green)

	# Cabeça arredondada no topo
	for y in range(4, 8):
		for x in range(13, 19):
			img.set_pixel(x, y, head_color)

	# Olhinhos pretos
	img.set_pixel(14, 6, plate_rim)
	img.set_pixel(17, 6, plate_rim)

	# Placas geométricas da carapaça (linhas em grade/hexágonos)
	for x in range(7, 25):
		img.set_pixel(x, 15, plate_rim)
	for y in range(8, 25):
		img.set_pixel(15, y, plate_rim)
		img.set_pixel(16, y, plate_rim)

	# Centros poligonais ocre/amarelos das placas da carapaça
	var centers: Array[Vector2i] = [
		Vector2i(11, 11), Vector2i(20, 11),
		Vector2i(11, 19), Vector2i(20, 19)
	]
	for c in centers:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				img.set_pixel(c.x + dx, c.y + dy, plate_center)


static func _draw_harpia_pixels(img: Image, center: Vector2) -> void:
	var lead_gray: Color = Color(0.24, 0.26, 0.32, 1.0)
	var crest_dark: Color = Color(0.14, 0.15, 0.20, 1.0)
	var face_white: Color = Color(0.92, 0.93, 0.96, 1.0)
	var raptor_eyes: Color = Color(1.0, 0.88, 0.15, 1.0)
	var beak_hook: Color = Color(0.12, 0.12, 0.15, 1.0)

	# Corpo cinza chumbo
	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				img.set_pixel(x, y, lead_gray)

	# Disco facial e peito branco
	for y in range(10, 22):
		for x in range(10, 22):
			if Vector2(x, y).distance_to(center) < 8.0:
				img.set_pixel(x, y, face_white)

	# Crista dupla proeminente de penas no topo (icônica da Harpia)
	for y in range(3, 8):
		for x in range(8, 12):
			img.set_pixel(x, y, crest_dark)
		for x in range(20, 24):
			img.set_pixel(x, y, crest_dark)

	# Olhos amarelos predadores penetrantes
	img.set_pixel(11, 13, raptor_eyes)
	img.set_pixel(12, 13, beak_hook)
	img.set_pixel(19, 13, beak_hook)
	img.set_pixel(20, 13, raptor_eyes)

	# Bico curvo adunco preto descendo em gancho
	for y in range(15, 20):
		img.set_pixel(15, y, beak_hook)
		img.set_pixel(16, y, beak_hook)
	img.set_pixel(15, 20, beak_hook)


static func _draw_generic_pixels(img: Image, center: Vector2) -> void:
	var base_gray: Color = Color(0.55, 0.58, 0.62, 1.0)
	var core_white: Color = Color(0.95, 0.95, 0.95, 1.0)

	for y in range(32):
		for x in range(32):
			if Vector2(x, y).distance_to(center) < 12.0:
				if Vector2(x, y).distance_to(center) < 4.0:
					img.set_pixel(x, y, core_white)
				else:
					img.set_pixel(x, y, base_gray)
