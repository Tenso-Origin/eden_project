using System;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 5: Mapas de Influência (Food & Danger Heatmaps).
/// Permite aos agentes animais encontrar alimento e fugir de predadores navegando gradientes
/// locais (8 vizinhos) sem rodar A* (95% de economia de CPU).
/// </summary>
public sealed class InfluenceMap
{
    public readonly float[] FoodGradient = new float[Chunk.CellCount];
    public readonly float[] DangerGradient = new float[Chunk.CellCount];
    private readonly float[] _blurBuffer = new float[Chunk.CellCount];

    /// <summary>
    /// Constrói o gradiente difuso de comida a partir da biomassa do Chunk usando Box Blur 3x3.
    /// </summary>
    public void UpdateFromBiomass(Chunk chunk)
    {
        // Copia a biomassa bruta
        Array.Copy(chunk.Biomass, FoodGradient, Chunk.CellCount);

        // Aplica filtro de desfoque 3x3 para criar o gradiente contínuo de atração
        ApplyBoxBlur3x3(FoodGradient, _blurBuffer);
    }

    private static void ApplyBoxBlur3x3(float[] src, float[] temp)
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
