// =========================================================================
// MÓDULO DE ESPÉCIES AQUÁTICAS: TAMBAQUI E TRAÍRA (BACIA FLUVIAL AMAZÔNICA)
// =========================================================================

/**
 * Criação da fauna aquática inicial distribuída na rede fluvial e lagos de meandro
 */
function createInitialAquatic(oxbowLakes, gridWidth = 2048, gridHeight = 1024) {
  const aquaticList = [];
  const TAMBAQUI_COUNT = 75; // Cardumes de tambaquis ao longo de toda a bacia fluvial
  const TRAIRA_COUNT = 14;   // Predadores solitários territoriais de emboscada

  // Função auxiliar para obter pontos de desova fluviais válidos
  function getRandomAquaticSpawn(preferLakes = false) {
    if (preferLakes && oxbowLakes && oxbowLakes.length > 0 && Math.random() < 0.65) {
      // Lago de ferradura
      const lake = oxbowLakes[Math.floor(Math.random() * oxbowLakes.length)];
      const ang = lake.startAng + Math.random() * (lake.endAng - lake.startAng);
      const rad = lake.r + (Math.random() - 0.5) * (lake.width * 0.7);
      return {
        x: Math.max(10, Math.min(gridWidth - 10, lake.cx + Math.cos(ang) * rad)),
        y: Math.max(10, Math.min(gridHeight - 10, lake.cy + Math.sin(ang) * rad))
      };
    } else {
      // Calha do rio principal ou afluente
      const rx = 100 + Math.random() * (gridWidth - 200);
      let ry = 0;
      if (typeof getRiverTributaryY === 'function' && rx < 1200 && Math.random() < 0.35) {
        ry = getRiverTributaryY(rx) + (Math.random() - 0.5) * 16.0;
      } else if (typeof getRiverMainY === 'function') {
        ry = getRiverMainY(rx) + (Math.random() - 0.5) * 24.0;
      } else {
        ry = 512.0 + Math.sin(rx * 0.003) * 150.0;
      }
      return {
        x: Math.max(10, Math.min(gridWidth - 10, rx)),
        y: Math.max(10, Math.min(gridHeight - 10, ry))
      };
    }
  }

  // 1. Tambaquis (Colossoma macropomum) - Herbívoros/Frugívoros da calha dos rios e várzeas
  for (let i = 0; i < TAMBAQUI_COUNT; i++) {
    const pt = getRandomAquaticSpawn(false);
    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.25);
    const gestationDays = 10.0;
    const gestationRem = isPregnantInit ? (1.0 + Math.random() * (gestationDays - 1.0)) : 0.0;

    aquaticList.push({
      id: 2000 + i,
      species: 'tambaqui',
      diet: 'herbivore',
      name: 'Tambaqui da Amazônia',
      sex: sex,
      x: pt.x,
      y: pt.y,
      hp: 100,
      maxHp: 100,
      hunger: 5.0 + Math.random() * 15.0,
      speed: 2.3,
      attackPower: 4.0,
      defensePower: 8.0,
      ageInDays: 300.0 + Math.random() * 400.0,
      maxLifespan: 9125.0, // ~25 anos
      
      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (5 + Math.floor(Math.random() * 6)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 35.0) : (5.0 + Math.random() * 20.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 28.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.3) ? (Math.random() * 4.0) : 0.0,

      fearTimer: 0.0,
      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  // 2. Traíras (Hoplias malabaricus) - Predadores de emboscada em remansos e lagos de ferradura
  for (let i = 0; i < TRAIRA_COUNT; i++) {
    const pt = getRandomAquaticSpawn(true);
    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
    const gestationDays = 6.0;
    const gestationRem = isPregnantInit ? (1.0 + Math.random() * (gestationDays - 1.0)) : 0.0;

    aquaticList.push({
      id: 3000 + i,
      species: 'traira',
      diet: 'carnivore',
      name: 'Traíra da Amazônia',
      sex: sex,
      x: pt.x,
      y: pt.y,
      hp: 120,
      maxHp: 120,
      hunger: 5.0 + Math.random() * 15.0,
      speed: 1.8,
      lungeSpeed: 6.2,
      attackPower: 32.0,
      defensePower: 9.0,
      ageInDays: 350.0 + Math.random() * 300.0,
      maxLifespan: 4380.0, // ~12 anos

      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (2 + Math.floor(Math.random() * 3)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 60.0) : (10.0 + Math.random() * 30.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 45.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 3.5) : 0.0,

      isLurking: true,
      lungeCooldown: 0.0,
      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  return aquaticList;
}

/**
 * Função utilitária que detecta se uma coordenada tem água navegável para peixes
 */
function isNavigableWater(x, y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER) {
  if (x < 2 || x >= gridW - 2 || y < 2 || y >= gridH - 2) return false;
  const idx = getIdx(Math.floor(x), Math.floor(y));
  return (matId[idx] === MAT_WATER || surfaceWater[idx] > 0.35);
}

/**
 * Atualização comportamental do Tambaqui na rede fluvial
 */
function updateTambaquiBehavior(a, dt, ctx) {
  const { animals, matId, surfaceWater, getIdx, grains, biomass, weather, MAT_WATER, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Fuga de ameaças aquáticas (Traíras ativas e Jacarés)
  if (a.fearTimer > 0) a.fearTimer -= dt;
  let closestThreat = null;
  let minDist = 18.0;

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.hp <= 0) continue;
    if (other.species === 'traira') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      const detectionThreshold = other.isLurking ? 9.0 : 20.0;
      if (d < detectionThreshold && d < minDist) {
        minDist = d;
        closestThreat = other;
      }
    } else if (other.species === 'caiman') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      if (d < 24.0 && d < minDist) {
        minDist = d;
        closestThreat = other;
      }
    }
  }

  if (closestThreat) {
    a.fearTimer = 2.8;
    const escapeX = a.x - closestThreat.x;
    const escapeY = a.y - closestThreat.y;
    const escDist = Math.hypot(escapeX, escapeY) || 1.0;
    const testEscX = a.x + (escapeX / escDist) * 8.0;
    const testEscY = a.y + (escapeY / escDist) * 8.0;
    if (isNavigableWater(testEscX, testEscY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      return { targetX: testEscX, targetY: testEscY };
    }
  }

  // 2. Cortejo e Desova Fértil
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && a.hp > 50 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate) {
    let closestMate = null;
    let mateDist = 32.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'tambaqui') continue;
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
      if (mateDist < 2.5) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 10.0;
          female.litterSize = 5 + Math.floor(Math.random() * 6);
          female.matingCooldown = 45.0;
          male.matingCooldown = 15.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Forrageamento: Sementes caídas, frutos e macrófitas na várzea alagada
  if (a.hunger > 18.0) {
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (grains && grains[curIdx] > 1.0) {
      const bite = Math.min(grains[curIdx], 5.0 * dt);
      grains[curIdx] -= bite;
      a.hunger = Math.max(0, a.hunger - bite * 4.5);
    } else if (biomass && biomass[curIdx] > 4.0) {
      const biteBio = Math.min(biomass[curIdx], 4.0 * dt);
      biomass[curIdx] -= biteBio;
      a.hunger = Math.max(0, a.hunger - biteBio * 2.8);
    }
  }

  // 4. Navegação fluvial contínua: testa células à frente e curva suavemente se terra firme
  for (let attempt = 0; attempt < 8; attempt++) {
    const testAngle = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.4 : -attempt * 0.4));
    const nextX = a.x + Math.cos(testAngle) * 3.5;
    const nextY = a.y + Math.sin(testAngle) * 3.5;

    if (isNavigableWater(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      a.wanderAngle = testAngle + (Math.random() - 0.5) * 0.25 * dt;
      targetX = nextX;
      targetY = nextY;
      return { targetX, targetY };
    }
  }

  // Se preso perto da margem, inverte rumo
  a.wanderAngle += Math.PI * 0.8;
  targetX = a.x + Math.cos(a.wanderAngle) * 2.0;
  targetY = a.y + Math.sin(a.wanderAngle) * 2.0;
  return { targetX, targetY };
}

/**
 * Atualização comportamental da Traíra na rede fluvial
 */
function updateTrairaBehavior(a, dt, ctx) {
  const { animals, matId, surfaceWater, getIdx, weather, applyDeathDecomposition, onPredationSuccess, MAT_WATER, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  const timeOfDay = (weather && weather.timeOfDay != null) ? weather.timeOfDay : 12.0;
  const isNight = (timeOfDay < 6.0 || timeOfDay > 18.0);

  if (a.lungeCooldown > 0) a.lungeCooldown = Math.max(0, a.lungeCooldown - dt);

  // 1. Cortejo territorial no crepúsculo/noite
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 50.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'traira').length < 20) {
    let closestMate = null;
    let mateDist = 40.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'traira') continue;
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
      if (mateDist < 2.5) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 6.0;
          female.litterSize = 2 + Math.floor(Math.random() * 3);
          female.matingCooldown = 65.0;
          male.matingCooldown = 25.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 2. Estado Diurno: Tocaia e Camuflagem no fundo/vegetação
  if (!isNight) {
    a.isLurking = true;
    let opportunisticPrey = null;
    let minDist = 7.0;

    for (let j = 0; j < animals.length; j++) {
      const p = animals[j];
      if (p === a || p.hp <= 0) continue;
      if (p.species === 'tambaqui' || p.species === 'rat' || p.species === 'dragonfly') {
        const d = Math.hypot(p.x - a.x, p.y - a.y);
        if (d < minDist) {
          minDist = d;
          opportunisticPrey = p;
        }
      }
    }

    if (opportunisticPrey && a.lungeCooldown <= 0) {
      const dirX = opportunisticPrey.x - a.x;
      const dirY = opportunisticPrey.y - a.y;
      const dist = Math.hypot(dirX, dirY) || 1.0;
      targetX = opportunisticPrey.x;
      targetY = opportunisticPrey.y;

      if (dist <= 2.2) {
        const damage = a.attackPower * (0.9 + Math.random() * 0.3);
        opportunisticPrey.hp -= damage;
        a.lungeCooldown = 5.0;
        a.hunger = Math.max(0, a.hunger - 70.0);

        if (opportunisticPrey.hp <= 0) {
          if (applyDeathDecomposition) applyDeathDecomposition(opportunisticPrey.x, opportunisticPrey.y);
          if (onPredationSuccess) onPredationSuccess(opportunisticPrey, a);
        }
      }
      return { targetX, targetY };
    }

    // De dia quase estacionária
    a.wanderAngle += (Math.random() - 0.5) * 0.1 * dt;
    targetX = a.x + Math.cos(a.wanderAngle) * 0.25;
    targetY = a.y + Math.sin(a.wanderAngle) * 0.25;
    return { targetX, targetY };
  }

  // 3. Estado Noturno: Caçador Ativo por Emboscada
  a.isLurking = false;
  let bestPrey = null;
  let bestScore = -999;
  const detectionRadius = (a.hunger > 35.0) ? 28.0 : 18.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0) continue;

    const isAquatic = (prey.species === 'tambaqui' || prey.species === 'dragonfly');
    const isVulnerable = (prey.species === 'rat' && isNavigableWater(prey.x, prey.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER));

    if (!isAquatic && !isVulnerable) continue;

    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d <= detectionRadius) {
      let score = (100.0 - d);
      if (prey.hp < 40) score += 30;
      if (score > bestScore) {
        bestScore = score;
        bestPrey = prey;
      }
    }
  }

  if (bestPrey && a.hunger > 12.0) {
    const dirX = bestPrey.x - a.x;
    const dirY = bestPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;
    targetX = bestPrey.x;
    targetY = bestPrey.y;

    if (dist <= 2.2 && a.lungeCooldown <= 0) {
      const damage = a.attackPower * (0.85 + Math.random() * 0.4);
      bestPrey.hp -= damage;
      a.lungeCooldown = 4.0;
      a.hunger = Math.max(0, a.hunger - 65.0);

      if (bestPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(bestPrey.x, bestPrey.y);
        if (onPredationSuccess) onPredationSuccess(bestPrey, a);
      }
    } else {
      const rush = (dist < 10.0 && a.lungeCooldown <= 0) ? a.lungeSpeed : a.speed;
      targetX = a.x + (dirX / dist) * rush * 1.5;
      targetY = a.y + (dirY / dist) * rush * 1.5;
    }
    return { targetX, targetY };
  }

  // 4. Patrulha territorial aquática
  for (let attempt = 0; attempt < 8; attempt++) {
    const testAngle = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.4 : -attempt * 0.4));
    const nextX = a.x + Math.cos(testAngle) * 2.2;
    const nextY = a.y + Math.sin(testAngle) * 2.2;

    if (isNavigableWater(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      a.wanderAngle = testAngle + (Math.random() - 0.5) * 0.3 * dt;
      targetX = nextX;
      targetY = nextY;
      return { targetX, targetY };
    }
  }

  a.wanderAngle += Math.PI * 0.7;
  targetX = a.x + Math.cos(a.wanderAngle) * 1.5;
  targetY = a.y + Math.sin(a.wanderAngle) * 1.5;
  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.AquaticSpecies = {
    createInitialAquatic,
    updateTambaquiBehavior,
    updateTrairaBehavior,
    updatePiranhaBehavior: updateTrairaBehavior
  };
}
