using System;
using Xunit;
using SimCore.Matter;
using SimCore.SpatialGrid;
using SimCore.Biosphere;

namespace SimCore.Tests;

public class BiosphereTests
{
    [Fact]
    public void Flora_GrowsWithMoistureAndOptimalTemperature_AndConsumesMoisture()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdOakWood, temp: 24f, moisture: 0.8f, elevation: 5f);
        int idx = Chunk.GetIndex(8, 8);
        chunk.Biomass[idx] = 10.0f;
        float initialMoisture = chunk.Moisture[idx];

        var catalog = MaterialCatalog.GetAll();

        // Executa 10 passos de flora
        for (int i = 0; i < 10; i++)
        {
            FloraAutomata.StepFlora(chunk, catalog, 0.5f);
        }

        // A biomassa deve ter aumentado significativamente
        Assert.True(chunk.Biomass[idx] > 10.0f);
        // A umidade foi consumida na fotossíntese/transpiração
        Assert.True(chunk.Moisture[idx] < initialMoisture);
    }

    [Fact]
    public void Flora_DecaysUnderFreezingFrost()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdOakWood, temp: -15f, moisture: 0.5f, elevation: 5f);
        int idx = Chunk.GetIndex(8, 8);
        chunk.Biomass[idx] = 50.0f;

        var catalog = MaterialCatalog.GetAll();

        // 10 passos sob frio congelante
        for (int i = 0; i < 10; i++)
        {
            FloraAutomata.StepFlora(chunk, catalog, 0.5f);
        }

        Assert.True(chunk.Biomass[idx] < 50.0f);
    }

    [Fact]
    public void InfluenceMap_BoxBlurCreatesContinuousGradientFromPoint()
    {
        var chunk = new Chunk(0, 0);
        var map = new InfluenceMap();

        int centerIdx = Chunk.GetIndex(8, 8);
        chunk.Biomass[centerIdx] = 100.0f; // Fonte pontual de comida

        map.UpdateFromChunk(chunk);

        // O centro tem a maior intensidade
        float centerVal = map.FoodGradient[centerIdx];
        float neighbor1Val = map.FoodGradient[Chunk.GetIndex(7, 8)];
        float neighbor2Val = map.FoodGradient[Chunk.GetIndex(6, 8)];

        Assert.True(centerVal > 0f);
        Assert.True(neighbor1Val > 0f);
        Assert.True(centerVal >= neighbor1Val);
        Assert.True(neighbor1Val >= neighbor2Val);
    }

    [Fact]
    public void Fauna_NavigatesTowardsHighestFoodGradient_WithoutAStar()
    {
        var chunk = new Chunk(0, 0);
        var map = new InfluenceMap();

        // Coloca abundância de biomassa na célula (10, 10)
        chunk.Biomass[Chunk.GetIndex(10, 10)] = 100.0f;
        map.UpdateFromChunk(chunk);

        // Herbívoro faminto posicionado em (8.5, 8.5)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: 1, diet: AnimalDiet.Herbivore, x: 8.5f, y: 8.5f, speed: 2.0f)
        };
        agents[0].Hunger = 60f; // Faminto

        float initialDist = MathF.Sqrt(MathF.Pow(10.5f - agents[0].PosX, 2) + MathF.Pow(10.5f - agents[0].PosY, 2));

        // Executa 5 passos de fauna
        for (int i = 0; i < 5; i++)
        {
            FaunaSystem.StepFauna(agents, chunk, map, 0.2f);
        }

        float finalDist = MathF.Sqrt(MathF.Pow(10.5f - agents[0].PosX, 2) + MathF.Pow(10.5f - agents[0].PosY, 2));

        // O agente aproximou-se da comida sem A*
        Assert.True(finalDist < initialDist);
    }

    [Fact]
    public void Fauna_FleesFromPredatorDangerGradient()
    {
        var chunk = new Chunk(0, 0);
        var map = new InfluenceMap();

        // Predador carnívoro na célula (8, 8) e Herbívoro na célula (9, 8)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: 10, diet: AnimalDiet.Carnivore, x: 8.0f, y: 8.0f, speed: 0f),
            new AnimalAgent(id: 2, species: 1,  diet: AnimalDiet.Herbivore, x: 9.0f, y: 8.0f, speed: 3.0f)
        };

        map.UpdateFromChunk(chunk);

        float initialPosX = agents[1].PosX;

        // Executa 5 passos
        for (int i = 0; i < 5; i++)
        {
            map.UpdateFromChunk(chunk);
            FaunaSystem.StepFauna(agents, chunk, map, 0.2f);
        }

        // O herbívoro deve ter fugido para a direita (+X), afastando-se do predador
        Assert.True(agents[1].PosX > initialPosX);
    }

    [Fact]
    public void Fauna_EatsBiomass_ReducesHungerAndCellBiomass()
    {
        var chunk = new Chunk(0, 0);
        var map = new InfluenceMap();

        int cellIdx = Chunk.GetIndex(4, 4);
        chunk.Biomass[cellIdx] = 50.0f;
        map.UpdateFromChunk(chunk);

        // Herbívoro faminto sobre a célula (4, 4)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: 1, diet: AnimalDiet.Herbivore, x: 4.5f, y: 4.5f, speed: 0f)
        };
        agents[0].Hunger = 80.0f;

        FaunaSystem.StepFauna(agents, chunk, map, 1.0f);

        // A biomassa da célula deve ter reduzido e a fome do animal também
        Assert.True(chunk.Biomass[cellIdx] < 50.0f);
        Assert.True(agents[0].Hunger < 80.0f);
    }

    [Fact]
    public void LotkaVolterra_SustainsPeriodicOscillations_WithoutExtinction()
    {
        float prey = 100.0f;
        float predator = 15.0f;

        // Simula 1.000 iterações de chunks inativos
        for (int i = 0; i < 1000; i++)
        {
            (prey, predator) = LotkaVolterra.StepMacroEcosystem(prey, predator, dt: 0.05f);

            Assert.False(float.IsNaN(prey));
            Assert.False(float.IsNaN(predator));
            Assert.True(prey > 0.001f, "Presa extinta");
            Assert.True(predator > 0.001f, "Predador extinto");
        }
    }

    [Fact]
    public void ZeroAllocations_DuringFaunaAndFloraTick()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdOakWood, 24f, 0.8f, 5f);
        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        var agents = new AnimalAgent[4];
        for (int i = 0; i < agents.Length; i++)
        {
            agents[i] = new AnimalAgent((uint)i, 1, AnimalDiet.Herbivore, 5f + i, 5f + i);
        }

        var catalog = MaterialCatalog.GetAll();

        // Warm-up
        FloraAutomata.StepFlora(chunk, catalog, 0.033f);
        FaunaSystem.StepFauna(agents, chunk, map, 0.033f);

        long beforeAlloc = GC.GetAllocatedBytesForCurrentThread();

        for (int i = 0; i < 100; i++)
        {
            FloraAutomata.StepFlora(chunk, catalog, 0.033f);
            FaunaSystem.StepFauna(agents, chunk, map, 0.033f);
        }

        long afterAlloc = GC.GetAllocatedBytesForCurrentThread();

        // Zero bytes alocados na heap durante a simulação da biosfera
        Assert.Equal(0, afterAlloc - beforeAlloc);
    }
}
