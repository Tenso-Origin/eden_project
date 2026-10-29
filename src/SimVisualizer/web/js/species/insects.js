// =========================================================================
// MÓDULO DE INSETOS NEOTROPICAIS (BACIA AMAZÔNICA 2048x1024)
// INSETOS SOCIAIS: COLÔNIAS CENTRAIS, SISTEMA DE CARGAS, PROPORÇÃO REAL DE FORRAGEAMENTO,
// DADOS BIOLÓGICOS DA RAINHA (LONGEVIDADE E OVOPOSIÇÃO) E REVOADA SAZONAL
// =========================================================================

/**
 * Criação da população inicial e colônias
 * Colônias começam com 5 ícones (500 indivíduos no total).
 * 4 cargas ficam trabalhando internamente na colônia e 1 enxame sai forrageando ao lado.
 */
/**
 * Validação rigorosa de terra firme para colônias de formigas e cupins (Proibido gerar na água)
 */
function isWaterSpot(x, y, matId, surfaceWater, getIdx, gridW = 2048, gridH = 1024, MAT_WATER = 0) {
  if (typeof isPointInWaterBody === 'function' && isPointInWaterBody(x, y)) return true;
  if (matId && getIdx) {
    const cx = Math.max(0, Math.min(gridW - 1, Math.floor(x)));
    const cy = Math.max(0, Math.min(gridH - 1, Math.floor(y)));
    const idx = getIdx(cx, cy);
    if (matId[idx] === MAT_WATER || (surfaceWater && surfaceWater[idx] > 0.05)) return true;
  }
  return false;
}

