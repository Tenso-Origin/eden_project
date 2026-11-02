extends SceneTree

func _init():
	var root_scene = load("res://cena_riacho_floresta.tscn").instantiate()
	root.add_child(root_scene)
	
	for i in range(45):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	var cam = root_scene.find_child("Camera3D", true, false) as Camera3D
	var initial_rot = pivot.rotation if pivot else Vector3.ZERO
	var initial_pos = pivot.global_position if pivot else Vector3.ZERO
	var initial_size = cam.size if cam else 7.5
	
	var save_shot = func(path: String):
		var img = svp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("Salvo: ", path)
			
	# 1. Visão Geral Panorâmica (size = 7.5)
	save_shot.call("res://screenshot_riacho_floresta.png")
	
	# 2. Visão Rotacionada 45°
	if pivot:
		pivot.rotate_y(deg_to_rad(45.0))
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_riacho_floresta_rotacionado.png")
	
	# Restaura rotação e posição
	if pivot:
		pivot.rotation = initial_rot
		pivot.global_position = initial_pos
	if cam:
		cam.size = initial_size
		
	# 3. Close-up Riacho de Igarapé e Margem de Terra Preta (X=0.0, Z=0.2, size=4.2)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 0.4, 0.2)
		cam.size = 4.2
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_riacho_aguas.png")
	
	# 4. Close-up Paredão de Terra e Rocha Saliente (X=0.6, Z=-1.8, size=4.0)
	if pivot and cam:
		pivot.global_position = Vector3(0.6, 1.2, -1.8)
		cam.size = 4.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_riacho_rocha_paredao.png")
	
	print("Todas as capturas do riacho concluidas com sucesso!")
	quit()

