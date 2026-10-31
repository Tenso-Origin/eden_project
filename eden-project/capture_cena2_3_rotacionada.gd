extends SceneTree

func _init():
	var root_scene = load("res://cena2_3.tscn").instantiate()
	root.add_child(root_scene)
	
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	if pivot:
		pivot.rotate_y(deg_to_rad(45.0))
		print("CameraPivot rotacionado em 45 graus para captura orbital.")
	
	# Aguarda frames para estabilização de física, vento e maré
	for i in range(45):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	if svp:
		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://screenshot_cena2_3_rotacionada.png"
			img.save_png(save_path)
			print("Screenshot cena2_3 rotacionada salva com sucesso em: ", save_path)
		else:
			print("Falha ao obter imagem da viewport rotacionada")
			
	quit()

