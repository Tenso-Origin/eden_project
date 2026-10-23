using System;
using System.Runtime.CompilerServices;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2: Condução Térmica (Lei de Fourier) e Transições de Fase Bidirecionais.
/// Execução pura sobre arrays contíguos do Chunk sem alocação de memória (GC = 0).
/// </summary>
public static class Thermodynamics
{
    public const float AmbientAirTemp = 20.0f;
    public const float AmbientAirCoupling = 0.02f;

    /// <summary>
    /// Executa um passo de difusão de calor no Chunk.
    /// Lê exclusivamente de Chunk.Temperature e Chunk.MaterialId (ReadOnly)
    /// Escreve em Chunk.NextTemperature e Chunk.NextMaterialId.
    /// </summary>
    public static void StepDiffusion(
        Chunk chunk,
        ReadOnlySpan<MaterialDef> catalog,
        float dt,
        float ambientTemp = AmbientAirTemp)
    {
        ReadOnlySpan<ushort> matIds = chunk.MaterialId;
        ReadOnlySpan<float> temps = chunk.Temperature;
        Span<ushort> nextMatIds = chunk.NextMaterialId;
        Span<float> nextTemps = chunk.NextTemperature;

        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);
                ushort matId = matIds[idx];
                ref readonly var mat = ref catalog[matId];

                float currentTemp = temps[idx];
                float k1 = mat.ThermalConductivity;
                float thermalMass = MathF.Max(0.5f, mat.Density);

                float heatFluxSum = 0f;

                // Condução com os 4 vizinhos ortogonais (Von Neumann)
                if (x > 0)
                {
                    int nIdx = Chunk.GetIndex(x - 1, y);
                    heatFluxSum += ComputeConductionFlux(currentTemp, temps[nIdx], k1, catalog[matIds[nIdx]].ThermalConductivity);
                }
                if (x < Chunk.Width - 1)
                {
                    int nIdx = Chunk.GetIndex(x + 1, y);
                    heatFluxSum += ComputeConductionFlux(currentTemp, temps[nIdx], k1, catalog[matIds[nIdx]].ThermalConductivity);
                }
                if (y > 0)
                {
                    int nIdx = Chunk.GetIndex(x, y - 1);
                    heatFluxSum += ComputeConductionFlux(currentTemp, temps[nIdx], k1, catalog[matIds[nIdx]].ThermalConductivity);
                }
                if (y < Chunk.Height - 1)
                {
                    int nIdx = Chunk.GetIndex(x, y + 1);
                    heatFluxSum += ComputeConductionFlux(currentTemp, temps[nIdx], k1, catalog[matIds[nIdx]].ThermalConductivity);
                }

                // Troca térmica com a atmosfera ambiente (resfriamento/aquecimento convectivo de topo)
                // Gradiente altimétrico adiabático: -6.5°C por 1000m (-0.0065°C / m)
                float localAmbient = ambientTemp - (chunk.Elevation[idx] * 0.0065f);
                heatFluxSum += (localAmbient - currentTemp) * AmbientAirCoupling;

                // Atualização da temperatura resultante
                float deltaT = (heatFluxSum / thermalMass) * dt;
                float newTemp = currentTemp + deltaT;

                // Avaliação de Transições de Fase
                ushort newMatId = matId;

                // 1. Gelo <-> Água Líquida (0°C)
                if (matId == MaterialCatalog.IdIce && newTemp > 0.0f)
                {
                    newMatId = MaterialCatalog.IdWater;
                }
                else if (matId == MaterialCatalog.IdWater && newTemp <= 0.0f)
                {
                    newMatId = MaterialCatalog.IdIce;
                }
                // 2. Água Líquida <-> Vapor (100°C)
                else if (matId == MaterialCatalog.IdWater && newTemp >= 100.0f)
                {
                    newMatId = MaterialCatalog.IdSteam;
                }
                else if (matId == MaterialCatalog.IdSteam && newTemp < 100.0f)
                {
                    newMatId = MaterialCatalog.IdWater;
                }
                // 3. Regra Geral de Catálogo
                else if (mat.PhaseChangeTargetId != 0 && newTemp >= mat.BoilingPoint)
                {
                    newMatId = mat.PhaseChangeTargetId;
                }

                nextTemps[idx] = newTemp;
                nextMatIds[idx] = newMatId;
            }
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static float ComputeConductionFlux(float t1, float t2, float k1, float k2)
    {
        // Média harmônica das condutividades térmicas das duas células
        float kEff = (2.0f * k1 * k2) / (k1 + k2 + 0.0001f);
        return kEff * (t2 - t1);
    }
}
