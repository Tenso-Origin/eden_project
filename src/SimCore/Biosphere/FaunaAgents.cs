using System;
using System.Runtime.InteropServices;

namespace SimCore.Biosphere;

public enum AnimalDiet : byte
{
    Herbivore = 0,
    Carnivore = 1,
    Omnivore  = 2
}

/// <summary>
/// FASE 5: Componente de agente animal para arquitetura ECS.
/// Struct pura sem referências heap para alocação contígua em memória.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct AnimalAgent
{
    public uint EntityId;
    public ushort SpeciesId;
    public AnimalDiet Diet;
    public byte Age;

    // Estado fisiológico
    public float Health;    // 0.0 a 100.0
    public float Hunger;    // 0.0 (Saciado) a 100.0 (Faminto)
    public float Thirst;    // 0.0 (Hidratado) a 100.0 (Desidratado)
    public float Energy;    // 0.0 a 100.0

    // Posição no mundo
    public float PosX;
    public float PosY;
    public float VelocityX;
    public float VelocityY;

    public AnimalAgent(uint id, ushort species, AnimalDiet diet, float x, float y)
    {
        EntityId = id;
        SpeciesId = species;
        Diet = diet;
        Age = 1;
        Health = 100f;
        Hunger = 0f;
        Thirst = 0f;
        Energy = 100f;
        PosX = x;
        PosY = y;
        VelocityX = 0f;
        VelocityY = 0f;
    }
}
