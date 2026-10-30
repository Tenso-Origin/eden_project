extends SceneTree

func _init():
	var root_scene = load("res://cena2.tscn").instantiate()
	root.add_child(root_scene)
	
	# Aguarda frames para inicialização e shaders
	for i in range(45):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	if svp:
		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://screenshot_cena2.png"
			img.save_png(save_path)
			print("Screenshot cena2 salva com sucesso em: ", save_path)
		else:
			print("Falha ao obter imagem da viewport de cena2")
			
	quit()