function findSafeDryLandCoords(targetX, targetY, matId, surfaceWater, getIdx, gridW = 2048, gridH = 1024, MAT_WATER = 0) {
  if (!isWaterSpot(targetX, targetY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
    return { x: targetX, y: targetY };
  }
  // Espirala até encontrar terra firme segura e distante de inundações
  for (let r = 10; r <= 300; r += 10) {
    for (let a = 0; a < Math.PI * 2; a += Math.PI / 8) {
      const tx = Math.max(25, Math.min(gridW - 25, targetX + Math.cos(a) * r));
      const ty = Math.max(25, Math.min(gridH - 25, targetY + Math.sin(a) * r));
      if (!isWaterSpot(tx, ty, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
        return { x: tx, y: ty };
      }
    }
  }
  return { x: targetX, y: targetY };
}

function createInitialInsects(gridWidth = 2048, gridHeight = 1024, nests = null, ctx = {}) {
  const insectList = [];
  const { matId, surfaceWater, getIdx, MAT_WATER } = ctx;

  // Coordenadas calibradas estritamente em TERRA FIRME (nenhuma colônia em corpos d'água ou meandros)
  const SOCIAL_COLONIES = {
    ant: [
      { name: 'Formigueiro Oeste (Saúva)', x: 320, y: 140, radius: 95.0, res: 40.0 },
      { name: 'Formigueiro Sul (Saúva)', x: 1050, y: 780, radius: 95.0, res: 35.0 },
      { name: 'Formigueiro Leste (Saúva)', x: 1680, y: 390, radius: 95.0, res: 35.0 }
    ],
    termite: [
      { name: 'Cupinzeiro da Mata Oeste', x: 380, y: 720, radius: 55.0, res: 30.0 },
      { name: 'Cupinzeiro da Floresta Central', x: 1140, y: 190, radius: 55.0, res: 30.0 },
      { name: 'Cupinzeiro da Mata Leste', x: 1820, y: 820, radius: 55.0, res: 30.0 }
    ],
    bee: [
      { name: 'Colmeia Jataí (Oco Oeste)', x: 520, y: 460, radius: 140.0, res: 25.0 },
      { name: 'Colmeia Jataí (Oco Central)', x: 960, y: 410, radius: 140.0, res: 25.0 },
      { name: 'Colmeia Jataí (Oco Leste)', x: 1560, y: 560, radius: 140.0, res: 25.0 }
    ]
  };

  let nestSeq = 5000;
  let idCounter = 8000;

  if (nests && Array.isArray(nests)) {
    for (const [sp, list] of Object.entries(SOCIAL_COLONIES)) {
      for (const nConf of list) {
        // Dados biológicos reais da rainha por espécie:
        // - Saúva: Longevidade de 12 a 15 anos (~4.745 dias), postura de ~150 ovos/dia
        // - Cupim: Longevidade de 15 a 20 anos (~6.200 dias), postura de ~100 ovos/dia
        // - Abelha Jataí: Longevidade de 2 a 3 anos (~912 dias), postura de ~60 ovos/dia
        const maxLifeDays = (sp === 'ant' ? 4745.0 : (sp === 'termite' ? 6200.0 : 912.0));
        const dailyEggs = (sp === 'ant' ? 150.0 : (sp === 'termite' ? 100.0 : 60.0));
        const extRatio = (sp === 'bee' ? 0.25 : 0.20); // 20% a 25% forrageando externamente, 75% a 80% interna

        // Garante que a colônia seja posicionada 100% fora de corpos d'água
        const safeCoords = findSafeDryLandCoords(nConf.x, nConf.y, matId, surfaceWater, getIdx, gridWidth, gridHeight, MAT_WATER);
        const colonyObj = {
          id: nestSeq++,
          species: sp,
          name: nConf.name,
          x: safeCoords.x,
          y: safeCoords.y,
          quality: 90,
          resourcesKg: nConf.res,
          forageRadius: nConf.radius,
          isSocialColony: true,

          // População total inicial: 500 indivíduos (5 ícones/cargas)
          totalInitialCharges: 5,
          maxPopulationCharges: 5,
          charges: 4,                  // 4 cargas internas trabalhando dentro da colônia
          activeSwarmsCount: 1,        // 1 enxame em campo trabalhando fora (5ª carga)
          maxExternalRatio: extRatio,  // Proporção de forrageamento exterior observada na realidade
          dispatchCooldown: 5.0 + Math.random() * 8.0,

          // Rainha da Colônia
          queen: {
            isAlive: true,
            ageDays: 180.0,
            maxLifespanDays: maxLifeDays,
            eggsPerDay: dailyEggs,
            eggBuffer: 0.0
          },

          lastNuptialFlightYear: -1
        };

        nests.push(colonyObj);

        // Cria exatamente 1 enxame ativo (100 indivíduos) ao lado da colônia
        const spawnAngle = Math.random() * Math.PI * 2;
        const sDist = 3.0 + Math.random() * 3.0;
        insectList.push({
          id: idCounter++,
          species: sp,
          diet: (sp === 'termite' ? 'decomposer' : 'herbivore'),
          name: (sp === 'ant' ? 'Formiga-saúva' : (sp === 'termite' ? 'Cupim-da-terra' : 'Abelha-jataí')),
          icon: (sp === 'ant' ? '🐜' : (sp === 'termite' ? '🪵' : '🐝')),
          sex: 'female',
          x: colonyObj.x + Math.cos(spawnAngle) * sDist,
          y: colonyObj.y + Math.sin(spawnAngle) * sDist,
          hp: 100,             // 100 indivíduos no enxame
          maxHp: 100,
          hunger: 5.0,
          speed: (sp === 'ant' ? 1.1 : (sp === 'bee' ? 2.8 : 0.8)),
          attackPower: 0.1,    // 0.1 de ataque unitário por indivíduo
          defensePower: 0.0,   // 0.0 de defesa individual
          isSocial: true,
          nestId: colonyObj.id,
          nestX: colonyObj.x,
          nestY: colonyObj.y,
          maxForageRadius: colonyObj.forageRadius,
          foodCarried: 0.0,
          isReturningToNest: false,
          ageInDays: 15.0,
          maxLifespan: 365.0,
          wanderAngle: spawnAngle,
          enteredNest: false
        });
      }
    }
  }

  // Insetos Solitários e Predadores da Bacia Amazônica
  const SOLITARY_CONFIG = [
    { species: 'butterfly', count: 30, name: 'Borboleta-morfo', diet: 'herbivore', spd: 2.2, icon: '🦋', zone: 'clearings', femaleRatio: 0.50, gest: 7.0, litter: [5, 9], mat: 15.0, est: 10.0 },
    { species: 'dragonfly', count: 25, name: 'Libélula-imperador', diet: 'carnivore', spd: 3.8, icon: '🪰', zone: 'water', femaleRatio: 0.50, gest: 10.0, litter: [4, 7], mat: 25.0, est: 14.0 },
    { species: 'beetle', count: 25, name: 'Besouro-hércules', diet: 'decomposer', spd: 0.9, icon: '🪲', zone: 'forest', femaleRatio: 0.50, gest: 20.0, litter: [2, 5], mat: 40.0, est: 25.0 },
    { species: 'mosquito', count: 40, name: 'Mosquito-prego', diet: 'carnivore', spd: 2.0, icon: '🦟', zone: 'water', femaleRatio: 0.60, gest: 5.0, litter: [8, 18], mat: 10.0, est: 7.0 },
    { species: 'grasshopper', count: 35, name: 'Gafanhoto-esperança', diet: 'herbivore', spd: 2.4, icon: '🦗', zone: 'varzea', femaleRatio: 0.50, gest: 14.0, litter: [5, 10], mat: 30.0, est: 18.0 },
    { species: 'mantis', count: 20, name: 'Louva-a-deus', diet: 'carnivore', spd: 1.2, icon: '🍃', zone: 'varzea', femaleRatio: 0.50, gest: 18.0, litter: [3, 7], mat: 40.0, est: 20.0 },
    { species: 'roach', count: 28, name: 'Barata-da-mata', diet: 'decomposer', spd: 1.8, icon: '🪳', zone: 'forest', femaleRatio: 0.50, gest: 20.0, litter: [6, 12], mat: 35.0, est: 18.0 }
  ];

  for (const cfg of SOLITARY_CONFIG) {
    for (let i = 0; i < cfg.count; i++) {
      let x, y;
      if (cfg.zone === 'water') {
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 35.0;
      } else if (cfg.zone === 'varzea') {
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 160.0;
      } else {
        x = 60 + Math.random() * (gridWidth - 120);
        y = 60 + Math.random() * (gridHeight - 120);
      }

      x = Math.max(15, Math.min(gridWidth - 15, x));
      y = Math.max(15, Math.min(gridHeight - 15, y));

      const sex = (Math.random() < cfg.femaleRatio) ? 'female' : 'male';
      const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
      const gestationRem = isPregnantInit ? (1.0 + Math.random() * (cfg.gest - 1.0)) : 0.0;

      insectList.push({
        id: idCounter++,
        species: cfg.species,
        diet: cfg.diet,
        name: cfg.name,
        icon: cfg.icon,
        sex: sex,
        x: x,
        y: y,
        hp: 100,
        maxHp: 100,
        hunger: 5.0 + Math.random() * 15.0,
        speed: cfg.spd,
        attackPower: (cfg.diet === 'carnivore' ? 18.0 : 2.0),
        defensePower: 2.0,
        isSocial: false,
        ageInDays: 20.0 + Math.random() * 100.0,
        maxLifespan: 365.0,
        pollinateTimer: 0.0,
        wanderAngle: Math.random() * Math.PI * 2,
        isPregnant: isPregnantInit,
        daysPregnant: isPregnantInit ? (cfg.gest - gestationRem) : 0.0,
        gestationRemaining: gestationRem,
        litterSize: isPregnantInit ? (cfg.litter[0] + Math.floor(Math.random() * (cfg.litter[1] - cfg.litter[0] + 1))) : 0,
        matingCooldown: isPregnantInit ? (gestationRem + 15.0) : (5.0 + Math.random() * 20.0),
        estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * (cfg.est || 15.0)),
        estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 3.0) : 0.0
      });
    }
  }

  return insectList;
}

