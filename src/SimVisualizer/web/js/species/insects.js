// =========================================================================
// MÓDULO DE INSETOS NEOTROPICAIS (10 ESPÉCIES - BACIA AMAZÔNICA 2048x1024)
// =========================================================================

/**
 * Criação da população inicial de insetos distribuída por nicho ecológico
 */
function createInitialInsects(gridWidth = 2048, gridHeight = 1024) {
  const insectList = [];

  const SPECIES_CONFIG = [
    { species: 'ant', count: 40, name: 'Formiga-saúva', diet: 'herbivore', spd: 1.1, icon: '🐜', zone: 'forest', femaleRatio: 0.80, gest: 12.0, litter: [8, 16], mat: 25.0, est: 15.0 },
    { species: 'bee', count: 30, name: 'Abelha-jataí', diet: 'herbivore', spd: 2.8, icon: '🐝', zone: 'flowers', femaleRatio: 0.80, gest: 10.0, litter: [6, 12], mat: 20.0, est: 14.0 },
    { species: 'butterfly', count: 30, name: 'Borboleta-morfo', diet: 'herbivore', spd: 2.2, icon: '🦋', zone: 'clearings', femaleRatio: 0.50, gest: 7.0, litter: [5, 9], mat: 15.0, est: 10.0 },
    { species: 'dragonfly', count: 25, name: 'Libélula-imperador', diet: 'carnivore', spd: 3.8, icon: '🪰', zone: 'water', femaleRatio: 0.50, gest: 10.0, litter: [4, 7], mat: 25.0, est: 14.0 },
    { species: 'beetle', count: 25, name: 'Besouro-hércules', diet: 'decomposer', spd: 0.9, icon: '🪲', zone: 'forest', femaleRatio: 0.50, gest: 20.0, litter: [2, 5], mat: 40.0, est: 25.0 },
    { species: 'mosquito', count: 40, name: 'Mosquito-prego', diet: 'carnivore', spd: 2.0, icon: '🦟', zone: 'water', femaleRatio: 0.60, gest: 5.0, litter: [8, 18], mat: 10.0, est: 7.0 },
    { species: 'grasshopper', count: 35, name: 'Gafanhoto-esperança', diet: 'herbivore', spd: 2.4, icon: '🦗', zone: 'varzea', femaleRatio: 0.50, gest: 14.0, litter: [5, 10], mat: 30.0, est: 18.0 },
    { species: 'mantis', count: 20, name: 'Louva-a-deus', diet: 'carnivore', spd: 1.2, icon: '🍃', zone: 'varzea', femaleRatio: 0.50, gest: 18.0, litter: [3, 7], mat: 40.0, est: 20.0 },
    { species: 'roach', count: 28, name: 'Barata-da-mata', diet: 'decomposer', spd: 1.8, icon: '🪳', zone: 'forest', femaleRatio: 0.50, gest: 20.0, litter: [6, 12], mat: 35.0, est: 18.0 },
    { species: 'termite', count: 35, name: 'Cupim-da-terra', diet: 'decomposer', spd: 0.8, icon: '🪵', zone: 'wood', femaleRatio: 0.70, gest: 10.0, litter: [10, 20], mat: 20.0, est: 12.0 }
  ];

  let idCounter = 8000;

  for (const cfg of SPECIES_CONFIG) {
    for (let i = 0; i < cfg.count; i++) {
      let x, y;
      if (cfg.zone === 'water') {
        // Perto dos rios ou lagos de ferradura
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 35.0;
      } else if (cfg.zone === 'varzea') {
        // Várzea aberta rica em gramíneas
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 160.0;
      } else {
        // Floresta de terra firme
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
        hunger: 10.0 + Math.random() * 20.0,
        speed: cfg.spd,
        attackPower: (cfg.diet === 'carnivore' ? 18.0 : 2.0),
        defensePower: 2.0,
        ageInDays: 20.0 + Math.random() * 100.0,
        maxLifespan: 365.0, // ~1 ano
        pollinateTimer: 0.0,
        wanderAngle: Math.random() * Math.PI * 2,

        // Ciclo Reprodutivo
        isPregnant: isPregnantInit,
        daysPregnant: isPregnantInit ? (cfg.gest - gestationRem) : 0.0,
        gestationRemaining: gestationRem,
        litterSize: isPregnantInit ? (cfg.litter[0] + Math.floor(Math.random() * (cfg.litter[1] - cfg.litter[0] + 1))) : 0,
        matingCooldown: isPregnantInit ? (gestationRem + 15.0) : (5.0 + Math.random() * 20.0),
        estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * cfg.est),
        estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 3.0) : 0.0
      });
    }
  }

  return insectList;
}

