extends SceneTree

func set_owner_recursive(node: Node, root: Node):
	for child in node.get_children():
		child.owner = root
		set_owner_recursive(child, root)

func _init():
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://ruinas_fonte.glb", state)
	if err == OK:
		var scene = gltf.generate_scene(state)
		
		# Prepara o ShaderMaterial com pixel_water.gdshader
		var shader = load("res://pixel_water.gdshader")
		var mat_water = ShaderMaterial.new()
		mat_water.shader = shader
		mat_water.set_shader_parameter("enable_3way_blend", false)
		mat_water.set_shader_parameter("use_voronoi", false)
		mat_water.set_shader_parameter("shallow_color", Color(0.18, 0.72, 0.82, 0.40))
		mat_water.set_shader_parameter("deep_color", Color(0.08, 0.32, 0.52, 0.70))
		mat_water.set_shader_parameter("depth_fade_distance", 1.20)
		mat_water.set_shader_parameter("pixel_grid_density", 64.0)
		mat_water.set_shader_parameter("wave_speed", 2.0)
		mat_water.set_shader_parameter("wave_height", 0.02)
		mat_water.set_shader_parameter("shoreline_foam_dist", 0.30)
		mat_water.set_shader_parameter("shoreline_ripple_rings", 3)
		mat_water.set_shader_parameter("contact_foam_threshold", 0.05)
		mat_water.set_shader_parameter("reflection_strength", 0.35)
		mat_water.set_shader_parameter("reflection_distortion_px", 1.8)
		mat_water.set_shader_parameter("wind_direction", Vector2(0.7071, 0.7071))
		mat_water.set_shader_parameter("wind_speed", 2.0)
		mat_water.set_shader_parameter("wind_strength", 1.0)
		mat_water.set_shader_parameter("refraction_strength", 4.0)
		mat_water.set_shader_parameter("dash_density", 0.55)
		mat_water.set_shader_parameter("dash_cycle_speed", 0.55)
		mat_water.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))
		
		var water_nodes = []
		for child in scene.get_children():
			if "Water" in child.name or "water" in child.name.to_lower():
				if child is MeshInstance3D:
					child.material_override = mat_water
					water_nodes.append(child.name)
		
		print("Water meshes found and assigned pixel_water shader: ", water_nodes)
		
		set_owner_recursive(scene, scene)
		var packed = PackedScene.new()
		var pack_err = packed.pack(scene)
		if pack_err == OK:
			var save_err = ResourceSaver.save(packed, "res://ruinas_fonte.tscn")
			if save_err == OK:
				print("Successfully generated res://ruinas_fonte.tscn with water meshes!")
			else:
				print("Failed to save scene: ", save_err)
		else:
			print("Failed to pack scene: ", pack_err)
	else:
		print("Failed to load GLTF: ", err)
	quit()

