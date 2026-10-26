using System;
using System.Runtime.InteropServices;
using SimCore.SpatialGrid;

namespace SimCore.Biosphere;

public enum AnimalDiet : byte
{
    Herbivore = 0,
    Carnivore = 1,
    Omnivore  = 2
}

public enum AnimalSpecies : ushort
{
    Rat = 1, // Herbívoro: Vida ~2.5 anos, busca biomassa em até 5 células, alta taxa metabólica
    Cat = 10 // Carnívoro: Vida ~14 anos, territorial, busca presas em até 15 células, alta saciedade
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

    // Posição contínua e Cinética no Mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    public bool IsFemale => Sex == 0;
    public bool IsMale => Sex == 1;
    public bool IsAdult => AgeInDays >= (MaxLifespanDays * 0.08f);
    public bool IsReadyToMate => IsAdult && Hunger < 35.0f && MatingCooldown <= 0.0f && Health > 50.0f && (!IsFemale || !IsPregnant);

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y, float speed = 2.0f, byte? specificSex = null)
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
        IsPregnant = false;
        GestationDaysRemaining = 0f;
        LitterSize = 0;

        // Puxa os parâmetros biológicos reais diretamente do "DNA" da Espécie (Tabela 1)
        ref readonly var def = ref SpeciesCatalog.GetSpecies(species);
        Energy = def.MaxEnergyReserveJoules * 0.8f;
        MoveSpeed = speed;
        MaxLifespanDays = def.MaxLifespanDays;
        SensoryRadius = def.VisualSensoryRadius;

        // Proporção sexual natural da espécie
        int femaleChance = (int)(def.FemaleRatioNatural * 100.0f);
        Sex = specificSex ?? (byte)(Random.Shared.Next(100) < femaleChance ? 0 : 1);

        // Inicia como jovem adulto saudável
        if (species == SpeciesCatalog.IdRat)
        {
            AgeInDays = 75.0f;
            MatingCooldown = 15.0f;
        }
        else // Gato
        {
            AgeInDays = 400.0f;
            MatingCooldown = 60.0f;
        }
    }
}

