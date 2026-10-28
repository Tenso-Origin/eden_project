// =========================================================================
// MÓDULO DA ESPÉCIE: GATO (Felis catus / Predador com Faro e Emboscada)
// =========================================================================

/**
 * Criação do genoma felino herdável pelo DNA aos descendentes
 */
function createDefaultCatGenome() {
  return {
    harpyVigilance: 1.0 + (Math.random() * 0.4 - 0.2), // 0.8 a 1.2: percepção da sombra e mergulho da harpia
    ambushPatience: 1.0 + (Math.random() * 0.4 - 0.2), // 0.8 a 1.2: tempo de espera na orla da várzea
    combatFerocity: 1.0 + (Math.random() * 0.4 - 0.2), // 0.8 a 1.2: poder de abate e revide contra harpia
    staminaEfficiency: 1.0 + (Math.random() * 0.4 - 0.2), // 0.8 a 1.2: economia anaeróbica no sprint
    memoryRetention: 0.75 + (Math.random() * 0.20 - 0.10), // 0.65 a 0.85: retenção da memória espacial genética de caça
    generation: 0
  };
}

/**
 * Recombinação genética mendeliana felina com herança epigenética e mutação
 */
function recombineCatGenome(motherGen, fatherGen) {
  const m = motherGen || createDefaultCatGenome();
  const f = fatherGen || m;
  const mut = () => (Math.random() * 0.10 - 0.05); // Mutação mendeliana ±5%
  return {
    harpyVigilance: Math.max(0.6, Math.min(2.2, (m.harpyVigilance + f.harpyVigilance) * 0.5 * (1.0 + mut()))),
    ambushPatience: Math.max(0.6, Math.min(2.2, (m.ambushPatience + f.ambushPatience) * 0.5 * (1.0 + mut()))),
    combatFerocity: Math.max(0.6, Math.min(2.2, (m.combatFerocity + f.combatFerocity) * 0.5 * (1.0 + mut()))),
    staminaEfficiency: Math.max(0.6, Math.min(2.2, (m.staminaEfficiency + f.staminaEfficiency) * 0.5 * (1.0 + mut()))),
    memoryRetention: Math.max(0.40, Math.min(1.0, (m.memoryRetention + f.memoryRetention) * 0.5 * (1.0 + mut()))),
    generation: Math.max(m.generation || 0, f.generation || 0) + 1
  };
}

/**
 * Ciclo Comportamental Completo do Gato (Caça de Emboscada, Desinteresse, Sede, Sono, Defesa)
 * Retorna { targetX, targetY }
 */
