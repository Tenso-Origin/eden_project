// =========================================================================
// MÓDULO DA ESPÉCIE: HARPIA AMAZÔNICA (Harpia harpyja / Gavião-Real)
// =========================================================================

/**
 * Inicialização do casal monogâmico de harpias com ninho na samaúma
 */
function createInitialHarpies() {
  return [
    {
      id: 9001,
      species: 'harpy',
      sex: 'male',
      name: 'Harpia Macho',
      x: 210.0,
      y: 200.0,
      z: 35.0, // Altitude em metros
      hp: 100,
      attackPower: 80.0,
      defensePower: 28.0,
      hunger: 15.0,
      thirst: 5.0,
      fatigue: 10.0,
      isSleeping: false,
      foodMemoryX: 256.0,
      foodMemoryY: 256.0,
      hasFoodMemory: false,
      state: 'patrol',
      target: null,
      diveSpeed: 0.0,
      nestX: 435.0,
      nestY: 85.0,
      flightAngle: 0.5,
      circleRadius: 140.0, // Raio expandido sobre a várzea ampla
      migrated: false
    },
    {
      id: 9002,
      species: 'harpy',
      sex: 'female',
      name: 'Harpia Fêmea',
      x: 290.0,
      y: 270.0,
      z: 40.0,
      hp: 100,
      attackPower: 95.0, // Fêmea 30% mais pesada e forte
      defensePower: 34.0,
      hunger: 10.0,
      thirst: 5.0,
      fatigue: 10.0,
      isSleeping: false,
      foodMemoryX: 256.0,
      foodMemoryY: 256.0,
      hasFoodMemory: false,
      state: 'patrol',
      target: null,
      diveSpeed: 0.0,
      nestX: 435.0,
      nestY: 85.0,
      flightAngle: 3.5,
      circleRadius: 165.0,
      migrated: false
    }
  ];
}

/**
 * Passo de Simulação e Dinâmica das Harpias Amazônicas
 */
