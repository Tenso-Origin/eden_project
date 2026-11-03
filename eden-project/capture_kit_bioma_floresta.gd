extends SceneTree

func _init():
	var root_scene = load("res://cena_kit_bioma_floresta.tscn").instantiate()
	root.add_child(root_scene)
	
	for i in range(45):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	var cam = root_scene.find_child("Camera3D", true, false) as Camera3D
	var initial_rot = pivot.rotation if pivot else Vector3.ZERO
	var initial_pos = pivot.global_position if pivot else Vector3.ZERO
	var initial_size = cam.size if cam else 10.0
	
	var save_shot = func(path: String):
		var img = svp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("Salvo: ", path)
			
	# 1. Visão Geral Panorâmica do Kit (size = 10.0)
	save_shot.call("res://screenshot_kit_bioma_floresta.png")
	
	# 2. Visão Rotacionada 45°
	if pivot:
		pivot.rotate_y(deg_to_rad(45.0))
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_kit_bioma_floresta_rotacionado.png")
	
	# Restaura rotação e posição
	if pivot:
		pivot.rotation = initial_rot
		pivot.global_position = initial_pos
	if cam:
		cam.size = initial_size
		
	# 3. Close-up Águas Tropicais (X=0, Z=0)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 0.5, 0.0)
		cam.size = 5.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_kit_aguas.png")
	
	# 4. Close-up Solo Orgânico & Rampas (X=2.0, Z=-2.2)
	if pivot and cam:
		pivot.global_position = Vector3(2.0, 0.6, -2.2)
		cam.size = 5.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_kit_solo_organico.png")
	
	# 5. Close-up Subsolo Laterita & Areia Branca (X=5.0, Z=-0.7)
	if pivot and cam:
		pivot.global_position = Vector3(5.0, 0.6, -0.7)
		cam.size = 5.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_kit_subsolo_e_areia.png")
	
	# 6. Close-up Matacão de Granito (X=8.5, Z=-1.5)
	if pivot and cam:
		pivot.global_position = Vector3(8.5, 1.2, -1.5)
		cam.size = 5.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_kit_matacao.png")
	
	print("Todas as capturas concluidas com sucesso!")
	quit()
