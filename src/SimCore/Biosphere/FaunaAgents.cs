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

/// <summary>
/// FASE 5: Componente de agente animal para arquitetura ECS.
/// Struct pura sem referências heap para alocação contígua em memória (Zero GC).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct AnimalAgent
{
    public uint EntityId;
    public ushort SpeciesId;
    public AnimalDiet Diet;
    public byte Age;             // Idade em escala simplificada (anos)

    // Estado fisiológico
    public float Health;         // 0.0 (Morto) a 100.0 (Cheio de vida)
    public float Hunger;         // 0.0 (Saciado) a 100.0 (Faminto)
    public float Thirst;         // 0.0 (Hidratado) a 100.0 (Desidratado)
    public float Energy;         // 0.0 a 100.0
    public float MoveSpeed;      // Células por segundo (ex: 2.0f)

    // Ciclo Biológico Realista (Rato vs Gato)
    public float AgeInDays;      // Idade acumulada em dias de simulação
    public float MaxLifespanDays;// Expectativa máxima de vida (Rato: ~900 dias; Gato: ~5100 dias)
    public float MatingCooldown; // Tempo até poder acasalar novamente
    public byte SensoryRadius;   // Raio sensorial: 5 para ratos, 15 para gatos
    public byte DailyFunKills;   // Caças lúdicas no dia (gato perde o interesse após a 2ª)
    public byte Sex;             // 0 = Fêmea, 1 = Macho (proporção natural da espécie)
    public bool IsPregnant;      // Fêmea em período de gestação
    public float GestationDaysRemaining; // Dias de gestação restantes (Rato: ~21d; Gato: ~64d)
    public byte LitterSize;      // Média real de filhotes (Rato: 6 a 10; Gato: 3 a 5)

    // Posição contínua no mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    public bool IsFemale => Sex == 0;
    public bool IsMale => Sex == 1;
    public bool IsAdult => AgeInDays >= (MaxLifespanDays * 0.08f); // Jovem adulto a partir de ~8% da vida
    public bool IsReadyToMate => IsAdult && Hunger < 35.0f && MatingCooldown <= 0.0f && Health > 50.0f && (!IsFemale || !IsPregnant);

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y, float speed = 2.0f, byte? specificSex = null)
    {
        EntityId = id;
        SpeciesId = species;
        Diet = diet;
        Health = 100f;
        Hunger = 20f;
        Thirst = 0f;
        Energy = 100f;
        MoveSpeed = speed;
        DailyFunKills = 0;
        PosX = x;
        PosY = y;
        VelocityX = 0f;
        VelocityY = 0f;
        IsPregnant = false;
        GestationDaysRemaining = 0f;
        LitterSize = 0;

        // Configuração Biológica baseada em tempos reais
        if (diet == AnimalDiet.Herbivore || species == (ushort)AnimalSpecies.Rat)
        {
            // RATO: Expectativa de vida ~2.5 anos (~912 dias). Adulto aos ~60 dias.
            // Proporção sexual real: 50% machos, 50% fêmeas (1:1)
            Sex = specificSex ?? (byte)(Random.Shared.Next(100) < 50 ? 1 : 0);
            MaxLifespanDays = 912.5f;
            AgeInDays = 75.0f; // Inicia jovem adulto
            Age = 1;
            SensoryRadius = 5; // Herbívoros procuram comida em até 5 células
            MatingCooldown = 15.0f;
        }
        else
        {
            // GATO: Expectativa de vida ~14 anos (~5110 dias). Adulto aos ~210 dias.
            // Proporção sexual real: ~51% machos, 49% fêmeas
            Sex = specificSex ?? (byte)(Random.Shared.Next(100) < 51 ? 1 : 0);
            MaxLifespanDays = 5110.0f;
            AgeInDays = 400.0f; // Inicia jovem adulto
            Age = 1;
            SensoryRadius = 15; // Predadores procuram em até 15 células
            MatingCooldown = 60.0f;
        }
    }
}

/// <summary>
/// FASE 5: Sistema de Comportamento e Movimentação por Gradiente de Influência e Ciclo Biológico Real.
/// Processa agentes animais em lote contíguo (Span).
/// </summary>
public static class FaunaSystem
{
    // Taxas de metabolismo calibradas para estabilidade ecológica e saciedade realista
    public const float RatHungerRate = 0.20f;     // Rato: queima saciedade moderadamente, alimenta-se com frequência
    public const float CatHungerRate = 0.05f;     // Gato: queima lenta de carnívoro, alta saciedade prolongada por presa
    public const float StarvationDamage = 0.6f;   // Dano suave de inanição dando tempo de forrageamento

    public const byte CatHuntingZone = 15;        // Zona de caça e visão direta do gato: 15 células (preda por diversão)
    public const byte CatOlfactoryRange = 45;     // Capacidade de farejar o cheiro do rato: 3x a zona de caça (45 células)

    /// <summary>
    /// Executa o tick fisiológico, tomada de decisão, caça por diversão/faro e reprodução.
    /// </summary>
    public static void StepFauna(
        Span<AnimalAgent> agents,
        Chunk chunk,
        InfluenceMap influence,
        float dt)
    {
        // 1. Predadores emitem perigo nos mapas de influência
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

        // 2. Processa fisiologia, alimentação, faro e movimento
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f) continue;

