using System;
using System.Runtime.CompilerServices;
using SimCore.Matter;

namespace SimCore.SpatialGrid;

/// <summary>
/// FASE 2 / HIDROLOGIA & GEOMORFOLOGIA QUANTITATIVA:
/// Implementação de dinâmicas naturais baseadas no USGS Stream Power Incision Model (SPIM),
/// na Equação de Continuidade de Sedimentos de Exner e na Hidrologia Fill-and-Spill para Lagos.
/// Opera estritamente no paradigma DOD (Data-Oriented Design) sobre arrays contíguos do Chunk (GC = 0).
/// </summary>
public static class Hydrology
{
    // Coeficientes Hidráulicos (Balanço Hídrico ANA / CPRM)
    public const float GravityFlowRate = 0.50f;          // Coeficiente de escoamento livre de lâmina d'água
    public const float InfiltrationRate = 0.10f;         // Coeficiente de permeação no solo (m/s / hora)
    public const float ThermalEvaporationCoeff = 0.0005f;// Evaporação térmica direta
    public const float RiparianDiffusionRate = 0.04f;    // Infiltração lateral ripária nas margens de rios e lagos

    // Coeficientes Geomorfológicos e Fluviais (USGS Stream Power Law)
    // E = K * (Q^m) * (S^n), onde m = 0.5 (raiz de Q) e n = 1.0 (declividade linear)
    public const float StreamPowerIncisionCoeff = 0.0035f; // Coeficiente K de erodibilidade base
    public const float MaxDailyErosionRate = 1.0f;         // Teto estrito de desgaste: 1.0m por dia (1/24 m/hora)
    
    // Coeficientes de Sedimento e Transporte (Equação de Exner)
    public const float SedimentTransportCoeff = 0.025f;    // Capacidade de transporte de sedimento: Tc = Kt * Q * S
    public const float SedimentDepositionRate = 0.15f;     // Taxa de decantação quando Qs > Tc (formação de várzeas e deltas)
    public const float LakeDecantationEfficiency = 0.85f;  // Alta decantação de sedimentos em águas estagnadas (assoreamento de lagos)

    /// <summary>
    /// Executa um passo temporal completo de hidrologia, incisão fluvial de rios e dinâmica lacustre.
    /// </summary>
    public static void StepHydrology(Chunk chunk, ReadOnlySpan<MaterialDef> catalog, float dt)
    {
        ReadOnlySpan<ushort> matIds = chunk.MaterialId;
        Span<float> elevations = chunk.Elevation;
        ReadOnlySpan<float> waters = chunk.SurfaceWater;
        ReadOnlySpan<float> lakes = chunk.LakeWater;
        ReadOnlySpan<float> sediments = chunk.SuspendedSediment;
        ReadOnlySpan<float> moistures = chunk.Moisture;
        ReadOnlySpan<float> temps = chunk.Temperature;

        Span<ushort> nextMatIds = chunk.NextMaterialId;
        Span<float> nextWaters = chunk.NextSurfaceWater;
        Span<float> nextLakes = chunk.NextLakeWater;
        Span<float> nextSediments = chunk.NextSuspendedSediment;
        Span<float> nextDischarges = chunk.NextWaterDischarge;
        Span<float> nextMoistures = chunk.NextMoisture;

        // Cópia conservativa inicial para aplicação de deltas nos buffers de escrita
        waters.CopyTo(nextWaters);
        lakes.CopyTo(nextLakes);
        sediments.CopyTo(nextSediments);
        moistures.CopyTo(nextMoistures);
        matIds.CopyTo(nextMatIds);

        // Zera o buffer de vazão acumulada para o tick atual
        nextDischarges.Clear();

        // Limite máximo de erosão permitido para a fatia de tempo dt (1 dia = 24h)
        float maxErosionStep = (MaxDailyErosionRate / 24.0f) * dt;

        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);
                float curWater = waters[idx];
                float curLake = lakes[idx];
                float curElev = elevations[idx];
                float curTotalWater = curWater + curLake;
                float curHead = curElev + curTotalWater; // Carga hidráulica total
                ushort matId = matIds[idx];
                ref readonly var mat = ref catalog[matId];

