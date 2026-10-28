// =========================================================================
// MÓDULO DE ESPÉCIES AQUÁTICAS: TAMBAQUI E TRAÍRA (EQUILÍBRIO TRÓFICO LACUSTRE)
// =========================================================================

/**
 * Criação da fauna aquática inicial do lago
 * Calibração Lotka-Volterra: Alta proporção de presas (Tambaquis) para poucos predadores de emboscada (Traíras).
 */
function createInitialAquatic(lakeCenterX = 512.0, lakeCenterY = 512.0, lakeRadius = 100.0) {
  const aquaticList = [];
  const TAMBAQUI_COUNT = 65; // População base sólida de peixes frugívoros/herbívoros
  const TRAIRA_COUNT = 8;    // Predadores solitários noturnos em baixa densidade (~8:1)

  // 1. Tambaquis (Colossoma macropomum) - Herbívoros/Frugívoros pacíficos em cardume
  for (let i = 0; i < TAMBAQUI_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const r = Math.random() * (lakeRadius * 0.82);
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
      hunger: 5.0 + Math.random() * 15.0,
      speed: 2.2,
      attackPower: 4.0,
      defensePower: 8.0,
      ageInDays: 300.0 + Math.random() * 400.0,
      maxLifespan: 9125.0, // ~25 anos
      matingCooldown: 25.0 + Math.random() * 35.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      fearTimer: 0.0,
      wanderAngle: angle + Math.PI / 2
    });
  }

  // 2. Traíras (Hoplias malabaricus) - Predadores carnívoros solitários de emboscada noturna
  for (let i = 0; i < TRAIRA_COUNT; i++) {
    const angle = (i / TRAIRA_COUNT) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
    // Distribuídas pelas margens com vegetação ou fundo lodoso
    const r = lakeRadius * (0.35 + Math.random() * 0.50);
    const x = lakeCenterX + Math.cos(angle) * r;
    const y = lakeCenterY + Math.sin(angle) * r;
    const sex = (i % 2 === 0) ? 'female' : 'male';

    aquaticList.push({
      id: 3000 + i,
      species: 'traira',
      diet: 'carnivore',
      name: 'Traíra da Amazônia',
      sex: sex,
      x: x,
      y: y,
      hp: 120,
      maxHp: 120,
      hunger: 5.0 + Math.random() * 15.0, // Saciedade inicial saudável
      speed: 1.8,                        // Natação lenta de espreita / esconde-esconde
      lungeSpeed: 6.2,                   // Bote explosivo veloz de curta distância
      attackPower: 32.0,                 // Mordida fulminante com dentes cônicos caniniformes
      defensePower: 9.0,
      ageInDays: 350.0 + Math.random() * 300.0,
      maxLifespan: 4380.0,               // ~12 anos
      matingCooldown: 40.0 + Math.random() * 40.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      isLurking: true,                   // Começa em camuflagem de tocaia
      lungeCooldown: 0.0,
      wanderAngle: angle
    });
  }

  return aquaticList;
}

/**
 * Atualização comportamental do Tambaqui (Forrageamento, natação em cardume e fuga de ameaças)
 */
function updateTambaquiBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, getIdx, grains, biomass, weather } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Manutenção de confinamento rigoroso no lago
  const dToCenter = Math.hypot(a.x - lakeCenterX, a.y - lakeCenterY);
  if (dToCenter > lakeRadius * 0.88) {
    const toCX = (lakeCenterX - a.x) / dToCenter;
    const toCY = (lakeCenterY - a.y) / dToCenter;
    targetX = a.x + toCX * 8.0;
    targetY = a.y + toCY * 8.0;
    return { targetX, targetY };
  }

  // 2. Fuga de ameaças aquáticas (Traíras ativas e Jacarés)
  if (a.fearTimer > 0) a.fearTimer -= dt;
  let closestThreat = null;
  let minDist = 18.0;

  for (let j = 0; j < animals.length; j++) {
    const other = animals[j];
    if (other.hp <= 0) continue;
    // Traíra só assusta se não estiver camuflada/inativa ou se estiver muito perto (<10m)
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
    targetX = a.x + (escapeX / escDist) * 11.0;
    targetY = a.y + (escapeY / escDist) * 11.0;
    return { targetX, targetY };
  }

  // 3. Forrageamento pacífico: Sementes, frutos caídos na água ou biomassa aquática
  if (a.hunger > 20.0) {
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

  // 4. Dinâmica suave de cardume (Schooling): atração leve por outros tambaquis próximos
  let avgX = 0, avgY = 0, neighborCount = 0;
  for (let j = 0; j < animals.length; j++) {
    const peer = animals[j];
    if (peer !== a && peer.species === 'tambaqui' && peer.hp > 0) {
      const d = Math.hypot(peer.x - a.x, peer.y - a.y);
      if (d < 16.0 && d > 2.0) {
        avgX += peer.x;
        avgY += peer.y;
        neighborCount++;
      }
    }
  }

  if (neighborCount > 0) {
    avgX /= neighborCount;
    avgY /= neighborCount;
    const pullX = (avgX - a.x) * 0.08;
    const pullY = (avgY - a.y) * 0.08;
    a.wanderAngle += (Math.random() - 0.5) * 0.3 * dt;
    targetX = a.x + Math.cos(a.wanderAngle) * 3.5 + pullX;
    targetY = a.y + Math.sin(a.wanderAngle) * 3.5 + pullY;
  } else {
    a.wanderAngle += (Math.random() - 0.5) * 0.4 * dt;
    targetX = a.x + Math.cos(a.wanderAngle) * 3.5;
    targetY = a.y + Math.sin(a.wanderAngle) * 3.5;
  }

  return { targetX, targetY };
}

/**
 * Atualização comportamental da Traíra (Hoplias malabaricus):
 * - Hábito Noturno e Crepuscular: De dia fica em tocaia quieta (isLurking = true), metabolismo reduzido.
 * - Caça por Emboscada: Espreita solitária, sem frenesi em cardume; aproximação lenta e bote repentino.
 * - Alta Saciedade por Refeição: Alimenta-se espaçadamente, preservando a sustentabilidade do lago.
 */
function updateTrairaBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, weather, applyDeathDecomposition, onPredationSuccess } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Manutenção no lago
  const dToCenter = Math.hypot(a.x - lakeCenterX, a.y - lakeCenterY);
  if (dToCenter > lakeRadius * 0.90) {
    const toCX = (lakeCenterX - a.x) / dToCenter;
    const toCY = (lakeCenterY - a.y) / dToCenter;
    targetX = a.x + toCX * 8.0;
    targetY = a.y + toCY * 8.0;
    return { targetX, targetY };
  }

  // 2. Determinação de ciclo circadiano (Dia vs Noite)
  // Horário: 06:00 às 18:00 é dia. Antes das 06:00 ou após as 18:00 é noite/crepúsculo.
  const timeOfDay = (weather && weather.timeOfDay != null) ? weather.timeOfDay : 12.0;
  const isNight = (timeOfDay < 6.0 || timeOfDay > 18.0);

  if (a.lungeCooldown > 0) {
    a.lungeCooldown = Math.max(0, a.lungeCooldown - dt);
  }

  // 3. Estado Diurno: Tocaia e Camuflagem no fundo/vegetação
  if (!isNight) {
    a.isLurking = true;
    // Metabolismo muito lento de dia: fome sobe muito pouco
    // Só ataca se presa passar inadvertidamente bem na frente da boca (< 6.0m)
    let opportunisticPrey = null;
    let minDist = 6.0;

    for (let j = 0; j < animals.length; j++) {
      const p = animals[j];
      if (p === a || p.hp <= 0) continue;
      if (p.species === 'tambaqui' || (p.species === 'rat' && Math.hypot(p.x - lakeCenterX, p.y - lakeCenterY) < lakeRadius * 0.92) || p.species === 'giant_water_bug') {
        const d = Math.hypot(p.x - a.x, p.y - a.y);
        if (d < minDist) {
          minDist = d;
          opportunisticPrey = p;
        }
      }
    }

    if (opportunisticPrey && a.lungeCooldown <= 0) {
      // Bote fulminante de surpresa a partir da tocaia
      const dirX = opportunisticPrey.x - a.x;
      const dirY = opportunisticPrey.y - a.y;
      const dist = Math.hypot(dirX, dirY) || 1.0;
      targetX = opportunisticPrey.x;
      targetY = opportunisticPrey.y;

      if (dist <= 2.2) {
        const damage = a.attackPower * (0.9 + Math.random() * 0.3);
        opportunisticPrey.hp -= damage;
        a.lungeCooldown = 5.0;
        a.hunger = Math.max(0, a.hunger - 70.0); // Saciedade prolongada

        if (opportunisticPrey.hp <= 0) {
          if (applyDeathDecomposition) applyDeathDecomposition(opportunisticPrey.x, opportunisticPrey.y);
          if (onPredationSuccess) onPredationSuccess(opportunisticPrey, a);
        }
      }
      return { targetX, targetY };
    }

    // De dia fica quase estacionária (flutuação imperceptível na água)
    a.wanderAngle += (Math.random() - 0.5) * 0.1 * dt;
    targetX = a.x + Math.cos(a.wanderAngle) * 0.3;
    targetY = a.y + Math.sin(a.wanderAngle) * 0.3;
    return { targetX, targetY };
  }

  // 4. Estado Noturno: Caçador Ativo por Emboscada
  a.isLurking = false;

  // Busca presas aquáticas (Tambaqui) ou terrestres vulneráveis na água (Ratos, Baratas-d'água)
  let bestPrey = null;
  let bestScore = -999;
  const detectionRadius = (a.hunger > 35.0) ? 26.0 : 16.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0) continue;

    const isAquatic = (prey.species === 'tambaqui' || prey.species === 'giant_water_bug');
    const isTerrestrialInWater = (prey.species === 'rat' && Math.hypot(prey.x - lakeCenterX, prey.y - lakeCenterY) < lakeRadius * 0.92);

    if (!isAquatic && !isTerrestrialInWater) continue;

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

  // 5. Ataque e Perseguição Curta
  if (bestPrey && a.hunger > 12.0) {
    const dirX = bestPrey.x - a.x;
    const dirY = bestPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    targetX = bestPrey.x;
    targetY = bestPrey.y;

    if (dist <= 2.2 && a.lungeCooldown <= 0) {
      // Bote veloz com mordida esmagadora
      const damage = a.attackPower * (0.85 + Math.random() * 0.4);
      bestPrey.hp -= damage;
      a.lungeCooldown = 4.0;
      a.hunger = Math.max(0, a.hunger - 65.0); // Alta saciedade

      if (bestPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(bestPrey.x, bestPrey.y);
        if (onPredationSuccess) onPredationSuccess(bestPrey, a);
      }
    } else {
      // Aproximação furtiva antes do bote
      const rush = (dist < 10.0 && a.lungeCooldown <= 0) ? a.lungeSpeed : a.speed;
      targetX = a.x + (dirX / dist) * rush * 1.5;
      targetY = a.y + (dirY / dist) * rush * 1.5;
    }

    return { targetX, targetY };
  }

  // 6. Patrulha noturna solitária e territorial
  // Evita aproximação de outras traíras para manter territórios separados
  let repX = 0, repY = 0;
  for (let j = 0; j < animals.length; j++) {
    const peer = animals[j];
    if (peer !== a && peer.species === 'traira' && peer.hp > 0) {
      const d = Math.hypot(peer.x - a.x, peer.y - a.y);
      if (d < 25.0 && d > 0.1) {
        repX += (a.x - peer.x) / d;
        repY += (a.y - peer.y) / d;
      }
    }
  }

  a.wanderAngle += (Math.random() - 0.5) * 0.5 * dt;
  const patrolSpeed = 2.0;
  targetX = a.x + Math.cos(a.wanderAngle) * patrolSpeed + repX * 1.2;
  targetY = a.y + Math.sin(a.wanderAngle) * patrolSpeed + repY * 1.2;

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.AquaticSpecies = {
    createInitialAquatic,
    updateTambaquiBehavior,
    updateTrairaBehavior,
    updatePiranhaBehavior: updateTrairaBehavior // Alias de compatibilidade
  };
}