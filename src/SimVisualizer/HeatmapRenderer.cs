using System;
using System.IO;
using System.Text;
using SimCore.Biosphere;
using SimCore.Matter;
using SimCore.SpatialGrid;

namespace SimVisualizer;

public enum HeatmapMode
{
    Temperature,
    MoistureAndWater,
    Biomass,
    InfluenceDanger,
    CompositeBiome
}

/// <summary>
/// FASES 2 a 5: Visualizador Debug de Heatmaps em Tempo Real.
/// Renderiza matrizes de pixels RGB no Console (via ANSI TrueColor)
/// e exporta imagens brutas PPM sem nenhuma dependência gráfica externa.
/// </summary>
public static class HeatmapRenderer
{
    /// <summary>
    /// Renderiza o Chunk no terminal utilizando blocos com ANSI TrueColor de 24 bits.
    /// </summary>
    public static void RenderToConsole(
        Chunk chunk,
        HeatmapMode mode,
        InfluenceMap? influence = null,
        ReadOnlySpan<AnimalAgent> agents = default)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"=== CHUNK ({chunk.ChunkX}, {chunk.ChunkY}) - MODO: {mode} ===");

        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);

                // Verifica se há um animal sobre esta célula
                int agentOnCell = -1;
                for (int a = 0; a < agents.Length; a++)
                {
                    if ((int)agents[a].PosX == x && (int)agents[a].PosY == y)
                    {
                        agentOnCell = a;
                        break;
                    }
                }

                (byte r, byte g, byte b, char glyph) = GetCellColorAndGlyph(
                    chunk, idx, mode, influence, agentOnCell >= 0 ? agents[agentOnCell] : null);

                // ANSI Escape sequence de TrueColor de fundo e texto
                sb.Append($"\x1b[48;2;{r};{g};{b}m\x1b[38;2;255;255;255m{glyph} \x1b[0m");
            }
            sb.AppendLine();
        }

        Console.Write(sb.ToString());
    }

    /// <summary>
    /// Exporta o Chunk como uma imagem PPM P3 (Portable Pixmap) pura.
    /// </summary>
    public static void ExportToPpm(string filePath, Chunk chunk, HeatmapMode mode)
    {
        using var writer = new StreamWriter(filePath, false, Encoding.ASCII);
        writer.WriteLine("P3");
        writer.WriteLine($"{Chunk.Width} {Chunk.Height}");
        writer.WriteLine("255");

        for (int y = 0; y < Chunk.Height; y++)
        {
            for (int x = 0; x < Chunk.Width; x++)
            {
                int idx = Chunk.GetIndex(x, y);
                var (r, g, b, _) = GetCellColorAndGlyph(chunk, idx, mode, null, null);
                writer.WriteLine($"{r} {g} {b}");
            }
        }
    }

    private static (byte r, byte g, byte b, char glyph) GetCellColorAndGlyph(
        Chunk chunk,
        int idx,
        HeatmapMode mode,
        InfluenceMap? influence,
        AnimalAgent? agent)
    {
        // Se houver animal desenha o glifo do animal
        if (agent.HasValue)
        {
            char c = agent.Value.Diet == AnimalDiet.Carnivore ? 'W' : 'H'; // Wolf / Herbivore
            return (255, 255, 0, c);
        }

        switch (mode)
        {
            case HeatmapMode.Temperature:
            {
                float t = Math.Clamp((chunk.Temperature[idx] + 20f) / 80f, 0f, 1f);
                byte r = (byte)(t * 255);
                byte b = (byte)((1f - t) * 255);
                byte g = (byte)(MathF.Sin(t * MathF.PI) * 180);
                return (r, g, b, ' ');
            }

            case HeatmapMode.MoistureAndWater:
            {
                if (chunk.SurfaceWater[idx] > 0.5f)
                {
                    return (30, 90, 220, '~'); // Água superficial
                }
                float m = Math.Clamp(chunk.Moisture[idx], 0f, 1f);
                byte b = (byte)(m * 200 + 40);
                byte g = (byte)(m * 150 + 50);
                return (20, g, b, ' ');
            }

            case HeatmapMode.Biomass:
            {
                float bio = Math.Clamp(chunk.Biomass[idx] / 100f, 0f, 1f);
                byte g = (byte)(bio * 220 + 35);
                byte r = (byte)((1f - bio) * 80 + 30);
                return (r, g, 20, bio > 0.4f ? '*' : ' ');
            }

            case HeatmapMode.InfluenceDanger:
            {
                float danger = influence != null ? Math.Clamp(influence.DangerGradient[idx] / 100f, 0f, 1f) : 0f;
                byte r = (byte)(danger * 255);
                return (r, 20, 20, danger > 0.3f ? '!' : ' ');
            }

            case HeatmapMode.CompositeBiome:
            default:
            {
                ushort mat = chunk.MaterialId[idx];
                if (mat == MaterialCatalog.IdWater || chunk.SurfaceWater[idx] > 1.0f)
                {
                    return (20, 80, 200, '~'); // Lago / Rio
                }
                if (mat == MaterialCatalog.IdIce || chunk.Temperature[idx] < -2f)
                {
                    return (220, 240, 255, '#'); // Gelo / Neve
                }
                if (chunk.Biomass[idx] > 30f)
                {
                    return (34, 139, 34, '^'); // Floresta / Vegetação
                }
                if (mat == MaterialCatalog.IdSand || chunk.Moisture[idx] < 0.05f)
                {
                    return (210, 180, 110, '.'); // Deserto / Areia
                }
                return (120, 90, 60, ' '); // Solo / Terra
            }
        }
    }
}
