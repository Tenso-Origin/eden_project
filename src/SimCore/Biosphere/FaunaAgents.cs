using System;
using System.Runtime.InteropServices;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

public enum AnimalDiet : byte
{
    Herbivore = 0,
    Carnivore = 1,
    Omnivore  = 2,
    AvianApex = 3 // Predador Aéreo de Topo (Harpia / Gavião-Real Amazônico)
}

public enum AnimalSpecies : ushort
{
    Rat = 1,        // Herbívoro: Vida ~2.5 anos, busca biomassa/grãos, alta fecundidade
    Cat = 10,       // Carnívoro: Vida ~14 anos, territorial, busca presas em até 15 células
    HarpyEagle = 30 // Ave de Rapina de Topo: Casal monogâmico, caça em gramíneas abertas
}

public enum AgentState : byte
{
    Foraging = 0,
    Hunting  = 1,
    Fleeing  = 2,
    Mating   = 3,
    Resting  = 4,
    Drinking = 5,
    Dead     = 6
}

/// <summary>
/// Genoma Adaptativo e Neuroevolução de Traços Herdáveis dos Ratos.
/// Modelado para seleção natural darwiniana contínua, recombinação mendeliana e plasticidade epigenética.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct RatGenome
{
    public float AlertRadius;     // 10.0f a 24.0f: Raio sensorial de percepção antecipada de predadores
    public float RefugeAffinity;  // 0.2f a 1.0f: Viés cinemático de fuga para cobertura vegetal densa (refúgio de Holling)
    public float SprintBurst;     // 1.2f a 1.9f: Multiplicador de arrancada anaeróbica sob perseguição iminente
    public float EpigeneticBonus; // 0.0f a 4.0f: Experiência adquirida de sobrevivência individual
    public ushort Generation;     // Contador geracional contínuo (G0, G1, G2...)

    public static RatGenome CreateDefault(ushort gen = 0)
    {
        return new RatGenome
        {
            AlertRadius = 12.0f + (Random.Shared.NextSingle() * 4.0f - 2.0f),
            RefugeAffinity = 0.45f + (Random.Shared.NextSingle() * 0.20f - 0.10f),
            SprintBurst = 1.35f + (Random.Shared.NextSingle() * 0.20f - 0.10f),
            EpigeneticBonus = 0f,
            Generation = gen
        };
    }

    public static RatGenome Recombine(in RatGenome mother, in RatGenome father)
    {
        // 1. Recombinação genética (Crossover 50/50)
        float baseAlert = (mother.AlertRadius + father.AlertRadius) * 0.5f;
        float baseRefuge = (mother.RefugeAffinity + father.RefugeAffinity) * 0.5f;
        float baseSprint = (mother.SprintBurst + father.SprintBurst) * 0.5f;

        // 2. Herança epigenética parcial (pais experientes passam +15% de vigilância aos filhotes)
        float parentalExp = (mother.EpigeneticBonus + father.EpigeneticBonus) * 0.15f;
        baseAlert += parentalExp;

        // 3. Mutação darwiniana randômica (+- 5%)
        float mutAlert = (Random.Shared.NextSingle() * 0.10f - 0.05f) * baseAlert;
        float mutRefuge = (Random.Shared.NextSingle() * 0.10f - 0.05f) * baseRefuge;
        float mutSprint = (Random.Shared.NextSingle() * 0.10f - 0.05f) * baseSprint;

        ushort nextGen = (ushort)(Math.Max(mother.Generation, father.Generation) + 1);

        return new RatGenome
        {
            AlertRadius = Math.Clamp(baseAlert + mutAlert, 8.0f, 26.0f),
            RefugeAffinity = Math.Clamp(baseRefuge + mutRefuge, 0.10f, 1.0f),
            SprintBurst = Math.Clamp(baseSprint + mutSprint, 1.15f, 2.0f),
            EpigeneticBonus = 0f,
            Generation = nextGen
        };
    }
}

