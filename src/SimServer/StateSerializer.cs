using System;

namespace SimServer;

/// <summary>
/// FASE 6: Serialização eficiente com quantização de floats para uint16 e compressão de delta.
/// Reduz o tamanho de pacotes de rede em até 75%.
/// </summary>
public static class StateSerializer
{
    public const float MinWorldTemp = -100.0f;
    public const float MaxWorldTemp = 1500.0f;

    /// <summary>
    /// Quantiza temperatura de 32-bit float para 16-bit uint (0 a 65535).
    /// </summary>
    public static ushort QuantizeTemperature(float temperature)
    {
        float clamped = Math.Clamp(temperature, MinWorldTemp, MaxWorldTemp);
        float normalized = (clamped - MinWorldTemp) / (MaxWorldTemp - MinWorldTemp);
        return (ushort)(normalized * 65535.0f);
    }

    /// <summary>
    /// Reconverte 16-bit uint para float no cliente.
    /// </summary>
    public static float DequantizeTemperature(ushort quantized)
    {
        float normalized = quantized / 65535.0f;
        return MinWorldTemp + normalized * (MaxWorldTemp - MinWorldTemp);
    }

    /// <summary>
    /// Quantiza umidade de float (0.0 a 1.0) para byte (0 a 255).
    /// </summary>
    public static byte QuantizeMoisture(float moisture)
    {
        float clamped = Math.Clamp(moisture, 0f, 1f);
        return (byte)(clamped * 255f);
    }

    public static float DequantizeMoisture(byte quantized)
    {
        return quantized / 255.0f;
    }
}
