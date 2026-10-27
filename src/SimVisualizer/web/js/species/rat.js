// =========================================================================
// MÓDULO DA ESPÉCIE: RATO (Rattus norvegicus / Herbívoro de Várzea)
// =========================================================================

/**
 * Criação do genoma basal do rato com traços adaptativos e epigenéticos
 */
function createDefaultRatGenome() {
  return {
    alertRadius: 12.0 + (Math.random() * 4.0 - 2.0),
    refugeAffinity: 0.45 + (Math.random() * 0.20 - 0.10),
    sprintBurst: 1.35 + (Math.random() * 0.20 - 0.10),
    epigeneticBonus: 0.0,
    memoryRetention: 0.70 + (Math.random() * 0.20 - 0.10),
    generation: 0
  };
}

/**
 * Recombinação genética mendeliana com crossover e mutação para filhotes de ratos
 */
function recombineRatGenome(motherGen, fatherGen) {
  const m = motherGen || createDefaultRatGenome();
  const f = fatherGen || m;
  const baseAlert = (m.alertRadius + f.alertRadius) * 0.5 + ((m.epigeneticBonus || 0) + (f.epigeneticBonus || 0)) * 0.15;
  const baseRefuge = (m.refugeAffinity + f.refugeAffinity) * 0.5;
  const baseSprint = (m.sprintBurst + f.sprintBurst) * 0.5;
  const baseMemory = ((m.memoryRetention || 0.70) + (f.memoryRetention || 0.70)) * 0.5;

  const mutAlert = (Math.random() * 0.10 - 0.05) * baseAlert;
  const mutRefuge = (Math.random() * 0.10 - 0.05) * baseRefuge;
  const mutSprint = (Math.random() * 0.10 - 0.05) * baseSprint;
  const mutMemory = (Math.random() * 0.10 - 0.05) * baseMemory;

  return {
    alertRadius: Math.max(8.0, Math.min(26.0, baseAlert + mutAlert)),
    refugeAffinity: Math.max(0.10, Math.min(1.0, baseRefuge + mutRefuge)),
    sprintBurst: Math.max(1.15, Math.min(2.0, baseSprint + mutSprint)),
    epigeneticBonus: 0.0,
    memoryRetention: Math.max(0.40, Math.min(1.0, baseMemory + mutMemory)),
    generation: Math.max(m.generation || 0, f.generation || 0) + 1
  };
}

/**
 * Ciclo Comportamental Completo do Rato (Herbivoria, Fuga, Acuamento, Forrageamento, Sono, Sede)
 * Retorna { targetX, targetY }
 */
