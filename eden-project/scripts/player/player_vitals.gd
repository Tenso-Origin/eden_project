@tool
extends Node
class_name PlayerVitals

## =========================================================================
## SISTEMA DE FISIOLOGIA E VITALS DO JOGADOR (David Holland Architecture)
## =========================================================================
## Modela a biologia e metabolismo humano com base em parâmetros fisiológicos:
## - Saúde (HP): trauma, infecções e sangramento (não regenera sem nutrição)
## - Estamina: energia de trabalho imediata (recuperação aeróbica rápida)
## - Nutrição (Calorias): taxa metabólica basal + custo de locomoção
## - Hidratação: perda hídrica por suor e calor ambiente úmido
## - Temperatura Corporal: balanço térmico entre ambiente, chuva e insolação

signal vitals_changed(hp: float, stamina: float, hunger: float, thirst: float, body_temp: float)
signal player_died(cause: String)

@export_group("Capacidades Máximas")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_hunger: float = 2500.0   # Calorias (kcal)
@export var max_thirst: float = 3000.0   # Volume hídrico (ml)
@export var baseline_temp: float = 36.5  # Temperatura basal corporal (°C)

@export_group("Taxas Metabólicas")
## Taxa metabólica basal em repouso (kcal/segundo)
@export var basal_metabolic_rate: float = 0.02
## Consumo hídrico basal em clima tropical úmido (ml/segundo)
@export var basal_water_loss_rate: float = 0.35
## Regeneração passiva de estamina por segundo em repouso
@export var stamina_recovery_rate: float = 15.0

# Estado Fisiológico Atual
var current_health: float = 100.0
var current_stamina: float = 100.0
var current_hunger: float = 2200.0
var current_thirst: float = 2800.0
var current_body_temp: float = 36.5

var is_running: bool = false
var is_swimming: bool = false
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_body_temp = baseline_temp
	_emit_vitals()

func update_vitals(delta: float, ambient_temp: float = 28.0, is_in_water: bool = false, is_raining: bool = false) -> void:
	if is_dead:
		return

	# 1. Gasto de Nutrição e Hidratação Basal
	var hunger_drain = basal_metabolic_rate * delta
	var thirst_drain = basal_water_loss_rate * delta

	# 2. Modulação por Atividade Física
	if is_running:
		hunger_drain *= 2.5
		thirst_drain *= 2.8
		consume_stamina(20.0 * delta)
	elif is_swimming:
		hunger_drain *= 3.0
		thirst_drain *= 2.0
		consume_stamina(25.0 * delta)
	else:
		# Recupera estamina se não estiver exausto por sede/fome extrema
		if current_stamina < max_stamina and current_hunger > 200.0 and current_thirst > 250.0:
			current_stamina = clampf(current_stamina + stamina_recovery_rate * delta, 0.0, max_stamina)

	# 3. Aplica decaimento metabólico
	current_hunger = clampf(current_hunger - hunger_drain, 0.0, max_hunger)
	current_thirst = clampf(current_thirst - thirst_drain, 0.0, max_thirst)

	# 4. Termorregulação Corporal
	_update_thermoregulation(delta, ambient_temp, is_in_water, is_raining)

	# 5. Dano por Inanição, Desidratação ou Choque Térmico
	_check_health_decay(delta)

	_emit_vitals()

func consume_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina = clampf(current_stamina - amount, 0.0, max_stamina)
		return true
	return false

func apply_damage(amount: float, cause: String = "Trauma") -> void:
	if is_dead:
		return
	current_health = clampf(current_health - amount, 0.0, max_health)
	if current_health <= 0.0:
		is_dead = true
		player_died.emit(cause)

func restore_health(amount: float) -> void:
	if not is_dead:
		current_health = clampf(current_health + amount, 0.0, max_health)

func consume_food(calories: float, hydration: float = 0.0) -> void:
	current_hunger = clampf(current_hunger + calories, 0.0, max_hunger)
	current_thirst = clampf(current_thirst + hydration, 0.0, max_thirst)

func drink_water(hydration_ml: float) -> void:
	current_thirst = clampf(current_thirst + hydration_ml, 0.0, max_thirst)

func _update_thermoregulation(delta: float, ambient_temp: float, is_in_water: bool, is_raining: bool) -> void:
	var target_temp = baseline_temp
	var cooling_factor = 0.02

	if is_in_water:
		# Água transfere calor 24x mais rápido que o ar
		cooling_factor = 0.08
		target_temp = minf(baseline_temp, ambient_temp)
	elif is_raining:
		cooling_factor = 0.04
		target_temp = minf(baseline_temp, ambient_temp - 2.0)
	elif ambient_temp > 35.0:
		# Insolação extrema em campo aberto sem hidratação
		target_temp = baseline_temp + (ambient_temp - 35.0) * 0.15

	current_body_temp = move_toward(current_body_temp, target_temp, cooling_factor * delta)

func _check_health_decay(delta: float) -> void:
	var damage = 0.0
	var cause = ""

	if current_thirst <= 0.0:
		damage += 2.0 * delta
		cause = "Desidratação Severa"
	if current_hunger <= 0.0:
		damage += 1.0 * delta
		cause = "Inanição Calórica"
	if current_body_temp < 34.0:
		damage += 1.5 * delta
		cause = "Hipotermia"
	elif current_body_temp > 39.5:
		damage += 2.0 * delta
		cause = "Insolação e Choque Térmico"

	if damage > 0.0:
		apply_damage(damage, cause)

func _emit_vitals() -> void:
	vitals_changed.emit(current_health, current_stamina, current_hunger, current_thirst, current_body_temp)

func serialize() -> Dictionary:
	return {
		"health": current_health,
		"stamina": current_stamina,
		"hunger": current_hunger,
		"thirst": current_thirst,
		"body_temp": current_body_temp,
		"is_dead": is_dead
	}

func deserialize(data: Dictionary) -> void:
	current_health = data.get("health", max_health)
	current_stamina = data.get("stamina", max_stamina)
	current_hunger = data.get("hunger", max_hunger)
	current_thirst = data.get("thirst", max_thirst)
	current_body_temp = data.get("body_temp", baseline_temp)
	is_dead = data.get("is_dead", false)
	_emit_vitals()
