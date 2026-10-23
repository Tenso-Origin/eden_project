using System;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 4: Autômato Celular de Crescimento Vegetal, Consumo de Umidade e Biomassa.
/// Opera diretamente sobre a estrutura SoA do Chunk com zero alocação de heap.
/// </summary>
public static class FloraAutomata
{
    public const float MaxBiomass = 100.0f;
    public const float OptimalGrowthTemp = 24.0f;
    public const float GrowthTempWindow = 14.0f; // [10°C .. 38°C]
    public const float MoistureConsumptionRate = 0.05f;

    /// <summary>
    /// Passo temporal de vegetação:
    /// - Absorve umidade do solo e radiação solar para sintetizar biomassa.
    /// - Degrada por geada (< 0°C), calor extremo (> 45°C) ou seca severa (< 0.05 umidade).
    /// </summary>
    public static void StepFlora(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            ushort matId = chunk.MaterialId[i];
            ref readonly var mat = ref catalog[matId];

            // Substratos minerais rochosos puros (ex: rocha maciça) impedem crescimento de flora
            if (matId == MaterialCatalog.IdStone && chunk.Elevation[i] > 50f) continue;

            float temp = chunk.Temperature[i];
            float moisture = chunk.Moisture[i];
            float currentBiomass = chunk.Biomass[i];

            // Condições ótimas de germinação e crescimento
            if (temp >= 10.0f && temp <= 40.0f && moisture > 0.08f)
            {
                // Eficiência fotossintética/térmica (máxima em 24°C)
                float tempFactor = 1.0f - MathF.Abs(temp - OptimalGrowthTemp) / GrowthTempWindow;
                tempFactor = Math.Clamp(tempFactor, 0.1f, 1.0f);

                // Solo mais fértil e úmido acelera o crescimento
                float growth = tempFactor * moisture * 3.5f * dt;

                // Capacidade de suporte logística: dM/dt = r * M * (1 - M / K)
                float availableCapacity = MathF.Max(0.5f, 1.0f - (currentBiomass / MaxBiomass));
                float actualGrowth = growth * availableCapacity;

                chunk.Biomass[i] = Math.Clamp(currentBiomass + actualGrowth, 0f, MaxBiomass);

                // A vegetação transpira e absorve umidade do solo
                float moistureUsed = actualGrowth * MoistureConsumptionRate;
                chunk.Moisture[i] = MathF.Max(0f, moisture - moistureUsed);
            }
            else if (temp < 0.0f || temp > 45.0f || moisture < 0.03f)
            {
                // Morte de vegetação por choque térmico ou dessecação severa
                float decayRate = (temp < 0.0f ? 2.0f : 1.2f) * dt;
                chunk.Biomass[i] = MathF.Max(0f, currentBiomass - decayRate);
            }
        }
    }
}
