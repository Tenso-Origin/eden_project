using System;
using System.Numerics;
using SimCore.Climate;
using SimCore.SpatialGrid;

namespace GameClient.Rendering;

public readonly record struct WeatherParticle(Vector2 Position, Vector2 Velocity, float Lifetime);

/// <summary>
/// PÓS-FASE 6: Pipeline de Renderização HD Pixel Art em Camadas e Partículas Climáticas.
/// Desacoplado do Core: recebe os arrays contíguos do Chunk e da MacroCell para
/// computar iluminação 2D dinâmica e emissores de partículas atmosféricas.
/// </summary>
public sealed class LayerCompositor
{
    public float TimeOfDayHour { get; set; } = 12.0f; // 0.0 a 24.0h

    /// <summary>
    /// Calcula a cor e intensidade da luz ambiente global com base no horário e insolação solar.
    /// Retorna cor RGBA normalizada (R, G, B, Intensitade).
    /// </summary>
    public Vector4 ComputeSunlight(in MacroCell macro)
    {
        // Posição solar: Meio-dia (12h) = máximo zênite, 6h/18h = crepúsculo dourado, 0h = noite azul
        float sunAngle = (TimeOfDayHour - 6.0f) / 12.0f * MathF.PI;
        float sunHeight = MathF.Sin(sunAngle);

        if (sunHeight > 0f)
        {
            // Luz diurna filtrada pelo albedo das nuvens
            float cloudFilter = 1.0f - (macro.CloudCover * 0.6f);
            float intensity = sunHeight * cloudFilter * macro.SolarInsolation;

            // Transição quente no nascer/pôr do sol para branco no zênite
            float goldenHour = 1.0f - MathF.Abs(sunHeight - 0.2f) / 0.8f;
            goldenHour = Math.Clamp(goldenHour, 0f, 1f);

            float r = Math.Clamp(1.0f, 0f, 1f);
            float g = Math.Clamp(0.85f + 0.15f * (1.0f - goldenHour), 0f, 1f);
            float b = Math.Clamp(0.65f + 0.35f * (1.0f - goldenHour), 0f, 1f);

            return new Vector4(r, g, b, Math.Clamp(intensity, 0.05f, 1.0f));
        }
        else
        {
            // Luz lunar noturna fria (azulada)
            return new Vector4(0.12f, 0.16f, 0.35f, 0.10f);
        }
    }

    /// <summary>
    /// Emite partículas de chuva ou neve com base na taxa de precipitação e temperatura do Macro-Clima.
    /// </summary>
    public int SpawnWeatherParticles(
        in MacroCell macro,
        Span<WeatherParticle> particleBuffer,
        float screenWidth,
        float screenHeight)
    {
        if (macro.Precipitation <= 0.001f) return 0;

        bool isSnow = macro.Temperature <= 0f;
        int spawnCount = Math.Min(particleBuffer.Length, (int)(macro.Precipitation * 40f));
        var random = Random.Shared;

        Vector2 baseWind = macro.WindVector * 10.0f;
        float fallSpeed = isSnow ? 60.0f : 280.0f;

        for (int i = 0; i < spawnCount; i++)
        {
            float startX = random.NextSingle() * screenWidth;
            float startY = -10.0f;
            var vel = new Vector2(baseWind.X + (random.NextSingle() - 0.5f) * 15f, fallSpeed);

            particleBuffer[i] = new WeatherParticle(
                Position: new Vector2(startX, startY),
                Velocity: vel,
                Lifetime: screenHeight / fallSpeed
            );
        }

        return spawnCount;
    }
}
