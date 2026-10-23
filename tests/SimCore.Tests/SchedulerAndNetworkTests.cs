using System;
using Xunit;
using SimCore.Matter;
using SimCore.Scheduler;
using SimCore.SpatialGrid;
using SimServer;

namespace SimCore.Tests;

public class SchedulerAndNetworkTests
{
    [Fact]
    public void TickAccumulator_ExecutesExactTicks_At30Hz()
    {
        var scheduler = new TickManager();
        int physicsTicks = 0;

        scheduler.OnPhysicsTick += (dt) => physicsTicks++;

        // Avança 0.10 segundos (100ms) de tempo real -> deve executar exatamente 3 ticks de 33.33ms
        scheduler.AdvanceTime(0.10);

        Assert.Equal(3, physicsTicks);
        Assert.Equal(3UL, scheduler.TickCount);
    }

    [Fact]
    public void ChunkSlicing_DistributesTicks_AcrossSlicesModulo()
    {
        var scheduler = new TickManager();
        var slicesSeen = new System.Collections.Generic.List<int>();

        scheduler.OnSliceTick += (slice, totalSlices, dt) =>
        {
            slicesSeen.Add(slice);
            Assert.Equal(6, totalSlices);
        };

        // Roda 12 ticks
        for (int i = 0; i < 12; i++)
        {
            scheduler.Step();
        }

        // Deve alternar ciclicamente entre as fatias 1, 2, 3, 4, 5, 0, 1, 2...
        Assert.Equal(12, slicesSeen.Count);
        Assert.Equal(1, slicesSeen[0]);
        Assert.Equal(2, slicesSeen[1]);
        Assert.Equal(0, slicesSeen[5]);
    }

    [Fact]
    public void StateSerializer_QuantizeTemperature_PreservesHighAccuracy()
    {
        float[] testTemps = { -100f, -20.5f, 0f, 23.45f, 100f, 850f, 1500f };

        foreach (var original in testTemps)
        {
            ushort quantized = StateSerializer.QuantizeTemperature(original);
            float reconstructed = StateSerializer.DequantizeTemperature(quantized);

            // Erro de quantização máximo menor que 0.05°C para uma escala de 1600°C
            Assert.True(MathF.Abs(original - reconstructed) < 0.05f);
        }
    }

    [Fact]
    public void StateSerializer_DeltaCompression_EncodesOnlyMutatedCells()
    {
        var current = new Chunk(0, 0);
        var previousAck = new Chunk(0, 0);

        current.Fill(MaterialCatalog.IdStone, 20f, 0.2f, 10f);
        previousAck.Fill(MaterialCatalog.IdStone, 20f, 0.2f, 10f);

        // Altera apenas 3 células no estado atual
        int idx1 = Chunk.GetIndex(2, 2);
        int idx2 = Chunk.GetIndex(5, 5);
        int idx3 = Chunk.GetIndex(10, 10);

        current.Temperature[idx1] = 65.0f; // Variação térmica
        current.MaterialId[idx2] = MaterialCatalog.IdWater; // Transição de fase
        current.Biomass[idx3] = 45.0f; // Crescimento de biomassa

        var deltaBuffer = new DeltaCell[Chunk.CellCount];
        int deltaCount = StateSerializer.EncodeDelta(current, previousAck, deltaBuffer);

        // O delta deve conter EXATAMENTE as 3 células modificadas, poupando 253 células intactas
        Assert.Equal(3, deltaCount);
    }

    [Fact]
    public void StateSerializer_ApplyDelta_ReconstructsStateAccurately()
    {
        var current = new Chunk(0, 0);
        current.Fill(MaterialCatalog.IdStone, 20f, 0.1f, 5f);
        current.Temperature[Chunk.GetIndex(3, 3)] = 120.0f;

        var deltaBuffer = new DeltaCell[Chunk.CellCount];
        int count = StateSerializer.EncodeDelta(current, previousAck: null, deltaBuffer);

        var clientChunk = new Chunk(0, 0);
        StateSerializer.ApplyDelta(clientChunk, new ReadOnlySpan<DeltaCell>(deltaBuffer, 0, count));

        Assert.Equal(current.MaterialId[Chunk.GetIndex(3, 3)], clientChunk.MaterialId[Chunk.GetIndex(3, 3)]);
        Assert.True(MathF.Abs(clientChunk.Temperature[Chunk.GetIndex(3, 3)] - 120.0f) < 0.1f);
    }

    [Fact]
    public void AreaOfInterest_FiltersChunkVisibility_BasedOnRadius()
    {
        var aoi = new AreaOfInterest { RadiusChunks = 2 };
        aoi.RegisterPlayer(playerId: 1, initialChunkX: 10, initialChunkY: 10);

        // Chunks dentro do raio de 2 (X e Y entre 8 e 12)
        Assert.True(aoi.IsChunkVisibleTo(1, 10, 10));
        Assert.True(aoi.IsChunkVisibleTo(1, 12, 11));

        // Chunks fora do raio
        Assert.False(aoi.IsChunkVisibleTo(1, 13, 10));
        Assert.False(aoi.IsChunkVisibleTo(1, 10, 7));
    }

    [Fact]
    public void AreaOfInterest_MovePlayer_DetectsEnteringAndExitingChunks()
    {
        var aoi = new AreaOfInterest { RadiusChunks = 1 }; // Grade 3x3 = 9 chunks
        aoi.RegisterPlayer(1, initialChunkX: 0, initialChunkY: 0);

        // Move 1 chunk para a direita (+X)
        var (entered, exited) = aoi.MovePlayer(1, newChunkX: 1, newChunkY: 0);

        // 3 novos chunks entraram (coluna X = 2) e 3 chunks saíram (coluna X = -1)
        Assert.Equal(3, entered.Count);
        Assert.Equal(3, exited.Count);

        foreach (var c in entered) Assert.Equal(2, c.X);
        foreach (var c in exited) Assert.Equal(-1, c.X);
    }

    [Fact]
    public void ZeroAllocations_DuringDeltaEncoding()
    {
        var current = new Chunk(0, 0);
        var prev = new Chunk(0, 0);
        current.Fill(MaterialCatalog.IdStone, 25f, 0.1f, 5f);
        prev.Fill(MaterialCatalog.IdStone, 25f, 0.1f, 5f);
        current.Temperature[10] = 50f;

        var deltaBuffer = new DeltaCell[Chunk.CellCount];

        // Warm-up
        StateSerializer.EncodeDelta(current, prev, deltaBuffer);

        long beforeAlloc = GC.GetAllocatedBytesForCurrentThread();

        for (int i = 0; i < 100; i++)
        {
            StateSerializer.EncodeDelta(current, prev, deltaBuffer);
        }

        long afterAlloc = GC.GetAllocatedBytesForCurrentThread();

        // 0 bytes no heap
        Assert.Equal(0, afterAlloc - beforeAlloc);
    }
}
