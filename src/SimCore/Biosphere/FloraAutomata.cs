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
    public const float OptimalGrowthTemp = 28.5f; // Ponto ótimo fotossintético da Amazônia (26°C a 31°C)
    public const float GrowthTempWindow = 11.0f;  // Janela fotossintética ativa [17.5°C .. 39.5°C]
    public const float MoistureConsumptionRate = 0.04f;

    /// <summary>
    /// Passo temporal de vegetação amazônica:
    /// - Gramíneas e Macrófitas de Várzea (Echinochloa / Paspalum / Oryza glumaepatula)
    /// - Floresta Tropical Densa de Terra Firme
    /// - Ciclagem de Nutrientes Orgânicos e Transpiração Foliar
    /// </summary>
    public static void StepFlora(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            ushort matId = chunk.MaterialId[i];
            ref readonly var mat = ref catalog[matId];

            // Substratos minerais rochosos puros impedem crescimento de flora
            if (matId == MaterialCatalog.IdStone && chunk.Elevation[i] > 50f) continue;

            float temp = chunk.Temperature[i];
            float moisture = chunk.Moisture[i];
            float currentBiomass = chunk.Biomass[i];
            float waterDepth = chunk.SurfaceWater[i];

            // Condições fisiológicas amazônicas: [12°C .. 42°C] e umidade acima do ponto de murcha permanente (> 0.08)
            if (temp >= 12.0f && temp <= 42.0f && moisture > 0.08f)
            {
                // Curva fotossintética assimétrica (declínio acentuado acima de 34°C por estresse térmico/VPD)
                float tempEff;
                if (temp <= OptimalGrowthTemp)
                {
                    tempEff = 1.0f - MathF.Pow((OptimalGrowthTemp - temp) / GrowthTempWindow, 1.6f);
                }
                else
                {
                    tempEff = 1.0f - MathF.Pow((temp - OptimalGrowthTemp) / (42.0f - OptimalGrowthTemp), 1.8f);
                }
                tempEff = Math.Clamp(tempEff, 0.08f, 1.0f);

                // Solo mais fértil e úmido acelera o crescimento (calibrado com NPP real amazônico)
                float baseGrowthRate = (chunk.Elevation[i] < 15.0f) ? 0.95f : 0.48f; // Várzea C4 (~28-32 dias) vs Floresta de Terra Firme (~75-90 dias)
                float baseGrowth = tempEff * MathF.Pow(moisture, 0.8f) * baseGrowthRate * dt;

                // Ciclagem de Nutrientes (Decomposição de Carcaças e Matéria Orgânica)
                float detritus = chunk.OrganicDetritus[i];
                float fertilityBoost = 1.0f;
                if (detritus > 0f)
                {
                    float decomp = detritus * 0.15f * dt;
                    fertilityBoost += MathF.Min(2.0f, decomp * 0.8f);
                    chunk.OrganicDetritus[i] = MathF.Max(0f, detritus - decomp);

                    if (matId == MaterialCatalog.IdStone && detritus > 5.0f)
                    {
                        chunk.NextMaterialId[i] = MaterialCatalog.IdSoil;
                    }
                }

                float growth = baseGrowth * fertilityBoost;

                // Capacidade de suporte logística: dM/dt = r * M * (1 - M / K)
                float targetMax = (chunk.Elevation[i] < 15.0f) ? 55.0f : MaxBiomass;
                float availableCapacity = MathF.Max(0.15f, 1.0f - (currentBiomass / targetMax));
                float actualGrowth = growth * availableCapacity;

                chunk.Biomass[i] = Math.Clamp(currentBiomass + actualGrowth, 0f, targetMax);

                // Dinâmica de Grãos Silvestres de Várzea (Oryza glumaepatula)
                // Exige solo hidromórfico (moisture > 0.35f), água rasa (<= 0.25m) e porte foliar mínimo (currentBiomass >= 12.0f)
                if (moisture > 0.35f && waterDepth <= 0.25f && currentBiomass >= 12.0f && temp >= 18f && temp <= 38f)
                {
                    float currentGrains = chunk.Grains[i];
                    const float maxGrainCapacity = 80.0f; // Até 80 kg/m² nas touceiras maduras de várzea
                    float grainMaturityFactor = MathF.Min(1.0f, currentBiomass / 35.0f);
                    float grainGrowth = 0.05f * dt * moisture * tempEff * grainMaturityFactor * (1.0f - currentGrains / maxGrainCapacity);
                    chunk.Grains[i] = Math.Clamp(currentGrains + MathF.Max(0f, grainGrowth), 0f, maxGrainCapacity);
                }
                else if (waterDepth > 0.60f || moisture < 0.20f)
                {
                    if (chunk.Grains[i] > 0f) chunk.Grains[i] = MathF.Max(0f, chunk.Grains[i] - 0.25f * dt);
                }

                // A vegetação transpira e absorve umidade do solo
                float moistureUsed = actualGrowth * MoistureConsumptionRate;
                chunk.Moisture[i] = MathF.Max(0f, moisture - moistureUsed);
            }
            else if (temp < 5.0f || temp > 43.0f || moisture < 0.05f)
            {
                // Morte de vegetação por choque térmico ou dessecação severa
                float decayRate = (temp < 5.0f ? 1.8f : (temp > 43.0f ? 2.5f : 0.8f)) * dt;
                chunk.Biomass[i] = MathF.Max(0f, currentBiomass - decayRate);
                if (chunk.Grains[i] > 0f) chunk.Grains[i] = MathF.Max(0f, chunk.Grains[i] - decayRate * 0.5f);
            }
        }
    }
}
