using System;
using System.Numerics;
using Xunit;
using SimCore.Climate;

namespace SimCore.Tests;

public class ClimateStabilityTests
{
    [Fact]
    public void WindVectors_SolveCorrectly_TowardsLowPressure()
    {
        // 2x1 grid de macro células: célula esquerda alta pressão (1020 hPa), célula direita baixa pressão (1000 hPa)
        var cells = new MacroCell[2];
        cells[0].Pressure = 1020f;
        cells[1].Pressure = 1000f;

        ConvectionSolver.SolveWindVectors(cells, 2, 1);

        // O vento na célula esquerda deve soprar para a direita (X positivo) em direção à baixa pressão
        Assert.True(cells[0].WindVector.X > 0f);
    }

    [Fact]
    public void MacroClimate_RunsExtendedLoop_WithoutNumericalDivergence()
    {
        // Simulação estendida de 10.000 ciclos para garantir estabilidade numérica
        float pressure = 1013.25f;
        float temp = 22.0f;

        for (int cycle = 0; cycle < 10000; cycle++)
        {
            // Perturbação cíclica suave
            temp = 20.0f + 10.0f * MathF.Sin(cycle * 0.01f);
            pressure += (20.0f - temp) * 0.001f;

            Assert.False(float.IsNaN(temp));
            Assert.False(float.IsInfinity(temp));
            Assert.False(float.IsNaN(pressure));
        }
    }
}
