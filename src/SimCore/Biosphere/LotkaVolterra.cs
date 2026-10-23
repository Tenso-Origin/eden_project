using System;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 4 & 5: Modelo Macro-Ecológico Predador-Presa de Lotka-Volterra com Capacidade de Suporte.
/// Utilizado para simular a dinâmica populacional de Chunks inativos (fora do frustum de visão)
/// sem incorrer no custo de CPU de instanciar entidades ECS individuais.
/// </summary>
public static class LotkaVolterra
{
    /// <summary>
    /// Passo de simulação macro usando integração de Runge-Kutta 4ª Ordem (RK4)
    /// com amortecimento logístico de Verhulst.
    /// </summary>
    public static (float prey, float predator) StepMacroEcosystem(
        float prey, float predator,
        float alpha = 0.80f,  // Taxa intrínseca de natalidade da presa
        float beta = 0.05f,   // Taxa de predação por encontro
        float gamma = 0.50f,  // Taxa de mortalidade natural do predador
        float delta = 0.03f,  // Eficiência de conversão de presas em novos predadores
        float carryingCapacity = 500.0f, // Limite de biomassa do bioma
        float dt = 0.1f)
    {
        if (prey <= 0.001f && predator <= 0.001f) return (0f, 0f);

        // RK4 - k1
        Derivatives(prey, predator, alpha, beta, gamma, delta, carryingCapacity, out float dp1, out float dpred1);

        // RK4 - k2
        Derivatives(prey + 0.5f * dt * dp1, predator + 0.5f * dt * dpred1,
            alpha, beta, gamma, delta, carryingCapacity, out float dp2, out float dpred2);

        // RK4 - k3
        Derivatives(prey + 0.5f * dt * dp2, predator + 0.5f * dt * dpred2,
            alpha, beta, gamma, delta, carryingCapacity, out float dp3, out float dpred3);

        // RK4 - k4
        Derivatives(prey + dt * dp3, predator + dt * dpred3,
            alpha, beta, gamma, delta, carryingCapacity, out float dp4, out float dpred4);

        float nextPrey = prey + (dt / 6.0f) * (dp1 + 2f * dp2 + 2f * dp3 + dp4);
        float nextPredator = predator + (dt / 6.0f) * (dpred1 + 2f * dpred2 + 2f * dpred3 + dpred4);

        return (MathF.Max(0.01f, nextPrey), MathF.Max(0.01f, nextPredator));
    }

    private static void Derivatives(
        float x, float y,
        float alpha, float beta, float gamma, float delta,
        float k,
        out float dPrey, out float dPredator)
    {
        // dx/dt = alpha * x * (1 - x / K) - beta * x * y
        dPrey = alpha * x * (1.0f - (x / k)) - beta * x * y;
        // dy/dt = delta * x * y - gamma * y
        dPredator = delta * x * y - gamma * y;
    }
}
