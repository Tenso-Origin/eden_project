using System;
using System.Numerics;

namespace GameClient.Prediction;

public readonly record struct EntitySnapshot(ulong ServerTick, Vector2 Position, double Timestamp);

/// <summary>
/// PÓS-FASE 6: Predição de Movimento do Cliente (Client-Side Prediction)
/// e Interpolação Hermite/Linear de Entidades Remotas.
/// Elimina latência percebida local e garante animação suave a 60/144 FPS
/// a partir de pacotes de 30Hz do servidor.
/// </summary>
public sealed class ClientPrediction
{
    // --- Predição do Jogador Local ---
    public Vector2 PredictedPosition { get; private set; }

    public void Initialize(Vector2 startingPos)
    {
        PredictedPosition = startingPos;
    }

    /// <summary>
    /// Aplica input instantâneo no cliente (Zero Lag).
    /// </summary>
    public void PredictMove(Vector2 inputDir, float moveSpeed, float dt)
    {
        if (inputDir.LengthSquared() > 0.001f)
        {
            var normalized = Vector2.Normalize(inputDir);
            PredictedPosition += normalized * moveSpeed * dt;
        }
    }

    /// <summary>
    /// Reconcilia a posição predita contra a posição autoritativa confirmada pelo servidor.
    /// Corrige eventuais discrepâncias (snap suave se o erro for aceitável).
    /// </summary>
    public void Reconcile(Vector2 serverAuthoritativePos, float maxErrorThreshold = 1.5f)
    {
        float error = Vector2.Distance(PredictedPosition, serverAuthoritativePos);
        if (error > maxErrorThreshold)
        {
            // Erro grande (desync ou colisão): força a posição do servidor
            PredictedPosition = serverAuthoritativePos;
        }
        else if (error > 0.05f)
        {
            // Erro sutil: interpola suavemente em direção à verdade do servidor
            PredictedPosition = Vector2.Lerp(PredictedPosition, serverAuthoritativePos, 0.25f);
        }
    }

    // --- Interpolação de Entidades Remotas (Animais / Outros Jogadores) ---
    /// <summary>
    /// Interpola a posição de uma entidade remota entre dois snapshots sucessivos do servidor.
    /// </summary>
    public static Vector2 InterpolateRemoteEntity(
        in EntitySnapshot from,
        in EntitySnapshot to,
        double renderTimestamp)
    {
        double duration = to.Timestamp - from.Timestamp;
        if (duration <= 0.0001) return to.Position;

        float t = (float)Math.Clamp((renderTimestamp - from.Timestamp) / duration, 0.0, 1.0);

        // Interpolação cúbica suave (SmoothStep: 3t² - 2t³)
        float smoothT = t * t * (3.0f - 2.0f * t);
        return Vector2.Lerp(from.Position, to.Position, smoothT);
    }
}
