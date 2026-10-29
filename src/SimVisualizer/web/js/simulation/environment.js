function stepFlora(dt) {
  stepVegetationAndBiomass(dt);
}

// =========================================================================
// MÓDULO DE AMBIENTE: TERMODINÂMICA, CLIMA AMAZÔNICO, PULSO DE INUNDAÇÃO E FLORA
// =========================================================================

/**
 * Dinâmica Térmica com Gradiente Altissonante Adiabático (2048x1024)
 */
function stepThermodynamics(dt) {
  const simDeltaHours = 0.08 * dt;
  timeOfDay = (timeOfDay + simDeltaHours) % 24.0;
  totalSimHours += simDeltaHours;

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
  const equatorY = (GRID_HEIGHT - 1) / 2.0;

  for (let y = 0; y < GRID_HEIGHT; y += 2) {
    const latDist = Math.abs(y - equatorY) / equatorY;
    const latFactor = Math.max(0, 1.0 - latDist);

    for (let x = 0; x < GRID_WIDTH; x += 2) {
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
        targetT = 14.0 + (latFactor * 7.0) - altitudeLapse;
      }

      const nT = curT + (targetT - curT) * 0.12 * dt;
      temp[idx] = nT;
      temp[idx + 1] = nT;
      if (y + 1 < GRID_HEIGHT) {
        temp[idx + GRID_WIDTH] = nT;
        temp[idx + GRID_WIDTH + 1] = nT;
      }
    }
  }
}

/**
 * Sistema Meteorológico Amazônico, Ventos Alísios, Pulso de Inundação e Erosão Fluvial
 */
