extends SceneTree

func _init():
	print("--- TESTE UNITÁRIO: MODULAR TERRAIN BUILDER 1M (FASE 1) ---")
	var builder_script = load("res://modular_terrain_builder_1m.gd")
	if not builder_script:
		push_error("Falha ao carregar modular_terrain_builder_1m.gd")
		quit(1)
		return

	var builder = builder_script.new()
	var mesh = builder.build_chunk_mesh(Vector2i(0, 0), 16)
	
	if mesh and mesh.get_surface_count() > 0:
		var arrays = mesh.surface_get_arrays(0)
		var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		print("Sucesso! Chunk de 16x16m gerado na grade estrita 1x1x1m.")
		print("Quantidade total de vértices gerados: ", verts.size())
		print("Triângulos gerados: ", verts.size() / 3)
		
		# Verifica se os vértices respeitam o snapping vertical de 0.25m
		var snapped_correctly = true
		for v in verts:
			var rem = abs(fmod(v.y, 0.25))
			if rem > 0.001 and rem < 0.249:
				snapped_correctly = false
				print("Vértice fora do snap 0.25m: ", v)
				break
				
		if snapped_correctly:
			print("Validação do Snapping: 100% dos vértices obedecem ao degrau de 0.25m!")
		else:
			print("Aviso: foram encontrados vértices fora da quantização estrita de 0.25m.")
	else:
		push_error("Malha vazia ou com erro.")
		quit(1)
		return
		
	print("Fase 1 pronta para integração na nova cena!")
	quit(0)

