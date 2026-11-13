@tool
class_name AmazonBiosphereSimulator
extends Node3D

## AmazonBiosphereSimulator - Controlador Central da Biosfera Amazônica no Godot 4
##
## Implementa a simulação autônoma de fauna e flora neotropical sobre uma grade
## 16x16 células (cobrindo X e Z de -8.0m a +8.0m), espelhando com rigor matemático
## o SimCore C# (InfluenceMap, FaunaAgents, SpeciesCatalog e Lotka-Volterra).
##
## Suporta execução em tempo real no Godot Editor (@tool) e no jogo executável,
## gerenciando tokens 2D billboard (BiosphereToken2D) sincronizados no espaço 3D.

# --- IDENTIFICADORES DE ESPÉCIES (Alinhados com SpeciesCatalog.cs) ---
const ID_CUTIA: int = 1        # Dasyprocta leporina (Cutia / Roedor)
const ID_JAGUATIRICA: int = 10 # Leopardus pardalis (Jaguatirica / Mesopredador)
const ID_ONCA: int = 11        # Panthera onca (Onça-Pintada / Superpredador Topo)
const ID_CAPIVARA: int = 12    # Hydrochoerus hydrochaeris (Capivara / Herbívoro Semi-aquático)
const ID_HARPIA: int = 30      # Harpia harpyja (Harpia / Gavião-Real Amazônico)
const ID_JABUTI: int = 50      # Chelonoidis denticulatus (Jabuti-da-mata / Quelônio)

# --- DIETAS E GUILDAS TRÓFICAS ---
const DIET_HERBIVORE: int = 0
const DIET_CARNIVORE: int = 1
const DIET_OMNIVORE: int = 2
const DIET_AVIAN_APEX: int = 3

# --- ESTADOS COMPORTAMENTAIS (AgentState) ---
const STATE_FORAGING: int = 0 # Forrageando / Pastando
const STATE_HUNTING: int = 1  # Espreitando / Caçando
const STATE_FLEEING: int = 2  # Em fuga acelerada
const STATE_MATING: int = 3   # Cortejo / Acasalamento
const STATE_RESTING: int = 4  # Sono / Repouso
const STATE_DRINKING: int = 5 # Bebendo água
const STATE_DEAD: int = 6     # Decomposição

# --- DIMENSÕES DA GRADE 16x16 (Fallback para Chunk Único) ---
const GRID_SIZE: int = 16
const CELL_COUNT: int = 256 # 16 * 16
const WORLD_MIN: float = -8.0
const WORLD_MAX: float = 8.0
const CELL_SIZE: float = 1.0 # 16m / 16 células = 1m por célula

# --- DIREÇÕES DE NAVEGAÇÃO ESPACIAL 2D ---
const DIRECTIONS_8: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(-1.0, 0.0),
	Vector2(0.0, 1.0),
	Vector2(0.0, -1.0),
	Vector2(0.70710678, 0.70710678),
	Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, -0.70710678)
]

# --- REFERÊNCIAS DE CLASSES ---
const BiosphereToken2DClass = preload("res://biosphere_token_2d.gd")
const ModularTerrainBuilder1mClass = preload("res://modular_terrain_builder_1m.gd")

# =========================================================================
# PARÂMETROS EXPORTADOS PARA CALIBRAGEM VISUAL NO INSPECTOR
# =========================================================================
@export_group("Simulation Controls")
## Habilita ou pausa o ciclo da simulação ao vivo (funciona no Editor @tool e em Play)
@export var is_simulating: bool = true:
	set(val):
		is_simulating = val
		if is_inside_tree() and is_simulating and (agents.is_empty() or agents_container == null):
			setup_simulation()

## Frequência de ticks do motor da biosfera (Hz)
@export var sim_tick_rate: float = 10.0

## Hora do ciclo circadiano (0.0 a 24.0h: Dia das 06h às 18h)
@export_range(0.0, 24.0, 0.1) var current_sim_hour: float = 12.0

## Velocidade de avanço das horas por segundo real
@export var day_night_cycle_speed: float = 0.05

## Botão para reiniciar a população no Inspector
@export var respawn_population_trigger: bool = false:
	set(val):
		if val:
			respawn_population_trigger = false
			respawn_population()

@export_group("World Open-World Simulation")
## Caminho explícito opcional para o nó WorldStreamingManager100x100
@export var streaming_manager_path: NodePath

## Teto máximo de animais ativos no mundo aberto em torno da câmera (mantém 60 FPS cravados)
@export var max_world_agents: int = 60

## População mínima desejada no anel ativo da câmera
@export var min_world_agents: int = 45

## Distância em chunks da câmera para despawnar/reciclar agentes (> 7 chunks = > 112m)
@export var despawn_distance_chunks: float = 7.0

## Intervalo em segundos para checagem de spawn e despawn dinâmico
@export var dynamic_population_interval: float = 0.8

@export_group("Species Movement Speeds (m/s)")
@export var agouti_speed: float = 2.2
@export var capybara_speed: float = 1.8
@export var ocelot_speed: float = 2.5
@export var jaguar_speed: float = 3.0
@export var tortoise_speed: float = 0.6
@export var harpy_speed: float = 3.5

@export_group("Initial Population")
@export var initial_agouti_count: int = 6
@export var initial_capybara_count: int = 4
@export var initial_ocelot_count: int = 2
@export var initial_jaguar_count: int = 1
@export var initial_tortoise_count: int = 2
@export var initial_harpy_count: int = 1

# Aliases de compatibilidade para propriedades serializadas na cena .tscn
@export var spawn_agouti_count: int:
	get: return initial_agouti_count
	set(val): initial_agouti_count = val

@export var spawn_capybara_count: int:
	get: return initial_capybara_count
	set(val): initial_capybara_count = val

@export var spawn_ocelot_count: int:
	get: return initial_ocelot_count
	set(val): initial_ocelot_count = val

@export var spawn_jaguar_count: int:
	get: return initial_jaguar_count
	set(val): initial_jaguar_count = val

@export var spawn_tortoise_count: int:
	get: return initial_tortoise_count
	set(val): initial_tortoise_count = val

@export var spawn_harpy_count: int:
	get: return initial_harpy_count
	set(val): initial_harpy_count = val

# =========================================================================
# DADOS DA GRADE DO CHUNK (PackedFloat32Array de 256 elementos)
# =========================================================================
var biomass: PackedFloat32Array = PackedFloat32Array()
var grains: PackedFloat32Array = PackedFloat32Array()
var surface_water: PackedFloat32Array = PackedFloat32Array()
var elevation: PackedFloat32Array = PackedFloat32Array()
var food_gradient: PackedFloat32Array = PackedFloat32Array()
var danger_gradient: PackedFloat32Array = PackedFloat32Array()
var water_gradient: PackedFloat32Array = PackedFloat32Array()

