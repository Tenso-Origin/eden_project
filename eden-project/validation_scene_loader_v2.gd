@tool
extends Node3D

## Loader de Cenários HD Pixel Art 3D com Planar Reflection Camera (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://lago_ruinas.glb"

@export_group("Simulação de Maré")
@export var tide_enabled: bool = true
@export var tide_min_y: float = -0.8
@export var tide_max_y: float = -0.2
@export var tide_speed: float = 0.25
@export var manual_water_level: float = -0.5

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_FOLIAGE = preload("res://pixel_foliage.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const SHADER_METAL = preload("res://pixel_metal_mirror.gdshader")

var water_node: MeshInstance3D = null
var tide_time: float = 0.0

var refl_vp: SubViewport = null
var refl_cam: Camera3D = null
var main_cam: Camera3D = null
var main_vp: SubViewport = null
var cutoff_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	tide_time = randf() * 100.0
	for child in get_children():
		child.queue_free()
		
	setup_reflection_viewport()
		
	var scene_res = load(glb_path) as PackedScene
	if not scene_res:
		push_error("Falha ao carregar " + glb_path)
		return
		
	var instance = scene_res.instantiate()
	add_child(instance)
	
	cutoff_materials.clear()
	setup_materials(instance)

func setup_reflection_viewport() -> void:
	if refl_vp and is_instance_valid(refl_vp):
		return
		
	main_vp = get_viewport() as SubViewport
	var root_node: Node = main_vp.get_parent() if main_vp else null
	
	if root_node:
		refl_vp = root_node.get_node_or_null("ReflectionViewport") as SubViewport
	if not refl_vp:
		refl_vp = get_node_or_null("ReflectionViewport") as SubViewport
		
	if not refl_vp:
		var vp_size = Vector2i(642, 362)
		if main_vp and main_vp.size != Vector2i.ZERO:
			vp_size = main_vp.size
			
		refl_vp = SubViewport.new()
		refl_vp.name = "ReflectionViewport"
		refl_vp.size = vp_size
		refl_vp.transparent_bg = true
		refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if root_node:
			root_node.add_child.call_deferred(refl_vp)
		else:
			add_child.call_deferred(refl_vp)
			
		refl_cam = Camera3D.new()
		refl_cam.name = "ReflectionCamera"
		refl_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		refl_cam.cull_mask = 1
		refl_cam.size = 7.2
		refl_vp.add_child(refl_cam)
	else:
		refl_cam = refl_vp.get_node_or_null("ReflectionCamera") as Camera3D

func _process(delta: float) -> void:
	if not water_node or not is_instance_valid(water_node):
		return
		
	var cur_water_y: float = manual_water_level
	if tide_enabled:
		tide_time += delta * tide_speed
		var h1 = sin(tide_time)
		var h2 = sin(tide_time * 1.618 + 1.3) * 0.38
		var h3 = cos(tide_time * 0.732 + 2.8) * 0.22
		var combined = (h1 + h2 + h3) / 1.6
		var tide_factor = clamp(combined * 0.5 + 0.5, 0.0, 1.0)
		cur_water_y = lerpf(tide_min_y, tide_max_y, tide_factor)
		water_node.position.y = cur_water_y
	else:
		cur_water_y = manual_water_level
		water_node.position.y = cur_water_y

	# Atualiza corte de geometria submersa (Y < water_y) para a ReflectionCamera
	for mat in cutoff_materials:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("water_cutoff_y", cur_water_y)

	# Assegura que refl_vp compartilha o mesmo world_3d da viewport principal
	if refl_vp and is_instance_valid(refl_vp) and main_vp and is_instance_valid(main_vp):
		var w3d = main_vp.find_world_3d()
		if w3d and refl_vp.world_3d != w3d:
			refl_vp.world_3d = w3d

	# Garante que a textura de reflexão está atribuída ao material da água
	if water_node and is_instance_valid(water_node) and refl_vp and is_instance_valid(refl_vp):
		var w_mat = water_node.material_override as ShaderMaterial
		if w_mat and w_mat.get_shader_parameter("reflection_texture") == null:
			w_mat.set_shader_parameter("reflection_texture", refl_vp.get_texture())

	# Atualiza câmeras e sincronização planar
	if not main_vp:
		main_vp = get_viewport() as SubViewport
	if not main_cam and main_vp:
		main_cam = main_vp.find_child("Camera3D", true, false)
		
	if main_cam and is_instance_valid(main_cam):
		if "refl_cam" in main_cam:
			main_cam.refl_cam = refl_cam
		if "water_y" in main_cam:
			main_cam.water_y = cur_water_y

	if refl_cam and is_instance_valid(refl_cam) and refl_cam.is_inside_tree() and main_cam and is_instance_valid(main_cam) and main_cam.is_inside_tree():
		refl_cam.size = main_cam.size
		var cam_pos: Vector3 = main_cam.global_position
		refl_cam.global_position = Vector3(cam_pos.x, 2.0 * cur_water_y - cam_pos.y, cam_pos.z)

		var forward: Vector3 = -main_cam.global_transform.basis.z
		var up: Vector3 = main_cam.global_transform.basis.y
		var refl_forward: Vector3 = Vector3(forward.x, -forward.y, forward.z).normalized()
		var refl_up: Vector3 = Vector3(-up.x, up.y, -up.z).normalized()
		refl_cam.look_at(refl_cam.global_position + refl_forward, refl_up)

func setup_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_name: String = child.name
			
			if mesh_name.begins_with("Tree_Canopy") or mesh_name.begins_with("Grass_Tuft"):
				child.layers = 1
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_FOLIAGE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.12, 0.10, 0.24, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				mat.set_shader_parameter("wind_strength", 0.35)
				mat.set_shader_parameter("wind_speed", 2.2)
				child.material_override = mat
				cutoff_materials.append(mat)
				
			elif mesh_name.begins_with("Water_Surface"):
				child.layers = 2
				water_node = child
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("shallow_color", Color(0.20, 0.72, 0.82, 0.82))
				mat.set_shader_parameter("deep_color", Color(0.08, 0.32, 0.54, 0.94))
				mat.set_shader_parameter("depth_fade_distance", 0.85)
				mat.set_shader_parameter("pixel_grid_density", 52.0)
				mat.set_shader_parameter("wave_speed", 1.8)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("shoreline_foam_dist", 0.28)
				mat.set_shader_parameter("reflection_strength", 0.55)
				mat.set_shader_parameter("wave_ripple_strength", 1.8)
				if refl_vp:
					mat.set_shader_parameter("reflection_texture", refl_vp.get_texture())
				child.material_override = mat
				
			elif mesh_name.begins_with("Riverbed"):
				child.layers = 2
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				child.material_override = mat
				
			elif mesh_name.begins_with("Ore_Crystals"):
				child.layers = 1
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_METAL
				mat.set_shader_parameter("metal_base_color", Color(0.35, 0.95, 0.78, 1.0))
				mat.set_shader_parameter("metal_dark_band", Color(0.08, 0.45, 0.42, 1.0))
				mat.set_shader_parameter("metal_highlight", Color(0.92, 1.0, 0.96, 1.0))
				mat.set_shader_parameter("mirror_reflectivity", 0.45)
				mat.set_shader_parameter("emission_energy", 0.35)
				child.material_override = mat
				cutoff_materials.append(mat)
				
			elif mesh_name.begins_with("Soil") or mesh_name.begins_with("Tree_Trunk") or mesh_name.begins_with("Ruin") or mesh_name.begins_with("Rock"):
				child.layers = 1
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				child.material_override = mat
				cutoff_materials.append(mat)

		if child.get_child_count() > 0:
			setup_materials(child)
