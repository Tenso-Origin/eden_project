using System;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 4: Autômato Celular de Crescimento Vegetal, Consumo de Umidade e Biomassa.
/// Opera diretamente sobre a estrutura SoA do Chunk com zero alocação de heap.
/// Modela a ecologia vegetal amazônica: Floresta de Terra Firme, Várzea com macrófitas C4,
/// Arroz Silvestre (Oryza glumaepatula), ciclagem ultrarrápida de serapilheira e pedogênese de Terra Preta.
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
    /// - Ciclagem Acelerada de Serapilheira e Carcaças (Geração de Terra Preta Fértil)
    /// - Transpiração Foliar e Consumo Hídrico
    /// </summary>
    public static void StepFlora(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        for (int i = 0; i < Chunk.CellCount; i++)
        {
            ushort matId = chunk.MaterialId[i];
            ref readonly var mat = ref catalog[matId];

            // Substratos rochosos puros em alta altitude impedem crescimento de flora
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

                // Pulso de nutrientes de águas brancas/barrentas: sedimentos em suspensão enriquecem várzea e solos hidromórficos
                float suspendedSediment = chunk.SuspendedSediment[i];
                float whiteWaterNutrientBoost = 1.0f + MathF.Min(1.5f, suspendedSediment * 0.5f);

                // Taxa de crescimento base: Várzea C4 e Macrófitas aquáticas acumulam biomassa muito mais rápido que Terra Firme
                bool isVarzeaOrHydromorphic = (chunk.Elevation[i] < 15.0f) || (waterDepth > 0.01f && waterDepth <= 0.45f);
                float baseGrowthRate = isVarzeaOrHydromorphic ? (0.95f * whiteWaterNutrientBoost) : 0.48f;
                float baseGrowth = tempEff * MathF.Pow(moisture, 0.8f) * baseGrowthRate * dt;

                // Ciclagem acelerada de detritos orgânicos amazônicos (Serapilheira / Folhiço e Carcaças):
                // A alta temperatura e umidade catalisam decomposição microbiana/fúngica acelerada
                float detritus = chunk.OrganicDetritus[i];
                float fertilityBoost = 1.0f;

                // Queda contínua de serapilheira (litterfall) pela biomassa arbórea madura
                if (currentBiomass > 25.0f)
                {
                    float litterfall = currentBiomass * 0.004f * dt;
                    detritus += litterfall;
                }

                if (detritus > 0f)
                {
                    // Decomposição ultrarrápida amazônica proporcional à temperatura e umidade
                    float decompRate = (0.22f + (moisture * 0.18f)) * tempEff;
                    float decomp = detritus * decompRate * dt;
                    fertilityBoost += MathF.Min(2.5f, decomp * 1.4f);
                    detritus = MathF.Max(0f, detritus - decomp);
                    chunk.OrganicDetritus[i] = detritus;

                    // Pedogênese de Terra Preta Arqueológica/Antrópica:
                    // Decomposição densa sobre substratos minerais/arenosos (Sand ou Stone de baixa cota)
                    // converte mineral estéril em Terra Preta fértil (IdSoil)
                    if ((matId == MaterialCatalog.IdSand || matId == MaterialCatalog.IdStone) && detritus >= 3.0f)
                    {
                        chunk.NextMaterialId[i] = MaterialCatalog.IdSoil;
                        chunk.MaterialId[i] = MaterialCatalog.IdSoil;
                        matId = MaterialCatalog.IdSoil;
                    }
                }

                float growth = baseGrowth * fertilityBoost;

                // Capacidade de suporte logística: dM/dt = r * M * (1 - M / K)
                // Várzea com macrófitas atinge 65 kg/m²; floresta densa de terra firme atinge MaxBiomass (100)
                float targetMax = isVarzeaOrHydromorphic ? 65.0f : MaxBiomass;
                float availableCapacity = MathF.Max(0.15f, 1.0f - (currentBiomass / targetMax));
                float actualGrowth = growth * availableCapacity;

                chunk.Biomass[i] = Math.Clamp(currentBiomass + actualGrowth, 0f, targetMax);

                // Dinâmica de Grãos Silvestres e Frutos da Várzea (Oryza glumaepatula) e Macrófitas:
                // Exige solo hidromórfico raso (moisture > 0.30f), lâmina d'água rasa (<= 0.35m),
                // temperatura tropical [18°C .. 38°C] e suporte foliar (currentBiomass >= 10.0f).
                // A fertilidade sazonal de águas brancas/barrentas impulsiona a produção de sementes e frutos.
                if (moisture > 0.30f && waterDepth <= 0.35f && currentBiomass >= 10.0f && temp >= 18f && temp <= 38f)
                {
                    float currentGrains = chunk.Grains[i];
                    const float maxGrainCapacity = 80.0f; // Até 80 kg/m² nas touceiras maduras de várzea
                    float grainMaturityFactor = MathF.Min(1.0f, currentBiomass / 30.0f);
                    float grainGrowth = 0.08f * dt * moisture * tempEff * grainMaturityFactor * whiteWaterNutrientBoost * (1.0f - currentGrains / maxGrainCapacity);
                    chunk.Grains[i] = Math.Clamp(currentGrains + MathF.Max(0f, grainGrowth), 0f, maxGrainCapacity);
                }
                else if (waterDepth > 0.70f || moisture < 0.15f)
                {
                    // Desprendimento / degradação sob inundação profunda (anoxia) ou seca extrema
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