function stepHydrologyAndErosion(dt) {
  const simDeltaHours = 0.08 * dt;
  const simDate = getSimDate(totalSimHours);
  const isRainySeason = simDate.isRainySeason;

  // 1. Controle Sazonal dos Ventos Alísios e Precipitação Amazônica
  if (isRainySeason) {
    // Inverno Amazônico (Novembro a Abril):
    // Ventos Alísios fortes e constantes soprando do Oceano Atlântico (Leste) para o continente (Oeste)
    weather.speedX = -2.2;
    weather.speedY = 0.35 + Math.sin(totalSimHours * 0.05) * 0.2;
    weather.windSpeedKmH = 16.0 + Math.random() * 8.0;

    // Subida do Pulso Anual de Inundação (Flood Pulse): até +4.5m
    const seasonProgress = (simDate.monthIdx >= 10 ? (simDate.monthIdx - 10) : (simDate.monthIdx + 2)) / 6.0;
    const targetFloodLevel = Math.sin(seasonProgress * Math.PI) * 4.8;
    weather.floodPulseLevel += (targetFloodLevel - weather.floodPulseLevel) * 0.05 * dt;

    // Chuvas frequentes (ciclo curto de 4 a 8 horas)
    weather.timerHours -= simDeltaHours;
    if (weather.timerHours <= 0) {
      if (weather.isRaining) {
        weather.isRaining = false;
        weather.timerHours = 3.0 + Math.random() * 8.0;
        weather.intensity = 0.0;
      } else {
        weather.isRaining = true;
        weather.timerHours = 3.0 + Math.random() * 6.0;
        weather.intensity = 1.8 + Math.random() * 2.5; // Tempestades tropicais volumosas
        weather.frontX = (GRID_WIDTH - 150) + Math.random() * 100; // Entram pelo Leste
        weather.frontY = Math.random() * GRID_HEIGHT;
        weather.cloudRadius = 180.0 + Math.random() * 140.0;
      }
    }
  } else {
    // Verão Amazônico (Maio a Outubro):
    // Estiagem, ventos mais fracos e brisas locais
    weather.speedX = -0.6;
    weather.speedY = (Math.random() - 0.5) * 0.4;
    weather.windSpeedKmH = 6.0 + Math.random() * 5.0;

    // Recuo do Pulso de Inundação (Vazante): drena de volta para a calha normal (0.0m)
    weather.floodPulseLevel += (0.0 - weather.floodPulseLevel) * 0.08 * dt;

    weather.timerHours -= simDeltaHours;
    if (weather.timerHours <= 0) {
      if (weather.isRaining) {
        weather.isRaining = false;
        weather.timerHours = 18.0 + Math.random() * 40.0; // Intervalos longos sem chuva
        weather.intensity = 0.0;
      } else {
        weather.isRaining = true;
        weather.timerHours = 1.0 + Math.random() * 3.0; // Pancadas rápidas
        weather.intensity = 0.6 + Math.random() * 1.2;
        weather.frontX = Math.random() * GRID_WIDTH;
        weather.frontY = Math.random() * GRID_HEIGHT;
        weather.cloudRadius = 120.0 + Math.random() * 80.0;
      }
    }
  }

  // Deslocamento da frente de nuvens
  weather.frontX = (weather.frontX + weather.speedX * dt * 8.0 + GRID_WIDTH) % GRID_WIDTH;
  weather.frontY = (weather.frontY + weather.speedY * dt * 8.0 + GRID_HEIGHT) % GRID_HEIGHT;

  nextSurfaceWater.set(surfaceWater);

  // 2. Precipitação na Frente de Chuva
  if (weather.isRaining && weather.intensity > 0) {
    const stormSamples = 140;
    for (let i = 0; i < stormSamples; i++) {
      const ang = Math.random() * Math.PI * 2;
      const rad = Math.sqrt(Math.random()) * weather.cloudRadius;
      const rx = Math.floor((weather.frontX + Math.cos(ang) * rad + GRID_WIDTH) % GRID_WIDTH);
      const ry = Math.floor((weather.frontY + Math.sin(ang) * rad + GRID_HEIGHT) % GRID_HEIGHT);
      const rIdx = getIdx(rx, ry);
      nextSurfaceWater[rIdx] += weather.intensity * 0.55 * dt;
    }
  }

  // 3. Aplicação do Pulso de Inundação Fluvial nas Várzeas
  // Quando o nível do pulso sobe, a água extravasa o canal do rio e inunda áreas de várzea < floodPulseLevel
  if (weather.floodPulseLevel > 0.1) {
    const floodSamples = 400;
    for (let k = 0; k < floodSamples; k++) {
      const fx = Math.floor(Math.random() * GRID_WIDTH);
      const fy = Math.floor(Math.random() * GRID_HEIGHT);
      const fIdx = getIdx(fx, fy);
      const elev = elevation[fIdx];
      if (matId[fIdx] !== MAT_WATER && elev < weather.floodPulseLevel && elev < 12.0) {
        const expectedWater = weather.floodPulseLevel - elev;
        if (nextSurfaceWater[fIdx] < expectedWater) {
          nextSurfaceWater[fIdx] += (expectedWater - nextSurfaceWater[fIdx]) * 0.25 * dt;
        }
      }
    }
  }

  // 4. Evaporação Solar e Drenagem na Seca
  const evapoSamples = 600;
  for (let i = 0; i < evapoSamples; i++) {
    const ex = Math.floor(Math.random() * GRID_WIDTH);
    const ey = Math.floor(Math.random() * GRID_HEIGHT);
    const eIdx = getIdx(ex, ey);
    if (matId[eIdx] !== MAT_WATER && nextSurfaceWater[eIdx] > 0.01) {
      const t = temp[eIdx];
      if (t > 4.0) {
        const evRate = Math.min(nextSurfaceWater[eIdx], (t - 4.0) * (isRainySeason ? 0.012 : 0.035) * dt);
        nextSurfaceWater[eIdx] -= evRate;
      }
    }
  }

  // 5. Escoamento Gravitacional
  const passOffset = (tickCount % 2);
  for (let y = 1 + passOffset; y < GRID_HEIGHT - 1; y += 2) {
    for (let x = 1 + passOffset; x < GRID_WIDTH - 1; x += 2) {
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

      // Infiltração
      if (perm > 0) {
        const soilCap = Math.max(0, 1.0 - moisture[idx]);
        const infilt = Math.min(water, soilCap, perm * 0.45 * dt);
        nextSurfaceWater[idx] -= infilt;
        moisture[idx] = Math.min(1.0, moisture[idx] + infilt);
      }

      // Escoamento para célula mais baixa
      let lowestHead = curHead;
      let lowestIdx = -1;

      const nIndices = [
        getIdx(x - 1, y),
        getIdx(x + 1, y),
        getIdx(x, y - 1),
        getIdx(x, y + 1)
      ];

      for (let ni = 0; ni < 4; ni++) {
        const nIdx = nIndices[ni];
        const nHead = elevation[nIdx] + surfaceWater[nIdx];
        if (nHead < lowestHead) {
          lowestHead = nHead;
          lowestIdx = nIdx;
        }
      }

      if (lowestIdx !== -1) {
        const slope = (curHead - lowestHead);
        const flow = Math.min(water * 0.55, slope * 0.35) * dt;
        nextSurfaceWater[idx] -= flow;
        nextSurfaceWater[lowestIdx] += flow;

        // Mecânica de Erosão Fluvial, Desagregação e Transporte de Sedimentos
        if (flow > 0.005 && slope > 0.02) {
          const plantCover = (typeof biomass !== 'undefined' && biomass && biomass[idx] !== undefined) ? Math.min(1.0, biomass[idx] / 60.0) : 0.5;
          const erodibility = 0.012 * (1.0 - plantCover * 0.75);
          const eroded = Math.min(0.006, slope * flow * erodibility) * dt;
          if (eroded > 0.00001) {
            elevation[idx] -= eroded;
            elevation[lowestIdx] += eroded * 0.90;
            if (typeof cumulativeErosion !== 'undefined' && cumulativeErosion) cumulativeErosion[idx] += eroded;
            if (typeof globalErosionTotal !== 'undefined') globalErosionTotal += eroded;
          }
        }
      }
    }
  }

  surfaceWater.set(nextSurfaceWater);
}

