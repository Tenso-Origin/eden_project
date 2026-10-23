using System;
using System.Runtime.InteropServices;

namespace SimCore.Matter;

/// <summary>
/// Representa uma fração de material inserida em uma mistura ou caldeirão.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct MaterialInput
{
    public readonly ushort MaterialId;
    public readonly float Volume; // Em cm³ ou unidades de volume

    public MaterialInput(ushort materialId, float volume)
    {
        MaterialId = materialId;
        Volume = volume;
    }
}

/// <summary>
/// Regra de emergência química/metalúrgica (Ex: Cobre + Estanho = Bronze).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public readonly struct SynergyRule
{
    public readonly ushort MatA;
    public readonly ushort MatB;
    public readonly float IdealRatioB;          // Ex: 0.12 (12% de Estanho no Cobre)
    public readonly float Tolerance;            // Ex: 0.08 (Aceita entre 4% e 20%)
    public readonly float HardnessMultiplier;   // Ex: 1.85x mais duro que a média
    public readonly float ToughnessMultiplier;  // Ex: 1.30x mais tenaz
    public readonly float MeltingPointOffset;   // Ex: -120°C (Eutético: funde mais fácil)

    public SynergyRule(ushort a, ushort b, float ratioB, float tol, float hardMult, float toughMult, float meltOffset)
    {
        MatA = a; MatB = b; IdealRatioB = ratioB; Tolerance = tol;
        HardnessMultiplier = hardMult; ToughnessMultiplier = toughMult; MeltingPointOffset = meltOffset;
    }
}

public static class AlloyMixer
{
    /// <summary>
    /// Combina N materiais calculando a média ponderada por MASSA (Volume * Densidade)
    /// e aplica modificadores não-lineares caso ocorra sinergia de liga.
    /// Zero alocações de memória (100% Stack/Span).
    /// </summary>
    public static MaterialDef Mix(
        ReadOnlySpan<MaterialInput> inputs,
        ReadOnlySpan<MaterialDef> registry,
        ReadOnlySpan<SynergyRule> synergies,
        float processTemperature,
        ushort generatedId)
    {
        float totalVolume = 0f;
        float totalMass = 0f;
        MaterialFlags combinedFlags = MaterialFlags.None;

        // 1ª Passada: Calcular Massa Total e Volume Total
        for (int i = 0; i < inputs.Length; i++)
        {
            ref readonly var mat = ref registry[inputs[i].MaterialId];
            float vol = inputs[i].Volume;
            float mass = vol * mat.Density;

            totalVolume += vol;
            totalMass += mass;
            combinedFlags |= mat.Flags;
        }

        if (totalMass <= 0.0001f) return default;

        // Acumuladores ponderados
        float hardness = 0f, toughness = 0f, flexibility = 0f;
        float melting = 0f, boiling = 0f, thermalCond = 0f, flammability = 0f;
        float oxidation = 0f, putrefaction = 0f, permeability = 0f;

        // 2ª Passada: Interpolação Ponderada pela Fração de Massa
        for (int i = 0; i < inputs.Length; i++)
        {
            ref readonly var mat = ref registry[inputs[i].MaterialId];
            float massWeight = (inputs[i].Volume * mat.Density) / totalMass;

            hardness     += mat.Hardness * massWeight;
            toughness    += mat.Toughness * massWeight;
            flexibility  += mat.Flexibility * massWeight;
            melting      += mat.MeltingPoint * massWeight;
            boiling      += mat.BoilingPoint * massWeight;
            thermalCond  += mat.ThermalConductivity * massWeight;
            flammability += mat.Flammability * massWeight;
            oxidation    += mat.OxidationRate * massWeight;
            putrefaction += mat.PutrefactionRate * massWeight;
            permeability += mat.Permeability * massWeight;
        }

        float finalDensity = totalMass / totalVolume;

        // 3ª Passada: Verificar Sinergia de Liga Metálica (Apenas se fundidos)
        if (inputs.Length == 2 && processTemperature >= melting)
        {
            ApplySynergyIfApplicable(
                inputs, registry, synergies, totalMass,
                ref hardness, ref toughness, ref melting);
        }

        return new MaterialDef(
            id: generatedId,
            phaseTargetId: 0,
            flags: combinedFlags | MaterialFlags.IsComposite,
            density: finalDensity,
            hardness: Math.Clamp(hardness, 0f, 10f),
            toughness: Math.Clamp(toughness, 0f, 10f),
            flexibility: Math.Clamp(flexibility, 0f, 1f),
            meltingPoint: melting,
            boilingPoint: boiling,
            thermalCond: Math.Clamp(thermalCond, 0f, 1f),
            flammability: Math.Clamp(flammability, 0f, 1f),
            oxidationRate: Math.Clamp(oxidation, 0f, 1f),
            putrefactionRate: Math.Clamp(putrefaction, 0f, 1f),
            permeability: Math.Clamp(permeability, 0f, 1f)
        );
    }

    private static void ApplySynergyIfApplicable(
        ReadOnlySpan<MaterialInput> inputs,
        ReadOnlySpan<MaterialDef> registry,
        ReadOnlySpan<SynergyRule> synergies,
        float totalMass,
        ref float hardness, ref float toughness, ref float melting)
    {
        ushort id0 = inputs[0].MaterialId;
        ushort id1 = inputs[1].MaterialId;

        for (int i = 0; i < synergies.Length; i++)
        {
            ref readonly var rule = ref synergies[i];
            bool matchOrder = (rule.MatA == id0 && rule.MatB == id1);
            bool matchReverse = (rule.MatA == id1 && rule.MatB == id0);

            if (!matchOrder && !matchReverse) continue;

            // Descobre a proporção em massa do elemento secundário (MatB)
            var inputB = matchOrder ? inputs[1] : inputs[0];
            float massB = inputB.Volume * registry[inputB.MaterialId].Density;
            float actualRatioB = massB / totalMass;

            float diff = Math.Abs(actualRatioB - rule.IdealRatioB);
            if (diff <= rule.Tolerance)
            {
                // Quanto mais próximo da proporção ideal, mais próximo de 100% do bônus da liga
                float synergyEfficiency = 1.0f - (diff / rule.Tolerance);

                hardness  *= 1.0f + ((rule.HardnessMultiplier - 1.0f) * synergyEfficiency);
                toughness *= 1.0f + ((rule.ToughnessMultiplier - 1.0f) * synergyEfficiency);
                melting   += rule.MeltingPointOffset * synergyEfficiency;
                break;
            }
        }
    }
}
