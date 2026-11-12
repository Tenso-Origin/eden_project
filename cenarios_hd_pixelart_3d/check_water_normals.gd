extends SceneTree

func _init():
	var scene = load("res://cena2_4.tscn").instantiate()
	var ruinas = scene.find_child("RuinasFonte", true, false)
	if ruinas:
		for child in ruinas.get_children():
			if "Water" in child.name:
				print("Child: ", child.name)
				var mesh = child.mesh as ArrayMesh
				if mesh:
					var mdt = MeshDataTool.new()
					mdt.create_from_surface(mesh, 0)
					print("  Vertex count: ", mdt.get_vertex_count(), " Face count: ", mdt.get_face_count())
					if mdt.get_face_count() > 0:
						var normal = mdt.get_face_normal(0)
						print("  Face 0 normal (local): ", normal)
						var t = child.global_transform
						var world_normal = (t.basis * normal).normalized()
						print("  Face 0 normal (world): ", world_normal)
	quit()