                // =========================================================================
                // 1. INFILTRAÇÃO NO SOLO E RECARGA SUBTERRÂNEA
                // =========================================================================
                if (curTotalWater > 0f && mat.Permeability > 0f)
                {
                    float availMoistureCapacity = MathF.Max(0f, 1.0f - nextMoistures[idx]);
                    float infiltAmount = MathF.Min(curTotalWater, mat.Permeability * InfiltrationRate * dt);
                    infiltAmount = MathF.Min(infiltAmount, availMoistureCapacity);

                    if (nextWaters[idx] >= infiltAmount)
                    {
                        nextWaters[idx] -= infiltAmount;
                    }
                    else
                    {
                        float rem = infiltAmount - nextWaters[idx];
                        nextWaters[idx] = 0f;
                        nextLakes[idx] = MathF.Max(0f, nextLakes[idx] - rem);
                    }
                    nextMoistures[idx] += infiltAmount;
                }

                // =========================================================================
                // 2. EVAPORAÇÃO TÉRMICA DIRETA
                // =========================================================================
                float temp = temps[idx];
                if (temp > 0f)
                {
                    float evapo = temp * ThermalEvaporationCoeff * dt;
                    if (nextWaters[idx] > 0f)
                    {
                        nextWaters[idx] = MathF.Max(0f, nextWaters[idx] - evapo);
                    }
                    else if (nextLakes[idx] > 0f)
                    {
                        nextLakes[idx] = MathF.Max(0f, nextLakes[idx] - evapo);
                    }
                    else if (nextMoistures[idx] > 0f)
                    {
                        nextMoistures[idx] = MathF.Max(0f, nextMoistures[idx] - (evapo * 0.4f));
                    }
                }

