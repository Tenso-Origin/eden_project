"""
Script para download completo dos módulos complementares do Hunyuan3D-2:
1. hunyuan3d-delight-v2-0 (De-lighting e remoção de sombras para texturização)
2. hunyuan3d-paint-v2-0-turbo (Pintura e geração de textura PBR multi-view)
3. hunyuan3d-dit-v2-0-turbo (Versão Turbo de geometria)
4. hunyuan3d-vae-v2-0 (Decodificador VAE)

Otimizado com `local_dir` direto no cache do hy3dgen, evitando qualquer dependência de symlinks no Windows.
"""

import os
import sys
from huggingface_hub import snapshot_download

REPO_ID = "tencent/Hunyuan3D-2"

# Diretório oficial de cache local do hy3dgen
DEST_DIR = os.path.expanduser("~/.cache/hy3dgen/tencent/Hunyuan3D-2")

# Padrões selecionados para download inteligente (evita arquivos .ckpt e .bin redundantes)
ALLOW_PATTERNS = [
    # Módulo de De-lighting (texturização)
    "hunyuan3d-delight-v2-0/*",
    # Módulo de Pintura Turbo (texturização rápida)
    "hunyuan3d-paint-v2-0-turbo/*.json",
    "hunyuan3d-paint-v2-0-turbo/*.txt",
    "hunyuan3d-paint-v2-0-turbo/*.py",
    "hunyuan3d-paint-v2-0-turbo/**/*.json",
    "hunyuan3d-paint-v2-0-turbo/**/*.txt",
    "hunyuan3d-paint-v2-0-turbo/**/*.safetensors",
    # Módulo DiT Turbo (geometria ultra rápida)
    "hunyuan3d-dit-v2-0-turbo/*.yaml",
    "hunyuan3d-dit-v2-0-turbo/*.safetensors",
    # Módulo VAE
    "hunyuan3d-vae-v2-0/*.yaml",
    "hunyuan3d-vae-v2-0/*.safetensors",
]

IGNORE_PATTERNS = [
    "*.ckpt",
    "*.bin",
    "assets/*",
    "hunyuan3d-paint-v2-0/*", # Mantém a versão turbo que é mais rápida e consome menos VRAM
    "hunyuan3d-dit-v2-0-fast/*"
]

def main():
    print("=" * 65)
    print("  DOWNLOAD COMPLETO DOS MÓDULOS HUNYUAN3D-2 (TEXTURA & TURBO)")
    print("=" * 65)
    print(f"Repositório : {REPO_ID}")
    print(f"Destino     : {DEST_DIR}")
    print("Módulos a baixar:")
    print(" -> hunyuan3d-delight-v2-0 (Remoção de sombras e iluminação)")
    print(" -> hunyuan3d-paint-v2-0-turbo (Gerador de texturas PBR multi-view)")
    print(" -> hunyuan3d-dit-v2-0-turbo (Geometria 3D Turbo)")
    print(" -> hunyuan3d-vae-v2-0 (Decodificador VAE)")
    print("=" * 65)
    print("Iniciando download direto (sem symlinks)... Aguarde.\n")

    os.makedirs(DEST_DIR, exist_ok=True)

    try:
        download_path = snapshot_download(
            repo_id=REPO_ID,
            allow_patterns=ALLOW_PATTERNS,
            ignore_patterns=IGNORE_PATTERNS,
            local_dir=DEST_DIR,
            max_workers=4
        )
        print("\n" + "=" * 65)
        print("  DOWNLOAD CONCLUÍDO COM SUCESSO!")
        print(f"Todos os módulos prontos em: {download_path}")
        print("=" * 65)
        
    except Exception as e:
        print(f"\n[ERRO DURANTE O DOWNLOAD]: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
