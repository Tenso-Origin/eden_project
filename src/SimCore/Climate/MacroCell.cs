using System.Numerics;
using System.Runtime.InteropServices;

namespace SimCore.Climate;

/// <summary>
/// FASE 3: Célula Macro-Atmosférica (1 MacroCell abrange 8x8 Chunks = 128x128 células locais).
/// Armazena pressões e fluxos vetoriais de vento para transporte advectivo de umidade e calor,
/// além de variáveis para laços de retroalimentação de Gaia (albedo e cobertura de nuvens).
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct MacroCell
{
    public float Pressure;         // hPa / Pressão barométrica (~1013.25f padrão)
    public float Temperature;      // Temperatura média da coluna de ar (°C)
    public float Humidity;         // Umidade absoluta / vapor d'água na massa de ar (g/m³ ou normalizado 0 a 1)
    public Vector2 WindVector;     // Vetor velocidade do vento em células/tick (U, V)
    public float Precipitation;    // Taxa de chuva precipitada no tick (mm/tick)
    public float CloudCover;       // Fração de cobertura de nuvens (0.0 a 1.0 - Albedo)
    public float SolarInsolation;  // Radiação solar incidente (W/m² normalizada)
    public float Elevation;        // Altitude média continental (metros)
}
