@tool
extends Node3D
class_name DayNightCycleController

## =========================================================================
## CONTROLADOR DE CICLO DE DIA E NOITE EQUATORIAL (David Holland Architecture)
## =========================================================================
## Simula a trajetória solar para regiões equatoriais (Latitude ~0°)
## com variação sazonal da declinação solar segundo o calendário planetário (365 dias).
## Utiliza ZENITH_OFFSET_ANGLE de 10 graus no eixo Z para evitar o zênite perfeito (90°)
## e desliga a luz à noite (visible = false) para economizar processamento na GPU.

signal time_changed(hour: float, day_of_year: int, date_str: String)

@export_group("Referências de Nós")
@export var sun_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Tempo e Calendário")
## Hora atual do dia em ponto flutuante (0.0 = Meia-noite, 6.0 = Nascer do Sol, 12.0 = Meio-dia, 18.0 = Pôr do Sol)
@export_range(0.0, 24.0, 0.05) var current_hour: float = 12.0:
	set(val):
		current_hour = fposmod(val, 24.0)
		if is_inside_tree():
			_update_lighting()

## Dia do ano (1 a 365). 80 = Equinócio de Março, 172 = Solstício de Junho (Inverno Sul), 265 = Equinócio de Setembro, 355 = Solstício de Dezembro (Verão Sul)
@export_range(1, 365, 1) var day_of_year: int = 80:
	set(val):
		day_of_year = clampi(val, 1, 365)
		if is_inside_tree():
			_update_lighting()

## Ano da simulação
@export var current_year: int = 1

## Duração de 1 dia completo (24 horas de simulação) em segundos reais
@export var day_duration_seconds: float = 120.0

## Multiplicador de escala de tempo (1x, 2x, 4x via teclas 1, 2, 3)
@export var time_scale: float = 1.0

## Se o tempo avança automaticamente
@export var auto_advance: bool = true

@export_group("Parâmetros do Sol e Zênite")
## Ângulo de inclinação lateral em graus para evitar o zênite perfeito (90°)
const ZENITH_OFFSET_ANGLE: float = 10.0

## Energia máxima da luz solar amarela ao meio-dia
@export var max_sun_energy: float = 1.25

# Paleta Cromática Atmosférica
const COLOR_DAY_LIGHT: Color = Color(1.0, 0.96, 0.82, 1.0)       # Luz amarela solar viva
const COLOR_NOON_LIGHT: Color = Color(1.0, 0.98, 0.88, 1.0)      # Meio-dia brilhante
const COLOR_DAWN_LIGHT: Color = Color(1.0, 0.72, 0.42, 1.0)      # Dourado suave da manhã
const COLOR_DUSK_LIGHT: Color = Color(1.0, 0.52, 0.25, 1.0)      # Âmbar crepuscular

const COLOR_SKY_DAY: Color = Color(0.24, 0.42, 0.62, 1.0)        # Céu azul tropical
const COLOR_SKY_DAWN: Color = Color(0.72, 0.44, 0.40, 1.0)       # Céu alvorada
const COLOR_SKY_DUSK: Color = Color(0.80, 0.36, 0.20, 1.0)       # Céu pôr do sol
const COLOR_SKY_NIGHT: Color = Color(0.06, 0.08, 0.16, 1.0)      # Céu noturno escuro

const COLOR_AMB_DAY: Color = Color(0.40, 0.38, 0.50, 1.0)        # Luz ambiente diurna
const COLOR_AMB_DAWN: Color = Color(0.45, 0.32, 0.40, 1.0)       # Luz ambiente alvorada
const COLOR_AMB_DUSK: Color = Color(0.46, 0.28, 0.35, 1.0)       # Luz ambiente crepúsculo
const COLOR_AMB_NIGHT: Color = Color(0.16, 0.20, 0.35, 1.0)      # Luz ambiente noturna suave

# Meses do Calendário (365 dias, idêntico a core.js)
const MONTHS = [
	{"name": "janeiro", "days": 31},
	{"name": "fevereiro", "days": 28},
	{"name": "março", "days": 31},
	{"name": "abril", "days": 30},
	{"name": "maio", "days": 31},
	{"name": "junho", "days": 30},
	{"name": "julho", "days": 31},
	{"name": "agosto", "days": 31},
	{"name": "setembro", "days": 30},
	{"name": "outubro", "days": 31},
	{"name": "novembro", "days": 30},
	{"name": "dezembro", "days": 31}
]

var _last_broadcast_hour: float = -1.0