/**
 * Atualização das Colônias de Insetos Sociais:
 * - Ciclo de vida da rainha e postura de ovos
 * - Manutenção da proporção interna/externa (forrageadoras em campo vs trabalho interno)
 * - Despacho de enxames consumindo cargas
 * - Revoada nupcial anual sincronizada com o calendário de chuvas amazônico
 */
function updateSocialColonies(nests, targetAnimalList, dt, ctx) {
  if (!nests || !Array.isArray(nests)) return;

  const { GRID_WIDTH, GRID_HEIGHT, totalSimHours, weather, animals } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  const simDeltaDays = (0.08 * dt) / 24.0;
  const animalSource = animals || targetAnimalList || [];

  for (let ni = 0; ni < nests.length; ni++) {
    const colony = nests[ni];
    if (!colony.isSocialColony) continue;

    // 1. CICLO BIOLÓGICO DA RAINHA E OVOPOSIÇÃO
    if (colony.queen) {
      colony.queen.ageDays += simDeltaDays;

      if (colony.queen.ageDays >= colony.queen.maxLifespanDays) {
        colony.queen.isAlive = false;
        // Abelhas Jataí promovem princesa com alimento estocado
        if (colony.species === 'bee' && (colony.resourcesKg || 0) >= 5.0) {
          colony.queen.isAlive = true;
          colony.queen.ageDays = 0.0;
          colony.resourcesKg -= 2.5;
          console.log(`👑 [SUCESSÃO JATAÍ] Nova rainha princesa assumiu a colmeia '${colony.name}'!`);
        }
      }

      if (colony.queen.isAlive) {
        const eggsSpawned = colony.queen.eggsPerDay * simDeltaDays;
        colony.queen.eggBuffer = (colony.queen.eggBuffer || 0) + eggsSpawned;

        // Ao atingir 100 ovos incubados e havendo biomassa/celulose estocada (1.5 kg por carga):
        colony.maxPopulationCharges = colony.maxPopulationCharges || 5;
        if (colony.queen.eggBuffer >= 100.0 && (colony.resourcesKg || 0) >= 1.5) {
          colony.resourcesKg -= 1.5;
          colony.queen.eggBuffer -= 100.0;
          if ((colony.maxPopulationCharges || 5) < 50) {
            colony.maxPopulationCharges = (colony.maxPopulationCharges || 5) + 1;
            colony.charges = Math.max(0, Math.min(colony.maxPopulationCharges - (colony.activeSwarmsCount || 0), (colony.charges || 0) + 1));
            console.log(`🐣 [ECLOSÃO] Colônia '${colony.name}' chocou 100 ovos (+1 carga)! Total: ${colony.maxPopulationCharges} cargas.`);
          }
        }
      }
    }

    // 2. REVOADA SAZONAL (VOO NUPCIAL) DAS RAINHAS VIRGENS
    if (totalSimHours != null && typeof getSimDate === 'function') {
      const simDate = getSimDate(totalSimHours);
      let isNuptialSeason = false;

      if (colony.species === 'ant') {
        // Saúvas: Outubro a Dezembro (meses 9, 10, 11)
        isNuptialSeason = (simDate.monthIdx >= 9 && simDate.monthIdx <= 11);
      } else if (colony.species === 'termite') {
        // Cupins: Novembro a Janeiro (meses 10, 11, 0)
        isNuptialSeason = (simDate.monthIdx >= 10 || simDate.monthIdx === 0);
      } else if (colony.species === 'bee') {
        // Abelhas Jataí: Dezembro a Fevereiro (meses 11, 0, 1)
        isNuptialSeason = (simDate.monthIdx >= 11 || simDate.monthIdx <= 1);
      }

      if (isNuptialSeason && colony.lastNuptialFlightYear !== simDate.year && (colony.resourcesKg || 0) >= 16.0) {
        colony.lastNuptialFlightYear = simDate.year;
        colony.resourcesKg = Math.max(0, colony.resourcesKg - 10.0);

        const numQueens = 8 + Math.floor(Math.random() * 6);
        for (let q = 0; q < numQueens; q++) {
          targetAnimalList.push({
            id: 95000 + Math.floor(Math.random() * 900000),
            species: colony.species,
            subspecies: colony.species === 'ant' ? 'sauva' : (colony.species === 'termite' ? 'cupim' : 'jatai'),
            isVirginQueen: true,
            isSocial: false,
            nestId: colony.id,
            originNestId: colony.id,
            name: (colony.species === 'ant' ? 'Tanajura (Rainha Virgem)' : (colony.species === 'bee' ? 'Princesa Jataí' : 'Aleluia (Rainha Virgem)')),
            icon: (colony.species === 'ant' ? '🐜' : (colony.species === 'bee' ? '🐝' : '🪵')),
            sex: 'female',
            x: colony.x + (Math.random() - 0.5) * 4.0,
            y: colony.y + (Math.random() - 0.5) * 4.0,
            hp: 1, // 1 indivíduo singular
            maxHp: 1,
            speed: 2.5,
            attackPower: 0.1,
            defensePower: 0.0,
            flightTimer: 25.0 + Math.random() * 25.0,
            flightAngle: Math.random() * Math.PI * 2,
            maxForageRadius: colony.forageRadius,
            hunger: 5.0,
            ageInDays: 1.0,
            maxLifespan: 100.0,
            wanderAngle: Math.random() * Math.PI * 2
          });
        }
        console.log(`✨ [REVOADA AMAZÔNICA] Colônia '${colony.name}' liberou ${numQueens} rainhas virgens em voo nupcial!`);
      }
    }

    // 3. DESPACHO DE ENXAMES PARA FORRAGEAMENTO DISPERSO (REMOÇÃO DE CARGA)
    // Censo de enxames ativos pertencentes a esta colônia no mapa
    let activeSwarms = 0;
    for (let ai = 0; ai < animalSource.length; ai++) {
      const a = animalSource[ai];
      if (a.nestId === colony.id && a.isSocial && a.hp > 0 && !a.enteredNest) {
        activeSwarms++;
      }
    }
    colony.activeSwarmsCount = activeSwarms;

    colony.maxPopulationCharges = colony.maxPopulationCharges || 5;
    const ratio = colony.maxExternalRatio || (colony.species === 'bee' ? 0.25 : 0.20);
    // Permite que a colônia mantenha uma proporção biológica real em campo (~20% exterior, 80% interior)
    const maxSwarmsAllowed = Math.max(1, Math.min(6, Math.floor(colony.maxPopulationCharges * ratio)));

    colony.dispatchCooldown = (colony.dispatchCooldown || 0) - dt;

    if (activeSwarms < maxSwarmsAllowed && (colony.charges || 0) >= 1 && colony.dispatchCooldown <= 0) {
      // Remove uma carga do ícone da colônia
      colony.charges = Math.max(0, colony.charges - 1);
      colony.activeSwarmsCount = activeSwarms + 1;

      // Dispersão em 8 quadrantes/setores radiais distintos para que as formigas não tomem a mesma direção
      colony.dispatchSequence = (colony.dispatchSequence || 0) + 1;
      const sector = (colony.dispatchSequence % 8);
      const baseAngle = (sector / 8.0) * Math.PI * 2;
      const spawnAngle = baseAngle + (Math.random() - 0.5) * 0.35;
      const sDist = 3.5 + Math.random() * 3.0;
      const sx = Math.max(12, Math.min(gridW - 12, colony.x + Math.cos(spawnAngle) * sDist));
      const sy = Math.max(12, Math.min(gridH - 12, colony.y + Math.sin(spawnAngle) * sDist));

      targetAnimalList.push({
        id: 86000 + Math.floor(Math.random() * 900000),
        species: colony.species,
        diet: (colony.species === 'termite' ? 'decomposer' : 'herbivore'),
        name: (colony.species === 'ant' ? 'Formiga-saúva' : (colony.species === 'termite' ? 'Cupim-da-terra' : 'Abelha-jataí')),
        icon: (colony.species === 'ant' ? '🐜' : (colony.species === 'termite' ? '🪵' : '🐝')),
        sex: 'female',
        x: sx,
        y: sy,
        hp: 100,             // 100 indivíduos
        maxHp: 100,
        hunger: 5.0,
        speed: (colony.species === 'ant' ? 1.2 : (colony.species === 'bee' ? 2.9 : 0.85)),
        attackPower: 0.1,    // 0.1 por indivíduo
        defensePower: 0.0,   // 0.0 de defesa
        isSocial: true,
        nestId: colony.id,
        nestX: colony.x,
        nestY: colony.y,
        maxForageRadius: colony.forageRadius,
        foodCarried: 0.0,
        targetLoad: (colony.species === 'ant' ? (4.5 + Math.random() * 2.5) : (3.0 + Math.random() * 2.0)),
        isReturningToNest: false,
        ageInDays: 15.0,
        maxLifespan: 365.0,
        trailAngle: spawnAngle,
        wanderAngle: spawnAngle,
        targetForageDist: 25.0 + Math.random() * (colony.forageRadius - 30.0),
        enteredNest: false
      });

      // Se ainda houver vagas para atingir a cota de forrageiras, despacha rapidamente o próximo grupo
      colony.dispatchCooldown = 15.0 + Math.random() * 10.0;
    }
  }
}

