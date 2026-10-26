using System;
using System.Runtime.InteropServices;

namespace SimCore.Biosphere;

public enum EcologicalEventType : byte
{
    Birth              = 1,
    DeathByStarvation  = 2,
    DeathByPredation   = 3,
    DeathBySenescence  = 4,
    ClimateExtremity   = 5
}

/// <summary>
/// Registro discreto de evento demográfico ocorrido na simulação.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct DemographicEvent
{
    public readonly ulong TickIndex;
    public readonly float SimulationHour;
    public readonly ushort SpeciesId;
    public readonly EcologicalEventType EventType;
    public readonly float PosX;
    public readonly float PosY;

    public DemographicEvent(
        ulong tick, float simHour, ushort speciesId,
        EcologicalEventType eventType, float x, float y)
    {
        TickIndex = tick;
        SimulationHour = simHour;
        SpeciesId = speciesId;
        EventType = eventType;
        PosX = x;
        PosY = y;
    }
}

/// <summary>
/// Amostra agregada periódica da biosfera para séries temporais e gráficos de Lotka-Volterra.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct EcologicalTelemetrySample
{
    public readonly ulong Tick;
    public readonly float SimulationDays;
    public readonly int HerbivorePopulation;
    public readonly int PredatorPopulation;
    public readonly float GlobalPlantBiomass;
    public readonly int TotalBirthsRecorded;
    public readonly int StarvationDeathsRecorded;
    public readonly int PredationDeathsRecorded;
    public readonly int SenescenceDeathsRecorded;
    public readonly float CarryingCapacityEst;
    public readonly float StabilityIndex; // 0.0 (Colapso) a 1.0 (Homeostase perfeita)

    public EcologicalTelemetrySample(
        ulong tick, float days, int herbivores, int predators, float plantBiomass,
        int births, int starvations, int predations, int senescences,
        float carryingCapacity, float stability)
    {
        Tick = tick;
        SimulationDays = days;
        HerbivorePopulation = herbivores;
        PredatorPopulation = predators;
        GlobalPlantBiomass = plantBiomass;
        TotalBirthsRecorded = births;
        StarvationDeathsRecorded = starvations;
        PredationDeathsRecorded = predations;
        SenescenceDeathsRecorded = senescences;
        CarryingCapacityEst = carryingCapacity;
        StabilityIndex = stability;
    }
}

/// <summary>
/// TABELA 5: Telemetria, Histórico e Métricas de Balanço Ecológico Global.
/// Mantém um buffer circular de séries temporais para geração de gráficos sem alocação dinâmica.
/// </summary>
public sealed class EcosystemTelemetry
{
    public const int MaxHistorySamples = 1000;
    public const int MaxRecentEvents = 256;

    private readonly EcologicalTelemetrySample[] _samples = new EcologicalTelemetrySample[MaxHistorySamples];
    private int _sampleCount;
    private int _sampleHead;

    private readonly DemographicEvent[] _recentEvents = new DemographicEvent[MaxRecentEvents];
    private int _eventCount;
    private int _eventHead;

    // Contadores cumulativos vitais
    public int CumulativeBirths { get; private set; }
    public int CumulativeStarvationDeaths { get; private set; }
    public int CumulativePredationDeaths { get; private set; }
    public int CumulativeSenescenceDeaths { get; private set; }

    public void RecordEvent(ulong tick, float simHour, ushort speciesId, EcologicalEventType type, float x, float y)
    {
        _recentEvents[_eventHead] = new DemographicEvent(tick, simHour, speciesId, type, x, y);
        _eventHead = (_eventHead + 1) % MaxRecentEvents;
        if (_eventCount < MaxRecentEvents) _eventCount++;

        switch (type)
        {
            case EcologicalEventType.Birth:
                CumulativeBirths++;
                break;
            case EcologicalEventType.DeathByStarvation:
                CumulativeStarvationDeaths++;
                break;
            case EcologicalEventType.DeathByPredation:
                CumulativePredationDeaths++;
                break;
            case EcologicalEventType.DeathBySenescence:
                CumulativeSenescenceDeaths++;
                break;
        }
    }

    public void RecordSample(
        ulong tick, float days, int herbivores, int predators, float plantBiomass, float carryingCapacity)
    {
        // Cálculo do Índice de Estabilidade Homeostática (Equilíbrio de Lotka-Volterra):
        // Relação saudável teórica de presas para predadores é ~4:1 a 8:1
        float predatorToPreyRatio = (predators > 0) ? (float)herbivores / predators : 0f;
        float ratioBalance = 1.0f - MathF.Min(1.0f, MathF.Abs(predatorToPreyRatio - 4.5f) / 10.0f);
        float biomassHealth = Math.Clamp(plantBiomass / MathF.Max(1.0f, carryingCapacity), 0.1f, 1.0f);
        float stabilityIndex = Math.Clamp(ratioBalance * 0.7f + biomassHealth * 0.3f, 0.0f, 1.0f);

        _samples[_sampleHead] = new EcologicalTelemetrySample(
            tick, days, herbivores, predators, plantBiomass,
            CumulativeBirths, CumulativeStarvationDeaths, CumulativePredationDeaths, CumulativeSenescenceDeaths,
            carryingCapacity, stabilityIndex
        );

        _sampleHead = (_sampleHead + 1) % MaxHistorySamples;
        if (_sampleCount < MaxHistorySamples) _sampleCount++;
    }

    public ReadOnlySpan<EcologicalTelemetrySample> GetLatestSamples(int count)
    {
        int available = Math.Min(count, _sampleCount);
        if (available <= 0) return ReadOnlySpan<EcologicalTelemetrySample>.Empty;

        var result = new EcologicalTelemetrySample[available];
        for (int i = 0; i < available; i++)
        {
            int idx = (_sampleHead - 1 - i + MaxHistorySamples) % MaxHistorySamples;
            result[available - 1 - i] = _samples[idx];
        }
        return result;
    }

    public void Reset()
    {
        _sampleCount = 0;
        _sampleHead = 0;
        _eventCount = 0;
        _eventHead = 0;
        CumulativeBirths = 0;
        CumulativeStarvationDeaths = 0;
        CumulativePredationDeaths = 0;
        CumulativeSenescenceDeaths = 0;
    }
}