# =========================================================================
# CLASSE DE AGENTE INDIVIDUAL (AgentData)
# =========================================================================
class AgentData extends RefCounted:
	var id: int = 0
	var species_id: int = 1
	var diet: int = 0
	var state: int = 0

	var health: float = 100.0
	var hunger: float = 10.0
	var thirst: float = 10.0
	var fatigue: float = 10.0
	var stamina: float = 100.0
	var is_exhausted: bool = false

	var pos_x: float = 0.0
	var pos_z: float = 0.0
	var vel_x: float = 0.0
	var vel_z: float = 0.0

	var is_diving: bool = false
	var breath: float = 20.0
	var max_breath: float = 20.0

	var is_alerted: bool = false
	var chase_timer: float = 0.0
	var chase_abandon_cooldown: float = 0.0
	var pounce_cooldown: float = 0.0
	var target_entity_id: int = 0

	var token_node: Node = null
	var decay_timer: float = 0.0
	var home_roost: Vector2 = Vector2.ZERO

# =========================================================================
# VARIÁVEIS INTERNAS DE CONTROLE E CONEXÃO COM O MUNDO ABERTO
# =========================================================================
var agents: Array = []
var agents_container: Node3D = null
var terrain_builder = null
var tick_accumulator: float = 0.0
var next_entity_id: int = 100

var world_min_x: float = -8.0
var world_max_x: float = 8.0
var world_min_z: float = -8.0
var world_max_z: float = 8.0

var streaming_manager = null
var dynamic_pop_timer: float = 0.0


func _ready() -> void:
	_connect_to_world_streaming()

	if terrain_builder == null and ModularTerrainBuilder1mClass:
		terrain_builder = ModularTerrainBuilder1mClass.new()

	init_chunk_data()

	if not Engine.is_editor_hint() or is_simulating:
		setup_simulation()


## Conecta dinamicamente com o WorldStreamingManager100x100 para expansão a 1.6 km
func _connect_to_world_streaming() -> void:
	var prev_mgr = streaming_manager
	streaming_manager = null

	if not streaming_manager_path.is_empty():
		streaming_manager = get_node_or_null(streaming_manager_path)
	if not streaming_manager:
		streaming_manager = get_node_or_null("../WorldStreamingManager")
	if not streaming_manager and get_parent() and get_parent().has_method("get_height_at"):
		streaming_manager = get_parent()

	if streaming_manager:
		# Mundo aberto 100x100 chunks (-800m a +800m)
		world_min_x = getattr_fallback(streaming_manager, "WORLD_MIN_X", -800.0)
		world_max_x = getattr_fallback(streaming_manager, "WORLD_MAX_X", 800.0)
		world_min_z = getattr_fallback(streaming_manager, "WORLD_MIN_Z", -800.0)
		world_max_z = getattr_fallback(streaming_manager, "WORLD_MAX_Z", 800.0)
	else:
		# Fallback para cena de chunk único clássica (-8.0m a +8.0m)
		world_min_x = -8.0
		world_max_x = 8.0
		world_min_z = -8.0
		world_max_z = 8.0


func getattr_fallback(target_obj: Object, prop_name: String, fallback_val: float) -> float:
	if target_obj and prop_name in target_obj:
		return float(target_obj.get(prop_name))
	return fallback_val


func _process(delta: float) -> void:
	if not is_simulating:
		return

	# Reconexão resiliente se o nó WorldStreamingManager foi instanciado tardiamente
	if streaming_manager == null and is_inside_tree():
		_connect_to_world_streaming()

	# Gerenciamento dinâmico de população (Spawning & Despawning por anel da câmera no mundo aberto)
	if streaming_manager:
		_manage_dynamic_population(delta)

	# Acumulador para ticks discretos da simulação ecológica (padrão 10 Hz)
	var sim_dt: float = 1.0 / maxf(1.0, sim_tick_rate)
	tick_accumulator += delta

	var max_steps: int = 4
	while tick_accumulator >= sim_dt and max_steps > 0:
		step_fauna(sim_dt)
		tick_accumulator -= sim_dt
		max_steps -= 1

	# Sincronização contínua das posições e estados dos tokens visuais
	_sync_visual_tokens(delta)


# =========================================================================
# 1. MAPEAMENTO E CONVERSÃO DE COORDENADAS (MUNDO <-> GRADE 16x16)
# =========================================================================

## Converte coordenada de mundo (wx, wz) [-8.0, +8.0] em coordenada de célula (gx, gz) [0..15]
func world_to_grid(wx: float, wz: float) -> Vector2i:
	var gx: int = clampi(int(floor(wx + 8.0)), 0, GRID_SIZE - 1)
	var gz: int = clampi(int(floor(wz + 8.0)), 0, GRID_SIZE - 1)
	return Vector2i(gx, gz)


## Converte coordenada de célula (gx, gz) [0..15] para o centro contínuo no mundo [-8.0, +8.0]
func grid_to_world(gx: int, gz: int) -> Vector2:
	var wx: float = (float(clampi(gx, 0, GRID_SIZE - 1)) + 0.5) - 8.0
	var wz: float = (float(clampi(gz, 0, GRID_SIZE - 1)) + 0.5) - 8.0
	return Vector2(wx, wz)


## Converte coordenada de célula (gx, gz) em índice 1D [0..255]
func grid_to_index(gx: int, gz: int) -> int:
	return (clampi(gz, 0, GRID_SIZE - 1) << 4) | clampi(gx, 0, GRID_SIZE - 1)


## Converte índice 1D [0..255] em coordenada de célula (gx, gz)
func index_to_grid(idx: int) -> Vector2i:
	idx = clampi(idx, 0, CELL_COUNT - 1)
	return Vector2i(idx & 15, idx >> 4)


## Converte coordenada contínua de mundo (wx, wz) diretamente em índice 1D [0..255]
func world_to_index(wx: float, wz: float) -> int:
	var gx: int = clampi(int(floor(wx + 8.0)), 0, GRID_SIZE - 1)
	var gz: int = clampi(int(floor(wz + 8.0)), 0, GRID_SIZE - 1)
	return (gz << 4) | gx


## Converte índice 1D [0..255] no centro contínuo correspondente no mundo
func index_to_world(idx: int) -> Vector2:
	var g: Vector2i = index_to_grid(idx)
	return grid_to_world(g.x, g.y)


# =========================================================================
# 2. CONSULTAS ANALÍTICAS DE TERRENO E LÂMINA D'ÁGUA
# =========================================================================

## Retorna a cota de relevo Y ajustada para a célula ou posição
func get_terrain_height(wx: float, wz: float) -> float:
	if streaming_manager and streaming_manager.has_method("get_height_at"):
		return float(streaming_manager.get_height_at(wx, wz))
	elif terrain_builder:
		# Builder usa coordenadas locais do chunk [0..16]
		return terrain_builder.evaluate_snapped_height(wx + 8.0, wz + 8.0)
	return 0.0


## Retorna os dados hidrológicos da coordenada (has_water, water_y, is_waterfall)
func get_water_info(wx: float, wz: float) -> Dictionary:
	if streaming_manager and streaming_manager.has_method("get_water_at"):
		var wy: float = float(streaming_manager.get_water_at(wx, wz))
		var has_w: bool = (wy > -500.0)
		return {
			"has_water": has_w,
			"water_y": wy if has_w else 0.0,
			"is_waterfall": false
		}
	elif terrain_builder:
		var lx: int = clampi(int(floor(wx + 8.0)), 0, GRID_SIZE - 1)
		var lz: int = clampi(int(floor(wz + 8.0)), 0, GRID_SIZE - 1)
		return terrain_builder.evaluate_water_cell(lx, lz)
	return {"has_water": false, "water_y": 0.0, "is_waterfall": false}


