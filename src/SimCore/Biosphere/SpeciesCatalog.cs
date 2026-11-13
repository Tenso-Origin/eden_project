using System;
using System.Runtime.InteropServices;

namespace SimCore.Biosphere;

/// <summary>
/// Classificação da guilda trófica na teia alimentar ecológica.
/// </summary>
public enum TrophicGuild : byte
{
    PrimaryProducer   = 0, // Vegetais, gramíneas e biomassa fotossintética
    PrimaryConsumer   = 1, // Herbívoros (ex: roedores, lebres, capivaras, antas, insetos)
    SecondaryConsumer = 2, // Mesopredadores / Carnívoros / Onívoros (ex: jaguatirica, ariranha, macaco-prego)
    ApexPredator      = 3, // Predadores de topo de cadeia (ex: onça-pintada, harpia, sucuri, jacaré)
    Decomposer        = 4  // Fungos, bactérias e detritívoros do solo (ex: besouros, cupins, baratas)
}

/// <summary>
/// TABELA 1: O "DNA" do Sistema (Species Blueprint).
/// Define os parâmetros biológicos, metabólicos e fisiológicos de cada espécie,
/// calibrados com bases científicas reais (PanTHERIA, Open Traits, INPA e TRY Database).
/// Estrutura imutável orientada a dados com Zero Garbage Collection (GC = 0).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct SpeciesDef
{
    public readonly ushort SpeciesId;
    public readonly TrophicGuild Guild;
    public readonly byte TrophicLevel; // 1 = Produtor, 2 = Herbívoro, 3 = Mesopredador/Onívoro, 4 = ApexPredator

    // --- Traços Morfológicos e Fisiológicos (PanTHERIA / INPA) ---
    public readonly float AdultBodyMassGrams;       // Massa corporal média adulta (gramas)
    public readonly float BasalMetabolicRateWatts;   // Taxa metabólica basal pela Lei de Kleiber (BMR ∝ M^0.75)
    public readonly float MovementCostPerMeter;      // Custo energético de locomoção por metro (Joules)
    public readonly float MaxEnergyReserveJoules;    // Capacidade máxima de reserva energética de gordura/glicogênio
    public readonly float DailyWaterRequirementMl;   // Necessidade hídrica diária por peso corporal (mL)

    // --- Ciclo Reprodutivo Realista e Estro (PanTHERIA / INPA) ---
    public readonly float MaxLifespanDays;          // Expectativa máxima de vida (dias)
    public readonly float SexualMaturityDays;        // Idade de início da maturidade reprodutiva (dias)
    public readonly float GestationPeriodDays;       // Período de gestação/incubação real (dias)
    public readonly float MeanLitterSize;            // Média real de filhotes por ninhada
    public readonly float ReproductionEnergyCost;    // Gasto energético exigido da mãe para conceber e desmamar
    public readonly float FemaleRatioNatural;        // Proporção sexual biológica de fêmeas
    public readonly float PostPartumCooldownDays;    // Período de recuperação pós-parto (dias)
    public readonly float EstrusIntervalDays;        // Intervalo cíclico regular entre cios (dias)
    public readonly float EstrusDurationDays;        // Duração da janela fértil receptiva de cio (dias)

    // --- Nicho Ecológico e Sensores ---
    public readonly float MinOptimalTemp;           // Temperatura mínima suportada confortavelmente (°C)
    public readonly float MaxOptimalTemp;           // Temperatura máxima suportada confortavelmente (°C)
    public readonly byte VisualSensoryRadius;       // Raio focal de visão direta em células/metros
    public readonly byte OlfactorySensoryRadius;    // Raio de detecção química / faro em células/metros

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
/// Catálogo Estático em Memória dos Modelos de Espécies e Interações Tróficas do Bioma Amazônico.
/// Permite lookup imediato O(1) na CPU sem alocações dinâmicas (Zero GC).
/// </summary>
public static class SpeciesCatalog
{
    // ==========================================
    // IDENTIFICADORES DE ESPÉCIES E RECURSOS
    // ==========================================
    public const ushort IdVegetation = 0;
    public const ushort IdAgouti = 1;
    public const ushort IdRat = 1; // Alias retrocompatível (Dasyprocta leporina / Cutia-vermelha)
    public const ushort IdOcelot = 10;
    public const ushort IdCat = 10; // Alias retrocompatível (Leopardus pardalis / Jaguatirica)
    public const ushort IdJaguar = 11;             // Onça-pintada (Panthera onca)
    public const ushort IdCapybara = 12;           // Capivara (Hydrochoerus hydrochaeris)
    public const ushort IdTapir = 13;              // Anta-brasileira (Tapirus terrestris)
    public const ushort IdSloth = 14;              // Preguiça-real (Choloepus didactylus)
    public const ushort IdCapuchinMonkey = 15;     // Macaco-prego (Sapajus apella)
    public const ushort IdGiantOtter = 16;         // Ariranha (Pteronura brasiliensis)
    public const ushort IdAnaconda = 17;           // Sucuri-verde (Eunectes murinus)

    public const ushort IdGrain = 20;              // Arroz Silvestre da Várzea Amazônica (Oryza glumaepatula)
    public const ushort IdBrazilNut = 21;          // Castanheira-do-Brasil (Bertholletia excelsa)
    public const ushort IdAcaiPalm = 22;           // Açaizeiro (Euterpe oleracea)
    public const ushort IdVictoriaRegia = 23;      // Vitória-régia (Victoria amazonica)

    public const ushort IdHarpyEagle = 30;         // Harpia / Gavião-Real Amazônico (Harpia harpyja)
    public const ushort IdToucan = 31;             // Tucano-toco (Ramphastos toco)
    public const ushort IdCarcara = 32;            // Carcará (Caracara plancus)

    public const ushort IdTambaqui = 40;           // Tambaqui (Colossoma macropomum)
    public const ushort IdTraira = 41;             // Traíra (Hoplias malabaricus)
    public const ushort IdPiranha = 41;            // Alias mantido para retrocompatibilidade
    public const ushort IdPirarucu = 42;           // Pirarucu (Arapaima gigas)

    public const ushort IdTortoise = 50;           // Jabuti-tinga (Chelonoidis denticulatus)
    public const ushort IdCaiman = 51;             // Jacaré-açu (Melanosuchus niger)
    public const ushort IdPoisonDartFrog = 52;     // Sapo-ponta-de-flecha (Dendrobates tinctorius)

    // Microfauna / Insetos Neotropicais (DOD)
    public const ushort IdAnt = 60;                // Formiga-saúva (Atta sexdens)
    public const ushort IdBee = 61;                // Abelha-jataí (Tetragonisca angustula)
    public const ushort IdButterfly = 62;          // Borboleta-morfo (Morpho menelaus)
    public const ushort IdDragonfly = 63;          // Libélula-imperador (Erythemis vesiculosa)
    public const ushort IdBeetle = 64;             // Besouro-hércules (Dynastes hercules)
    public const ushort IdMosquito = 65;           // Mosquito-prego (Anopheles darlingi)
    public const ushort IdGrasshopper = 66;        // Gafanhoto-esperança (Tropidacris cristata)
    public const ushort IdMantis = 67;             // Louva-a-deus (Acanthops falcata)
    public const ushort IdRoach = 68;              // Barata-da-mata (Blaberus giganteus)
    public const ushort IdTermite = 69;            // Cupim-de-montículo (Nasutitermes corniger)

    private static readonly SpeciesDef[] _speciesRegistry = new SpeciesDef[128];
    private static readonly TrophicInteraction[] _trophicInteractions;

    static SpeciesCatalog()
    {
        // -------------------------------------------------------------------------
        // FLORA E RECURSOS VEGETAIS (Produtores Primários)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdVegetation] = new SpeciesDef(IdVegetation, TrophicGuild.PrimaryProducer, 1, 1000f, 0f, 0f, 500f, 0f, 36500f, 30f, 0f, 0f, 0f, 0.5f, 0f, 0f, 0f, 10f, 45f, 0, 0);
        _speciesRegistry[IdGrain] = new SpeciesDef(IdGrain, TrophicGuild.PrimaryProducer, 1, 50f, 0f, 0f, 200f, 0f, 365f, 60f, 0f, 0f, 0f, 0.5f, 0f, 0f, 0f, 15f, 42f, 0, 0);
        _speciesRegistry[IdBrazilNut] = new SpeciesDef(IdBrazilNut, TrophicGuild.PrimaryProducer, 1, 500000f, 0f, 0f, 5000f, 0f, 182500f, 3650f, 0f, 0f, 0f, 0.5f, 0f, 0f, 0f, 18f, 40f, 0, 0);
        _speciesRegistry[IdAcaiPalm] = new SpeciesDef(IdAcaiPalm, TrophicGuild.PrimaryProducer, 1, 150000f, 0f, 0f, 3000f, 0f, 36500f, 1460f, 0f, 0f, 0f, 0.5f, 0f, 0f, 0f, 18f, 40f, 0, 0);
        _speciesRegistry[IdVictoriaRegia] = new SpeciesDef(IdVictoriaRegia, TrophicGuild.PrimaryProducer, 1, 10000f, 0f, 0f, 1500f, 0f, 7300f, 365f, 0f, 0f, 0f, 0.5f, 0f, 0f, 0f, 20f, 38f, 0, 0);

        // -------------------------------------------------------------------------
        // 1. Dasyprocta leporina (Cutia-vermelha / Herbívoro Frugívoro)
        // Calibrado PanTHERIA / INPA: massa 3.2kg, BMR 5.5W, mat 240d, gest 104d, ninhada 2.2
        // -------------------------------------------------------------------------
        _speciesRegistry[IdAgouti] = new SpeciesDef(
            id: IdAgouti,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 3200f,
            bmrWatts: 5.5f,
            moveCost: 0.08f,
            maxEnergy: 1400f,
            waterMl: 80f,
            maxLifespan: 3650f,
            maturityDays: 240f,
            gestationDays: 104f,
            litterSize: 2.2f,
            reproCost: 140f,
            femaleRatio: 0.50f,
            postPartumCooldown: 45f,
            estrusInterval: 30f,
            estrusDuration: 2f,
            minTemp: 16f,
            maxTemp: 40f,
            visualRadius: 25,
            olfactoryRadius: 60
        );

        // -------------------------------------------------------------------------
        // 10. Leopardus pardalis (Jaguatirica / Mesopredador Noturno)
        // Calibrado PanTHERIA / INPA: massa 12kg, BMR 26W, mat 550d, gest 80d, ninhada 2.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdOcelot] = new SpeciesDef(
            id: IdOcelot,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 12000f,
            bmrWatts: 26.0f,
            moveCost: 0.25f,
            maxEnergy: 4500f,
            waterMl: 350f,
            maxLifespan: 5840f,
            maturityDays: 550f,
            gestationDays: 80f,
            litterSize: 2.0f,
            reproCost: 320f,
            femaleRatio: 0.50f,
            postPartumCooldown: 90f,
            estrusInterval: 25f,
            estrusDuration: 5f,
            minTemp: 15f,
            maxTemp: 42f,
            visualRadius: 35,
            olfactoryRadius: 95
        );

        // -------------------------------------------------------------------------
        // 11. Panthera onca (Onça-Pintada / Apex Predator Terrestre Amazônico)
        // Calibrado PanTHERIA / INPA: massa 95kg, BMR 115W, mat 3a (1095d), gest 100d, ninhada 2.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdJaguar] = new SpeciesDef(
            id: IdJaguar,
            guild: TrophicGuild.ApexPredator,
            trophicLevel: 4,
            massGrams: 95000f,
            bmrWatts: 115.0f,
            moveCost: 0.35f,
            maxEnergy: 16000f,
            waterMl: 1500f,
            maxLifespan: 8030f,
            maturityDays: 1095f,
            gestationDays: 100f,
            litterSize: 2.0f,
            reproCost: 850f,
            femaleRatio: 0.50f,
            postPartumCooldown: 180f,
            estrusInterval: 45f,
            estrusDuration: 7f,
            minTemp: 14f,
            maxTemp: 42f,
            visualRadius: 50,
            olfactoryRadius: 110
        );

        // -------------------------------------------------------------------------
        // 12. Hydrochoerus hydrochaeris (Capivara / Herbívoro Semi-aquático Social)
        // Calibrado PanTHERIA / INPA: massa 55kg, BMR 62W, mat 540d, gest 150d, ninhada 4.5
        // -------------------------------------------------------------------------
        _speciesRegistry[IdCapybara] = new SpeciesDef(
            id: IdCapybara,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 55000f,
            bmrWatts: 62.0f,
            moveCost: 0.18f,
            maxEnergy: 9500f,
            waterMl: 800f,
            maxLifespan: 4015f,
            maturityDays: 540f,
            gestationDays: 150f,
            litterSize: 4.5f,
            reproCost: 500f,
            femaleRatio: 0.50f,
            postPartumCooldown: 90f,
            estrusInterval: 35f,
            estrusDuration: 3f,
            minTemp: 16f,
            maxTemp: 40f,
            visualRadius: 30,
            olfactoryRadius: 70
        );

        // -------------------------------------------------------------------------
        // 13. Tapirus terrestris (Anta-brasileira / Maior Herbívoro Terrestre Neotropical)
        // Calibrado PanTHERIA / INPA: massa 220kg, BMR 175W, mat 1200d, gest 395d, ninhada 1.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdTapir] = new SpeciesDef(
            id: IdTapir,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 220000f,
            bmrWatts: 175.0f,
            moveCost: 0.22f,
            maxEnergy: 22000f,
            waterMl: 2500f,
            maxLifespan: 10950f,
            maturityDays: 1200f,
            gestationDays: 395f,
            litterSize: 1.0f,
            reproCost: 900f,
            femaleRatio: 0.50f,
            postPartumCooldown: 240f,
            estrusInterval: 60f,
            estrusDuration: 4f,
            minTemp: 15f,
            maxTemp: 40f,
            visualRadius: 20,
            olfactoryRadius: 90
        );

        // -------------------------------------------------------------------------
        // 14. Choloepus didactylus (Preguiça-real / Herbívoro de Dossel)
        // Calibrado PanTHERIA / INPA: massa 7kg, BMR 3.2W, mat 1095d, gest 180d, ninhada 1.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdSloth] = new SpeciesDef(
            id: IdSloth,
            guild: TrophicGuild.PrimaryConsumer,
            trophicLevel: 2,
            massGrams: 7000f,
            bmrWatts: 3.2f,
            moveCost: 0.03f,
            maxEnergy: 2100f,
            waterMl: 90f,
            maxLifespan: 7300f,
            maturityDays: 1095f,
            gestationDays: 180f,
            litterSize: 1.0f,
            reproCost: 180f,
            femaleRatio: 0.50f,
            postPartumCooldown: 180f,
            estrusInterval: 365f,
            estrusDuration: 10f,
            minTemp: 18f,
            maxTemp: 38f,
            visualRadius: 15,
            olfactoryRadius: 30
        );

        // -------------------------------------------------------------------------
        // 15. Sapajus apella (Macaco-prego / Onívoro Inteligente de Dossel)
        // Calibrado PanTHERIA / INPA: massa 3.5kg, BMR 9.5W, mat 1460d, gest 160d, ninhada 1.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdCapuchinMonkey] = new SpeciesDef(
            id: IdCapuchinMonkey,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 3500f,
            bmrWatts: 9.5f,
            moveCost: 0.14f,
            maxEnergy: 2600f,
            waterMl: 120f,
            maxLifespan: 9125f,
            maturityDays: 1460f,
            gestationDays: 160f,
            litterSize: 1.0f,
            reproCost: 220f,
            femaleRatio: 0.50f,
            postPartumCooldown: 150f,
            estrusInterval: 28f,
            estrusDuration: 4f,
            minTemp: 16f,
            maxTemp: 40f,
            visualRadius: 65,
            olfactoryRadius: 35
        );

        // -------------------------------------------------------------------------
        // 16. Pteronura brasiliensis (Ariranha / Carnívoro Semi-aquático Social)
        // Calibrado PanTHERIA / INPA: massa 26kg, BMR 45W, mat 730d, gest 68d, ninhada 3.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdGiantOtter] = new SpeciesDef(
            id: IdGiantOtter,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 26000f,
            bmrWatts: 45.0f,
            moveCost: 0.28f,
            maxEnergy: 6500f,
            waterMl: 600f,
            maxLifespan: 4745f,
            maturityDays: 730f,
            gestationDays: 68f,
            litterSize: 3.0f,
            reproCost: 380f,
            femaleRatio: 0.50f,
            postPartumCooldown: 120f,
            estrusInterval: 90f,
            estrusDuration: 5f,
            minTemp: 18f,
            maxTemp: 38f,
            visualRadius: 40,
            olfactoryRadius: 75
        );

        // -------------------------------------------------------------------------
        // 17. Eunectes murinus (Sucuri-verde / Apex Predator de Várzeas e Igapós)
        // Calibrado PanTHERIA / INPA: massa 90kg, BMR 14W, mat 1460d, gest 210d, ninhada 25.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdAnaconda] = new SpeciesDef(
            id: IdAnaconda,
            guild: TrophicGuild.ApexPredator,
            trophicLevel: 4,
            massGrams: 90000f,
            bmrWatts: 14.0f,
            moveCost: 0.10f,
            maxEnergy: 14000f,
            waterMl: 200f,
            maxLifespan: 9125f,
            maturityDays: 1460f,
            gestationDays: 210f,
            litterSize: 25.0f,
            reproCost: 750f,
            femaleRatio: 0.50f,
            postPartumCooldown: 365f,
            estrusInterval: 365f,
            estrusDuration: 20f,
            minTemp: 20f,
            maxTemp: 40f,
            visualRadius: 25,
            olfactoryRadius: 90
        );

        // -------------------------------------------------------------------------
        // 30. Harpia harpyja (Gavião-Real / Harpia Amazônica - Apex Predator Aéreo)
        // Calibrado AVONET / PanTHERIA: massa 6kg, BMR 18W, mat 1460d, gest 56d, ninhada 2.0
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
            visualRadius: 150,
            olfactoryRadius: 20
        );

        // -------------------------------------------------------------------------
        // 31. Ramphastos toco (Tucano-toco / Ave Frugívora de Copa)
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
        // 32. Caracara plancus (Carcará / Falcão Terrestre Oportunista)
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
        // 40. Colossoma macropomum (Tambaqui / Peixe Frugívoro do Lago)
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
        // 41. Hoplias malabaricus (Traíra / Predador Lacustre de Emboscada)
        // -------------------------------------------------------------------------
        _speciesRegistry[IdTraira] = new SpeciesDef(
            id: IdTraira,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 2200f,
            bmrWatts: 0.95f,
            moveCost: 0.05f,
            maxEnergy: 2400f,
            waterMl: 0f,
            maxLifespan: 4380.0f,
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
        // 42. Arapaima gigas (Pirarucu / Gigante Piscívoro de Água Doce)
        // Calibrado INPA: massa 120kg, BMR 24W, mat 1460d, gest 30d, ninhada 60.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdPirarucu] = new SpeciesDef(
            id: IdPirarucu,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 120000f,
            bmrWatts: 24.0f,
            moveCost: 0.09f,
            maxEnergy: 12000f,
            waterMl: 0f,
            maxLifespan: 7300f,
            maturityDays: 1460f,
            gestationDays: 30f,
            litterSize: 60.0f,
            reproCost: 550f,
            femaleRatio: 0.50f,
            postPartumCooldown: 180f,
            estrusInterval: 365f,
            estrusDuration: 15f,
            minTemp: 20f,
            maxTemp: 36f,
            visualRadius: 35,
            olfactoryRadius: 80
        );

        // -------------------------------------------------------------------------
        // 50. Chelonoidis denticulatus (Jabuti-tinga / Réptil Herbívoro)
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
        // 51. Melanosuchus niger (Jacaré-açu / Predador Anfíbio de Topo)
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
        // 52. Dendrobates tinctorius (Sapo-ponta-de-flecha / Insetívoro Venenoso)
        // Calibrado INPA: massa 10g, BMR 0.015W, mat 365d, gest 14d, ninhada 12.0
        // -------------------------------------------------------------------------
        _speciesRegistry[IdPoisonDartFrog] = new SpeciesDef(
            id: IdPoisonDartFrog,
            guild: TrophicGuild.SecondaryConsumer,
            trophicLevel: 3,
            massGrams: 10f,
            bmrWatts: 0.015f,
            moveCost: 0.005f,
            maxEnergy: 8f,
            waterMl: 0.2f,
            maxLifespan: 2920f,
            maturityDays: 365f,
            gestationDays: 14f,
            litterSize: 12.0f,
            reproCost: 1.5f,
            femaleRatio: 0.50f,
            postPartumCooldown: 30f,
            estrusInterval: 45f,
            estrusDuration: 5f,
            minTemp: 18f,
            maxTemp: 38f,
            visualRadius: 16,
            olfactoryRadius: 20
        );

        // -------------------------------------------------------------------------
        // 60 a 69: INSETOS NEOTROPICAIS (Microfauna Ecológica DOD)
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
        // TABELA 3: Grafo Expandido de Conexões Tróficas (Quem consome quem)
        // -------------------------------------------------------------------------
        _trophicInteractions = new TrophicInteraction[]
        {
            // === Cutia-vermelha (IdAgouti) ===
            new TrophicInteraction(IdAgouti, IdVegetation, 60.0f, 1.0f, 0.20f, 30.0f),
            new TrophicInteraction(IdAgouti, IdGrain, 220.0f, 1.0f, 0.15f, 60.0f),
            new TrophicInteraction(IdAgouti, IdBrazilNut, 500.0f, 0.95f, 0.40f, 90.0f), // Quebrador primário de ouriço
            new TrophicInteraction(IdAgouti, IdAcaiPalm, 160.0f, 1.0f, 0.15f, 50.0f),
            new TrophicInteraction(IdAgouti, IdGrasshopper, 35.0f, 0.85f, 0.10f, 20.0f),
            new TrophicInteraction(IdAgouti, IdRoach, 40.0f, 0.90f, 0.10f, 25.0f),

            // === Jaguatirica (IdOcelot) ===
            new TrophicInteraction(IdOcelot, IdAgouti, 1200.0f, 0.75f, 0.60f, 85.0f),  // Preda Cutia (capture 0.75, yield 1200)
            new TrophicInteraction(IdOcelot, IdToucan, 450.0f, 0.60f, 0.50f, 50.0f),   // Preda Aves
            new TrophicInteraction(IdOcelot, IdCarcara, 800.0f, 0.50f, 0.80f, 65.0f),  // Preda Aves
            new TrophicInteraction(IdOcelot, IdGrasshopper, 35.0f, 0.90f, 0.10f, 15.0f), // Insetos
            new TrophicInteraction(IdOcelot, IdRoach, 40.0f, 0.95f, 0.10f, 15.0f),      // Insetos
            new TrophicInteraction(IdOcelot, IdBeetle, 50.0f, 0.90f, 0.15f, 20.0f),     // Insetos
            new TrophicInteraction(IdOcelot, IdSloth, 1500.0f, 0.65f, 0.80f, 75.0f),

            // === Onça-Pintada (IdJaguar) ===
            new TrophicInteraction(IdJaguar, IdCapybara, 8500.0f, 0.75f, 1.50f, 100.0f), // Preda Capivara (capture 0.75, yield 8500)
            new TrophicInteraction(IdJaguar, IdTapir, 12000.0f, 0.50f, 2.00f, 100.0f),   // Preda Anta (capture 0.50)
            new TrophicInteraction(IdJaguar, IdCaiman, 5500.0f, 0.65f, 1.80f, 90.0f),    // Preda Jacaré jovem (capture 0.65)
            new TrophicInteraction(IdJaguar, IdTortoise, 2500.0f, 0.85f, 1.20f, 70.0f),  // Preda Jabuti (capture 0.85, quebra de casco)
            new TrophicInteraction(IdJaguar, IdAgouti, 1400.0f, 0.85f, 0.40f, 40.0f),
            new TrophicInteraction(IdJaguar, IdSloth, 2200.0f, 0.90f, 0.60f, 60.0f),
            new TrophicInteraction(IdJaguar, IdGiantOtter, 3200.0f, 0.55f, 1.00f, 75.0f),

            // === Capivara (IdCapybara) ===
            new TrophicInteraction(IdCapybara, IdGrain, 250.0f, 1.0f, 0.20f, 70.0f),        // Consome Grãos
            new TrophicInteraction(IdCapybara, IdVegetation, 120.0f, 1.0f, 0.30f, 45.0f),   // Vegetação de várzea
            new TrophicInteraction(IdCapybara, IdVictoriaRegia, 180.0f, 1.0f, 0.25f, 55.0f),// Macrófitas aquáticas

            // === Anta-brasileira (IdTapir) ===
            new TrophicInteraction(IdTapir, IdVegetation, 200.0f, 1.0f, 0.40f, 50.0f),   // Consome Biomassa
            new TrophicInteraction(IdTapir, IdBrazilNut, 600.0f, 0.90f, 0.30f, 80.0f),   // Consome Castanhas
            new TrophicInteraction(IdTapir, IdAcaiPalm, 350.0f, 1.0f, 0.25f, 65.0f),

            // === Preguiça-real (IdSloth) ===
            new TrophicInteraction(IdSloth, IdVegetation, 90.0f, 1.0f, 0.60f, 40.0f),    // Consome Biomassa de folhas

            // === Macaco-prego (IdCapuchinMonkey) ===
            new TrophicInteraction(IdCapuchinMonkey, IdGrain, 150.0f, 1.0f, 0.15f, 45.0f),       // Grãos
            new TrophicInteraction(IdCapuchinMonkey, IdAcaiPalm, 200.0f, 1.0f, 0.20f, 55.0f),    // Frutos de Açaí
            new TrophicInteraction(IdCapuchinMonkey, IdBrazilNut, 450.0f, 0.70f, 0.50f, 75.0f),   // Castanha (ferramentas de pedra)
            new TrophicInteraction(IdCapuchinMonkey, IdGrasshopper, 40.0f, 0.85f, 0.10f, 25.0f), // Insetos
            new TrophicInteraction(IdCapuchinMonkey, IdBeetle, 50.0f, 0.80f, 0.15f, 30.0f),      // Insetos
            new TrophicInteraction(IdCapuchinMonkey, IdRoach, 35.0f, 0.85f, 0.10f, 25.0f),       // Insetos
            new TrophicInteraction(IdCapuchinMonkey, IdTermite, 25.0f, 0.95f, 0.10f, 20.0f),     // Insetos
            new TrophicInteraction(IdCapuchinMonkey, IdToucan, 300.0f, 0.50f, 0.40f, 60.0f),     // Ovos / filhotes de ninho

            // === Harpia / Gavião-Real (IdHarpyEagle) ===
            new TrophicInteraction(IdHarpyEagle, IdSloth, 2500.0f, 0.90f, 1.20f, 95.0f),           // Preda Preguiça (capture 0.90, yield 2500)
            new TrophicInteraction(IdHarpyEagle, IdCapuchinMonkey, 1600.0f, 0.65f, 0.90f, 85.0f),   // Preda Macaco-prego (capture 0.65, yield 1600)
            new TrophicInteraction(IdHarpyEagle, IdAgouti, 1300.0f, 0.85f, 0.60f, 75.0f),          // Preda Cutia (capture 0.85)
            new TrophicInteraction(IdHarpyEagle, IdOcelot, 2200.0f, 0.45f, 1.40f, 90.0f),          // Preda Jaguatirica jovem (capture 0.45)
            new TrophicInteraction(IdHarpyEagle, IdToucan, 600.0f, 0.85f, 0.60f, 65.0f),
            new TrophicInteraction(IdHarpyEagle, IdCarcara, 1300.0f, 0.60f, 1.00f, 85.0f),
            new TrophicInteraction(IdHarpyEagle, IdTambaqui, 3200.0f, 0.80f, 1.50f, 98.0f),

            // === Jacaré-açu (IdCaiman) ===
            new TrophicInteraction(IdCaiman, IdCapybara, 6000.0f, 0.70f, 1.60f, 95.0f),  // Preda Capivara (capture 0.70, yield 6000)
            new TrophicInteraction(IdCaiman, IdTambaqui, 3500.0f, 0.80f, 1.50f, 95.0f),  // Preda Tambaqui
            new TrophicInteraction(IdCaiman, IdTraira, 950.0f, 0.65f, 0.80f, 65.0f),     // Preda Traíra
            new TrophicInteraction(IdCaiman, IdPirarucu, 7000.0f, 0.50f, 2.00f, 98.0f),
            new TrophicInteraction(IdCaiman, IdAgouti, 900.0f, 0.80f, 0.50f, 55.0f),
            new TrophicInteraction(IdCaiman, IdOcelot, 2200.0f, 0.65f, 1.20f, 85.0f),

            // === Sucuri-verde (IdAnaconda) ===
            new TrophicInteraction(IdAnaconda, IdCapybara, 7500.0f, 0.65f, 2.50f, 100.0f), // Preda Capivara (capture 0.65, yield 7500)
            new TrophicInteraction(IdAnaconda, IdCaiman, 4500.0f, 0.55f, 2.20f, 90.0f),    // Preda Jacaré jovem
            new TrophicInteraction(IdAnaconda, IdPirarucu, 5500.0f, 0.60f, 2.00f, 95.0f),  // Preda Peixes
            new TrophicInteraction(IdAnaconda, IdTambaqui, 2800.0f, 0.75f, 1.50f, 85.0f),  // Preda Peixes
            new TrophicInteraction(IdAnaconda, IdAgouti, 1200.0f, 0.75f, 1.00f, 70.0f),
            new TrophicInteraction(IdAnaconda, IdTapir, 9500.0f, 0.40f, 3.00f, 100.0f),

            // === Ariranha (IdGiantOtter) ===
            new TrophicInteraction(IdGiantOtter, IdTraira, 1100.0f, 0.85f, 0.50f, 75.0f),   // Preda Traíra (capture 0.85)
            new TrophicInteraction(IdGiantOtter, IdTambaqui, 2200.0f, 0.80f, 0.80f, 90.0f), // Preda Tambaqui (capture 0.80)
            new TrophicInteraction(IdGiantOtter, IdCaiman, 1800.0f, 0.45f, 1.20f, 80.0f),

            // === Pirarucu (IdPirarucu) ===
            new TrophicInteraction(IdPirarucu, IdTambaqui, 1800.0f, 0.75f, 0.70f, 80.0f),   // Preda Tambaqui jovem
            new TrophicInteraction(IdPirarucu, IdTraira, 850.0f, 0.70f, 0.50f, 65.0f),
            new TrophicInteraction(IdPirarucu, IdMosquito, 20.0f, 0.95f, 0.10f, 15.0f),     // Insetos aquáticos
            new TrophicInteraction(IdPirarucu, IdDragonfly, 30.0f, 0.90f, 0.10f, 20.0f),

            // === Sapo-ponta-de-flecha (IdPoisonDartFrog) ===
            new TrophicInteraction(IdPoisonDartFrog, IdAnt, 0.8f, 0.95f, 0.05f, 25.0f),         // Preda Formiga
            new TrophicInteraction(IdPoisonDartFrog, IdMosquito, 0.5f, 0.90f, 0.05f, 20.0f),    // Preda Mosquito
            new TrophicInteraction(IdPoisonDartFrog, IdBeetle, 2.0f, 0.70f, 0.10f, 35.0f),      // Preda Besouro pequeno
            new TrophicInteraction(IdPoisonDartFrog, IdTermite, 0.6f, 0.95f, 0.05f, 20.0f),

            // === Tucano-toco (IdToucan) ===
            new TrophicInteraction(IdToucan, IdVegetation, 50.0f, 1.0f, 0.20f, 30.0f),
            new TrophicInteraction(IdToucan, IdGrain, 120.0f, 1.0f, 0.20f, 50.0f),
            new TrophicInteraction(IdToucan, IdAcaiPalm, 180.0f, 1.0f, 0.15f, 55.0f),
            new TrophicInteraction(IdToucan, IdButterfly, 30.0f, 0.75f, 0.10f, 25.0f),
            new TrophicInteraction(IdToucan, IdGrasshopper, 45.0f, 0.80f, 0.15f, 35.0f),

            // === Carcará (IdCarcara) ===
            new TrophicInteraction(IdCarcara, IdAgouti, 400.0f, 0.75f, 0.40f, 60.0f),
            new TrophicInteraction(IdCarcara, IdGrasshopper, 45.0f, 0.90f, 0.10f, 20.0f),
            new TrophicInteraction(IdCarcara, IdBeetle, 55.0f, 0.90f, 0.10f, 25.0f),
            new TrophicInteraction(IdCarcara, IdTortoise, 120.0f, 0.20f, 1.00f, 30.0f),

            // === Tambaqui (IdTambaqui) ===
            new TrophicInteraction(IdTambaqui, IdVegetation, 120.0f, 1.0f, 0.20f, 40.0f),
            new TrophicInteraction(IdTambaqui, IdGrain, 200.0f, 1.0f, 0.15f, 60.0f),
            new TrophicInteraction(IdTambaqui, IdAcaiPalm, 220.0f, 1.0f, 0.15f, 65.0f), // Frutos caídos na várzea

            // === Traíra (IdTraira) ===
            new TrophicInteraction(IdTraira, IdTambaqui, 650.0f, 0.55f, 0.50f, 75.0f),
            new TrophicInteraction(IdTraira, IdAgouti, 320.0f, 0.80f, 0.30f, 65.0f),

            // === Jabuti-tinga (IdTortoise) ===
            new TrophicInteraction(IdTortoise, IdVegetation, 85.0f, 1.0f, 0.40f, 50.0f),
            new TrophicInteraction(IdTortoise, IdAcaiPalm, 110.0f, 1.0f, 0.25f, 45.0f),

            // === Polinização / Mutualismo (Abelhas e Borboletas polinizam Castanheira, Açaizeiro e Vitória-régia) ===
            new TrophicInteraction(IdBee, IdBrazilNut, 25.0f, 1.0f, 0.10f, 40.0f),
            new TrophicInteraction(IdBee, IdAcaiPalm, 20.0f, 1.0f, 0.10f, 35.0f),
            new TrophicInteraction(IdBee, IdVictoriaRegia, 22.0f, 1.0f, 0.10f, 35.0f),
            new TrophicInteraction(IdButterfly, IdBrazilNut, 20.0f, 1.0f, 0.10f, 35.0f),
            new TrophicInteraction(IdButterfly, IdAcaiPalm, 18.0f, 1.0f, 0.10f, 30.0f),
            new TrophicInteraction(IdButterfly, IdVictoriaRegia, 20.0f, 1.0f, 0.10f, 30.0f),

            // === Insetos e Herbivoria / Detritivoria ===
            new TrophicInteraction(IdAnt, IdVegetation, 10.0f, 1.0f, 0.10f, 30.0f),
            new TrophicInteraction(IdBee, IdVegetation, 15.0f, 1.0f, 0.10f, 30.0f),
            new TrophicInteraction(IdButterfly, IdVegetation, 12.0f, 1.0f, 0.10f, 25.0f),
            new TrophicInteraction(IdGrasshopper, IdVegetation, 25.0f, 1.0f, 0.10f, 35.0f),
            new TrophicInteraction(IdGrasshopper, IdGrain, 75.0f, 1.0f, 0.10f, 60.0f),
            new TrophicInteraction(IdDragonfly, IdMosquito, 5.0f, 0.90f, 0.05f, 40.0f),
            new TrophicInteraction(IdDragonfly, IdButterfly, 15.0f, 0.60f, 0.10f, 55.0f),
            new TrophicInteraction(IdMantis, IdGrasshopper, 30.0f, 0.80f, 0.20f, 65.0f),
            new TrophicInteraction(IdMantis, IdBee, 18.0f, 0.75f, 0.15f, 50.0f),
            new TrophicInteraction(IdMantis, IdMosquito, 6.0f, 0.90f, 0.05f, 30.0f),
            new TrophicInteraction(IdMosquito, IdAgouti, 1.0f, 0.80f, 0.05f, 10.0f),
            new TrophicInteraction(IdMosquito, IdCapybara, 1.5f, 0.85f, 0.05f, 12.0f),
            new TrophicInteraction(IdMosquito, IdTapir, 2.0f, 0.85f, 0.05f, 15.0f),
            new TrophicInteraction(IdMosquito, IdOcelot, 1.0f, 0.75f, 0.05f, 10.0f),
            new TrophicInteraction(IdBeetle, IdVegetation, 30.0f, 1.0f, 0.30f, 45.0f),
            new TrophicInteraction(IdRoach, IdVegetation, 20.0f, 1.0f, 0.20f, 35.0f),
            new TrophicInteraction(IdTermite, IdVegetation, 8.0f, 1.0f, 0.10f, 25.0f)
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