            // Envelhecimento biológico (tempo em dias)
            a.AgeInDays += dt * 0.1f;
            if (a.AgeInDays >= a.MaxLifespanDays)
            {
                // Morte por senescência: fertiliza biomassa no solo
                ApplyDeathDecomposition(chunk, (int)a.PosX, (int)a.PosY);
                a.Health = 0f;
                continue;
            }

            if (a.MatingCooldown > 0f)
            {
                a.MatingCooldown = MathF.Max(0f, a.MatingCooldown - dt);
            }

            // Gestação biológica real (Rato: 21d, Ninhada: 6-10; Gato: 64d, Ninhada: 3-5)
            if (a.IsFemale && a.IsPregnant)
            {
                a.GestationDaysRemaining -= dt * 0.1f;
                if (a.GestationDaysRemaining <= 0f)
                {
                    // Parto realizado: entra em período de amamentação/recuperação pós-parto
                    a.IsPregnant = false;
                    a.LitterSize = 0;
                    a.MatingCooldown = (a.Diet == AnimalDiet.Herbivore) ? 18.0f : 50.0f;
                }
            }

            // Metabolismo e Saciedade realista
            float hungerRate = (a.Diet == AnimalDiet.Herbivore) ? RatHungerRate : CatHungerRate;
            a.Hunger = MathF.Min(100f, a.Hunger + hungerRate * dt);

            if (a.Hunger >= 90f)
            {
                a.Health = MathF.Max(0f, a.Health - StarvationDamage * dt);
                if (a.Health <= 0f)
                {
                    ApplyDeathDecomposition(chunk, (int)a.PosX, (int)a.PosY);
                    continue;
                }
            }

            int curCellX = (int)Math.Clamp(a.PosX, 0, Chunk.Width - 1);
            int curCellY = (int)Math.Clamp(a.PosY, 0, Chunk.Height - 1);
            int curCellIdx = Chunk.GetIndex(curCellX, curCellY);

            // Herbívoro alimentando-se: 1 célula cheia alimenta 1 rato por 3 dias.
            // Se houver mais ratos na mesma célula, dividem a biomassa disponível.
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

                // Taxa diária de 1 rato: 100 biomassa / 3 dias = 33.33/dia = ~1.388 por hora de simulação
                float bitePerDay = 33.33f / ratsInCell;
                float bite = MathF.Min(chunk.Biomass[curCellIdx] / ratsInCell, (bitePerDay / 24.0f) * dt);
                chunk.Biomass[curCellIdx] -= bite;
                a.Hunger = MathF.Max(0f, a.Hunger - bite * 3.5f);
            }

            // Tomada de Decisão com faro, caça lúdica (máx 2/dia) e fuga de alagamento
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

            // Movimento suave em direção ao alvo (animais atravessam água a 70% da velocidade, mas não permanecem nela)
            float dirX = (targetX + 0.5f) - a.PosX;
            float dirY = (targetY + 0.5f) - a.PosY;
            float dist = MathF.Sqrt(dirX * dirX + dirY * dirY);

            if (dist > 0.05f)
            {
                float speedModifier = (chunk.SurfaceWater[curCellIdx] > 0.2f) ? 0.7f : 1.0f;
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
    /// Boost de biomassa vegetal decorrente da decomposição do animal morto no solo.
    /// </summary>
    private static void ApplyDeathDecomposition(Chunk chunk, int centerX, int centerY)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            int ny = centerY + dy;
            if (ny < 0 || ny >= Chunk.Height) continue;

            for (int dx = -1; dx <= 1; dx++)
            {
                int nx = centerX + dx;
                if (nx < 0 || nx >= Chunk.Width) continue;

                int idx = Chunk.GetIndex(nx, ny);
                chunk.Biomass[idx] = MathF.Min(100f, chunk.Biomass[idx] + 35.0f);
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

        // Animais podem atravessar água, mas têm repulsão severa contra permanecer em terreno inundado!
        float floodPenalty = (water > 0.1f) ? -35.0f : 0f;

        if (agent.Diet == AnimalDiet.Herbivore)
        {
            // Rato: Raio de busca 5 células, pastagem e fuga equilibrada
            float fearWeight = 8.0f;
            float foodWeight = (agent.Hunger / 100.0f) * 4.0f;

            float score = (food * foodWeight) - (danger * fearWeight) + floodPenalty;

            // Procura parceiro fértil do sexo oposto para acasalamento se estiver pronto
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

            // Busca de presas (Ratos):
            // 1. Na zona de caça (15 células): preda por diversão se tiver menos de 2 caças diárias (após a 2ª perde o interesse lúdico)!
            // 2. Fora da zona de caça (até 45 células pelo faro): só caça se estiver com fome!
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Herbivore && other.Health > 0f)
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));

                    if (d <= CatHuntingZone)
                    {
                        // Se atingiu a 2ª caça no dia, perde o interesse a menos que esteja com fome real
                        if (agent.DailyFunKills < 2 || agent.Hunger > 30.0f)
                        {
                            score += (CatHuntingZone - d) * 4.5f;
                        }
                    }
                    else if (d <= CatOlfactoryRange && agent.Hunger > 30.0f)
                    {
                        // Fareja até 45 células, mas somente persegue se estiver com fome
                        float hungerFactor = agent.Hunger / 100.0f;
                        score += (CatOlfactoryRange - d) * 1.5f * hungerFactor;
                    }
                }
            }

            // Territorialidade: Repele outros gatos próximos se não estiver procurando acasalamento heterossexual
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
                            score -= (10.0f - d) * 4.0f; // Repulsão territorial
                        }
                    }
                }
            }

            return score;
        }
    }
}
