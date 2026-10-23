using System;
using System.Runtime.InteropServices;
using SimCore.SpatialGrid;

namespace SimServer;

/// <summary>
/// Representa a mutação de uma única célula serializada em apenas 8 bytes.
/// Substitui o envio de 32 bytes de floats não-comprimidos.
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 2)]
public readonly struct DeltaCell
{
    public readonly ushort CellIndex;        // 2 bytes: Posição [0..255]
    public readonly ushort MaterialId;       // 2 bytes: Tipo de material
    public readonly ushort QuantizedTemp;    // 2 bytes: Temperatura [-100..1500°C]
    public readonly byte QuantizedMoist;     // 1 byte:  Umidade [0..1]
    public readonly byte QuantizedBiomass;   // 1 byte:  Biomassa [0..100]

    public DeltaCell(ushort index, ushort matId, ushort temp, byte moist, byte biomass)
    {
        CellIndex = index;
        MaterialId = matId;
        QuantizedTemp = temp;
        QuantizedMoist = moist;
        QuantizedBiomass = biomass;
    }
}

/// <summary>
/// FASE 6: Serialização Eficiente, Quantização e Compressão Delta de Chunks.
/// Permite enviar apenas as células que sofreram variações físicas perceptíveis,
/// reduzindo o tráfego de rede em mais de 85%.
/// </summary>
public static class StateSerializer
{
    public const float MinWorldTemp = -100.0f;
    public const float MaxWorldTemp = 1500.0f;

    public static ushort QuantizeTemperature(float temperature)
    {
        float clamped = Math.Clamp(temperature, MinWorldTemp, MaxWorldTemp);
        float normalized = (clamped - MinWorldTemp) / (MaxWorldTemp - MinWorldTemp);
        return (ushort)(normalized * 65535.0f);
    }

    public static float DequantizeTemperature(ushort quantized)
    {
        float normalized = quantized / 65535.0f;
        return MinWorldTemp + normalized * (MaxWorldTemp - MinWorldTemp);
    }

    public static byte QuantizeMoisture(float moisture)
    {
        float clamped = Math.Clamp(moisture, 0f, 1f);
        return (byte)(clamped * 255.0f);
    }

    public static float DequantizeMoisture(byte quantized)
    {
        return quantized / 255.0f;
    }

    public static byte QuantizeBiomass(float biomass)
    {
        float clamped = Math.Clamp(biomass, 0f, 100.0f);
        return (byte)((clamped / 100.0f) * 255.0f);
    }

    public static float DequantizeBiomass(byte quantized)
    {
        return (quantized / 255.0f) * 100.0f;
    }

    /// <summary>
    /// Compara o estado atual do Chunk com o último estado confirmado pelo cliente (previousAck)
    /// e escreve no buffer de saída apenas as células com diferenças relevantes (Delta Compression).
    /// Retorna a quantidade de células modificadas escritas no deltaBuffer.
    /// </summary>
    public static int EncodeDelta(
        Chunk current,
        Chunk? previousAck,
        Span<DeltaCell> deltaBuffer,
        float tempDeltaThreshold = 0.5f,
        float moistDeltaThreshold = 0.05f)
    {
        int writtenCount = 0;

        for (int i = 0; i < Chunk.CellCount; i++)
        {
            bool hasChanged = false;

            if (previousAck == null)
            {
                // Snapshot completo inicial
                hasChanged = true;
            }
            else
            {
                if (current.MaterialId[i] != previousAck.MaterialId[i])
                {
                    hasChanged = true;
                }
                else if (MathF.Abs(current.Temperature[i] - previousAck.Temperature[i]) >= tempDeltaThreshold)
                {
                    hasChanged = true;
                }
                else if (MathF.Abs(current.Moisture[i] - previousAck.Moisture[i]) >= moistDeltaThreshold)
                {
                    hasChanged = true;
                }
                else if (MathF.Abs(current.Biomass[i] - previousAck.Biomass[i]) >= 2.0f)
                {
                    hasChanged = true;
                }
            }

            if (hasChanged && writtenCount < deltaBuffer.Length)
            {
                deltaBuffer[writtenCount++] = new DeltaCell(
                    index: (ushort)i,
                    matId: current.MaterialId[i],
                    temp: QuantizeTemperature(current.Temperature[i]),
                    moist: QuantizeMoisture(current.Moisture[i]),
                    biomass: QuantizeBiomass(current.Biomass[i])
                );
            }
        }

        return writtenCount;
    }

    /// <summary>
    /// Aplica um pacote de deltas recebido da rede sobre um Chunk local (lado do Cliente).
    /// </summary>
    public static void ApplyDelta(Chunk target, ReadOnlySpan<DeltaCell> deltas)
    {
        for (int i = 0; i < deltas.Length; i++)
        {
            ref readonly var delta = ref deltas[i];
            int idx = delta.CellIndex;

            target.MaterialId[idx] = delta.MaterialId;
            target.Temperature[idx] = DequantizeTemperature(delta.QuantizedTemp);
            target.Moisture[idx] = DequantizeMoisture(delta.QuantizedMoist);
            target.Biomass[idx] = DequantizeBiomass(delta.QuantizedBiomass);
        }
    }
}
