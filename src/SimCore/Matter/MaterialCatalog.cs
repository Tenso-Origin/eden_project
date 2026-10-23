using System;

namespace SimCore.Matter;

/// <summary>
/// Catálogo Estático Binário em Memória.
/// Acesso direto O(1) via índice uint16 sem overhead de dicionários ou hashing.
/// </summary>
public static class MaterialCatalog
{
    public const ushort IdAir     = 0;
    public const ushort IdWater   = 1;
    public const ushort IdSteam   = 2;
    public const ushort IdIce     = 3;
    public const ushort IdIron    = 10;
    public const ushort IdSteel   = 11;
    public const ushort IdCopper  = 12;
    public const ushort IdTin     = 13;
    public const ushort IdBronze  = 14;
    public const ushort IdHemp    = 20;
    public const ushort IdLeather = 21;
    public const ushort IdOakWood = 22;
    public const ushort IdPineWood= 23;
    public const ushort IdStone   = 30;
    public const ushort IdSand    = 31;

    public const ushort MaxMaterials = 256;

    private static readonly MaterialDef[] _registry = new MaterialDef[MaxMaterials];
    private static readonly SynergyRule[] _synergies;

    static MaterialCatalog()
    {
        // 0: Vácuo / Ar
        _registry[IdAir] = new MaterialDef(
            id: IdAir, phaseTargetId: 0,
            flags: MaterialFlags.IsGas,
            density: 0.0012f, hardness: 0f, toughness: 0f, flexibility: 1.0f,
            meltingPoint: -218f, boilingPoint: -183f, thermalCond: 0.02f, flammability: 0f,
            oxidationRate: 0f, putrefactionRate: 0f, permeability: 1.0f);

        // 1: Água líquida
        _registry[IdWater] = new MaterialDef(
            id: IdWater, phaseTargetId: IdSteam,
            flags: MaterialFlags.IsLiquid | MaterialFlags.IsSoluble,
            density: 1.0f, hardness: 0f, toughness: 0f, flexibility: 1.0f,
            meltingPoint: 0f, boilingPoint: 100f, thermalCond: 0.6f, flammability: 0f,
            oxidationRate: 0f, putrefactionRate: 0f, permeability: 1.0f);

        // 2: Vapor de Água
        _registry[IdSteam] = new MaterialDef(
            id: IdSteam, phaseTargetId: IdWater,
            flags: MaterialFlags.IsGas,
            density: 0.0006f, hardness: 0f, toughness: 0f, flexibility: 1.0f,
            meltingPoint: 0f, boilingPoint: 100f, thermalCond: 0.03f, flammability: 0f,
            oxidationRate: 0f, putrefactionRate: 0f, permeability: 1.0f);

        // 3: Gelo
        _registry[IdIce] = new MaterialDef(
            id: IdIce, phaseTargetId: IdWater,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMineral,
            density: 0.917f, hardness: 1.5f, toughness: 0.5f, flexibility: 0.01f,
            meltingPoint: 0f, boilingPoint: 100f, thermalCond: 2.2f, flammability: 0f,
            oxidationRate: 0f, putrefactionRate: 0f, permeability: 0.0f);

        // 10: Ferro Puro
        _registry[IdIron] = new MaterialDef(
            id: IdIron, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMetal | MaterialFlags.IsConductive | MaterialFlags.IsAlloyable,
            density: 7.87f, hardness: 4.5f, toughness: 6.0f, flexibility: 0.15f,
            meltingPoint: 1538f, boilingPoint: 2862f, thermalCond: 0.80f, flammability: 0f,
            oxidationRate: 0.35f, putrefactionRate: 0f, permeability: 0.0f);

        // 11: Aço Carbono
        _registry[IdSteel] = new MaterialDef(
            id: IdSteel, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMetal | MaterialFlags.IsConductive | MaterialFlags.IsAlloyable,
            density: 7.85f, hardness: 6.5f, toughness: 8.5f, flexibility: 0.08f,
            meltingPoint: 1425f, boilingPoint: 2750f, thermalCond: 0.70f, flammability: 0f,
            oxidationRate: 0.10f, putrefactionRate: 0f, permeability: 0.0f);

        // 12: Cobre
        _registry[IdCopper] = new MaterialDef(
            id: IdCopper, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMetal | MaterialFlags.IsConductive | MaterialFlags.IsAlloyable,
            density: 8.96f, hardness: 3.0f, toughness: 4.0f, flexibility: 0.40f,
            meltingPoint: 1085f, boilingPoint: 2562f, thermalCond: 0.95f, flammability: 0f,
            oxidationRate: 0.05f, putrefactionRate: 0f, permeability: 0.0f);

        // 13: Estanho
        _registry[IdTin] = new MaterialDef(
            id: IdTin, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMetal | MaterialFlags.IsConductive | MaterialFlags.IsAlloyable,
            density: 7.31f, hardness: 1.8f, toughness: 2.0f, flexibility: 0.50f,
            meltingPoint: 232f, boilingPoint: 2602f, thermalCond: 0.66f, flammability: 0f,
            oxidationRate: 0.02f, putrefactionRate: 0f, permeability: 0.0f);

        // 14: Bronze Padrão
        _registry[IdBronze] = new MaterialDef(
            id: IdBronze, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMetal | MaterialFlags.IsConductive | MaterialFlags.IsComposite,
            density: 8.80f, hardness: 5.5f, toughness: 5.8f, flexibility: 0.20f,
            meltingPoint: 950f, boilingPoint: 2400f, thermalCond: 0.75f, flammability: 0f,
            oxidationRate: 0.03f, putrefactionRate: 0f, permeability: 0.0f);

        // 20: Cânhamo / Linho (Fibras vegetais)
        _registry[IdHemp] = new MaterialDef(
            id: IdHemp, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsOrganic | MaterialFlags.IsFiber | MaterialFlags.IsFlammable,
            density: 1.2f, hardness: 0.5f, toughness: 1.5f, flexibility: 0.95f,
            meltingPoint: 220f, boilingPoint: 0f, thermalCond: 0.05f, flammability: 0.85f,
            oxidationRate: 0.0f, putrefactionRate: 0.50f, permeability: 0.85f);

        // 21: Couro
        _registry[IdLeather] = new MaterialDef(
            id: IdLeather, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsOrganic | MaterialFlags.IsLeather | MaterialFlags.IsFlammable,
            density: 0.95f, hardness: 1.0f, toughness: 2.5f, flexibility: 0.80f,
            meltingPoint: 180f, boilingPoint: 0f, thermalCond: 0.15f, flammability: 0.40f,
            oxidationRate: 0.0f, putrefactionRate: 0.25f, permeability: 0.30f);

        // 22: Madeira de Carvalho
        _registry[IdOakWood] = new MaterialDef(
            id: IdOakWood, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsOrganic | MaterialFlags.IsWood | MaterialFlags.IsFlammable,
            density: 0.75f, hardness: 3.5f, toughness: 4.0f, flexibility: 0.25f,
            meltingPoint: 300f, boilingPoint: 0f, thermalCond: 0.17f, flammability: 0.70f,
            oxidationRate: 0.0f, putrefactionRate: 0.15f, permeability: 0.40f);

        // 23: Madeira de Pinho
        _registry[IdPineWood] = new MaterialDef(
            id: IdPineWood, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsOrganic | MaterialFlags.IsWood | MaterialFlags.IsFlammable,
            density: 0.50f, hardness: 2.0f, toughness: 2.8f, flexibility: 0.35f,
            meltingPoint: 260f, boilingPoint: 0f, thermalCond: 0.12f, flammability: 0.80f,
            oxidationRate: 0.0f, putrefactionRate: 0.20f, permeability: 0.55f);

        // 30: Pedra (Granito)
        _registry[IdStone] = new MaterialDef(
            id: IdStone, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMineral,
            density: 2.70f, hardness: 7.0f, toughness: 3.0f, flexibility: 0.02f,
            meltingPoint: 1215f, boilingPoint: 2900f, thermalCond: 2.8f, flammability: 0f,
            oxidationRate: 0.0f, putrefactionRate: 0f, permeability: 0.05f);

        // 31: Areia
        _registry[IdSand] = new MaterialDef(
            id: IdSand, phaseTargetId: 0,
            flags: MaterialFlags.IsSolid | MaterialFlags.IsMineral,
            density: 1.60f, hardness: 6.0f, toughness: 0.1f, flexibility: 0.0f,
            meltingPoint: 1700f, boilingPoint: 2230f, thermalCond: 0.27f, flammability: 0f,
            oxidationRate: 0.0f, putrefactionRate: 0f, permeability: 0.95f);

        // Regras de Sinergia
        _synergies = new SynergyRule[]
        {
            // Cobre (12) + Estanho (13) -> Liga Bronze (ideal 12% estanho, tolerância 8%)
            new SynergyRule(
                a: IdCopper, b: IdTin, ratioB: 0.12f, tol: 0.08f,
                hardMult: 1.85f, toughMult: 1.30f, meltOffset: -120f)
        };
    }

    public static ReadOnlySpan<MaterialDef> GetAll() => _registry;
    public static ReadOnlySpan<SynergyRule> GetSynergies() => _synergies;

    public static ref readonly MaterialDef Get(ushort id)
    {
        if (id >= MaxMaterials) return ref _registry[0];
        return ref _registry[id];
    }
}
