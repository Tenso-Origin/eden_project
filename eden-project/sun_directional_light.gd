@tool
extends DirectionalLight3D
class_name SunDirectionalLight

## =========================================================================
## CONTROLADOR DO SOL (DirectionalLight3D)
## =========================================================================
## Implementa a rotação suave do Sol no eixo X, evitando o zênite perfeito
## com ZENITH_OFFSET_ANGLE fixo de 10 graus no eixo Z, e desliga a luz à noite
## (visible = false) para economizar processamento na GPU.
##
## CORREÇÃO SHADOW ACNE AO MEIO-DIA:
## O shadow_bias é ajustado dinamicamente conforme a altura do sol.
## Quando o sol está no zênite, o ângulo de incidência da luz em superfícies
## horizontais tende a zero — o shadow map perde resolução angular e gera
## "shadow acne" (manchas escuras no terreno). O bias dinâmico compensa isso
## aumentando automaticamente o offset ao meio-dia.

@export var speed: float = 0.05
@export var max_intensity: float = 1.0

# Ângulo de inclinação lateral em graus para evitar o zênite perfeito (90°)
const ZENITH_OFFSET_ANGLE: float = 10.0

# Cor amarela viva solar
@export var sun_color: Color = Color(1.0, 0.96, 0.82, 1.0)

@export_group("Shadow Bias Dinâmico")
## Bias mínimo no amanhecer/pôr do sol (ângulo baixo, sombras longas)
@export var shadow_bias_dawn: float = 0.05
## Bias máximo ao meio-dia (zênite — previne shadow acne no terreno plano)
@export var shadow_bias_noon: float = 0.18
## Normal bias fixo — empurra a superfície receptora para evitar auto-shadowing em low-poly
@export var shadow_normal_bias_value: float = 2.0

var time_of_day: float = 0.0
var time_scale: float = 1.0

func _ready() -> void:
	light_color = sun_color
	shadow_enabled = true
	shadow_normal_bias = shadow_normal_bias_value
	# PSSM 2 cascades: o 1º cascade cobre os 15% mais próximos (alta resolução)
	# e o 2º cascade cobre o restante (120m máx). Elimina os artefatos de
	# shadow acne que o cascade único (ORTHOGONAL) gerava ao meio-dia.
	directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	directional_shadow_split_1 = 0.15
	directional_shadow_max_distance = 120.0
	directional_shadow_pancake_size = 20.0

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Avança o tempo do ciclo (0 a 360 graus) com escala de velocidade
		time_of_day += speed * delta * time_scale
		if time_of_day >= 360.0:
			time_of_day = 0.0
	
	_update_sun()

func _update_sun() -> void:
	# Converte o tempo em radianos para cálculos trigonométricos
	var rad = deg_to_rad(time_of_day)
	
	# Calcula a rotação principal baseada no tempo (eixo X simulando o nascer/pôr do sol)
	var sun_angle_x = rad
	# Adicionamos um offset fixo no eixo Z para inclinar a luz e fugir do vetor vertical puro
	var sun_angle_z = deg_to_rad(ZENITH_OFFSET_ANGLE)
	
	# Substitui a rotação por Euler por Quatérnions para evitar Gimbal Lock no zênite
	var rot_x = Quaternion(Vector3.RIGHT, sun_angle_x)
	var rot_z = Quaternion(Vector3.FORWARD, sun_angle_z)
	quaternion = rot_x * rot_z
	
	# Ajusta a intensidade da luz baseada na altura do sol (seno)
	var sun_height = sin(rad)
	if sun_height > 0.0:
		light_energy = max_intensity * sun_height
		visible = true
		
		# --- SHADOW BIAS DINÂMICO ---
		# sun_height vai de 0 (horizonte) a 1 (zênite).
		# Interpolamos o bias entre dawn (horizonte) e noon (zênite) usando
		# uma curva suave (smoothstep) para evitar transições abruptas.
		var t: float = smoothstep(0.0, 1.0, sun_height)
		shadow_bias = lerpf(shadow_bias_dawn, shadow_bias_noon, t)
	else:
		light_energy = 0.0
		visible = false # Desliga a luz à noite para economizar processamento
		shadow_bias = shadow_bias_dawn

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				time_scale = 1.0
				print("[Sol] Velocidade 1x (Normal)")
			KEY_2:
				time_scale = 2.0
				print("[Sol] Velocidade 2x")
			KEY_3:
				time_scale = 4.0
				print("[Sol] Velocidade 4x")