/// <summary>
/// TABELA 2: Agentes Individuais Ativos (ECS Entity Component).
/// Struct contígua em memória sem ponteiros para o Garbage Collector (GC = 0).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct AnimalAgent
{
    public uint EntityId;
    public ushort SpeciesId;
    public AnimalDiet Diet;
    public AgentState State;

    // Estado Fisiológico Contínuo (Combustível Metabólico da Tabela 1)
    public float Health;         // 0.0 (Morto) a 100.0 (Cheio de vida)
    public float Hunger;         // 0.0 (Saciado) a 100.0 (Faminto)
    public float Thirst;         // 0.0 (Hidratado) a 100.0 (Desidratado)
    public float Energy;         // Reserva energética em Joules relativos (0.0 a MaxEnergy)
    public float MoveSpeed;      // Células por segundo (ex: 2.0f)

    // Ciclo Biológico Realista (PanTHERIA / Add-my-Pet)
    public float AgeInDays;      // Idade acumulada em dias de simulação
    public float MaxLifespanDays;// Expectativa máxima de vida
    public float MatingCooldown; // Tempo até poder acasalar novamente
    public byte SensoryRadius;   // Raio focal de visão direta
    public byte DailyFunKills;   // Caças lúdicas no dia (gato perde o interesse lúdico após a 2ª)
    public byte Sex;             // 0 = Fêmea, 1 = Macho (proporção natural da espécie)
    public bool IsPregnant;      // Fêmea em período de gestação
    public float GestationDaysRemaining; // Dias de gestação restantes
    public byte LitterSize;      // Média real de filhotes da ninhada

    // Ciclos Reprodutivos Biológicos Reais e Estro (PanTHERIA / Add-my-Pet)
    public float EstrusCycleTimer;        // Temporizador até o próximo ciclo fértil (interestro)
    public float EstrusDurationRemaining; // Dias restantes do cio receptivo ativo
    public float PounceBoostCooldown;     // Cooldown da arrancada anaeróbica de emboscada felina

    // Genética Evolutiva e Inteligência Hereditária
    public RatGenome Genome;
    public RatGenome MateGenome; // Genoma do parceiro retido na fêmea para recombinação no parto

    // Posição contínua e Cinética no Mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    // Mecânica de Ninho / Toca / Refúgio Ecológico (+ comida, - predadores)
    public bool HasNest;
    public float NestPosX;
    public float NestPosY;
    public float DaysPregnant;
    public uint MotherId;
    public bool IsMigrated; // Dispersão/migração temporária fora do bioma (controle homeostático)
    public bool IsSafeInBurrow => HasNest && (MathF.Pow(PosX - NestPosX, 2) + MathF.Pow(PosY - NestPosY, 2) <= 9.0f);

    public bool IsFemale => Sex == 0;
    public bool IsMale => Sex == 1;
    public bool IsAdult => AgeInDays >= (MaxLifespanDays * 0.08f);
    public bool IsInEstrus => IsFemale && IsAdult && !IsPregnant && EstrusDurationRemaining > 0f && Health > 50f;
    public bool IsReadyToMate => IsAdult && Health > 50.0f && (
        (IsFemale && IsInEstrus && Hunger < 50.0f) ||
        (IsMale && Hunger < 55.0f && MatingCooldown <= 0.0f)
    );

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y, float speed = 2.0f, byte? specificSex = null, ushort initialGen = 0)
    {
        EntityId = id;
        SpeciesId = species;
        Diet = diet;
        State = AgentState.Foraging;
        Health = 100f;
        Hunger = 20f;
        Thirst = 0f;
        DailyFunKills = 0;
        PosX = x;
        PosY = y;
        VelocityX = 0f;
        VelocityY = 0f;
        HasNest = false;
        NestPosX = x;
        NestPosY = y;
        IsPregnant = false;
        GestationDaysRemaining = 0f;
        LitterSize = 0;
        PounceBoostCooldown = 0f;
        IsMigrated = false;
        Genome = RatGenome.CreateDefault(initialGen);
        MateGenome = Genome;

        // Puxa os parâmetros biológicos reais diretamente do "DNA" da Espécie (Tabela 1)
        ref readonly var def = ref SpeciesCatalog.GetSpecies(species);
        Energy = def.MaxEnergyReserveJoules * 0.8f;
        MoveSpeed = speed;
        MaxLifespanDays = def.MaxLifespanDays;
        SensoryRadius = def.VisualSensoryRadius;

        // Proporção sexual natural da espécie
        int femaleChance = (int)(def.FemaleRatioNatural * 100.0f);
        Sex = specificSex ?? (byte)(Random.Shared.Next(100) < femaleChance ? 0 : 1);

        // Ciclos de estro escalonados de forma natural para fêmeas iniciais
        if (Sex == 0)
        {
            EstrusCycleTimer = Random.Shared.NextSingle() * def.EstrusIntervalDays;
            EstrusDurationRemaining = (Random.Shared.NextSingle() < 0.35f) ? (Random.Shared.NextSingle() * def.EstrusDurationDays) : 0f;
        }
        else
        {
            EstrusCycleTimer = 0f;
            EstrusDurationRemaining = 0f;
        }

        // Inicia como jovem adulto saudável
        if (species == SpeciesCatalog.IdRat)
        {
            AgeInDays = 75.0f;
            MatingCooldown = 15.0f;
        }
        else if (species == SpeciesCatalog.IdCat)
        {
            AgeInDays = 400.0f;
            MatingCooldown = 60.0f;
        }
        else // Harpia Amazônica
        {
            AgeInDays = 2000.0f;
            MatingCooldown = 180.0f;
        }
    }
}

/// <summary>
/// Tipos de micro-abrigos naturais no bioma que impedem a captura por predadores.
/// </summary>
public enum RefugeType : byte
{
    FallenLog = 0,       // Troncos de árvores caídos
    RockCrevice = 1,     // Espaços embaixo de pedras e fendas rochosas
    DenseVegetation = 2  // Moitas de vegetação densa impenetrável
}

/// <summary>
/// Refúgio natural fixo no ecossistema (75% na floresta e 25% na várzea).
/// Concede imunidade física contra predadores terrestres e aéreos aos roedores abrigados.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct NaturalRefuge
{
    public readonly float PosX;
    public readonly float PosY;
    public readonly RefugeType Type;
    public readonly float Radius;

    public NaturalRefuge(float x, float y, RefugeType type, float radius = 2.5f)
    {
        PosX = x;
        PosY = y;
        Type = type;
        Radius = radius;
    }

    /// <summary>
    /// Gera os micro-abrigos naturais no bioma, limitados estritamente a 10% da quantidade inicial de ratos
    /// (75% posicionados na floresta e 25% na várzea).
    /// </summary>
    public static NaturalRefuge[] CreateAmazonRefuges(int initialRatCount = 180)
    {
        int count = Math.Max(1, (int)MathF.Round(initialRatCount * 0.10f)); // Limite estrito de 10% da quantidade inicial de ratos
        var refuges = new NaturalRefuge[count];
        int forestCount = (int)(count * 0.75f); // 75% na floresta densa

        for (int i = 0; i < count; i++)
        {
            bool inForest = (i < forestCount);
            float angle = Random.Shared.NextSingle() * MathF.PI * 2f;
            float radius = inForest
                ? (195.0f + Random.Shared.NextSingle() * 45.0f)  // 75% na floresta densa (R > 195m)
                : (58.0f + Random.Shared.NextSingle() * 135.0f); // 25% na várzea (R: 58m a 193m)

            float x = Math.Clamp(256f + MathF.Cos(angle) * radius, 10f, 502f);
            float y = Math.Clamp(256f + MathF.Sin(angle) * radius, 10f, 502f);
            var type = (RefugeType)Random.Shared.Next(0, 3);
            refuges[i] = new NaturalRefuge(x, y, type, 2.5f);
        }
        return refuges;
    }
}