/**
 * Atualização comportamental dos insetos (Sociais e Solitários)
 */
function updateInsectBehavior(a, dt, ctx) {
  const { animals, nests, biomass, grains, getIdx, matId, MAT_WATER, GRID_WIDTH, GRID_HEIGHT, timeOfDay, totalSimHours, weather, applyDeathDecomposition } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // =========================================================================
  // CASO 1: RAINHA VIRGEM EM VOO NUPCIAL (REVOADA / DISPERSÃO REPRODUTIVA)
  // =========================================================================
  if (a.isVirginQueen) {
    a.flightTimer = (a.flightTimer || 25.0) - dt;
    a.flightAngle += (Math.random() - 0.5) * 0.45 * dt;

    targetX = a.x + Math.cos(a.flightAngle) * (a.speed * 1.5);
    targetY = a.y + Math.sin(a.flightAngle) * (a.speed * 1.5);

    // Predação de fêmeas aladas por aves, sapos e peixes
    for (let j = 0; j < animals.length; j++) {
      const pred = animals[j];
      if (pred.id === a.id || pred.hp <= 0) continue;
      if (['carcara', 'toucan', 'traira'].includes(pred.species)) {
        if (Math.hypot(pred.x - a.x, pred.y - a.y) < 3.2) {
          a.hp = 0;
          pred.hunger = Math.max(0, pred.hunger - 10.0);
          return { targetX: a.x, targetY: a.y };
        }
      }
    }

    // Afogamento em corpos d'água
    const cellIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (matId && matId[cellIdx] === MAT_WATER) {
      if (Math.random() < 0.25 * dt) {
        a.hp = 0;
        return { targetX: a.x, targetY: a.y };
      }
    }

    // Pouso e tentativa de fundação ao término do voo (Proibido fundar em água)
    if (a.flightTimer <= 0) {
      const isWater = isWaterSpot(a.x, a.y, matId, ctx.surfaceWater, getIdx, gridW, gridH, MAT_WATER);
      if (!isWater) {
        // Territorialidade: Rainhas que pousam perto de colônias rivais (<65m) são eliminadas
        let hasRivalColonyNearby = false;
        if (nests && Array.isArray(nests)) {
          for (let ni = 0; ni < nests.length; ni++) {
            const nest = nests[ni];
            if (nest.species === a.species && Math.hypot(nest.x - a.x, nest.y - a.y) < 65.0) {
              hasRivalColonyNearby = true;
              break;
            }
          }
        }

        // Taxa de sucesso biológico real na natureza (~4%)
        if (!hasRivalColonyNearby && Math.random() < 0.04) {
          const newNestId = 6000 + Math.floor(Math.random() * 4000);
          const nestTitle = (a.species === 'ant') ? `Novo Formigueiro (#${newNestId})` : ((a.species === 'termite') ? `Novo Cupinzeiro (#${newNestId})` : `Nova Colmeia Jataí (#${newNestId})`);
          const maxR = (a.species === 'termite' ? 45.0 : (a.species === 'ant' ? 85.0 : 130.0));
          const maxLifeDays = (a.species === 'ant' ? 4745.0 : (a.species === 'termite' ? 6200.0 : 912.0));
          const dailyEggs = (a.species === 'ant' ? 150.0 : (a.species === 'termite' ? 100.0 : 60.0));
          const extRatio = (a.species === 'bee' ? 0.25 : 0.20);

          const newColony = {
            id: newNestId,
            species: a.species,
            name: nestTitle,
            x: a.x,
            y: a.y,
            quality: 85,
            resourcesKg: 20.0,
            forageRadius: maxR,
            isSocialColony: true,
            totalInitialCharges: 5,
            charges: 4,                  // 4 cargas internas
            activeSwarmsCount: 1,        // 1 enxame externo inicial
            maxExternalRatio: extRatio,
            dispatchCooldown: 12.0,
            queen: {
              isAlive: true,
              ageDays: 0.0,
              maxLifespanDays: maxLifeDays,
              eggsPerDay: dailyEggs,
              eggBuffer: 0.0
            },
            lastNuptialFlightYear: (typeof getSimDate === 'function' && totalSimHours != null) ? getSimDate(totalSimHours).year : 0
          };

          if (nests && Array.isArray(nests)) nests.push(newColony);

          // Spawna o primeiro enxame para a nova colônia
          if (animals && Array.isArray(animals)) animals.push({
            id: 88000 + Math.floor(Math.random() * 900000),
            species: a.species,
            diet: (a.species === 'termite' ? 'decomposer' : 'herbivore'),
            name: (a.species === 'ant' ? 'Formiga-saúva' : (a.species === 'termite' ? 'Cupim-da-terra' : 'Abelha-jataí')),
            icon: (a.species === 'ant' ? '🐜' : (a.species === 'termite' ? '🪵' : '🐝')),
            sex: 'female',
            x: a.x + 2.0,
            y: a.y + 2.0,
            hp: 100,
            maxHp: 100,
            hunger: 5.0,
            speed: (a.species === 'ant' ? 1.1 : (a.species === 'bee' ? 2.8 : 0.8)),
            attackPower: 0.1,
            defensePower: 0.0,
            isSocial: true,
            nestId: newNestId,
            nestX: a.x,
            nestY: a.y,
            maxForageRadius: maxR,
            foodCarried: 0.0,
            isReturningToNest: false,
            ageInDays: 5.0,
            maxLifespan: 365.0,
            wanderAngle: Math.random() * Math.PI * 2,
            enteredNest: false
          });

          console.log(`👑 [NOVA COLÔNIA FUNDADA] ${nestTitle} fundado em (${a.x.toFixed(0)}, ${a.y.toFixed(0)}) por rainha virgem!`);
        }
      }

      a.hp = 0;
      return { targetX: a.x, targetY: a.y };
    }

    return { targetX, targetY };
  }

  // =========================================================================
  // CASO 2: INSETOS SOCIAIS EM ENXAME (FORMIGAS, CUPINS E ABELHAS)
  // Cada token representa 1 indivíduo por ponto de HP (ex: 100 HP = 100 operárias)
  // Atua em torno do ninho com raio radial de forrageamento
  // Ao retornar ao ninho, descarrega alimentos, desaparece e devolve 1 carga à colônia
  // =========================================================================
  if (a.isSocial) {
    let myNest = null;
    if (nests && Array.isArray(nests)) {
      myNest = nests.find(n => n.id === a.nestId);
    }
    const nestX = myNest ? myNest.x : (a.nestX || a.x);
    const nestY = myNest ? myNest.y : (a.nestY || a.y);
    const dNest = Math.hypot(a.x - nestX, a.y - nestY);
    const maxR = a.maxForageRadius || (a.species === 'termite' ? 45.0 : (a.species === 'ant' ? 85.0 : 130.0));

    // 1. RETORNO AO NINHO E ABSORÇÃO DE CARGA
    if (a.isReturningToNest) {
      targetX = nestX;
      targetY = nestY;

      if (dNest < 3.2) {
        if (myNest && !a.enteredNest) {
          // Descarrega recursos no estoque da colônia
          myNest.resourcesKg = (myNest.resourcesKg || 0) + (a.foodCarried || 0);

          // Restaura rigorosamente a carga que saiu (conservação estrita da capacidade biológica)
          const maxCap = myNest.maxPopulationCharges || 5;
          myNest.activeSwarmsCount = Math.max(0, (myNest.activeSwarmsCount || 1) - 1);
          myNest.charges = Math.max(0, Math.min(maxCap - myNest.activeSwarmsCount, (myNest.charges || 0) + 1));
        }

        // O ícone do enxame desaparece do mapa e entra na colônia
        a.hp = 0;
        a.enteredNest = true;
        return { targetX: nestX, targetY: nestY };
      }

      return { targetX, targetY };
    }

    // 2. FORRAGEAMENTO RADIAL EM TORNO DO NINHO
    a.forageDuration = (a.forageDuration || 0) + dt;
    const loadLimit = a.targetLoad || (a.species === 'ant' ? 5.0 : 3.5);
    // Só retorna ao ninho se ultrapassou o raio máximo OU se atingiu a carga e forrageou a uma distância mínima
    if (dNest > maxR || ((a.foodCarried || 0) >= loadLimit && (dNest >= 12.0 || a.forageDuration >= 18.0))) {
      a.isReturningToNest = true;
      return { targetX: nestX, targetY: nestY };
    }

    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    const defolTimer = (ctx.soilDefoliationTimer || (typeof soilDefoliationTimer !== 'undefined' ? soilDefoliationTimer : null));
    const flowerList = (ctx.flowerPatches || (typeof flowerPatches !== 'undefined' ? flowerPatches : []));

    // A. FORMIGAS CORTADEIRAS (SAÚVAS): Colheita foliar com Halo de Desfolha e Supressão de Solo
    if (a.species === 'ant') {
      // Ignora células com biomassa rala (< 18.0) para forçar as formigas a buscarem folhas frescas longe do ninho
      if (biomass && biomass[curIdx] > 18.0) {
        const cut = Math.min(biomass[curIdx] - 3.0, 2.5 * dt);
        biomass[curIdx] -= cut;
        a.foodCarried = (a.foodCarried || 0) + cut;
        a.hunger = Math.max(0, a.hunger - cut * 2.5);

        // Aplica o timer de desfolha: essa célula demorará ~120 dias para rebrotar, forçando saúvas a irem mais longe
        if (defolTimer) {
          defolTimer[curIdx] = 120.0;
        }

        if (a.foodCarried >= loadLimit) {
          a.isReturningToNest = true;
          return { targetX: nestX, targetY: nestY };
        }
      }

      // Marcha ao longo da trilha radial atribuída (afastando-se do halo desfolhado em direção a vegetação fresca)
      if (dNest < (a.targetForageDist || 35.0)) {
        // Direção da trilha radial atribuída no despacho
        const trailX = Math.cos(a.trailAngle || a.wanderAngle);
        const trailY = Math.sin(a.trailAngle || a.wanderAngle);
        a.wanderAngle = (a.trailAngle || a.wanderAngle) + (Math.random() - 0.5) * 0.25;
        targetX = a.x + trailX * (a.speed * 1.4);
        targetY = a.y + trailY * (a.speed * 1.4);
      } else {
        // Ao atingir a distância alvo, explora em meandros na mata densa
        a.wanderAngle += (Math.random() - 0.5) * 0.7 * dt;
        if (dNest > maxR * 0.90) {
          a.isReturningToNest = true;
        }
        targetX = a.x + Math.cos(a.wanderAngle) * (a.speed * 1.2);
        targetY = a.y + Math.sin(a.wanderAngle) * (a.speed * 1.2);
      }

      // Evita entrar em corpos d'água
      if (isWaterSpot(targetX, targetY, matId, ctx.surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
        const angleToNest = Math.atan2(nestY - a.y, nestX - a.x);
        a.wanderAngle = angleToNest;
        targetX = a.x + Math.cos(angleToNest) * 1.5;
        targetY = a.y + Math.sin(angleToNest) * 1.5;
      }
      return { targetX, targetY };
    }

    // B. CUPINS DA TERRA: Decomposição em terra firme
    else if (a.species === 'termite') {
      if (biomass && biomass[curIdx] > 4.0) {
        const cut = Math.min(biomass[curIdx], 1.4 * dt);
        biomass[curIdx] -= cut;
        a.foodCarried = (a.foodCarried || 0) + cut;
        a.hunger = Math.max(0, a.hunger - cut * 2.5);
        if (a.foodCarried >= (a.targetLoad || 3.0)) {
          a.isReturningToNest = true;
          return { targetX: nestX, targetY: nestY };
        }
      }
      a.wanderAngle += (Math.random() - 0.5) * 0.7 * dt;
      if (dNest > maxR * 0.85) {
        a.wanderAngle = Math.atan2(nestY - a.y, nestX - a.x) + (Math.random() - 0.5) * 0.4;
      }
      targetX = a.x + Math.cos(a.wanderAngle) * (a.speed * 1.2);
      targetY = a.y + Math.sin(a.wanderAngle) * (a.speed * 1.2);
      return { targetX, targetY };
    }

    // C. ABELHAS JATAÍ: Busca ativa de TOUCEIRAS DE FLORES (Orquídeas, Bromélias, Ipês) a longas distâncias
    else if (a.species === 'bee') {
      let targetFlower = null;
      let bestFlowerDist = 9999.0;
      // Usa a lista de flores recebida do contexto ou global


      for (let fpi = 0; fpi < flowerList.length; fpi++) {
        const fp = flowerList[fpi];
        if (fp.nectar <= 1.0) continue;
        const d = Math.hypot(fp.x - a.x, fp.y - a.y);
        // Abelhas detectam touceiras de flores a até 150m de distância
        if (d < 150.0 && d < bestFlowerDist) {
          bestFlowerDist = d;
          targetFlower = fp;
        }
      }

      if (targetFlower) {
        targetX = targetFlower.x;
        targetY = targetFlower.y;

        // Ao sobrevoar a touceira de flores, colhe néctar
        if (bestFlowerDist < 3.8) {
          const harvest = Math.min(targetFlower.nectar, 2.5 * dt);
          targetFlower.nectar -= harvest;
          a.foodCarried = (a.foodCarried || 0) + harvest;
          a.hunger = Math.max(0, a.hunger - harvest * 3.5);
          if (a.foodCarried >= (a.targetLoad || 3.5)) {
            a.isReturningToNest = true;
          }
        }
        return { targetX, targetY };
      }

      // Se nenhuma touceira de flores estiver no campo visual imediato, voa em longas varreduras de dossel
      a.wanderAngle += (Math.random() - 0.5) * 0.35 * dt;
      if (dNest > maxR * 0.90) {
        a.wanderAngle = Math.atan2(nestY - a.y, nestX - a.x) + (Math.random() - 0.5) * 0.5;
      }
      targetX = a.x + Math.cos(a.wanderAngle) * (a.speed * 1.5);
      targetY = a.y + Math.sin(a.wanderAngle) * (a.speed * 1.5);
      return { targetX, targetY };
    }
  }

  // =========================================================================
  // CASO 3: INSETOS SOLITÁRIOS (LIBÉLULA, LOUVA-A-DEUS, BORBOLETA, ETC.)
  // =========================================================================

  // 1. Cortejo Reprodutivo para Espécies Solitárias
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 50.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate) {
    let closestMate = null;
    let mateDist = 30.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== a.species) continue;
      if (other.sex !== a.sex && other.matingCooldown <= 0 && other.hunger < 55.0) {
        if (a.sex === 'male' && other.isPregnant) continue;
        if (a.sex === 'male' && (!other.estrusDurationRemaining || other.estrusDurationRemaining <= 0)) continue;
        const d = Math.hypot(other.x - a.x, other.y - a.y);
        if (d < mateDist) {
          mateDist = d;
          closestMate = other;
        }
      }
    }

    if (closestMate) {
      if (mateDist < 2.2) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;

        female.isPregnant = true;
        female.gestationRemaining = (female.species === 'mosquito') ? 5.0 : ((female.species === 'butterfly') ? 7.0 : 14.0);
        female.daysPregnant = 0.0;
        female.litterSize = 10 + Math.floor(Math.random() * 20);
        female.matingCooldown = female.gestationRemaining + 10.0;
        female.estrusDurationRemaining = 0.0;

        male.matingCooldown = 15.0;
      } else {
        targetX = closestMate.x;
        targetY = closestMate.y;
        return { targetX, targetY };
      }
    }
  }

  // 2. Comportamento Trófico (Predação e Forrageamento Solitário)
  if (a.diet === 'carnivore' && a.hunger > 35.0) {
    let targetBug = null;
    let minD = 40.0;
    for (let j = 0; j < animals.length; j++) {
      const prey = animals[j];
      if (prey.id === a.id || prey.hp <= 0) continue;
      if (['butterfly', 'mosquito', 'grasshopper', 'roach'].includes(prey.species)) {
        const d = Math.hypot(prey.x - a.x, prey.y - a.y);
        if (d < minD) {
          minD = d;
          targetBug = prey;
        }
      }
    }

    if (targetBug) {
      if (minD < 1.8) {
        // Multi-ataque ou ataque do predador
        const dmg = a.attackPower || 18.0;
        targetBug.hp -= dmg;
        a.hunger = Math.max(0, a.hunger - 35.0);
        if (targetBug.hp <= 0 && ctx.onPredationSuccess) {
          ctx.onPredationSuccess(targetBug, a);
        }
      } else {
        targetX = targetBug.x;
        targetY = targetBug.y;
        return { targetX, targetY };
      }
    }
  }

  // 3. Hematofagia do Mosquito-prego
  if (a.species === 'mosquito' && a.hunger > 40.0) {
    let host = null;
    let minD = 35.0;
    for (let j = 0; j < animals.length; j++) {
      const target = animals[j];
      if (target.id === a.id || target.hp <= 0) continue;
      if (['rat', 'cat', 'caiman', 'tortoise'].includes(target.species)) {
        const d = Math.hypot(target.x - a.x, target.y - a.y);
        if (d < minD) {
          minD = d;
          host = target;
        }
      }
    }
    if (host) {
      if (minD < 1.6) {
        a.hunger = Math.max(0, a.hunger - 40.0);
        host.hp -= 0.5;
        return { targetX: a.x, targetY: a.y };
      } else {
        targetX = host.x;
        targetY = host.y;
        return { targetX, targetY };
      }
    }
  }

  // 4. Herbivoria e Decomposição Geral
  const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
  if (a.diet === 'herbivore' && biomass && biomass[curIdx] > 2.0 && a.hunger > 30.0) {
    const bite = Math.min(biomass[curIdx], 2.0 * dt);
    biomass[curIdx] -= bite;
    a.hunger = Math.max(0, a.hunger - bite * 2.0);
  }

  // Voo e Movimentação Geral
  a.wanderAngle += (Math.random() - 0.5) * 0.9 * dt;
  targetX = a.x + Math.cos(a.wanderAngle) * (a.speed * 1.2);
  targetY = a.y + Math.sin(a.wanderAngle) * (a.speed * 1.2);

  return { targetX, targetY };
}


