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
 * Regeneração Biológica de Flora e Grãos de Várzea (Dados Reais da Amazônia / Oeste do Pará)
 * - Ponto Ótimo Fotossintético Tropical (T_opt): 28.5°C (curva biológica real C3/C4).
 * - Gramíneas e Macrófitas de Várzea (Paspalum repens / Echinochloa polystachya): Altíssima produtividade primária (NPP), rebrota rápida pós-pastagem e saturação em 45-60.
 * - Arroz Selvagem de Várzea (Oryza glumaepatula): Floresce em solos úmidos (m > 0.35) e água rasa (<= 0.25m), acumulando até 60-80 kg/m² quando a planta atinge porte vegetativo.
 * - Floresta de Terra Firme: Dossel denso com alta capacidade de suporte (85 a 100) e estabilidade frente a estiagens moderadas.
 * - Evapotranspiração: Vegetação transcreve umidade para a atmosfera conforme taxa de crescimento e biomassa.
 */
function stepFlora(dt) {
  // Amostragem ampliada para 2048 células por tick para manter o recobrimento uniforme da grade 512x512
  const sampleCount = 2048;
  const OPTIMAL_TEMP = 28.5; // Média térmica ótima da Amazônia (26°C a 31°C)
  const TEMP_WINDOW = 11.0;   // Janela fotossintética ativa [17.5°C .. 39.5°C]

  for (let i = 0; i < sampleCount; i++) {
    const rx = Math.floor(Math.random() * CHUNK_SIZE);
    const ry = Math.floor(Math.random() * CHUNK_SIZE);
    const idx = getIdx(rx, ry);

    if (matId[idx] === MAT_WATER || matId[idx] === MAT_ICE) continue;

    const t = temp[idx];
    const m = moisture[idx];
    const curBio = biomass[idx];
    const wDepth = surfaceWater[idx];

    // Condições fisiológicas para fotossíntese e crescimento:
    // Temperatura entre 12°C e 42°C e umidade do solo acima do ponto de murcha permanente (> 0.08)
    if (t >= 12.0 && t <= 42.0 && m > 0.08) {
      // Eficiência fotossintética com declínio mais acentuado acima de 34°C por estresse térmico/VPD
      let tempEff;
      if (t <= OPTIMAL_TEMP) {
        tempEff = 1.0 - Math.pow((OPTIMAL_TEMP - t) / TEMP_WINDOW, 1.6);
      } else {
        tempEff = 1.0 - Math.pow((t - OPTIMAL_TEMP) / (42.0 - OPTIMAL_TEMP), 1.8);
      }
      tempEff = Math.max(0.08, Math.min(1.0, tempEff));

      let targetMaxBiomass = 100.0;
      let baseGrowthRate = 4.2; // Taxa vigorosa típica da produtividade primária líquida amazônica

      if (currentScenario === 'amazon') {
        const distCenter = Math.hypot(rx - 256.0, ry - 256.0);

        if (distCenter >= 48.0 && distCenter <= 145.0) {
          // ZONA 1: VÁRZEA ALAGÁVEL E GRAMÍNEAS C4 (Paspalum / Echinochloa)
          targetMaxBiomass = 55.0;
          baseGrowthRate = 6.8; // Rebrota rápida pós-pastagem dos herbívoros

          // DINÂMICA DE GRÃOS DE ARROZ SELVAGEM (Oryza glumaepatula)
          if (m > 0.35 && wDepth <= 0.25 && curBio >= 12.0) {
            const currentG = grains[idx] || 0.0;
            const maxGrainCap = 80.0;
            const grainMaturityFactor = Math.min(1.0, curBio / 35.0);
            const grainGrowth = 0.32 * dt * m * tempEff * grainMaturityFactor * (1.0 - currentG / maxGrainCap);
            grains[idx] = Math.min(maxGrainCap, currentG + Math.max(0, grainGrowth));
          } else if (wDepth > 0.60 || m < 0.20) {
            if (grains[idx] > 0) grains[idx] = Math.max(0, grains[idx] - 0.25 * dt);
          }
        } else if (distCenter > 145.0 && rx >= 150 && rx <= 465) {
          // ZONA 2: FLORESTA TROPICAL DENSA DE TERRA FIRME (Dossel Fechado)
          targetMaxBiomass = 95.0;
          baseGrowthRate = 3.6;
        } else if (rx < 150) {
          // ZONA 3: SERRA OCIDENTAL ELEVADA (Transição Montana até 550m)
          targetMaxBiomass = 65.0;
          baseGrowthRate = 2.8;
        }
      }

      // Crescimento Logístico Sigmoidal: dM/dt = r * M * (1 - M / K)
      const capacityFactor = Math.max(0.15, 1.0 - (curBio / targetMaxBiomass));
      const moistureFactor = Math.min(1.0, Math.pow(m, 0.8));
      const actualGrowth = baseGrowthRate * tempEff * moistureFactor * capacityFactor * dt;

      biomass[idx] = Math.min(targetMaxBiomass, Math.max(0, curBio + actualGrowth));

      // Evapotranspiração: Vegetação absorve umidade do solo durante a fotossíntese
      const transpiration = actualGrowth * 0.04;
      moisture[idx] = Math.max(0.02, m - transpiration);

    } else if (t < 5.0 || t > 43.0 || m < 0.06) {
      // Degradação e dessecação por estresse térmico letal, geada ou seca extrema
      const decay = (t < 5.0 ? 1.8 : (t > 43.0 ? 2.5 : 0.8)) * dt;
      biomass[idx] = Math.max(0, curBio - decay);
      if (grains[idx] > 0) grains[idx] = Math.max(0, grains[idx] - decay * 0.5);
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
 * - Exatamente 8 refúgios na zona de grama (várzea)
 * - Abrigos expandidos na borda da floresta (transição ecotonal) e interior
 * - Raio de proteção reduzido para 1.0 metro
 */
function initNaturalRefuges(initialRatCount = 180) {
  naturalRefuges = [];
  let nextId = 1;

  const refugeZones = [
    { count: 8, minR: 56.0, maxR: 138.0, desc: 'grama_varzea' },       // 8 na zona de grama
    { count: 20, minR: 140.0, maxR: 200.0, desc: 'borda_floresta' },  // Espalhados na borda da floresta
    { count: 12, minR: 202.0, maxR: 245.0, desc: 'interior_floresta' } // Interior da floresta de terra firme
  ];

  for (const zone of refugeZones) {
    for (let i = 0; i < zone.count; i++) {
      for (let attempt = 0; attempt < 50; attempt++) {
        let rx, ry;
        if (currentScenario === 'amazon') {
          const angle = Math.random() * Math.PI * 2;
          const r = zone.minR + Math.random() * (zone.maxR - zone.minR);
          rx = 256.0 + Math.cos(angle) * r;
          ry = 256.0 + Math.sin(angle) * r;
        } else {
          rx = 25 + Math.random() * (CHUNK_SIZE - 50);
          ry = 25 + Math.random() * (CHUNK_SIZE - 50);
        }
        rx = Math.max(8, Math.min(CHUNK_SIZE - 8, rx));
        ry = Math.max(8, Math.min(CHUNK_SIZE - 8, ry));
        const idx = getIdx(Math.floor(rx), Math.floor(ry));

        if (matId[idx] !== MAT_WATER && surfaceWater[idx] < 0.15) {
          const typeRoll = Math.random();
          const type = typeRoll < 0.40 ? 'log' : (typeRoll < 0.75 ? 'rock' : 'brush');
          naturalRefuges.push({
            id: nextId++,
            x: rx,
            y: ry,
            type: type,
            zone: zone.desc,
            radius: 1.0 // Raio reduzido estritamente para 1m
          });
          clearBiomassRadius(rx, ry, 1.5); // Limpeza suave de 1.5m para manter alimento acessível próximo
          break;
        }
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
 * Imunidade de Predação em Tocas, Covis e Refúgios Naturais (Raio de 1m)
 */
function isProtectedInBurrowOrRefuge(animal) {
  // 1. Toca própria
  if (animal.hasNest && Math.hypot(animal.x - animal.nestX, animal.y - animal.nestY) <= 1.2) {
    return true;
  }
  // 2. Qualquer toca da mesma espécie
  for (let ni = 0; ni < nests.length; ni++) {
    const n = nests[ni];
    if (n.species === animal.species && Math.hypot(n.x - animal.x, n.y - animal.y) <= 1.2) {
      return true;
    }
  }
  // 3. Refúgio Natural (roedores) - área estrita de 1m
  if (animal.species === 'rat') {
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
