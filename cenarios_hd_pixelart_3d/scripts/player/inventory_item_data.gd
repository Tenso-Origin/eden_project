@tool
extends Resource
class_name InventoryItemData

## =========================================================================
## DEFINIÇÃO DE ITEM DE INVENTÁRIO (David Holland Architecture)
## =========================================================================
## Recurso de dados leve e serializável que encapsula propriedades físicas,
## nutricionais e de durabilidade de itens no mundo do jogo.

enum ItemCategory {
	TOOL,
	WEAPON,
	MATERIAL,
	FOOD,
	MEDICINE,
	EQUIPMENT
}

@export var id: String = "empty"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: ItemCategory = ItemCategory.MATERIAL

@export_group("Propriedades Físicas")
## Massa em quilogramas (impacta peso total carregado e velocidade de corrida)
@export var weight_kg: float = 0.5
@export var is_stackable: bool = true
@export var max_stack: int = 64

@export_group("Propriedades de Sobrevivência")
## Calorias fornecidas ao ser consumido (kcal)
@export var calories: float = 0.0
## Hidratação fornecida em mililitros (ml)
@export var hydration_ml: float = 0.0
## Cura imediata de saúde (HP)
@export var health_restore: float = 0.0

@export_group("Durabilidade de Ferramentas")
@export var max_durability: float = 100.0
@export var current_durability: float = 100.0

func serialize() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"weight_kg": weight_kg,
		"current_durability": current_durability
	}

