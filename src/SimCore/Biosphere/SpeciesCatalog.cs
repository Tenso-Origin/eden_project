using System;
using System.Runtime.InteropServices;

namespace SimCore.Biosphere;

/// <summary>
/// Classificação da guilda trófica na teia alimentar ecológica.
/// </summary>
public enum TrophicGuild : byte
{
    PrimaryProducer   = 0, // Vegetais, gramíneas e biomassa fotossintética
    PrimaryConsumer   = 1, // Herbívoros (ex: roedores, lebres, insetos)
    SecondaryConsumer = 2, // Mesopredadores / Carnívoros (ex: felinos, canídeos)
    ApexPredator      = 3, // Predadores de topo de cadeia
    Decomposer        = 4  // Fungos, bactérias e necrófagos do solo
}

/// <summary>
/// TABELA 1: O "DNA" do Sistema (Species Blueprint).
/// Define os parâmetros biológicos, metabólicos e fisiológicos de cada espécie,
/// calibrados com bases científicas reais (PanTHERIA, Open Traits, Add-my-Pet e TRY Database).
/// Estrutura imutável orientada a dados com Zero Garbage Collection (GC = 0).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct SpeciesDef
{
    public readonly ushort SpeciesId;
    public readonly TrophicGuild Guild;
    public readonly byte TrophicLevel; // 1 = Produtor, 2 = Herbívoro, 3 = Carnívoro

    // --- Traços Morfológicos e Fisiológicos (PanTHERIA / Add-my-Pet) ---
    public readonly float AdultBodyMassGrams;       // Massa corporal média adulta (Rato: 250g; Gato: 4200g)
    public readonly float BasalMetabolicRateWatts;   // Taxa metabólica basal pela Lei de Kleiber (BMR ∝ M^0.75)
    public readonly float MovementCostPerMeter;      // Custo energético de locomoção por metro
    public readonly float MaxEnergyReserveJoules;    // Capacidade máxima de reserva energética de gordura/glicogênio
    public readonly float DailyWaterRequirementMl;   // Necessidade hídrica diária por peso corporal

    // --- Ciclo de Vida e Senescência ---
    public readonly float MaxLifespanDays;          // Expectativa máxima de vida (Rato: ~912d / 2.5a; Gato: ~5110d / 14a)
    public readonly float SexualMaturityDays;        // Idade de início da maturidade reprodutiva (Rato: ~60d; Gato: ~210d)
    public readonly float GestationPeriodDays;       // Período de gestação real (Rato: ~21d; Gato: ~64d)
    public readonly float MeanLitterSize;            // Média real de filhotes por ninhada (Rato: ~8; Gato: ~4)
    public readonly float ReproductionEnergyCost;    // Gasto energético exigido da mãe para conceber e desmamar
    public readonly float FemaleRatioNatural;        // Proporção sexual biológica de fêmeas (Rato: 0.50; Gato: 0.49)
    public readonly float PostPartumCooldownDays;    // Período de estro/recuperação pós-parto

    // --- Nicho Ecológico e Sensores ---
    public readonly float MinOptimalTemp;           // Temperatura mínima suportada confortavelmente (°C)
    public readonly float MaxOptimalTemp;           // Temperatura máxima suportada confortavelmente (°C)
    public readonly byte VisualSensoryRadius;       // Raio focal de visão direta em células
    public readonly byte OlfactorySensoryRadius;    // Raio de detecção química / faro em células (ex: 3x a visão no gato)

    public SpeciesDef(
        ushort id, TrophicGuild guild, byte trophicLevel,
        float massGrams, float bmrWatts, float moveCost, float maxEnergy, float waterMl,
        float maxLifespan, float maturityDays, float gestationDays, float litterSize,
        float reproCost, float femaleRatio, float postPartumCooldown,
        float minTemp, float maxTemp, byte visualRadius, byte olfactoryRadius)
    {
        SpeciesId = id;
        Guild = guild;
        TrophicLevel = trophicLevel;
        AdultBodyMassGrams = massGrams;
        BasalMetabolicRateWatts = bmrWatts;
        MovementCostPerMeter = moveCost;
        MaxEnergyReserveJoules = maxEnergy;
        DailyWaterRequirementMl = waterMl;
        MaxLifespanDays = maxLifespan;
        SexualMaturityDays = maturityDays;
        GestationPeriodDays = gestationDays;
        MeanLitterSize = litterSize;
        ReproductionEnergyCost = reproCost;
        FemaleRatioNatural = femaleRatio;
        PostPartumCooldownDays = postPartumCooldown;
        MinOptimalTemp = minTemp;
        MaxOptimalTemp = maxTemp;
        VisualSensoryRadius = visualRadius;
        OlfactorySensoryRadius = olfactoryRadius;
    }
}

/// <summary>
/// TABELA 3: Grafo de Interações Tróficas (Food Web Logic).
/// Conecta quem consome quem na teia alimentar, a eficiência nutricional e a Resposta Funcional de Holling.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct TrophicInteraction
{
    public readonly ushort PredatorSpeciesId;
    public readonly ushort PreySpeciesId;            // 0 = Produtor Primário (Biomassa Vegetal)
    public readonly float NutritionalYieldJoules;    // Energia absorvida pelo predador por unidade de biomassa consumida
    public readonly float BaseCaptureSuccessRate;    // Probabilidade nominal de sucesso de captura (0.0 a 1.0)
    public readonly float HollingHandlingTime;       // Tempo de manuseio e ingestão (saturação da curva de Holling Tipo II)
    public readonly float SatietyBoost;              // Redução de fome fornecida pela refeição

    public TrophicInteraction(
        ushort predatorId, ushort preyId,
        float nutritionalYield, float captureSuccess, float handlingTime, float satietyBoost)
    {
        PredatorSpeciesId = predatorId;
        PreySpeciesId = preyId;
        NutritionalYieldJoules = nutritionalYield;
        BaseCaptureSuccessRate = captureSuccess;
        HollingHandlingTime = handlingTime;
        SatietyBoost = satietyBoost;
    }
}

