using System.Numerics;

namespace SimCore.Climate;

/// <summary>
/// FASE 3: Célula Macro-Atmosférica (1 MacroCell abrange 8x8 Chunks = 128x128 células locais).
/// Armazena pressões e fluxos vetoriais de vento para transporte advectivo de umidade e calor.
/// </summary>
public struct MacroCell
{
    public float Pressure;      // hPa / Pressão barométrica
    public float Temperature;   // Temperatura média da coluna de ar (°C)
    public float Humidity;      // Umidade relativa / vapor d'água na massa de ar (0.0 a 1.0)
    public Vector2 WindVector;  // Vetor velocidade do vento (U, V)
    public float Precipitation; // Taxa de chuva precipitada no tick
}
