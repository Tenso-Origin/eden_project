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
        // Cálculo do Índice de Estabilidade Homeostática (Equilíbrio Trófico da Amazônia):
        // 1. Razão presas-predadores: faixa saudável ~6:1 a 35:1 (ótimo em ~20:1 a 28:1)
        float faunalBalance;
        if (predators > 0 && herbivores > 0)
        {
            float preyToPredatorRatio = (float)herbivores / predators;
            float ratioDev = MathF.Abs(preyToPredatorRatio - 24.0f);
            faunalBalance = MathF.Max(0f, 1.0f - (ratioDev / 20.0f));
            // Viabilidade demográfica mínima para evitar artefatos em populações mínimas
            float viability = MathF.Min(1.0f, (herbivores + predators) / 8.0f);
            faunalBalance *= viability;
        }
        else if (herbivores == 0 && predators == 0)
        {
            faunalBalance = 0.5f; // Clímax puramente vegetal sem herbivoria
        }
        else
        {
            faunalBalance = 0.0f; // Colapso trófico (extinção de presas ou predadores de topo)
        }

        // 2. Saúde da Cobertura Vegetal e Produtividade Primária Líquida
        float effectiveCapacity = MathF.Max(1.0f, carryingCapacity);
        float biomassHealth = Math.Clamp(plantBiomass / effectiveCapacity, 0.0f, 1.0f);

        // 3. Equilíbrio de Mortalidade Demográfica (Predação regulatória vs Inanição em massa)
        int totalRecordedDeaths = CumulativeStarvationDeaths + CumulativePredationDeaths;
        float mortalityBalance = 1.0f;
        if (totalRecordedDeaths > 10)
        {
            // Em homeostase saudável, predadores controlam herbívoros; excesso de inanição indica colapso de suporte
            float starvationFraction = (float)CumulativeStarvationDeaths / totalRecordedDeaths;
            mortalityBalance = Math.Clamp(1.0f - (starvationFraction * 0.5f), 0.2f, 1.0f);
        }

        // Estabilidade sistêmica combinada [0.0 .. 1.0]
        float stabilityIndex = Math.Clamp(
            (faunalBalance * 0.50f) + (biomassHealth * 0.35f) + (mortalityBalance * 0.15f),
            0.0f, 1.0f
        );

        _samples[_sampleHead] = new EcologicalTelemetrySample(
            tick, days, herbivores, predators, plantBiomass,
            CumulativeBirths, CumulativeStarvationDeaths, CumulativePredationDeaths, CumulativeSenescenceDeaths,
            carryingCapacity, stabilityIndex
        );

        _sampleHead = (_sampleHead + 1) % MaxHistorySamples;
        if (_sampleCount < MaxHistorySamples) _sampleCount++;
    }

    /// <summary>
    /// Calcula o Índice de Homeostase Ecológica percentual (0 a 100%) baseado no equilíbrio de Lotka-Volterra
    /// da teia trófica neotropical amazônica (razão ótima presas/predadores ~20:1 a 35:1).
    /// </summary>
    public static float CalculateHomeostasis(int herbivores, int carnivores)
    {
        if (herbivores <= 0 && carnivores <= 0) return 0f;
        if (herbivores <= 0 || carnivores <= 0) return 0f; // Colapso por extinção de nível trófico

        float ratio = (float)herbivores / carnivores;
        const float optimalRatio = 28.0f;
        const float toleranceWindow = 22.0f;

        float deviation = MathF.Abs(ratio - optimalRatio);
        float balance = MathF.Max(0f, 1.0f - MathF.Pow(deviation / toleranceWindow, 1.4f));

        // Resiliência demográfica contra deriva genética e flutuações estocásticas
        float viability = MathF.Min(1.0f, (herbivores + carnivores) / 10.0f);

        return Math.Clamp(balance * viability * 100.0f, 0f, 100f);
    }

    /// <summary>
    /// Sobrecarga com 3 níveis tróficos amazônicos: produtores primários (biomassa vegetal), herbívoros e predadores de topo.
    /// </summary>
    public static float CalculateHomeostasis(int herbivores, int carnivores, float plantBiomass, float carryingCapacity)
    {
        float faunalHomeostasis = CalculateHomeostasis(herbivores, carnivores);
        float effectiveCapacity = MathF.Max(1.0f, carryingCapacity);
        float biomassHealth = Math.Clamp(plantBiomass / effectiveCapacity, 0.0f, 1.0f);

        if (herbivores <= 0 && carnivores <= 0)
        {
            return biomassHealth * 40.0f;
        }

        return Math.Clamp((faunalHomeostasis * 0.60f) + (biomassHealth * 40.0f), 0f, 100f);
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
