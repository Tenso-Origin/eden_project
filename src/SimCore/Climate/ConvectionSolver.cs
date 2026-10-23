using System;
using System.Numerics;
using System.Runtime.CompilerServices;

namespace SimCore.Climate;

/// <summary>
/// FASE 3: Solver de Convecção Atmosférica, Advecção Semi-Lagrangiana e Laços de Retroalimentação de Gaia.
/// Simula vento por gradiente de pressão (-∇P), transporte de massas de ar, chuva por condensação
/// de saturação e albedo de nuvens regulador da temperatura global.
/// </summary>
public static class ConvectionSolver
{
    public const float StandardSeaPressure = 1013.25f;
    public const float ThermalPressureFactor = 1.20f;
    public const float WindFriction = 0.85f;

    /// <summary>
    /// Passo completo da atmosfera:
    /// 1. Atualização Barométrica -> 2. Campo de Vento -> 3. Advecção Semi-Lagrange -> 4. Termodinâmica e Gaia Loops
    /// </summary>
    public static void StepClimate(ClimateGrid grid, float dt)
    {
        ReadOnlySpan<MacroCell> current = grid.Current;
        Span<MacroCell> next = grid.Next;
        int w = grid.Width;
        int h = grid.Height;

        // 1. Atualiza pressões barométricas com base em temperatura e altitude
        UpdatePressureField(grid);

        // 2. Calcula campo vetorial de vento com base em -∇P
        SolveWindVectors(grid);

        // 3. Advecção Semi-Lagrangiana e Balanço de Gaia (Umidade, Nuvens, Chuva e Radiação)
        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = grid.GetIndex(x, y);
                ref readonly var src = ref current[idx];
                ref var dst = ref next[idx];

                // Posição de origem no passado (Backtracking Semi-Lagrange)
                Vector2 wind = src.WindVector;
                float fromX = x - wind.X * dt;
                float fromY = y - wind.Y * dt;

                // Suporte a wrap-around toroidal em X (planeta cilíndrico/esférico)
                fromX = WrapCoord(fromX, w);
                fromY = Math.Clamp(fromY, 0f, h - 1.001f);

                // Amostragem bilinear da massa de ar advectada
                SampleBilinear(current, w, h, fromX, fromY, out float advTemp, out float advHumidity);

                // --- Gaia Loop: Insolação Solar vs Albedo de Nuvens ---
                // Nuvens refletem a luz solar impedindo o aquecimento excessivo (albedo negativo feedback)
                float albedo = Math.Clamp(src.CloudCover * 0.75f, 0f, 0.85f);
                float netSolar = src.SolarInsolation * (1.0f - albedo);
                float solarHeating = netSolar * 2.5f * dt;

                // Perda radiativa infravermelha para o espaço
                float radiativeCooling = (advTemp - (-20.0f)) * 0.03f * dt;
                float finalTemp = advTemp + solarHeating - radiativeCooling;

                // --- Condensação e Precipitação (Equação de Clausius-Clapeyron simplificada) ---
                // Capacidade máxima de suporte de vapor de água em função da temperatura
                float qSat = MathF.Max(0.02f, 0.08f * MathF.Exp(0.055f * finalTemp));

                float finalHumidity = advHumidity;
                float cloudCover = src.CloudCover;
                float precipitation = 0f;

                if (finalHumidity > qSat)
                {
                    // Excesso condensa em nuvens
                    float condensed = finalHumidity - qSat;
                    cloudCover = Math.Clamp(cloudCover + condensed * 1.5f, 0f, 1.0f);
                    finalHumidity = qSat;
                }
                else
                {
                    // Dissipação gradual de nuvens por evaporação do ar seco
                    cloudCover = MathF.Max(0f, cloudCover - 0.05f * dt);
                }

                // Precipitação ocorre se a cobertura de nuvens atingir saturação (> 0.50)
                if (cloudCover > 0.50f)
                {
                    precipitation = (cloudCover - 0.50f) * 4.0f * dt;
                    cloudCover = MathF.Max(0f, cloudCover - precipitation * 0.4f);
                }

                dst.Temperature = finalTemp;
                dst.Humidity = Math.Clamp(finalHumidity, 0f, 1.5f);
                dst.CloudCover = cloudCover;
                dst.Precipitation = precipitation;
                dst.SolarInsolation = src.SolarInsolation;
                dst.Elevation = src.Elevation;
                dst.WindVector = src.WindVector;
                dst.Pressure = src.Pressure;
            }
        }
    }

    private static void UpdatePressureField(ClimateGrid grid)
    {
        var cells = grid.Current;
        for (int i = 0; i < grid.CellCount; i++)
        {
            ref var c = ref cells[i];
            // Ar quente cria depressão barométrica; altitude reduz a coluna de ar
            float thermalOffset = -(c.Temperature - 15.0f) * ThermalPressureFactor;
            float altitudeOffset = -(c.Elevation * 0.12f);
            c.Pressure = StandardSeaPressure + thermalOffset + altitudeOffset;
        }
    }

    public static void SolveWindVectors(ClimateGrid grid)
    {
        var cells = grid.Current;
        int w = grid.Width;
        int h = grid.Height;

        for (int y = 0; y < h; y++)
        {
            for (int x = 0; x < w; x++)
            {
                int idx = grid.GetIndex(x, y);
                ref var cell = ref cells[idx];

                // Gradiente horizontal toroidal (X)
                int leftX = (x > 0) ? x - 1 : w - 1;
                int rightX = (x < w - 1) ? x + 1 : 0;
                float pLeft = cells[grid.GetIndex(leftX, y)].Pressure;
                float pRight = cells[grid.GetIndex(rightX, y)].Pressure;
                float gradX = (pRight - pLeft) * 0.5f;

                // Gradiente vertical (Y - com limites nos polos)
                int upY = Math.Max(0, y - 1);
                int downY = Math.Min(h - 1, y + 1);
                float pUp = cells[grid.GetIndex(x, upY)].Pressure;
                float pDown = cells[grid.GetIndex(x, downY)].Pressure;
                float gradY = (pDown - pUp) * 0.5f;

                // Vento sopra de alta pressão para baixa pressão (-∇P) com amortecimento
                cell.WindVector = new Vector2(-gradX * 0.25f * WindFriction, -gradY * 0.25f * WindFriction);
            }
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static void SampleBilinear(
        ReadOnlySpan<MacroCell> grid, int w, int h,
        float x, float y,
        out float temp, out float humidity)
    {
        int x0 = (int)MathF.Floor(x);
        int y0 = (int)MathF.Floor(y);
        int x1 = (x0 + 1) % w;
        int y1 = Math.Min(y0 + 1, h - 1);

        float fx = x - x0;
        float fy = y - y0;

        ref readonly var c00 = ref grid[y0 * w + x0];
        ref readonly var c10 = ref grid[y0 * w + x1];
        ref readonly var c01 = ref grid[y1 * w + x0];
        ref readonly var c11 = ref grid[y1 * w + x1];

        // Interpolação de temperatura
        float topT = MathF.FusedMultiplyAdd(c10.Temperature - c00.Temperature, fx, c00.Temperature);
        float btmT = MathF.FusedMultiplyAdd(c11.Temperature - c01.Temperature, fx, c01.Temperature);
        temp = MathF.FusedMultiplyAdd(btmT - topT, fy, topT);

        // Interpolação de umidade
        float topH = MathF.FusedMultiplyAdd(c10.Humidity - c00.Humidity, fx, c00.Humidity);
        float btmH = MathF.FusedMultiplyAdd(c11.Humidity - c01.Humidity, fx, c01.Humidity);
        humidity = MathF.FusedMultiplyAdd(btmH - topH, fy, topH);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static float WrapCoord(float val, int max)
    {
        while (val < 0f) val += max;
        while (val >= max) val -= max;
        return val;
    }
}