func _ready() -> void:
	_resolve_node_references()
	_update_lighting()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if auto_advance and day_duration_seconds > 0.0:
		var hours_per_sec: float = 24.0 / day_duration_seconds
		var delta_hours: float = delta * hours_per_sec * time_scale
		
		var new_hour: float = current_hour + delta_hours
		if new_hour >= 24.0:
			new_hour -= 24.0
			day_of_year += 1
			if day_of_year > 365:
				day_of_year = 1
				current_year += 1
		current_hour = new_hour
		
		# Emite sinal periodicamente a cada ~10 minutos simulados
		if abs(current_hour - _last_broadcast_hour) > 0.166:
			_last_broadcast_hour = current_hour
			var date_info = get_sim_date()
			time_changed.emit(current_hour, day_of_year, date_info.full_str)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
		
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				time_scale = 1.0
				print("[Ciclo Dia/Noite] Velocidade 1x (Normal)")
			KEY_2:
				time_scale = 2.0
				print("[Ciclo Dia/Noite] Velocidade 2x")
			KEY_3:
				time_scale = 4.0
				print("[Ciclo Dia/Noite] Velocidade 4x")
			KEY_0, KEY_P:
				auto_advance = not auto_advance
				print("[Ciclo Dia/Noite] Avanço automático: ", "LIGADO" if auto_advance else "PAUSADO")
			KEY_BRACKETLEFT:
				current_hour = fposmod(current_hour - 1.0, 24.0)
				print("[Ciclo Dia/Noite] Hora recuada: ", _format_time_str(current_hour))
			KEY_BRACKETRIGHT:
				current_hour = fposmod(current_hour + 1.0, 24.0)
				print("[Ciclo Dia/Noite] Hora avançada: ", _format_time_str(current_hour))

## Encontra automaticamente as referências aos nós caso não tenham sido atribuídas
func _resolve_node_references() -> void:
	if not is_inside_tree() or not get_parent():
		return
	if not sun_light:
		sun_light = get_parent().find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if not world_environment:
		world_environment = get_parent().find_child("WorldEnvironment", true, false) as WorldEnvironment

## Retorna a data e estação atual conforme o calendário planetário
func get_sim_date() -> Dictionary:
	var day_in_year: int = day_of_year - 1
	var month_idx: int = 0
	var days_left: int = day_in_year
	
	for m in range(MONTHS.size()):
		var m_days: int = MONTHS[m].days
		if days_left < m_days:
			month_idx = m
			break
		days_left -= m_days
		
	var day_of_month: int = days_left + 1
	var month_name: String = MONTHS[month_idx].name
	var is_rainy: bool = (month_idx >= 10 or month_idx <= 3) # Novembro a Abril
	var season_name: String = "Inverno Amazônico (Cheias)" if is_rainy else "Verão Amazônico (Vazante)"
	var time_str: String = _format_time_str(current_hour)
	
	var day_str: String = "%02d" % day_of_month
	var full_str: String = "%s de %s do ano %d - %s [%s]" % [day_str, month_name, current_year, time_str, season_name]
	
	return {
		"day": day_of_month,
		"month_idx": month_idx,
		"month_name": month_name,
		"year": current_year,
		"is_rainy_season": is_rainy,
		"season_name": season_name,
		"time_str": time_str,
		"full_str": full_str,
		"hour": current_hour
	}