## Verifica se uma posição no mundo possui lâmina d'água superficial
func is_in_water(wx: float, wz: float) -> bool:
	if streaming_manager and streaming_manager.has_method("has_water_at"):
		return bool(streaming_manager.has_water_at(wx, wz))
	var winfo: Dictionary = get_water_info(wx, wz)
	return bool(winfo.get("has_water", false))


## Retorna a altitude Y de contato (superfície da água ou solo emerso)
func get_ground_or_water_y(wx: float, wz: float) -> float:
	if streaming_manager and streaming_manager.has_method("get_ground_or_water_y"):
		return float(streaming_manager.get_ground_or_water_y(wx, wz))
	var winfo: Dictionary = get_water_info(wx, wz)
	if winfo.get("has_water", false):
		return float(winfo.get("water_y", 0.0))
	return get_terrain_height(wx, wz)


# =========================================================================
# 3. DIFUSÃO CONTÍNUA POR BOX BLUR 3x3 (SEM A*)
# =========================================================================

## Aplica Box Blur 3x3 com normalização local de bordas idêntico ao InfluenceMap.cs
func apply_box_blur_3x3(src: PackedFloat32Array) -> PackedFloat32Array:
	var dst: PackedFloat32Array = PackedFloat32Array()
	dst.resize(CELL_COUNT)

	for y in range(GRID_SIZE):
		var y_min: int = maxi(0, y - 1)
		var y_max: int = mini(GRID_SIZE - 1, y + 1)
		var row_dst: int = y << 4

		for x in range(GRID_SIZE):
			var x_min: int = maxi(0, x - 1)
			var x_max: int = mini(GRID_SIZE - 1, x + 1)
			var sum: float = 0.0
			var count: int = 0

			for ny in range(y_min, y_max + 1):
				var row_offset: int = ny << 4
				for nx in range(x_min, x_max + 1):
					sum += src[row_offset | nx]
					count += 1

			dst[row_dst | x] = sum / float(count)

	return dst


# =========================================================================
# 4. INICIALIZAÇÃO DE DADOS DO CHUNK
# =========================================================================

func init_chunk_data() -> void:
	biomass.resize(CELL_COUNT)
	grains.resize(CELL_COUNT)
	surface_water.resize(CELL_COUNT)
	elevation.resize(CELL_COUNT)
	food_gradient.resize(CELL_COUNT)
	danger_gradient.resize(CELL_COUNT)
	water_gradient.resize(CELL_COUNT)

	for cz in range(GRID_SIZE):
		for cx in range(GRID_SIZE):
			var idx: int = (cz << 4) | cx
			var w_pos: Vector2 = grid_to_world(cx, cz)
			var winfo: Dictionary = get_water_info(w_pos.x, w_pos.y)
			var has_w: bool = bool(winfo.get("has_water", false))
			var water_y: float = float(winfo.get("water_y", 0.0))
			var terr_y: float = get_terrain_height(w_pos.x, w_pos.y)

			elevation[idx] = terr_y

			if has_w:
				surface_water[idx] = 1.0 if not bool(winfo.get("is_waterfall", false)) else 0.5
				biomass[idx] = 12.0 # Macrófitas e gramíneas de várzea na margem
				grains[idx] = 4.0
			else:
				surface_water[idx] = 0.0
				# Floresta densa de terra firme com serrapilheira e frutos caídos
				biomass[idx] = 55.0 + randf() * 30.0
				grains[idx] = 12.0 + randf() * 18.0

			food_gradient[idx] = biomass[idx] + grains[idx] * 1.5
			water_gradient[idx] = surface_water[idx] * 10.0
			danger_gradient[idx] = 0.0


# =========================================================================
# 5. GERENCIAMENTO E SPAWN DA FAUNA
# =========================================================================

func setup_simulation() -> void:
	_connect_to_world_streaming()

	# 1. Localizar ou instanciar container 'Agents'
	agents_container = get_node_or_null("Agents") as Node3D
	if not agents_container:
		agents_container = Node3D.new()
		agents_container.name = "Agents"
		add_child(agents_container)

	# 2. Limpar agentes e tokens antigos
	for child in agents_container.get_children():
		child.queue_free()
	agents.clear()

	# 3. Instanciar populações iniciais ajustadas
	if streaming_manager:
		# Povoamento distribuído nos chunks do mundo aberto 100x100
		_populate_initial_world_fauna()
	else:
		# Povoamento canônico da cena de chunk único (-8.0m a +8.0m)
		_spawn_species_group(ID_CUTIA, initial_agouti_count, Vector2(-4.0, 3.0), 3.0)
		_spawn_species_group(ID_CAPIVARA, initial_capybara_count, Vector2(0.5, 0.0), 2.5)
		_spawn_species_group(ID_JAGUATIRICA, initial_ocelot_count, Vector2(-5.0, -2.0), 2.0)
		_spawn_species_group(ID_ONCA, initial_jaguar_count, Vector2(4.5, -3.5), 1.5)
		_spawn_species_group(ID_JABUTI, initial_tortoise_count, Vector2(-2.5, 4.5), 2.0)
		_spawn_species_group(ID_HARPIA, initial_harpy_count, Vector2(0.0, 0.0), 1.0)


func respawn_population() -> void:
	init_chunk_data()
	setup_simulation()


func _spawn_species_group(sp_id: int, count: int, center: Vector2, spread: float) -> void:
	for i in range(count):
		var offset: Vector2 = Vector2((randf() - 0.5) * 2.0 * spread, (randf() - 0.5) * 2.0 * spread)
		var spawn_pos: Vector2 = center + offset
		spawn_pos.x = clampf(spawn_pos.x, world_min_x + 0.5, world_max_x - 0.5)
		spawn_pos.y = clampf(spawn_pos.y, world_min_z + 0.5, world_max_z - 0.5)
		spawn_agent(sp_id, spawn_pos)


