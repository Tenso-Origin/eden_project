using System;
using System.Runtime.InteropServices;

namespace SimCore.Matter;

/// <summary>
/// Máscaras de bits de 64 bits para classificação taxonômica e estados físicos.
/// Checagens custam 1 ciclo de clock da CPU via operadores bitwise (&, |).
/// </summary>
[Flags]
public enum MaterialFlags : ulong
{
    None        = 0,
    // Estados Físicos Base
    IsSolid     = 1UL << 0,
    IsLiquid    = 1UL << 1,
    IsGas       = 1UL << 2,

    // Famílias Químicas / Estruturais
    IsMetal     = 1UL << 3,
    IsMineral   = 1UL << 4,
    IsOrganic   = 1UL << 5,
    IsFiber     = 1UL << 6,
    IsWood      = 1UL << 7,
    IsLeather   = 1UL << 8,

    // Propriedades Reativas / Comportamentais
    IsFlammable = 1UL << 9,
    IsConductive= 1UL << 10,
    IsSoluble   = 1UL << 11,
    IsToxic     = 1UL << 12,
    IsAlloyable = 1UL << 13,
    IsComposite = 1UL << 14
}

/// <summary>
/// Estrutura imutável orientada a dados (52 bytes).
/// Sem referências a objetos (strings ou classes) para não acionar o Garbage Collector.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct MaterialDef
{
    public readonly ushort Id;                 // 2 bytes (Suporta até 65.535 materiais)
    public readonly ushort PhaseChangeTargetId;// 2 bytes (ID do material ao derreter/evaporar)
    public readonly MaterialFlags Flags;       // 8 bytes

    // --- Atributos Mecânicos ---
    public readonly float Density;             // g/cm³ (Ex: Ferro = 7.87, Pinho = 0.5)
    public readonly float Hardness;            // Escala contínua 0.0 a 10.0 (Mohs/Vickers)
    public readonly float Toughness;           // Tenacidade / Resistência a fratura (0.0 a 10.0)
    public readonly float Flexibility;         // Elasticidade / Maleabilidade (0.0 a 1.0)

    // --- Atributos Térmicos e Químicos ---
    public readonly float MeltingPoint;        // °C (Ponto de fusão/combustão)
    public readonly float BoilingPoint;        // °C (Ponto de ebulição)
    public readonly float ThermalConductivity; // 0.0 (Isolante) a 1.0 (Supercondutor)
    public readonly float Flammability;        // 0.0 (Inerte) a 1.0 (Altamente inflamável)

    // --- Atributos de Degradação e Ambiente ---
    public readonly float OxidationRate;       // Taxa de ferrugem/corrosão (0.0 a 1.0)
    public readonly float PutrefactionRate;    // Taxa de apodrecimento orgânico (0.0 a 1.0)
    public readonly float Permeability;        // Retenção/passagem hídrica no solo (0.0 a 1.0)

    public MaterialDef(
        ushort id, ushort phaseTargetId, MaterialFlags flags,
        float density, float hardness, float toughness, float flexibility,
        float meltingPoint, float boilingPoint, float thermalCond, float flammability,
        float oxidationRate, float putrefactionRate, float permeability)
    {
        Id = id;
        PhaseChangeTargetId = phaseTargetId;
        Flags = flags;
        Density = density;
        Hardness = hardness;
        Toughness = toughness;
        Flexibility = flexibility;
        MeltingPoint = meltingPoint;
        BoilingPoint = boilingPoint;
        ThermalConductivity = thermalCond;
        Flammability = flammability;
        OxidationRate = oxidationRate;
        PutrefactionRate = putrefactionRate;
        Permeability = permeability;
    }

    // Helper inline para checagem rápida de flags na CPU
    public bool HasFlags(MaterialFlags check) => (Flags & check) == check;
}
