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
    /// Registra uma fonte pontual de perigo com intensidade graduada (ex: predador carnívoro, harpia ou fogo).
    /// Registra o pico de intensidade do gradiente de perigo por célula de forma determinística e sem alocações.
    /// </summary>
    public void EmitGradedDanger(int x, int y, float intensity)
    {
        if ((uint)x < (uint)Chunk.Width && (uint)y < (uint)Chunk.Height)
        {
            int idx = Chunk.GetIndex(x, y);
            if (intensity > DangerGradient[idx])
            {
                DangerGradient[idx] = intensity;
            }
        }
    }

    /// <summary>
    /// Registra uma fonte de perigo com dispersão radial graduada sem qualquer alocação na heap.
    /// </summary>
    public void EmitGradedDanger(int x, int y, float intensity, int radius)
    {
        if (radius <= 0)
        {
            EmitGradedDanger(x, y, intensity);
            return;
        }

        for (int dy = -radius; dy <= radius; dy++)
        {
            int ny = y + dy;
            if ((uint)ny >= (uint)Chunk.Height) continue;

            for (int dx = -radius; dx <= radius; dx++)
            {
                int nx = x + dx;
                if ((uint)nx >= (uint)Chunk.Width) continue;

                float distSq = dx * dx + dy * dy;
                float rSq = radius * radius;
                if (distSq <= rSq)
                {
                    float factor = 1.0f - (MathF.Sqrt(distSq) / (radius + 0.001f));
                    float cellIntensity = intensity * MathF.Max(0f, factor);
                    int idx = Chunk.GetIndex(nx, ny);
                    if (cellIntensity > DangerGradient[idx])
                    {
                        DangerGradient[idx] = cellIntensity;
                    }
                }
            }
        }
    }

    /// <summary>
    /// Registra uma fonte pontual de perigo (mantido para compatibilidade total de chamada).
    /// </summary>
    public void EmitDanger(int x, int y, float intensity)
    {
        EmitGradedDanger(x, y, intensity);
    }

    /// <summary>
    /// Atualiza todos os mapas de gradiente a partir do Chunk e aplica Box Blur 3x3
    /// para gerar o "cheiro" difuso contínuo de alimento, água e perigo.
    /// </summary>
    public void UpdateFromChunk(Chunk chunk)
    {
        // 1. Mapa de Comida: herda biomassa vegetal e grãos maduros de várzea
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            FoodGradient[i] = chunk.Biomass[i] + (chunk.Grains[i] * 1.5f);
        }
        ApplyBoxBlur3x3(FoodGradient, _blurBuffer);

        // 2. Mapa de Água: herda lâmina superficial + umidade intersticial + corpos de lago
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            WaterGradient[i] = chunk.SurfaceWater[i] + (chunk.Moisture[i] * 10.0f) + chunk.LakeWater[i];
        }
        ApplyBoxBlur3x3(WaterGradient, _blurBuffer);

        // 3. Mapa de Perigo: difunde suavemente os pontos e gradientes de perigo emitidos
        ApplyBoxBlur3x3(DangerGradient, _blurBuffer);
    }

    /// <summary>
    /// Aplica Box Blur 3x3 com normalização local nas bordas, garantindo difusão contínua
    /// de gradientes sem gerar alocações no garbage collector.
    /// </summary>
    public static void ApplyBoxBlur3x3(float[] src, float[] temp)
    {
        for (int y = 0; y < Chunk.Height; y++)
        {
            int yMin = (y > 0) ? y - 1 : 0;
            int yMax = (y < Chunk.Height - 1) ? y + 1 : Chunk.Height - 1;

            for (int x = 0; x < Chunk.Width; x++)
            {
                int xMin = (x > 0) ? x - 1 : 0;
                int xMax = (x < Chunk.Width - 1) ? x + 1 : Chunk.Width - 1;

                float sum = 0f;
                int count = 0;

                for (int ny = yMin; ny <= yMax; ny++)
                {
                    int rowOffset = ny << 4;
                    for (int nx = xMin; nx <= xMax; nx++)
                    {
                        sum += src[rowOffset | nx];
                        count++;
                    }
                }

                temp[(y << 4) | x] = sum / count;
            }
        }

        Array.Copy(temp, src, Chunk.CellCount);
    }
}