func spawn_agent(sp_id: int, pos: Vector2) -> AgentData:
	var agent: AgentData = AgentData.new()
	agent.id = next_entity_id
	next_entity_id += 1
	agent.species_id = sp_id
	agent.pos_x = clampf(pos.x, world_min_x + 0.5, world_max_x - 0.5)
	agent.pos_z = clampf(pos.y, world_min_z + 0.5, world_max_z - 0.5)
	agent.home_roost = Vector2(agent.pos_x, agent.pos_z)
	agent.health = 100.0
	agent.hunger = 10.0 + randf() * 15.0
	agent.thirst = 10.0 + randf() * 10.0
	agent.fatigue = 5.0 + randf() * 10.0
	agent.stamina = 100.0

	# Guilda e Fisiologia
	match sp_id:
		ID_CUTIA:
			agent.diet = DIET_HERBIVORE
			agent.max_breath = 8.0
			agent.breath = 8.0
		ID_CAPIVARA:
			agent.diet = DIET_HERBIVORE
			agent.max_breath = 25.0
			agent.breath = 25.0
		ID_JAGUATIRICA:
			agent.diet = DIET_CARNIVORE
			agent.max_breath = 10.0
			agent.breath = 10.0
		ID_ONCA:
			agent.diet = DIET_CARNIVORE
			agent.max_breath = 12.0
			agent.breath = 12.0
		ID_JABUTI:
			agent.diet = DIET_HERBIVORE
			agent.max_breath = 15.0
			agent.breath = 15.0
		ID_HARPIA:
			agent.diet = DIET_AVIAN_APEX
			agent.max_breath = 10.0
			agent.breath = 10.0

	# Instanciar token visual correspondente
	if BiosphereToken2DClass and agents_container:
		var token = BiosphereToken2DClass.new()
		token.name = "Token_" + get_species_name(sp_id) + "_" + str(agent.id)
		token.species_id = sp_id
		agents_container.add_child(token)
		agent.token_node = token

		var gy: float = get_ground_or_water_y(agent.pos_x, agent.pos_z)
		token.update_token(agent.pos_x, agent.pos_z, gy, agent.state, agent.is_diving, agent.hunger / 100.0, agent.health, false)

	agents.append(agent)
	return agent


func get_species_name(sp_id: int) -> String:
	match sp_id:
		ID_CUTIA: return "Cutia"
		ID_JAGUATIRICA: return "Jaguatirica"
		ID_ONCA: return "Onca"
		ID_CAPIVARA: return "Capivara"
		ID_HARPIA: return "Harpia"
		ID_JABUTI: return "Jabuti"
		_: return "Fauna"


func get_species_speed(sp_id: int) -> float:
	match sp_id:
		ID_CUTIA: return agouti_speed
		ID_CAPIVARA: return capybara_speed
		ID_JAGUATIRICA: return ocelot_speed
		ID_ONCA: return jaguar_speed
		ID_JABUTI: return tortoise_speed
		ID_HARPIA: return harpy_speed
		_: return 1.5


# =========================================================================
# 6. TICK DE SIMULAÇÃO (StepFauna)
# =========================================================================

