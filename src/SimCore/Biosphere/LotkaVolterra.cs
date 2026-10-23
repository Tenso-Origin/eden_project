using System;

namespace SimCore.Biosphere;

/// <summary>
/// FASE 4 & 5: Modelo matemático macro Predador-Presa para simular populações
/// em chunks inativos sem custo computacional de instanciar entidades individuais.
/// dx/dt = alpha*x - beta*x*y
/// dy/dt = delta*x*y - gamma*y
/// </summary>
public static class LotkaVolterra
{
    public static (float prey, float predator) StepMacroEcosystem(
        float prey, float predator,
        float alpha, float beta, float gamma, float delta,
        float dt)
    {
        float dPrey = (alpha * prey - beta * prey * predator) * dt;
        float dPredator = (delta * prey * predator - gamma * predator) * dt;

        float newPrey = MathF.Max(0f, prey + dPrey);
        float newPredator = MathF.Max(0f, predator + dPredator);

        return (newPrey, newPredator);
    }
}
