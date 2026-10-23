using System;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimVisualizer;

/// <summary>
/// FASES 2 a 5: Painel de inspeção analítica de células do Chunk.
/// Imprime no console ou viewport os dados físicos de uma célula específica.
/// </summary>
public static class InspectorUI
{
    public static void InspectCell(Chunk chunk, int x, int y)
    {
        int idx = Chunk.GetIndex(x, y);
        ushort matId = chunk.MaterialId[idx];
        ref readonly var mat = ref MaterialCatalog.Get(matId);

        Console.WriteLine($"--- Célula ({x}, {y}) [Chunk ({chunk.ChunkX}, {chunk.ChunkY})] ---");
        Console.WriteLine($"Material ID: {matId} | Flags: {mat.Flags}");
        Console.WriteLine($"Temperatura: {chunk.Temperature[idx]:F2}°C (Ponto Fusão: {mat.MeltingPoint}°C)");
        Console.WriteLine($"Umidade:     {chunk.Moisture[idx]:F3} | Permeabilidade: {mat.Permeability:F2}");
        Console.WriteLine($"Biomassa:    {chunk.Biomass[idx]:F2} / 100.0");
    }
}
