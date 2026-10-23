using System;
using System.Runtime.InteropServices;
using Xunit;
using SimCore.Matter;

namespace SimCore.Tests;

public class MaterialAlgebraTests
{
    [Fact]
    public void MaterialDef_StructSize_IsExactly52Bytes()
    {
        // Garante que a struct cabe dentro de 1 linha de cache L1 (64 bytes)
        int size = Marshal.SizeOf<MaterialDef>();
        Assert.Equal(52, size);
    }

    [Fact]
    public void BitFlags_CheckFastBitwise_RunsInSingleOp()
    {
        var iron = MaterialCatalog.Get(MaterialCatalog.IdIron);

        // Deve ser metal condutor e sólido
        Assert.True(iron.HasFlags(MaterialFlags.IsMetal | MaterialFlags.IsConductive));
        Assert.True(iron.HasFlags(MaterialFlags.IsSolid));

        // Não deve ser orgânico ou inflamável
        Assert.False(iron.HasFlags(MaterialFlags.IsOrganic));
        Assert.False(iron.HasFlags(MaterialFlags.IsFlammable));
    }

    [Fact]
    public void Rope_CraftedWithSteel_HasHighLoadButTerribleKnot()
    {
        // Obtém materiais base do catálogo
        var steel = MaterialCatalog.Get(MaterialCatalog.IdSteel);
        var hemp = MaterialCatalog.Get(MaterialCatalog.IdHemp);

        // Act: Criar duas cordas com a mesma espessura (2 cm²)
        var steelCable = RopeStats.Craft(steel, 2.0f);
        var hempRope = RopeStats.Craft(hemp, 2.0f);

        // Assert: Validação física emergente
        Assert.True(steelCable.MaxTensileLoadKg > hempRope.MaxTensileLoadKg); // Aço suporta muito mais carga
        Assert.True(steelCable.KnotStability < 0.15f);                       // Nó de aço escorrega / fratura
        Assert.True(hempRope.KnotStability > 0.90f);                         // Nó de cânhamo é estável
        Assert.True(hempRope.WeatherLifespan < steelCable.WeatherLifespan);   // Cânhamo apodrece na umidade
    }

    [Fact]
    public void Axe_CraftedWithStoneHeadAndWoodHandle_ComputesPhysicalBalance()
    {
        var stone = MaterialCatalog.Get(MaterialCatalog.IdStone);
        var oakWood = MaterialCatalog.Get(MaterialCatalog.IdOakWood);

        // Cabeça de 100cm³, Cabo de 200cm³
        var axe = AxeStats.Craft(stone, 100f, oakWood, 200f);

        Assert.True(axe.ChoppingPower > 0f);
        Assert.True(axe.ShockAbsorption > 0.2f);
        Assert.Equal((100f * stone.Density) + (200f * oakWood.Density), axe.TotalWeight, precision: 2);
    }

    [Fact]
    public void AlloyMixer_CopperAndTin_ProducesBronzeSynergy()
    {
        var registry = MaterialCatalog.GetAll();
        var synergies = MaterialCatalog.GetSynergies();

        // 88% Cobre + 12% Estanho em volume ajustado para proporção ideal em massa
        float copperVol = 88f;
        float tinVol = 12f;

        var inputs = new MaterialInput[]
        {
            new MaterialInput(MaterialCatalog.IdCopper, copperVol),
            new MaterialInput(MaterialCatalog.IdTin, tinVol)
        };

        // Temperatura acima do ponto de fusão para reagir
        float meltingTemp = 1100f;
        var bronze = AlloyMixer.Mix(inputs, registry, synergies, meltingTemp, 99);

        var copper = MaterialCatalog.Get(MaterialCatalog.IdCopper);
        var tin = MaterialCatalog.Get(MaterialCatalog.IdTin);

        // O bronze deve ser significativamente mais duro que ambos os componentes originais
        Assert.True(bronze.Hardness > copper.Hardness);
        Assert.True(bronze.Hardness > tin.Hardness);
        Assert.True(bronze.HasFlags(MaterialFlags.IsComposite));
    }
}
