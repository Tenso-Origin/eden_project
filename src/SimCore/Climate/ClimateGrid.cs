using System;
using System.Runtime.CompilerServices;

namespace SimCore.Climate;

/// <summary>
/// FASE 3: Grade Atmosférica 2D Contígua em Memória com Double Buffering.
/// Ex: grade de 64x64 células cobre um mundo de 512x512 chunks com baixo custo de CPU.
/// </summary>
public sealed class ClimateGrid
{
    public readonly int Width;
    public readonly int Height;
    public readonly int CellCount;

    public MacroCell[] Current;
    public MacroCell[] Next;

    public ClimateGrid(int width, int height)
    {
        Width = width;
        Height = height;
        CellCount = width * height;

        Current = new MacroCell[CellCount];
        Next = new MacroCell[CellCount];
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public int GetIndex(int x, int y) => y * Width + x;

    public void PrepareNextBuffer()
    {
        Array.Copy(Current, Next, CellCount);
    }

    public void SwapBuffers()
    {
        (Current, Next) = (Next, Current);
    }

    /// <summary>
    /// Inicializa a atmosfera com gradiente latitudinal de temperatura e insolação solar.
    /// Latitude: Y=0 (Polo Sul / Frio), Y=Height/2 (Equador / Quente), Y=Height-1 (Polo Norte / Frio).
    /// </summary>
    public void InitializeStandardPlanetary(float equatorTemp = 32f, float poleTemp = -25f)
    {
        float midY = (Height - 1) * 0.5f;

        for (int y = 0; y < Height; y++)
        {
            // Fator de latitude: 1.0 no equador, 0.0 nos polos
            float latFactor = 1.0f - MathF.Abs((y - midY) / midY);
            float temp = poleTemp + (equatorTemp - poleTemp) * latFactor;
            float solar = latFactor; // Radiação solar máxima no equador

            for (int x = 0; x < Width; x++)
            {
                int idx = GetIndex(x, y);
                Current[idx] = new MacroCell
                {
                    Pressure = 1013.25f,
                    Temperature = temp,
                    Humidity = 0.5f,
                    WindVector = System.Numerics.Vector2.Zero,
                    Precipitation = 0f,
                    CloudCover = 0.2f,
                    SolarInsolation = solar,
                    Elevation = 0f
                };
            }
        }
    }
}
