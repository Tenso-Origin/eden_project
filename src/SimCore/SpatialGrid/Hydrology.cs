using System;
using System.Runtime.CompilerServices;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2: Hidrologia Avançada - Escoamento Gravitacional, Infiltração e Erosão Fluvial do Solo.
/// A água líquida superficial escorre orientada pela carga hidráulica (Elevação + Lâmina d'água),
/// infiltra-se conforme a permeabilidade do solo e provoca desgaste erosivo nas calhas de escoamento.
/// </summary>
public static class Hydrology
{
    public const float GravityFlowRate = 0.50f;          // Coeficiente de escoamento livre
    public const float InfiltrationRate = 0.10f;         // Coeficiente de permeação no solo
    public const float ThermalEvaporationCoeff = 0.0005f;
    public const float SoilErosionRate = 0.0025f;        // Taxa de desgaste erosivo por fluxo de água

    /// <summary>
    /// Executa um passo hidrológico com infiltração, evaporação, escoamento e erosão topográfica.
    /// </summary>
    public static void StepHydrology(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        ReadOnlySpan<ushort> matIds = chunk.MaterialId;
        Span<float> elevations = chunk.Elevation;
        ReadOnlySpan<float> waters = chunk.SurfaceWater;
        ReadOnlySpan<float> moistures = chunk.Moisture;
        ReadOnlySpan<float> temps = chunk.Temperature;

        Span<float> nextWaters = chunk.NextSurfaceWater;
        Span<float> nextMoistures = chunk.NextMoisture;

        // Inicializa o buffer com os valores atuais para aplicar deltas conservativos
        waters.CopyTo(nextWaters);
        moistures.CopyTo(nextMoistures);

        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);
                float curWater = waters[idx];
                float curElev = elevations[idx];
                float curHead = curElev + curWater; // Carga hidráulica total
                ushort matId = matIds[idx];
                ref readonly var mat = ref catalog[matId];

                // 1. Infiltração da água superficial no solo baseada na permeabilidade
                if (curWater > 0f && mat.Permeability > 0f)
                {
                    float availMoistureCapacity = MathF.Max(0f, 1.0f - nextMoistures[idx]);
                    float infiltAmount = MathF.Min(curWater, mat.Permeability * InfiltrationRate * dt);
                    infiltAmount = MathF.Min(infiltAmount, availMoistureCapacity);

                    nextWaters[idx] -= infiltAmount;
                    nextMoistures[idx] += infiltAmount;
                }

                // 2. Evaporação termicamente induzida
                float temp = temps[idx];
                if (temp > 0f)
                {
                    float evapo = temp * ThermalEvaporationCoeff * dt;
                    if (nextWaters[idx] > 0f)
                    {
                        nextWaters[idx] = MathF.Max(0f, nextWaters[idx] - evapo);
                    }
                    else if (nextMoistures[idx] > 0f)
                    {
                        nextMoistures[idx] = MathF.Max(0f, nextMoistures[idx] - (evapo * 0.5f));
                    }
                }

                // 3. Escoamento Gravitacional para regiões mais baixas e EROSÃO FLUVIAL
                if (curWater > 0.001f)
                {
                    int lowestNeighborIdx = -1;
                    float lowestNeighborHead = curHead;

                    CheckNeighbor(x - 1, y, curHead, elevations, waters, ref lowestNeighborHead, ref lowestNeighborIdx);
                    CheckNeighbor(x + 1, y, curHead, elevations, waters, ref lowestNeighborHead, ref lowestNeighborIdx);
                    CheckNeighbor(x, y - 1, curHead, elevations, waters, ref lowestNeighborHead, ref lowestNeighborIdx);
                    CheckNeighbor(x, y + 1, curHead, elevations, waters, ref lowestNeighborHead, ref lowestNeighborIdx);

                    if (lowestNeighborIdx >= 0)
                    {
                        float headDiff = curHead - lowestNeighborHead;
                        // Fluxo máximo transferível limitado a 50% da diferença de nível para estabilidade
                        float maxFlow = headDiff * 0.5f;
                        float flow = MathF.Min(curWater, maxFlow) * GravityFlowRate * dt;

                        nextWaters[idx] -= flow;
                        nextWaters[lowestNeighborIdx] += flow;

                        // EROSÃO: Água corrente desgasta a elevação (calibrada para no máximo 1m por dia)
                        if (flow > 0.05f)
                        {
                            float erodibility = Math.Clamp(1.0f - (mat.Hardness / 10.0f), 0.1f, 1.0f);
                            // 1 dia = 24h de simulação. Limite diário estrito de 1.0m/dia
                            float maxErosionStep = (1.0f / 24.0f) * dt;
                            float calculatedErosion = flow * headDiff * SoilErosionRate * erodibility * dt;
                            float erosionAmount = MathF.Min(maxErosionStep, calculatedErosion);

                            elevations[idx] -= erosionAmount;

                            // Deposição sedimentar parcial na depressão receptora
                            elevations[lowestNeighborIdx] += erosionAmount * 0.4f;
                        }
                    }
                }
            }
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static void CheckNeighbor(
        int nx, int ny, float currentHead,
        ReadOnlySpan<float> elevations,
        ReadOnlySpan<float> waters,
        ref float lowestHead,
        ref int lowestIdx)
    {
        if (nx < 0 || nx >= Chunk.Width || ny < 0 || ny >= Chunk.Height) return;

        int nIdx = Chunk.GetIndex(nx, ny);
        float neighborHead = elevations[nIdx] + waters[nIdx];

        if (neighborHead < lowestHead)
        {
            lowestHead = neighborHead;
            lowestIdx = nIdx;
        }
    }
}
