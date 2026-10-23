using System;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 4: Crescimento vegetal, acúmulo de biomassa e reciclagem de solo.
/// </summary>
public static class FloraAutomata
{
    public const float MaxBiomass = 100f;

    /// <summary>
    /// Tick biológico da flora: consome umidade e calor ótimo (15°C a 30°C) para converter em biomassa.
    /// </summary>
    public static void StepFlora(Chunk chunk, float dt)
    {
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            float temp = chunk.Temperature[i];
            float moisture = chunk.Moisture[i];
            float currentBiomass = chunk.Biomass[i];

            // Faixa de temperatura viável para crescimento vegetal
            if (temp >= 10f && temp <= 38f && moisture > 0.1f)
            {
                float optimalFactor = 1.0f - MathF.Abs(temp - 24f) / 14f;
                float growth = optimalFactor * moisture * 2.5f * dt;
                chunk.Biomass[i] = MathF.Min(MaxBiomass, currentBiomass + growth);
            }
            else if (temp < 0f || moisture < 0.02f)
            {
                // Degradação e seca
                chunk.Biomass[i] = MathF.Max(0f, currentBiomass - (1.0f * dt));
            }
        }
    }
}
