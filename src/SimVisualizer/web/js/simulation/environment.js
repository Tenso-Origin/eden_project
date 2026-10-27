// =========================================================================
// MÓDULO DE AMBIENTE: TERMODINÂMICA, HIDROLOGIA, FLORA E REFÚGIOS
// =========================================================================

/**
 * Dinâmica Térmica com Gradiente Altissonante Adiabático
 */
function stepThermodynamics(dt) {
  const simDeltaHours = 0.08 * dt;
  timeOfDay = (timeOfDay + simDeltaHours) % 24.0;
  totalSimHours += simDeltaHours;

  // Controle de virada de dia (reinicia cota diária de caça lúdica dos gatos)
  const currentDay = Math.floor(totalSimHours / 24.0);
  if (currentDay > lastSimDay) {
    lastSimDay = currentDay;
    for (let i = 0; i < animals.length; i++) {
      if (animals[i].species === 'cat') {
        animals[i].dailyFunKills = 0;
      }
    }
  }

  const sunHeight = Math.sin(((timeOfDay - 6.0) / 12.0) * Math.PI);
  const isDay = sunHeight > 0;
  const equatorY = 255.5;

  for (let y = 0; y < CHUNK_SIZE; y += 2) {
    const latDist = Math.abs(y - equatorY) / 255.5;
    const latFactor = Math.max(0, 1.0 - latDist);

    for (let x = 0; x < CHUNK_SIZE; x += 2) {
      const idx = getIdx(x, y);
      const elev = elevation[idx];
      const curT = temp[idx];

      // Gradiente adiabático padrão: -6.5°C por 1000m (-0.0065°C/m)
      const altitudeLapse = elev * 0.0065;

      let targetT = 0;
      if (isDay) {
        const solarHeat = sunHeight * (12.0 + latFactor * 14.0);
        targetT = 18.0 + solarHeat - altitudeLapse;
      } else {
        targetT = 13.0 + (latFactor * 7.0) - altitudeLapse;
      }

      const nT = curT + (targetT - curT) * 0.12 * dt;
      temp[idx] = nT;
      temp[idx + 1] = nT;
      if (y + 1 < CHUNK_SIZE) {
        temp[idx + CHUNK_SIZE] = nT;
        temp[idx + CHUNK_SIZE + 1] = nT;
      }

      // Transição de Neve Alpina acima de 1600m
      if (elev > 1600.0 && nT < 0.0 && matId[idx] === MAT_STONE) {
        matId[idx] = MAT_ICE;
      } else if (elev > 1600.0 && nT > 3.0 && matId[idx] === MAT_ICE) {
        matId[idx] = MAT_STONE;
      }
    }
  }
}

/**
 * Sistema Pluviométrico Dinâmico, Escoamento Gravitacional e Erosão Fluvial
 */
