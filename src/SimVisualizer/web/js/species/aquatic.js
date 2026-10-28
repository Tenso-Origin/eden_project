// =========================================================================
// MÓDULO DE ESPÉCIES AQUÁTICAS: TAMBAQUI E PIRANHA-VERMELHA (ÁGUA DOCE)
// =========================================================================

/**
 * Criação da fauna aquática inicial do lago
 */
function createInitialAquatic(lakeCenterX = 512.0, lakeCenterY = 512.0, lakeRadius = 100.0) {
  const aquaticList = [];
  const TAMBAQUI_COUNT = 45;
  const PIRANHA_COUNT = 25;

  // 1. Tambaquis (Colossoma macropomum) - Herbívoros/Frugívoros pacíficos
  for (let i = 0; i < TAMBAQUI_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const r = Math.random() * (lakeRadius * 0.78);
    const x = lakeCenterX + Math.cos(angle) * r;
    const y = lakeCenterY + Math.sin(angle) * r;
    const sex = (i % 2 === 0) ? 'female' : 'male';

    aquaticList.push({
      id: 2000 + i,
      species: 'tambaqui',
      diet: 'herbivore',
      name: 'Tambaqui da Amazônia',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 10.0 + Math.random() * 20.0,
      speed: 2.1,
      attackPower: 5.0,
      defensePower: 8.0,
      ageInDays: 300.0 + Math.random() * 300.0,
      maxLifespan: 9125.0, // ~25 anos
      matingCooldown: 30.0 + Math.random() * 40.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      fearTimer: 0.0,
      wanderAngle: angle + Math.PI / 2
    });
  }

  // 2. Piranhas-vermelhas (Pygocentrus nattereri) - Carnívoros agressivos em cardume
  for (let i = 0; i < PIRANHA_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const r = Math.random() * (lakeRadius * 0.85);
    const x = lakeCenterX + Math.cos(angle) * r;
    const y = lakeCenterY + Math.sin(angle) * r;
    const sex = (i % 2 === 0) ? 'female' : 'male';

    aquaticList.push({
      id: 3000 + i,
      species: 'piranha',
      diet: 'carnivore',
      name: 'Piranha-vermelha',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 15.0 + Math.random() * 25.0,
      speed: 3.1,
      attackPower: 34.0,
      defensePower: 6.0,
      ageInDays: 200.0 + Math.random() * 200.0,
      maxLifespan: 3650.0, // ~10 anos
      matingCooldown: 25.0 + Math.random() * 30.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      frenzyTimer: 0.0,
      wanderAngle: angle
    });
  }

  return aquaticList;
}

/**
 * Atualização comportamental do Tambaqui (Forrageamento aquático, fuga de piranhas e jacarés)
 */
function updateTambaquiBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, matId, MAT_WATER, getIdx, grains, biomass, weather } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Manutenção de confinamento no lago (garantir que não nade em terra firme)
  const dToCenter = Math.hypot(a.x - lakeCenterX, a.y - lakeCenterY);
  if (dToCenter > lakeRadius * 0.88) {
    const toCX = (lakeCenterX - a.x) / dToCenter;
    const toCY = (lakeCenterY - a.y) / dToCenter;
    targetX = a.x + toCX * 8.0;
    targetY = a.y + toCY * 8.0;
    return { targetX, targetY };
  }

  // 2. Fuga de ameaças aquáticas (Piranhas em frenesi e Jacarés)
  if (a.fearTimer > 0) a.fearTimer -= dt;
  let closestPred = null;
  let minDist = 22.0;

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.hp <= 0) continue;
    if (other.species === 'piranha' || other.species === 'caiman') {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      if (d < minDist) {
        minDist = d;
        closestPred = other;
      }
    }
  }

  if (closestPred) {
    a.fearTimer = 3.5;
    const escapeX = a.x - closestPred.x;
    const escapeY = a.y - closestPred.y;
    const escDist = Math.hypot(escapeX, escapeY) || 1.0;
    targetX = a.x + (escapeX / escDist) * 12.0;
    targetY = a.y + (escapeY / escDist) * 12.0;
    return { targetX, targetY };
  }

  // 3. Forrageamento: Busca grãos ou vegetação de borda do lago se com fome
  if (a.hunger > 25.0) {
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (grains && grains[curIdx] > 1.0) {
      const bite = Math.min(grains[curIdx], 5.0 * dt);
      grains[curIdx] -= bite;
      a.hunger = Math.max(0, a.hunger - bite * 4.0);
    } else if (biomass && biomass[curIdx] > 5.0) {
      const biteBio = Math.min(biomass[curIdx], 4.0 * dt);
      biomass[curIdx] -= biteBio;
      a.hunger = Math.max(0, a.hunger - biteBio * 2.5);
    }
  }

  // 4. Natação suave circular em cardume
  a.wanderAngle += (Math.random() - 0.5) * 0.45 * dt;
  targetX = a.x + Math.cos(a.wanderAngle) * 4.0;
  targetY = a.y + Math.sin(a.wanderAngle) * 4.0;

  return { targetX, targetY };
}

