using System;

namespace SimCore.Matter;

public readonly struct RopeStats
{
    public readonly float MaxTensileLoadKg; // Carga máxima antes de arrebentar
    public readonly float KnotStability;    // Facilidade de dar nó e não escorregar (0 a 1)
    public readonly float WeatherLifespan;  // Resistência ao apodrecimento na chuva
    public readonly float WeightPerMeterKg;

    public RopeStats(float maxLoad, float knot, float lifespan, float weight)
    {
        MaxTensileLoadKg = maxLoad;
        KnotStability = knot;
        WeatherLifespan = lifespan;
        WeightPerMeterKg = weight;
    }

    // A mágica do Data-Oriented Design: a função não pede "Linho" ou "Couro".
    // Ela recebe a struct bruta MaterialDef e uma variável dimensional (espessura).
    public static RopeStats Craft(in MaterialDef mat, float crossSectionAreaCm2)
    {
        // 1. Carga máxima: Área transversal multiplicada pela tenacidade (resistência à tração) do material.
        float maxLoad = crossSectionAreaCm2 * mat.Toughness * 100f; 

        // 2. Estabilidade do nó: Depende diretamente da flexibilidade. 
        // Um fio de aço/cobre rígido não segura um nó sem fadiga estrutural.
        float knot = Math.Clamp(mat.Flexibility, 0f, 1f);

        // 3. Resistência ao clima: Inversamente proporcional à taxa de degradação orgânica ou oxidação.
        float lifespan = 1.0f / (mat.PutrefactionRate + mat.OxidationRate + 0.001f);

        // 4. Peso: Volume de 1 metro de corda (100cm * Área) * Densidade.
        float weight = (crossSectionAreaCm2 * 100f) * mat.Density / 1000f; // kg/m

        return new RopeStats(maxLoad, knot, lifespan, weight);
    }
}

// Exemplo de item multi-slot (Composição estrutural)
public readonly struct AxeStats
{
    public readonly float ChoppingPower;
    public readonly float ShockAbsorption; // Durabilidade do item a impactos
    public readonly float TotalWeight;

    // Um machado obriga o jogador a alocar dois materiais diferentes: Lâmina e Cabo.
    public static AxeStats Craft(in MaterialDef headMat, float headVolume, 
                                 in MaterialDef handleMat, float handleVolume)
    {
        float headWeight = headVolume * headMat.Density;
        float handleWeight = handleVolume * handleMat.Density;

        // Poder de corte: Multiplica a dureza do material pela inércia (massa) da cabeça.
        float chopping = headMat.Hardness * headWeight;

        // Absorção de choque: O cabo precisa de flexibilidade para dissipar a energia cinética.
        // A lâmina precisa de tenacidade para não estilhaçar.
        float shock = (handleMat.Flexibility * 0.7f) + (headMat.Toughness * 0.3f);

        return new AxeStats(chopping, shock, headWeight + handleWeight);
    }
}
