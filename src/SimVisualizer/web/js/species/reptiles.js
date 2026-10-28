// =========================================================================
// MÓDULO DE RÉPTEIS: JABUTI-TINGA (HERBÍVORO) E JACARÉ-AÇU (COM REPRODUÇÃO REAL)
// =========================================================================

/**
 * Criação da população de répteis
 */
function createInitialReptiles(lakeCenterX = 512.0, lakeCenterY = 512.0, lakeRadius = 100.0) {
  const reptileList = [];
  const TORTOISE_COUNT = 18;
  const CAIMAN_COUNT = 8;

  // 1. Jabuti-tinga (Chelonoidis denticulatus) - Terrestre lento com carapaça
  for (let i = 0; i < TORTOISE_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const distFromCenter = lakeRadius + 60.0 + Math.random() * 260.0;
    const x = Math.max(30, Math.min(1024 - 30, lakeCenterX + Math.cos(angle) * distFromCenter));
    const y = Math.max(30, Math.min(1024 - 30, lakeCenterY + Math.sin(angle) * distFromCenter));
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

  // 2. Jacaré-açu (Melanosuchus niger) - Predador semi-aquático de topo
  for (let i = 0; i < CAIMAN_COUNT; i++) {
    const angle = (i / CAIMAN_COUNT) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
    const distFromCenter = lakeRadius * (0.85 + Math.random() * 0.25);
    const x = lakeCenterX + Math.cos(angle) * distFromCenter;
    const y = lakeCenterY + Math.sin(angle) * distFromCenter;
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

      wanderAngle: angle
    });
  }

  return reptileList;
}

/**
 * Atualização comportamental do Jabuti-tinga (Forrageamento lento, retração na carapaça e cortejo)
 */
function updateTortoiseBehavior(a, dt, ctx) {
  const { animals, biomass, getIdx, matId, MAT_WATER, temp, CHUNK_SIZE } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Defesa Passiva: Retração na Carapaça se predador perigoso próximo (< 8.0m)
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

  // 2. Cortejo e Acasalamento de Jabutis
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'tortoise').length < 45) {
    let closestMate = null;
    let mateDist = 40.0;
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
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 40.0;
          female.litterSize = 3 + Math.floor(Math.random() * 4);
          female.matingCooldown = 120.0;
          male.matingCooldown = 40.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Forrageamento de Vegetação Rasteira e Fungos
  if (a.hunger > 15.0) {
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (biomass && biomass[curIdx] > 5.0) {
      const bite = Math.min(biomass[curIdx], 3.0 * dt);
      biomass[curIdx] -= bite;
      a.hunger = Math.max(0, a.hunger - bite * 3.5);
    }
  }

  // 4. Locomoção lenta e segura em terra firme
  a.wanderAngle += (Math.random() - 0.5) * 0.25 * dt;
  targetX = Math.max(15, Math.min(CHUNK_SIZE - 15, a.x + Math.cos(a.wanderAngle) * (a.speed * 1.5)));
  targetY = Math.max(15, Math.min(CHUNK_SIZE - 15, a.y + Math.sin(a.wanderAngle) * (a.speed * 1.5)));

  return { targetX, targetY };
}

/**
 * Atualização comportamental do Jacaré-açu (Basking, emboscada na margem e acasalamento)
 */
function updateCaimanBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, getIdx, matId, MAT_WATER, applyDeathDecomposition, onPredationSuccess } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  if (a.lungeCooldown > 0) a.lungeCooldown -= dt;

  // 1. Termorregulação (Banho de Sol / Basking na Praia se bem alimentado)
  if (a.hunger < 25.0 && a.baskingTimer <= 0 && Math.random() < 0.005) {
    a.isBasking = true;
    a.baskingTimer = 15.0 + Math.random() * 20.0;
  }

  if (a.isBasking) {
    a.baskingTimer -= dt;
    if (a.baskingTimer <= 0) a.isBasking = false;
    return { targetX: a.x, targetY: a.y };
  }

  // 2. Cortejo Reprodutivo de Jacarés na Margem
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 45.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate && animals.filter(x => x.species === 'caiman').length < 18) {
    let closestMate = null;
    let mateDist = 50.0;
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
        } else {
          female.isPregnant = true;
          female.daysPregnant = 0.0;
          female.gestationRemaining = 45.0;
          female.litterSize = 3 + Math.floor(Math.random() * 3);
          female.matingCooldown = 150.0;
          male.matingCooldown = 50.0;
        }
      }
      return { targetX, targetY };
    }
  }

  // 3. Detecção de presas próximas (Tambaqui, Traíra, Rato, Gato)
  let targetPrey = null;
  let minDist = 25.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0 || prey.species === 'caiman') continue;

    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d < minDist) {
      minDist = d;
      targetPrey = prey;
    }
  }

  // 4. Execução do Bote de Emboscada (Lunge)
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

  // 5. Patrulha anfíbia suave entre o lago e a praia
  a.wanderAngle += (Math.random() - 0.5) * 0.4 * dt;
  const targetDist = lakeRadius * (0.92 + Math.sin(a.wanderAngle) * 0.12);
  targetX = lakeCenterX + Math.cos(a.wanderAngle) * targetDist;
  targetY = lakeCenterY + Math.sin(a.wanderAngle) * targetDist;

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