function stepHydrologyAndErosion(dt) {
  const simDeltaHours = 0.08 * dt;

  // 1. Ciclo Dinâmico de Chuva
  weather.timerHours -= simDeltaHours;
  if (weather.timerHours <= 0) {
    if (weather.isRaining) {
      weather.isRaining = false;
      weather.timerHours = 6.0 + Math.random() * 18.0;
      weather.intensity = 0.0;
    } else {
      weather.isRaining = true;
      weather.timerHours = 3.0 + Math.random() * 11.0;
      weather.intensity = 0.8 + Math.random() * 2.2;
      weather.frontX = Math.random() * CHUNK_SIZE;
      weather.frontY = Math.random() * CHUNK_SIZE;
      weather.speedX = (Math.random() - 0.45) * 3.0;
      weather.speedY = (Math.random() - 0.45) * 3.0;
      weather.cloudRadius = 110.0 + Math.random() * 120.0;
    }
  }

  weather.frontX = (weather.frontX + weather.speedX * dt + CHUNK_SIZE) % CHUNK_SIZE;
  weather.frontY = (weather.frontY + weather.speedY * dt + CHUNK_SIZE) % CHUNK_SIZE;

  nextSurfaceWater.set(surfaceWater);

  // Precipitação na frente de chuva
  if (weather.isRaining && weather.intensity > 0) {
    const stormSamples = 70;
    for (let i = 0; i < stormSamples; i++) {
      const ang = Math.random() * Math.PI * 2;
      const rad = Math.sqrt(Math.random()) * weather.cloudRadius;
      const rx = Math.floor((weather.frontX + Math.cos(ang) * rad + CHUNK_SIZE) % CHUNK_SIZE);
      const ry = Math.floor((weather.frontY + Math.sin(ang) * rad + CHUNK_SIZE) % CHUNK_SIZE);
      const rIdx = getIdx(rx, ry);
      nextSurfaceWater[rIdx] += weather.intensity * 0.45 * dt;
    }
  }

  // Evaporação solar
  const evapoSamples = 400;
  for (let i = 0; i < evapoSamples; i++) {
    const ex = Math.floor(Math.random() * CHUNK_SIZE);
    const ey = Math.floor(Math.random() * CHUNK_SIZE);
    const eIdx = getIdx(ex, ey);
    if (matId[eIdx] !== MAT_WATER && nextSurfaceWater[eIdx] > 0.01) {
      const t = temp[eIdx];
      if (t > 4.0) {
        const evRate = Math.min(nextSurfaceWater[eIdx], (t - 4.0) * 0.018 * dt);
        nextSurfaceWater[eIdx] -= evRate;
      }
    }
  }

  // Escoamento gravitacional e erosão celular (limite de 1.0 m/dia)
  const maxErosionStep = (1.0 / 24.0) * simDeltaHours;
  const passOffset = (tickCount % 2);

  for (let y = 1 + passOffset; y < CHUNK_SIZE - 1; y += 2) {
    for (let x = 1 + passOffset; x < CHUNK_SIZE - 1; x += 2) {
      const idx = getIdx(x, y);
      const water = surfaceWater[idx];
      if (water <= 0.01) continue;

      if (matId[idx] === MAT_WATER) {
        nextSurfaceWater[idx] = Math.max(0, -elevation[idx]);
        continue;
      }

      const curElev = elevation[idx];
      const curHead = curElev + water;
      const perm = MATERIALS[matId[idx]]?.perm || 0.5;

      // Infiltração no solo
      if (perm > 0) {
        const soilCap = Math.max(0, 1.0 - moisture[idx]);
        const infilt = Math.min(water, soilCap, perm * 0.45 * dt);
        nextSurfaceWater[idx] -= infilt;
        moisture[idx] = Math.min(1.0, moisture[idx] + infilt);
      }

      // Escoamento gravitacional
      let lowestHead = curHead;
      let lowestIdx = -1;

      const neighbors = [
        getIdx(x - 1, y),
        getIdx(x + 1, y),
        getIdx(x, y - 1),
        getIdx(x, y + 1)
      ];

      for (const nIdx of neighbors) {
        const nHead = elevation[nIdx] + surfaceWater[nIdx];
        if (nHead < lowestHead) {
          lowestHead = nHead;
          lowestIdx = nIdx;
        }
      }

      if (lowestIdx >= 0) {
        const headDiff = curHead - lowestHead;
        const flow = Math.min(water * 0.55, headDiff * 0.38) * dt;

        nextSurfaceWater[idx] -= flow;
        nextSurfaceWater[lowestIdx] += flow;

        // Erosão fluvial limitada
        if (headDiff > 0.1 && elevation[idx] > -90.0) {
          const erodibility = MATERIALS[matId[idx]]?.erod || 0.05;
          const potentialErosion = flow * headDiff * erodibility * 0.06;
          const erosionAmount = Math.min(maxErosionStep, potentialErosion);

          elevation[idx] -= erosionAmount;
          cumulativeErosion[idx] += erosionAmount;
          globalErosionTotal += erosionAmount;

          elevation[lowestIdx] += erosionAmount * 0.40;
        }
      }
    }
  }

  surfaceWater.set(nextSurfaceWater);
}

