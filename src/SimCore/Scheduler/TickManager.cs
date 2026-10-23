using System;

namespace SimCore.Scheduler;

/// <summary>
/// FASE 6 (Parte 1): Escalonador Determinístico de Ticks.
/// Opera em Fixed Timestep de 30Hz (33.33ms por tick).
/// Distribui a carga de processamento via operador módulo (%) para eliminar stuttering.
/// </summary>
public sealed class TickManager
{
    public const float FixedDeltaTime = 1.0f / 30.0f; // 33.33ms (30 ticks/s)

    public ulong TickCount { get; private set; }

    public event Action<float>? OnPhysicsTick;         // 30Hz: Animais e entidades
    public event Action<float>? OnThermodynamicsTick;  // 5Hz (tick % 6 == 0): Calor e água
    public event Action<float>? OnClimateTick;         // 0.1Hz (tick % 300 == 0): Macro-clima e Gaia loops

    public void Step()
    {
        TickCount++;

        // 30Hz (A cada tick): Física, movimento de fauna e inputs
        OnPhysicsTick?.Invoke(FixedDeltaTime);

        // 5Hz (A cada 6 ticks): Termodinâmica e difusão local
        if (TickCount % 6 == 0)
        {
            OnThermodynamicsTick?.Invoke(FixedDeltaTime * 6);
        }

        // 0.1Hz (A cada 300 ticks = 10 segundos): Macro-clima e ecossistema global
        if (TickCount % 300 == 0)
        {
            OnClimateTick?.Invoke(FixedDeltaTime * 300);
        }
    }

    public void Reset()
    {
        TickCount = 0;
    }
}