func step_fauna(dt: float) -> void:
	# 1. Ciclo Circadiano (Dia das 06h às 18h)
	current_sim_hour = fposmod(current_sim_hour + (day_night_cycle_speed * dt), 24.0)
	var is_daytime: bool = current_sim_hour >= 6.0 and current_sim_hour < 18.0

	# 2, 3 e 4. Atualização de gradientes da grade local (Apenas em cenas de chunk único)
	if not streaming_manager:
		# Regeneração lenta de vegetação (biomassa e frutos caídos)
		for idx in range(CELL_COUNT):
			biomass[idx] = minf(100.0, biomass[idx] + 0.45 * dt)
			grains[idx] = minf(50.0, grains[idx] + 0.20 * dt)
			food_gradient[idx] = biomass[idx] + grains[idx] * 1.5
			water_gradient[idx] = surface_water[idx] * 10.0
			danger_gradient[idx] = 0.0

		# Predadores projetam gradiente contínuo de perigo no mapa
		for ag in agents:
			var agent: AgentData = ag as AgentData
			if agent.health <= 0.0:
				continue

			var danger_val: float = 0.0
			if agent.species_id == ID_ONCA:
				danger_val = 100.0
			elif agent.species_id == ID_JAGUATIRICA:
				danger_val = 60.0
			elif agent.species_id == ID_HARPIA and is_daytime and agent.state != STATE_RESTING:
				danger_val = 30.0

			if danger_val > 0.0:
				_emit_radial_danger(agent.pos_x, agent.pos_z, danger_val, 3)

		# Difusão contínua por Box Blur 3x3 dos 3 gradientes
		food_gradient = apply_box_blur_3x3(food_gradient)
		water_gradient = apply_box_blur_3x3(water_gradient)
		danger_gradient = apply_box_blur_3x3(danger_gradient)

	# 5. Processamento comportamental dos agentes
	for ag in agents:
		var agent: AgentData = ag as AgentData
		if agent.health <= 0.0:
			agent.state = STATE_DEAD
			continue

		# Cooldowns e fisiologia
		if agent.chase_abandon_cooldown > 0.0:
			agent.chase_abandon_cooldown = maxf(0.0, agent.chase_abandon_cooldown - dt)
		if agent.pounce_cooldown > 0.0:
			agent.pounce_cooldown = maxf(0.0, agent.pounce_cooldown - dt)

		agent.hunger = minf(100.0, agent.hunger + 0.04 * dt)
		agent.thirst = minf(100.0, agent.thirst + 0.06 * dt)
		agent.stamina = minf(100.0, agent.stamina + 12.0 * dt)
		if agent.is_exhausted and agent.stamina >= 40.0:
			agent.is_exhausted = false

		var in_water: bool = is_in_water(agent.pos_x, agent.pos_z)
		if in_water:
			agent.thirst = maxf(0.0, agent.thirst - 40.0 * dt)

		# -------------------------------------------------------------
		# A) COMPORTAMENTO ESPECÍFICO: HARPIA (Avian Apex Predator)
		# -------------------------------------------------------------
		if agent.species_id == ID_HARPIA:
			if not is_daytime:
				# À noite: empoleira no ninho/copa e repousa
				var roost_pos: Vector2 = agent.home_roost if streaming_manager else Vector2(-5.0, -5.0)
				var to_roost: Vector2 = roost_pos - Vector2(agent.pos_x, agent.pos_z)
				if to_roost.length() <= 1.2:
					agent.state = STATE_RESTING
					agent.vel_x = 0.0
					agent.vel_z = 0.0
					continue
			else:
				if agent.state == STATE_RESTING:
					agent.state = STATE_FORAGING

		# -------------------------------------------------------------
		# B) COMPORTAMENTO ESPECÍFICO: CAPIVARA (Mergulho e Refúgio)
		# -------------------------------------------------------------
		if agent.species_id == ID_CAPIVARA:
			var predator_threat: bool = false
			for other_ag in agents:
				var other: AgentData = other_ag as AgentData
				if other == agent or other.health <= 0.0:
					continue
				if other.species_id == ID_ONCA or other.species_id == ID_JAGUATIRICA:
					var dist_sq: float = Vector2(agent.pos_x - other.pos_x, agent.pos_z - other.pos_z).length_squared()
					if dist_sq <= 36.0: # < 6.0m
						predator_threat = true
						break
				elif other.species_id == ID_HARPIA and is_daytime and other.state != STATE_RESTING:
					var dist_sq: float = Vector2(agent.pos_x - other.pos_x, agent.pos_z - other.pos_z).length_squared()
					if dist_sq <= 100.0: # < 10.0m
						predator_threat = true
						break

			# Se houver perigo iminente E estiver na água: ATIVA MERGULHO
			if in_water and predator_threat and agent.breath > 0.0:
				agent.is_diving = true
				agent.breath = maxf(0.0, agent.breath - dt)
				agent.is_alerted = true
			else:
				agent.is_diving = false
				agent.breath = minf(agent.max_breath, agent.breath + 3.5 * dt)
				if predator_threat and not in_water:
					agent.is_alerted = true
					agent.state = STATE_FLEEING
				else:
					agent.is_alerted = false
					if agent.state == STATE_FLEEING:
						agent.state = STATE_FORAGING

		# -------------------------------------------------------------
		# C) AVALIAÇÃO DE VIZINHANÇA E DIREÇÃO DE MOVIMENTO
		# -------------------------------------------------------------
		var target_world: Vector2
		if streaming_manager:
			# Mundo aberto 100x100: Steer vetorial contínuo sem limites de grade
			target_world = _steer_open_world(agent, is_daytime)
		else:
			# Chunk único: Influence Map 8-direcional na grade 16x16
			var cur_grid: Vector2i = world_to_grid(agent.pos_x, agent.pos_z)
			var best_score: float = _evaluate_cell_score(cur_grid.x, cur_grid.y, agent, is_daytime)
			var target_gx: int = cur_grid.x
			var target_gz: int = cur_grid.y

			for dy in range(-1, 2):
				var ny: int = cur_grid.y + dy
				if ny < 0 or ny >= GRID_SIZE:
					continue
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = cur_grid.x + dx
					if nx < 0 or nx >= GRID_SIZE:
						continue

					var score: float = _evaluate_cell_score(nx, ny, agent, is_daytime)
					if score > best_score:
						best_score = score
						target_gx = nx
						target_gz = ny

			target_world = grid_to_world(target_gx, target_gz)

		# -------------------------------------------------------------
		# D) MOVIMENTAÇÃO SUAVE EM DIREÇÃO AO PONTO ALVO
		# -------------------------------------------------------------
		var to_target: Vector2 = target_world - Vector2(agent.pos_x, agent.pos_z)
		var dist: float = to_target.length()

		if dist > 0.04:
			var move_dir: Vector2 = to_target / dist
			var speed: float = get_species_speed(agent.species_id)

			# Modificadores de velocidade física
			if in_water:
				if agent.species_id == ID_CAPIVARA:
					speed *= 1.35 # Capivara nada com agilidade
				elif agent.species_id == ID_ONCA:
					speed *= 0.70
				elif agent.species_id == ID_JAGUATIRICA:
					speed *= 0.35 # Jaguatirica odeia nadar
				elif agent.species_id == ID_HARPIA:
					speed *= 1.00 # Harpia voa livre
				else:
					speed *= 0.45

			if agent.is_diving:
				speed *= 0.85 # Arrasto subaquático

			if agent.is_alerted and not agent.is_exhausted and agent.stamina > 5.0:
				speed *= 1.40 # Arrancada anaeróbica (sprint)
				agent.stamina = maxf(0.0, agent.stamina - 20.0 * dt)
				if agent.stamina <= 0.0:
					agent.is_exhausted = true

			var step: float = speed * dt
			var actual_step: float = minf(dist, step)
			agent.pos_x = clampf(agent.pos_x + move_dir.x * actual_step, world_min_x + 0.5, world_max_x - 0.5)
			agent.pos_z = clampf(agent.pos_z + move_dir.y * actual_step, world_min_z + 0.5, world_max_z - 0.5)
			agent.vel_x = move_dir.x * speed
			agent.vel_z = move_dir.y * speed
		else:
			agent.vel_x = 0.0
			agent.vel_z = 0.0

		# -------------------------------------------------------------
		# E) FORRAGEAMENTO VEGETAL (CUTIA, CAPIVARA, JABUTI)
		# -------------------------------------------------------------
		if agent.diet == DIET_HERBIVORE and agent.hunger > 10.0:
			if not streaming_manager:
				var cur_idx: int = world_to_index(agent.pos_x, agent.pos_z)
				if grains[cur_idx] > 0.8:
					var grain_bite: float = minf(grains[cur_idx], 3.0 * dt)
					grains[cur_idx] -= grain_bite
					agent.hunger = maxf(0.0, agent.hunger - grain_bite * 2.2)
				elif biomass[cur_idx] > 1.5:
					var bite: float = minf(biomass[cur_idx], 2.5 * dt)
					biomass[cur_idx] -= bite
					agent.hunger = maxf(0.0, agent.hunger - bite * 1.0)
			else:
				# No mundo aberto, pastagem e forrageamento natural contínuo
				if agent.species_id == ID_CAPIVARA:
					agent.hunger = maxf(0.0, agent.hunger - 4.5 * dt)
				elif not is_in_water(agent.pos_x, agent.pos_z):
					agent.hunger = maxf(0.0, agent.hunger - 3.5 * dt)

		# -------------------------------------------------------------
		# F) PREDAÇÃO E COMBATE AMAZÔNICO
		# -------------------------------------------------------------
		if agent.diet == DIET_CARNIVORE:
			_process_carnivore_predation(agent, dt)
		elif agent.species_id == ID_HARPIA and is_daytime:
			_process_harpy_predation(agent, dt)


## Dispersão radial graduada de perigo (idêntico a InfluenceMap.cs)
func _emit_radial_danger(wx: float, wz: float, intensity: float, radius: int) -> void:
	var center_g: Vector2i = world_to_grid(wx, wz)
	var r_sq: float = float(radius * radius)

	for dy in range(-radius, radius + 1):
		var ny: int = center_g.y + dy
		if ny < 0 or ny >= GRID_SIZE:
			continue
		for dx in range(-radius, radius + 1):
			var nx: int = center_g.x + dx
			if nx < 0 or nx >= GRID_SIZE:
				continue

			var dist_sq: float = float(dx * dx + dy * dy)
			if dist_sq <= r_sq:
				var factor: float = 1.0 - (sqrt(dist_sq) / (float(radius) + 0.001))
				var cell_val: float = intensity * maxf(0.0, factor)
				var idx: int = (ny << 4) | nx
				if cell_val > danger_gradient[idx]:
					danger_gradient[idx] = cell_val