function stepHarpies(dt, ctx) {
  const {
    harpies,
    animals,
    currentScenario,
    timeOfDay,
    simDeltaHours,
    CHUNK_SIZE,
    matId,
    MAT_WATER,
    surfaceWater,
    biomass,
    isProtectedInBurrowOrRefuge,
    applyDeathDecomposition,
    onHarpyPredation
  } = ctx;

  if (currentScenario !== 'amazon' || !harpies || harpies.length === 0) return;

  // 1. Cálculo contínuo da Homeostase Ecológica (Lotka-Volterra: razão equilibrada 30:1)
  const aliveRats = animals.filter(a => a.species === 'rat' && a.hp > 0).length;
  const aliveCats = animals.filter(a => a.species === 'cat' && a.hp > 0).length;
  const currentRatio = (aliveCats > 0) ? (aliveRats / aliveCats) : 0;
  let currentHomeostasis = 100 - Math.min(100, Math.abs(currentRatio - 30.0) * 2.8);
  if (aliveRats === 0 && aliveCats === 0) currentHomeostasis = 0;

  // Regra de Histerese de Dispersão e Retorno por Homeostase Ecológica:
  // - 1ª Harpia (Macho): migra quando Homeostase <= 85%, retorna quando >= 90%
  // - 2ª Harpia (Fêmea): migra quando Homeostase <= 75%, retorna quando >= 80%
  if (harpies.length >= 1) {
    const h1 = harpies[0];
    if (!h1.migrated && currentHomeostasis <= 85.0) {
      h1.migrated = true;
      h1.target = null;
      h1.state = 'retreat';
    } else if (h1.migrated && currentHomeostasis >= 90.0) {
      h1.migrated = false;
      h1.x = h1.nestX;
      h1.y = h1.nestY;
      h1.z = 38.0;
      h1.state = 'patrol';
    }
  }

  if (harpies.length >= 2) {
    const h2 = harpies[1];
    if (!h2.migrated && currentHomeostasis <= 75.0) {
      h2.migrated = true;
      h2.target = null;
      h2.state = 'retreat';
    } else if (h2.migrated && currentHomeostasis >= 80.0) {
      h2.migrated = false;
      h2.x = h2.nestX;
      h2.y = h2.nestY;
      h2.z = 38.0;
      h2.state = 'patrol';
    }
  }

  const sunH = Math.sin(((timeOfDay - 6.0) / 12.0) * Math.PI);
  const isDayTime = (sunH > 0); // Diurno das 06:00 às 18:00

  for (let hi = 0; hi < harpies.length; hi++) {
    const h = harpies[hi];
    if (h.hp <= 0 || h.migrated) continue;

    // Metabolismo basal e fisiologia
    h.hunger = Math.min(100, h.hunger + 0.15 * simDeltaHours);
    if (h.thirst === undefined) h.thirst = 5.0;
    if (h.fatigue === undefined) h.fatigue = 10.0;
    h.thirst = Math.min(100, h.thirst + 0.035 * dt);

    // 1. Descanso e Regeneração no Ninho da Copa da Samaúma
    if (h.state === 'nest_resting') {
      h.z = 35.0;
      h.x = h.nestX;
      h.y = h.nestY;
      h.hp = Math.min(100, h.hp + 5.0 * dt);
      h.fatigue = 0.0;
      h.isSleeping = true;
      if (isDayTime && h.hp >= 95.0 && h.hunger > 25.0) {
        h.state = 'patrol';
        h.isSleeping = false;
      }
      continue;
    }

    // Comportamento Diurno: Ao anoitecer, regressa para a copa da árvore
    if (!isDayTime && h.state !== 'retreat') {
      h.state = 'retreat';
      h.target = null;
    }

    // Sobrevivência: se HP < 30, voa para o ninho
    if (h.hp < 30.0) {
      h.state = 'retreat';
      h.target = null;
    }

    // 2. Fuga / Retorno ao Ninho
    if (h.state === 'retreat') {
      const toNestX = h.nestX - h.x;
      const toNestY = h.nestY - h.y;
      const distNest = Math.hypot(toNestX, toNestY);
      h.z = Math.min(45.0, h.z + 6.0 * dt);
      if (distNest > 2.0) {
        const flySpeed = 8.0;
        h.x += (toNestX / distNest) * flySpeed * dt;
        h.y += (toNestY / distNest) * flySpeed * dt;
      } else {
        h.x = h.nestX;
        h.y = h.nestY;
        h.state = 'nest_resting';
        h.isSleeping = true;
      }
      continue;
    }

    // 3. Voo de Patrulha em Círculos
    if (h.state === 'patrol') {
      h.isSleeping = false;

      // Sede: desce na borda do lago para beber água
      if (h.thirst > 40.0) {
        const dLakeCenter = Math.hypot(h.x - 256.0, h.y - 256.0);
        if (dLakeCenter > 52.0) {
          const lakeDirX = (256.0 - h.x) / dLakeCenter;
          const lakeDirY = (256.0 - h.y) / dLakeCenter;
          h.x += lakeDirX * 6.5 * dt;
          h.y += lakeDirY * 6.5 * dt;
        } else {
          h.z = Math.max(1.0, h.z - 12.0 * dt);
          if (h.z <= 2.5) {
            h.thirst = Math.max(0, h.thirst - 50.0 * dt);
          }
        }
      } else {
        h.z = 38.0 + Math.sin(h.flightAngle * 2.0) * 4.0;
        h.flightAngle += 0.24 * dt;
        const cx = 256.0, cy = 256.0;
        const targetPatrolX = cx + Math.cos(h.flightAngle) * h.circleRadius;
        const targetPatrolY = cy + Math.sin(h.flightAngle) * h.circleRadius;

        const pDirX = targetPatrolX - h.x;
        const pDirY = targetPatrolY - h.y;
        const pDist = Math.hypot(pDirX, pDirY);
        if (pDist > 0.1) {
          const speed = 5.5;
          h.x += (pDirX / pDist) * speed * dt;
          h.y += (pDirY / pDist) * speed * dt;
        }
      }

      // Busca por presas se faminta (hunger > 20)
      if (h.hunger > 20.0 && h.thirst <= 45.0) {
        let candidatePrey = null;
        let bestScore = -999;

        for (let ai = 0; ai < animals.length; ai++) {
          const prey = animals[ai];
          if (prey.hp <= 0 || isProtectedInBurrowOrRefuge(prey) || prey.isDiving) continue;

          const pX = Math.floor(prey.x), pY = Math.floor(prey.y);
          if (pX < 0 || pX >= CHUNK_SIZE || pY < 0 || pY >= CHUNK_SIZE) continue;
          const pIdx = ctx.getIdx(pX, pY);

          // REGRA ESTRITA: Harpia SÓ ATACA NA ZONA DE GRAMÍNEAS (CAMPO ABERTO DE VÁRZEA)
          const isGrasslandZone = (matId[pIdx] !== MAT_WATER && surfaceWater[pIdx] < 0.10 && biomass[pIdx] >= 15.0 && biomass[pIdx] <= 55.0);
          if (!isGrasslandZone) continue;

          // Visão telescópica ampliada: até 150m
          const distToPrey = Math.hypot(prey.x - h.x, prey.y - h.y);
          if (distToPrey > 150.0) continue;

          if (prey.species === 'cat' && h.hp < 50.0) continue;

          let preyVal = (prey.species === 'rat') ? 80.0 : 45.0;
          const score = preyVal - distToPrey * 0.8;
          if (score > bestScore) {
            bestScore = score;
            candidatePrey = prey;
          }
        }

        if (candidatePrey) {
          h.state = 'dive';
          h.target = candidatePrey;
        }
      }
    }

    // 4. Mergulho Rasante de Ataque (Dive Attack)
    else if (h.state === 'dive') {
      const prey = h.target;
      if (!prey || prey.hp <= 0 || isProtectedInBurrowOrRefuge(prey) || prey.isDiving) {
        h.state = 'patrol';
        h.target = null;
        h.z = 38.0;
        continue;
      }

      const pX = Math.floor(prey.x), pY = Math.floor(prey.y);
      const pIdx = ctx.getIdx(Math.max(0, Math.min(CHUNK_SIZE - 1, pX)), Math.max(0, Math.min(CHUNK_SIZE - 1, pY)));

      // Se a presa alcançar refúgio, água, toca ou vegetação densa: aborta rasante!
      if (biomass[pIdx] > 55.0 || matId[pIdx] === MAT_WATER || surfaceWater[pIdx] > 0.15 || isProtectedInBurrowOrRefuge(prey) || prey.isDiving) {
        h.state = 'patrol';
        h.target = null;
        h.z = 38.0;
        continue;
      }

      const dX = prey.x - h.x;
      const dY = prey.y - h.y;
      const distHoriz = Math.hypot(dX, dY);

      const diveSpeed = 12.8;
      if (distHoriz > 0.2) {
        h.x += (dX / distHoriz) * diveSpeed * dt;
        h.y += (dY / distHoriz) * diveSpeed * dt;
      }
      h.z = Math.max(0.5, h.z - 18.0 * dt);

      // Bote no alvo
      if (distHoriz < 1.8 && h.z < 2.5) {
        if (isProtectedInBurrowOrRefuge(prey) || prey.isDiving) {
          h.state = 'patrol';
          h.target = null;
          h.z = 38.0;
          continue;
        }

        if (prey.species === 'rat') {
          // Rato: 90% taxa de captura
          if (Math.random() < 0.90) {
            prey.hp = 0;
            if (onHarpyPredation) onHarpyPredation(prey, h);
            h.hunger = Math.max(0, h.hunger - 45.0);
            h.foodMemoryX = prey.x;
            h.foodMemoryY = prey.y;
            h.hasFoodMemory = true;
          }
          h.state = 'patrol';
          h.target = null;
          h.z = 38.0;
        } else if (prey.species === 'cat') {
          // Defesa e contra-ataque do gato acuado contra a ave de rapina
          const ferocity = (prey.catGenome && prey.catGenome.combatFerocity) || 1.0;
          const catStrikeDmg = Math.max(15.0, Math.min(42.0, (prey.attackPower * ferocity * 0.8) - ((h.defensePower || 28.0) * 0.3) + (Math.random() * 8.0 - 4.0)));
          h.hp = Math.max(0, h.hp - catStrikeDmg);

          const harpyStrikeDmg = Math.max(22.0, ((h.attackPower || 80.0) * 0.8) - (prey.defensePower * 0.5) + (Math.random() * 8.0 - 4.0));
          prey.hp = Math.max(0, prey.hp - harpyStrikeDmg);

          if (h.hp < 45.0) {
            // Harpia recua ferida
            h.state = 'retreat';
            h.target = null;
            prey.currentSprintBoost = 1.6;
            prey.wanderAngle = Math.atan2(prey.y - 256.0, prey.x - 256.0);
          } else if (prey.hp <= 0) {
            prey.hp = 0;
            if (onHarpyPredation) onHarpyPredation(prey, h);
            h.hunger = Math.max(0, h.hunger - 85.0);
            h.state = 'patrol';
            h.target = null;
            h.z = 38.0;
          } else {
            h.state = 'patrol';
            h.target = null;
            h.z = 38.0;
            prey.currentSprintBoost = 1.4;
          }
        }
      }
    }
  }
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.HarpySpecies = {
    createInitialHarpies,
    stepHarpies
  };
  window.createInitialHarpies = createInitialHarpies;
  window.stepHarpies = stepHarpies;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createInitialHarpies,
    stepHarpies
  };
}