/// <summary>
/// FASE 5: Motor de Dinâmica Populacional, Fisiologia Metabólica e Teia Trófica.
/// Processa agentes animais em lote contíguo com Resposta Funcional de Holling Tipo II/III.
/// </summary>
public static class FaunaSystem
{
    public const float StarvationDamage = 0.6f;   // Dano suave de inanição dando tempo de busca por alimento
    public const byte CatHuntingZone = 25;        // Zona de caça direta do gato: 25 células (dados reais de bote)
    public const byte CatOlfactoryRange = 90;     // Alcance de faro: 90 células (dados reais de faro felino)

    public static readonly NaturalRefuge[] AmazonRefuges = NaturalRefuge.CreateAmazonRefuges(180); // Limite de 10% dos 180 ratos iniciais (18 refúgios)

    /// <summary>
    /// Avalia se o roedor/animal está protegido dentro de sua toca maternal ou em um refúgio natural
    /// (troncos de árvores caídos, espaços embaixo de pedras ou vegetação densa que impedem predadores).
    /// </summary>
    public static bool IsProtectedInBurrowOrRefuge(in AnimalAgent animal)
    {
        if (animal.IsSafeInBurrow) return true;
        if (animal.Diet != AnimalDiet.Herbivore) return false;

        for (int r = 0; r < AmazonRefuges.Length; r++)
        {
            ref readonly var refg = ref AmazonRefuges[r];
            float dx = animal.PosX - refg.PosX;
            float dy = animal.PosY - refg.PosY;
            if ((dx * dx + dy * dy) <= (refg.Radius * refg.Radius))
            {
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Controle de histerese e dispersão das Harpias Amazônicas com base no Índice de Homeostase Ecológica:
    /// - 1ª Harpia: remove (migra) quando Homeostase <= 85%, retorna quando Homeostase >= 90%.
    /// - 2ª Harpia: remove (migra) quando Homeostase <= 75%, retorna quando Homeostase >= 80%.
    /// </summary>
    public static void UpdateHarpyHomeostasisHysteresis(Span<AnimalAgent> agents, float homeostasisPercent)
    {
        int harpyCount = 0;
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Diet == AnimalDiet.AvianApex && a.Health > 0f)
            {
                if (harpyCount == 0) // 1ª Harpia (primeira a dispersar)
                {
                    if (!a.IsMigrated && homeostasisPercent <= 85.0f)
                    {
                        a.IsMigrated = true;
                    }
                    else if (a.IsMigrated && homeostasisPercent >= 90.0f)
                    {
                        a.IsMigrated = false;
                    }
                }
                else if (harpyCount == 1) // 2ª Harpia (dispersa sob crise severa)
                {
                    if (!a.IsMigrated && homeostasisPercent <= 75.0f)
                    {
                        a.IsMigrated = true;
                    }
                    else if (a.IsMigrated && homeostasisPercent >= 80.0f)
                    {
                        a.IsMigrated = false;
                    }
                }
                harpyCount++;
            }
        }
    }

    /// <summary>
    /// Executa o tick fisiológico, a teia trófica de predação de Holling, decomposição e telemetria.
    /// </summary>
    public static void StepFauna(
        Span<AnimalAgent> agents,
        Chunk chunk,
        InfluenceMap influence,
        float dt,
        EcosystemTelemetry? telemetry = null,
        ulong currentTick = 0,
        float currentSimHour = 0f)
    {
        // 0. Censo populacional e cálculo do Índice de Homeostase Ecológica (Lotka-Volterra: razão ótima 30:1)
        int liveHerbivores = 0;
        int liveCarnivores = 0;
        for (int i = 0; i < agents.Length; i++)
        {
            ref readonly var ag = ref agents[i];
            if (ag.Health <= 0f) continue;
            if (ag.Diet == AnimalDiet.Herbivore) liveHerbivores++;
            else if (ag.Diet == AnimalDiet.Carnivore) liveCarnivores++;
        }

        float ratio = (liveCarnivores > 0) ? ((float)liveHerbivores / liveCarnivores) : 0f;
        float currentHomeostasis = 100f - MathF.Min(100f, MathF.Abs(ratio - 30.0f) * 2.8f);
        if (liveHerbivores == 0 && liveCarnivores == 0) currentHomeostasis = 0f;

        // Regra de Histerese das Harpias: 1ª sai a <=85% (volta a >=90%) | 2ª sai a <=75% (volta a >=80%)
        UpdateHarpyHomeostasisHysteresis(agents, currentHomeostasis);

        // Ciclo Circadiano Planetário (06h às 18h = Dia claro; 18h às 06h = Noite)
        float simHour = (currentSimHour > 0f) ? currentSimHour : 12.0f;
        float hourOfDay = simHour % 24f;
        bool isDayTime = (hourOfDay >= 6.0f && hourOfDay < 18.0f);

        // 1. Predadores projetam gradiente de perigo nos mapas de influência
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f || a.IsMigrated) continue;

            if (a.Diet == AnimalDiet.Carnivore)
            {
                int cellX = (int)Math.Clamp(a.PosX, 0, Chunk.Width - 1);
                int cellY = (int)Math.Clamp(a.PosY, 0, Chunk.Height - 1);
                influence.EmitDanger(cellX, cellY, 80.0f);
            }
        }