## Avaliação de score de cada célula candidata para direcionamento do agente
func _evaluate_cell_score(gx: int, gz: int, agent: AgentData, is_daytime: bool) -> float:
	var idx: int = (gz << 4) | gx
	var cell_pos: Vector2 = grid_to_world(gx, gz)
	var food: float = food_gradient[idx]
	var danger: float = danger_gradient[idx]
	var water: float = water_gradient[idx]
	var has_w: bool = surface_water[idx] > 0.05

	# 1. HERBÍVOROS (Cutia, Capivara, Jabuti)
	if agent.diet == DIET_HERBIVORE:
		var score: float = 0.0

		if agent.species_id == ID_CUTIA:
			# Cutia forrageia em terra firme e tem aversão a solo inundado
			var flood_penalty: float = -40.0 if has_w else 0.0
			var food_weight: float = (agent.hunger / 100.0) * 4.5
			var fear_weight: float = 9.0
			score = (food * food_weight) - (danger * fear_weight) + flood_penalty

			# Se sob perigo alto (> 8.0), busca refúgio em biomassa densa
			if danger > 8.0:
				score += biomass[idx] * 0.8
				agent.is_alerted = true
				agent.state = STATE_FLEEING
			else:
				agent.is_alerted = false
				agent.state = STATE_FORAGING

		elif agent.species_id == ID_CAPIVARA:
			# Capivara adora margens e várzeas (+15.0 de atratividade em células de água)
			var water_bonus: float = 15.0 if has_w else 0.0
			var food_weight: float = (agent.hunger / 100.0) * 3.5
			var fear_weight: float = 6.0 if not agent.is_diving else 0.5
			score = (food * food_weight) - (danger * fear_weight) + water_bonus

		elif agent.species_id == ID_JABUTI:
			# Jabuti é lento, tem casca dura, forrageia sem pânico e evita água funda
			var flood_penalty: float = -50.0 if has_w else 0.0
			score = (food * 3.0) - (danger * 1.5) + flood_penalty

		return score

	# 2. CARNÍVOROS (Jaguatirica e Onça-Pintada)
	elif agent.diet == DIET_CARNIVORE:
		var score: float = 0.0
		var in_water_penalty: float = -25.0 if has_w and agent.species_id == ID_JAGUATIRICA else (-5.0 if has_w else 0.0)
		score += in_water_penalty

		# Patrulha e atração olfativa sobre presas potenciais
		if agent.chase_abandon_cooldown <= 0.0:
			for other_ag in agents:
				var prey: AgentData = other_ag as AgentData
				if prey == agent or prey.health <= 0.0:
					continue

				# Validação de alvos viáveis por predador:
				var can_hunt: bool = false
				if agent.species_id == ID_JAGUATIRICA:
					# Jaguatirica caça Cutia; IGNORA o Jabuti (armadura impenetrável)
					if prey.species_id == ID_CUTIA:
						can_hunt = true
				elif agent.species_id == ID_ONCA:
					# Onça-Pintada caça Capivara, Cutia e quebra o Jabuti
					if prey.species_id == ID_CAPIVARA or prey.species_id == ID_CUTIA or prey.species_id == ID_JABUTI:
						can_hunt = true

				# Presa mergulhada sob a água é inacessível para predadores terrestres
				if prey.is_diving:
					can_hunt = false

				if can_hunt:
					var dist_to_prey: float = cell_pos.distance_to(Vector2(prey.pos_x, prey.pos_z))
					if dist_to_prey <= 12.0:
						score += (12.0 - dist_to_prey) * 4.0 * (agent.hunger / 50.0 + 0.5)

		# Patrulha em áreas onde herbívoros se alimentam
		score += food * 0.15
		return score

	# 3. HARPIA (Avian Apex Predator)
	else:
		if not is_daytime:
			# Noturno: atração pelo ninho no dossel
			var roost_pos: Vector2 = Vector2(-5.0, -5.0)
			return (25.0 - cell_pos.distance_to(roost_pos)) * 6.0

		var score: float = 0.0
		for other_ag in agents:
			var prey: AgentData = other_ag as AgentData
			if prey == agent or prey.health <= 0.0:
				continue

			# Harpia evita Onça adulta e ignora presas mergulhadas sob a água
			if prey.species_id == ID_ONCA or prey.is_diving:
				continue

			if prey.species_id == ID_CUTIA or prey.species_id == ID_CAPIVARA or prey.species_id == ID_JABUTI:
				var dist: float = cell_pos.distance_to(Vector2(prey.pos_x, prey.pos_z))
				if dist <= 14.0:
					score += (14.0 - dist) * 3.5 * (agent.hunger / 60.0 + 0.6)

		return score


## Lógica de caça e combate de carnívoros terrestres
func _process_carnivore_predation(carnivore: AgentData, dt: float) -> void:
	for other_ag in agents:
		var prey: AgentData = other_ag as AgentData
		if prey == carnivore or prey.health <= 0.0:
			continue

		# Presa mergulhada está totalmente protegida contra predadores terrestres
		if prey.is_diving:
			continue

		var can_attack: bool = false
		if carnivore.species_id == ID_JAGUATIRICA:
			# Jaguatirica não fere o Jabuti (armadura impenetrável para mesopredador)
			if prey.species_id == ID_CUTIA:
				can_attack = true
		elif carnivore.species_id == ID_ONCA:
			# Onça caça Capivara, Cutia e Jabuti
			if prey.species_id == ID_CAPIVARA or prey.species_id == ID_CUTIA or prey.species_id == ID_JABUTI:
				can_attack = true

		if not can_attack:
			continue

		var dist_to_prey: float = Vector2(carnivore.pos_x - prey.pos_x, carnivore.pos_z - prey.pos_z).length()

		# Espreita e bote (Pounce)
		if dist_to_prey <= 3.0 and carnivore.pounce_cooldown <= 0.0 and carnivore.stamina > 15.0:
			carnivore.pounce_cooldown = 4.0
			carnivore.state = STATE_HUNTING
			carnivore.vel_x *= 1.45
			carnivore.vel_z *= 1.45

		# Ataque corpo a corpo (< 1.3m)
		if dist_to_prey <= 1.30:
			var damage: float = 30.0
			if carnivore.species_id == ID_ONCA:
				damage = 50.0 # Mordida potente de 1000 psi
				if prey.species_id == ID_JABUTI:
					# Onça quebra a carapaça do Jabuti com força total
					damage = 45.0
			elif carnivore.species_id == ID_JAGUATIRICA:
				damage = 25.0

			prey.health = maxf(0.0, prey.health - damage)
			carnivore.state = STATE_HUNTING

			if prey.health <= 0.0:
				prey.state = STATE_DEAD
				carnivore.hunger = maxf(0.0, carnivore.hunger - 50.0)
				carnivore.chase_abandon_cooldown = 2.0
				carnivore.state = STATE_FORAGING

				# Fertiliza o solo onde a presa caiu (+25 de biomassa vegetal)
				_add_biomass_at(prey.pos_x, prey.pos_z, 25.0)
				break


## Lógica de patrulha e rasante da Harpia durante o dia
func _process_harpy_predation(harpy: AgentData, dt: float) -> void:
	for other_ag in agents:
		var prey: AgentData = other_ag as AgentData
		if prey == harpy or prey.health <= 0.0:
			continue

		# Harpia ignora presas mergulhadas sob a água e predadores de grande porte (Onça)
		if prey.is_diving or prey.species_id == ID_ONCA:
			continue

		if prey.species_id == ID_CUTIA or (prey.species_id == ID_CAPIVARA and not is_in_water(prey.pos_x, prey.pos_z)):
			var dist: float = Vector2(harpy.pos_x - prey.pos_x, harpy.pos_z - prey.pos_z).length()
			if dist <= 1.50 and harpy.hunger > 20.0:
				# Rasante de garras
				var harpy_damage: float = 40.0
				prey.health = maxf(0.0, prey.health - harpy_damage)
				harpy.state = STATE_HUNTING

				if prey.health <= 0.0:
					prey.state = STATE_DEAD
					harpy.hunger = maxf(0.0, harpy.hunger - 45.0)
					harpy.chase_abandon_cooldown = 3.0
					harpy.state = STATE_FORAGING
					break


