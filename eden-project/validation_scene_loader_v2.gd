@tool
extends Node3D

## Loader de Cenários HD Pixel Art 3D (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://lago_ruinas.glb"

@export_group("Simulação de Maré")
## Habilita a simulação contínua e suave da maré
@export var tide_enabled: bool = true
## Nível mínimo da maré (maré baixa) no eixo Y (-0.8m)
@export var tide_min_y: float = -0.8
## Nível máximo da maré (maré alta) no eixo Y (-0.2m)
@export var tide_max_y: float = -0.2
## Velocidade da transição da maré
@export var tide_speed: float = 0.25
## Altura manual da água quando a maré automática estiver desativada
@export var manual_water_level: float = -0.5

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_FOLIAGE = preload("res://pixel_foliage.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const SHADER_METAL = preload("res://pixel_metal_mirror.gdshader")

var water_node: MeshInstance3D = null
var tide_time: float = 0.0

func _ready() -> void:
	tide_time = randf() * 100.0
	for child in get_children():
		child.queue_free()
		
	var scene_res = load(glb_path) as PackedScene
	if not scene_res:
		push_error("Falha ao carregar " + glb_path)
		return
		
	var instance = scene_res.instantiate()
	add_child(instance)
	
	setup_materials(instance)

func _process(delta: float) -> void:
	if not water_node or not is_instance_valid(water_node):
		return
		
	if tide_enabled:
		tide_time += delta * tide_speed
		# Composição harmônica não-linear com frequências orgânicas para maré pseudo-aleatória
		var h1 = sin(tide_time)
		var h2 = sin(tide_time * 1.618 + 1.3) * 0.38
		var h3 = cos(tide_time * 0.732 + 2.8) * 0.22
		var combined = (h1 + h2 + h3) / 1.6
		var tide_factor = clamp(combined * 0.5 + 0.5, 0.0, 1.0)
		water_node.position.y = lerpf(tide_min_y, tide_max_y, tide_factor)
	else:
		water_node.position.y = manual_water_level

func setup_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_name: String = child.name
			
			if mesh_name.begins_with("Tree_Canopy") or mesh_name.begins_with("Grass_Tuft"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_FOLIAGE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.12, 0.10, 0.24, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				mat.set_shader_parameter("wind_strength", 0.35)
				mat.set_shader_parameter("wind_speed", 2.2)
				child.material_override = mat
				
			elif mesh_name.begins_with("Water_Surface"):
				water_node = child
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("shallow_color", Color(0.18, 0.68, 0.82, 0.88))
				mat.set_shader_parameter("deep_color", Color(0.10, 0.42, 0.62, 0.95))
				mat.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))
				mat.set_shader_parameter("depth_fade_distance", 0.75)
				mat.set_shader_parameter("pixel_grid_density", 52.0)
				mat.set_shader_parameter("wave_speed", 2.0)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("shoreline_foam_dist", 0.32)
				mat.set_shader_parameter("shoreline_ripple_rings", 3)
				mat.set_shader_parameter("reflection_strength", 0.35)
				child.material_override = mat
				
			elif mesh_name.begins_with("Ore_Crystals"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_METAL
				mat.set_shader_parameter("metal_base_color", Color(0.35, 0.95, 0.78, 1.0))
				mat.set_shader_parameter("metal_dark_band", Color(0.08, 0.45, 0.42, 1.0))
				mat.set_shader_parameter("metal_highlight", Color(0.92, 1.0, 0.96, 1.0))
				mat.set_shader_parameter("mirror_reflectivity", 0.45)
				mat.set_shader_parameter("emission_energy", 0.35)
				child.material_override = mat
				
			elif mesh_name.begins_with("Soil") or mesh_name.begins_with("Tree_Trunk") or mesh_name.begins_with("Ruin") or mesh_name.begins_with("Rock") or mesh_name.begins_with("Riverbed"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				child.material_override = mat

		if child.get_child_count() > 0:
			setup_materials(child)
