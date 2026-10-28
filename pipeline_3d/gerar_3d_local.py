import gc
import os
import sys
import torch
from PIL import Image
from rembg import remove

# Adiciona o diretório do Hunyuan3D-2 ao path se necessário
current_dir = os.path.dirname(os.path.abspath(__file__))
hunyuan_path = os.path.join(current_dir, "Hunyuan3D-2")
if hunyuan_path not in sys.path:
    sys.path.insert(0, hunyuan_path)

# Garantir uso eficiente de VRAM em placas de 8GB
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

def limpar_vram():
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

def preparar_imagem(caminho_entrada, caminho_saida, recortar_rodape=False):
    print("[1/4] Preparando imagem e removendo fundo/marca d'água...")
    img = Image.open(caminho_entrada).convert("RGBA")
    
    # Recorta 8% inferiores caso tenha a barra do Dreamstime se solicitado
    if recortar_rodape:
        largura, altura = img.size
        img = img.crop((0, 0, largura, int(altura * 0.92)))
    
    # Remove o fundo mantendo apenas o objeto
    img_sem_fundo = remove(img)
    img_sem_fundo.save(caminho_saida)
    limpar_vram()
    return caminho_saida

def gerar_modelo_3d(imagem_limpa, saida_glb, gerar_textura=False):
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    # ESTÁGIO 1: Geometria 3D (Usa ~5.5 GB de VRAM em fp16)
    print("[2/4] Carregando Hunyuan3D-DiT (Gerador de Geometria Flow Matching)...")
    shape_pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
        "tencent/Hunyuan3D-2",
        subfolder="hunyuan3d-dit-v2-0",
        torch_dtype=torch.float16,
        use_safetensors=True
    )
    shape_pipe.to("cuda")

    print(" -> Esculpindo malha 3D (aguarde ~45-90s)...")
    mesh = shape_pipe(
        image=imagem_limpa,
        num_inference_steps=35,
        octree_resolution=256, # Equilíbrio ideal para 8GB VRAM e estilo low-poly/voxel
        guidance_scale=5.5
    )[0]

    # Descarregar modelo de geometria da VRAM antes de pintar!
    del shape_pipe
    limpar_vram()

    # ESTÁGIO 2: Textura PBR
    if gerar_textura:
        try:
            from hy3dgen.texgen import Hunyuan3DPaintPipeline
            print("[3/4] Carregando Hunyuan3D-Paint (Gerador de Textura)...")
            paint_pipe = Hunyuan3DPaintPipeline.from_pretrained(
                "tencent/Hunyuan3D-2",
                subfolder="hunyuan3d-paint-v2-0"
            )
            
            print(" -> Projetando textura 3D (aguarde ~60-120s)...")
            mesh_texturizada = paint_pipe(mesh, image=imagem_limpa)

            print(f"[4/4] Exportando arquivo final para: {saida_glb}")
            mesh_texturizada.export(saida_glb)
            del paint_pipe
        except Exception as e:
            print(f"[Aviso] Estágio de textura reportou: {e}. Exportando malha geométrica base para: {saida_glb}")
            mesh.export(saida_glb)
    else:
        print(f"[3/4] Pulando pintura neural (modo geometria ativa)...")
        print(f"[4/4] Exportando arquivo GLB para: {saida_glb}")
        mesh.export(saida_glb)
    
    limpar_vram()
    print("Concluído com sucesso!")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Geração 3D local com Hunyuan3D-2")
    parser.add_argument("--input", default="bola_praia.png", help="Caminho da imagem de entrada")
    parser.add_argument("--output", default="guerreiro_3d.glb", help="Caminho do arquivo GLB de saída")
    parser.add_argument("--crop-bottom", action="store_true", default=False, help="Recorta 8% inferiores para marcas d'água")
    parser.add_argument("--textura", action="store_true", default=False, help="Executa o estágio 2 de pintura de textura neural")
    args = parser.parse_args()

    img_original = args.input if os.path.exists(args.input) else ("guerreiro_input.jpg" if os.path.exists("guerreiro_input.jpg") else args.input)
    img_processada = os.path.splitext(img_original)[0] + "_limpo.png"
    modelo_final = args.output
    
    preparar_imagem(img_original, img_processada, recortar_rodape=args.crop_bottom)
    gerar_modelo_3d(img_processada, modelo_final, gerar_textura=args.textura)
