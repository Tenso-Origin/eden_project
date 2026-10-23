using System;
using System.Collections.Generic;

namespace SimServer;

/// <summary>
/// FASE 6: Filtro espacial de Área de Interesse (Area of Interest - AoI).
/// Garante que cada cliente receba apenas deltas dos Chunks contidos no seu raio de visão.
/// </summary>
public sealed class AreaOfInterest
{
    public int ViewRadiusChunks { get; set; } = 4; // Raio de visão de 4 chunks em torno do jogador

    public bool IsInView(int playerChunkX, int playerChunkY, int chunkX, int chunkY)
    {
        int dx = Math.Abs(playerChunkX - chunkX);
        int dy = Math.Abs(playerChunkY - chunkY);
        return dx <= ViewRadiusChunks && dy <= ViewRadiusChunks;
    }
}
