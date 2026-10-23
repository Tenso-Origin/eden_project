using System;
using SimCore.SpatialGrid;

namespace SimVisualizer;

/// <summary>
/// FASES 2 a 5: Visualizador Debug de Heatmaps (Temperatura, Umidade e Biomassa).
/// Gera buffers de pixels RGB para inspeção visual em tempo real.
/// </summary>
public static class HeatmapRenderer
{
    public static uint[] GenerateTemperaturePixels(Chunk chunk)
    {
        uint[] pixels = new uint[Chunk.CellCount];
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            float temp = chunk.Temperature[i];
            // Normaliza temperatura entre -20°C (Azul) e 60°C (Vermelho)
            float t = Math.Clamp((temp + 20f) / 80f, 0f, 1f);
            byte r = (byte)(t * 255);
            byte b = (byte)((1f - t) * 255);
            pixels[i] = 0xFF000000u | ((uint)r << 16) | (uint)b;
        }
        return pixels;
    }
}