/**
 * Mecânica de Defesa Territorial Feroz dos Insetos Sociais:
 * Qualquer animal estranho (mamíferos, répteis ou insetos rivais) que invada
 * o perímetro da colônia é atacado com extrema ferocidade por centenas de soldados e operárias.
 */
function applyColonyDefense(a, nests, dt, ctx) {
  if (!a || a.hp <= 0 || a.enteredNest) return null;
  if (!nests || !Array.isArray(nests)) return null;

  // Peixes em água profunda não são atacados por formigueiros/cupinzeiros terrestres
  if (a.species === 'tambaqui' || a.species === 'traira' || a.species === 'piranha') {
    return null;
  }

  let attackedByColony = null;
  let minColonyDist = 999.0;

  for (let ni = 0; ni < nests.length; ni++) {
    const col = nests[ni];
    if (!col.isSocialColony) continue;

    // Se o animal pertence ou é cria desta mesma colônia (ex: operária, soldado ou rainha virgem em voo), não é atacado
    if (a.nestId === col.id || a.originNestId === col.id) continue;

    // Raio de defesa territorial do ninho (em metros)
    const defRadius = (col.species === 'ant' ? 7.5 : (col.species === 'termite' ? 6.5 : 8.0));
    const dist = Math.hypot(a.x - col.x, a.y - col.y);

    if (dist < defRadius && dist < minColonyDist) {
      minColonyDist = dist;
      attackedByColony = col;
    }
  }

  if (!attackedByColony) {
    if (a.isUnderSwarmAttack) a.isUnderSwarmAttack = false;
    return null;
  }

  const col = attackedByColony;
  const defRadius = (col.species === 'ant' ? 7.5 : (col.species === 'termite' ? 6.5 : 8.0));
  
  // Proximidade: quanto mais próximo da entrada/monte, mais furioso e concentrado é o contra-ataque
  const proximityFactor = Math.max(0.4, 1.0 - (minColonyDist / defRadius));

  // Contingente defensor mobilizado pela colônia (soldados e operárias que saem para defender)
  // Cada carga interna representa 100 indivíduos.
  const colonyPop = Math.max(100, (col.charges || 4) * 100);
  const activeDefenders = Math.min(250, colonyPop * 0.40) * proximityFactor;

  // Dano coletivo feroz: 0.1 de poder por indivíduo defensor
  // Ex: 150 defensores * 0.1 = 15.0 de dano por segundo!
  const dps = activeDefenders * 0.1;
  const damage = dps * dt;
  a.hp = Math.max(0, a.hp - damage);

  // Reação do invasor: Pânico, picadas generalizadas e fuga em alta velocidade
  a.isUnderSwarmAttack = true;
  a.swarmAttackTimer = 1.2;
  a.currentSprintBoost = 2.4; // Dispara em velocidade máxima de pânico

  // Vetor de Repulsão Violenta (foge na direção oposta ao centro da colônia)
  const dx = a.x - col.x;
  const dy = a.y - col.y;
  const len = Math.hypot(dx, dy) || 1.0;
  const fleeDirX = dx / len;
  const fleeDirY = dy / len;
  const fleeTargetX = a.x + fleeDirX * 35.0;
  const fleeTargetY = a.y + fleeDirY * 35.0;

  // Ativa alerta de defesa e combate na colônia para a interface visual
  col.defensiveAlertTimer = 1.6;
  col.lastInvaderPos = { x: a.x, y: a.y, species: a.species, name: a.name || a.species };
  col.totalInvadersRepelled = (col.totalInvadersRepelled || 0) + 1;

  // Se o animal não resistiu ao ataque feroz e morreu no perímetro do ninho:
  if (a.hp <= 0) {
    if (ctx && typeof ctx.applyDeathDecomposition === 'function') {
      ctx.applyDeathDecomposition(a.x, a.y);
    }
    // A colônia recolhe a biomassa e proteína do invasor abatido
    col.resourcesKg = (col.resourcesKg || 0) + 3.5;
    console.log(`⚔️ [DEFESA FEROZ] Colônia '${col.name}' abateu invasor (${a.name || a.species})! +3.5kg de proteína estocados.`);
  }

  return {
    isUnderAttack: true,
    colony: col,
    fleeTargetX,
    fleeTargetY,
    damageApplied: damage
  };
}

