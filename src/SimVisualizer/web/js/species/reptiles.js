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
  const { animals, getIdx, matId, surfaceWater, applyDeathDecomposition, onPredationSuccess, timeOfDay, GRID_WIDTH, GRID_HEIGHT, MAT_WATER, MAT_SAND } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  const matWaterId = (typeof MAT_WATER !== 'undefined') ? MAT_WATER : 1;
  const matSandId = (typeof MAT_SAND !== 'undefined') ? MAT_SAND : 31;

  let targetX = a.x;
  let targetY = a.y;

  const curX = Math.floor(a.x);
  const curY = Math.floor(a.y);
  const curIdx = getIdx(curX, curY);

  // Status de estar na água
  const inWater = (matId[curIdx] === matWaterId || surfaceWater[curIdx] > 0.30);

  if (a.lungeCooldown > 0) a.lungeCooldown = Math.max(0, a.lungeCooldown - dt);

  // 1. Termorregulação (Banho de Sol em Praias Fluviais / Margem Imediata)
  const tod = (typeof timeOfDay !== 'undefined') ? timeOfDay : 12.0;
  const isSunnyDay = (tod >= 8.5 && tod <= 16.0);

  if (a.isBasking) {
    a.baskingTimer -= dt;
    if (a.baskingTimer <= 0) {
      a.isBasking = false;
      // Ao terminar o banho de sol, retorna imediatamente para a água
      const wCoords = (typeof getNearestWaterCoords === 'function') ? getNearestWaterCoords(a.x, a.y) : { x: a.x, y: 512.0 };
      const dirX = wCoords.x - a.x;
      const dirY = wCoords.y - a.y;
      const d = Math.hypot(dirX, dirY) || 1.0;
      return { targetX: a.x + (dirX / d) * 2.5, targetY: a.y + (dirY / d) * 2.5 };
    }
    // Permanece imóvel tomando sol na praia
    return { targetX: a.x, targetY: a.y };
  }

  // Oportunidade de iniciar banho de sol se estiver no rio próximo a uma praia de areia
  if (!a.isBasking && a.baskingTimer <= 0 && isSunnyDay && a.hunger < 45.0 && Math.random() < 0.015) {
    // Procura praia de areia (MAT_SAND) em raio de 10 células
    for (let dy = -8; dy <= 8; dy += 2) {
      for (let dx = -8; dx <= 8; dx += 2) {
        const nx = curX + dx, ny = curY + dy;
        if (nx >= 2 && nx < gridW - 2 && ny >= 2 && ny < gridH - 2) {
          const nIdx = getIdx(nx, ny);
          if (matId[nIdx] === matSandId && surfaceWater[nIdx] < 0.10) {
            a.isBasking = true;
            a.baskingTimer = 20.0 + Math.random() * 25.0;
            return { targetX: nx, targetY: ny };
          }
        }
      }
    }
  }

  // 2. Retorno Rígido à Água se estiver em terra seca e NÃO estiver tomando sol
  if (!inWater && !a.isBasking) {
    const wCoords = (typeof getNearestWaterCoords === 'function') ? getNearestWaterCoords(a.x, a.y) : { x: a.x, y: 512.0 };
    const dirX = wCoords.x - a.x;
    const dirY = wCoords.y - a.y;
    const d = Math.hypot(dirX, dirY) || 1.0;
    // Rasteja direto de volta para o rio ou meandro
    return { targetX: a.x + (dirX / d) * 3.0, targetY: a.y + (dirY / d) * 3.0 };
  }

  // 3. Cortejo Reprodutivo na Água
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 50.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'caiman').length < 22) {
    let closestMate = null;
    let mateDist = 70.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'caiman') continue;
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
      if (mateDist < 3.2) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 12.0;
          female.litterSize = 2 + Math.floor(Math.random() * 3);
          female.matingCooldown = 90.0;
          male.matingCooldown = 30.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 4. Predação Ativa de Topo na Água e na Margem (Gatilho hunger > 5.0)
  let targetPrey = null;
  let minDist = 35.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0 || prey.species === 'caiman') continue;

    // Jacaré só caça presas aquáticas OU presas que estejam na beira imediata da água (até 7m da água)
    const pIdx = getIdx(Math.floor(prey.x), Math.floor(prey.y));
    const preyInWater = (matId[pIdx] === matWaterId || surfaceWater[pIdx] > 0.20);
    const d = Math.hypot(prey.x - a.x, prey.y - a.y);

    if (preyInWater || d <= 12.0) {
      // Prioridade para peixes, roedores e pequenos animais
      let score = (100.0 - d);
      if (prey.species === 'tambaqui' || prey.species === 'traira') score += 30.0;
      if (prey.species === 'rat') score += 20.0;
      if (prey.species === 'cat') score += 25.0; // Predação oportunista de felinos na margem

      if (d < minDist) {
        minDist = d;
        targetPrey = prey;
      }
    }
  }

  // Execução do Bote Fatal de Emboscada
  if (targetPrey && a.hunger > 5.0) {
    const dirX = targetPrey.x - a.x;
    const dirY = targetPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    if (dist <= 3.8 && a.lungeCooldown <= 0) {
      a.lungeCooldown = 4.0;
      const damage = a.attackPower * (1.2 + Math.random() * 0.5); // Mordida esmagadora
      targetPrey.hp -= damage;
      a.hunger = Math.max(0, a.hunger - 55.0);

      if (targetPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(targetPrey.x, targetPrey.y);
        if (onPredationSuccess) onPredationSuccess(targetPrey, a);
      }
      return { targetX: targetPrey.x, targetY: targetPrey.y };
    } else {
      // Natação veloz de aproximação
      const rushSpeed = a.speed * 1.8;
      targetX = a.x + (dirX / dist) * rushSpeed;
      targetY = a.y + (dirY / dist) * rushSpeed;
      return { targetX, targetY };
    }
  }

  // 5. Patrulha Fluvial Contínua dentro do Leito dos Rios e Meandros
  for (let attempt = 0; attempt < 8; attempt++) {
    const testAngle = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.45 : -attempt * 0.45));
    const nextX = a.x + Math.cos(testAngle) * 2.2;
    const nextY = a.y + Math.sin(testAngle) * 2.2;
    if (nextX >= 4 && nextX < gridW - 4 && nextY >= 4 && nextY < gridH - 4) {
      const nIdx = getIdx(Math.floor(nextX), Math.floor(nextY));
      if (matId[nIdx] === matWaterId || surfaceWater[nIdx] > 0.25 || matId[nIdx] === matSandId) {
        a.wanderAngle = testAngle + (Math.random() - 0.5) * 0.25 * dt;
        return { targetX: nextX, targetY: nextY };
      }
    }
  }

  // Se estiver encostando na terra, curva de volta para a calha do rio
  const wCent = (typeof getNearestWaterCoords === 'function') ? getNearestWaterCoords(a.x, a.y) : { x: a.x, y: 512.0 };
  a.wanderAngle = Math.atan2(wCent.y - a.y, wCent.x - a.x);
  return { targetX: a.x + Math.cos(a.wanderAngle) * 2.0, targetY: a.y + Math.sin(a.wanderAngle) * 2.0 };
}


// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.ReptileSpecies = {
    createInitialReptiles,
    updateTortoiseBehavior,
    updateCaimanBehavior
  };
}
