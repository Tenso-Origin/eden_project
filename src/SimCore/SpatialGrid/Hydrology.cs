using System;
using System.Runtime.CompilerServices;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2: Hidrologia Local - Escoamento Superficial Gravitacional, Infiltração e Evaporação.
/// Utiliza a carga hidráulica total (Elevação + Lâmina d'água) para direcionar o fluxo hídrico
/// sem turbulências instáveis ou alocações no heap.
/// </summary>
public static class Hydrology
{
    public const float GravityFlowRate = 0.50f;      // Coeficiente de escoamento livre
    public const float InfiltrationRate = 0.10f;     // Coeficiente de permeação no solo
    public const float ThermalEvaporationCoeff = 0.0005f;

    /// <summary>
    /// Executa um passo hidrológico sobre o Chunk.
    /// </summary>
    public static void StepHydrology(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        ReadOnlySpan<ushort> matIds = chunk.MaterialId;
        ReadOnlySpan<float> elevations = chunk.Elevation;
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

                // 1. Infiltração da água superficial no substrato (solo)
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

                // 3. Escoamento Superficial (Downhill Flow)
                // Encontra o vizinho com menor carga hidráulica
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
                        // O fluxo máximo transferível é a metade da diferença de nível para evitar oscilações numéricas
                        float maxFlow = headDiff * 0.5f;
                        float flow = MathF.Min(curWater, maxFlow) * GravityFlowRate * dt;

                        nextWaters[idx] -= flow;
                        nextWaters[lowestNeighborIdx] += flow;
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
