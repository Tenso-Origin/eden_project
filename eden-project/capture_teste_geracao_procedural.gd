extends SceneTree

func _init():
	print("Iniciando teste de geracao procedural de terreno...")
	var root_scene = load("res://cena_teste_geracao_procedural.tscn").instantiate()
	root.add_child(root_scene)
	
	# Aguarda frames para geracao procedural dos chunks e inicializacao dos shaders
	for i in range(50):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	var cam = root_scene.find_child("Camera3D", true, false) as Camera3D
	
	var save_shot = func(path: String):
		var img = svp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("Salvo com sucesso: ", path)
			
	# 1. Visão Geral Panorâmica (size = 36.0, enquadra Campina -> Transição -> Floresta)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.5, 0.0)
		cam.size = 36.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_terreno_procedural_geral.png")
	
	# 2. Close-up da Região da Campina com Lago de Águas Claras (X = -26.0, Z = 0.0, size = 16.0)
	if pivot and cam:
		pivot.global_position = Vector3(-26.0, 0.8, 0.0)
		cam.size = 16.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_terreno_procedural_campina.png")
	
	# 3. Close-up da Floresta Profunda (X = 22.0, Z = 2.0, size = 18.0)
	# Mostra o rio de água preta de igarapé, montes acidentados, barrancos de laterita e matacões
	if pivot and cam:
		pivot.global_position = Vector3(22.0, 2.0, 2.0)
		cam.size = 18.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_terreno_procedural_floresta.png")
	
	print("Todas as capturas do terreno procedural concluidas com sucesso!")
	quit()

