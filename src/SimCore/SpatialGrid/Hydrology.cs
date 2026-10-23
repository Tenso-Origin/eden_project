using System;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2: Escoamento hídrico superficial, retenção/permeabilidade de solo e evaporação.
/// </summary>
public static class Hydrology
{
    public const float EvaporationFactor = 0.001f;

    /// <summary>
    /// Passo de simulação hidrológica sobre o Chunk.
    /// </summary>
    public static void StepHydrology(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            ushort matId = chunk.MaterialId[i];
            ref readonly var mat = ref catalog[matId];

            float moisture = chunk.Moisture[i];
            float temp = chunk.Temperature[i];

            // Evaporação acoplada à temperatura
            if (temp > 20f && moisture > 0f)
            {
                float evapoRate = (temp - 20f) * EvaporationFactor * dt;
                moisture = MathF.Max(0f, moisture - evapoRate);
            }

            // Permeabilidade e infiltração no substrato
            float retention = (1.0f - mat.Permeability) * 0.95f;
            moisture *= (1.0f - (1.0f - retention) * dt);

            chunk.NextMoisture[i] = moisture;
        }
    }
}
