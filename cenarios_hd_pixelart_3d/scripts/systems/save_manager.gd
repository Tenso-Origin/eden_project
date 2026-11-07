@tool
extends Node
class_name SaveManager

## =========================================================================
## GERENCIADOR DE PERSISTÊNCIA E SAVE/LOAD (David Holland Architecture)
## =========================================================================
## Serializa o estado completo do jogo para JSON em user://save_game.json,
## incluindo vitals fisiológicos, inventário, coordenadas e ciclo solar.

const SAVE_FILE_PATH: String = "user://eden_savegame.json"
const SAVE_VERSION: String = "1.0.0"

signal save_completed()
signal load_completed()
signal save_error(message: String)

@export var player: CharacterBody3D
@export var vitals: PlayerVitals
@export var inventory: InventoryManager
@export var day_night_cycle: DayNightCycleController

func save_game() -> bool:
	var save_data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"player": {},
		"vitals": {},
		"inventory": {},
		"time": {}
	}

	# 1. Posição e Rotação do Jogador
	if player:
		save_data["player"] = {
			"position": {
				"x": player.global_position.x,
				"y": player.global_position.y,
				"z": player.global_position.z
			},
			"rotation_y": player.rotation.y
		}

	# 2. Vitals Fisiológicos
	if vitals:
		save_data["vitals"] = vitals.serialize()

	# 3. Inventário
	if inventory:
		save_data["inventory"] = inventory.serialize()

	# 4. Calendário e Horário Solar
	if day_night_cycle:
		save_data["time"] = {
			"current_hour": day_night_cycle.current_hour,
			"day_of_year": day_night_cycle.day_of_year,
			"current_year": day_night_cycle.current_year
		}

	var json_str := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		save_error.emit("Erro ao abrir arquivo para escrita: %d" % err)
		return false

	file.store_string(json_str)
	file.close()
	save_completed.emit()
	print("[SaveManager] Jogo salvo com sucesso em: ", SAVE_FILE_PATH)
	return true

func load_game(item_catalog_func: Callable = Callable()) -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		save_error.emit("Nenhum arquivo de save encontrado.")
		return false

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		var err := FileAccess.get_open_error()
		save_error.emit("Erro ao abrir arquivo de save: %d" % err)
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK:
		save_error.emit("Erro ao analisar JSON de save: %s na linha %d" % [json.get_error_message(), json.get_error_line()])
		return false

	var data: Dictionary = json.data as Dictionary

	# 1. Restaura Posição do Jogador
	if player and data.has("player"):
		var p_data: Dictionary = data["player"]
		var pos_dict: Dictionary = p_data.get("position", {})
		if not pos_dict.is_empty():
			player.global_position = Vector3(
				pos_dict.get("x", 0.0),
				pos_dict.get("y", 0.0),
				pos_dict.get("z", 0.0)
			)
		player.rotation.y = p_data.get("rotation_y", 0.0)

	# 2. Restaura Vitals
	if vitals and data.has("vitals"):
		vitals.deserialize(data["vitals"])

	# 3. Restaura Inventário
	if inventory and data.has("inventory"):
		inventory.deserialize(data["inventory"], item_catalog_func)

	# 4. Restaura Calendário Solar
	if day_night_cycle and data.has("time"):
		var t_data: Dictionary = data["time"]
		day_night_cycle.current_hour = t_data.get("current_hour", 12.0)
		day_night_cycle.day_of_year = t_data.get("day_of_year", 80)
		day_night_cycle.current_year = t_data.get("current_year", 1)

	load_completed.emit()
	print("[SaveManager] Jogo carregado com sucesso.")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