        // 2. Processa fisiologia, envelhecimento, faro, predação e reprodução
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f || a.IsMigrated) continue;

            ref readonly var speciesDef = ref SpeciesCatalog.GetSpecies(a.SpeciesId);

            // Comportamento Estritamente Diurno da Harpia Amazônica:
            // Ao cair da noite (18h às 06h), cessa a patrulha e permanece em repouso no ninho na copa
            if (a.Diet == AnimalDiet.AvianApex && !isDayTime)
            {
                if (a.HasNest)
                {
                    float dNestSq = MathF.Pow(a.NestPosX - a.PosX, 2) + MathF.Pow(a.NestPosY - a.PosY, 2);
                    if (dNestSq <= 4.0f)
                    {
                        a.State = AgentState.Resting;
                        a.PosX = a.NestPosX;
                        a.PosY = a.NestPosY;
                        a.VelocityX = 0f;
                        a.VelocityY = 0f;
                        a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + 25.0f * dt);
                        continue; // Empoleirada dormindo no ninho durante a noite
                    }
                }
            }

            // Envelhecimento biológico em dias
            a.AgeInDays += dt * 0.1f;
            if (a.AgeInDays >= a.MaxLifespanDays)
            {
                // Morte por senescência: fertiliza solo com carcaça orgânica
                DepositCarryingDebris(chunk, (int)a.PosX, (int)a.PosY, speciesDef.AdultBodyMassGrams);
                telemetry?.RecordEvent(currentTick, currentSimHour, a.SpeciesId, EcologicalEventType.DeathBySenescence, a.PosX, a.PosY);
                a.Health = 0f;
                a.State = AgentState.Dead;
                continue;
            }

            if (a.MatingCooldown > 0f)
            {
                a.MatingCooldown = MathF.Max(0f, a.MatingCooldown - dt);
            }

            // Ciclo de Estro e Sazonalidade Biológica das Fêmeas (PanTHERIA / Add-my-Pet)
            if (a.IsFemale && a.IsAdult && !a.IsPregnant)
            {
                if (a.EstrusDurationRemaining > 0f)
                {
                    // Cio ativo (janela fértil receptiva)
                    a.EstrusDurationRemaining = MathF.Max(0f, a.EstrusDurationRemaining - dt * 0.1f);
                    if (a.EstrusDurationRemaining <= 0f)
                    {
                        // Fim do cio: inicia período de interestro até o próximo ciclo
                        a.EstrusCycleTimer = speciesDef.EstrusIntervalDays;
                    }
                }
                else
                {
                    // Contagem regressiva até o próximo estro
                    a.EstrusCycleTimer = MathF.Max(0f, a.EstrusCycleTimer - dt * 0.1f);
                    if (a.EstrusCycleTimer <= 0f)
                    {
                        a.EstrusDurationRemaining = speciesDef.EstrusDurationDays;
                    }
                }
            }

            // Cooldown da arrancada anaeróbica de emboscada felina
            if (a.PounceBoostCooldown > 0f)
            {
                a.PounceBoostCooldown = MathF.Max(0f, a.PounceBoostCooldown - dt);
            }

            // Ciclo de Gestação Real (Rato: 21d; Gato: 64d)
            if (a.IsFemale && a.IsPregnant)
            {
                float gestProgress = dt * 0.1f;
                a.GestationDaysRemaining -= gestProgress;
                a.DaysPregnant += gestProgress;

                // Concede habilidade de criar tocas onde a fêmea estiver após 3 dias de gestação (inclusive na várzea/gramíneas)
                if (a.DaysPregnant >= 3.0f && !a.HasNest)
                {
                    a.HasNest = true;
                    a.NestPosX = a.PosX;
                    a.NestPosY = a.PosY;
                }

                if (a.GestationDaysRemaining <= 0f)
                {
                    // Parto: Fêmea dá à luz filhotes diretamente em sua toca segura na floresta
                    a.IsPregnant = false;
                    a.DaysPregnant = 0f;
                    byte litter = (a.LitterSize > 0) ? a.LitterSize : (byte)Random.Shared.Next(speciesDef.MinLitterSize, speciesDef.MaxLitterSize + 1);
                    a.LitterSize = 0;
                    a.MatingCooldown = speciesDef.PostPartumCooldownDays;

                    // Aloca os filhotes nos slots disponíveis do pool ECS sem garbage collection
                    int spawned = 0;
                    for (int k = 0; k < agents.Length && spawned < litter; k++)
                    {
                        if (agents[k].Health <= 0f)
                        {
                            agents[k] = new AnimalAgent(
                                id: (uint)(currentTick * 1000 + k),
                                species: a.SpeciesId,
                                diet: a.Diet,
                                x: a.HasNest ? a.NestPosX : a.PosX,
                                y: a.HasNest ? a.NestPosY : a.PosY,
                                speed: (a.SpeciesId == SpeciesCatalog.IdRat ? 2.2f : 1.8f)
                            )
                            {
                                AgeInDays = 0f,
                                MotherId = a.EntityId,
                                HasNest = a.HasNest,
                                NestPosX = a.NestPosX,
                                NestPosY = a.NestPosY,
                                Sex = (byte)(Random.Shared.NextDouble() < 0.5 ? 0 : 1),
                                Health = 100f,
                                Hunger = 20f,
                                Genome = (a.SpeciesId == SpeciesCatalog.IdRat)
                                    ? RatGenome.Recombine(in a.Genome, in a.MateGenome)
                                    : default
                            };
                            spawned++;
                        }
                    }

                    if (a.SpeciesId == SpeciesCatalog.IdRat)
                    {
                        // Roedores: estro pós-parto fértil imediato (~1 dia) se bem nutrida
                        a.EstrusDurationRemaining = 1.0f;
                    }
                    else
                    {
                        // Felinos: anestro de lactação (45-50 dias amamentando filhotes)
                        a.EstrusCycleTimer = speciesDef.PostPartumCooldownDays;
                        a.EstrusDurationRemaining = 0f;
                    }
                    telemetry?.RecordEvent(currentTick, currentSimHour, a.SpeciesId, EcologicalEventType.Birth, a.PosX, a.PosY);
                }
            }

            // =========================================================================
            // CICLO DE VIDA EFÊMERO DE TOCAS E COVIS (REGRA MATERNAL)
            // As tocas só existem enquanto as mães estiverem prenhas e até seus filhotes atingirem a maturidade
            // =========================================================================
            if (a.MotherId > 0 && a.IsAdult && a.HasNest)
            {
                // Filhote atinge a idade adulta: deixa o ninho/toca materna
                a.HasNest = false;
            }

            if (a.IsFemale && a.HasNest && !a.IsPregnant)
            {
                // Verifica se a mãe ainda possui algum filhote imaturo vivo sob seus cuidados
                bool hasImmaturePups = false;
                for (int j = 0; j < agents.Length; j++)
                {
                    if (agents[j].Health > 0f && agents[j].MotherId == a.EntityId && !agents[j].IsAdult)
                    {
                        hasImmaturePups = true;
                        break;
                    }
                }
                if (!hasImmaturePups)
                {
                    // Ninhada atingiu a maturidade reprodutiva (ou pereceu): toca na floresta é desfeita!
                    a.HasNest = false;
                }
            }

            // Gasto Metabólico Basal (BMR derivado da Lei de Kleiber na Tabela 1 - PanTHERIA)
            // Roedores queimam ~0.08/hora; Felinos de 4kg queimam ~0.025/hora (8 a 10 dias de autonomia calórica por presa)
            float bmrHourRate = (speciesDef.BasalMetabolicRateWatts / speciesDef.MaxEnergyReserveJoules) * (a.Diet == AnimalDiet.Herbivore ? 0.08f : 0.025f);
            a.Hunger = MathF.Min(100f, a.Hunger + bmrHourRate * dt);
            a.Energy = MathF.Max(0f, a.Energy - (speciesDef.MovementCostPerMeter * dt));

            // Dano por inanição severa
            if (a.Hunger >= 90f)
            {
                a.Health = MathF.Max(0f, a.Health - StarvationDamage * dt);
                if (a.Health <= 0f)
                {
                    DepositCarryingDebris(chunk, (int)a.PosX, (int)a.PosY, speciesDef.AdultBodyMassGrams);
                    telemetry?.RecordEvent(currentTick, currentSimHour, a.SpeciesId, EcologicalEventType.DeathByStarvation, a.PosX, a.PosY);
                    a.State = AgentState.Dead;
                    continue;
                }
            }

            int curCellX = (int)Math.Clamp(a.PosX, 0, Chunk.Width - 1);
            int curCellY = (int)Math.Clamp(a.PosY, 0, Chunk.Height - 1);
            int curCellIdx = Chunk.GetIndex(curCellX, curCellY);

            // =========================================================================
            // HERBIVORIA (RATO ALIMENTANDO-SE DE GRÃOS DE VÁRZEA OU BIOMASSA COMUM)
            // =========================================================================
            if (a.Diet == AnimalDiet.Herbivore && a.Hunger > 5f)
            {
                // 1. Prioridade Absoluta: Consumo de Grãos Amazônicos de Várzea (Oryza glumaepatula)
                if (chunk.Grains[curCellIdx] > 0.5f)
                {
                    float grainBite = MathF.Min(chunk.Grains[curCellIdx], (25.0f / 24.0f) * dt);
                    chunk.Grains[curCellIdx] -= grainBite;
                    // Grão altamente calórico: 4x rendimento calórico e saciedade rápida (Tabela 3)
                    a.Hunger = MathF.Max(0f, a.Hunger - grainBite * 2.2f);
                    a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + grainBite * 8.0f);
                }
                // 2. Consumo de Biomassa Vegetal Comum (Saciedade reduzida para 10% para forçar forrageamento de grãos)
                else if (chunk.Biomass[curCellIdx] > 0.5f)
                {
                    int ratsInCell = 1;
                    for (int j = 0; j < agents.Length; j++)
                    {
                        if (i == j) continue;
                        ref readonly var other = ref agents[j];
                        if (other.Diet == AnimalDiet.Herbivore && other.Health > 0f &&
                            (int)other.PosX == curCellX && (int)other.PosY == curCellY)
                        {
                            ratsInCell++;
                        }
                    }

                    float bitePerDay = 33.33f / ratsInCell;
                    float bite = MathF.Min(chunk.Biomass[curCellIdx] / ratsInCell, (bitePerDay / 24.0f) * dt);
                    chunk.Biomass[curCellIdx] -= bite;
                    a.Hunger = MathF.Max(0f, a.Hunger - bite * 0.35f); // 10% da saciedade anterior
                    a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + bite * 1.0f);
                }
            }

            // =========================================================================
            // ACASALAMENTO FÍSICO E TRANSMISSÃO GENÉTICA
            // =========================================================================
            if (a.IsReadyToMate)
            {
                for (int j = 0; j < agents.Length; j++)
                {
                    if (i == j) continue;
                    ref var partner = ref agents[j];
                    if (partner.SpeciesId == a.SpeciesId && partner.Health > 0f && partner.Sex != a.Sex && partner.IsReadyToMate)
                    {
                        float distSq = MathF.Pow(partner.PosX - a.PosX, 2) + MathF.Pow(partner.PosY - a.PosY, 2);
                        if (distSq <= 2.25f) // Contato reprodutivo (1.5 células)
                        {
                            ref var female = ref (a.IsFemale ? ref a : ref partner);
                            ref var male = ref (a.IsMale ? ref a : ref partner);

                            female.IsPregnant = true;
                            female.DaysPregnant = 0f;
                            female.GestationDaysRemaining = speciesDef.GestationPeriodDays + ((Random.Shared.NextSingle() - 0.5f) * 2.0f);
                            female.LitterSize = (byte)Random.Shared.Next(speciesDef.MinLitterSize, speciesDef.MaxLitterSize + 1);
                            female.MateGenome = male.Genome; // Retém genoma paterno para recombinação mendeliana no parto
                            female.MatingCooldown = female.GestationDaysRemaining + speciesDef.PostPartumCooldownDays;
                            male.MatingCooldown = 15.0f;
                            break;
                        }
                    }
                }
            }

            // =========================================================================
            // PREDAÇÃO COM RESPOSTA FUNCIONAL DE HOLLING TIPO II / III (GATO PREDA RATO)
            // =========================================================================
            if (a.Diet == AnimalDiet.Carnivore)
            {
                for (int j = 0; j < agents.Length; j++)
                {
                    if (i == j) continue;
                    ref var prey = ref agents[j];
                    if (prey.Diet != AnimalDiet.Herbivore || prey.Health <= 0f || IsProtectedInBurrowOrRefuge(in prey)) continue;

                    float distSq = MathF.Pow(prey.PosX - a.PosX, 2) + MathF.Pow(prey.PosY - a.PosY, 2);
                    if (distSq <= 1.44f) // Alcance físico de bote (1.2 células)
                    {
                        // Verifica se pode predar: por diversão se tiver < 2 caças no dia, ou por fome real
                        bool willAttack = (a.DailyFunKills < 2) || (a.Hunger > 25.0f);
                        if (willAttack)
                        {
                            if (SpeciesCatalog.TryGetInteraction(a.SpeciesId, prey.SpeciesId, out var interaction))
                            {
                                // Resposta de Holling com Proteção Adaptativa do Genoma:
                                // Em vegetação densa, presas com alta afinidade genética de refúgio se camuflam com maestria
                                float refugeFactor = 1.0f;
                                if (chunk.Biomass[curCellIdx] > 35.0f)
                                {
                                    refugeFactor = MathF.Max(0.35f, 0.70f - (prey.Genome.RefugeAffinity * 0.35f));
                                }
                                float effectiveSuccessRate = interaction.BaseCaptureSuccessRate * refugeFactor;

                                if (Random.Shared.NextDouble() < effectiveSuccessRate)
                                {
                                    // Predação bem sucedida!
                                    prey.Health = 0f;
                                    prey.State = AgentState.Dead;
                                    telemetry?.RecordEvent(currentTick, currentSimHour, prey.SpeciesId, EcologicalEventType.DeathByPredation, prey.PosX, prey.PosY);

                                    // Se caçou por fome, absorve nutrientes e sacia-se
                                    if (a.Hunger > 20.0f)
                                    {
                                        a.Hunger = MathF.Max(0f, a.Hunger - interaction.SatietyBoost);
                                        a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + interaction.NutritionalYieldJoules);
                                    }
                                    else
                                    {
                                        a.DailyFunKills++;
                                    }

                                    // Carcaça restante fertiliza o solo com detrito orgânico
                                    DepositCarryingDebris(chunk, (int)prey.PosX, (int)prey.PosY, 250f);
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================================
            // PREDAÇÃO AÉREA DE TOPO (HARPIA AMAZÔNICA / GAVIÃO-REAL - TABELA 3)
            // =========================================================================
            if (a.Diet == AnimalDiet.AvianApex)
            {
                // Harpias possuem comportamento estritamente diurno: não caçam presas à noite
                if (!isDayTime)
                {
                    a.State = AgentState.Resting;
                    continue;
                }

                // A Harpia patrulha o espaço aéreo e mergulha sobre presas terrestres desprotegidas
                for (int j = 0; j < agents.Length; j++)
                {
                    if (i == j) continue;
                    ref var prey = ref agents[j];
                    if (prey.Health <= 0f) continue;
                    // IMUNIDADE: Presa dentro da toca ou abrigada em refúgio natural é inatingível!
                    if (IsProtectedInBurrowOrRefuge(in prey)) continue;

                    if (prey.Diet != AnimalDiet.Herbivore && prey.Diet != AnimalDiet.Carnivore) continue;

                    float distSq = MathF.Pow(prey.PosX - a.PosX, 2) + MathF.Pow(prey.PosY - a.PosY, 2);
                    if (distSq <= 6.25f && a.Hunger > 15.0f) // Alcance de rasante de impacto (2.5 células)
                    {
                        if (SpeciesCatalog.TryGetInteraction(a.SpeciesId, prey.SpeciesId, out var interaction))
                        {
                            // O dossel da floresta densa oferece refúgio vegetal (30% de eficácia); em várzea/gramíneas, rasante letal
                            float canopyCover = chunk.Biomass[curCellIdx] > 45.0f ? 0.35f : 1.0f;
                            float captureRate = interaction.BaseCaptureSuccessRate * canopyCover;

                            if (Random.Shared.NextDouble() < captureRate)
                            {
                                prey.Health = 0f;
                                prey.State = AgentState.Dead;
                                telemetry?.RecordEvent(currentTick, currentSimHour, prey.SpeciesId, EcologicalEventType.DeathByPredation, prey.PosX, prey.PosY);

                                a.Hunger = MathF.Max(0f, a.Hunger - interaction.SatietyBoost);
                                a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + interaction.NutritionalYieldJoules);
                                DepositCarryingDebris(chunk, (int)prey.PosX, (int)prey.PosY, (prey.SpeciesId == SpeciesCatalog.IdRat ? 250f : 4200f));
                                break;
                            }
                        }
                    }
                }
            }

            // Tomada de Decisão com faro olfativo, ciclo circadiano e fuga de alagamento
            float bestScore = EvaluateCellScore(curCellX, curCellY, in a, influence, agents, i, isDayTime);
            int targetX = curCellX;
            int targetY = curCellY;

            for (int dy = -1; dy <= 1; dy++)
            {
                int ny = curCellY + dy;
                if (ny < 0 || ny >= Chunk.Height) continue;

                for (int dx = -1; dx <= 1; dx++)
                {
                    if (dx == 0 && dy == 0) continue;
                    int nx = curCellX + dx;
                    if (nx < 0 || nx >= Chunk.Width) continue;

                    float score = EvaluateCellScore(nx, ny, in a, influence, agents, i, isDayTime);
                    if (score > bestScore)
                    {
                        bestScore = score;
                        targetX = nx;
                        targetY = ny;
                    }
                }
            }

            // PERAMBULAÇÃO EXPLORATÓRIA ATIVA (LÉVY FORAGING FLIGHT):
            // Se o rato consumiu o pasto local e não detectou comida nas 8 células vizinhas,
            // NUNCA FICA PARADO: caminha com persistência angular até descobrir novos pastos!
            if (targetX == curCellX && targetY == curCellY && a.Diet == AnimalDiet.Herbivore && chunk.Biomass[curCellIdx] < 5.0f)
            {
                float angle = MathF.Atan2(a.VelocityY, a.VelocityX + 0.0001f) + ((Random.Shared.NextSingle() - 0.5f) * 0.9f);
                targetX = (int)Math.Clamp(a.PosX + MathF.Cos(angle) * 4.0f, 0, Chunk.Width - 1);
                targetY = (int)Math.Clamp(a.PosY + MathF.Sin(angle) * 4.0f, 0, Chunk.Height - 1);
            }

            // Movimentação suave (animais atravessam água a 70% da velocidade, mas não permanecem nela)
            float dirX = (targetX + 0.5f) - a.PosX;
            float dirY = (targetY + 0.5f) - a.PosY;
            float dist = MathF.Sqrt(dirX * dirX + dirY * dirY);

            if (dist > 0.05f)
            {
                float speedModifier = (chunk.SurfaceWater[curCellIdx] > 0.2f || chunk.LakeWater[curCellIdx] > 0.2f) ? 0.7f : 1.0f;

                // Adaptação Dinâmica: Arrancada Anaeróbica (SprintBurst) e Aprendizado de Fuga
                if (a.Diet == AnimalDiet.Herbivore)
                {
                    bool underImminentPursuit = false;
                    for (int j = 0; j < agents.Length; j++)
                    {
                        if (i == j) continue;
                        ref readonly var cat = ref agents[j];
                        if (cat.Diet == AnimalDiet.Carnivore && cat.Health > 0f)
                        {
                            float dSq = MathF.Pow(cat.PosX - a.PosX, 2) + MathF.Pow(cat.PosY - a.PosY, 2);
                            if (dSq <= 16.0f) // Predador colado (< 4.0 células)
                            {
                                underImminentPursuit = true;
                                break;
                            }
                        }
                    }

                    if (underImminentPursuit)
                    {
                        speedModifier *= a.Genome.SprintBurst;
                        // Sobreviver a encontros imediatos aumenta a vigilância fenotípica (aprendizado epigenético)
                        a.Genome.EpigeneticBonus = MathF.Min(4.0f, a.Genome.EpigeneticBonus + 0.12f * dt);
                    }
                }
                else if (a.Diet == AnimalDiet.Carnivore)
                {
                    // Arrancada Explosiva de Emboscada (Pounce Burst): salta para ~3.78 cél/s ao encurralar presas (< 4.5 células)
                    bool nearPrey = false;
                    for (int j = 0; j < agents.Length; j++)
                    {
                        if (i == j) continue;
                        ref readonly var prey = ref agents[j];
                        if (prey.Diet == AnimalDiet.Herbivore && prey.Health > 0f)
                        {
                            float dSq = MathF.Pow(prey.PosX - a.PosX, 2) + MathF.Pow(prey.PosY - a.PosY, 2);
                            if (dSq <= 20.25f) // < 4.5 células
                            {
                                nearPrey = true;
                                break;
                            }
                        }
                    }

                    if (nearPrey && (a.DailyFunKills < 2 || a.Hunger > 25.0f))
                    {
                        speedModifier *= 1.35f; // Pounce Burst supera o sprint da presa em campo aberto
                    }
                }

                float stepDist = a.MoveSpeed * speedModifier * dt;
                float moveX = (dirX / dist) * MathF.Min(dist, stepDist);
                float moveY = (dirY / dist) * MathF.Min(dist, stepDist);

                a.PosX = Math.Clamp(a.PosX + moveX, 0f, Chunk.Width - 0.01f);
                a.PosY = Math.Clamp(a.PosY + moveY, 0f, Chunk.Height - 0.01f);
                a.VelocityX = moveX / dt;
                a.VelocityY = moveY / dt;
            }
        }
    }

    /// <summary>
    /// Deposição de carcaça e matéria orgânica no solo (Tabela 4), impulsionando a regeneração da biomassa vegetal.
    /// </summary>
    private static void DepositCarryingDebris(Chunk chunk, int centerX, int centerY, float massGrams)
    {
        float detritusContribution = massGrams * 0.04f; // Conversão em unidades de fertilidade

        for (int dy = -1; dy <= 1; dy++)
        {
            int ny = centerY + dy;
            if (ny < 0 || ny >= Chunk.Height) continue;

            for (int dx = -1; dx <= 1; dx++)
            {
                int nx = centerX + dx;
                if (nx < 0 || nx >= Chunk.Width) continue;

                int idx = Chunk.GetIndex(nx, ny);
                chunk.OrganicDetritus[idx] += detritusContribution * 0.33f;
                chunk.Biomass[idx] = MathF.Min(100f, chunk.Biomass[idx] + 25.0f);
            }
        }
    }

    private static float EvaluateCellScore(
        int x,
        int y,
        in AnimalAgent agent,
        InfluenceMap influence,
        ReadOnlySpan<AnimalAgent> allAgents,
        int selfIdx,
        bool isDayTime = true)
    {
        int idx = Chunk.GetIndex(x, y);
        float food = influence.FoodGradient[idx];
        float danger = influence.DangerGradient[idx];
        float water = influence.WaterGradient[idx];

        // Repulsão severa contra solo alagado / inundado
        float floodPenalty = (water > 0.1f) ? -35.0f : 0f;

        if (agent.Diet == AnimalDiet.Herbivore)
        {
            // Vigilância ponderada pelo Genoma Evoluído + Experiência Epigenética
            float effectiveAlert = agent.Genome.AlertRadius + agent.Genome.EpigeneticBonus;
            float fearWeight = 8.0f * (effectiveAlert / 12.0f);
            float foodWeight = (agent.Hunger / 100.0f) * 4.0f;

            // Busca Ativa de Refúgio (Holling, Toca Segura e Refúgios Naturais: troncos, pedras, moitas)
            float refugeBonus = 0f;
            if (danger > 8.0f)
            {
                refugeBonus = (food * 4.0f) * agent.Genome.RefugeAffinity;
                float bestRefugeDist = float.MaxValue;
                if (agent.HasNest)
                {
                    bestRefugeDist = MathF.Sqrt(MathF.Pow(agent.NestPosX - x, 2) + MathF.Pow(agent.NestPosY - y, 2));
                }
                for (int r = 0; r < AmazonRefuges.Length; r++)
                {
                    ref readonly var refg = ref AmazonRefuges[r];
                    float d = MathF.Sqrt(MathF.Pow(refg.PosX - x, 2) + MathF.Pow(refg.PosY - y, 2));
                    if (d < bestRefugeDist) bestRefugeDist = d;
                }
                if (bestRefugeDist < 200.0f)
                {
                    refugeBonus += (200.0f - bestRefugeDist) * 0.25f * 4.5f;
                }
            }

            float score = (food * foodWeight) - (danger * fearWeight) + refugeBonus + floodPenalty;

            // Busca de parceiro fértil durante o ciclo de estro (feromônios urinários e USVs até 50 células)
            if (agent.IsReadyToMate)
            {
                for (int i = 0; i < allAgents.Length; i++)
                {
                    if (i == selfIdx) continue;
                    ref readonly var other = ref allAgents[i];
                    if (other.SpeciesId == agent.SpeciesId && other.Sex != agent.Sex)
                    {
                        bool isPairReceptive = (agent.IsFemale && agent.IsInEstrus && other.IsMale && other.Hunger < 50f) ||
                                               (agent.IsMale && other.IsFemale && other.IsInEstrus && agent.Hunger < 50f);

                        if (isPairReceptive)
                        {
                            float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                            if (d <= 50.0f)
                            {
                                score += MathF.Max(0f, (50.0f - d) * 3.5f);
                            }
                        }
                    }
                }
            }

            return score;
        }
        else if (agent.Diet == AnimalDiet.Carnivore) // Carnívoro / Gato
        {
            float score = floodPenalty;

            // 1. Zona de caça (25 células): predação se tiver < 2 caças no dia ou com fome (ignora presas imunes em tocas/refúgios)
            // 2. Faro químico (até 90 células): persegue se estiver com fome real
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Herbivore && other.Health > 0f && !IsProtectedInBurrowOrRefuge(in other))
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));

                    if (d <= CatHuntingZone)
                    {
                        if (agent.DailyFunKills < 2 || agent.Hunger > 30.0f)
                        {
                            score += (CatHuntingZone - d) * 4.5f;
                        }
                    }
                    else if (d <= CatOlfactoryRange && agent.Hunger > 30.0f)
                    {
                        float hungerFactor = agent.Hunger / 100.0f;
                        score += (CatOlfactoryRange - d) * 1.5f * hungerFactor;
                    }
                }
            }

            // Comunicação e Chamado Acústico / Feromônio de Acasalamento (até 100 células)
            // Gatas em cio emitem chamados que suprimem a territorialidade agressiva dos machos
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Carnivore && other.Health > 0f)
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));

                    if (other.Sex != agent.Sex)
                    {
                        bool isPairReceptive = (agent.IsFemale && agent.IsInEstrus && other.IsMale && other.Hunger < 55f) ||
                                               (agent.IsMale && other.IsFemale && other.IsInEstrus && agent.Hunger < 55f);

                        if (isPairReceptive && d <= 100.0f)
                        {
                            // Forte atração reprodutiva acústica/química
                            score += (100.0f - d) * 3.8f;
                        }
                    }
                    else if (d <= 10.0f)
                    {
                        // Repulsão territorial quando do mesmo sexo ou sem fêmea receptiva
                        score -= (10.0f - d) * 3.5f;
                    }
                }
            }

            return score;
        }
        else // AnimalDiet.AvianApex (Harpia Amazônica)
        {
            if (!isDayTime)
            {
                // Comportamento Estritamente Diurno: à noite voa diretamente para o ninho na copa
                if (agent.HasNest)
                {
                    float dNest = MathF.Sqrt(MathF.Pow(agent.NestPosX - x, 2) + MathF.Pow(agent.NestPosY - y, 2));
                    return (300.0f - dNest) * 8.0f;
                }
                return 0f;
            }

            // Visão aérea telescópica de 150 células com atração sobre presas terrestres desprotegidas durante o dia
            float score = 0f;
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Health > 0f && (other.Diet == AnimalDiet.Herbivore || other.Diet == AnimalDiet.Carnivore) && !IsProtectedInBurrowOrRefuge(in other))
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                    if (d <= 150.0f)
                    {
                        score += (150.0f - d) * 2.2f * (agent.Hunger / 100.0f);
                    }
                }
            }

            return score;
        }
    }
}
