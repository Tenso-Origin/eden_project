@tool
extends MeshInstance3D
class_name FloatingGlowingCube

## =========================================================================
## CUBO MÍSTICO FLUTUANTE COM EMISSÃO DIA/NOITE (David Holland Architecture)
## =========================================================================
## Cubo de 0.25m que flutua e oscila verticalmente por 1m acima da fonte.
## Emite luz fraca quase imperceptível durante o dia, transformando-se
## em um glow etéreo radiante durante a noite.

@export_group("Cinemática de Flutuação")
## Altura inicial mínima acima do chão (logo acima do cálice da fonte a ~1.6m)
@export var base_height: float = 1.85

## Amplitude vertical total da oscilação (1.0m conforme especificado)
@export var travel_distance: float = 1.0

## Velocidade da oscilação vertical (ciclos por segundo)
@export var bob_speed: float = 1.8

## Velocidade de rotação mística nos eixos X, Y e Z (radianos/s)
@export var rotation_speed: Vector3 = Vector3(0.35, 1.1, 0.25)

@export_group("Glow e Iluminação Dinâmica")
## Cor do brilho místico (turquesa / ciano etéreo)
@export var glow_color: Color = Color(0.25, 0.85, 1.0, 1.0)

## Energia do material emissivo durante o dia (luz bem fraca, quase invisível)
@export var day_emission: float = 0.20

## Energia do material emissivo durante a noite (glow radiante vivo)
@export var night_emission: float = 4.8

## Energia da OmniLight3D durante o dia
@export var day_light_energy: float = 0.10

## Energia da OmniLight3D durante a noite
@export var night_light_energy: float = 2.4

## Alcance da luz emitida (metros)
@export var light_range: float = 7.0

var omni_light: OmniLight3D = null
var cube_material: StandardMaterial3D = null
var day_night_node: Node = null
var current_time: float = 0.0

func _ready() -> void:
	# 1. Configura a malha do cubo para exatamente 0.25m x 0.25m x 0.25m
	if not mesh or not (mesh is BoxMesh):
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.25, 0.25)
		mesh = box
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3(0.25, 0.25, 0.25)

	# 2. Configura material emissivo único
	cube_material = StandardMaterial3D.new()
	cube_material.albedo_color = glow_color.lerp(Color.WHITE, 0.35)
	cube_material.roughness = 0.2
	cube_material.emission_enabled = true
	cube_material.emission = glow_color
	cube_material.emission_energy_multiplier = day_emission
	material_override = cube_material

	# 3. Busca ou cria o nó OmniLight3D como filho
	omni_light = get_node_or_null("OmniLight3D") as OmniLight3D
	if not omni_light:
		omni_light = OmniLight3D.new()
		omni_light.name = "OmniLight3D"
		add_child(omni_light)
		if Engine.is_editor_hint():
			omni_light.owner = get_tree().edited_scene_root

	omni_light.light_color = glow_color
	omni_light.light_energy = day_light_energy
	omni_light.omni_range = light_range
	omni_light.omni_attenuation = 1.2
	omni_light.shadow_enabled = true
	omni_light.shadow_bias = 0.03

	_find_day_night_cycle()

func _find_day_night_cycle() -> void:
	var root = get_tree().current_scene if get_tree() else null
	if not root:
		root = get_parent()
	if root:
		day_night_node = root.find_child("DayNightCycle", true, false)

func _process(delta: float) -> void:
	current_time += delta

	# 1. Movimento vertical senoidal suave cobrindo exatamente travel_distance (1.0m)
	# Seno normalizado de [ -1, 1 ] para [ 0, 1 ]
	var wave: float = (sin(current_time * bob_speed) * 0.5) + 0.5
	position.y = base_height + (wave * travel_distance)

	# 2. Rotação contínua nos eixos para efeito místico de relíquia
	rotate_x(rotation_speed.x * delta)
	rotate_y(rotation_speed.y * delta)
	rotate_z(rotation_speed.z * delta)

	# 3. Cálculo do fator noite (0.0 = pleno dia, 1.0 = plena noite)
	var night_factor: float = _calculate_night_factor()

	# 4. Atualização dinâmica da emissão do material e da OmniLight
	var current_emission: float = lerpf(day_emission, night_emission, night_factor)
	var current_light: float = lerpf(day_light_energy, night_light_energy, night_factor)

	if cube_material:
		cube_material.emission_energy_multiplier = current_emission
		# À noite, o albedo fica mais branco/intenso pelo brilho interno
		cube_material.albedo_color = glow_color.lerp(Color.WHITE, 0.35 + (night_factor * 0.45))

	if omni_light:
		omni_light.light_energy = current_light

func _calculate_night_factor() -> float:
	if not day_night_node or not is_instance_valid(day_night_node):
		_find_day_night_cycle()

	if day_night_node and "current_hour" in day_night_node:
		var hour: float = day_night_node.current_hour
		# Dia: entre 06:00 e 18:00 (sol acima do horizonte)
		if hour >= 6.0 and hour <= 18.0:
			var sun_arc: float = sin((hour - 6.0) / 12.0 * PI) # 0.0 no nascer/pôr, 1.0 ao meio-dia
			# Ao meio-dia (sun_arc = 1.0), night_factor = 0.0 (dia puro)
			# Perto das 06:00 e 18:00 (sun_arc < 0.25), faz transição suave
			return clampf(1.0 - (sun_arc * 1.35), 0.0, 1.0)
		else:
			# Noite pura (18:00 às 06:00)
			return 1.0

	# Padrão fallback caso não haja controlador de dia/noite
	return 0.0

