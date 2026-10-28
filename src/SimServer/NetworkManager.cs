using System;
using System.Collections.Generic;
using SimCore.Scheduler;
using SimCore.SpatialGrid;

namespace SimServer;

public delegate void DeltaPacketSender(int playerId, ReadOnlySpan<DeltaCell> delta);

/// <summary>
/// FASE 6: Gerenciador de Rede e Sincronização do Servidor Headless.
/// Orquestra sessões de clientes, filtragem de Área de Interesse (AoI)
/// e empacotamento de deltas quantizados sem alocação no heap.
/// </summary>
public sealed class NetworkManager
{
    public ushort Port { get; }
    public bool IsRunning { get; private set; }

    public AreaOfInterest AoI { get; } = new();
    private readonly DeltaCell[] _sendBuffer = new DeltaCell[Chunk.CellCount];

    public NetworkManager(ushort port = 7777)
    {
        Port = port;
    }

    public void Start()
    {
        IsRunning = true;
    }

    public void Stop()
    {
        IsRunning = false;
    }

    /// <summary>
    /// Serializa as alterações de um Chunk ativo e despacha o delta exclusivamente
    /// para os jogadores que possuem esse Chunk visível na sua AoI.
    /// </summary>
    public int BroadcastChunkDelta(
        Chunk currentChunk,
        Chunk? previousAck,
        IEnumerable<int> playerIds,
        DeltaPacketSender packetSender)
    {
        // Codifica os deltas uma única vez no buffer estático reutilizável (Zero GC)
        int deltaCount = StateSerializer.EncodeDelta(currentChunk, previousAck, _sendBuffer);

        if (deltaCount == 0) return 0;

        var deltaSpan = new ReadOnlySpan<DeltaCell>(_sendBuffer, 0, deltaCount);

        foreach (var playerId in playerIds)
        {
            if (AoI.IsChunkVisibleTo(playerId, currentChunk.ChunkX, currentChunk.ChunkY))
            {
                packetSender(playerId, deltaSpan);
            }
        }

        return deltaCount;
    }
}