# =========================================================================
# 7. SINCRONIZAÇÃO VISUAL CONTÍNUA DOS TOKENS (BiosphereToken2D)
# =========================================================================

func _sync_visual_tokens(delta: float) -> void:
	var i: int = agents.size() - 1
	while i >= 0:
		var agent: AgentData = agents[i] as AgentData

		if agent.token_node and is_instance_valid(agent.token_node):
			var gy: float = get_ground_or_water_y(agent.pos_x, agent.pos_z)
			var token = agent.token_node

			token.update_token(
				agent.pos_x,
				agent.pos_z,
				gy,
				agent.state,
				agent.is_diving,
				agent.hunger / 100.0,
				agent.health,
				agent.is_alerted
			)

			# Decaimento visual do token ao perecer
			if agent.health <= 0.0:
				agent.decay_timer += delta
				token.modulate.a = maxf(0.0, 1.0 - (agent.decay_timer / 4.0))

				if agent.decay_timer >= 4.0:
					token.queue_free()
					agent.token_node = null
					agents.remove_at(i)
		i -= 1


func _add_biomass_at(wx: float, wz: float, amount: float) -> void:
	if not streaming_manager:
		var dead_idx: int = world_to_index(wx, wz)
		biomass[dead_idx] = minf(100.0, biomass[dead_idx] + amount)


# =========================================================================
# 8. SISTEMA DE POPULAÇÃO DINÂMICA E STREAMING DE FAUNA (100x100 Chunks)
# =========================================================================

## Obtém a posição contínua de mundo da câmera ativa ou do CameraPivot
func get_camera_position() -> Vector3:
	if streaming_manager and streaming_manager.has_method("get_camera_pivot_position"):
		var p: Vector3 = streaming_manager.get_camera_pivot_position()
		if p != Vector3.ZERO or (streaming_manager.target_camera_pivot and not streaming_manager.target_camera_pivot.is_empty()):
			return p
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		return cam.global_position
	return Vector3.ZERO


## Retorna a lista de coordenadas Vector2i dos chunks carregados na malha
func get_active_chunk_coords() -> Array:
	if streaming_manager and "active_chunks" in streaming_manager:
		var chunks_dict = streaming_manager.get("active_chunks")
		if chunks_dict is Dictionary:
			return chunks_dict.keys()
	return []


## Contagem de indivíduos vivos de determinada espécie
func _count_species(sp_id: int) -> int:
	var count: int = 0
	for ag in agents:
		var agent: AgentData = ag as AgentData
		if agent.species_id == sp_id and agent.health > 0.0:
			count += 1
	return count


## Gerencia o ciclo contínuo de despawn e spawn ao redor da câmera no mundo aberto (1.6 km)
func _manage_dynamic_population(delta: float) -> void:
	if not streaming_manager:
		return

	dynamic_pop_timer += delta
	if dynamic_pop_timer < dynamic_population_interval:
		return
	dynamic_pop_timer = 0.0

	var cam_pos: Vector3 = get_camera_position()
	var despawn_dist_m: float = despawn_distance_chunks * 16.0 # 7 chunks = 112m
	var despawn_dist_sq: float = despawn_dist_m * despawn_dist_m

	# 1. Despawnar / reciclar agentes a mais de 7 chunks da câmera para preservar 60 FPS
	for i in range(agents.size() - 1, -1, -1):
		var ag: AgentData = agents[i] as AgentData
		var d_sq: float = Vector2(ag.pos_x - cam_pos.x, ag.pos_z - cam_pos.z).length_squared()
		var out_of_world: bool = (ag.pos_x < world_min_x or ag.pos_x > world_max_x or ag.pos_z < world_min_z or ag.pos_z > world_max_z)

		if d_sq > despawn_dist_sq or out_of_world:
			if ag.token_node and is_instance_valid(ag.token_node):
				ag.token_node.queue_free()
				ag.token_node = null
			agents.remove_at(i)

	# 2. Spawning dinâmico de novos animais caso a população esteja abaixo do teto
	if agents.size() < max_world_agents:
		var to_spawn: int = mini(3, max_world_agents - agents.size())
		var active_coords: Array = get_active_chunk_coords()

		for s in range(to_spawn):
			var spawn_pos: Vector2
			if not active_coords.is_empty():
				var rand_chunk: Vector2i = active_coords[randi() % active_coords.size()]
				var cx_world: float = float(rand_chunk.x) * 16.0
				var cz_world: float = float(rand_chunk.y) * 16.0
				spawn_pos = Vector2(
					cx_world + randf_range(1.5, 14.5),
					cz_world + randf_range(1.5, 14.5)
				)
			else:
				var angle: float = randf() * TAU
				var dist: float = randf_range(16.0, 52.0)
				spawn_pos = Vector2(
					cam_pos.x + cos(angle) * dist,
					cam_pos.z + sin(angle) * dist
				)

			spawn_pos.x = clampf(spawn_pos.x, world_min_x + 1.0, world_max_x - 1.0)
			spawn_pos.y = clampf(spawn_pos.y, world_min_z + 1.0, world_max_z - 1.0)

			_spawn_biome_appropriate_agent(spawn_pos)


## Seleciona a espécie nativa mais adequada com base no relevo e hidrologia do ponto
func _spawn_biome_appropriate_agent(pos: Vector2) -> void:
	var in_w: bool = is_in_water(pos.x, pos.y)
	var sp_id: int = ID_CUTIA

	if in_w:
		# Chunks com lâmina d'água (rio / igarapé / várzea): Capivaras!
		sp_id = ID_CAPIVARA
	else:
		# Chunks de terra firme / floresta: Cutias, Jabutis, Jaguatiricas, Onças-Pintadas e Harpias
		var harpy_count: int = _count_species(ID_HARPIA)
		if harpy_count < 3 and randf() < 0.10:
			sp_id = ID_HARPIA # No céu: Harpias sobrevoando a Y += 3.5m
		else:
			var roll: float = randf()
			if roll < 0.45:
				sp_id = ID_CUTIA       # Cutias forrageando
			elif roll < 0.70:
				sp_id = ID_JABUTI      # Jabutis
			elif roll < 0.88:
				sp_id = ID_JAGUATIRICA # Jaguatiricas
			else:
				sp_id = ID_ONCA        # Onças-Pintadas

	spawn_agent(sp_id, pos)


