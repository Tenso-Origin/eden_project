// =========================================================================
// MÓDULO DE AVES ADICIONAIS: TUCANO-TOCO E CARCARÁ (COM REPRODUÇÃO REAL)
// =========================================================================

/**
 * Criação da população de aves adicionais (Tucanos e Carcarás)
 */
function createInitialBirds(lakeCenterX = 512.0, lakeCenterY = 512.0, CHUNK_SIZE = 1024) {
  const birdsList = [];
  const TOUCAN_COUNT = 16;
  const CARCARA_COUNT = 10;

  // 1. Tucanos (Ramphastos toco) - Frugívoros pacíficos das copas
  for (let i = 0; i < TOUCAN_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const dist = 320.0 + Math.random() * 160.0;
    const x = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterX + Math.cos(angle) * dist));
    const y = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterY + Math.sin(angle) * dist));
    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
    const gestationDays = 18.0;
    const gestationRem = isPregnantInit ? (2.0 + Math.random() * (gestationDays - 2.0)) : 0.0;

    birdsList.push({
      id: 6000 + i,
      species: 'toucan',
      diet: 'omnivore',
      name: 'Tucano-toco',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      hunger: 10.0 + Math.random() * 20.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 4.2,
      attackPower: 12.0,
      defensePower: 10.0,
      ageInDays: 400.0 + Math.random() * 600.0,
      maxLifespan: 7300.0, // ~20 anos
      perchTimer: 2.0 + Math.random() * 5.0,
      wanderAngle: Math.random() * Math.PI * 2,

      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (2 + Math.floor(Math.random() * 3)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 50.0) : (10.0 + Math.random() * 30.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 40.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 5.0) : 0.0
    });
  }

  // 2. Carcarás (Caracara plancus) - Predadores e necrófagos oportunistas
  for (let i = 0; i < CARCARA_COUNT; i++) {
    const angle = (i / CARCARA_COUNT) * Math.PI * 2;
    const dist = 120.0 + Math.random() * 140.0;
    const x = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterX + Math.cos(angle) * dist));
    const y = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterY + Math.sin(angle) * dist));
    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnantInit = (sex === 'female' && Math.random() < 0.20);
    const gestationDays = 30.0;
    const gestationRem = isPregnantInit ? (2.0 + Math.random() * (gestationDays - 2.0)) : 0.0;

    birdsList.push({
      id: 7000 + i,
      species: 'carcara',
      diet: 'carnivore',
      name: 'Carcará',
      sex: sex,
      x: x,
      y: y,
      hp: 110,
      hunger: 12.0 + Math.random() * 20.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 4.8,
      attackPower: 35.0,
      defensePower: 16.0,
      ageInDays: 500.0 + Math.random() * 700.0,
      maxLifespan: 5840.0, // ~16 anos
      soarTimer: 5.0 + Math.random() * 10.0,
      wanderAngle: Math.random() * Math.PI * 2,

      // Ciclo Reprodutivo
      isPregnant: isPregnantInit,
      daysPregnant: isPregnantInit ? (gestationDays - gestationRem) : 0.0,
      gestationRemaining: gestationRem,
      litterSize: isPregnantInit ? (2 + Math.floor(Math.random() * 2)) : 0,
      matingCooldown: isPregnantInit ? (gestationRem + 60.0) : (15.0 + Math.random() * 40.0),
      estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * 45.0),
      estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.20) ? (Math.random() * 6.0) : 0.0
    });
  }

  return birdsList;
}

/**
 * Atualização comportamental do Tucano-toco (Frugivoria em copas, voo gracioso e cortejo)
 */
