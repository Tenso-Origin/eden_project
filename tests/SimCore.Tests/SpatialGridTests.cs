using System;
using Xunit;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimCore.Tests;

public class SpatialGridTests
{
    [Fact]
    public void DoubleBuffering_Swap_SwapsBuffersInstantly()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdStone, 20f, 0.1f, 10f);

        // Modifica buffer de escrita
        chunk.NextTemperature[0] = 50f;
        var oldReadBuffer = chunk.Temperature;
        var oldWriteBuffer = chunk.NextTemperature;

        chunk.SwapBuffers();

        // O buffer de leitura atual deve agora conter 50f e ser o antigo write buffer
        Assert.Same(oldWriteBuffer, chunk.Temperature);
        Assert.Same(oldReadBuffer, chunk.NextTemperature);
        Assert.Equal(50f, chunk.Temperature[0]);
    }

    [Fact]
    public void Thermodynamics_HeatConducts_TowardsEquilibrium()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdIron, 20f, 0f, 0f);

        // Aquece a célula central (8, 8) a 500°C
        int centerIdx = Chunk.GetIndex(8, 8);
        chunk.Temperature[centerIdx] = 500f;
        chunk.PrepareNextBuffer();

        var catalog = MaterialCatalog.GetAll();

        // Executa 10 passos de difusão térmica
        for (int i = 0; i < 10; i++)
        {
            Thermodynamics.StepDiffusion(chunk, catalog, 0.1f, ambientTemp: 20f);
            chunk.SwapBuffers();
        }

        // O centro deve ter esfriado e os vizinhos ortogonais devem ter aquecido
        int neighborIdx = Chunk.GetIndex(8, 9);
        Assert.True(chunk.Temperature[centerIdx] < 500f);
        Assert.True(chunk.Temperature[neighborIdx] > 20f);
    }

    [Fact]
    public void Thermodynamics_IceMeltsToWater_WhenHeatedAboveZero()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdStone, 25f, 0f, 0f);

        int idx = Chunk.GetIndex(5, 5);
        chunk.MaterialId[idx] = MaterialCatalog.IdIce;
        chunk.Temperature[idx] = -10f; // Gelo a -10°C
        chunk.PrepareNextBuffer();

        var catalog = MaterialCatalog.GetAll();

        // Aquece a célula com temperatura ambiente de 35°C
        for (int i = 0; i < 30; i++)
        {
            Thermodynamics.StepDiffusion(chunk, catalog, 0.2f, ambientTemp: 35f);
            chunk.SwapBuffers();
        }

        // Deve ter derretido e mudado para Água (IdWater = 1)
        Assert.True(chunk.Temperature[idx] > 0f);
        Assert.Equal(MaterialCatalog.IdWater, chunk.MaterialId[idx]);
    }

    [Fact]
    public void Thermodynamics_WaterBoilsToSteam_WhenHeatedPast100()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdStone, 20f, 0f, 0f);

        int idx = Chunk.GetIndex(5, 5);
        chunk.MaterialId[idx] = MaterialCatalog.IdWater;
        chunk.Temperature[idx] = 95f;
        chunk.PrepareNextBuffer();

        var catalog = MaterialCatalog.GetAll();

        // Aquece intensamente acima de 100°C
        for (int i = 0; i < 20; i++)
        {
            Thermodynamics.StepDiffusion(chunk, catalog, 0.2f, ambientTemp: 150f);
            chunk.SwapBuffers();
        }

        Assert.True(chunk.Temperature[idx] >= 100f);
        Assert.Equal(MaterialCatalog.IdSteam, chunk.MaterialId[idx]);
    }

    [Fact]
    public void Hydrology_SurfaceWater_FlowsDownhill()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdStone, 20f, 0f, 10f); // Platô a 10m de altitude

        int highIdx = Chunk.GetIndex(7, 7);
        int lowIdx = Chunk.GetIndex(8, 7);

        // Cria declive: célula (8, 7) está a 5m de elevação
        chunk.Elevation[lowIdx] = 5f;
        // Coloca 20mm de água na célula alta (7, 7)
        chunk.SurfaceWater[highIdx] = 20.0f;
        chunk.SurfaceWater[lowIdx] = 0.0f;
        chunk.PrepareNextBuffer();

        var catalog = MaterialCatalog.GetAll();

        // Executa 5 passos de hidrologia
        for (int i = 0; i < 5; i++)
        {
            Hydrology.StepHydrology(chunk, catalog, 0.1f);
            chunk.SwapBuffers();
        }

        // A água deve ter escoado da célula alta para a célula baixa
        Assert.True(chunk.SurfaceWater[highIdx] < 20.0f);
        Assert.True(chunk.SurfaceWater[lowIdx] > 0.0f);
    }

    [Fact]
    public void Hydrology_Infiltration_IncreasesSoilMoisture()
    {
        var chunk = new Chunk(0, 0);
        // Areia tem alta permeabilidade (0.95)
        chunk.Fill(MaterialCatalog.IdSand, 20f, 0.1f, 10f);

        int idx = Chunk.GetIndex(4, 4);
        chunk.SurfaceWater[idx] = 50.0f; // Muita água superficial
        float initialMoisture = chunk.Moisture[idx];
        chunk.PrepareNextBuffer();

        var catalog = MaterialCatalog.GetAll();

        Hydrology.StepHydrology(chunk, catalog, 0.5f);
        chunk.SwapBuffers();

        // Umidade do solo aumentou por infiltração
        Assert.True(chunk.Moisture[idx] > initialMoisture);
    }

    [Fact]
    public void ZeroAllocations_DuringThermodynamicsAndHydrologyStep()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdStone, 20f, 0.2f, 10f, 5f);
        chunk.PrepareNextBuffer();
        var catalog = MaterialCatalog.GetAll();

        // Warm-up do JIT
        Thermodynamics.StepDiffusion(chunk, catalog, 0.033f);
        chunk.SwapBuffers();
        Hydrology.StepHydrology(chunk, catalog, 0.033f);
        chunk.SwapBuffers();

        long beforeAlloc = GC.GetAllocatedBytesForCurrentThread();

        // Executa 100 iterações em loop contínuo
        for (int i = 0; i < 100; i++)
        {
            Thermodynamics.StepDiffusion(chunk, catalog, 0.033f);
            chunk.SwapBuffers();
            Hydrology.StepHydrology(chunk, catalog, 0.033f);
            chunk.SwapBuffers();
        }

        long afterAlloc = GC.GetAllocatedBytesForCurrentThread();

        // Zero bytes alocados na heap (100% stack, sem GC)
        Assert.Equal(0, afterAlloc - beforeAlloc);
    }
}
