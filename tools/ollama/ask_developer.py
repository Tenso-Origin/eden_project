#!/usr/bin/env python3
"""
Utilitário Python para invocar o agente 'developer' (Qwen2.5-Coder-14B) no Ollama.
Suporta streaming de tokens e leitura de arquivos de especificação.
"""

import sys
import argparse
import urllib.request
import json

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL_NAME = "developer"

def call_developer(prompt: str, stream: bool = True):
    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": stream
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL, data=data, headers={"Content-Type": "application/json; charset=utf-8"})

    try:
        with urllib.request.urlopen(req) as resp:
            if stream:
                for line in resp:
                    if line:
                        chunk = json.loads(line.decode("utf-8"))
                        token = chunk.get("response", "")
                        print(token, end="", flush=True)
                        if chunk.get("done", False):
                            print()
            else:
                raw = resp.read().decode("utf-8")
                res = json.loads(raw)
                print(res.get("response", ""))
    except Exception as e:
        print(f"Erro ao conectar com Ollama ({OLLAMA_URL}): {e}", file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Invoca o agente developer no Ollama")
    parser.add_argument("prompt", nargs="?", default="", help="Prompt ou Pseudocódigo")
    parser.add_argument("-f", "--file", help="Caminho do arquivo com a especificação (.md / .txt)")
    parser.add_argument("--no-stream", action="store_true", help="Desativa streaming de tokens")

    args = parser.parse_args()
    prompt_content = ""

    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            prompt_content = f.read()
    elif args.prompt:
        prompt_content = args.prompt
    else:
        if not sys.stdin.isatty():
            prompt_content = sys.stdin.read()
        else:
            parser.print_help()
            sys.exit(1)

    call_developer(prompt_content, stream=not args.no_stream)

