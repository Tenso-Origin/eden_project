@tool
extends Node
class_name InventoryManager

## =========================================================================
## GERENCIADOR DE INVENTÁRIO E HOTBAR (David Holland Architecture)
## =========================================================================
## Controla o armazenamento matricial de itens (8 slots de Hotbar + 24 de Mochila),
## cálculo de peso total transportado, empilhamento e seleção ativa de ferramentas.

signal inventory_updated()
signal hotbar_selection_changed(slot_idx: int, item: InventoryItemData)
signal item_added(item: InventoryItemData, count: int)
signal inventory_full(item: InventoryItemData)

const HOTBAR_SLOT_COUNT: int = 8
const MAIN_SLOT_COUNT: int = 24
const TOTAL_SLOT_COUNT: int = HOTBAR_SLOT_COUNT + MAIN_SLOT_COUNT # 32 slots totais

@export var max_carry_capacity_kg: float = 45.0

# Array de 32 slots: cada elemento é { "item": InventoryItemData, "count": int } ou null
var slots: Array = []
var selected_hotbar_idx: int = 0

func _ready() -> void:
	if slots.is_empty():
		_initialize_slots()

func _initialize_slots() -> void:
	slots.clear()
	for i in range(TOTAL_SLOT_COUNT):
		slots.append(null)

func add_item(item: InventoryItemData, amount: int = 1) -> int:
	if not item or amount <= 0:
		return 0

	var remaining = amount

	# 1. Tenta empilhar em slots existentes que já contêm o mesmo item
	if item.is_stackable:
		for i in range(TOTAL_SLOT_COUNT):
			if slots[i] != null and slots[i].item.id == item.id:
				var available_space = item.max_stack - slots[i].count
				if available_space > 0:
					var to_add = mini(remaining, available_space)
					slots[i].count += to_add
					remaining -= to_add
					if remaining == 0:
						break

	# 2. Se sobrou, aloca em slots vazios (priorizando a hotbar 0-7, depois mochila 8-31)
	if remaining > 0:
		for i in range(TOTAL_SLOT_COUNT):
			if slots[i] == null:
				var to_add = mini(remaining, item.max_stack if item.is_stackable else 1)
				slots[i] = {
					"item": item,
					"count": to_add
				}
				remaining -= to_add
				if remaining == 0:
					break

	var added = amount - remaining
	if added > 0:
		item_added.emit(item, added)
		inventory_updated.emit()
		_notify_hotbar_if_affected()

	if remaining > 0:
		inventory_full.emit(item)

	return remaining

func remove_item_at(slot_idx: int, amount: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= TOTAL_SLOT_COUNT or slots[slot_idx] == null:
		return false

	var entry = slots[slot_idx]
	if entry.count <= amount:
		slots[slot_idx] = null
	else:
		entry.count -= amount

	inventory_updated.emit()
	if slot_idx == selected_hotbar_idx:
		_notify_hotbar_if_affected()
	return true

func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= TOTAL_SLOT_COUNT or idx_b < 0 or idx_b >= TOTAL_SLOT_COUNT:
		return
	var temp = slots[idx_a]
	slots[idx_a] = slots[idx_b]
	slots[idx_b] = temp
	inventory_updated.emit()
	_notify_hotbar_if_affected()

func select_hotbar_slot(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < HOTBAR_SLOT_COUNT:
		selected_hotbar_idx = slot_idx
		var active_item = get_active_hotbar_item()
		hotbar_selection_changed.emit(selected_hotbar_idx, active_item)

func get_active_hotbar_item() -> InventoryItemData:
	if selected_hotbar_idx >= 0 and selected_hotbar_idx < HOTBAR_SLOT_COUNT:
		if slots[selected_hotbar_idx] != null:
			return slots[selected_hotbar_idx].item
	return null

func get_total_weight() -> float:
	var total: float = 0.0
	for entry in slots:
		if entry != null and entry.item != null:
			total += entry.item.weight_kg * float(entry.count)
	return total

func _notify_hotbar_if_affected() -> void:
	var active_item = get_active_hotbar_item()
	hotbar_selection_changed.emit(selected_hotbar_idx, active_item)

func serialize() -> Dictionary:
	var serialized_slots: Array = []
	for i in range(TOTAL_SLOT_COUNT):
		if slots[i] != null:
			serialized_slots.append({
				"slot_idx": i,
				"item_id": slots[i].item.id,
				"count": slots[i].count,
				"durability": slots[i].item.current_durability
			})
	return {
		"selected_hotbar": selected_hotbar_idx,
		"slots": serialized_slots
	}

func deserialize(data: Dictionary, item_catalog_func: Callable) -> void:
	_initialize_slots()
	selected_hotbar_idx = data.get("selected_hotbar", 0)
	var serialized_slots = data.get("slots", [])
	for entry in serialized_slots:
		var slot_idx: int = entry.get("slot_idx", -1)
		var item_id: String = entry.get("item_id", "")
		var count: int = entry.get("count", 1)
		var durability: float = entry.get("durability", 100.0)

		if slot_idx >= 0 and slot_idx < TOTAL_SLOT_COUNT and item_catalog_func.is_valid():
			var item: InventoryItemData = item_catalog_func.call(item_id)
			if item:
				var item_clone = item.duplicate() as InventoryItemData
				item_clone.current_durability = durability
				slots[slot_idx] = {
					"item": item_clone,
					"count": count
				}

	inventory_updated.emit()
	_notify_hotbar_if_affected()