/**
 * Atualização comportamental da Piranha-vermelha (Cardume, Emboscada e Frenesi)
 */
function updatePiranhaBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, getIdx, matId, MAT_WATER, applyDeathDecomposition, onPredationSuccess } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Confinamento no lago
  const dToCenter = Math.hypot(a.x - lakeCenterX, a.y - lakeCenterY);
  if (dToCenter > lakeRadius * 0.90) {
    const toCX = (lakeCenterX - a.x) / dToCenter;
    const toCY = (lakeCenterY - a.y) / dToCenter;
    targetX = a.x + toCX * 10.0;
    targetY = a.y + toCY * 10.0;
    return { targetX, targetY };
  }

  if (a.frenzyTimer > 0) a.frenzyTimer = Math.max(0, a.frenzyTimer - dt);

  // 2. Detecção de presas aquáticas e animais terrestres nadando no lago
  let bestPrey = null;
  let bestScore = -999;
  const attackRadius = (a.frenzyTimer > 0) ? 35.0 : 20.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0) continue;

    // Presas válidas: Tambaquis, Ratos na água (nadando/mergulhando), Gatos na água, filhotes
    const isAquaticPrey = (prey.species === 'tambaqui');
    const isTerrestrialInWater = (prey.species === 'rat' && (prey.isDiving || Math.hypot(prey.x - lakeCenterX, prey.y - lakeCenterY) < lakeRadius * 0.95))
                              || (prey.species === 'cat' && Math.hypot(prey.x - lakeCenterX, prey.y - lakeCenterY) < lakeRadius * 0.85);

    if (!isAquaticPrey && !isTerrestrialInWater) continue;

    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d <= attackRadius) {
      let score = (100.0 - d) + (prey.hp < 50 ? 50 : 0);
      if (prey.species === 'rat') score += 40; // Rato na água é presa extremamente fácil
      if (score > bestScore) {
        bestScore = score;
        bestPrey = prey;
      }
    }
  }

  // 3. Ataque em cardume e mordidas
  if (bestPrey) {
    const dirX = bestPrey.x - a.x;
    const dirY = bestPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    targetX = bestPrey.x;
    targetY = bestPrey.y;

    if (dist <= 1.8) {
      // Dano de mordida
      const damage = a.attackPower * (0.8 + Math.random() * 0.5) * dt;
      bestPrey.hp -= damage;
      a.frenzyTimer = 5.0; // Espalha frenesi
      a.hunger = Math.max(0, a.hunger - 15.0 * dt);

      // Alerta outras piranhas próximas para entrar no frenesi
      for (let k = 0; k < animals.length; k++) {
        const oth = animals[k];
        if (oth.species === 'piranha' && Math.hypot(oth.x - a.x, oth.y - a.y) < 25.0) {
          oth.frenzyTimer = 5.0;
        }
      }

      if (bestPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(bestPrey.x, bestPrey.y);
        if (onPredationSuccess) onPredationSuccess(bestPrey, a);
      }
    }
    return { targetX, targetY };
  }

  // 4. Patrulha de cardume
  a.wanderAngle += (Math.random() - 0.5) * 0.8 * dt;
  const patrolSpeed = (a.frenzyTimer > 0) ? 5.5 : 2.5;
  targetX = a.x + Math.cos(a.wanderAngle) * patrolSpeed;
  targetY = a.y + Math.sin(a.wanderAngle) * patrolSpeed;

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.AquaticSpecies = {
    createInitialAquatic,
    updateTambaquiBehavior,
    updatePiranhaBehavior
  };
}