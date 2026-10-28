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

    // --- Ciclo Reprodutivo Realista e Estro (PanTHERIA / Add-my-Pet) ---
    public readonly float MaxLifespanDays;          // Expectativa máxima de vida (Rato: ~912d / 2.5a; Gato: ~5110d / 14a)
    public readonly float SexualMaturityDays;        // Idade de início da maturidade reprodutiva (Rato: ~60d; Gato: ~210d)
    public readonly float GestationPeriodDays;       // Período de gestação real (Rato: ~21d; Gato: ~64d)
    public readonly float MeanLitterSize;            // Média real de filhotes por ninhada (Rato: ~8; Gato: ~4)
    public readonly float ReproductionEnergyCost;    // Gasto energético exigido da mãe para conceber e desmamar
    public readonly float FemaleRatioNatural;        // Proporção sexual biológica de fêmeas (Rato: 0.50; Gato: 0.49)
    public readonly float PostPartumCooldownDays;    // Período de estro/recuperação pós-parto
    public readonly float EstrusIntervalDays;        // Intervalo cíclico regular entre cios (Rato: 4.5d; Gato: 18.0d)
    public readonly float EstrusDurationDays;        // Duração da janela fértil receptiva de cio (Rato: 0.8d; Gato: 5.0d)

    // --- Nicho Ecológico e Sensores ---
    public readonly float MinOptimalTemp;           // Temperatura mínima suportada confortavelmente (°C)
    public readonly float MaxOptimalTemp;           // Temperatura máxima suportada confortavelmente (°C)
    public readonly byte VisualSensoryRadius;       // Raio focal de visão direta em células
    public readonly byte OlfactorySensoryRadius;    // Raio de detecção química / faro em células (ex: 3x a visão no gato)

    public byte MinLitterSize => (byte)Math.Max(1, (int)MathF.Round(MeanLitterSize * 0.75f));
    public byte MaxLitterSize => (byte)Math.Max(1, (int)MathF.Round(MeanLitterSize * 1.30f));

    public SpeciesDef(
        ushort id, TrophicGuild guild, byte trophicLevel,
        float massGrams, float bmrWatts, float moveCost, float maxEnergy, float waterMl,
        float maxLifespan, float maturityDays, float gestationDays, float litterSize,
        float reproCost, float femaleRatio, float postPartumCooldown,
        float estrusInterval, float estrusDuration,
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
        EstrusIntervalDays = estrusInterval;
        EstrusDurationDays = estrusDuration;
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
    public const ushort IdGrain = 20;       // Arroz Silvestre da Várzea Amazônica (Oryza glumaepatula)
    public const ushort IdHarpyEagle = 30;  // Harpia / Gavião-Real Amazônico (Harpia harpyja)
    public const ushort IdToucan = 31;      // Tucano-toco (Ramphastos toco) - Ave Frugívora/Passiva
    public const ushort IdCarcara = 32;     // Carcará (Caracara plancus) - Ave Predadora Oportunista
    public const ushort IdTambaqui = 40;    // Tambaqui (Colossoma macropomum) - Peixe Passivo/Frugívoro
        public const ushort IdTraira = 41;      // Traíra (Hoplias malabaricus) - Predador de Emboscada Noturna
        public const ushort IdPiranha = 41;     // Alias mantido para compatibilidade
    public const ushort IdTortoise = 50;    // Jabuti-tinga (Chelonoidis denticulatus) - Réptil Passivo/Herbívoro
    public const ushort IdCaiman = 51;      // Jacaré-açu / Coroa (Melanosuchus niger) - Réptil Predador Semi-aquático
    public const ushort IdAnt = 60;         // Formiga-saúva (Atta sexdens) - Inseto Herbívoro Social
    public const ushort IdBee = 61;         // Abelha-jataí (Tetragonisca angustula) - Inseto Polinizador
    public const ushort IdButterfly = 62;   // Borboleta-morfo (Morpho menelaus) - Inseto Nectívoro
    public const ushort IdDragonfly = 63;   // Libélula-imperador (Erythemis vesiculosa) - Inseto Predador Aéreo
    public const ushort IdBeetle = 64;      // Besouro-hércules (Dynastes hercules) - Inseto Detritívoro de Madeira
    public const ushort IdMosquito = 65;    // Mosquito-prego (Anopheles darlingi) - Inseto Hematófago/Aquático
    public const ushort IdGrasshopper = 66; // Gafanhoto-esperança (Tropidacris cristata) - Inseto Herbívoro Saltador
    public const ushort IdMantis = 67;      // Louva-a-deus (Acanthops falcata) - Inseto Carnívoro Emboscada
    public const ushort IdRoach = 68;       // Barata-da-mata (Blaberus giganteus) - Inseto Detritívoro Noturno
    public const ushort IdTermite = 69;     // Cupim-de-montículo (Nasutitermes corniger) - Inseto Decompositor

    private static readonly SpeciesDef[] _speciesRegistry = new SpeciesDef[128];
    private static readonly TrophicInteraction[] _trophicInteractions;

    static SpeciesCatalog()
    {
        // -------------------------------------------------------------------------
        // 1. ESPÉCIE: Rattus norvegicus (Rato-marrom / Herbívoro)
        // Traços baseados em PanTHERIA & Add-my-Pet (com aumento de +30% na taxa de natalidade):
        // Massa: ~250g | BMR: ~1.4W | Vida: ~2.5 anos (912.5 dias) | Maturidade: ~60 dias
        // Gestação: 21 dias | Ninhada média: ~10.4 filhotes (+30%) | Proporção sexual: 50% Fêmeas (1:1)
        // Ciclo estral: cio regular a cada 3.5 dias (duração fértil de ~0.8 dias)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdRat] = new SpeciesDef(
            id: IdRat,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 250f,
            bmrWatts: 1.4f,
            moveCost: 0.04f,
            maxEnergy: 650f,
            waterMl: 28f,
            maxLifespan: 912.5f,
            maturityDays: 60.0f,
            gestationDays: 21.0f,
            litterSize: 10.4f,    // +30% na taxa de natalidade (média 10.4 filhotes, min 8 a max 14)
            reproCost: 80.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 11.5f, // Recuperação pós-parto acelerada (+30% fecundidade contínua)
            estrusInterval: 3.5f,      // Ciclo estral mais frequente (+30% taxa de fertilidade)
            estrusDuration: 0.8f,
            minTemp: -5.0f,
            maxTemp: 38.0f,
            visualRadius: 15,     // Visão de campo próximo
            olfactoryRadius: 40   // Faro apurado de grãos e feromônios (40 metros)
        );

        // -------------------------------------------------------------------------
        // 2. ESPÉCIE: Felis catus (Gato-doméstico / Carnívoro Mesopredador)
        // Traços baseados em PanTHERIA & Add-my-Pet:
        // Massa: ~4200g | BMR: ~12.5W | Vida: ~14 anos (5110 dias) | Maturidade: ~210 dias
        // Gestação: 64 dias | Ninhada média: 4 filhotes | Proporção sexual: 49% Fêmeas / 51% Machos
        // Ciclo estral: cio a cada 18 dias com duração de 5 dias (chamado acústico e feromônio)
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
            estrusInterval: 18.0f,
            estrusDuration: 5.0f,
            minTemp: -8.0f,
            maxTemp: 42.0f,
            visualRadius: 25,     // Zona de caça direta e emboscada (25 metros)
            olfactoryRadius: 90   // Faro de longo alcance de presas e parceiros (90 metros)
        );

        // -------------------------------------------------------------------------
        // 3. ESPÉCIE: Harpia harpyja (Gavião-Real / Harpia Amazônica - Predador de Topo)
        // Traços reais (AVONET / PanTHERIA):
        // Massa: ~6500g (fêmea) / ~4800g (macho) | BMR: ~18.0W | Vida: ~35 anos (12775 dias)
        // Monogamia estrita (casal vitalício) | Ninhada: 1 a 2 ovos a cada 2 a 3 anos
        // Visão telescópica aérea de altíssima resolução (raio visual de 150 células)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdHarpyEagle] = new SpeciesDef(
            id: IdHarpyEagle,
            guild: TrophicGuild.ApexPredator,
            trophicLevel: 4,
            massGrams: 6000f,
            bmrWatts: 18.0f,
            moveCost: 0.15f,
            maxEnergy: 3800f,
            waterMl: 120f,
            maxLifespan: 12775.0f,
            maturityDays: 1460.0f,
            gestationDays: 56.0f,
            litterSize: 2.0f,
            reproCost: 450.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 180.0f,
            estrusInterval: 365.0f,
            estrusDuration: 14.0f,
            minTemp: 12.0f,
            maxTemp: 42.0f,
            visualRadius: 150,    // Visão telescópica aérea de predador de topo (150 metros)
            olfactoryRadius: 20
        );

        // -------------------------------------------------------------------------
        // 4. ESPÉCIE: Ramphastos toco (Tucano-toco / Ave Frugívora de Copa)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdToucan] = new SpeciesDef(
            id: IdToucan,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 600f,
            bmrWatts: 4.5f,
            moveCost: 0.12f,
            maxEnergy: 900f,
            waterMl: 45f,
            maxLifespan: 7300.0f,
            maturityDays: 730.0f,
            gestationDays: 18.0f,
            litterSize: 3.5f,
            reproCost: 120.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 90.0f,
            estrusInterval: 365.0f,
            estrusDuration: 10.0f,
            minTemp: 14.0f,
            maxTemp: 40.0f,
            visualRadius: 90,
            olfactoryRadius: 15
        );

        // -------------------------------------------------------------------------
        // 5. ESPÉCIE: Caracara plancus (Carcará / Falcão Terrestre Oportunista)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdCarcara] = new SpeciesDef(
            id: IdCarcara,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 1400f,
            bmrWatts: 7.8f,
            moveCost: 0.14f,
            maxEnergy: 1600f,
            waterMl: 65f,
            maxLifespan: 6200.0f,
            maturityDays: 730.0f,
            gestationDays: 30.0f,
            litterSize: 2.5f,
            reproCost: 210.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 120.0f,
            estrusInterval: 365.0f,
            estrusDuration: 12.0f,
            minTemp: 10.0f,
            maxTemp: 42.0f,
            visualRadius: 110,
            olfactoryRadius: 40
        );

        // -------------------------------------------------------------------------
        // 6. ESPÉCIE: Colossoma macropomum (Tambaqui / Peixe Frugívoro do Lago)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdTambaqui] = new SpeciesDef(
            id: IdTambaqui,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 15000f,
            bmrWatts: 5.2f,
            moveCost: 0.05f,
            maxEnergy: 4200f,
            waterMl: 0f,
            maxLifespan: 9125.0f,
            maturityDays: 1095.0f,
            gestationDays: 10.0f,
            litterSize: 40.0f,
            reproCost: 350.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 180.0f,
            estrusInterval: 365.0f,
            estrusDuration: 15.0f,
            minTemp: 18.0f,
            maxTemp: 36.0f,
            visualRadius: 25,
            olfactoryRadius: 50
        );

        // -------------------------------------------------------------------------
        // -------------------------------------------------------------------------
        // 7. ESPÉCIE: Hoplias malabaricus (Traíra / Predador Lacustre de Emboscada Noturna)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdTraira] = new SpeciesDef(
            id: IdTraira,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 2200f,
            bmrWatts: 0.95f,           // Metabolismo basal econômico de espreita/tocaia
            moveCost: 0.05f,
            maxEnergy: 2400f,
            waterMl: 0f,
            maxLifespan: 4380.0f,      // ~12 anos
            maturityDays: 450.0f,
            gestationDays: 5.0f,
            litterSize: 20.0f,
            reproCost: 180.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 120.0f,
            estrusInterval: 240.0f,
            estrusDuration: 10.0f,
            minTemp: 18.0f,
            maxTemp: 34.0f,
            visualRadius: 22,
            olfactoryRadius: 65
        );

        // -------------------------------------------------------------------------
        // 8. ESPÉCIE: Chelonoidis denticulatus (Jabuti-tinga / Réptil Herbívoro)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdTortoise] = new SpeciesDef(
            id: IdTortoise,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 8500f,
            bmrWatts: 1.5f,
            moveCost: 0.02f,
            maxEnergy: 3200f,
            waterMl: 40f,
            maxLifespan: 18250.0f,
            maturityDays: 3650.0f,
            gestationDays: 120.0f,
            litterSize: 8.0f,
            reproCost: 180.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 240.0f,
            estrusInterval: 365.0f,
            estrusDuration: 20.0f,
            minTemp: 16.0f,
            maxTemp: 38.0f,
            visualRadius: 18,
            olfactoryRadius: 35
        );

        // -------------------------------------------------------------------------
        // 9. ESPÉCIE: Melanosuchus niger (Jacaré-açu / Predador Anfíbio de Topo)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdCaiman] = new SpeciesDef(
            id: IdCaiman,
            guild: TrophicGuild.ApexPredator,
            trophicLevel: 4,
            massGrams: 50000f,
            bmrWatts: 6.0f,
            moveCost: 0.11f,
            maxEnergy: 8500f,
            waterMl: 150f,
            maxLifespan: 21900.0f,
            maturityDays: 3650.0f,
            gestationDays: 90.0f,
            litterSize: 35.0f,
            reproCost: 650.0f,
            femaleRatio: 0.50f,
            postPartumCooldown: 365.0f,
            estrusInterval: 365.0f,
            estrusDuration: 25.0f,
            minTemp: 18.0f,
            maxTemp: 40.0f,
            visualRadius: 50,
            olfactoryRadius: 85
        );

        // -------------------------------------------------------------------------
        // 10 a 19: INSETOS NEOTROPICAIS (Microfauna Ecológica DOD)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdAnt] = new SpeciesDef(IdAnt, TrophicGuild.PrimaryConsumer, 2, 0.02f, 0.0001f, 0.001f, 0.5f, 0.01f, 365f, 30f, 15f, 50f, 0.1f, 0.8f, 10f, 30f, 5f, 15f, 40f, 6, 25);
        _speciesRegistry[IdBee] = new SpeciesDef(IdBee, TrophicGuild.PrimaryConsumer, 2, 0.05f, 0.0003f, 0.002f, 1.0f, 0.02f, 120f, 20f, 12f, 30f, 0.2f, 0.9f, 8f, 20f, 3f, 16f, 40f, 12, 35);
        _speciesRegistry[IdButterfly] = new SpeciesDef(IdButterfly, TrophicGuild.PrimaryConsumer, 2, 0.3f, 0.001f, 0.005f, 2.5f, 0.05f, 45f, 15f, 7f, 60f, 0.5f, 0.5f, 5f, 14f, 2f, 18f, 38f, 15, 20);
        _speciesRegistry[IdDragonfly] = new SpeciesDef(IdDragonfly, TrophicGuild.SecondaryConsumer, 3, 0.8f, 0.003f, 0.008f, 4.0f, 0.08f, 90f, 30f, 10f, 40f, 0.8f, 0.5f, 7f, 20f, 3f, 18f, 38f, 24, 10);
        _speciesRegistry[IdBeetle] = new SpeciesDef(IdBeetle, TrophicGuild.Decomposer, 2, 15.0f, 0.015f, 0.012f, 35.0f, 0.3f, 730f, 180f, 30f, 20f, 4.0f, 0.5f, 30f, 60f, 7f, 15f, 39f, 10, 30);
        _speciesRegistry[IdMosquito] = new SpeciesDef(IdMosquito, TrophicGuild.SecondaryConsumer, 2, 0.005f, 0.00005f, 0.001f, 0.2f, 0.005f, 30f, 10f, 5f, 100f, 0.05f, 0.6f, 4f, 10f, 2f, 18f, 40f, 8, 30);
        _speciesRegistry[IdGrasshopper] = new SpeciesDef(IdGrasshopper, TrophicGuild.PrimaryConsumer, 2, 3.5f, 0.008f, 0.010f, 15.0f, 0.15f, 150f, 45f, 14f, 45f, 2.0f, 0.5f, 15f, 30f, 4f, 16f, 40f, 14, 15);
        _speciesRegistry[IdMantis] = new SpeciesDef(IdMantis, TrophicGuild.SecondaryConsumer, 3, 4.0f, 0.010f, 0.006f, 18.0f, 0.18f, 240f, 60f, 20f, 50f, 3.0f, 0.5f, 20f, 45f, 5f, 18f, 39f, 22, 12);
        _speciesRegistry[IdRoach] = new SpeciesDef(IdRoach, TrophicGuild.Decomposer, 2, 5.0f, 0.008f, 0.008f, 20.0f, 0.20f, 550f, 90f, 25f, 35f, 3.0f, 0.5f, 20f, 40f, 5f, 15f, 41f, 10, 45);
        _speciesRegistry[IdTermite] = new SpeciesDef(IdTermite, TrophicGuild.Decomposer, 2, 0.015f, 0.0001f, 0.001f, 0.4f, 0.01f, 300f, 25f, 12f, 80f, 0.1f, 0.7f, 8f, 20f, 3f, 16f, 40f, 4, 30);

        // -------------------------------------------------------------------------
        // TABELA 3: Grafo Expandido de Conexões Tróficas (Quem come o quê)
        // -------------------------------------------------------------------------
        _trophicInteractions = new TrophicInteraction[]
        {
            // Rato consome Vegetação e Grãos
            new TrophicInteraction(IdRat, IdVegetation, 45.0f, 1.0f, 0.2f, 25.0f),
            new TrophicInteraction(IdRat, IdGrain, 180.0f, 1.0f, 0.15f, 55.0f),
            new TrophicInteraction(IdRat, IdGrasshopper, 35.0f, 0.85f, 0.1f, 20.0f),
            new TrophicInteraction(IdRat, IdRoach, 40.0f, 0.90f, 0.1f, 25.0f),

            // Gato consome Rato, Gafanhoto e Pássaros menores
            new TrophicInteraction(IdCat, IdRat, 650.0f, 0.75f, 0.5f, 85.0f),
            new TrophicInteraction(IdCat, IdGrasshopper, 35.0f, 0.90f, 0.1f, 15.0f),
            new TrophicInteraction(IdCat, IdRoach, 40.0f, 0.95f, 0.1f, 15.0f),

            // Harpia consome Rato, Gato, Peixes grandes e Tucanos
            new TrophicInteraction(IdHarpyEagle, IdRat, 250.0f, 0.90f, 0.3f, 35.0f),
            new TrophicInteraction(IdHarpyEagle, IdCat, 1800.0f, 0.55f, 1.2f, 95.0f),
            new TrophicInteraction(IdHarpyEagle, IdTambaqui, 3200.0f, 0.80f, 1.5f, 98.0f),
            new TrophicInteraction(IdHarpyEagle, IdToucan, 600.0f, 0.85f, 0.6f, 65.0f),
            new TrophicInteraction(IdHarpyEagle, IdCarcara, 1300.0f, 0.60f, 1.0f, 85.0f),

            // Tucano consome Vegetação, Grãos, Borboleta e Gafanhoto
            new TrophicInteraction(IdToucan, IdVegetation, 50.0f, 1.0f, 0.2f, 30.0f),
            new TrophicInteraction(IdToucan, IdGrain, 120.0f, 1.0f, 0.2f, 50.0f),
            new TrophicInteraction(IdToucan, IdButterfly, 30.0f, 0.75f, 0.1f, 25.0f),
            new TrophicInteraction(IdToucan, IdGrasshopper, 45.0f, 0.80f, 0.15f, 35.0f),

            // Carcará consome Rato, Gafanhoto, Besouro e Carcaças
            new TrophicInteraction(IdCarcara, IdRat, 400.0f, 0.75f, 0.4f, 60.0f),
            new TrophicInteraction(IdCarcara, IdGrasshopper, 45.0f, 0.90f, 0.1f, 20.0f),
            new TrophicInteraction(IdCarcara, IdBeetle, 55.0f, 0.90f, 0.1f, 25.0f),
            new TrophicInteraction(IdCarcara, IdTortoise, 120.0f, 0.20f, 1.0f, 30.0f), // Carapaça dura do jabuti dificulta predação

            // Tambaqui consome Vegetação Aquática e Grãos caídos no lago
            new TrophicInteraction(IdTambaqui, IdVegetation, 120.0f, 1.0f, 0.2f, 40.0f),
            new TrophicInteraction(IdTambaqui, IdGrain, 200.0f, 1.0f, 0.15f, 60.0f),

        // Traíra preda Tambaqui jovem/adulto por emboscada e pequenos animais na água
        new TrophicInteraction(IdTraira, IdTambaqui, 650.0f, 0.55f, 0.5f, 75.0f),
        new TrophicInteraction(IdTraira, IdRat, 320.0f, 0.80f, 0.3f, 65.0f),

            // Jabuti consome Vegetação e Detritos orgânicos
            new TrophicInteraction(IdTortoise, IdVegetation, 85.0f, 1.0f, 0.4f, 50.0f),

            // Jacaré preda Peixes (Tambaqui, Piranha), Ratos e Gatos na margem
            new TrophicInteraction(IdCaiman, IdTambaqui, 3500.0f, 0.80f, 1.5f, 95.0f),
        new TrophicInteraction(IdCaiman, IdTraira, 950.0f, 0.65f, 0.8f, 65.0f),
            new TrophicInteraction(IdCaiman, IdRat, 450.0f, 0.90f, 0.3f, 50.0f),
            new TrophicInteraction(IdCaiman, IdCat, 2200.0f, 0.70f, 1.2f, 90.0f),

            // Insetos e suas Interações
            new TrophicInteraction(IdAnt, IdVegetation, 10.0f, 1.0f, 0.1f, 30.0f),
            new TrophicInteraction(IdBee, IdVegetation, 15.0f, 1.0f, 0.1f, 30.0f),
            new TrophicInteraction(IdButterfly, IdVegetation, 12.0f, 1.0f, 0.1f, 25.0f),
            new TrophicInteraction(IdGrasshopper, IdVegetation, 25.0f, 1.0f, 0.1f, 35.0f),
            new TrophicInteraction(IdGrasshopper, IdGrain, 75.0f, 1.0f, 0.1f, 60.0f),
            new TrophicInteraction(IdDragonfly, IdMosquito, 5.0f, 0.90f, 0.05f, 40.0f),
            new TrophicInteraction(IdDragonfly, IdButterfly, 15.0f, 0.60f, 0.1f, 55.0f),
            new TrophicInteraction(IdMantis, IdGrasshopper, 30.0f, 0.80f, 0.2f, 65.0f),
            new TrophicInteraction(IdMantis, IdBee, 18.0f, 0.75f, 0.15f, 50.0f),
            new TrophicInteraction(IdMantis, IdMosquito, 6.0f, 0.90f, 0.05f, 30.0f),
            new TrophicInteraction(IdMosquito, IdRat, 1.0f, 0.80f, 0.05f, 10.0f),
            new TrophicInteraction(IdMosquito, IdCat, 1.0f, 0.75f, 0.05f, 10.0f),
            new TrophicInteraction(IdBeetle, IdVegetation, 30.0f, 1.0f, 0.3f, 45.0f),
            new TrophicInteraction(IdRoach, IdVegetation, 20.0f, 1.0f, 0.2f, 35.0f),
            new TrophicInteraction(IdTermite, IdVegetation, 8.0f, 1.0f, 0.1f, 25.0f)
            ),

            // Harpia preda Gato em Campo Aberto (Chance de Revide Felino!)
            new TrophicInteraction(
                predatorId: IdHarpyEagle,
                preyId: IdCat,
                nutritionalYield: 1800.0f,
                captureSuccess: 0.55f,    // Gato pode revidar com unhas e dentes e fugir
                handlingTime: 1.2f,
                satietyBoost: 95.0f
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
