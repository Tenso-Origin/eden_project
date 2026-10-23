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
    public byte Age;

    // Estado fisiológico
    public float Health;    // 0.0 (Morto) a 100.0 (Cheio de vida)
    public float Hunger;    // 0.0 (Saciado) a 100.0 (Faminto)
    public float Thirst;    // 0.0 (Hidratado) a 100.0 (Desidratado)
    public float Energy;    // 0.0 a 100.0
    public float MoveSpeed; // Células por segundo (ex: 2.0f)

    // Posição contínua no mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y, float speed = 2.0f)
    {
        EntityId = id;
        SpeciesId = species;
        Diet = diet;
        Age = 1;
        Health = 100f;
        Hunger = 0f;
        Thirst = 0f;
        Energy = 100f;
        MoveSpeed = speed;
        PosX = x;
        PosY = y;
        VelocityX = 0f;
        VelocityY = 0f;
    }
}

/// <summary>
/// FASE 5: Sistema de Comportamento e Movimentação por Gradiente de Influência (Zero A*).
/// Processa agentes animais em lote contíguo (Span).
/// </summary>
public static class FaunaSystem
{
    public const float HungerRate = 1.0f;     // Ganho de fome por segundo
    public const float StarvationDamage = 2.5f;

    /// <summary>
    /// Executa o tick fisiológico, tomada de decisão por mapas de influência e alimentação.
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

        // 2. Processa movimentação e fisiologia de cada agente
        for (int i = 0; i < agents.Length; i++)
        {
            ref var a = ref agents[i];
            if (a.Health <= 0f) continue;

            // Fisiologia
            a.Hunger = Math.Min(100f, a.Hunger + HungerRate * dt);
            if (a.Hunger >= 90f)
            {
                a.Health = Math.Max(0f, a.Health - StarvationDamage * dt);
            }

            int curCellX = (int)Math.Clamp(a.PosX, 0, Chunk.Width - 1);
            int curCellY = (int)Math.Clamp(a.PosY, 0, Chunk.Height - 1);
            int curCellIdx = Chunk.GetIndex(curCellX, curCellY);

            // Se for herbívoro e estiver sobre biomassa com fome > 10, alimenta-se
            if (a.Diet == AnimalDiet.Herbivore && a.Hunger > 10f && chunk.Biomass[curCellIdx] > 1.0f)
            {
                float bite = MathF.Min(chunk.Biomass[curCellIdx], 20.0f * dt);
                chunk.Biomass[curCellIdx] -= bite;
                a.Hunger = MathF.Max(0f, a.Hunger - bite * 2.0f);
            }

            // Tomada de Decisão: Avaliação das 8 células vizinhas (Moore neighborhood)
            float bestScore = EvaluateCellScore(curCellX, curCellY, in a, influence);
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

                    float score = EvaluateCellScore(nx, ny, in a, influence);
                    if (score > bestScore)
                    {
                        bestScore = score;
                        targetX = nx;
                        targetY = ny;
                    }
                }
            }

            // Movimento suave na direção da célula ótima sem A*
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

    private static float EvaluateCellScore(int x, int y, in AnimalAgent agent, InfluenceMap influence)
    {
        int idx = Chunk.GetIndex(x, y);
        float food = influence.FoodGradient[idx];
        float danger = influence.DangerGradient[idx];
        float water = influence.WaterGradient[idx];

        // Herbívoros priorizam fuga se houver perigo, ou comida quando famintos
        if (agent.Diet == AnimalDiet.Herbivore)
        {
            // Perigo tem peso repulsivo altíssimo (-10.0x)
            float fearWeight = 10.0f;
            float foodWeight = (agent.Hunger / 100.0f) * 3.0f;
            float waterWeight = (agent.Thirst / 100.0f) * 1.5f;

            return (food * foodWeight) + (water * waterWeight) - (danger * fearWeight);
        }
        else // Carnívoro
        {
            // Carnívoros caçam o "cheiro" de herbívoros (armazenado ou associado ao mapa)
            return food * 1.5f + water * 1.0f;
        }
    }
}