/**
 * Defesa de campo: se um animal não-membro pisoteia ou invade o raio de um enxame forrageador (ex: < 2.2m)
 */
function applySwarmFieldDefense(a, animals, dt) {
  if (!a || a.hp <= 0 || a.isSocial) return null;
  if (!animals || !Array.isArray(animals)) return null;

  for (let i = 0; i < animals.length; i++) {
    const s = animals[i];
    if (!s.isSocial || s.hp <= 0 || s.enteredNest) continue;
    const d = Math.hypot(a.x - s.x, a.y - s.y);
    if (d < 2.2) {
      // O enxame defende com seu contingente (0.1 de ataque por ponto de HP = até 10 DPS)
      const dmg = (s.hp * (s.attackPower || 0.1)) * 0.6 * dt;
      a.hp = Math.max(0, a.hp - dmg);
      a.isUnderSwarmAttack = true;
      a.currentSprintBoost = 1.9;
      const dx = a.x - s.x;
      const dy = a.y - s.y;
      const len = Math.hypot(dx, dy) || 1.0;
      return {
        isUnderAttack: true,
        fleeTargetX: a.x + (dx / len) * 22.0,
        fleeTargetY: a.y + (dy / len) * 22.0
      };
    }
  }
  return null;
}

// Vinculação de escopo para ambiente browser e Node.js
if (typeof window !== 'undefined') {
  window.InsectSpecies = {
    createInitialInsects,
    updateSocialColonies,
    updateInsectBehavior,
    isWaterSpot,
    findSafeDryLandCoords,
    applyColonyDefense,
    applySwarmFieldDefense
  };
  window.isWaterSpot = isWaterSpot;
  window.findSafeDryLandCoords = findSafeDryLandCoords;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createInitialInsects,
    updateSocialColonies,
    updateInsectBehavior,
    isWaterSpot,
    findSafeDryLandCoords,
    applyColonyDefense,
    applySwarmFieldDefense
  };
}
