using System;

namespace SimServer;

/// <summary>
/// FASE 6: Gerenciador de rede UDP / Sockets para o servidor Headless.
/// Responsável pelo envio e recepção de pacotes comprimidos sem alocações contínuas.
/// </summary>
public sealed class NetworkManager
{
    public ushort Port { get; }
    public bool IsRunning { get; private set; }

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
}