/// <summary>
/// FASE 5: Motor de Dinâmica Populacional, Fisiologia Metabólica e Teia Trófica.
/// Processa agentes animais em lote contíguo com Resposta Funcional de Holling Tipo II/III.
/// </summary>
public static class FaunaSystem
{
    public const float StarvationDamage = 0.6f;   // Dano suave de inanição dando tempo de busca por alimento
    public const byte CatHuntingZone = 15;        // Zona de caça direta do gato: 15 células (preda por diversão)
    public const byte CatOlfactoryRange = 45;     // Alcance de faro: 3x a zona de caça (45 células)

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
        // 1. Predadores projetam gradiente de perigo nos mapas de influência
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f) continue;

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
            if (a.Health <= 0f) continue;

            ref readonly var speciesDef = ref SpeciesCatalog.GetSpecies(a.SpeciesId);

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

            // Ciclo de Gestação Real (Rato: 21d; Gato: 64d)
            if (a.IsFemale && a.IsPregnant)
            {
                a.GestationDaysRemaining -= dt * 0.1f;
                if (a.GestationDaysRemaining <= 0f)
                {
                    // Parto: Fêmea dá à luz filhotes e entra em período de estro pós-parto
                    a.IsPregnant = false;
                    a.LitterSize = 0;
                    a.MatingCooldown = speciesDef.PostPartumCooldownDays;
                    telemetry?.RecordEvent(currentTick, currentSimHour, a.SpeciesId, EcologicalEventType.Birth, a.PosX, a.PosY);
                }
            }

            // Gasto Metabólico Basal (BMR derivado da Lei de Kleiber na Tabela 1)
            float bmrHourRate = (speciesDef.BasalMetabolicRateWatts / speciesDef.MaxEnergyReserveJoules) * 0.25f;
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
            // HERBIVORIA (RATO ALIMENTANDO-SE DA BIOMASSA VEGETAL - TABELA 3)
            // =========================================================================
            if (a.Diet == AnimalDiet.Herbivore && a.Hunger > 5f && chunk.Biomass[curCellIdx] > 0.5f)
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

                // 1 célula com 100 de biomassa alimenta 1 rato por 3 dias
                float bitePerDay = 33.33f / ratsInCell;
                float bite = MathF.Min(chunk.Biomass[curCellIdx] / ratsInCell, (bitePerDay / 24.0f) * dt);
                chunk.Biomass[curCellIdx] -= bite;
                a.Hunger = MathF.Max(0f, a.Hunger - bite * 3.5f);
                a.Energy = MathF.Min(speciesDef.MaxEnergyReserveJoules, a.Energy + bite * 10.0f);
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
                    if (prey.Diet != AnimalDiet.Herbivore || prey.Health <= 0f) continue;

                    float distSq = MathF.Pow(prey.PosX - a.PosX, 2) + MathF.Pow(prey.PosY - a.PosY, 2);
                    if (distSq <= 1.2f) // Alcance físico de contato
                    {
                        // Verifica se pode predar: por diversão se tiver < 2 caças no dia, ou por fome real
                        bool willAttack = (a.DailyFunKills < 2) || (a.Hunger > 25.0f);
                        if (willAttack)
                        {
                            if (SpeciesCatalog.TryGetInteraction(a.SpeciesId, prey.SpeciesId, out var interaction))
                            {
                                // Resposta de Holling: em locais de mata densa, presas encontram refúgio ecológico
                                float refugeFactor = (chunk.Biomass[curCellIdx] > 40.0f) ? 0.65f : 1.0f;
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

            // Tomada de Decisão com faro olfativo e fuga de alagamento
            float bestScore = EvaluateCellScore(curCellX, curCellY, in a, influence, agents, i);
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

                    float score = EvaluateCellScore(nx, ny, in a, influence, agents, i);
                    if (score > bestScore)
                    {
                        bestScore = score;
                        targetX = nx;
                        targetY = ny;
                    }
                }
            }

            // Movimentação suave (animais atravessam água a 70% da velocidade, mas não permanecem nela)
            float dirX = (targetX + 0.5f) - a.PosX;
            float dirY = (targetY + 0.5f) - a.PosY;
            float dist = MathF.Sqrt(dirX * dirX + dirY * dirY);

            if (dist > 0.05f)
            {
                float speedModifier = (chunk.SurfaceWater[curCellIdx] > 0.2f || chunk.LakeWater[curCellIdx] > 0.2f) ? 0.7f : 1.0f;
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
        int selfIdx)
    {
        int idx = Chunk.GetIndex(x, y);
        float food = influence.FoodGradient[idx];
        float danger = influence.DangerGradient[idx];
        float water = influence.WaterGradient[idx];

        // Repulsão severa contra solo alagado / inundado
        float floodPenalty = (water > 0.1f) ? -35.0f : 0f;

        if (agent.Diet == AnimalDiet.Herbivore)
        {
            float fearWeight = 8.0f;
            float foodWeight = (agent.Hunger / 100.0f) * 4.0f;
            float score = (food * foodWeight) - (danger * fearWeight) + floodPenalty;

            // Busca de parceiro fértil para acasalamento
            if (agent.IsReadyToMate)
            {
                for (int i = 0; i < allAgents.Length; i++)
                {
                    if (i == selfIdx) continue;
                    ref readonly var other = ref allAgents[i];
                    if (other.SpeciesId == agent.SpeciesId && other.Sex != agent.Sex && other.IsReadyToMate)
                    {
                        float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                        if (d <= agent.SensoryRadius)
                        {
                            score += MathF.Max(0f, (agent.SensoryRadius - d) * 3.0f);
                        }
                    }
                }
            }

            return score;
        }
        else // Carnívoro / Gato
        {
            float score = floodPenalty;

            // 1. Zona de caça (15 células): predação se tiver < 2 caças no dia ou com fome
            // 2. Faro químico (até 45 células): persegue se estiver com fome real
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Herbivore && other.Health > 0f)
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

            // Territorialidade felina
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Carnivore && other.Health > 0f)
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                    if (d <= 10.0f)
                    {
                        if (agent.IsReadyToMate && other.IsReadyToMate && other.Sex != agent.Sex)
                        {
                            score += (15.0f - d) * 2.5f;
                        }
                        else
                        {
                            score -= (10.0f - d) * 4.0f;
                        }
                    }
                }
            }

            return score;
        }
    }
}
