using System;
using System.Numerics;
using GameClient.Audio;
using GameClient.Prediction;
using GameClient.Rendering;
using SimCore.Climate;

namespace GameClient;

internal static class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("==========================================================");
        Console.WriteLine("   PROJETO BIOSFERA - GAMECLIENT HD PIXEL ART (PÓS-FASE 6)");
        Console.WriteLine("   Pipeline de Renderização, Predição e Áudio Atmosférico ");
        Console.WriteLine("==========================================================");

        var compositor = new LayerCompositor { TimeOfDayHour = 14.0f }; // 14h (Sol da tarde)
        var prediction = new ClientPrediction();
        prediction.Initialize(new Vector2(10f, 10f));

        var macro = new MacroCell
        {
            Pressure = 1010.0f,
            Temperature = 22.0f,
            Humidity = 0.70f,
            WindVector = new Vector2(0.8f, 0.2f),
            Precipitation = 0.25f, // Chuva moderada
            CloudCover = 0.65f,
            SolarInsolation = 0.90f
        };

        // 1. Iluminação e Partículas
        var sunlight = compositor.ComputeSunlight(macro);
        Console.WriteLine($"[Render] Cor da Luz Solar: (R:{sunlight.X:F2}, G:{sunlight.Y:F2}, B:{sunlight.Z:F2}), Intensidade: {sunlight.W:F2}");

        Span<WeatherParticle> particles = stackalloc WeatherParticle[32];
        int spawned = compositor.SpawnWeatherParticles(macro, particles, 1920f, 1080f);
        Console.WriteLine($"[Partículas] {spawned} gotas de chuva geradas orientadas pelo vento.");

        // 2. Predição Local
        prediction.PredictMove(new Vector2(1f, 0f), moveSpeed: 4.0f, dt: 0.033f);
        Console.WriteLine($"[Predição] Posição Local Predita: ({prediction.PredictedPosition.X:F2}, {prediction.PredictedPosition.Y:F2})");

        // 3. Áudio Atmosférico
        var audio = AtmosphericAudio.ComputeAudioMix(macro, compositor.TimeOfDayHour);
        Console.WriteLine($"[Áudio] Volume do Vento: {audio.WindVolume * 100:F0}% | Volume da Chuva: {audio.RainVolume * 100:F0}%");
    }
}