/**
 * Regeneração Biológica de Flora e Grãos de Várzea
 */
function stepFlora(dt) {
  const sampleCount = 600;
  for (let i = 0; i < sampleCount; i++) {
    const rx = Math.floor(Math.random() * CHUNK_SIZE);
    const ry = Math.floor(Math.random() * CHUNK_SIZE);
    const idx = getIdx(rx, ry);

    if (matId[idx] === MAT_WATER || matId[idx] === MAT_ICE) continue;

    const t = temp[idx];
    const m = moisture[idx];
    const curBio = biomass[idx];

    if (t >= 10 && t <= 40 && m > 0.1) {
      const opt = 1.0 - Math.abs(t - 24) / 16;
      const growth = Math.max(0.1, opt) * m * 3.5 * dt * (1.0 - curBio / 100);
      biomass[idx] = Math.min(100, curBio + growth);

      // Grãos de Arroz de Várzea (Oryza glumaepatula)
      if (currentScenario === 'amazon' && m > 0.40) {
        const d = Math.hypot(rx - 256, ry - 256);
        if (d >= 48.0 && d <= 145.0 && biomass[idx] < 55.0) {
          grains[idx] = Math.min(80.0, grains[idx] + 0.18 * dt * m);
        }
      }
    } else if (t < 0 || m < 0.05) {
      biomass[idx] = Math.max(0, curBio - 1.0 * dt);
    }
  }
}

/**
 * Decomposição Orgânica com Fertilização de Biomassa Vegetal
 */
function applyDeathDecomposition(centerX, centerY) {
  const cx = Math.floor(centerX);
  const cy = Math.floor(centerY);
  for (let dy = -2; dy <= 2; dy++) {
    const ny = cy + dy;
    if (ny < 0 || ny >= CHUNK_SIZE) continue;
    for (let dx = -2; dx <= 2; dx++) {
      const nx = cx + dx;
      if (nx < 0 || nx >= CHUNK_SIZE) continue;
      const d = Math.hypot(dx, dy);
      if (d <= 2.2) {
        const idx = getIdx(nx, ny);
        if (matId[idx] !== MAT_WATER && matId[idx] !== MAT_ICE) {
          biomass[idx] = Math.min(100, biomass[idx] + (2.5 - d) * 35.0);
          moisture[idx] = Math.min(1.0, moisture[idx] + 0.30);
        }
      }
    }
  }
}

/**
 * Refúgios Naturais: Troncos caídos, pedras e vegetação densa
 * Limitados a 10% da quantidade inicial de ratos (75% floresta, 25% várzea)
 */
function initNaturalRefuges(initialRatCount = 180) {
  naturalRefuges = [];
  const TOTAL_REFUGES = Math.max(1, Math.round(initialRatCount * 0.10));
  for (let i = 0; i < TOTAL_REFUGES; i++) {
    const inForest = (i < TOTAL_REFUGES * 0.75);
    for (let attempt = 0; attempt < 40; attempt++) {
      let rx, ry;
      if (currentScenario === 'amazon') {
        const angle = Math.random() * Math.PI * 2;
        const r = inForest
          ? (195.0 + Math.random() * 45.0)  // 75% na floresta densa (R > 195m)
          : (58.0 + Math.random() * 135.0); // 25% na várzea / gramíneas (R: 58m a 193m)
        rx = 256.0 + Math.cos(angle) * r;
        ry = 256.0 + Math.sin(angle) * r;
      } else {
        rx = 30 + Math.random() * (CHUNK_SIZE - 60);
        ry = 30 + Math.random() * (CHUNK_SIZE - 60);
      }
      rx = Math.max(10, Math.min(CHUNK_SIZE - 10, rx));
      ry = Math.max(10, Math.min(CHUNK_SIZE - 10, ry));
      const idx = getIdx(Math.floor(rx), Math.floor(ry));
      if (matId[idx] !== MAT_WATER && surfaceWater[idx] < 0.15) {
        const typeRoll = Math.random();
        const type = typeRoll < 0.40 ? 'log' : (typeRoll < 0.75 ? 'rock' : 'brush');
        naturalRefuges.push({
          id: i + 1,
          x: rx,
          y: ry,
          type: type,
          radius: 2.5
        });
        clearBiomassRadius(rx, ry, 10.0);
        break;
      }
    }
  }
}