func _format_time_str(hour_val: float) -> String:
	var h: int = int(hour_val)
	var m: int = int((hour_val - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]

## Atualiza a rotação do Sol, cor da luz, intensidade e céu de forma contínua
func _update_lighting() -> void:
	_resolve_node_references()
	
	# 1. Declinação Solar Sazonal (Variação ao longo do ano: Março 0°, Junho +23.44°, Dezembro -23.44°)
	var d_rad: float = (float(day_of_year) - 80.0) / 365.0 * TAU
	var declination_deg: float = 23.44 * sin(d_rad)
	
	# 2. Converte a hora do dia em graus (0° = 06h nascer, 90° = 12h meio-dia, 180° = 18h pôr do sol)
	var time_of_day: float = fposmod((current_hour - 6.0) / 24.0 * 360.0, 360.0)
	var rad: float = deg_to_rad(time_of_day)
	
	# 3. Calcula a rotação principal baseada no tempo (eixo X simulando o nascer/pôr do sol)
	var sun_angle_x = -rad
	# Adicionamos um offset fixo no eixo Z para inclinar a luz e fugir do vetor vertical puro (ZENITH_OFFSET_ANGLE)
	# mais a leve modulação sazonal da declinação solar no Equador
	var sun_angle_z = deg_to_rad(ZENITH_OFFSET_ANGLE + declination_deg * 0.35)
	
	# 4. Ajusta a intensidade da luz baseada na altura do sol (seno)
	var sun_height = sin(rad)
	
	# 3. Substitui a rotação por Euler por Quatérnions para evitar Gimbal Lock no zênite
	var rot_x = Quaternion(Vector3.RIGHT, sun_angle_x)
	var rot_z = Quaternion(Vector3.FORWARD, sun_angle_z)
	
	if sun_light:
		# Aplica a rotação combinada livre de travamentos
		sun_light.quaternion = rot_x * rot_z
		
		if sun_height > 0.0:
			sun_light.light_energy = max_sun_energy * sun_height
			sun_light.visible = true
			
			# Gradiente Cromático da Luz Solar Amarela
			if current_hour < 7.0:
				var t = clampf((current_hour - 5.5) / 1.5, 0.0, 1.0)
				sun_light.light_color = COLOR_DAWN_LIGHT.lerp(COLOR_DAY_LIGHT, t)
			elif current_hour >= 7.0 and current_hour < 11.0:
				var t = clampf((current_hour - 7.0) / 4.0, 0.0, 1.0)
				sun_light.light_color = COLOR_DAY_LIGHT.lerp(COLOR_NOON_LIGHT, t)
			elif current_hour >= 11.0 and current_hour <= 13.5:
				sun_light.light_color = COLOR_NOON_LIGHT
			elif current_hour > 13.5 and current_hour <= 16.5:
				var t = clampf((current_hour - 13.5) / 3.0, 0.0, 1.0)
				sun_light.light_color = COLOR_NOON_LIGHT.lerp(COLOR_DAY_LIGHT, t)
			else:
				var t = clampf((current_hour - 16.5) / 2.0, 0.0, 1.0)
				sun_light.light_color = COLOR_DAY_LIGHT.lerp(COLOR_DUSK_LIGHT, t)
		else:
			sun_light.light_energy = 0.0
			sun_light.visible = false # Desliga a luz à noite para economizar processamento
			
	# 5. Modula WorldEnvironment (Céu e Luz Ambiente Noturna/Diurna)
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		var sky_color: Color
		var amb_color: Color
		var amb_energy: float
		
		if current_hour >= 5.0 and current_hour < 6.5:
			var t = (current_hour - 5.0) / 1.5
			sky_color = COLOR_SKY_NIGHT.lerp(COLOR_SKY_DAWN, t)
			amb_color = COLOR_AMB_NIGHT.lerp(COLOR_AMB_DAWN, t)
			amb_energy = lerpf(0.40, 0.55, t)
		elif current_hour >= 6.5 and current_hour < 8.5:
			var t = (current_hour - 6.5) / 2.0
			sky_color = COLOR_SKY_DAWN.lerp(COLOR_SKY_DAY, t)
			amb_color = COLOR_AMB_DAWN.lerp(COLOR_AMB_DAY, t)
			amb_energy = lerpf(0.55, 0.65, t)
		elif current_hour >= 8.5 and current_hour < 16.5:
			sky_color = COLOR_SKY_DAY
			amb_color = COLOR_AMB_DAY
			amb_energy = 0.65
		elif current_hour >= 16.5 and current_hour < 18.5:
			var t = (current_hour - 16.5) / 2.0
			sky_color = COLOR_SKY_DAY.lerp(COLOR_SKY_DUSK, t)
			amb_color = COLOR_AMB_DAY.lerp(COLOR_AMB_DUSK, t)
			amb_energy = lerpf(0.65, 0.50, t)
		elif current_hour >= 18.5 and current_hour < 20.0:
			var t = (current_hour - 18.5) / 1.5
			sky_color = COLOR_SKY_DUSK.lerp(COLOR_SKY_NIGHT, t)
			amb_color = COLOR_AMB_DUSK.lerp(COLOR_AMB_NIGHT, t)
			amb_energy = lerpf(0.50, 0.40, t)
		else:
			sky_color = COLOR_SKY_NIGHT
			amb_color = COLOR_AMB_NIGHT
			amb_energy = 0.42 # Iluminação ambiente noturna para visibilidade do cenário com luz solar desligada
			
		env.background_color = sky_color
		env.ambient_light_color = amb_color
		env.ambient_light_energy = amb_energy