function updateCatBehavior(a, dt, ctx) {
  const {
    animals,
    biomass,
    inWater,
    floodEscapeX,
    floodEscapeY,
    isReadyToMate,
    isInEstrus,
    currentScenario,
    isProtectedInBurrowOrRefuge,
    applyDeathDecomposition
  } = ctx;

  const gridW = ctx.GRID_WIDTH || 2048;
  const gridH = ctx.GRID_HEIGHT || 1024;

  const CAT_HUNTING_ZONE = 25; // Percepção direta visual e auditiva de caça (25 metros)
  const CAT_OLFACTORY_RANGE = 90; // Faro químico de presas e trilha de odor (90 metros)

  // 1. Inicialização de segurança dos atributos de combate e fisiologia
  if (a.stamina === undefined) {
    a.stamina = 100.0;
    a.maxStamina = 100.0;
    a.isExhausted = false;
    a.attackPower = 42.0;
    a.defensePower = 14.0;
    a.isCornered = false;
    a.catGenome = createDefaultCatGenome();
    a.mateCatGenome = createDefaultCatGenome();
  }

  if (!a.catGenome) a.catGenome = createDefaultCatGenome();
  if (a.painStun === undefined) a.painStun = 0.0;
  if (a.painStun > 0) a.painStun = Math.max(0, a.painStun - dt);

  // Regeneração de Stamina e recuperação de exaustão fisiológica
  if (a.isExhausted) {
    a.stamina = Math.min(a.maxStamina, a.stamina + 8.0 * dt);
    if (a.stamina >= 35.0) {
      a.isExhausted = false; // Recuperou o fôlego
    }
  } else {
    a.stamina = Math.min(a.maxStamina, a.stamina + 14.0 * dt);
  }

  a.currentSprintBoost = a.isExhausted ? 0.75 : 1.0;
  if (a.painStun > 0) a.currentSprintBoost = 0.50; // Hesitação temporária por dor de mordida

  let targetX = a.x;
  let targetY = a.y;

  // 2. Comunicação e Chamado Acústico / Feromônio de Acasalamento (até 100m)
  let mateFound = false;
  let closestMate = null;
  let closestMateDist = 100.0;

  if (isReadyToMate && animals.filter(x => x.species === 'cat').length < 80) {
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id) continue;
      if (other.species === 'cat' && other.hp > 0 && other.sex !== a.sex) {
        const otherInEstrus = (other.sex === 'female' && other.estrusDurationRemaining > 0);
        const isPairReceptive = (a.sex === 'female' && isInEstrus && other.sex === 'male' && other.hunger < 55 && other.matingCooldown <= 0) ||
                               (a.sex === 'male' && other.sex === 'female' && otherInEstrus && !other.isPregnant && other.hunger < 55 && other.matingCooldown <= 0);

        if (isPairReceptive) {
          const d = Math.hypot(other.x - a.x, other.y - a.y);
          if (d < closestMateDist) {
            closestMateDist = d;
            closestMate = other;
          }
        }
      }
    }

    if (closestMate) {
      targetX = closestMate.x;
      targetY = closestMate.y;
      mateFound = true;

      if (closestMateDist < 1.8) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;

        male.matingCooldown = 30.0;
        female.isPregnant = true;
        female.daysPregnant = 0.0;
        female.gestationRemaining = 64.0 + (Math.random() - 0.5) * 4.0;
        female.litterSize = 3 + Math.floor(Math.random() * 3);
        female.mateCatGenome = male.catGenome;
        female.estrusDurationRemaining = 0.0;
        female.estrusCycleTimer = female.gestationRemaining;
        female.matingCooldown = female.gestationRemaining + 45.0;
      }
    }
  }

  // 3. Territorialidade: repulsão mútua se não for parceiro em cio
  let territoryRepulsionX = 0, territoryRepulsionY = 0, rivalCount = 0;
  if (!mateFound) {
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id) continue;
      if (other.species === 'cat' && other.hp > 0) {
        const d = Math.hypot(other.x - a.x, other.y - a.y);
        if (d < 10.0) {
          territoryRepulsionX += (a.x - other.x) / (d + 0.1);
          territoryRepulsionY += (a.y - other.y) / (d + 0.1);
          rivalCount++;
        }
      }
    }
  }

  // 4. CAÇA: DIVERSÃO NA ZONA DE CAÇA (25m) VS FOME FORA DELA (90m) + PERDA DE INTERESSE
  if (!mateFound) {
    let closestPrey = null;
    let closestDist = 99999;
    let isInHuntingZone = false;

    // Só busca presas se NÃO estiver no cooldown de desinteresse
    if (a.chaseAbandonCooldown <= 0) {
      for (let j = 0; j < animals.length; j++) {
        const prey = animals[j];
        if (prey.species === 'rat' && prey.hp > 0) {
          // Rato em toca, refúgio natural ou MERGULHADO: imune
          if (isProtectedInBurrowOrRefuge(prey) || prey.isDiving) continue;

          const d = Math.hypot(prey.x - a.x, prey.y - a.y);
          if (d <= CAT_HUNTING_ZONE) {
            if (!isInHuntingZone || d < closestDist) {
              closestDist = d;
              closestPrey = prey;
              isInHuntingZone = true;
            }
          } else if (!isInHuntingZone && d <= CAT_OLFACTORY_RANGE) {
            if (d < closestDist) {
              closestDist = d;
              closestPrey = prey;
            }
          }
        }
      }
    }

    let shouldHunt = false;
    let isFunHunt = false;

    // Sede crítica (> 50%) tem prioridade absoluta sobre caçadas para garantir sobrevivência
    const isCriticalThirst = (a.thirst > 50.0);

    if (closestPrey && a.chaseAbandonCooldown <= 0 && !isCriticalThirst) {
      if (isInHuntingZone) {
        // Zona de caça (25m): caça por diversão até 2 abates diários
        if (a.dailyFunKills < 2) {
          shouldHunt = true;
          isFunHunt = true;
        } else if (a.hunger > 30) {
          shouldHunt = true;
          isFunHunt = false;
        }
      } else if (a.hunger > 30) {
        // Fora da zona de caça (até 90m): apenas se com fome
        shouldHunt = true;
        isFunHunt = false;
      }
    }

    if (shouldHunt && closestPrey) {
      if (a.targetPreyId !== closestPrey.id) {
        a.targetPreyId = closestPrey.id;
        a.chaseTimer = 0.0;
      }
      a.chaseTimer += dt;

      // MECÂNICA DE DESINTERESSE OU MUDANÇA DE ALVO (PREDADOR DE EMBOSCADA):
      // Abandono se > 5.0 segundos, ou presa > 28m, ou exausto, ou presa em refúgio/mergulho
      if (a.chaseTimer > 5.0 || closestDist > 28.0 || a.isExhausted || isProtectedInBurrowOrRefuge(closestPrey) || closestPrey.isDiving) {
        a.targetPreyId = null;
        a.chaseTimer = 0.0;
        a.chaseAbandonCooldown = 4.0; // Desiste e descansa por 4s
        shouldHunt = false;
        closestPrey = null;
      }
    }

    if (shouldHunt && closestPrey) {
      targetX = closestPrey.x;
      targetY = closestPrey.y;

      const preyCellIdx = ctx.getIdx(Math.floor(closestPrey.x), Math.floor(closestPrey.y));
      const inHighVegetation = (biomass[preyCellIdx] > 35.0);

      // Pounce Burst anaeróbico limitado por Stamina e eficiência do DNA felino
      const eff = (a.catGenome && a.catGenome.staminaEfficiency) || 1.0;
      if (closestDist <= 4.5 && !inHighVegetation && a.painStun <= 0) {
        if (a.isExhausted) {
          a.currentSprintBoost = 0.65;
        } else {
          a.currentSprintBoost = 1.35;
          a.stamina = Math.max(0, a.stamina - (20.0 / eff) * dt);
          if (a.stamina <= 0) {
            a.isExhausted = true;
            a.currentSprintBoost = 0.65;
          }
        }
      }

      // Bote de caça com combate e dano no HP (Resposta Funcional de Holling)
      if (closestDist < 1.4 && a.painStun <= 0) {
        if (isProtectedInBurrowOrRefuge(closestPrey) || closestPrey.isDiving) {
          a.currentSprintBoost = 1.0;
        } else {
          // Verifica se o rato está sozinho (sem outros roedores num raio de 10m para alerta coletivo)
          let nearbyRats = 0;
          for (let k = 0; k < animals.length; k++) {
            const oth = animals[k];
            if (oth.id !== closestPrey.id && oth.species === 'rat' && oth.hp > 0) {
              if (Math.hypot(oth.x - closestPrey.x, oth.y - closestPrey.y) < 10.0) {
                nearbyRats++;
                break;
              }
            }
          }
          const isPreyAlone = (nearbyRats === 0);

          // Rato sozinho e surpreendido: escape quase nulo (bote letal certeiro do felino)
          const refugeSkill = closestPrey.genome ? closestPrey.genome.refugeAffinity : 0.45;
          let escapeChance = inHighVegetation ? Math.min(0.65, 0.30 + refugeSkill * 0.30) : 0.0;
          if (isPreyAlone) {
            escapeChance = inHighVegetation ? 0.05 : 0.0; // Presa isolada não consegue escapar
          }

          if (Math.random() >= escapeChance) {
            const ferocity = (a.catGenome && a.catGenome.combatFerocity) || 1.0;
            const ambushMultiplier = isPreyAlone ? 2.8 : 1.0;
            const catDmg = Math.max(16.0, (a.attackPower * ferocity * ambushMultiplier - (closestPrey.defensePower || 3.0) * 0.5) * dt * 5.5);
            closestPrey.hp -= catDmg;

            if (closestPrey.hp <= 0) {
              closestPrey.hp = 0;
              if (ctx.onPredationSuccess) ctx.onPredationSuccess(closestPrey, a, isFunHunt);

              a.foodMemoryX = closestPrey.x;
              a.foodMemoryY = closestPrey.y;
              a.hasFoodMemory = true;
              a.targetPreyId = null;
              a.chaseTimer = 0.0;
              a.hunger = Math.max(0, a.hunger - 90.0);

              if (isFunHunt && a.dailyFunKills < 2) {
                a.dailyFunKills++;
              }
            }
          }
        }
      }
    } else if (inWater && (floodEscapeX !== 0 || floodEscapeY !== 0)) {
      targetX = a.x + floodEscapeX * 3.5;
      targetY = a.y + floodEscapeY * 3.5;
    } else if (a.isPregnant && a.gestationRemaining < 4.0 && a.hasNest) {
      targetX = a.nestX;
      targetY = a.nestY;
    } else if (a.fatigue > 70.0 && a.hasNest) {
      const dNest = Math.hypot(a.nestX - a.x, a.nestY - a.y);
      if (dNest > 2.0) {
        targetX = a.x + ((a.nestX - a.x) / dNest) * 3.8;
        targetY = a.y + ((a.nestY - a.y) / dNest) * 3.8;
      }
    } else if (a.thirst > 25.0) {
      const curCellIdx = ctx.getIdx(Math.floor(a.x), Math.floor(a.y));
      if (surfaceWater[curCellIdx] > 0.04) {
        // Bebe água em poça de chuva ou orla imediata
        a.thirst = Math.max(0, a.thirst - 60.0 * dt);
      } else {
        const dLakeCenter = Math.hypot(a.x - 256.0, a.y - 256.0);
        if (dLakeCenter > 52.0) {
          // Caminha em direção à margem segura do lago (raio 51-52m)
          targetX = a.x + ((256.0 - a.x) / dLakeCenter) * 3.8;
          targetY = a.y + ((256.0 - a.y) / dLakeCenter) * 3.8;
        } else if (dLakeCenter < 48.0) {
          // Água profunda: recua imediatamente para a orla segura
          targetX = a.x + ((a.x - 256.0) / (dLakeCenter + 0.1)) * 4.0;
          targetY = a.y + ((a.y - 256.0) / (dLakeCenter + 0.1)) * 4.0;
        } else {
          // Na orla perfeita: bebe água calmamente
          a.thirst = Math.max(0, a.thirst - 60.0 * dt);
        }
      }
    } else if (rivalCount > 0) {
      targetX = a.x + territoryRepulsionX * 3.5;
      targetY = a.y + territoryRepulsionY * 3.5;
    } else {
      // Inteligência de emboscada: margens do lago e várzea atraem roedores
      let ambushX = 0, ambushY = 0, hasAmbushGoal = false;
      if (currentScenario === 'amazon' && a.hunger > 22) {
        const distToCenter = Math.hypot(a.x - 256.0, a.y - 256.0);
        if (distToCenter > 215.0) {
          ambushX = (256.0 - a.x) / distToCenter;
          ambushY = (256.0 - a.y) / distToCenter;
          hasAmbushGoal = true;
        } else if (distToCenter < 52.0) {
          ambushX = (a.x - 256.0) / distToCenter;
          ambushY = (a.y - 256.0) / distToCenter;
          hasAmbushGoal = true;
        }
      }

      // Memória territorial de caça bem-sucedida
      if (a.hunger > 28.0 && a.hasFoodMemory && a.chaseAbandonCooldown <= 0) {
        const dMem = Math.hypot(a.foodMemoryX - a.x, a.foodMemoryY - a.y);
        if (dMem > 3.0 && dMem < 100.0) {
          const memRetention = (a.catGenome && a.catGenome.memoryRetention) || 0.75;
          targetX = a.x + ((a.foodMemoryX - a.x) / dMem) * 3.5 * memRetention;
          targetY = a.y + ((a.foodMemoryY - a.y) / dMem) * 3.5 * memRetention;
        } else {
          targetX = a.x + (Math.random() - 0.5) * 4.0;
          targetY = a.y + (Math.random() - 0.5) * 4.0;
        }
      } else if (hasAmbushGoal) {
        targetX = a.x + ambushX * 3.2 + (Math.random() - 0.5) * 1.5;
        targetY = a.y + ambushY * 3.2 + (Math.random() - 0.5) * 1.5;
      } else {
        targetX = a.x + (Math.random() - 0.5) * 4.0;
        targetY = a.y + (Math.random() - 0.5) * 4.0;
      }
    }
  }

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.CatSpecies = {
    createDefaultCatGenome,
    recombineCatGenome,
    updateCatBehavior
  };
  window.createDefaultCatGenome = createDefaultCatGenome;
  window.recombineCatGenome = recombineCatGenome;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    createDefaultCatGenome,
    recombineCatGenome,
    updateCatBehavior
  };
}
