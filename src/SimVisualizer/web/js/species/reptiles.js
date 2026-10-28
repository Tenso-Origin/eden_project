// =========================================================================
// MÓDULO DE RÉPTEIS: JABUTI-TINGA E JACARÉ-AÇU (BACIA AMAZÔNICA 2048x1024)
// =========================================================================

/**
 * Criação da população de répteis distribuída por habitat real
 */
function createInitialReptiles(oxbowLakes, gridWidth = 2048, gridHeight = 1024) {
  const reptileList = [];
  const TORTOISE_COUNT = 24; // Jabutis em platôs de terra firme
  const CAIMAN_COUNT = 14;   // Jacarés nas praias e meandros fluviais

  // 1. Jabuti-tinga (Chelonoidis denticulatus) - Platôs de Terra Firme elevados
  for (let i = 0; i < TORTOISE_COUNT; i++) {
    // Escolhe pontos distantes do rio em terra firme
    let x = 100 + Math.random() * (gridWidth - 200);
    let y = 80 + Math.random() * (gridHeight - 160);
    if (typeof isPointInWaterBody === 'function') {
      while (isPointInWaterBody(x, y)) {
        x = 100 + Math.random() * (gridWidth - 200);
        y = 80 + Math.random() * (gridHeight - 160);
      }
    }

    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
    const gestationDays = 40.0;
    const gestationRem = isPregnantInit ? (2.0 + Math.random() * (gestationDays - 2.0)) : 0.0;

    reptileList.push({
      id: 4000 + i,
      species: 'tortoise',
      diet: 'herbivore',
      name: 'Jabuti-tinga',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 10.0 + Math.random() * 20.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 0.65,
      attackPower: 4.0,
      defensePower: 85.0,
      isRetracted: false,
      retractedTimer: 0.0,
      ageInDays: 1200.0 + Math.random() * 2500.0,
      maxLifespan: 18250.0, // ~50 anos

      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (3 + Math.floor(Math.random() * 4)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 90.0) : (10.0 + Math.random() * 40.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 60.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 8.0) : 0.0,

      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  // 2. Jacaré-açu (Melanosuchus niger) - Praias dos meandros e remansos
  for (let i = 0; i < CAIMAN_COUNT; i++) {
    // Posiciona em praias fluviais ou margens de lagos de ferradura
    let x, y;
    if (oxbowLakes && oxbowLakes.length > 0 && Math.random() < 0.50) {
      const lake = oxbowLakes[Math.floor(Math.random() * oxbowLakes.length)];
      const ang = lake.startAng + Math.random() * (lake.endAng - lake.startAng);
      const rad = lake.r + lake.width * 1.1; // Na praia ao lado do lago
      x = lake.cx + Math.cos(ang) * rad;
      y = lake.cy + Math.sin(ang) * rad;
    } else {
      x = 150 + Math.random() * (gridWidth - 300);
      const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
      y = yRiver + (Math.random() < 0.5 ? 35 : -35);
    }

    x = Math.max(20, Math.min(gridWidth - 20, x));
    y = Math.max(20, Math.min(gridHeight - 20, y));

    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
    const gestationDays = 45.0;
    const gestationRem = isPregnantInit ? (2.0 + Math.random() * (gestationDays - 2.0)) : 0.0;

    reptileList.push({
      id: 5000 + i,
      species: 'caiman',
      diet: 'carnivore',
      name: 'Jacaré-açu',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 15.0 + Math.random() * 20.0,
      thirst: 0.0,
      speed: 1.6,
      burstSpeed: 6.5,
      attackPower: 68.0,
      defensePower: 28.0,
      lungeCooldown: 0.0,
      isBasking: false,
      baskingTimer: 0.0,
      ageInDays: 800.0 + Math.random() * 1500.0,
      maxLifespan: 14600.0, // ~40 anos

      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (3 + Math.floor(Math.random() * 3)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 120.0) : (20.0 + Math.random() * 60.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 90.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.20) ? (Math.random() * 10.0) : 0.0,

      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  return reptileList;
}

/**
 * Atualização comportamental do Jabuti-tinga
 */
function updateTortoiseBehavior(a, dt, ctx) {
  const { animals, biomass, getIdx, matId, surfaceWater, MAT_WATER, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Defesa Passiva: Retração na Carapaça se ameaçado
  if (a.retractedTimer > 0) {
    a.retractedTimer -= dt;
    a.isRetracted = true;
    return { targetX: a.x, targetY: a.y };
  } else {
    a.isRetracted = false;
  }

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.hp <= 0) continue;
    if (other.species === 'cat' || other.species === 'caiman' || other.species === 'carcara') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      if (d < 7.5) {
        a.isRetracted = true;
        a.retractedTimer = 6.0;
        return { targetX: a.x, targetY: a.y };
      }
    }
  }

  // 2. Cortejo e Acasalamento
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'tortoise').length < 45) {
    let closestMate = null;
    let mateDist = 45.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'tortoise') continue;
      if (other.sex !== a.sex && other.matingCooldown <= 0 && other.hunger < 50.0) {
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
      if (mateDist < 2.2) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Forrageamento de Vegetação Rasteira
  if (a.hunger > 15.0) {
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (biomass && biomass[curIdx] > 5.0) {
      const bite = Math.min(biomass[curIdx], 3.0 * dt);
      biomass[curIdx] -= bite;
      a.hunger = Math.max(0, a.hunger - bite * 3.5);
    }
  }

  // 4. Locomoção em terra firme (evita entrar na água funda)
  for (let attempt = 0; attempt < 8; attempt++) {
    const testAng = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.45 : -attempt * 0.45));
    const nextX = Math.max(15, Math.min(gridW - 15, a.x + Math.cos(testAng) * (a.speed * 1.5)));
    const nextY = Math.max(15, Math.min(gridH - 15, a.y + Math.sin(testAng) * (a.speed * 1.5)));
    const nIdx = getIdx(Math.floor(nextX), Math.floor(nextY));

    // Jabuti não nada em água funda
    if (matId[nIdx] !== MAT_WATER && (!surfaceWater || surfaceWater[nIdx] < 0.35)) {
      a.wanderAngle = testAng + (Math.random() - 0.5) * 0.2 * dt;
      targetX = nextX;
      targetY = nextY;
      return { targetX, targetY };
    }
  }

  a.wanderAngle += Math.PI * 0.8;
  targetX = Math.max(15, Math.min(gridW - 15, a.x + Math.cos(a.wanderAngle) * 1.0));
  targetY = Math.max(15, Math.min(gridH - 15, a.y + Math.sin(a.wanderAngle) * 1.0));
  return { targetX, targetY };
}

/**
 * Atualização comportamental do Jacaré-açu
 */
function updateCaimanBehavior(a, dt, ctx) {
  const { animals, getIdx, matId, surfaceWater, applyDeathDecomposition, onPredationSuccess, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  if (a.lungeCooldown > 0) a.lungeCooldown -= dt;

  // 1. Termorregulação (Banho de Sol na Praia)
  if (a.hunger < 25.0 && a.baskingTimer <= 0 && Math.random() < 0.005) {
    a.isBasking = true;
    a.baskingTimer = 15.0 + Math.random() * 20.0;
  }

  if (a.isBasking) {
    a.baskingTimer -= dt;
    if (a.baskingTimer <= 0) a.isBasking = false;
    return { targetX: a.x, targetY: a.y };
  }

  // 2. Cortejo Reprodutivo
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'caiman').length < 18) {
    let closestMate = null;
    let mateDist = 60.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'caiman') continue;
      if (other.sex !== a.sex && other.matingCooldown <= 0 && other.hunger < 50.0) {
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
      if (mateDist < 3.0) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Detecção de presas fluviais e marginais
  let targetPrey = null;
  let minDist = 28.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0 || prey.species === 'caiman') continue;

    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d < minDist) {
      minDist = d;
      targetPrey = prey;
    }
  }

  // 4. Execução do Bote de Emboscada
  if (targetPrey && a.hunger > 18.0) {
    const dirX = targetPrey.x - a.x;
    const dirY = targetPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    if (dist <= 3.5 && a.lungeCooldown <= 0) {
      a.lungeCooldown = 4.5;
      const damage = a.attackPower * (0.85 + Math.random() * 0.4);
      targetPrey.hp -= damage;
      a.hunger = Math.max(0, a.hunger - 40.0);

      if (targetPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(targetPrey.x, targetPrey.y);
        if (onPredationSuccess) onPredationSuccess(targetPrey, a);
      }
      return { targetX: targetPrey.x, targetY: targetPrey.y };
    } else {
      targetX = a.x + (dirX / dist) * a.speed * 2.0;
      targetY = a.y + (dirY / dist) * a.speed * 2.0;
      return { targetX, targetY };
    }
  }

  // 5. Patrulha anfíbia suave entre o leito do rio e as praias
  a.wanderAngle += (Math.random() - 0.5) * 0.4 * dt;
  targetX = Math.max(20, Math.min(gridW - 20, a.x + Math.cos(a.wanderAngle) * (a.speed * 1.5)));
  targetY = Math.max(20, Math.min(gridH - 20, a.y + Math.sin(a.wanderAngle) * (a.speed * 1.5)));

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.ReptileSpecies = {
    createInitialReptiles,
    updateTortoiseBehavior,
    updateCaimanBehavior
  };
}
