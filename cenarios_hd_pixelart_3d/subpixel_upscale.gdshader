shader_type canvas_item;

// Shader de Upscale e Deslize Sub-pixel (David Holland Architecture)
// Aplique em um ShaderMaterial no SubViewportContainer.
// Compensa o erro fracionário de texel da Camera3D deslocando a leitura da textura na viewport 2D.

uniform vec2 cam_offset = vec2(0.0);

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel_size = 1.0 / tex_size;
	
	// Compensa o erro da câmera deslocando a leitura da UV (Y invertido entre View 3D e UV 2D)
	vec2 offset_uv = vec2(cam_offset.x, -cam_offset.y) * pixel_size;
	
	// Mapeia ignorando a borda de 1px de segurança nas extremidades da SubViewport
	vec2 cropped_uv = (UV * (tex_size - 2.0) + 1.0) * pixel_size;
	
	COLOR = texture(TEXTURE, cropped_uv + offset_uv);
}

