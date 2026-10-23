using System;
using SimCore.Climate;

namespace GameClient.Audio;

public readonly record struct AudioMixSnapshot(
    float WindVolume,
    float WindPitch,
    float RainVolume,
    bool IsSnowfall,
    float NightAmbienceVolume,
    float DesertDryingVolume
);

/// <summary>
/// PÓS-FASE 6: Gerador de Parâmetros de Áudio Atmosférico Dinâmico.
/// Modula a trilha e efeitos sonoros procedurais (vento, chuva, trovões, silêncio da neve)
/// diretamente a partir das variáveis físicas do Macro-Clima.
/// </summary>
public static class AtmosphericAudio
{
    public static AudioMixSnapshot ComputeAudioMix(in MacroCell macro, float timeOfDayHour)
    {
        // 1. Vento: intensidade calculada a partir da magnitude vetorial
        float windSpeed = macro.WindVector.Length();
        float windVol = Math.Clamp(windSpeed * 1.8f, 0.05f, 1.0f);
        float windPitch = Math.Clamp(0.8f + (windSpeed * 0.4f), 0.7f, 1.6f);

        // 2. Chuva / Precipitação
        bool isSnow = macro.Temperature <= 0f;
        float rainVol = Math.Clamp(macro.Precipitation * 2.5f, 0f, 1.0f);

        // 3. Ambiência Noturna (grilos / brisa calma)
        bool isNight = timeOfDayHour < 5f || timeOfDayHour > 20f;
        float nightVol = isNight && macro.Temperature > 12f && macro.Precipitation < 0.05f ? 0.85f : 0.0f;

        // 4. Clima árido / deserto
        float desertVol = macro.Temperature > 35f && macro.Humidity < 0.1f ? 0.75f : 0.0f;

        return new AudioMixSnapshot(
            WindVolume: windVol,
            WindPitch: windPitch,
            RainVolume: rainVol,
            IsSnowfall: isSnow,
            NightAmbienceVolume: nightVol,
            DesertDryingVolume: desertVol
        );
    }
}
