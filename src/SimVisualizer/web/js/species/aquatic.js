// =========================================================================
// MÓDULO DA FAUNA AQUÁTICA AMAZÔNICA: TAMBAQUI E TRAÍRA (2048x1024)
// =========================================================================

/**
 * Função utilitária que detecta se uma coordenada tem água navegável para peixes
 */
function isNavigableWater(x, y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER) {
  if (x < 2 || x >= gridW - 2 || y < 2 || y >= gridH - 2) return false;
  const idx = getIdx(Math.floor(x), Math.floor(y));
  return (matId[idx] === MAT_WATER || surfaceWater[idx] > 0.35);
}

/**
 * Avalia o fator de proximidade da margem terrestre (0.0 = canal aberto / águas profundas, 1.0 = colado na terra)
 */
function getWaterDepthOrMarginFactor(x, y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, checkRadius = 4) {
  let landNeighbors = 0;
  const samples = 8;
  for (let i = 0; i < samples; i++) {
    const ang = (i / samples) * Math.PI * 2;
    const sx = Math.floor(x + Math.cos(ang) * checkRadius);
    const sy = Math.floor(y + Math.sin(ang) * checkRadius);
    if (!isNavigableWater(sx, sy, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      landNeighbors++;
    }
  }
  return landNeighbors / samples;
}

/**
 * Retorna as coordenadas da massa d'água mais próxima para retornar peixes/jacarés
 */
function getNearestWaterCoords(x, y) {
  let bestX = x;
  let bestY = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
  let minDistSq = (bestY - y) * (bestY - y);

  if (typeof OXBOW_LAKES !== 'undefined' && Array.isArray(OXBOW_LAKES)) {
    for (let k = 0; k < OXBOW_LAKES.length; k++) {
      const ox = OXBOW_LAKES[k];
      const dSq = (ox.cx - x) * (ox.cx - x) + (ox.cy - y) * (ox.cy - y);
      if (dSq < minDistSq) {
        minDistSq = dSq;
        bestX = ox.cx;
        bestY = ox.cy;
      }
    }
  }
  return { x: bestX, y: bestY };
}

/**
 * Criação da População Inicial de Peixes Estratificada nos Rios e Meandros
 */
function createInitialAquatic(OXBOW_LAKES, GRID_WIDTH = 2048, GRID_HEIGHT = 1024) {
  const aquaticList = [];
  let nextId = 7000;

  // 1. Tambaquis (75 espécimes distribuídos pelo canal do Rio Solimões/Amazonas)
  const TAMBAQUI_COUNT = 75;
  for (let i = 0; i < TAMBAQUI_COUNT; i++) {
    const rx = 100 + Math.random() * (GRID_WIDTH - 200);
    const riverY = (typeof getRiverMainY === 'function') ? getRiverMainY(rx) : 512.0;
    const ry = riverY + (Math.random() - 0.5) * 32.0;

    aquaticList.push({
      id: nextId++,
      species: 'tambaqui',
      sex: Math.random() < 0.5 ? 'male' : 'female',
      name: `Tambaqui #${i + 1}`,
      x: rx,
      y: ry,
      hp: 100,
      attackPower: 6.0,
      defensePower: 12.0,
      hunger: 10.0 + Math.random() * 20.0,
      thirst: 0.0,
      fatigue: 5.0,
      isSleeping: false,
      isPregnant: false,
      daysPregnant: 0.0,
      gestationRemaining: 0.0,
      litterSize: 0,
      matingCooldown: 15.0 + Math.random() * 20.0,
      estrusDurationRemaining: 0.0,
      ageInDays: 30.0 + Math.random() * 80.0,
      speed: 2.3,
      wanderAngle: Math.random() * Math.PI * 2,
      fearTimer: 0.0
    });
  }

  // 2. Traíras (14 espécimes concentradas nos 5 Lagos de Meandro Abandonado / Remansos)
  const TRAIRA_COUNT = 14;
  for (let i = 0; i < TRAIRA_COUNT; i++) {
    let spawnX, spawnY;
    if (OXBOW_LAKES && OXBOW_LAKES.length > 0) {
      const ox = OXBOW_LAKES[i % OXBOW_LAKES.length];
      const ang = ox.startAng + Math.random() * (ox.endAng - ox.startAng);
      spawnX = ox.cx + Math.cos(ang) * ox.r + (Math.random() - 0.5) * 6.0;
      spawnY = ox.cy + Math.sin(ang) * ox.r + (Math.random() - 0.5) * 6.0;
    } else {
      spawnX = 600 + Math.random() * 800;
      spawnY = 512 + (Math.random() - 0.5) * 30.0;
    }

    aquaticList.push({
      id: nextId++,
      species: 'traira',
      sex: Math.random() < 0.5 ? 'male' : 'female',
      name: `Traíra #${i + 1}`,
      x: spawnX,
      y: spawnY,
      hp: 100,
      attackPower: 45.0,
      defensePower: 18.0,
      hunger: 15.0 + Math.random() * 25.0,
      thirst: 0.0,
      fatigue: 5.0,
      isSleeping: false,
      isPregnant: false,
      daysPregnant: 0.0,
      gestationRemaining: 0.0,
      litterSize: 0,
      matingCooldown: 25.0 + Math.random() * 30.0,
      estrusDurationRemaining: 0.0,
      ageInDays: 45.0 + Math.random() * 100.0,
      speed: 1.8,
      lungeSpeed: 6.2,
      isLurking: true,
      lungeCooldown: 0.0,
      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  return aquaticList;
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

  // Se estiver fora d'água, emergência: nadar em direção à água mais próxima
  if (!isNavigableWater(a.x, a.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
    const wCoords = getNearestWaterCoords(a.x, a.y);
    const dirX = wCoords.x - a.x;
    const dirY = wCoords.y - a.y;
    const d = Math.hypot(dirX, dirY) || 1.0;
    return { targetX: a.x + (dirX / d) * 1.5, targetY: a.y + (dirY / d) * 1.5 };
  }

  // 1. Fuga de ameaças aquáticas (Traíras ativas e Jacarés)
  if (a.fearTimer > 0) a.fearTimer -= dt;
  let closestThreat = null;
  let minDist = 20.0;

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.hp <= 0) continue;
    if (other.species === 'traira') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      const detectionThreshold = other.isLurking ? 8.0 : 22.0;
      if (d < detectionThreshold && d < minDist) {
        minDist = d;
        closestThreat = other;
      }
    } else if (other.species === 'caiman') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      if (d < 26.0 && d < minDist) {
        minDist = d;
        closestThreat = other;
      }
    }
  }

  if (closestThreat) {
    a.fearTimer = 3.0;
    const escapeX = a.x - closestThreat.x;
    const escapeY = a.y - closestThreat.y;
    const escDist = Math.hypot(escapeX, escapeY) || 1.0;
    const testEscX = a.x + (escapeX / escDist) * 7.0;
    const testEscY = a.y + (escapeY / escDist) * 7.0;
    if (isNavigableWater(testEscX, testEscY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      return { targetX: testEscX, targetY: testEscY };
    }
  }

  // 2. Cortejo e Reprodução
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && a.hp > 50 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'tambaqui').length < 110) {
    let closestMate = null;
    let mateDist = 50.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'tambaqui') continue;
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

    if (closestMate && isNavigableWater(closestMate.x, closestMate.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
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
          female.gestationRemaining = 8.0;
          female.litterSize = 3 + Math.floor(Math.random() * 5);
          female.matingCooldown = 60.0;
          male.matingCooldown = 20.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Forrageamento fluvial (Biomassa bentônica de leito e macrófitas/grãos aluviais)
  let bestFoodX = a.x, bestFoodY = a.y;
  let bestScore = -999;
  const searchR = 28;
  const curX = Math.floor(a.x), curY = Math.floor(a.y);

  for (let dy = -searchR; dy <= searchR; dy += 4) {
    for (let dx = -searchR; dx <= searchR; dx += 4) {
      const nx = curX + dx, ny = curY + dy;
      if (!isNavigableWater(nx, ny, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) continue;
      const nIdx = getIdx(nx, ny);
      const aquaBio = biomass[nIdx] || 0;
      const aquaGrains = grains[nIdx] || 0;
      if (aquaBio < 1.0 && aquaGrains < 0.2) continue;

      // Penalização de proximidade da margem terrestre: evita que peixes fiquem grudados nas bordas
      const marginFactor = getWaterDepthOrMarginFactor(nx, ny, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, 3);
      let score = (aquaGrains * 8.0) + (aquaBio * 2.2);

      if (marginFactor > 0.2) {
        score -= marginFactor * 45.0; // Penaliza bordas e margens rasas
      } else {
        score += 15.0; // Bônus para águas abertas / canal central
      }

      const dist = Math.hypot(dx, dy);
      score -= dist * 0.4;

      if (score > bestScore) {
        bestScore = score;
        bestFoodX = nx;
        bestFoodY = ny;
      }
    }
  }

  // Consumo no local se houver biomassa bentônica ou grãos
  const curIdx = getIdx(curX, curY);
  if ((biomass[curIdx] || 0) > 2.0 && a.hunger > 5.0) {
    const eatB = Math.min(biomass[curIdx] - 1.0, 3.0 * dt);
    biomass[curIdx] -= eatB;
    a.hunger = Math.max(0, a.hunger - eatB * 16.0);
  }
  if ((grains[curIdx] || 0) > 0.3 && a.hunger > 5.0) {
    const eatG = Math.min(grains[curIdx], 2.5 * dt);
    grains[curIdx] -= eatG;
    a.hunger = Math.max(0, a.hunger - eatG * 25.0);
  }

  if (bestScore > 0.0 && a.hunger > 15.0) {
    return { targetX: bestFoodX, targetY: bestFoodY };
  }

  // 4. Natação fluvial suave mantendo-se dentro da calha aquática e longe das margens
  const curMargin = getWaterDepthOrMarginFactor(a.x, a.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, 4);
  if (curMargin > 0.2) {
    // Muito próximo da margem/terra: força reorientação em direção ao centro do rio/lago
    const wCent = getNearestWaterCoords(a.x, a.y);
    const steerAngle = Math.atan2(wCent.y - a.y, wCent.x - a.x);
    a.wanderAngle = steerAngle + (Math.random() - 0.5) * 0.3;
  }

  for (let attempt = 0; attempt < 8; attempt++) {
    const testAngle = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.45 : -attempt * 0.45));
    const nextX = a.x + Math.cos(testAngle) * 2.2;
    const nextY = a.y + Math.sin(testAngle) * 2.2;
    if (isNavigableWater(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      const nextMargin = getWaterDepthOrMarginFactor(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, 3);
      if (curMargin > 0.2 && nextMargin > curMargin && attempt < 6) {
        continue; // Prefere ângulos que afastam da margem
      }
      a.wanderAngle = testAngle + (Math.random() - 0.5) * 0.3 * dt;
      return { targetX: nextX, targetY: nextY };
    }
  }

  // Se nenhum ângulo imediato for água, reorienta para o centro da calha mais próxima
  const wCent = getNearestWaterCoords(a.x, a.y);
  a.wanderAngle = Math.atan2(wCent.y - a.y, wCent.x - a.x);
  return { targetX: a.x + Math.cos(a.wanderAngle) * 1.5, targetY: a.y + Math.sin(a.wanderAngle) * 1.5 };
}

/**
 * Atualização comportamental da Traíra (Predador Emboscador Restrito à Água)
 */
function updateTrairaBehavior(a, dt, ctx) {
  const { animals, matId, surfaceWater, getIdx, weather, applyDeathDecomposition, onPredationSuccess, MAT_WATER, GRID_WIDTH, GRID_HEIGHT } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // 0. Restrição rígida: se a Traíra estiver encalhada fora d'água, tentar voltar imediatamente
  const inWater = isNavigableWater(a.x, a.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER);
  if (!inWater) {
    const wCoords = getNearestWaterCoords(a.x, a.y);
    const dirX = wCoords.x - a.x;
    const dirY = wCoords.y - a.y;
    const d = Math.hypot(dirX, dirY) || 1.0;
    return { targetX: a.x + (dirX / d) * 1.2, targetY: a.y + (dirY / d) * 1.2 };
  }

  const timeOfDay = (weather && weather.timeOfDay != null) ? weather.timeOfDay : 12.0;
  const isNight = (timeOfDay < 6.0 || timeOfDay > 18.0);

  if (a.lungeCooldown > 0) a.lungeCooldown = Math.max(0, a.lungeCooldown - dt);

  // 1. Cortejo territorial no crepúsculo/noite
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 50.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'traira').length < 24) {
    let closestMate = null;
    let mateDist = 45.0;
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

    if (closestMate && isNavigableWater(closestMate.x, closestMate.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
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

  // 2. Predação Oportunista (Ativa dia e noite se houver presa próxima dentro d'água)
  // Gatilho calibrado: hunger > 5.0 (ataca com fome moderada e instinto)
  let bestPrey = null;
  let bestScore = -999;
  const detectionRadius = isNight ? 32.0 : 16.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0 || prey.species === 'traira' || prey.species === 'caiman') continue;

    // A PRESA DEVE OBRIGATORIAMENTE ESTAR DENTRO DA ÁGUA NAVEGÁVEL!
    if (!isNavigableWater(prey.x, prey.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) continue;

    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d <= detectionRadius) {
      let score = (100.0 - d);
      if (prey.species === 'tambaqui') score += 25.0; // Presa primária natural
      if (prey.species === 'rat') score += 18.0;      // Roedor nadando na água
      if (prey.hp < 50) score += 20.0;
      if (score > bestScore) {
        bestScore = score;
        bestPrey = prey;
      }
    }
  }

  if (bestPrey && a.hunger > 5.0) {
    const dirX = bestPrey.x - a.x;
    const dirY = bestPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;
    const rush = (dist < 10.0 && a.lungeCooldown <= 0) ? a.lungeSpeed : a.speed;

    const candTargetX = a.x + (dirX / dist) * rush * 1.5;
    const candTargetY = a.y + (dirY / dist) * rush * 1.5;

    // Só avança se a célula de ataque também for água navegável
    if (isNavigableWater(candTargetX, candTargetY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      targetX = candTargetX;
      targetY = candTargetY;
    } else {
      targetX = bestPrey.x;
      targetY = bestPrey.y;
    }

    if (dist <= 2.2 && a.lungeCooldown <= 0) {
      const damage = a.attackPower * (0.95 + Math.random() * 0.4);
      bestPrey.hp -= damage;
      a.lungeCooldown = 3.5;
      a.hunger = Math.max(0, a.hunger - 50.0);

      if (bestPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(bestPrey.x, bestPrey.y);
        if (onPredationSuccess) onPredationSuccess(bestPrey, a);
      }
    }
    return { targetX, targetY };
  }

  // 3. Estado Diurno: Tocaia e Camuflagem Estacionária (pouco movimento)
  if (!isNight) {
    a.isLurking = true;
    a.wanderAngle += (Math.random() - 0.5) * 0.1 * dt;
    const candX = a.x + Math.cos(a.wanderAngle) * 0.20;
    const candY = a.y + Math.sin(a.wanderAngle) * 0.20;
    if (isNavigableWater(candX, candY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      return { targetX: candX, targetY: candY };
    }
    return { targetX: a.x, targetY: a.y };
  }

  // 4. Estado Noturno: Patrulha Territorial Ativa no Meandro/Remanso
  a.isLurking = false;
  const curMargin = getWaterDepthOrMarginFactor(a.x, a.y, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, 4);
  if (curMargin > 0.25) {
    const wCent = getNearestWaterCoords(a.x, a.y);
    const steerAngle = Math.atan2(wCent.y - a.y, wCent.x - a.x);
    a.wanderAngle = steerAngle + (Math.random() - 0.5) * 0.4;
  }

  for (let attempt = 0; attempt < 8; attempt++) {
    const testAngle = a.wanderAngle + (attempt === 0 ? 0 : (attempt % 2 === 1 ? attempt * 0.45 : -attempt * 0.45));
    const nextX = a.x + Math.cos(testAngle) * 2.0;
    const nextY = a.y + Math.sin(testAngle) * 2.0;

    if (isNavigableWater(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER)) {
      const nextMargin = getWaterDepthOrMarginFactor(nextX, nextY, matId, surfaceWater, getIdx, gridW, gridH, MAT_WATER, 3);
      if (curMargin > 0.25 && nextMargin > curMargin && attempt < 6) {
        continue;
      }
      a.wanderAngle = testAngle + (Math.random() - 0.5) * 0.3 * dt;
      return { targetX: nextX, targetY: nextY };
    }
  }

  // Se bloqueada nas margens do remanso, volta para o centro da massa d'água
  const wCent = getNearestWaterCoords(a.x, a.y);
  a.wanderAngle = Math.atan2(wCent.y - a.y, wCent.x - a.x);
  return { targetX: a.x + Math.cos(a.wanderAngle) * 1.5, targetY: a.y + Math.sin(a.wanderAngle) * 1.5 };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.AquaticSpecies = {
    createInitialAquatic,
    updateTambaquiBehavior,
    updateTrairaBehavior,
    updatePiranhaBehavior: updateTrairaBehavior,
    isNavigableWater,
    getNearestWaterCoords,
    getWaterDepthOrMarginFactor
  };
  window.isNavigableWater = isNavigableWater;
  window.getNearestWaterCoords = getNearestWaterCoords;
  window.getWaterDepthOrMarginFactor = getWaterDepthOrMarginFactor;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createInitialAquatic,
    updateTambaquiBehavior,
    updateTrairaBehavior,
    updatePiranhaBehavior: updateTrairaBehavior,
    isNavigableWater,
    getNearestWaterCoords,
    getWaterDepthOrMarginFactor
  };
}
