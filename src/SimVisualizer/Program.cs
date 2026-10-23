using System;
using SimCore.Biosphere;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimVisualizer;

internal static class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("==========================================================");
        Console.WriteLine("   PROJETO BIOSFERA - SIMVISUALIZER DEBUG VIEWPORT        ");
        Console.WriteLine("   Renderizador DOD em ANSI TrueColor de Baixa Latência   ");
        Console.WriteLine("==========================================================");

        var chunk = new Chunk(0, 0);
        var catalog = MaterialCatalog.GetAll();
        var map = new InfluenceMap();

        // 1. Gera relevo e bioma base
        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);

                if (x < 4 && y < 5)
                {
                    // Lago no canto superior esquerdo
                    chunk.MaterialId[idx] = MaterialCatalog.IdWater;
                    chunk.SurfaceWater[idx] = 10.0f;
                    chunk.Temperature[idx] = 18.0f;
                    chunk.Moisture[idx] = 1.0f;
                }
                else if (x >= 12 && y >= 12)
                {
                    // Região desértica quente
                    chunk.MaterialId[idx] = MaterialCatalog.IdSand;
                    chunk.Temperature[idx] = 42.0f;
                    chunk.Moisture[idx] = 0.02f;
                    chunk.Biomass[idx] = 2.0f;
                }
                else
                {
                    // Planície fértil temperada
                    chunk.MaterialId[idx] = MaterialCatalog.IdOakWood;
                    chunk.Temperature[idx] = 22.0f;
                    chunk.Moisture[idx] = 0.65f;
                    chunk.Biomass[idx] = 60.0f;
                }
            }
        }

        // 2. Agentes da fauna
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: 1, diet: AnimalDiet.Herbivore, x: 6.5f, y: 7.0f, speed: 1.5f),
            new AnimalAgent(id: 2, species: 2, diet: AnimalDiet.Carnivore, x: 10.0f, y: 9.0f, speed: 2.0f)
        };

        // 3. Simulação de 1 ciclo
        map.UpdateFromChunk(chunk);
        FaunaSystem.StepFauna(agents, chunk, map, 0.5f);

        Console.WriteLine("\n[Visualização: Bioma Composto]");
        HeatmapRenderer.RenderToConsole(chunk, HeatmapMode.CompositeBiome, map, agents);

        Console.WriteLine("\n[Visualização: Mapa Térmico]");
        HeatmapRenderer.RenderToConsole(chunk, HeatmapMode.Temperature);

        Console.WriteLine("\n[Inspeção de Célula de Amostra]");
        InspectorUI.InspectCell(chunk, 2, 2); // Lago
        InspectorUI.InspectCell(chunk, 14, 14); // Deserto
    }
}
