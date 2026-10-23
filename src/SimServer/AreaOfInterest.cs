using System;
using System.Collections.Generic;

namespace SimServer;

public readonly record struct ChunkCoord(int X, int Y);

/// <summary>
/// FASE 6: Sistema de Área de Interesse (Area of Interest - AoI) Multi-Player.
/// Filtra o streaming de pacotes de modo que cada cliente receba atualizações exclusivamente
/// dos Chunks contidos na sua vizinhança de visão.
/// </summary>
public sealed class AreaOfInterest
{
    public int RadiusChunks { get; set; } = 3; // Raio quadrado de visão: 7x7 = 49 chunks

    private readonly Dictionary<int, ChunkCoord> _playerPositions = new();

    public void RegisterPlayer(int playerId, int initialChunkX, int initialChunkY)
    {
        _playerPositions[playerId] = new ChunkCoord(initialChunkX, initialChunkY);
    }

    public void RemovePlayer(int playerId)
    {
        _playerPositions.Remove(playerId);
    }

    public bool TryGetPlayerCoord(int playerId, out ChunkCoord coord)
    {
        return _playerPositions.TryGetValue(playerId, out coord);
    }

    /// <summary>
    /// Atualiza a posição do jogador e retorna os Chunks que acabaram de entrar no raio de visão (precisam de snapshot completo)
    /// e os Chunks que saíram (podem ser descarregados do cache local do cliente).
    /// </summary>
    public (List<ChunkCoord> entered, List<ChunkCoord> exited) MovePlayer(
        int playerId,
        int newChunkX,
        int newChunkY)
    {
        var entered = new List<ChunkCoord>();
        var exited = new List<ChunkCoord>();

        if (!_playerPositions.TryGetValue(playerId, out var oldCoord))
        {
            _playerPositions[playerId] = new ChunkCoord(newChunkX, newChunkY);
            // Todos os chunks entram
            PopulateRadius(newChunkX, newChunkY, RadiusChunks, entered);
            return (entered, exited);
        }

        if (oldCoord.X == newChunkX && oldCoord.Y == newChunkY)
        {
            return (entered, exited);
        }

        _playerPositions[playerId] = new ChunkCoord(newChunkX, newChunkY);

        // Detecta quais chunks entraram e quais saíram
        var oldSet = new HashSet<ChunkCoord>();
        PopulateRadiusSet(oldCoord.X, oldCoord.Y, RadiusChunks, oldSet);

        var newSet = new HashSet<ChunkCoord>();
        PopulateRadiusSet(newChunkX, newChunkY, RadiusChunks, newSet);

        foreach (var c in newSet)
        {
            if (!oldSet.Contains(c)) entered.Add(c);
        }

        foreach (var c in oldSet)
        {
            if (!newSet.Contains(c)) exited.Add(c);
        }

        return (entered, exited);
    }

    public bool IsChunkVisibleTo(int playerId, int chunkX, int chunkY)
    {
        if (!_playerPositions.TryGetValue(playerId, out var p)) return false;
        return Math.Abs(p.X - chunkX) <= RadiusChunks && Math.Abs(p.Y - chunkY) <= RadiusChunks;
    }

    private static void PopulateRadius(int cx, int cy, int radius, List<ChunkCoord> list)
    {
        for (int dy = -radius; dy <= radius; dy++)
        {
            for (int dx = -radius; dx <= radius; dx++)
            {
                list.Add(new ChunkCoord(cx + dx, cy + dy));
            }
        }
    }

    private static void PopulateRadiusSet(int cx, int cy, int radius, HashSet<ChunkCoord> set)
    {
        for (int dy = -radius; dy <= radius; dy++)
        {
            for (int dx = -radius; dx <= radius; dx++)
            {
                set.Add(new ChunkCoord(cx + dx, cy + dy));
            }
        }
    }
}
