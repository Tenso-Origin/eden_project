using System;
using System.Numerics;

namespace SimCore.Climate;

/// <summary>
/// FASE 3: Solver de convecção e transporte atmosférico (Semi-Lagrangian advection simplificado).
/// Move massas de ar com base no gradiente de pressão barométrica (∇P).
/// </summary>
public static class ConvectionSolver
{
    /// <summary>
    /// Calcula os vetores de vento com base na diferença de pressão entre células vizinhas.
    /// </summary>
    public static void SolveWindVectors(Span<MacroCell> grid, int gridWidth, int gridHeight)
    {
        for (int y = 0; y < gridHeight; y++)
        {
            for (int x = 0; x < gridWidth; x++)
            {
                int idx = y * gridWidth + x;
                ref var cell = ref grid[idx];

                // Gradiente horizontal (dP/dx)
                float pLeft = (x > 0) ? grid[y * gridWidth + (x - 1)].Pressure : cell.Pressure;
                float pRight = (x < gridWidth - 1) ? grid[y * gridWidth + (x + 1)].Pressure : cell.Pressure;
                float gradX = (pRight - pLeft) * 0.5f;

                // Gradiente vertical (dP/dy)
                float pUp = (y > 0) ? grid[(y - 1) * gridWidth + x].Pressure : cell.Pressure;
                float pDown = (y < gridHeight - 1) ? grid[(y + 1) * gridWidth + x].Pressure : cell.Pressure;
                float gradY = (pDown - pUp) * 0.5f;

                // Vento sopra de alta pressão para baixa pressão (-∇P)
                cell.WindVector = new Vector2(-gradX, -gradY);
            }
        }
    }
}
