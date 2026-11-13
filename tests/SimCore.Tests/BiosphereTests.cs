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

        // Herbívoro faminto posicionado em (8.5, 8.5) (Cutia / Agouti)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdAgouti, diet: AnimalDiet.Herbivore, x: 8.5f, y: 8.5f, speed: 2.0f)
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

        // Predador carnívoro (Jaguatirica) na célula (8, 8) e Herbívoro (Cutia) na célula (9, 8)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdOcelot, diet: AnimalDiet.Carnivore, x: 8.0f, y: 8.0f, speed: 0f),
            new AnimalAgent(id: 2, species: SpeciesCatalog.IdAgouti, diet: AnimalDiet.Herbivore, x: 9.0f, y: 8.0f, speed: 3.0f)
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

        // Herbívoro faminto sobre a célula (4, 4) (Cutia / Agouti)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdAgouti, diet: AnimalDiet.Herbivore, x: 4.5f, y: 4.5f, speed: 0f)
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
            agents[i] = new AnimalAgent((uint)i, SpeciesCatalog.IdAgouti, AnimalDiet.Herbivore, 5f + i, 5f + i);
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

    [Fact]
    public void Fauna_AgoutiAndOcelot_ReplaceRatAndCat_WithNativeTraits()
    {
        // 1. Validação de Catálogo e Traços Nativos Amazônicos
        Assert.Equal(SpeciesCatalog.IdAgouti, SpeciesCatalog.IdRat);
        Assert.Equal(SpeciesCatalog.IdOcelot, SpeciesCatalog.IdCat);

        ref readonly var agoutiDef = ref SpeciesCatalog.GetSpecies(SpeciesCatalog.IdAgouti);
        Assert.Equal(TrophicGuild.PrimaryConsumer, agoutiDef.Guild);
        Assert.Equal(3200f, agoutiDef.AdultBodyMassGrams);

        ref readonly var ocelotDef = ref SpeciesCatalog.GetSpecies(SpeciesCatalog.IdOcelot);
        Assert.Equal(TrophicGuild.SecondaryConsumer, ocelotDef.Guild);
        Assert.Equal(12000f, ocelotDef.AdultBodyMassGrams);

        // 2. Cutia forrageando biomassa nativa como herbívoro
        var chunk = new Chunk(0, 0);
        int foodIdx = Chunk.GetIndex(4, 4);
        chunk.Biomass[foodIdx] = 60.0f;
        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        var agoutiAgent = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdAgouti, diet: AnimalDiet.Herbivore, x: 4.5f, y: 4.5f, speed: 0f)
        };
        agoutiAgent[0].Hunger = 70.0f;

        FaunaSystem.StepFauna(agoutiAgent, chunk, map, 1.0f);
        Assert.True(chunk.Biomass[foodIdx] < 60.0f);
        Assert.True(agoutiAgent[0].Hunger < 70.0f);

        // 3. Jaguatirica emitindo perigo carnívoro e Cutia fugindo do gradiente
        var agentsInteraction = new AnimalAgent[]
        {
            new AnimalAgent(id: 2, species: SpeciesCatalog.IdOcelot, diet: AnimalDiet.Carnivore, x: 8.0f, y: 8.0f, speed: 0f),
            new AnimalAgent(id: 3, species: SpeciesCatalog.IdAgouti, diet: AnimalDiet.Herbivore, x: 9.0f, y: 8.0f, speed: 3.0f)
        };

        float initialAgoutiPosX = agentsInteraction[1].PosX;

        for (int i = 0; i < 5; i++)
        {
            map.UpdateFromChunk(chunk);
            FaunaSystem.StepFauna(agentsInteraction, chunk, map, 0.2f);
        }

        // Jaguatirica projetou perigo na sua célula
        Assert.True(map.DangerGradient[Chunk.GetIndex(8, 8)] > 0f);
        // Cutia fugiu na direção oposta ao predador (+X)
        Assert.True(agentsInteraction[1].PosX > initialAgoutiPosX);
    }

    [Fact]
    public void Fauna_Jaguar_PreysUponCapybaraAndCrushesTortoise()
    {
        var chunk = new Chunk(0, 0);
        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        // 1. Mesopredador (Jaguatirica) não consegue perfurar a carapaça do Jabuti
        var ocelotVsTortoise = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdOcelot, diet: AnimalDiet.Carnivore, x: 5.0f, y: 5.0f, speed: 0f),
            new AnimalAgent(id: 2, species: SpeciesCatalog.IdTortoise, diet: AnimalDiet.Herbivore, x: 5.5f, y: 5.0f, speed: 0f)
        };
        ocelotVsTortoise[0].Hunger = 60.0f;

        FaunaSystem.StepFauna(ocelotVsTortoise, chunk, map, 1.0f);
        Assert.Equal(100.0f, ocelotVsTortoise[1].Health); // Carapaça impenetrável para Jaguatirica

        // 2. Onça-Pintada quebra a carapaça do Jabuti (ignora 70% da defesa com mordida de 1000 psi)
        var jaguarVsTortoise = new AnimalAgent[]
        {
            new AnimalAgent(id: 3, species: SpeciesCatalog.IdJaguar, diet: AnimalDiet.Carnivore, x: 5.0f, y: 5.0f, speed: 0f),
            new AnimalAgent(id: 4, species: SpeciesCatalog.IdTortoise, diet: AnimalDiet.Herbivore, x: 5.5f, y: 5.0f, speed: 0f)
        };
        jaguarVsTortoise[0].Hunger = 60.0f;

        FaunaSystem.StepFauna(jaguarVsTortoise, chunk, map, 1.0f);
        Assert.True(jaguarVsTortoise[1].Health < 100.0f); // Defesa esmagada pela mordida da Onça

        // 3. Onça-Pintada predando presa de grande porte (Capivara)
        var jaguarVsCapybara = new AnimalAgent[]
        {
            new AnimalAgent(id: 5, species: SpeciesCatalog.IdJaguar, diet: AnimalDiet.Carnivore, x: 5.0f, y: 5.0f, speed: 0f),
            new AnimalAgent(id: 6, species: SpeciesCatalog.IdCapybara, diet: AnimalDiet.Herbivore, x: 5.5f, y: 5.0f, speed: 0f)
        };
        jaguarVsCapybara[0].Hunger = 70.0f;
        float initialJaguarHunger = jaguarVsCapybara[0].Hunger;

        FaunaSystem.StepFauna(jaguarVsCapybara, chunk, map, 1.0f);
        Assert.True(jaguarVsCapybara[1].Health < 100.0f);
        // Ao abater/consumir a Capivara, a fome da Onça é saciada
        Assert.True(jaguarVsCapybara[0].Hunger < initialJaguarHunger || jaguarVsCapybara[1].State == AgentState.Dead);
    }

    [Fact]
    public void Fauna_Capybara_DivesToEscapePredators()
    {
        var chunk = new Chunk(0, 0);
        // Célula (5, 5) com lâmina de água superficial
        int waterIdx = Chunk.GetIndex(5, 5);
        chunk.SurfaceWater[waterIdx] = 1.0f;

        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        // Capivara na água e predador terrestre (Onça) em raio de ameaça
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdCapybara, diet: AnimalDiet.Herbivore, x: 5.5f, y: 5.5f, speed: 2.0f),
            new AnimalAgent(id: 2, species: SpeciesCatalog.IdJaguar, diet: AnimalDiet.Carnivore, x: 7.5f, y: 5.5f, speed: 0f)
        };

        Assert.False(agents[0].IsDiving);
        Assert.Equal(35.0f, agents[0].Breath);
        Assert.Equal(35.0f, agents[0].MaxBreath);

        // Executa 1 passo
        FaunaSystem.StepFauna(agents, chunk, map, 1.0f);

        // Capivara mergulha na água como refúgio e consome fôlego subaquático
        Assert.True(agents[0].IsDiving);
        Assert.True(agents[0].Breath < 35.0f);
        Assert.Equal(34.0f, agents[0].Breath);

        // Valida que enquanto mergulhada, a Capivara fica imune ao ataque corpo-a-corpo do predador terrestre
        agents[1].PosX = 5.6f; // Aproxima a Onça a curta distância de combate
        agents[1].Hunger = 70.0f;
        float healthBefore = agents[0].Health;

        FaunaSystem.StepFauna(agents, chunk, map, 1.0f);
        Assert.True(agents[0].IsDiving);
        Assert.Equal(healthBefore, agents[0].Health); // Não foi atacada devido ao mergulho protetor
    }

    [Fact]
    public void Fauna_CanopyLayer_ProtectsSlothFromGroundPredator()
    {
        var chunk = new Chunk(0, 0);
        int cellIdx = Chunk.GetIndex(6, 6);
        chunk.Biomass[cellIdx] = 60.0f; // Biomassa densa de copa (> 40f)

        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        // Preguiça no dossel (CanopyLayer == 2) e Onça no solo (CanopyLayer == 0)
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(id: 1, species: SpeciesCatalog.IdSloth, diet: AnimalDiet.Herbivore, x: 6.2f, y: 6.2f, speed: 0f),
            new AnimalAgent(id: 2, species: SpeciesCatalog.IdJaguar, diet: AnimalDiet.Carnivore, x: 6.5f, y: 6.2f, speed: 0f)
        };
        agents[1].Hunger = 60.0f;

        Assert.Equal(2, agents[0].CanopyLayer);
        Assert.Equal(0, agents[1].CanopyLayer);

        FaunaSystem.StepFauna(agents, chunk, map, 1.0f);

        // Sob biomassa densa (> 40f), o predador terrestre no chão não alcança a Preguiça no dossel
        Assert.Equal(100.0f, agents[0].Health);

        // Se a biomassa de dossel for degradada/clareira (<= 40f), a proteção vertical é perdida
        chunk.Biomass[cellIdx] = 20.0f;
        FaunaSystem.StepFauna(agents, chunk, map, 1.0f);
        Assert.True(agents[0].Health < 100.0f);
    }

    [Fact]
    public void ZeroAllocations_DuringFaunaAndFloraTick_WithAmazonBiodiversity()
    {
        var chunk = new Chunk(0, 0);
        chunk.Fill(MaterialCatalog.IdOakWood, 24f, 0.8f, 5f);
        var map = new InfluenceMap();
        map.UpdateFromChunk(chunk);

        // Biodiversidade nativa amazônica: Cutia, Jaguatirica, Onça, Capivara, Anta, Jabuti, Harpia e Tucano
        var agents = new AnimalAgent[]
        {
            new AnimalAgent(1, SpeciesCatalog.IdAgouti, AnimalDiet.Herbivore, 2.0f, 2.0f),
            new AnimalAgent(2, SpeciesCatalog.IdOcelot, AnimalDiet.Carnivore, 4.0f, 4.0f),
            new AnimalAgent(3, SpeciesCatalog.IdJaguar, AnimalDiet.Carnivore, 6.0f, 6.0f),
            new AnimalAgent(4, SpeciesCatalog.IdCapybara, AnimalDiet.Herbivore, 8.0f, 8.0f),
            new AnimalAgent(5, SpeciesCatalog.IdTapir, AnimalDiet.Herbivore, 10.0f, 10.0f),
            new AnimalAgent(6, SpeciesCatalog.IdTortoise, AnimalDiet.Herbivore, 12.0f, 12.0f),
            new AnimalAgent(7, SpeciesCatalog.IdHarpyEagle, AnimalDiet.AvianApex, 14.0f, 14.0f),
            new AnimalAgent(8, SpeciesCatalog.IdToucan, AnimalDiet.Herbivore, 14.0f, 12.0f)
        };

        var catalog = MaterialCatalog.GetAll();

        // Warm-up JIT
        FloraAutomata.StepFlora(chunk, catalog, 0.033f);
        FaunaSystem.StepFauna(agents, chunk, map, 0.033f);

        long beforeAlloc = GC.GetAllocatedBytesForCurrentThread();

        for (int i = 0; i < 100; i++)
        {
            FloraAutomata.StepFlora(chunk, catalog, 0.033f);
            FaunaSystem.StepFauna(agents, chunk, map, 0.033f);
        }

        long afterAlloc = GC.GetAllocatedBytesForCurrentThread();

        // Zero bytes alocados na heap durante simulação contínua com biodiversidade amazônica
        Assert.Equal(0, afterAlloc - beforeAlloc);
    }
}