function updateToucanBehavior(a, dt, ctx) {
  const { animals, biomass, grains, getIdx, CHUNK_SIZE } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Poleiro nas copas das árvores
  if (a.perchTimer > 0) {
    a.perchTimer -= dt;
    // Alimentação de frutos e sementes nas copas se com fome
    if (a.hunger > 15.0) {
      const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
      if (grains && grains[curIdx] > 1.0) {
        const bite = Math.min(grains[curIdx], 4.0 * dt);
        grains[curIdx] -= bite;
        a.hunger = Math.max(0, a.hunger - bite * 4.0);
      } else if (biomass && biomass[curIdx] > 10.0) {
        const biteBio = Math.min(biomass[curIdx], 3.0 * dt);
        biomass[curIdx] -= biteBio;
        a.hunger = Math.max(0, a.hunger - biteBio * 2.5);
      }
    }
    return { targetX: a.x, targetY: a.y };
  }

  // 2. Cortejo e Pareamento Arbóreo
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'toucan').length < 40) {
    let closestMate = null;
    let mateDist = 60.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'toucan') continue;
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
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 18.0;
          female.litterSize = 2 + Math.floor(Math.random() * 3);
          female.matingCooldown = 68.0;
          male.matingCooldown = 25.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Voo livre entre árvores frutíferas
  a.wanderAngle += (Math.random() - 0.5) * 0.4 * dt;
  targetX = Math.max(30, Math.min(CHUNK_SIZE - 30, a.x + Math.cos(a.wanderAngle) * (a.speed * 2.0)));
  targetY = Math.max(30, Math.min(CHUNK_SIZE - 30, a.y + Math.sin(a.wanderAngle) * (a.speed * 2.0)));

  // Chance de pousar em galho frondoso
  if (Math.random() < 0.03) {
    a.perchTimer = 5.0 + Math.random() * 8.0;
  }

  return { targetX, targetY };
}

/**
 * Atualização comportamental do Carcará (Voo planado, caça de pequenos vertebrados/insetos e cortejo)
 */
function updateCarcaraBehavior(a, dt, ctx) {
  const { animals, CHUNK_SIZE, applyDeathDecomposition, onPredationSuccess } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Cortejo Aéreo e Acasalamento
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'carcara').length < 25) {
    let closestMate = null;
    let mateDist = 80.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== 'carcara') continue;
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
      if (mateDist < 3.5) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 30.0;
          female.litterSize = 2 + Math.floor(Math.random() * 2);
          female.matingCooldown = 90.0;
          male.matingCooldown = 35.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 2. Caça Oportunista (Ratos, Insetos grandes, Pequenos vertebrados)
  let bestPrey = null;
  let bestDist = 38.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0) continue;
    if (prey.species === 'rat' || prey.species === 'grasshopper' || prey.species === 'roach' || prey.species === 'beetle') {
      const d = Math.hypot(prey.x - a.x, prey.y - a.y);
      if (d < bestDist) {
        bestDist = d;
        bestPrey = prey;
      }
    }
  }

  if (bestPrey && a.hunger > 18.0) {
    const dirX = bestPrey.x - a.x;
    const dirY = bestPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;
    targetX = bestPrey.x;
    targetY = bestPrey.y;

    if (dist <= 2.2) {
      const damage = a.attackPower * (0.8 + Math.random() * 0.4);
      bestPrey.hp -= damage;
      a.hunger = Math.max(0, a.hunger - 35.0);

      if (bestPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(bestPrey.x, bestPrey.y);
        if (onPredationSuccess) onPredationSuccess(bestPrey, a);
      }
    } else {
      targetX = a.x + (dirX / dist) * a.speed * 1.8;
      targetY = a.y + (dirY / dist) * a.speed * 1.8;
    }
    return { targetX, targetY };
  }

  // 3. Voo circular planado de vigilância
  a.wanderAngle += (Math.random() - 0.5) * 0.3 * dt;
  targetX = Math.max(30, Math.min(CHUNK_SIZE - 30, a.x + Math.cos(a.wanderAngle) * (a.speed * 2.2)));
  targetY = Math.max(30, Math.min(CHUNK_SIZE - 30, a.y + Math.sin(a.wanderAngle) * (a.speed * 2.2)));

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.BirdSpecies = {
    createInitialBirds,
    updateToucanBehavior,
    updateCarcaraBehavior
  };
}
