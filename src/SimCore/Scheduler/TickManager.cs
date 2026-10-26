using System;
using System.Collections.Generic;

namespace SimCore.Scheduler;

/// <summary>
/// FASE 6: Escalonador Determinístico de Ticks e Fatiamento de Chunks (Chunk Slicing).
/// Opera com Fixed Timestep estrito de 30Hz (33.33ms) e distribui o processamento térmico
/// e hidrológico em lotes por fatia para eliminar engasgos (stuttering).
/// </summary>
public sealed class TickManager
{
    public const float FixedDeltaTime = 1.0f / 30.0f; // 33.33ms (30 ticks/s)
    public const int SlicesPerSecond = 6;              // Termodinâmica a 5Hz dividida em 6 fatias

    public ulong TickCount { get; private set; }
    private double _accumulator;

    /// <summary>
    /// Escala de velocidade da simulação (Ex: 1x, 2x, 4x, 10x, 100x). Padrão = 1.0f.
    /// </summary>
    public float TimeScale { get; set; } = 1.0f;

    public event Action<float>? OnPhysicsTick;         // 30Hz: Animais e entidades
    public event Action<int, int, float>? OnSliceTick; // 5Hz fatiado: (sliceIndex, totalSlices, dt)
    public event Action<float>? OnClimateTick;         // 0.1Hz: Macro-clima (a cada 300 ticks)

    /// <summary>
    /// Define a escala de velocidade da simulação (suporta 1x até 100x).
    /// </summary>
    public void SetSpeed(float speed)
    {
        TimeScale = Math.Clamp(speed, 0.1f, 100.0f);
    }

    /// <summary>
    /// Acumula tempo real decorrido multiplicado pelo TimeScale e executa os ticks determinísticos.
    /// Garante que mesmo com variações de taxa de quadros (FPS jitter), a simulação avance de forma fixa.
    /// </summary>
    public void AdvanceTime(double realDeltaTime)
    {
        _accumulator += realDeltaTime * TimeScale;

        // Limite dinâmico de segurança proporcional à velocidade para evitar espiral de morte
        double maxAccumulator = FixedDeltaTime * Math.Max(5.0, 5.0 * TimeScale);
        if (_accumulator > maxAccumulator)
        {
            _accumulator = maxAccumulator;
        }

        while (_accumulator >= FixedDeltaTime)
        {
            Step();
            _accumulator -= FixedDeltaTime;
        }
    }

    /// <summary>
    /// Executa um único tick determinístico discreto.
    /// </summary>
    public void Step()
    {
        TickCount++;

        // 30Hz (A cada tick): Movimentação de fauna, colisões e inputs
        OnPhysicsTick?.Invoke(FixedDeltaTime);

        // Termodinâmica fatiada: Cada fatia processa 1/6 dos Chunks a cada tick
        int currentSlice = (int)(TickCount % SlicesPerSecond);
        OnSliceTick?.Invoke(currentSlice, SlicesPerSecond, FixedDeltaTime * SlicesPerSecond);

        // 0.1Hz (A cada 300 ticks = 10 segundos): Macro-clima e Gaia loops
        if (TickCount % 300 == 0)
        {
            OnClimateTick?.Invoke(FixedDeltaTime * 300);
        }
    }

    public void Reset()
    {
        TickCount = 0;
        _accumulator = 0.0;
    }
}
