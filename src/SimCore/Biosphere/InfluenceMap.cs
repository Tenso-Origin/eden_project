using System;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 5: Mapas de Influência Contínuos (Food, Danger, Water).
/// Permite aos agentes animais encontrar alimento/água e evitar predadores navegando o gradiente
/// local das 8 células vizinhas sem necessitar de A* (reduzindo 95% do custo de CPU).
/// </summary>
public sealed class InfluenceMap
{
    public readonly float[] FoodGradient = new float[Chunk.CellCount];
    public readonly float[] DangerGradient = new float[Chunk.CellCount];
    public readonly float[] WaterGradient = new float[Chunk.CellCount];

    private readonly float[] _blurBuffer = new float[Chunk.CellCount];

    /// <summary>
    /// Limpa os mapas antes de recalcular o tick de gradientes.
    /// </summary>
    public void Clear()
    {
        Array.Clear(FoodGradient, 0, Chunk.CellCount);
        Array.Clear(DangerGradient, 0, Chunk.CellCount);
        Array.Clear(WaterGradient, 0, Chunk.CellCount);
    }

    /// <summary>
    /// Registra uma fonte pontual de perigo (ex: predador carnívoro ou fogo).
    /// </summary>
    public void EmitDanger(int x, int y, float intensity)
    {
        if (x >= 0 && x < Chunk.Width && y >= 0 && y < Chunk.Height)
        {
            int idx = Chunk.GetIndex(x, y);
            DangerGradient[idx] = MathF.Max(DangerGradient[idx], intensity);
        }
    }

    /// <summary>
    /// Atualiza todos os mapas de gradiente a partir do Chunk e aplica Box Blur 3x3
    /// para gerar o "cheiro" difuso contínuo.
    /// </summary>
    public void UpdateFromChunk(Chunk chunk)
    {
        // 1. Mapa de Comida: herda biomassa vegetal
        Array.Copy(chunk.Biomass, FoodGradient, Chunk.CellCount);
        ApplyBoxBlur3x3(FoodGradient, _blurBuffer);

        // 2. Mapa de Água: herda lâmina superficial + umidade
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            WaterGradient[i] = chunk.SurfaceWater[i] + (chunk.Moisture[i] * 10.0f);
        }
        ApplyBoxBlur3x3(WaterGradient, _blurBuffer);

        // 3. Mapa de Perigo: difunde os pontos de perigo emitidos
        ApplyBoxBlur3x3(DangerGradient, _blurBuffer);
    }

    public static void ApplyBoxBlur3x3(float[] src, float[] temp)
    {
        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                float sum = 0f;
                int count = 0;

                for (int dy = -1; dy <= 1; dy++)
                {
                    int ny = y + dy;
                    if (ny < 0 || ny >= Chunk.Height) continue;

                    for (int dx = -1; dx <= 1; dx++)
                    {
                        int nx = x + dx;
                        if (nx < 0 || nx >= Chunk.Width) continue;

                        sum += src[Chunk.GetIndex(nx, ny)];
                        count++;
                    }
                }

                temp[Chunk.GetIndex(x, y)] = sum / count;
            }
        }

        Array.Copy(temp, src, Chunk.CellCount);
    }
}
