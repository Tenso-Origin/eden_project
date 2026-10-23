using System;
using System.Runtime.CompilerServices;

namespace SimCore.SpatialGrid;

/// <summary>
/// Representa um Chunk espacial de 16x16 células (256 células) usando Structure of Arrays (SoA).
/// Arrays planos contíguos em memória permitem carregamento sequencial em Cache L1 e vetorização SIMD.
/// Suporta Double Buffering para execução multithreaded sem locks.
/// </summary>
public sealed class Chunk
{
    public const int Width = 16;
    public const int Height = 16;
    public const int CellCount = Width * Height; // 256 células

    // Coordenadas espaciais do Chunk no mundo
    public readonly int ChunkX;
    public readonly int ChunkY;

    // --- Structure of Arrays (SoA) - Estado Atual (Leitura) ---
    public readonly ushort[] MaterialId = new ushort[CellCount];
    public float[] Temperature = new float[CellCount];
    public float[] Moisture = new float[CellCount];
    public readonly float[] Elevation = new float[CellCount];
    public readonly float[] Biomass = new float[CellCount];

    // --- Double Buffering - Próximo Estado (Escrita sem Data Race) ---
    public float[] NextTemperature = new float[CellCount];
    public float[] NextMoisture = new float[CellCount];

    public Chunk(int chunkX, int chunkY)
    {
        ChunkX = chunkX;
        ChunkY = chunkY;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int GetIndex(int x, int y) => (y << 4) | x; // y * 16 + x

    /// <summary>
    /// Inverte os ponteiros dos buffers ao término do tick (custo O(1)).
    /// </summary>
    public void SwapBuffers()
    {
        (Temperature, NextTemperature) = (NextTemperature, Temperature);
        (Moisture, NextMoisture) = (NextMoisture, Moisture);
    }
}
