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

    // Posição contínua no mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    public bool IsAdult => AgeInDays >= (MaxLifespanDays * 0.08f); // Jovem adulto a partir de ~8% da vida
    public bool IsReadyToMate => IsAdult && Hunger < 30.0f && MatingCooldown <= 0.0f && Health > 50.0f;

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y, float speed = 2.0f)
    {
        EntityId = id;
        SpeciesId = species;
        Diet = diet;
        Health = 100f;
        Hunger = 20f;
        Thirst = 0f;
        Energy = 100f;
        MoveSpeed = speed;
        PosX = x;
        PosY = y;
        VelocityX = 0f;
        VelocityY = 0f;

        // Configuração Biológica baseada em tempos reais
        if (diet == AnimalDiet.Herbivore || species == (ushort)AnimalSpecies.Rat)
        {
            // RATO: Expectativa de vida ~2.5 anos (~912 dias). Adulto aos ~60 dias.
            MaxLifespanDays = 912.5f;
            AgeInDays = 75.0f; // Inicia jovem adulto
            Age = 1;
            SensoryRadius = 5; // Herbívoros procuram comida em até 5 células
            MatingCooldown = 15.0f;
        }
        else
        {
            // GATO: Expectativa de vida ~14 anos (~5110 dias). Adulto aos ~365 dias.
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
    public const float RatHungerRate = 2.5f;      // Ratos possuem metabolismo acelerado (fome rápida)
    public const float CatHungerRate = 0.65f;     // Gatos carnívoros sustentam saciedade por muito mais tempo
    public const float StarvationDamage = 3.5f;

    /// <summary>
    /// Executa o tick fisiológico, tomada de decisão por mapas de influência, territorialidade e reprodução.
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
                influence.EmitDanger(cellX, cellY, 100.0f);
            }
        }

        // 2. Processa fisiologia, alimentação, territorialidade e movimento
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f) continue;

            // Envelhecimento biológico (tempo em dias)
            a.AgeInDays += dt * 0.5f;
            if (a.AgeInDays >= a.MaxLifespanDays)
            {
                // Morte por senescência natural (velhice)
                a.Health = 0f;
                continue;
            }

            if (a.MatingCooldown > 0f)
            {
                a.MatingCooldown = MathF.Max(0f, a.MatingCooldown - dt);
            }

            // Metabolismo e Saciedade: Rato queima comida rápido; Gato fica saciado muito mais tempo
            float hungerRate = (a.Diet == AnimalDiet.Herbivore) ? RatHungerRate : CatHungerRate;
            a.Hunger = MathF.Min(100f, a.Hunger + hungerRate * dt);

            if (a.Hunger >= 90f)
            {
                a.Health = MathF.Max(0f, a.Health - StarvationDamage * dt);
                if (a.Health <= 0f) continue;
            }

            int curCellX = (int)Math.Clamp(a.PosX, 0, Chunk.Width - 1);
            int curCellY = (int)Math.Clamp(a.PosY, 0, Chunk.Height - 1);
            int curCellIdx = Chunk.GetIndex(curCellX, curCellY);

            // Herbívoro pastando sobre biomassa
            if (a.Diet == AnimalDiet.Herbivore && a.Hunger > 10f && chunk.Biomass[curCellIdx] > 1.0f)
            {
                float bite = MathF.Min(chunk.Biomass[curCellIdx], 25.0f * dt);
                chunk.Biomass[curCellIdx] -= bite;
                a.Hunger = MathF.Max(0f, a.Hunger - bite * 2.2f);
            }

            // Tomada de Decisão: Avaliação das células vizinhas
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

            // Movimento suave em direção ao alvo
            float dirX = (targetX + 0.5f) - a.PosX;
            float dirY = (targetY + 0.5f) - a.PosY;
            float dist = MathF.Sqrt(dirX * dirX + dirY * dirY);

            if (dist > 0.05f)
            {
                float stepDist = a.MoveSpeed * dt;
                float moveX = (dirX / dist) * MathF.Min(dist, stepDist);
                float moveY = (dirY / dist) * MathF.Min(dist, stepDist);

                a.PosX = Math.Clamp(a.PosX + moveX, 0f, Chunk.Width - 0.01f);
                a.PosY = Math.Clamp(a.PosY + moveY, 0f, Chunk.Height - 0.01f);
                a.VelocityX = moveX / dt;
                a.VelocityY = moveY / dt;
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

        if (agent.Diet == AnimalDiet.Herbivore)
        {
            // Rato: Raio de busca 5 células, busca biomassa verde e foge de perigo
            float fearWeight = 12.0f;
            float foodWeight = (agent.Hunger / 100.0f) * 3.5f;
            float waterWeight = (agent.Thirst / 100.0f) * 1.5f;

            float score = (food * foodWeight) + (water * waterWeight) - (danger * fearWeight);

            // Procura semelhante para acasalamento se estiver pronto
            if (agent.IsReadyToMate)
            {
                for (int i = 0; i < allAgents.Length; i++)
                {
                    if (i == selfIdx) continue;
                    ref readonly var other = ref allAgents[i];
                    if (other.SpeciesId == agent.SpeciesId && other.IsReadyToMate)
                    {
                        float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                        if (d <= agent.SensoryRadius)
                        {
                            score += MathF.Max(0f, (agent.SensoryRadius - d) * 4.0f);
                        }
                    }
                }
            }

            return score;
        }
        else // Carnívoro / Gato
        {
            // Gato: Raio 15 células, territorialidade (repele outros gatos), saciedade prolongada
            float huntWeight = (agent.Hunger / 100.0f) * 4.0f;
            float score = (food * huntWeight) + water * 1.0f;

            // Territorialidade: Repele outros gatos próximos se não estiver procurando acasalamento
            for (int i = 0; i < allAgents.Length; i++)
            {
                if (i == selfIdx) continue;
                ref readonly var other = ref allAgents[i];
                if (other.Diet == AnimalDiet.Carnivore && other.Health > 0f)
                {
                    float d = MathF.Sqrt(MathF.Pow(other.PosX - x, 2) + MathF.Pow(other.PosY - y, 2));
                    if (d <= 8.0f) // Raio territorial de 8 células
                    {
                        if (agent.IsReadyToMate && other.IsReadyToMate)
                        {
                            // Atração reprodutiva
                            score += (agent.SensoryRadius - d) * 3.0f;
                        }
                        else
                        {
                            // Disputa territorial / repulsão
                            score -= (8.0f - d) * 5.0f;
                        }
                    }
                }
            }

            return score;
        }
    }
}
