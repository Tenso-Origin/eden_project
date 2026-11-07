@tool
extends Node3D
## =========================================================================
## SHADOW PROXY GENERATOR — @tool para Godot 4
## =========================================================================
## Funde toda a geometria dos filhos MeshInstance3D em um único ArrayMesh
## que projeta sombra, enquanto desliga as sombras individuais de cada peça.
## Isso elimina "shadow z-fighting" e sobreposição de sombras em grupos de
## pedras, pilares ou qualquer conjunto modular de meshes.
##
## USO:
##   1. Anexe este script ao Node3D raiz do grupo (ex: RockGroup, PillarSet).
##   2. No Inspetor, marque "Generate Shadow Proxy" para executar.
##   3. Um nó filho chamado "ShadowProxy" será criado automaticamente.
##   4. Para regenerar, delete o "ShadowProxy" existente e marque novamente.
## =========================================================================

## Botão de acionamento no Inspetor: marque para gerar o proxy de sombra.
@export var generate_shadow_proxy: bool = false:
	set(val):
		# Funciona como botão: executa e retorna para false imediatamente.
		if val and Engine.is_editor_hint():
			_run_generate()
		generate_shadow_proxy = false

## Se verdadeiro, também remove qualquer ShadowProxy anterior antes de gerar.
@export var overwrite_existing: bool = true


func _run_generate() -> void:
	# -----------------------------------------------------------------------
	# PASSO 1: Segurança — verifica se estamos no editor e dentro da árvore.
	# -----------------------------------------------------------------------
	if not is_inside_tree():
		push_error("[ShadowProxyGenerator] Nó não está na árvore. Operação cancelada.")
		return

	print("[ShadowProxyGenerator] Iniciando geração do Shadow Proxy para: ", name)

	# -----------------------------------------------------------------------
	# PASSO 2: Remove ShadowProxy anterior se existir e overwrite estiver ativo.
	# -----------------------------------------------------------------------
	var existing := find_child("ShadowProxy", false, false)
	if existing:
		if overwrite_existing:
			print("[ShadowProxyGenerator] Removendo ShadowProxy existente...")
			existing.queue_free()
			# Aguarda um frame para garantir que o nó foi removido da árvore.
			await get_tree().process_frame
		else:
			push_warning("[ShadowProxyGenerator] ShadowProxy já existe. Ative 'Overwrite Existing' para substituir.")
			return

	# -----------------------------------------------------------------------
	# PASSO 3: Coleta todos os MeshInstance3D filhos recursivamente.
	# -----------------------------------------------------------------------
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, mesh_instances)

	if mesh_instances.is_empty():
		push_warning("[ShadowProxyGenerator] Nenhum MeshInstance3D encontrado nos filhos de: ", name)
		return

	print("[ShadowProxyGenerator] Meshes encontrados: ", mesh_instances.size())

	# -----------------------------------------------------------------------
	# PASSO 4: Usa o SurfaceTool para combinar todas as superfícies em um
	# único ArrayMesh. Cada mesh filho contribui com sua geometria já
	# transformada para o espaço local do nó raiz (este nó).
	# -----------------------------------------------------------------------
	var combined_mesh := ArrayMesh.new()
	var st := SurfaceTool.new()

	for mi in mesh_instances:
		var source_mesh := mi.mesh
		if not source_mesh:
			continue

		# Calcula a transformação relativa do MeshInstance em relação a ESTE nó.
		# Isso garante que a geometria combinada esteja no espaço local correto.
		var relative_xform: Transform3D = global_transform.affine_inverse() * mi.global_transform

		# Itera sobre cada superfície do mesh fonte.
		for surf_idx in range(source_mesh.get_surface_count()):
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

			# Cria um MeshDataTool para ler os vértices da superfície atual.
			var mdt := MeshDataTool.new()
			# Cria um ArrayMesh temporário com apenas esta superfície para o MDT.
			var temp_mesh := ArrayMesh.new()
			source_mesh.surface_tool_begin_copy(surf_idx, st)

			# Alternativa robusta: lemos os arrays da superfície diretamente.
			st.clear()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

			var arrays: Array = source_mesh.surface_get_arrays(surf_idx)
			var verts: PackedVector3Array  = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
			var uvs: PackedVector2Array    = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
			var indices: PackedInt32Array  = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

			var has_normals: bool = normals.size() == verts.size()
			var has_uvs: bool     = uvs.size() == verts.size()

			if indices.size() > 0:
				# Mesh indexada: percorre os triângulos via índices.
				for i in range(0, indices.size(), 3):
					for k in [0, 1, 2]:
						var vi: int = indices[i + k]
						# Transforma o vértice para o espaço local do nó raiz.
						var local_pos: Vector3 = relative_xform * verts[vi]
						if has_normals:
							# Transforma a normal (apenas orientação, sem translação).
							st.set_normal(relative_xform.basis * normals[vi])
						if has_uvs:
							st.set_uv(uvs[vi])
						st.add_vertex(local_pos)
			else:
				# Mesh não indexada: vértices já estão em ordem de triângulos.
				for vi in range(verts.size()):
					var local_pos: Vector3 = relative_xform * verts[vi]
					if has_normals:
						st.set_normal(relative_xform.basis * normals[vi])
					if has_uvs:
						st.set_uv(uvs[vi])
					st.add_vertex(local_pos)

			# Gera índices automaticamente e consolida no ArrayMesh combinado.
			st.index()
			st.commit(combined_mesh)

		# PASSO 4b: Desliga a sombra do MeshInstance original para que apenas
		# o proxy unificado projete sombra, eliminando a sobreposição.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		print("  → Sombra desligada em: ", mi.name)

	# -----------------------------------------------------------------------
	# PASSO 5: Cria o nó ShadowProxy com o ArrayMesh combinado e configura
	# para projetar APENAS sombra (invisível para a câmera, sem custo visual).
	# -----------------------------------------------------------------------
	if combined_mesh.get_surface_count() == 0:
		push_error("[ShadowProxyGenerator] Nenhuma geometria válida foi combinada. Verifique os meshes filhos.")
		return

	var proxy := MeshInstance3D.new()
	proxy.name = "ShadowProxy"
	proxy.mesh = combined_mesh

	# SHADOWS_ONLY: o proxy é invisível para a câmera mas projeta sombras,
	# eliminando o z-fighting e a sobreposição de sombras das peças individuais.
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	# O proxy está no espaço local do nó raiz, então não precisa de transform extra.
	proxy.transform = Transform3D.IDENTITY

	add_child(proxy)

	# Necessário para que o nó seja salvo junto com a cena no editor.
	proxy.owner = get_tree().edited_scene_root

	print("[ShadowProxyGenerator] ✓ ShadowProxy criado com ", combined_mesh.get_surface_count(), " superfície(s).")
	print("[ShadowProxyGenerator] ✓ Sombras individuais desligadas em ", mesh_instances.size(), " mesh(es).")


## Coleta recursivamente todos os MeshInstance3D na hierarquia de filhos,
## ignorando o próprio ShadowProxy para evitar loop de auto-referência.
func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		# Ignora o ShadowProxy para não combinar a si mesmo recursivamente.
		if child.name == "ShadowProxy":
			continue
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		# Recursão para filhos aninhados.
		_collect_mesh_instances(child, result)
