@tool
extends DirectionalLight3D
class_name SunDirectionalLight

## =========================================================================
## CONTROLADOR DO SOL (DirectionalLight3D)
## =========================================================================
## Implementa a rotação suave do Sol no eixo X, evitando o zênite perfeito
## com ZENITH_OFFSET_ANGLE fixo de 10 graus no eixo Z, e desliga a luz à noite
## (visible = false) para economizar processamento na GPU.

@export var speed: float = 0.05
@export var max_intensity: float = 1.0

# Ângulo de inclinação lateral em graus para evitar o zênite perfeito (90°)
const ZENITH_OFFSET_ANGLE: float = 10.0

# Cor amarela viva solar
@export var sun_color: Color = Color(1.0, 0.96, 0.82, 1.0)

var time_of_day: float = 0.0
var time_scale: float = 1.0

func _ready() -> void:
	light_color = sun_color
	shadow_enabled = true

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
	
	# Calcula a rotação principal baseada no tempo (ex: eixo X simulando o nascer/pôr do sol)
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
	else:
		light_energy = 0.0
		visible = false # Desliga a luz à noite para economizar processamento

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

