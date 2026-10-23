using System;
using System.Numerics;
using Xunit;
using SimCore.Climate;

namespace SimCore.Tests;

public class ClimateStabilityTests
{
    [Fact]
    public void WindVectors_BlowFromHighToLowPressure()
    {
        var grid = new ClimateGrid(4, 4);

        // Define célula (1, 1) com alta pressão (1030 hPa) e célula vizinha (2, 1) com baixa pressão (990 hPa)
        for (int i = 0; i < grid.CellCount; i++) grid.Current[i].Pressure = 1013.25f;
        grid.Current[grid.GetIndex(1, 1)].Pressure = 1030f;
        grid.Current[grid.GetIndex(2, 1)].Pressure = 990f;

        ConvectionSolver.SolveWindVectors(grid);

        // O vento na célula (1, 1) deve soprar para o leste (+X) em direção à baixa pressão
        var windAtHigh = grid.Current[grid.GetIndex(1, 1)].WindVector;
        Assert.True(windAtHigh.X > 0f);
    }

    [Fact]
    public void SemiLagrangian_AdvectsMoistureDownwind()
    {
        var grid = new ClimateGrid(8, 8);
        for (int i = 0; i < grid.CellCount; i++)
        {
            grid.Current[i].Pressure = 1013.25f;
            grid.Current[i].Temperature = 20f;
            grid.Current[i].Humidity = 0.1f;
            grid.Current[i].WindVector = new Vector2(1.0f, 0f); // Vento constante soprando para o Leste (+X)
        }

        // Injeta bolha de umidade em X=2, Y=4
        int sourceIdx = grid.GetIndex(2, 4);
        grid.Current[sourceIdx].Humidity = 0.9f;

        // Executa 2 passos de advecção
        for (int step = 0; step < 2; step++)
        {
            ConvectionSolver.StepClimate(grid, 0.5f);
            grid.SwapBuffers();
        }

        // A célula a jusante (X=3, Y=4) deve ter recebido umidade
        int downwindIdx = grid.GetIndex(3, 4);
        Assert.True(grid.Current[downwindIdx].Humidity > 0.1f);
    }

    [Fact]
    public void SaturatedVapor_TriggersCloudCondensationAndRain()
    {
        var grid = new ClimateGrid(4, 4);
        int idx = grid.GetIndex(2, 2);

        // Coluna de ar frio (0°C) com umidade excessiva (0.50 g/m³)
        grid.Current[idx].Temperature = 0f;
        grid.Current[idx].Humidity = 0.50f;
        grid.Current[idx].CloudCover = 0.70f;
        grid.Current[idx].SolarInsolation = 0f;

        ConvectionSolver.StepClimate(grid, 0.5f);
        grid.SwapBuffers();

        // O excesso deve condensar e gerar precipitação
        Assert.True(grid.Current[idx].Precipitation > 0f);
    }

    [Fact]
    public void GaiaFeedback_AlbedoRegulatesSolarHeating()
    {
        var gridClear = new ClimateGrid(2, 2);
        var gridCloudy = new ClimateGrid(2, 2);

        // Céu limpo (albedo = 0) vs Céu nublado (albedo alto = 0.9)
        gridClear.Current[0].Temperature = 20f;
        gridClear.Current[0].SolarInsolation = 1.0f;
        gridClear.Current[0].CloudCover = 0.0f;

        gridCloudy.Current[0].Temperature = 20f;
        gridCloudy.Current[0].SolarInsolation = 1.0f;
        gridCloudy.Current[0].CloudCover = 0.9f;

        ConvectionSolver.StepClimate(gridClear, 0.2f);
        ConvectionSolver.StepClimate(gridCloudy, 0.2f);

        // A célula limpa deve absorver mais radiação e aquecer mais que a coberta por nuvens
        Assert.True(gridClear.Next[0].Temperature > gridCloudy.Next[0].Temperature);
    }

    [Fact]
    public void ExtendedSimulation_10000Ticks_NoNumericalDivergence()
    {
        // DoD Fase 3: Roda 10.000 ciclos contínuos sem divergência numérica, NaNs ou infinidades
        var grid = new ClimateGrid(16, 16);
        grid.InitializeStandardPlanetary(equatorTemp: 30f, poleTemp: -20f);

        float dt = 0.1f;

        for (int cycle = 0; cycle < 10000; cycle++)
        {
            ConvectionSolver.StepClimate(grid, dt);
            grid.SwapBuffers();
        }

        // Validação de estabilidade em todas as células após 10.000 iterações
        for (int i = 0; i < grid.CellCount; i++)
        {
            ref readonly var c = ref grid.Current[i];

            Assert.False(float.IsNaN(c.Temperature), $"NaN detectado em Temperature no índice {i}");
            Assert.False(float.IsInfinity(c.Temperature), $"Infinito detectado em Temperature no índice {i}");
            Assert.InRange(c.Temperature, -70f, 75f); // Faixa planetária estável regulada por Gaia

            Assert.False(float.IsNaN(c.Pressure), $"NaN detectado em Pressure no índice {i}");
            Assert.InRange(c.Pressure, 850f, 1150f);

            Assert.False(float.IsNaN(c.Humidity), $"NaN detectado em Humidity no índice {i}");
            Assert.InRange(c.Humidity, 0f, 2.0f);

            Assert.False(float.IsNaN(c.WindVector.X));
            Assert.False(float.IsNaN(c.WindVector.Y));
        }
    }
}