/// <summary>
/// Catálogo Estático em Memória dos Modelos de Espécies e Interações Tróficas.
/// Permite lookup imediato O(1) na CPU sem alocações dinâmicas.
/// </summary>
public static class SpeciesCatalog
{
    public const ushort IdVegetation = 0;
    public const ushort IdRat = 1;
    public const ushort IdCat = 10;

    private static readonly SpeciesDef[] _speciesRegistry = new SpeciesDef[64];
    private static readonly TrophicInteraction[] _trophicInteractions;

    static SpeciesCatalog()
    {
        // -------------------------------------------------------------------------
        // 1. ESPÉCIE: Rattus norvegicus (Rato-marrom / Herbívoro)
        // Traços baseados em PanTHERIA & Add-my-Pet:
        // Massa: ~250g | BMR: ~1.8W | Vida: ~2.5 anos (912.5 dias) | Maturidade: ~60 dias
        // Gestação: 21 dias | Ninhada média: 8 filhotes | Proporção sexual: 50% Fêmeas (1:1)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdRat] = new SpeciesDef(
            id: IdRat,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 250f,
            bmrWatts: 1.8f,
            moveCost: 0.08f,
            maxEnergy: 500f,
            waterMl: 25f,
            maxLifespan: 912.5f,
            maturityDays: 60.0f,
            gestationDays: 21.0f,
            litterSize: 8.0f,
            reproCost: 95.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 18.0f,
            minTemp: -5.0f,
            maxTemp: 38.0f,
            visualRadius: 5,
            olfactoryRadius: 8
        );

        // -------------------------------------------------------------------------
        // 2. ESPÉCIE: Felis catus (Gato-doméstico / Carnívoro Predador)
        // Traços baseados em PanTHERIA & Add-my-Pet:
        // Massa: ~4200g | BMR: ~12.5W | Vida: ~14 anos (5110 dias) | Maturidade: ~210 dias
        // Gestação: 64 dias | Ninhada média: 4 filhotes | Proporção sexual: 49% Fêmeas / 51% Machos
        // -------------------------------------------------------------------------
        _speciesRegistry[IdCat] = new SpeciesDef(
            id: IdCat,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 4200f,
            bmrWatts: 12.5f,
            moveCost: 0.22f,
            maxEnergy: 2400f,
            waterMl: 180f,
            maxLifespan: 5110.0f,
            maturityDays: 210.0f,
            gestationDays: 64.0f,
            litterSize: 4.0f,
            reproCost: 280.0f,
            femaleRatio: 0.49f,
            postPartumCooldown: 50.0f,
            minTemp: -8.0f,
            maxTemp: 42.0f,
            visualRadius: 15,
            olfactoryRadius: 45 // 3x a zona de caça visual direta
        );

        // -------------------------------------------------------------------------
        // TABELA 3: Grafo de Conexões Tróficas (Quem come o quê)
        // -------------------------------------------------------------------------
        _trophicInteractions = new TrophicInteraction[]
        {
            // Rato consome Biomassa Vegetal (Herbivoria)
            new TrophicInteraction(
                predatorId: IdRat,
                preyId: IdVegetation,
                nutritionalYield: 45.0f,
                captureSuccess: 1.0f,     // Pastagem garantida se houver biomassa
                handlingTime: 0.2f,
                satietyBoost: 25.0f
            ),

            // Gato consome Rato (Predação de Carnívoro com Resposta de Holling)
            new TrophicInteraction(
                predatorId: IdCat,
                preyId: IdRat,
                nutritionalYield: 320.0f, // 1 presa alimenta o gato com alta saciedade prolongada
                captureSuccess: 0.72f,    // 72% de chance de êxito no bote
                handlingTime: 1.5f,       // Tempo de imobilização e consumo
                satietyBoost: 80.0f
            )
        };
    }

    public static ref readonly SpeciesDef GetSpecies(ushort speciesId)
    {
        return ref _speciesRegistry[speciesId];
    }

    public static ReadOnlySpan<SpeciesDef> GetAllSpecies() => _speciesRegistry;
    public static ReadOnlySpan<TrophicInteraction> GetInteractions() => _trophicInteractions;

    /// <summary>
    /// Busca a interação trófica entre um consumidor e um recurso/presa.
    /// Retorna true se houver relação registrada no grafo ecológico.
    /// </summary>
    public static bool TryGetInteraction(ushort consumerId, ushort resourceId, out TrophicInteraction interaction)
    {
        for (int i = 0; i < _trophicInteractions.Length; i++)
        {
            if (_trophicInteractions[i].PredatorSpeciesId == consumerId &&
                _trophicInteractions[i].PreySpeciesId == resourceId)
            {
                interaction = _trophicInteractions[i];
                return true;
            }
        }
        interaction = default;
        return false;
    }
}