                // =========================================================================
                // 3. ROTEAMENTO DE ESCOAMENTO D8 (MOORE NEIGHBORHOOD) & GEOMORFOLOGIA
                // =========================================================================
                if (curTotalWater > 0.001f)
                {
                    int lowestNeighborIdx = -1;
                    float lowestNeighborHead = curHead;
                    float maxSlope = 0f;

                    // Busca o vizinho de menor carga hidráulica nas 8 direções cardeais e colaterais
                    ScanNeighborsD8(x, y, curHead, elevations, waters, lakes,
                        ref lowestNeighborHead, ref lowestNeighborIdx, ref maxSlope);

                    // CENÁRIO A: DEPRESSÃO FECHADA (FORMAÇÃO E RETENÇÃO DE LAGO NATURAL)
                    if (lowestNeighborIdx < 0 || lowestNeighborHead >= curHead)
                    {
                        // A água não consegue escorrer por gravidade: estabiliza-se como LAGO
                        if (nextWaters[idx] > 0f)
                        {
                            nextLakes[idx] += nextWaters[idx];
                            nextWaters[idx] = 0f;
                        }

                        // Em água estagnada (lago), a declividade S = 0 e a velocidade zera.
                        // Todo o sedimento suspenso decanta no leito do lago (assoreamento lacustre natural)
                        if (sediments[idx] > 0f)
                        {
                            float decanted = sediments[idx] * LakeDecantationEfficiency * dt;
                            nextSediments[idx] -= decanted;
                            elevations[idx] += decanted * 0.5f; // Eleva levemente o assoalho do lago

                            // Fundo de lago colonizado por argila impermeável (IdClay)
                            if (elevations[idx] > -90f && matId == MaterialCatalog.IdStone)
                            {
                                nextMatIds[idx] = MaterialCatalog.IdClay;
                            }
                        }

                        // Umedecimento ripário das margens circundantes do lago
                        DiffuseRiparianMoisture(x, y, nextMoistures, dt);
                    }
                    // CENÁRIO B: ESCOAMENTO ATIVO (FORMAÇÃO E INCISÃO DE RIOS)
                    else
                    {
                        float headDiff = curHead - lowestNeighborHead;
                        float flow = MathF.Min(curTotalWater, headDiff * 0.5f) * GravityFlowRate * dt;

                        // Se a célula tinha volume retido de lago, mas o nível superou o vizinho (Spillpoint):
                        // Ocorre o transbordamento e formação do rio efluente (outflow river)
                        if (nextWaters[idx] >= flow)
                        {
                            nextWaters[idx] -= flow;
                        }
                        else
                        {
                            float rem = flow - nextWaters[idx];
                            nextWaters[idx] = 0f;
                            nextLakes[idx] = MathF.Max(0f, nextLakes[idx] - rem);
                        }

                        nextWaters[lowestNeighborIdx] += flow;
                        nextDischarges[lowestNeighborIdx] += flow;

                        // -----------------------------------------------------------------
                        // LEI DE POTÊNCIA DO ESCOAMENTO FLUVIAL (USGS STREAM POWER INCISION)
                        // E = K * sqrt(Q) * S
                        // -----------------------------------------------------------------
                        float localDischarge = MathF.Max(flow, chunk.WaterDischarge[idx]);
                        float erodibility = Math.Clamp(1.0f - (mat.Hardness / 10.0f), 0.08f, 1.0f);
                        float streamPowerErosion = StreamPowerIncisionCoeff * MathF.Sqrt(localDischarge + 0.001f) * maxSlope * erodibility * dt;
                        float actualErosion = MathF.Min(maxErosionStep, streamPowerErosion);

                        if (actualErosion > 0f)
                        {
                            elevations[idx] -= actualErosion;
                            // A rocha/solo erodido entra na correnteza como sedimento carreado
                            nextSediments[idx] += actualErosion * 1.2f;
                        }

                        // -----------------------------------------------------------------
                        // EQUAÇÃO DA CONTINUIDADE DE SEDIMENTOS DE EXNER (TRANSPORTE E DEPOSIÇÃO)
                        // Tc = Kt * Q * S
                        // -----------------------------------------------------------------
                        float transportCapacity = SedimentTransportCoeff * localDischarge * maxSlope;
                        float curSediment = sediments[idx];

                        if (curSediment > transportCapacity)
                        {
                            // Sobrecarga de sedimentos: deposição no leito (formação de aluvião e várzeas)
                            float excessSediment = curSediment - transportCapacity;
                            float deposition = excessSediment * SedimentDepositionRate * dt;

                            elevations[idx] += deposition;
                            nextSediments[idx] -= deposition;

                            // Transformação mineral: leitos rochosos onde há deposição contínua viram solo fértil (IdSoil)
                            if (matId == MaterialCatalog.IdStone && deposition > 0.01f)
                            {
                                nextMatIds[idx] = MaterialCatalog.IdSoil;
                            }
                        }

                        // Transporte do sedimento restante para a célula receptora a jusante
                        float sedimentTransport = MathF.Min(nextSediments[idx], curSediment * (flow / (curTotalWater + 0.0001f)));
                        nextSediments[idx] -= sedimentTransport;
                        nextSediments[lowestNeighborIdx] += sedimentTransport;

                        // Infiltração lateral ao longo da calha do rio (mata ciliar ripária)
                        if (localDischarge > 0.1f)
                        {
                            DiffuseRiparianMoisture(x, y, nextMoistures, dt);
                        }
                    }
                }
            }
        }
    }

    /// <summary>
    /// Varredura nos 8 vizinhos D8 (Moore) calculando a declividade hidráulica geodésica.
    /// Distância ortogonal = 1.0m, distância diagonal = 1.4142m.
    /// </summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static void ScanNeighborsD8(
        int cx, int cy, float curHead,
        ReadOnlySpan<float> elevations,
        ReadOnlySpan<float> waters,
        ReadOnlySpan<float> lakes,
        ref float lowestHead,
        ref int lowestIdx,
        ref float maxSlope)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            int ny = cy + dy;
            if (ny < 0 || ny >= Chunk.Height) continue;

            for (int dx = -1; dx <= 1; dx++)
            {
                if (dx == 0 && dy == 0) continue;
                int nx = cx + dx;
                if (nx < 0 || nx >= Chunk.Width) continue;

                int nIdx = Chunk.GetIndex(nx, ny);
                float neighborHead = elevations[nIdx] + waters[nIdx] + lakes[nIdx];

                if (neighborHead < lowestHead)
                {
                    float dist = (dx != 0 && dy != 0) ? 1.41421356f : 1.0f;
                    float slope = (curHead - neighborHead) / dist;

                    if (slope > maxSlope)
                    {
                        maxSlope = slope;
                        lowestHead = neighborHead;
                        lowestIdx = nIdx;
                    }
                }
            }
        }
    }

    /// <summary>
    /// Difusão de umidade capilar para as margens imediatas de corpos d'água perenes (lagos e rios),
    /// sustentando cinturões contínuos de mata ciliar de alta biomassa vegetal.
    /// </summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static void DiffuseRiparianMoisture(int cx, int cy, Span<float> nextMoistures, float dt)
    {
        float riparianBoost = RiparianDiffusionRate * dt;

        for (int dy = -1; dy <= 1; dy++)
        {
            int ny = cy + dy;
            if (ny < 0 || ny >= Chunk.Height) continue;

            for (int dx = -1; dx <= 1; dx++)
            {
                if (dx == 0 && dy == 0) continue;
                int nx = cx + dx;
                if (nx < 0 || nx >= Chunk.Width) continue;

                int nIdx = Chunk.GetIndex(nx, ny);
                nextMoistures[nIdx] = MathF.Min(0.85f, nextMoistures[nIdx] + riparianBoost);
            }
        }
    }
}
