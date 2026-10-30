extends SceneTree

func _init():
	var root_scene = load("res://pixel_art_scene.tscn").instantiate()
	root.add_child(root_scene)
	
	# Aguarda alguns frames para os shaders compilarem e a cena inicializar
	for i in range(45):
		await process_frame
		
	# Captura o SubViewport
	var svp = root_scene.get_node("SubViewportContainer/SubViewport") as SubViewport
	if svp:
		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://screenshot_validacao.png"
			img.save_png(save_path)
			print("Screenshot salva com sucesso em: ", save_path)
		else:
			print("Falha ao obter imagem da viewport")
			
	quit()