function updateRatBehavior(a, dt, ctx) {
  const {
    animals,
    harpies,
    naturalRefuges,
    ratsInCell,
    grains,
    biomass,
    moisture,
    matId,
    surfaceWater,
    simDeltaHours,
    simDeltaDays,
    curIdx,
    curX,
    curY,
    inWater,
    floodEscapeX,
    floodEscapeY,
    isReadyToMate,
    isInEstrus,
    CHUNK_SIZE
  } = ctx;

  // 1. Inicialização de segurança dos atributos de combate e fisiologia
  if (a.stamina === undefined) {
    a.stamina = 100.0;
    a.maxStamina = 100.0;
    a.isExhausted = false;
    a.attackPower = 10.0;
    a.defensePower = 3.0;
    a.isCornered = false;
  }

  // Regeneração de Stamina e recuperação de exaustão fisiológica
  if (a.isExhausted) {
    a.stamina = Math.min(a.maxStamina, a.stamina + 8.0 * dt);
    if (a.stamina >= 35.0) {
      a.isExhausted = false; // Recuperou o fôlego aeróbico
    }
  } else {
    a.stamina = Math.min(a.maxStamina, a.stamina + 14.0 * dt);
  }

  // 2. Pastagem e Partilha de Alimento:
  // Grãos Amazônicos de Várzea (Oryza glumaepatula): alta prioridade calórica
  if (a.hunger > 5 && grains[curIdx] > 0.5) {
    const grainBite = Math.min(grains[curIdx], 2.8 * simDeltaHours);
    grains[curIdx] = Math.max(0, grains[curIdx] - grainBite);
    a.hunger = Math.max(0, a.hunger - grainBite * 18.0); // Boost imediato de saciedade calórica
    a.foodMemoryX = a.x;
    a.foodMemoryY = a.y;
    a.hasFoodMemory = true;
  } else if (a.hunger > 5 && biomass[curIdx] > 0.5) {
    const nRats = ratsInCell[curIdx] || 1;
    const baseRatePerHour = 100.0 / 72.0; // ~1.3888 biomassa/hora
    const sharedBite = Math.min(biomass[curIdx] / nRats, baseRatePerHour * simDeltaHours);
    biomass[curIdx] = Math.max(0, biomass[curIdx] - sharedBite);
    // Saciedade da biomassa comum reduzida a 10% (0.42) para forçar busca por grãos
    a.hunger = Math.max(0, a.hunger - sharedBite * 0.42);
    a.foodMemoryX = a.x;
    a.foodMemoryY = a.y;
    a.hasFoodMemory = true;
  }

  // 3. Detecção de ameaça de predadores terrestres (gatos) e aéreos (harpias)
  const effectiveAlert = (a.genome ? a.genome.alertRadius + (a.genome.epigeneticBonus || 0) : 12.0);
  let fleeVectorX = 0, fleeVectorY = 0, dangerCount = 0;
  let closestCatDist = 999.0;
  let closestCat = null;

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.species === 'cat' && other.hp > 0) {
      const d = Math.hypot(other.x - a.x, other.y - a.y);
      if (d < effectiveAlert) {
        fleeVectorX += (a.x - other.x) / (d + 0.1);
        fleeVectorY += (a.y - other.y) / (d + 0.1);
        dangerCount++;
        if (d < closestCatDist) {
          closestCatDist = d;
          closestCat = other;
        }
      }
    }
  }

  // Perigo Aéreo: Harpia mergulhando na várzea aberta (e não migrada)
  if (harpies && harpies.length > 0) {
    for (let hi = 0; hi < harpies.length; hi++) {
      const h = harpies[hi];
      if (h.hp > 0 && !h.migrated && h.state === 'dive') {
        const hd = Math.hypot(h.x - a.x, h.y - a.y);
        if (hd < 25.0) {
          fleeVectorX += (a.x - h.x) / (hd + 0.1);
          fleeVectorY += (a.y - h.y) / (hd + 0.1);
          dangerCount += 2;
          if (hd < closestCatDist) closestCatDist = hd;
        }
      }
    }
  }

  let targetX = a.x;
  let targetY = a.y;

  if (dangerCount > 0) {
    // Evasão ativa de predador: busca refúgio seguro (toca própria ou refúgio natural)
    let refugeBiasX = 0, refugeBiasY = 0;
    const refugeAffinity = a.genome ? a.genome.refugeAffinity : 0.45;

    let bestShelterX = null, bestShelterY = null, minShelterDist = 999.0;
    if (a.hasNest) {
      const dNest = Math.hypot(a.nestX - a.x, a.nestY - a.y);
      bestShelterX = a.nestX;
      bestShelterY = a.nestY;
      minShelterDist = dNest;
    }
    if (naturalRefuges && naturalRefuges.length > 0) {
      for (let ri = 0; ri < naturalRefuges.length; ri++) {
        const ref = naturalRefuges[ri];
        const dRef = Math.hypot(ref.x - a.x, ref.y - a.y);
        if (dRef < minShelterDist) {
          minShelterDist = dRef;
          bestShelterX = ref.x;
          bestShelterY = ref.y;
        }
      }
    }

    if (bestShelterX !== null && minShelterDist > 0.6) {
      const toShelterX = bestShelterX - a.x;
      const toShelterY = bestShelterY - a.y;
      refugeBiasX = (toShelterX / minShelterDist) * 4.5;
      refugeBiasY = (toShelterY / minShelterDist) * 4.5;
    }

    // COMPORTAMENTO DE ACUAMENTO EXTREMO ("TUDO OU NADA"):
    // Quando encurralado <= 1.8m e sem refúgio imediato ou exausto, contra-ataca com fúria!
    const isTrapped = (closestCatDist <= 1.8 && (minShelterDist > 7.0 || a.isExhausted) && closestCat !== null);

    if (isTrapped) {
      a.isCornered = true;
      targetX = closestCat.x;
      targetY = closestCat.y;
      a.currentSprintBoost = 1.1;

      // Mordida frenética de autodefesa: dor aguda no focinho do predador e atordoamento
      const ratDmg = Math.max(0.1, (a.attackPower * 0.4 - (closestCat.defensePower || 14.0) * 0.1) * dt * 0.8);
      closestCat.hp = Math.max(0, closestCat.hp - ratDmg);

      // Causa dor súbita, hesitação e quebra de foco no predador, permitindo a fuga do roedor
      closestCat.painStun = 2.2;
      closestCat.chaseAbandonCooldown = 3.5;
      closestCat.stamina = Math.max(0, (closestCat.stamina || 100.0) - 15.0);
    } else {
      a.isCornered = false;
      targetX = a.x + (fleeVectorX * 2.8) + (refugeBiasX * refugeAffinity * 2.2);
      targetY = a.y + (fleeVectorY * 2.8) + (refugeBiasY * refugeAffinity * 2.2);

      // Arrancada anaeróbica (SprintBurst) limitada por Stamina e ácido lático
      if (closestCatDist < 3.8 && a.genome) {
        if (a.isExhausted) {
          a.currentSprintBoost = 0.60;
        } else {
          a.currentSprintBoost = a.genome.sprintBurst || 1.35;
          a.stamina = Math.max(0, a.stamina - 28.0 * dt);
          if (a.stamina <= 0) {
            a.isExhausted = true;
            a.currentSprintBoost = 0.60;
          }
          a.genome.epigeneticBonus = Math.min(4.0, (a.genome.epigeneticBonus || 0) + 0.15 * dt);
        }
      } else {
        a.currentSprintBoost = a.isExhausted ? 0.75 : 1.0;
      }
    }
  } else {
    a.isCornered = false;
    a.currentSprintBoost = a.isExhausted ? 0.75 : 1.0;

    if (inWater && (floodEscapeX !== 0 || floodEscapeY !== 0)) {
      targetX = a.x + floodEscapeX * 3.0;
      targetY = a.y + floodEscapeY * 3.0;
    } else if (a.isPregnant && a.gestationRemaining < 2.5 && a.hasNest) {
      targetX = a.nestX;
      targetY = a.nestY;
    } else {
      let mateTargetFound = false;

      // Busca de parceiro fértil durante o ciclo de estro (feromônios ampliados: 50m)
      if (isReadyToMate && a.hunger < 50 && animals.length < 500) {
        let closestMate = null;
        let closestDist = 50.0;

        for (let j = 0; j < animals.length; j++) {
          const other = animals[j];
          if (other.id === a.id) continue;
          if (other.species === 'rat' && other.hp > 0 && other.sex !== a.sex) {
            const otherInEstrus = (other.sex === 'female' && other.estrusDurationRemaining > 0);
            const isPairReceptive = (a.sex === 'female' && isInEstrus && other.sex === 'male' && other.hunger < 55 && other.matingCooldown <= 0) ||
                                   (a.sex === 'male' && other.sex === 'female' && otherInEstrus && !other.isPregnant && other.hunger < 55 && other.matingCooldown <= 0);

            if (isPairReceptive) {
              const d = Math.hypot(other.x - a.x, other.y - a.y);
              if (d < closestDist) {
                closestDist = d;
                closestMate = other;
              }
            }
          }
        }

        if (closestMate) {
          targetX = closestMate.x;
          targetY = closestMate.y;
          mateTargetFound = true;

          if (closestDist < 1.5) {
            const female = (a.sex === 'female') ? a : closestMate;
            const male = (a.sex === 'male') ? a : closestMate;
            male.matingCooldown = 12.0;
            female.isPregnant = true;
            female.daysPregnant = 0.0;
            female.gestationRemaining = 21.0 + (Math.random() - 0.5) * 2.0;
            female.litterSize = 8 + Math.floor(Math.random() * 6); // +30% taxa natalidade (8 a 13 filhotes)
            female.mateGenome = male.genome;
            female.estrusDurationRemaining = 0.0;
            female.estrusCycleTimer = female.gestationRemaining;
            female.matingCooldown = female.gestationRemaining + 11.5;
          }
        }
      }

      // Forrageamento ativo se não encontrou parceiro ou está com fome (radar de 65m)
      if (!mateTargetFound) {
        let bestScore = -999;
        let bestX = curX, bestY = curY;
        const searchRadius = 65;

        for (let dy = -searchRadius; dy <= searchRadius; dy += 3) {
          const ny = curY + dy;
          if (ny < 0 || ny >= CHUNK_SIZE) continue;
          for (let dx = -searchRadius; dx <= searchRadius; dx += 3) {
            const nx = curX + dx;
            if (nx < 0 || nx >= CHUNK_SIZE) continue;
            if (dx * dx + dy * dy > searchRadius * searchRadius) continue;

            const nIdx = ctx.getIdx(nx, ny);
            const isFlooded = (matId[nIdx] === ctx.MAT_WATER || surfaceWater[nIdx] > 0.15);
            const floodPenalty = isFlooded ? -80.0 : 0.0;

            const grainVal = grains[nIdx] || 0.0;
            const score = (biomass[nIdx] * 0.12) + (grainVal * 8.5) + (moisture[nIdx] * 18.0) + floodPenalty;

            if (score > bestScore) {
              bestScore = score;
              bestX = nx;
              bestY = ny;
            }
          }
        }

        // Memória espacial genética de alimento
        let memoryBiasX = 0, memoryBiasY = 0, hasMemGoal = false;
        if (a.hunger > 20 && a.hasFoodMemory) {
          const dMem = Math.hypot(a.foodMemoryX - a.x, a.foodMemoryY - a.y);
          if (dMem > 2.0 && dMem < 120.0) {
            const memRetention = (a.genome && a.genome.memoryRetention) || 0.70;
            memoryBiasX = ((a.foodMemoryX - a.x) / dMem) * 6.5 * memRetention;
            memoryBiasY = ((a.foodMemoryY - a.y) / dMem) * 6.5 * memRetention;
            hasMemGoal = true;
          } else if (dMem <= 2.0 && biomass[curIdx] < 3.0 && (grains[curIdx] || 0) < 0.5) {
            a.hasFoodMemory = false;
          }
        }

        // Busca de água doce por sede
        let thirstBiasX = 0, thirstBiasY = 0, hasThirstGoal = false;
        if (a.thirst > 40) {
          const dLakeCenter = Math.hypot(a.x - 256.0, a.y - 256.0);
          if (dLakeCenter > 52.0) {
            thirstBiasX = ((256.0 - a.x) / dLakeCenter) * 5.0;
            thirstBiasY = ((256.0 - a.y) / dLakeCenter) * 5.0;
            hasThirstGoal = true;
          }
        }

        // Busca de ninho/toca por fadiga/sono
        let sleepBiasX = 0, sleepBiasY = 0, hasSleepGoal = false;
        if (a.fatigue > 65.0 && a.hasNest) {
          const dNest = Math.hypot(a.nestX - a.x, a.nestY - a.y);
          if (dNest > 2.0) {
            sleepBiasX = ((a.nestX - a.x) / dNest) * 5.5;
            sleepBiasY = ((a.nestY - a.y) / dNest) * 5.5;
            hasSleepGoal = true;
          }
        }

        const isInClearedDepletedZone = (biomass[curIdx] < 3.0 && (grains[curIdx] || 0) < 0.5);

        if (hasSleepGoal) {
          targetX = a.x + sleepBiasX;
          targetY = a.y + sleepBiasY;
        } else if (hasThirstGoal && a.thirst > 55.0) {
          targetX = a.x + thirstBiasX;
          targetY = a.y + thirstBiasY;
        } else if (bestScore > 5.0 && (bestX !== curX || bestY !== curY)) {
          targetX = bestX;
          targetY = bestY;
        } else if (hasMemGoal) {
          targetX = a.x + memoryBiasX;
          targetY = a.y + memoryBiasY;
        } else if (isInClearedDepletedZone) {
          if (!a.wanderAngle) a.wanderAngle = Math.random() * Math.PI * 2;
          targetX = Math.max(2, Math.min(CHUNK_SIZE - 3, a.x + Math.cos(a.wanderAngle) * 8.0));
          targetY = Math.max(2, Math.min(CHUNK_SIZE - 3, a.y + Math.sin(a.wanderAngle) * 8.0));
        } else {
          // Perambulação exploratória (Lévy Flight)
          if (!a.wanderAngle) a.wanderAngle = Math.random() * Math.PI * 2;
          a.wanderAngle += (Math.random() - 0.5) * 0.7;
          targetX = Math.max(2, Math.min(CHUNK_SIZE - 3, a.x + Math.cos(a.wanderAngle) * 5.0));
          targetY = Math.max(2, Math.min(CHUNK_SIZE - 3, a.y + Math.sin(a.wanderAngle) * 5.0));
        }
      }
    }
  }

  // 4. Habilidades de natação e mergulho defensivo submerso contra Harpias
  let underAirThreat = false;
  if (harpies && harpies.length > 0) {
    for (let hi = 0; hi < harpies.length; hi++) {
      const h = harpies[hi];
      if (h.hp > 0 && !h.migrated && (h.state === 'dive' || h.state === 'patrol')) {
        if (Math.hypot(h.x - a.x, h.y - a.y) < 25.0) {
          underAirThreat = true;
          break;
        }
      }
    }
  }

  if (inWater && underAirThreat && a.breath > 0) {
    a.isDiving = true;
    a.breath = Math.max(0, a.breath - dt);
  } else {
    a.isDiving = false;
    a.breath = Math.min(a.maxBreath, a.breath + 3.0 * dt);
  }

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser (compatível com file:// e web servers)
if (typeof window !== 'undefined') {
  window.RatSpecies = {
    createDefaultRatGenome,
    recombineRatGenome,
    updateRatBehavior
  };
  window.createDefaultRatGenome = createDefaultRatGenome;
  window.recombineRatGenome = recombineRatGenome;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createDefaultRatGenome,
    recombineRatGenome,
    updateRatBehavior
  };
}
