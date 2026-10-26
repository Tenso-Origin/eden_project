using System;
using System.Runtime.CompilerServices;

namespace SimCore.SpatialGrid;

/// <summary>
/// Representa um Chunk espacial de 16x16 células (256 células) usando Structure of Arrays (SoA).
/// Arrays planos contíguos em memória permitem carregamento sequencial em Cache L1 e vetorização SIMD.
/// Suporta Double Buffering completo para execução multithreaded sem locks.
/// </summary>
public sealed class Chunk
{
    public const int Width = 16;
    public const int Height = 16;
    public const int CellCount = Width * Height; // 256 células

    // Coordenadas espaciais do Chunk no mundo
    public readonly int ChunkX;
    public readonly int ChunkY;

    // --- Structure of Arrays (SoA) - Estado Atual T (Leitura) ---
    public ushort[] MaterialId = new ushort[CellCount];
    public float[] Temperature = new float[CellCount];
    public float[] Moisture = new float[CellCount];        // Umidade intersticial do solo (0.0 a 1.0)
    public float[] SurfaceWater = new float[CellCount];    // Lâmina d'água superficial livre (mm ou litros/m²)
    public float[] SuspendedSediment = new float[CellCount]; // Sedimento sólido carreado pelo fluxo (kg/m²)
    public float[] WaterDischarge = new float[CellCount];    // Vazão hídrica acumulada da bacia (Q)
    public float[] LakeWater = new float[CellCount];        // Volume estagnado em depressões endorreicas (lagos)
    public float[] OrganicDetritus = new float[CellCount];  // Carcaças e matéria orgânica em decomposição (Tabela 4)
    public float[] Grains = new float[CellCount];           // Arroz Silvestre da Várzea (Oryza glumaepatula) em kg/m²
    public readonly float[] Elevation = new float[CellCount];
    public readonly float[] Biomass = new float[CellCount];

    // --- Double Buffering - Próximo Estado T+1 (Escrita sem Data Race) ---
    public ushort[] NextMaterialId = new ushort[CellCount];
    public float[] NextTemperature = new float[CellCount];
    public float[] NextMoisture = new float[CellCount];
    public float[] NextSurfaceWater = new float[CellCount];
    public float[] NextSuspendedSediment = new float[CellCount];
    public float[] NextWaterDischarge = new float[CellCount];
    public float[] NextLakeWater = new float[CellCount];
    public float[] NextOrganicDetritus = new float[CellCount];
    public float[] NextGrains = new float[CellCount];

    public Chunk(int chunkX, int chunkY)
    {
        ChunkX = chunkX;
        ChunkY = chunkY;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int GetIndex(int x, int y) => (y << 4) | x; // y * 16 + x

    /// <summary>
    /// Copia o estado atual para o buffer de escrita antes do tick, garantindo que
    /// células não modificadas mantenham seus valores prévios.
    /// </summary>
    public void PrepareNextBuffer()
    {
        Array.Copy(MaterialId, NextMaterialId, CellCount);
        Array.Copy(Temperature, NextTemperature, CellCount);
        Array.Copy(Moisture, NextMoisture, CellCount);
        Array.Copy(SurfaceWater, NextSurfaceWater, CellCount);
        Array.Copy(SuspendedSediment, NextSuspendedSediment, CellCount);
        Array.Copy(WaterDischarge, NextWaterDischarge, CellCount);
        Array.Copy(LakeWater, NextLakeWater, CellCount);
        Array.Copy(OrganicDetritus, NextOrganicDetritus, CellCount);
        Array.Copy(Grains, NextGrains, CellCount);
    }

    /// <summary>
    /// Inverte os ponteiros dos buffers ao término do tick (custo O(1)).
    /// </summary>
    public void SwapBuffers()
    {
        (MaterialId, NextMaterialId) = (NextMaterialId, MaterialId);
        (Temperature, NextTemperature) = (NextTemperature, Temperature);
        (Moisture, NextMoisture) = (NextMoisture, Moisture);
        (SurfaceWater, NextSurfaceWater) = (NextSurfaceWater, SurfaceWater);
        (SuspendedSediment, NextSuspendedSediment) = (NextSuspendedSediment, SuspendedSediment);
        (WaterDischarge, NextWaterDischarge) = (NextWaterDischarge, WaterDischarge);
        (LakeWater, NextLakeWater) = (NextLakeWater, LakeWater);
        (OrganicDetritus, NextOrganicDetritus) = (NextOrganicDetritus, OrganicDetritus);
        (Grains, NextGrains) = (NextGrains, Grains);
    }

    /// <summary>
    /// Preenche o Chunk com valores homogêneos para testes ou inicialização de bioma.
    /// </summary>
    public void Fill(ushort matId, float temp, float moisture, float elevation, float surfaceWater = 0f, float lakeWater = 0f)
    {
        for (int i = 0; i < CellCount; i++)
        {
            MaterialId[i] = matId;
            Temperature[i] = temp;
            Moisture[i] = moisture;
            Elevation[i] = elevation;
            SurfaceWater[i] = surfaceWater;
            LakeWater[i] = lakeWater;
            SuspendedSediment[i] = 0f;
            WaterDischarge[i] = 0f;
            OrganicDetritus[i] = 0f;
            Grains[i] = 0f;

            NextMaterialId[i] = matId;
            NextTemperature[i] = temp;
            NextMoisture[i] = moisture;
            NextSurfaceWater[i] = surfaceWater;
            NextLakeWater[i] = lakeWater;
            NextSuspendedSediment[i] = 0f;
            NextWaterDischarge[i] = 0f;
            NextOrganicDetritus[i] = 0f;
            NextGrains[i] = 0f;
        }
    }
}
