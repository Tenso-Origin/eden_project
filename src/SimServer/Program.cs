using System;
using SimCore.Scheduler;

namespace SimServer;

internal static class Program
{
    private static void Main(string[] args)
    {
        Console.WriteLine("=== Projeto Biosfera: Servidor de Simulação Headless (FASE 6) ===");
        var scheduler = new TickManager();
        var network = new NetworkManager();

        network.Start();
        Console.WriteLine($"[Rede] Servidor iniciado na porta {network.Port}.");
        Console.WriteLine($"[Scheduler] Fixed Timestep ativo ({TickManager.FixedDeltaTime * 1000f:F2}ms por tick).");
    }
}
