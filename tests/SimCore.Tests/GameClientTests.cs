using System;
using System.IO;
using System.Numerics;
using Xunit;
using GameClient.Audio;
using GameClient.Prediction;
using GameClient.Rendering;
using SimCore.Climate;
using SimCore.Matter;
using SimCore.SpatialGrid;
using SimVisualizer;

namespace SimCore.Tests;

public class GameClientTests
{
    [Fact]
    public void LayerCompositor_Sunlight_ComputesCorrectColorsByTimeOfDay()
    {
        var compositor = new LayerCompositor();
        var macro = new MacroCell { CloudCover = 0f, SolarInsolation = 1.0f };

        // Meio-dia (12h) -> Luz diurna plena
        compositor.TimeOfDayHour = 12.0f;
        var noonLight = compositor.ComputeSunlight(macro);
        Assert.True(noonLight.W > 0.8f); // Intensidade alta

        // Meia-noite (0h) -> Luz noturna azulada
        compositor.TimeOfDayHour = 0.0f;
        var nightLight = compositor.ComputeSunlight(macro);
        Assert.True(nightLight.Z > nightLight.X); // Componente azul maior que vermelho
        Assert.True(nightLight.W < 0.2f);        // Intensidade baixa
    }

    [Fact]
    public void LayerCompositor_WeatherParticles_SpawnsSnowWhenFreezing()
    {
        var compositor = new LayerCompositor();
        var freezeMacro = new MacroCell
        {
            Temperature = -10.0f,
            Precipitation = 0.5f,
            WindVector = new Vector2(1f, 0f)
        };

        var buffer = new WeatherParticle[32];
        int count = compositor.SpawnWeatherParticles(freezeMacro, buffer, 800f, 600f);

        Assert.True(count > 0);
        // Velocidade vertical de neve (mais lenta que chuva)
        Assert.True(buffer[0].Velocity.Y < 150.0f);
    }

    [Fact]
    public void ClientPrediction_PredictMove_UpdatesPositionInstantly()
    {
        var pred = new ClientPrediction();
        pred.Initialize(new Vector2(5.0f, 5.0f));

        // Move para a direita (+X)
        pred.PredictMove(new Vector2(1f, 0f), moveSpeed: 10.0f, dt: 0.1f);

        // Deve ter avançado exatamente 1.0 unidade (10 * 0.1)
        Assert.Equal(6.0f, pred.PredictedPosition.X, precision: 2);
        Assert.Equal(5.0f, pred.PredictedPosition.Y, precision: 2);
    }

    [Fact]
    public void ClientPrediction_Reconcile_SmoothsMinorDeviations()
    {
        var pred = new ClientPrediction();
        pred.Initialize(new Vector2(10.0f, 10.0f));

        // Posição do servidor levemente discrepante (10.2)
        pred.Reconcile(new Vector2(10.2f, 10.0f));

        // Deve interpolar suavemente em direção a 10.2
        Assert.True(pred.PredictedPosition.X > 10.0f);
        Assert.True(pred.PredictedPosition.X <= 10.2f);
    }

    [Fact]
    public void ClientPrediction_InterpolateRemoteEntity_InterpolatesSmoothly()
    {
        var snapA = new EntitySnapshot(100, new Vector2(0f, 0f), 1.0);
        var snapB = new EntitySnapshot(101, new Vector2(10f, 0f), 2.0);

        // Timestamp intermediário (t = 1.5s -> meio do caminho)
        var pos = ClientPrediction.InterpolateRemoteEntity(snapA, snapB, 1.5);

        Assert.Equal(5.0f, pos.X, precision: 1);
        Assert.Equal(0.0f, pos.Y, precision: 1);
    }

    [Fact]
    public void AtmosphericAudio_ComputesWindAndRainVolumes_FromClimate()
    {
        var stormMacro = new MacroCell
        {
            WindVector = new Vector2(2.5f, 1.0f), // Vento forte
            Precipitation = 0.8f,                 // Chuva intensa
            Temperature = 15f
        };

        var audio = AtmosphericAudio.ComputeAudioMix(stormMacro, 14.0f);

        Assert.True(audio.WindVolume > 0.8f);
        Assert.True(audio.RainVolume > 0.8f);
        Assert.False(audio.IsSnowfall);
    }

    [Fact]
    public void HeatmapRenderer_ExportPpm_GeneratesValidP3Format()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdWater, 20f, 0.5f, 0f);

        string tempPath = Path.Combine(Path.GetTempPath(), $"test_chunk_{Guid.NewGuid():N}.ppm");

        try
        {
            HeatmapRenderer.ExportToPpm(tempPath, chunk, HeatmapMode.CompositeBiome);

            Assert.True(File.Exists(tempPath));
            string header = File.ReadLines(tempPath).Take(3).Aggregate((a, b) => a + "\n" + b);

            Assert.Contains("P3", header);
            Assert.Contains($"{Chunk.Width} {Chunk.Height}", header);
        }
        finally
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
        }
    }
}
