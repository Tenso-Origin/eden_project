using System;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimVisualizer;

internal static class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("=== Projeto Biosfera: Visualizador Debug (FASES 2 a 5) ===");
        var chunk = new Chunk(0, 0);

        // Inicializa célula central com água a 25°C
        int center = Chunk.GetIndex(8, 8);
        chunk.MaterialId[center] = MaterialCatalog.IdWater;
        chunk.Temperature[center] = 25.0f;
        chunk.Moisture[center] = 0.85f;
        chunk.Biomass[center] = 40.0f;

        InspectorUI.InspectCell(chunk, 8, 8);
    }
}