/**
 * Localização de Toca ou Covil Maternal sem restrição de bioma
 */
function findLocalNestLocation(animal) {
  for (let attempt = 0; attempt < 25; attempt++) {
    const angle = Math.random() * Math.PI * 2;
    const dist = Math.random() * 4.0;
    const nx = Math.max(8, Math.min(CHUNK_SIZE - 9, animal.x + Math.cos(angle) * dist));
    const ny = Math.max(8, Math.min(CHUNK_SIZE - 9, animal.y + Math.sin(angle) * dist));
    const idx = getIdx(Math.floor(nx), Math.floor(ny));
    if (matId[idx] !== MAT_WATER && surfaceWater[idx] < 0.15) {
      return { x: nx, y: ny };
    }
  }
  return { x: animal.x, y: animal.y };
}

/**
 * Imunidade de Predação em Tocas, Covis e Refúgios Naturais
 */
function isProtectedInBurrowOrRefuge(animal) {
  // 1. Toca própria
  if (animal.hasNest && Math.hypot(animal.x - animal.nestX, animal.y - animal.nestY) <= 3.0) {
    return true;
  }
  // 2. Qualquer toca da mesma espécie
  for (let ni = 0; ni < nests.length; ni++) {
    const n = nests[ni];
    if (n.species === animal.species && Math.hypot(n.x - animal.x, n.y - animal.y) <= 3.0) {
      return true;
    }
  }
  // 3. Refúgio Natural (roedores)
  if (animal.species === 'rat') {
    for (let ri = 0; ri < naturalRefuges.length; ri++) {
      const r = naturalRefuges[ri];
      if (Math.hypot(r.x - animal.x, r.y - animal.y) <= r.radius) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Ciclo de vida efêmero maternal de tocas e covis
 */
function updateNestLifecycles() {
  const RAT_MATURITY_AGE = 60.0;
  const CAT_MATURITY_AGE = 210.0;
  const survivingNests = [];

  for (let ni = 0; ni < nests.length; ni++) {
    const nest = nests[ni];
    if (nest.species === 'harpy') {
      survivingNests.push(nest);
      continue;
    }

    const mId = nest.motherId;
    const mother = animals.find(a => a.id === mId && a.hp > 0);
    const maturityAge = (nest.species === 'rat') ? RAT_MATURITY_AGE : CAT_MATURITY_AGE;

    const isMotherPregnant = (mother && mother.isPregnant);
    const hasImmaturePups = animals.some(a => a.motherId === mId && a.hp > 0 && a.ageInDays < maturityAge);

    if (isMotherPregnant || hasImmaturePups) {
      survivingNests.push(nest);
    } else {
      if (mother) mother.hasNest = false;
      for (let ai = 0; ai < animals.length; ai++) {
        if (animals[ai].motherId === mId) {
          animals[ai].hasNest = false;
        }
      }
    }
  }
  nests = survivingNests;
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.Environment = {
    stepThermodynamics,
    stepHydrologyAndErosion,
    stepFlora,
    applyDeathDecomposition,
    initNaturalRefuges,
    findLocalNestLocation,
    isProtectedInBurrowOrRefuge,
    updateNestLifecycles
  };
  window.stepThermodynamics = stepThermodynamics;
  window.stepHydrologyAndErosion = stepHydrologyAndErosion;
  window.stepFlora = stepFlora;
  window.applyDeathDecomposition = applyDeathDecomposition;
  window.initNaturalRefuges = initNaturalRefuges;
  window.findLocalNestLocation = findLocalNestLocation;
  window.isProtectedInBurrowOrRefuge = isProtectedInBurrowOrRefuge;
  window.updateNestLifecycles = updateNestLifecycles;
}
