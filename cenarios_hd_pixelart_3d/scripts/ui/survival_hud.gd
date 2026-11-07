@tool
extends Control
class_name SurvivalHUD

## =========================================================================
## HUD DE SOBREVIVÊNCIA E ESTADO DO MUNDO (David Holland Architecture)
## =========================================================================
## Interface 2D em pixel art que apresenta dados vitais fisiológicos,
## relógio equatorial solar, calendário estacional e hotbar de ferramentas.

@export_group("Referências de Sistemas")
@export var vitals: PlayerVitals
@export var inventory: InventoryManager
@export var day_night_cycle: DayNightCycleController

@export_group("Nós de Interface (UI)")
@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var hunger_bar: ProgressBar
@export var thirst_bar: ProgressBar
@export var temp_label: Label
@export var clock_label: Label
@export var season_label: Label
@export var hotbar_container: HBoxContainer

func _ready() -> void:
	if not Engine.is_editor_hint():
		_connect_signals()

func _connect_signals() -> void:
	if vitals:
		vitals.vitals_changed.connect(_on_vitals_changed)
		_on_vitals_changed(
			vitals.current_health,
			vitals.current_stamina,
			vitals.current_hunger,
			vitals.current_thirst,
			vitals.current_body_temp
		)

	if day_night_cycle:
		day_night_cycle.time_changed.connect(_on_time_changed)
		var info = day_night_cycle.get_sim_date()
		_update_clock_ui(info.time_str, info.full_str, info.season_name)

	if inventory:
		inventory.inventory_updated.connect(_on_inventory_updated)
		inventory.hotbar_selection_changed.connect(_on_hotbar_selection_changed)
		_on_inventory_updated()

func _on_vitals_changed(hp: float, stamina: float, hunger: float, thirst: float, body_temp: float) -> void:
	if health_bar:
		health_bar.value = hp
	if stamina_bar:
		stamina_bar.value = stamina
	if hunger_bar:
		hunger_bar.value = (hunger / (vitals.max_hunger if vitals else 2500.0)) * 100.0
	if thirst_bar:
		thirst_bar.value = (thirst / (vitals.max_thirst if vitals else 3000.0)) * 100.0
	if temp_label:
		temp_label.text = "%.1f °C" % body_temp
		if body_temp < 35.0:
			temp_label.modulate = Color(0.4, 0.7, 1.0) # Azul hipotermia
		elif body_temp > 38.0:
			temp_label.modulate = Color(1.0, 0.3, 0.2) # Vermelho hipertermia
		else:
			temp_label.modulate = Color.WHITE

func _on_time_changed(_hour: float, _day: int, _date_str: String) -> void:
	if day_night_cycle:
		var info = day_night_cycle.get_sim_date()
		_update_clock_ui(info.time_str, info.full_str, info.season_name)

func _update_clock_ui(time_str: String, _full_str: String, season_name: String) -> void:
	if clock_label:
		clock_label.text = time_str
	if season_label:
		season_label.text = season_name

func _on_inventory_updated() -> void:
	if not hotbar_container or not inventory:
		return
	var children = hotbar_container.get_children()
	for i in range(mini(children.size(), InventoryManager.HOTBAR_SLOT_COUNT)):
		var slot_panel = children[i] as Panel
		if not slot_panel:
			continue
		var count_label = slot_panel.get_node_or_null("CountLabel") as Label
		var icon_rect = slot_panel.get_node_or_null("IconRect") as TextureRect

		var entry = inventory.slots[i] if i < inventory.slots.size() else null
		if entry != null and entry.item != null:
			if icon_rect:
				icon_rect.texture = entry.item.icon
				icon_rect.visible = true
			if count_label:
				count_label.text = str(entry.count) if entry.count > 1 else ""
				count_label.visible = entry.count > 1
		else:
			if icon_rect:
				icon_rect.visible = false
			if count_label:
				count_label.visible = false

func _on_hotbar_selection_changed(slot_idx: int, _active_item: InventoryItemData) -> void:
	if not hotbar_container:
		return
	var children = hotbar_container.get_children()
	for i in range(children.size()):
		var slot_panel = children[i] as Panel
		if slot_panel:
			if i == slot_idx:
				slot_panel.modulate = Color(1.3, 1.3, 0.8) # Realce do slot selecionado
			else:
				slot_panel.modulate = Color.WHITE