/**
 * Atualização comportamental dos insetos
 */
function updateInsectBehavior(a, dt, ctx) {
  const { animals, biomass, grains, getIdx, applyDeathDecomposition, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Cortejo / Enxameação Reprodutiva
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
      targetX = closestMate.x;
      targetY = closestMate.y;
      if (mateDist < 2.0) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        }
      }
      return { targetX, targetY };
    }
  }

  // 2. Comportamentos tróficos específicos
  if (a.species === 'dragonfly' || a.species === 'mantis') {
    let targetBug = null;
    let minDist = 22.0;
    for (let j = 0; j < animals.length; j++) {
      const prey = animals[j];
      if (prey === a || prey.hp <= 0) continue;
      if (prey.species === 'mosquito' || prey.species === 'butterfly' || (a.species === 'mantis' && prey.species === 'grasshopper')) {
        const d = Math.hypot(prey.x - a.x, prey.y - a.y);
        if (d < minDist) {
          minDist = d;
          targetBug = prey;
        }
      }
    }

    if (targetBug && a.hunger > 3.0) {
      const dirX = targetBug.x - a.x;
      const dirY = targetBug.y - a.y;
      const dist = Math.hypot(dirX, dirY) || 1.0;
      targetX = targetBug.x;
      targetY = targetBug.y;
      if (dist <= 1.8) {
        targetBug.hp -= 25.0;
        a.hunger = Math.max(0, a.hunger - 25.0);
        if (targetBug.hp <= 0 && applyDeathDecomposition) {
          applyDeathDecomposition(targetBug.x, targetBug.y);
        }
      }
      return { targetX, targetY };
    }
  } else if (a.species === 'bee' || a.species === 'butterfly') {
    if (a.pollinateTimer > 0) {
      a.pollinateTimer -= dt;
      a.hunger = Math.max(0, a.hunger - 5.0 * dt);
      return { targetX: a.x, targetY: a.y };
    }
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (biomass && biomass[curIdx] > 12.0 && Math.random() < 0.05) {
      a.pollinateTimer = 3.0 + Math.random() * 4.0;
      return { targetX: a.x, targetY: a.y };
    }
  } else if (a.species === 'ant' || a.species === 'termite' || a.species === 'beetle' || a.species === 'roach') {
    if (a.hunger > 15.0) {
      const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
      if (biomass && biomass[curIdx] > 2.0) {
        const bite = Math.min(biomass[curIdx], 2.0 * dt);
        biomass[curIdx] -= bite;
        a.hunger = Math.max(0, a.hunger - bite * 3.0);
      }
    }
  }

  // 3. Deslocamento característico
  a.wanderAngle += (Math.random() - 0.5) * 0.8 * dt;
  targetX = Math.max(10, Math.min(gridW - 10, a.x + Math.cos(a.wanderAngle) * (a.speed * 1.5)));
  targetY = Math.max(10, Math.min(gridH - 10, a.y + Math.sin(a.wanderAngle) * (a.speed * 1.5)));

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.InsectSpecies = {
    createInitialInsects,
    updateInsectBehavior
  };
}
