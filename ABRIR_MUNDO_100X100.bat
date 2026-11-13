@echo off
echo ==============================================================
echo    EDEN PROJECT - MUNDO PROCEDURAL 100x100 CHUNKS (1.6 km)
echo    Streaming Dinamico de Biosfera Amazonica HD Pixel Art 3D
echo ==============================================================
echo Controles:
echo   - W, A, S, D : Navegar / Voar pelo mapa
echo   - SHIFT + W/A/S/D : Voo Turbo (4x velocidade)
echo   - Q, E : Girar camera 360 graus
echo   - M : Alternar Minimapa e Radar (Canto / Expandido / Oculto)
echo   - Roda do Mouse : Zoom in / Zoom out (5m a 40m)
echo   - Espaco / 0 : Resetar camera no centro
echo ==============================================================
start "" "E:\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0cenarios_hd_pixelart_3d" "res://cena_mundo_100x100_biosfera.tscn"