/**
 * Dinâmica Vegetal e Renovação de Biomassa e Grãos
 */
function stepVegetationAndBiomass(dt) {
  const simDeltaDays = (0.08 * dt) / 24.0;
  const simDate = getSimDate(totalSimHours);
  const isDrySeason = !simDate.isRainySeason;

  // Difusão de umidade
  nextMoisture.set(moisture);
  const moistSamples = 300;
  for (let s = 0; s < moistSamples; s++) {
    const rx = 1 + Math.floor(Math.random() * (GRID_WIDTH - 2));
    const ry = 1 + Math.floor(Math.random() * (GRID_HEIGHT - 2));
    const idx = getIdx(rx, ry);
    const avg = (moisture[getIdx(rx-1, ry)] + moisture[getIdx(rx+1, ry)] + moisture[getIdx(rx, ry-1)] + moisture[getIdx(rx, ry+1)]) * 0.25;
    nextMoisture[idx] += (avg - moisture[idx]) * 0.15 * dt;
  }
  moisture.set(nextMoisture);

  // Amostragem de crescimento vegetal
  const bioSamples = 600;
  for (let s = 0; s < bioSamples; s++) {
    const rx = Math.floor(Math.random() * GRID_WIDTH);
    const ry = Math.floor(Math.random() * GRID_HEIGHT);
    const idx = getIdx(rx, ry);

    if (matId[idx] === MAT_WATER) continue;

    const m = moisture[idx];
    const t = temp[idx];

    if (t > 15.0 && t < 38.0 && m > 0.25) {
      // Crescimento vigoroso da flora amazônica
      const growth = (m * 0.8) * Math.sin(((t - 15) / 23) * Math.PI) * 12.0 * simDeltaDays;
      biomass[idx] = Math.min(100.0, biomass[idx] + growth);

      // Produção de sementes e grãos na várzea exposta durante a seca
      if (isDrySeason && elevation[idx] < 16.0 && surfaceWater[idx] < 0.1) {
        grains[idx] = Math.min(100.0, grains[idx] + 25.0 * simDeltaDays);
      }
    }
  }
}

/**
 * Alias de compatibilidade para stepVegetationAndBiomass
 */
function stepFlora(dt) {
  stepVegetationAndBiomass(dt);
}

/**
 * Decomposição orgânica de cadáveres e reciclagem biogeoquímica de nutrientes
 */
