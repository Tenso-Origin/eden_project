using System;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2: Difusão de calor (Lei de Fourier) e transições de fase de matéria (Fusão / Ebulição).
/// Opera diretamente sobre os buffers do Chunk lendo do estado atual e escrevendo no próximo.
/// </summary>
public static class Thermodynamics
{
    public const float AmbientDiffusionRate = 0.05f;

    /// <summary>
    /// Passo de simulação térmica sobre o Chunk.
    /// </summary>
    public static void StepDiffusion(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);
                ushort matId = chunk.MaterialId[idx];
                ref readonly var mat = ref catalog[matId];

                float currentTemp = chunk.Temperature[idx];

                // Difusão laplaciana simples com 4 vizinhos imediatos
                float neighborTempSum = 0f;
                int neighborCount = 0;

                if (x > 0) { neighborTempSum += chunk.Temperature[Chunk.GetIndex(x - 1, y)]; neighborCount++; }
                if (x < Chunk.Width - 1) { neighborTempSum += chunk.Temperature[Chunk.GetIndex(x + 1, y)]; neighborCount++; }
                if (y > 0) { neighborTempSum += chunk.Temperature[Chunk.GetIndex(x, y - 1)]; neighborCount++; }
                if (y < Chunk.Height - 1) { neighborTempSum += chunk.Temperature[Chunk.GetIndex(x, y + 1)]; neighborCount++; }

                float avgNeighbor = neighborCount > 0 ? (neighborTempSum / neighborCount) : currentTemp;
                float diff = (avgNeighbor - currentTemp) * mat.ThermalConductivity * dt;

                float newTemp = currentTemp + diff;

                // Verificação de transição de fase
                if (mat.PhaseChangeTargetId != 0 && newTemp >= mat.BoilingPoint)
                {
                    chunk.MaterialId[idx] = mat.PhaseChangeTargetId;
                }

                chunk.NextTemperature[idx] = newTemp;
            }
        }
    }
}