## Popula o mundo aberto imediatamente no anel ativo da câmera para início instantâneo
func _populate_initial_world_fauna() -> void:
	var cam_pos: Vector3 = get_camera_position()
	var active_coords: Array = get_active_chunk_coords()
	var initial_target: int = mini(max_world_agents, maxi(min_world_agents, 45))

	for i in range(initial_target):
		var spawn_pos: Vector2
		if not active_coords.is_empty():
			var rand_chunk: Vector2i = active_coords[randi() % active_coords.size()]
			var cx_world: float = float(rand_chunk.x) * 16.0
			var cz_world: float = float(rand_chunk.y) * 16.0
			spawn_pos = Vector2(
				cx_world + randf_range(1.5, 14.5),
				cz_world + randf_range(1.5, 14.5)
			)
		else:
			var angle: float = randf() * TAU
			var dist: float = randf_range(8.0, 50.0)
			spawn_pos = Vector2(
				cam_pos.x + cos(angle) * dist,
				cam_pos.z + sin(angle) * dist
			)

		spawn_pos.x = clampf(spawn_pos.x, world_min_x + 1.0, world_max_x - 1.0)
		spawn_pos.y = clampf(spawn_pos.y, world_min_z + 1.0, world_max_z - 1.0)

		_spawn_biome_appropriate_agent(spawn_pos)


# =========================================================================
# 9. IA E NAVEGAÇÃO ESPACIAL CONTÍNUA NO MUNDO ABERTO (100x100 Chunks)
# =========================================================================

## Avaliação de 8 direções no plano XZ contínuo sem restrição de grade discreta
func _steer_open_world(agent: AgentData, is_daytime: bool) -> Vector2:
	var cur_pos: Vector2 = Vector2(agent.pos_x, agent.pos_z)
	var best_pos: Vector2 = cur_pos
	var best_score: float = _evaluate_world_position_score(cur_pos, agent, is_daytime)

	# Amostragem em 8 direções ao redor do animal a 1.8m
	var sample_dist: float = 1.8
	for dir in DIRECTIONS_8:
		var cand_pos: Vector2 = cur_pos + dir * sample_dist
		cand_pos.x = clampf(cand_pos.x, world_min_x + 0.5, world_max_x - 0.5)
		cand_pos.y = clampf(cand_pos.y, world_min_z + 0.5, world_max_z - 0.5)

		var score: float = _evaluate_world_position_score(cand_pos, agent, is_daytime)
		if score > best_score:
			best_score = score
			best_pos = cand_pos

	return best_pos


## Avalia a atratividade ecológica de uma coordenada real no mundo aberto
func _evaluate_world_position_score(pos: Vector2, agent: AgentData, is_daytime: bool) -> float:
	var in_w: bool = is_in_water(pos.x, pos.y)

	# 1. HERBÍVOROS (Cutia, Capivara, Jabuti)
	if agent.diet == DIET_HERBIVORE:
		var danger: float = _calculate_world_predator_danger(pos, is_daytime)
		var score: float = 0.0

		if agent.species_id == ID_CUTIA:
			# Cutia forrageia em terra firme e tem aversão a solo inundado
			var flood_penalty: float = -40.0 if in_w else 0.0
			var food_val: float = 20.0 if not in_w else 0.0
			var food_weight: float = (agent.hunger / 100.0) * 4.5
			var fear_weight: float = 9.0
			score = (food_val * food_weight) - (danger * fear_weight) + flood_penalty

			if danger > 8.0:
				score += 15.0 # Busca refúgio
				agent.is_alerted = true
				agent.state = STATE_FLEEING
			else:
				agent.is_alerted = false
				agent.state = STATE_FORAGING

		elif agent.species_id == ID_CAPIVARA:
			# Capivara adora corpos d'água (+25 de bônus em água)
			var water_bonus: float = 25.0 if in_w else 0.0
			var food_weight: float = (agent.hunger / 100.0) * 3.5
			var fear_weight: float = 0.5 if agent.is_diving else 6.0
			score = (18.0 * food_weight) - (danger * fear_weight) + water_bonus

		elif agent.species_id == ID_JABUTI:
			# Jabuti é lento, evita água funda
			var flood_penalty: float = -50.0 if in_w else 0.0
			score = 15.0 - (danger * 1.5) + flood_penalty

		# Componente orgânica de exploração (evita trajetórias estáticas)
		score += sin(pos.x * 0.13 + pos.y * 0.17) * 2.0
		return score

	# 2. CARNÍVOROS (Jaguatirica e Onça-Pintada)
	elif agent.diet == DIET_CARNIVORE:
		var score: float = 0.0
		var in_water_penalty: float = -25.0 if in_w and agent.species_id == ID_JAGUATIRICA else (-5.0 if in_w else 0.0)
		score += in_water_penalty

		# Atração e rastreamento olfativo sobre presas viáveis em raio de até 20m
		if agent.chase_abandon_cooldown <= 0.0:
			for other_ag in agents:
				var prey: AgentData = other_ag as AgentData
				if prey == agent or prey.health <= 0.0 or prey.is_diving:
					continue

				var can_hunt: bool = false
				if agent.species_id == ID_JAGUATIRICA:
					if prey.species_id == ID_CUTIA:
						can_hunt = true
				elif agent.species_id == ID_ONCA:
					if prey.species_id == ID_CAPIVARA or prey.species_id == ID_CUTIA or prey.species_id == ID_JABUTI:
						can_hunt = true

				if can_hunt:
					var dist_to_prey: float = pos.distance_to(Vector2(prey.pos_x, prey.pos_z))
					if dist_to_prey <= 18.0:
						score += (18.0 - dist_to_prey) * 4.5 * (agent.hunger / 50.0 + 0.5)

		# Exploração orgânica
		score += cos(pos.x * 0.09 - pos.y * 0.11) * 2.0
		return score

	# 3. HARPIA (Avian Apex Predator)
	else:
		if not is_daytime:
			# Noturno: retorno ao poleiro de origem
			return (60.0 - pos.distance_to(agent.home_roost)) * 4.0

		var score: float = 0.0
		for other_ag in agents:
			var prey: AgentData = other_ag as AgentData
			if prey == agent or prey.health <= 0.0 or prey.is_diving or prey.species_id == ID_ONCA:
				continue

			if prey.species_id == ID_CUTIA or (prey.species_id == ID_CAPIVARA and not is_in_water(prey.pos_x, prey.pos_z)) or prey.species_id == ID_JABUTI:
				var dist: float = pos.distance_to(Vector2(prey.pos_x, prey.pos_z))
				if dist <= 28.0:
					score += (28.0 - dist) * 3.5 * (agent.hunger / 60.0 + 0.6)

		score += sin(pos.x * 0.05 + pos.y * 0.05) * 3.0
		return score


## Calcula o gradiente de perigo exercido por predadores sobre a coordenada
func _calculate_world_predator_danger(pos: Vector2, is_daytime: bool) -> float:
	var total_danger: float = 0.0
	for ag in agents:
		var pred: AgentData = ag as AgentData
		if pred.health <= 0.0:
			continue

		var intensity: float = 0.0
		var radius: float = 0.0
		if pred.species_id == ID_ONCA:
			intensity = 100.0
			radius = 12.0
		elif pred.species_id == ID_JAGUATIRICA:
			intensity = 60.0
			radius = 8.0
		elif pred.species_id == ID_HARPIA and is_daytime and pred.state != STATE_RESTING:
			intensity = 40.0
			radius = 14.0

		if intensity > 0.0:
			var dist: float = pos.distance_to(Vector2(pred.pos_x, pred.pos_z))
			if dist < radius:
				total_danger += intensity * (1.0 - (dist / radius))

	return total_danger