function applyDeathDecomposition(centerX, centerY) {
  if (typeof totalDecomposedCount !== 'undefined') totalDecomposedCount++;
  if (typeof totalNutrientsRecycledKg !== 'undefined') totalNutrientsRecycledKg += 0.28;

  const cx = Math.floor(centerX);
  const cy = Math.floor(centerY);
  const gridW = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gridH = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  for (let dy = -2; dy <= 2; dy++) {
    const ny = cy + dy;
    if (ny < 0 || ny >= gridH) continue;
    for (let dx = -2; dx <= 2; dx++) {
      const nx = cx + dx;
      if (nx < 0 || nx >= gridW) continue;
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
 * Distribuídos pela bacia amazônica 2048x1024
 */
function initNaturalRefuges(initialRatCount = 180) {
  naturalRefuges = [];
  let nextId = 1;
  const gridW = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gridH = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  const totalRefuges = 80;
  for (let i = 0; i < totalRefuges; i++) {
    for (let attempt = 0; attempt < 50; attempt++) {
      const rx = 25 + Math.random() * (gridW - 50);
      const ry = 25 + Math.random() * (gridH - 50);
      const idx = getIdx(Math.floor(rx), Math.floor(ry));

      if (matId[idx] !== MAT_WATER && surfaceWater[idx] < 0.15) {
        const typeRoll = Math.random();
        const type = typeRoll < 0.40 ? 'log' : (typeRoll < 0.75 ? 'rock' : 'brush');
        naturalRefuges.push({
          id: nextId++,
          x: rx,
          y: ry,
          type: type,
          radius: 1.0
        });
        clearBiomassRadius(rx, ry, 1.5);
        break;
      }
    }
  }
}

/**
 * Localização de Toca ou Covil Maternal sem restrição de bioma
 */
function findLocalNestLocation(animal) {
  const gridW = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gridH = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  for (let attempt = 0; attempt < 25; attempt++) {
    const angle = Math.random() * Math.PI * 2;
    const dist = Math.random() * 4.0;
    const nx = Math.max(8, Math.min(gridW - 9, animal.x + Math.cos(angle) * dist));
    const ny = Math.max(8, Math.min(gridH - 9, animal.y + Math.sin(angle) * dist));
    const idx = getIdx(Math.floor(nx), Math.floor(ny));
    if (matId[idx] !== MAT_WATER && surfaceWater[idx] < 0.15) {
      return { x: nx, y: ny };
    }
  }
  return { x: animal.x, y: animal.y };
}

/**
 * Imunidade de Predação em Tocas, Covis e Refúgios Naturais (Raio de 1m)
 */
function isProtectedInBurrowOrRefuge(animal) {
  if (animal.hasNest && Math.hypot(animal.x - animal.nestX, animal.y - animal.nestY) <= 1.2) {
    return true;
  }
  for (let ni = 0; ni < nests.length; ni++) {
    const n = nests[ni];
    if (n.species === animal.species && Math.hypot(n.x - animal.x, n.y - animal.y) <= 1.2) {
      return true;
    }
  }
  if (animal.species === 'rat' && typeof naturalRefuges !== 'undefined') {
    for (let ri = 0; ri < naturalRefuges.length; ri++) {
      const r = naturalRefuges[ri];
      if (Math.hypot(r.x - animal.x, r.y - animal.y) <= 1.0) {
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
    if (nest.species === 'harpy' || nest.isSocialColony || ['ant', 'termite', 'bee'].includes(nest.species)) {
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
    stepVegetationAndBiomass,
    stepFlora,
    applyDeathDecomposition,
    initNaturalRefuges,
    findLocalNestLocation,
    isProtectedInBurrowOrRefuge,
    updateNestLifecycles
  };
  window.stepThermodynamics = stepThermodynamics;
  window.stepHydrologyAndErosion = stepHydrologyAndErosion;
  window.stepVegetationAndBiomass = stepVegetationAndBiomass;
  window.stepFlora = stepFlora;
  window.applyDeathDecomposition = applyDeathDecomposition;
  window.initNaturalRefuges = initNaturalRefuges;
  window.findLocalNestLocation = findLocalNestLocation;
  window.isProtectedInBurrowOrRefuge = isProtectedInBurrowOrRefuge;
  window.updateNestLifecycles = updateNestLifecycles;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    stepThermodynamics,
    stepHydrologyAndErosion,
    stepVegetationAndBiomass,
    stepFlora,
    applyDeathDecomposition,
    initNaturalRefuges,
    findLocalNestLocation,
    isProtectedInBurrowOrRefuge,
    updateNestLifecycles
  };
}
