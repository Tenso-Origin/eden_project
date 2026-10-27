// =========================================================================
// MÓDULO UI: CONTROLE DE CÂMERA, INTERAÇÃO, INSPEÇÃO E TELEMETRIA
// =========================================================================

const MIN_ZOOM = 0.40;
const MAX_ZOOM = 8.0;

function clampPan() {
  if (zoomLevel <= 1.0) {
    panX = 256.0;
    panY = 256.0;
  } else {
    const halfW = 256.0 / zoomLevel;
    const halfH = 256.0 / zoomLevel;
    panX = Math.max(halfW, Math.min(CHUNK_SIZE - halfW, panX));
    panY = Math.max(halfH, Math.min(CHUNK_SIZE - halfH, panY));
  }
}

function setZoom(newZoom, centerX = panX, centerY = panY) {
  const oldZoom = zoomLevel;
  zoomLevel = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, newZoom));

  if (zoomLevel <= 1.0) {
    panX = 256.0;
    panY = 256.0;
  } else if (oldZoom !== zoomLevel) {
    panX = centerX;
    panY = centerY;
    clampPan();
  }

  const lbl = document.getElementById('lblZoomLevel');
  if (lbl) lbl.innerText = `${zoomLevel.toFixed(1)}x`;
  render();
}

function movePan(dx, dy) {
  const step = 42.0 / zoomLevel;
  panX += dx * step;
  panY += dy * step;
  clampPan();
  const lbl = document.getElementById('lblZoomLevel');
  if (lbl) lbl.innerText = `${zoomLevel.toFixed(1)}x`;
  render();
}

function resetCamera() {
  zoomLevel = 1.0;
  panX = 256.0;
  panY = 256.0;
  const lbl = document.getElementById('lblZoomLevel');
  if (lbl) lbl.innerText = `1.0x`;
  render();
}

function getCanvasCoordinates(clientX, clientY) {
  const canvasElem = document.getElementById('viewportCanvas');
  const rect = canvasElem.getBoundingClientRect();
  const elemAspect = rect.width / rect.height;
  let renderedW, renderedH, offsetX, offsetY;

  if (elemAspect >= 1.0) {
    renderedW = rect.width;
    renderedH = rect.width;
    offsetX = 0;
    offsetY = (rect.height - renderedH) / 2;
  } else {
    renderedH = rect.height;
    renderedW = rect.height;
    offsetX = (rect.width - renderedW) / 2;
    offsetY = 0;
  }

  const canvasX = (clientX - rect.left - offsetX) * (canvasElem.width / renderedW);
  const canvasY = (clientY - rect.top - offsetY) * (canvasElem.height / renderedH);
  return { canvasX, canvasY };
}

function screenToWorld(clientX, clientY) {
  const canvasElem = document.getElementById('viewportCanvas');
  const { canvasX, canvasY } = getCanvasCoordinates(clientX, clientY);
  const wx = (canvasX - canvasElem.width / 2) / zoomLevel + panX;
  const wy = (canvasY - canvasElem.height / 2) / zoomLevel + panY;
  return {
    x: Math.max(0, Math.min(CHUNK_SIZE - 1, Math.floor(wx))),
    y: Math.max(0, Math.min(CHUNK_SIZE - 1, Math.floor(wy)))
  };
}

function inspectCell(x, y) {
  if (x < 0 || x >= CHUNK_SIZE || y < 0 || y >= CHUNK_SIZE) return;
  const idx = getIdx(x, y);

  const elCoord = document.getElementById('inspCoord');
  if (elCoord) elCoord.innerText = `(X: ${x}, Y: ${y})`;

  let region = "Planalto Continental";
  if (currentScenario === 'amazon') {
    const distCenter = Math.hypot(x - 256, y - 256);
    if (distCenter <= 36.0) region = "Lago de Várzea Central (~4.000m²)";
    else if (distCenter <= 86.0) region = "Faixa de Gramíneas de Várzea (50m - Zona da Harpia)";
    else if (x < 150) region = "Serra Ocidental Elevada (550m)";
    else if (x > 465) region = "Delta / Mar Estuarino Leste";
    else region = "Floresta Equatorial de Terra Firme";
  } else {
    if (x <= 25 && y <= 25 && Math.hypot(x, y) <= 20) region = "Maciço Montanhoso NW (2km)";
    else if (x >= 486 && y >= 486 && Math.hypot(511 - x, 511 - y) <= 20) region = "Oceano / Fossa Abissal SE (-100m)";
    else if (Math.abs(y - 255.5) <= 4) region = "Linha do Equador";
    else if (y < 80) region = "Planície Boreal (Norte)";
    else if (y > 430) region = "Planície Austral (Sul)";
  }
  const elReg = document.getElementById('inspRegion');
  if (elReg) elReg.innerText = region;

  const elMat = document.getElementById('inspMat');
  if (elMat) elMat.innerText = MATERIALS[matId[idx]]?.name || "Desconhecido";
  const elElev = document.getElementById('inspElev');
  if (elElev) elElev.innerText = elevation[idx].toFixed(1) + " m";
  const elTemp = document.getElementById('inspTemp');
  if (elTemp) elTemp.innerText = temp[idx].toFixed(1) + "°C";
  const elWater = document.getElementById('inspWater');
  if (elWater) elWater.innerText = surfaceWater[idx].toFixed(1) + " mm";
  const elMoist = document.getElementById('inspMoist');
  if (elMoist) elMoist.innerText = (moisture[idx] * 100).toFixed(1) + "%";
  const elBio = document.getElementById('inspBio');
  if (elBio) elBio.innerText = biomass[idx].toFixed(1);

  const elGrains = document.getElementById('inspGrains');
  if (elGrains) elGrains.innerText = (grains[idx] || 0.0).toFixed(1) + " kg/m²";
  const elNest = document.getElementById('inspNest');
  if (elNest) {
    const nestHere = nests.find(n => Math.hypot(n.x - x, n.y - y) < 4.0);
    elNest.innerText = nestHere ? `${nestHere.name} (${nestHere.species})` : "Nenhum";
  }
  const elEroded = document.getElementById('inspEroded');
  if (elEroded) elEroded.innerText = cumulativeErosion[idx].toFixed(2) + " m";

  // Telemetria detalhada de animais próximos
  const nearbyAnimals = animals.filter(a => Math.hypot(a.x - x, a.y - y) < 2.0);
  const elFauna = document.getElementById('inspFauna');
  if (elFauna) {
    if (nearbyAnimals.length > 0) {
      const names = nearbyAnimals.map(a => {
        const sp = (a.species === 'rat') ? '🐁 Rato' : '🐈 Gato';
        const sx = (a.sex === 'female') ? '♀' : '♂';
        let estrusStr = '';
        if (a.sex === 'female') {
          if (a.isPregnant) estrusStr = ` [Prenhe: ${a.gestationRemaining.toFixed(1)}d rest., Ninhada: ${a.litterSize}]`;
          else if (a.estrusDurationRemaining > 0) estrusStr = ` 🔥[EM CIO: ${a.estrusDurationRemaining.toFixed(1)}d]`;
          else estrusStr = ` [Cio em ${(a.estrusCycleTimer || 0).toFixed(1)}d]`;
        }
        const genStr = a.genome ? ` [G${a.genome.generation}]` : (a.catGenome ? ` [G${a.catGenome.generation}]` : '');
        const hpStr = ` HP:${Math.max(0, a.hp).toFixed(0)}`;
        const stamStr = a.stamina !== undefined ? ` St:${a.stamina.toFixed(0)}` : '';
        const atkDefStr = ` Atk:${a.attackPower || 10}/Def:${a.defensePower || 3}`;
        const tagStr = `${a.isCornered ? ' ⚠️ACUADO' : ''}${a.isExhausted ? ' 💨EXAUSTO' : ''}${a.isDiving ? ' 🤿MERGULHADO' : ''}${a.isSleeping ? ' 💤DORMINDO' : ''}`;
        const thirstStr = ` Th:${(a.thirst || 0).toFixed(0)}%`;
        const fatigueStr = ` Slp:${(a.fatigue || 0).toFixed(0)}%`;
        return `${sp} ${sx}${estrusStr}${genStr}${hpStr}${stamStr}${thirstStr}${fatigueStr}${atkDefStr}${tagStr} (Idade: ${a.ageInDays.toFixed(0)}d, Fome: ${a.hunger.toFixed(0)}%)`;
      }).join(', ');
      elFauna.innerText = names;
    } else {
      elFauna.innerText = "Nenhum";
    }
  }
}

function handleCanvasInteraction(e) {
  const coord = screenToWorld(e.clientX, e.clientY);
  const x = coord.x;
  const y = coord.y;
  const idx = getIdx(x, y);

  if (currentBrush === 'inspect') {
    inspectCell(x, y);
  } else if (currentBrush === 'water') {
    surfaceWater[idx] += 15.0;
    moisture[idx] = 1.0;
  } else if (currentBrush === 'rain') {
    for (let dy = -6; dy <= 6; dy++) {
      for (let dx = -6; dx <= 6; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && nx < CHUNK_SIZE && ny >= 0 && ny < CHUNK_SIZE) {
          surfaceWater[getIdx(nx, ny)] += 5.0;
        }
      }
    }
  } else if (currentBrush === 'rat') {
    const sex = (Math.random() < 0.50) ? 'male' : 'female';
    animals.push({
      id: Date.now() + Math.random(),
      species: 'rat',
      diet: 'herbivore',
      sex: sex,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      estrusCycleTimer: (sex === 'female' ? Math.random() * 4.5 : 0),
      estrusDurationRemaining: 0,
      x: x + 0.5,
      y: y + 0.5,
      hasNest: true,
      nestX: x + 0.5,
      nestY: y + 0.5,
      hp: 100,
      stamina: 100.0,
      maxStamina: 100.0,
      isExhausted: false,
      attackPower: 10.0,
      defensePower: 3.0,
      isCornered: false,
      hunger: 20,
      thirst: 5.0,
      fatigue: 0.0,
      isSleeping: false,
      breath: 7.0,
      maxBreath: 7.0,
      isDiving: false,
      speed: 2.2,
      ageInDays: 75.0,
      maxLifespan: 912.5,
      matingCooldown: 15.0,
      sensoryRadius: 5,
      dailyFunKills: 0,
      genome: (typeof RatSpecies !== 'undefined') ? RatSpecies.createDefaultRatGenome() : {
        alertRadius: 12.0, refugeAffinity: 0.45, sprintBurst: 1.35, epigeneticBonus: 0.0, memoryRetention: 0.70, generation: 0
      },
      mateGenome: null
    });
  } else if (currentBrush === 'cat') {
    const sex = (Math.random() < 0.51) ? 'male' : 'female';
    animals.push({
      id: Date.now() + Math.random(),
      species: 'cat',
      diet: 'carnivore',
      sex: sex,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      estrusCycleTimer: (sex === 'female' ? Math.random() * 18.0 : 0),
      estrusDurationRemaining: 0,
      x: x + 0.5,
      y: y + 0.5,
      hasNest: true,
      nestX: x + 0.5,
      nestY: y + 0.5,
      hp: 100,
      stamina: 100.0,
      maxStamina: 100.0,
      isExhausted: false,
      attackPower: 42.0,
      defensePower: 14.0,
      isCornered: false,
      hunger: 10,
      thirst: 5.0,
      fatigue: 0.0,
      isSleeping: false,
      breath: 0.0,
      maxBreath: 0.0,
      isDiving: false,
      speed: 2.8,
      ageInDays: 400.0,
      maxLifespan: 5110.0,
      matingCooldown: 40.0,
      sensoryRadius: 15,
      dailyFunKills: 0,
      catGenome: (typeof CatSpecies !== 'undefined') ? CatSpecies.createDefaultCatGenome() : null,
      mateCatGenome: null
    });
  } else if (currentBrush === 'plant') {
    for (let dy = -4; dy <= 4; dy++) {
      for (let dx = -4; dx <= 4; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && nx < CHUNK_SIZE && ny >= 0 && ny < CHUNK_SIZE) {
          biomass[getIdx(nx, ny)] = Math.min(100, biomass[getIdx(nx, ny)] + 50);
        }
      }
    }
  } else if (currentBrush === 'elevate') {
    elevation[idx] += 5.0;
  } else if (currentBrush === 'erode') {
    elevation[idx] = Math.max(-100, elevation[idx] - 5.0);
    cumulativeErosion[idx] += 5.0;
  } else if (currentBrush === 'heat') {
    temp[idx] = Math.min(120, temp[idx] + 25);
  }

  inspectCell(x, y);
  render();
}

function updateStats() {
  const elTicks = document.getElementById('statTicks');
  if (elTicks) elTicks.innerText = tickCount;

  const simDate = getSimDate(totalSimHours);
  const elDateBadge = document.getElementById('dateBadge');
  if (elDateBadge) elDateBadge.innerText = `📅 ${simDate.fullStr}`;
  const elStatDate = document.getElementById('statDate');
  if (elStatDate) elStatDate.innerText = simDate.fullStr;

  const hrs = Math.floor(timeOfDay);
  const mins = Math.floor((timeOfDay - hrs) * 60);
  const timeStr = `${hrs.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}h`;
  const elStatHour = document.getElementById('statHour');
  if (elStatHour) elStatHour.innerText = timeStr;

  const sunH = Math.sin(((timeOfDay - 6.0) / 12.0) * Math.PI);
  const isDay = sunH > 0;
  const weatherStr = weather.isRaining 
    ? `🌧️ Chuva Frente (${weather.timerHours.toFixed(1)}h | ${(weather.intensity).toFixed(1)}mm/s)` 
    : `🌤️ Céu Aberto (${weather.timerHours.toFixed(1)}h)`;
  const elSolar = document.getElementById('solarBadge');
  if (elSolar) elSolar.innerText = `${isDay ? '☀️' : '🌙'} ${timeStr} | ${weatherStr}`;

  const elAvgTemp = document.getElementById('statAvgTemp');
  if (elAvgTemp) elAvgTemp.innerText = temp[getIdx(256, 256)].toFixed(1) + "°C";
  const elErosion = document.getElementById('statErosion');
  if (elErosion) elErosion.innerText = (globalErosionTotal * 12.5).toFixed(1) + " m³";

  // Harpias Amazônicas
  const elHarpies = document.getElementById('statHarpies');
  if (elHarpies) {
    if (currentScenario === 'amazon' && harpies.length >= 2) {
      const hM = harpies[0], hF = harpies[1];
      const isNight = !isDay;
      const formatHarpyState = (h) => {
        if (h.migrated) return '🍃Dispersa';
        if (h.state === 'dive') return '⚡Mergulho';
        if (h.state === 'retreat') return isNight ? '🌙Retorno Noturno' : '🚨Fuga p/ Ninho';
        if (h.state === 'nest_resting') return isNight ? '😴Dormindo no Ninho' : '🪺Repouso (HP)';
        return '🦅Patrulha Diurna';
      };
      const stM = formatHarpyState(hM);
      const stF = formatHarpyState(hF);
      const activeCount = (!hM.migrated ? 1 : 0) + (!hF.migrated ? 1 : 0);
      if (activeCount === 0) {
        elHarpies.innerText = `🍃 Dispersas (Biomassa Saudável > 50%)`;
      } else {
        elHarpies.innerText = `🦅 ${activeCount}/2 Ativas (Biomassa < 50%) | ♂ ${stM} | ♀ ${stF}`;
      }
    } else {
      elHarpies.innerText = "Inativo neste bioma";
    }
  }

  // Grãos de Arroz
  const elGrains = document.getElementById('statGrains');
  if (elGrains) {
    let totalG = 0;
    for (let i = 0; i < CELL_COUNT; i += 8) totalG += grains[i];
    elGrains.innerText = `${Math.round(totalG * 8)} kg`;
  }

  // Ninhos
  const elNests = document.getElementById('statNests');
  if (elNests) {
    const ratN = nests.filter(n => n.species === 'rat').length;
    const catN = nests.filter(n => n.species === 'cat').length;
    const harpyN = harpies.filter(h => !h.migrated).length;
    elNests.innerText = `${nests.length} (${ratN} tocas, ${catN} covis, ${harpyN} harpia ativa)`;
  }

  // Censo de Fauna
  const rats = animals.filter(a => a.species === 'rat');
  const ratsF = rats.filter(a => a.sex === 'female').length;
  const ratsM = rats.filter(a => a.sex === 'male').length;
  const pregRats = rats.filter(a => a.isPregnant).length;
  const estrusRats = rats.filter(a => a.sex === 'female' && a.estrusDurationRemaining > 0).length;

  const cats = animals.filter(a => a.species === 'cat');
  const catsF = cats.filter(a => a.sex === 'female').length;
  const catsM = cats.filter(a => a.sex === 'male').length;
  const pregCats = cats.filter(a => a.isPregnant).length;
  const estrusCats = cats.filter(a => a.sex === 'female' && a.estrusDurationRemaining > 0).length;

  const elRats = document.getElementById('statRats');
  if (elRats) elRats.innerText = `${rats.length} (♀${ratsF} | ♂${ratsM})`;
  const elCats = document.getElementById('statCats');
  if (elCats) elCats.innerText = `${cats.length} (♀${catsF} | ♂${catsM})`;
  const elPreg = document.getElementById('statPregnant');
  if (elPreg) elPreg.innerText = `${pregRats} ratas prenhes (${estrusRats} em cio) | ${pregCats} gatas prenhes (${estrusCats} em cio)`;

  const elPeak = document.getElementById('statPeak');
  if (elPeak) elPeak.innerText = elevation[getIdx(0, 0)].toFixed(1) + " m";
  const elAbyss = document.getElementById('statAbyss');
  if (elAbyss) elAbyss.innerText = elevation[getIdx(511, 511)].toFixed(1) + " m";

  // 1. Homeostase Ecológica e Razão Predador-Presa (Lotka-Volterra)
  const elHomeoVal = document.getElementById('lblHomeostasisVal');
  const elRatio = document.getElementById('lblPredPreyRatio');
  const aliveRatsCount = rats.length;
  const aliveCatsCount = cats.length;
  const curRatio = (aliveCatsCount > 0) ? (aliveRatsCount / aliveCatsCount) : 0;

  let homeoScore = 95.0;
  if (aliveRatsCount === 0 || aliveCatsCount === 0) {
    homeoScore = 0.0;
  } else {
    let penalty = 0.0;
    if (curRatio < 1.5) penalty = (1.5 - curRatio) * 18.0;
    else if (curRatio > 12.0) penalty = Math.min(35.0, (curRatio - 12.0) * 1.8);
    if (aliveRatsCount < 60) penalty += (60 - aliveRatsCount) * 0.75;
    homeoScore = Math.max(10.0, Math.min(100.0, 98.0 - penalty));
  }

  if (elHomeoVal) {
    let statusLabel = "Equilíbrio Sustentável";
    let statusColor = "#3fb950";
    if (homeoScore < 75.0) {
      statusLabel = "Crise Severa / Dispersão";
      statusColor = "#f85149";
    } else if (homeoScore < 85.0) {
      statusLabel = "Alerta Trófico";
      statusColor = "#d29922";
    }
    elHomeoVal.innerText = `${homeoScore.toFixed(1)}% (${statusLabel})`;
    elHomeoVal.style.color = statusColor;
  }

  if (elRatio) {
    elRatio.innerText = `Razão ${curRatio.toFixed(1)}:1`;
  }

  // 2. Média genética dos Roedores (Bases Adaptativas)
  if (rats.length > 0) {
    let sumAlert = 0, sumRefuge = 0, sumSprint = 0, sumGen = 0;
    for (const r of rats) {
      if (r.genome) {
        sumAlert += r.genome.alertRadius + (r.genome.epigeneticBonus || 0);
        sumRefuge += r.genome.refugeAffinity;
        sumSprint += r.genome.sprintBurst;
        sumGen += r.genome.generation;
      }
    }
    const n = rats.length;
    const elAvgGen = document.getElementById('lblAvgGen');
    if (elAvgGen) elAvgGen.innerText = `G${(sumGen / n).toFixed(1)}`;
    const elAvgAlert = document.getElementById('lblAvgAlert');
    if (elAvgAlert) elAvgAlert.innerText = `${(sumAlert / n).toFixed(1)}c`;
    const elAvgRefuge = document.getElementById('lblAvgRefuge');
    if (elAvgRefuge) elAvgRefuge.innerText = `${((sumRefuge / n) * 100).toFixed(0)}%`;
  }

  // 3. Média genética dos Felinos (DNA Herdável & Combate)
  if (cats.length > 0) {
    let sumVig = 0, sumFer = 0, sumStam = 0, sumCatGen = 0;
    for (const c of cats) {
      if (c.catGenome) {
        sumVig += c.catGenome.harpyVigilance;
        sumFer += c.catGenome.combatFerocity;
        sumStam += c.catGenome.staminaEfficiency;
        sumCatGen += (c.catGenome.generation || 0);
      }
    }
    const nc = cats.length;
    const elCatGen = document.getElementById('lblCatGen');
    if (elCatGen) elCatGen.innerText = `G${(sumCatGen / nc).toFixed(1)}`;
    const elCatVig = document.getElementById('lblCatVigilance');
    if (elCatVig) elCatVig.innerText = `${(sumVig / nc).toFixed(2)}x`;
    const elCatFer = document.getElementById('lblCatFerocity');
    if (elCatFer) elCatFer.innerText = `${(sumFer / nc).toFixed(2)}x`;
    const elCatStam = document.getElementById('lblCatStamina');
    if (elCatStam) elCatStam.innerText = `${(sumStam / nc).toFixed(2)}x`;
  }

  // 4. Contadores de Nascimentos e Mortes
  const elBirths = document.getElementById('statBirths');
  if (elBirths && typeof totalBirthsCount !== 'undefined') elBirths.innerText = totalBirthsCount;
  const elPred = document.getElementById('statPredDeaths');
  if (elPred && typeof totalPredationDeaths !== 'undefined') elPred.innerText = totalPredationDeaths;
  const elStarv = document.getElementById('statStarvDeaths');
  if (elStarv && typeof totalStarvationDeaths !== 'undefined') elStarv.innerText = totalStarvationDeaths;
  const elThirst = document.getElementById('statThirstDeaths');
  if (elThirst && typeof totalThirstDeaths !== 'undefined') elThirst.innerText = totalThirstDeaths;
}

function setRatsUI(val) {
  const ratsInput = document.getElementById('initRatsInput');
  const ratsSlider = document.getElementById('initRatsSlider');
  const lblRatsVal = document.getElementById('lblRatsVal');
  if (ratsInput) ratsInput.value = val;
  if (ratsSlider) ratsSlider.value = val;
  if (lblRatsVal) lblRatsVal.innerText = val;
}

function setCatsUI(val) {
  const catsInput = document.getElementById('initCatsInput');
  const catsSlider = document.getElementById('initCatsSlider');
  const lblCatsVal = document.getElementById('lblCatsVal');
  if (catsInput) catsInput.value = val;
  if (catsSlider) catsSlider.value = val;
  if (lblCatsVal) lblCatsVal.innerText = val;
}

/**
 * Inicialização dos Event Listeners de Botões, Sliders e Canvas
 */
function initUI() {
  const canvasElem = document.getElementById('viewportCanvas');
  if (!canvasElem) return;

  // Zoom
  const btnZIn = document.getElementById('btnZoomIn');
  if (btnZIn) btnZIn.addEventListener('click', () => setZoom(zoomLevel * 1.35));
  const btnZOut = document.getElementById('btnZoomOut');
  if (btnZOut) btnZOut.addEventListener('click', () => setZoom(zoomLevel / 1.35));
  const btnZReset = document.getElementById('btnResetZoom');
  if (btnZReset) btnZReset.addEventListener('click', resetCamera);

  // D-Pad
  const btnNavU = document.getElementById('btnNavUp');
  if (btnNavU) btnNavU.addEventListener('click', () => movePan(0, -1));
  const btnNavD = document.getElementById('btnNavDown');
  if (btnNavD) btnNavD.addEventListener('click', () => movePan(0, 1));
  const btnNavL = document.getElementById('btnNavLeft');
  if (btnNavL) btnNavL.addEventListener('click', () => movePan(-1, 0));
  const btnNavR = document.getElementById('btnNavRight');
  if (btnNavR) btnNavR.addEventListener('click', () => movePan(1, 0));
  const btnNavC = document.getElementById('btnNavCenter');
  if (btnNavC) btnNavC.addEventListener('click', resetCamera);

  // Overlay
  const btnOverU = document.getElementById('btnOverlayUp');
  if (btnOverU) btnOverU.addEventListener('click', (e) => { e.stopPropagation(); movePan(0, -1); });
  const btnOverD = document.getElementById('btnOverlayDown');
  if (btnOverD) btnOverD.addEventListener('click', (e) => { e.stopPropagation(); movePan(0, 1); });
  const btnOverL = document.getElementById('btnOverlayLeft');
  if (btnOverL) btnOverL.addEventListener('click', (e) => { e.stopPropagation(); movePan(-1, 0); });
  const btnOverR = document.getElementById('btnOverlayRight');
  if (btnOverR) btnOverR.addEventListener('click', (e) => { e.stopPropagation(); movePan(1, 0); });
  const btnOverC = document.getElementById('btnOverlayCenter');
  if (btnOverC) btnOverC.addEventListener('click', (e) => { e.stopPropagation(); resetCamera(); });

  // Teclado
  window.addEventListener('keydown', (e) => {
    const tag = (document.activeElement && document.activeElement.tagName) ? document.activeElement.tagName.toLowerCase() : '';
    if (tag === 'input' || tag === 'select' || tag === 'textarea') return;

    if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') {
      e.preventDefault(); movePan(0, -1);
    } else if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
      e.preventDefault(); movePan(0, 1);
    } else if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') {
      e.preventDefault(); movePan(-1, 0);
    } else if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') {
      e.preventDefault(); movePan(1, 0);
    } else if (e.key === ' ' || e.key === 'Home') {
      e.preventDefault(); resetCamera();
    } else if (e.key === '+' || e.key === '=') {
      e.preventDefault(); setZoom(zoomLevel * 1.35);
    } else if (e.key === '-' || e.key === '_') {
      e.preventDefault(); setZoom(zoomLevel / 1.35);
    }
  });

  // Wheel Zoom
  canvasElem.addEventListener('wheel', (e) => {
    e.preventDefault();
    const { canvasX: mouseCanvasX, canvasY: mouseCanvasY } = getCanvasCoordinates(e.clientX, e.clientY);
    const worldX = (mouseCanvasX - canvasElem.width / 2) / zoomLevel + panX;
    const worldY = (mouseCanvasY - canvasElem.height / 2) / zoomLevel + panY;

    const zoomFactor = (e.deltaY < 0) ? 1.25 : (1.0 / 1.25);
    const targetZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoomLevel * zoomFactor));

    if (targetZoom <= 1.0) {
      setZoom(targetZoom);
    } else {
      const newPanX = worldX - (mouseCanvasX - canvasElem.width / 2) / targetZoom;
      const newPanY = worldY - (mouseCanvasY - canvasElem.height / 2) / targetZoom;
      setZoom(targetZoom, newPanX, newPanY);
    }
  }, { passive: false });

  // Mouse Pan & Interações
  let isMouseDown = false;
  let isDraggingPan = false;
  let lastMouseX = 0, lastMouseY = 0;
  let mouseMovedDist = 0;

  canvasElem.addEventListener('mousedown', (e) => {
    isMouseDown = true;
    isDraggingPan = (e.button === 2 || e.shiftKey || currentBrush === 'inspect');
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
    mouseMovedDist = 0;
    if (!isDraggingPan) handleCanvasInteraction(e);
  });

  window.addEventListener('mouseup', (e) => {
    if (isMouseDown && currentBrush === 'inspect' && mouseMovedDist < 6) {
      handleCanvasInteraction(e);
    }
    isMouseDown = false;
    isDraggingPan = false;
  });

  canvasElem.addEventListener('mousemove', (e) => {
    if (isMouseDown) {
      const dx = e.clientX - lastMouseX;
      const dy = e.clientY - lastMouseY;
      mouseMovedDist += Math.abs(dx) + Math.abs(dy);
      lastMouseX = e.clientX;
      lastMouseY = e.clientY;

      if (isDraggingPan || e.buttons === 2 || e.shiftKey || (currentBrush === 'inspect' && mouseMovedDist > 5)) {
        panX -= dx / zoomLevel;
        panY -= dy / zoomLevel;
        clampPan();
        render();
      } else {
        handleCanvasInteraction(e);
      }
    }
  });

  canvasElem.addEventListener('contextmenu', (e) => e.preventDefault());

  // Cenário
  const scenarioSelect = document.getElementById('scenarioSelect');
  if (scenarioSelect) {
    scenarioSelect.addEventListener('change', () => {
      currentScenario = scenarioSelect.value;
      initWorld();
      tickCount = 0;
      totalSimHours = 0;
      timeOfDay = 12.0;
      updateStats();
      render();
    });
  }

  // Camadas
  document.querySelectorAll('.layer-btn').forEach(btn => {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.layer-btn').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      currentLayer = this.dataset.layer;

      const info = document.getElementById('layerInfo');
      const grad = document.getElementById('legendGradient');
      const minL = document.getElementById('legendMin');
      const maxL = document.getElementById('legendMax');

      if (currentLayer === 'temp') {
        if (info) info.innerText = "Modo: Gradiente Altimétrico Adiabático (-6.5°C/km) e Ciclo Solar (-15°C a +45°C)";
        if (grad) grad.style.background = "linear-gradient(to right, #0044ff, #00ddff, #00ff66, #ffcc00, #ff2200)";
        if (minL) minL.innerText = "-15°C"; if (maxL) maxL.innerText = "+45°C";
      } else if (currentLayer === 'moisture') {
        if (info) info.innerText = "Modo: Hidrologia e Escoamento Superficial (Infiltração por Permeabilidade)";
        if (grad) grad.style.background = "linear-gradient(to right, #0a1422, #184880, #2080dd, #00eeff)";
        if (minL) minL.innerText = "Seco (0%)"; if (maxL) maxL.innerText = "Lâmina Livre";
      } else if (currentLayer === 'erosion') {
        if (info) info.innerText = "Modo: Topografia (-100m a +2000m) e Ravinas de Erosão Fluvial";
        if (grad) grad.style.background = "linear-gradient(to right, #002288, #222222, #888888, #ffffff, #ffcc00)";
        if (minL) minL.innerText = "-100m (Mar)"; if (maxL) maxL.innerText = "+2000m (Pico)";
      } else if (currentLayer === 'biomass') {
        if (info) info.innerText = "Modo: Biomassa Vegetal e Pasto para Herbívoros (0.0 a 100.0)";
        if (grad) grad.style.background = "linear-gradient(to right, #241c10, #386018, #2ea043, #00ff66)";
        if (minL) minL.innerText = "0.0"; if (maxL) maxL.innerText = "100.0";
      } else if (currentLayer === 'grains') {
        if (info) info.innerText = "Modo: Grãos de Arroz Selvagem Amazônico (Oryza glumaepatula) na Várzea";
        if (grad) grad.style.background = "linear-gradient(to right, #1c2620, #734812, #d29922, #f59e0b, #fff085)";
        if (minL) minL.innerText = "0 kg/m²"; if (maxL) maxL.innerText = "80 kg/m²";
      } else if (currentLayer === 'nests') {
        if (info) info.innerText = "Modo: Ninhos e Refúgios - Tocas Roedores (Ocre) | Covis Felinos (Vermelho) | Harpias (Esmeralda)";
        if (grad) grad.style.background = "linear-gradient(to right, #8b5a2b, #cd853f, #10b981, #58a6ff)";
        if (minL) minL.innerText = "Tocas Roedores"; if (maxL) maxL.innerText = "Ninho Harpia";
      } else if (currentLayer === 'fauna') {
        if (info) info.innerText = "Modo: Fauna ECS - Fêmeas (Claro) | Machos (Escuro) | Halo: Gestação/Cio";
        if (grad) grad.style.background = "linear-gradient(to right, #fff59d, #d48800, #ff7b72, #991b1b)";
        if (minL) minL.innerText = "🐁 Rato"; if (maxL) maxL.innerText = "🐈 Gato";
      } else if (currentLayer === 'scent') {
        if (info) info.innerText = "Modo: Trilha de Odor (24h) | Gato: Zona de Caça (25m) vs Faro (90m)";
        if (grad) grad.style.background = "linear-gradient(to right, #111111, #443311, #ffcc00, #ff4444)";
        if (minL) minL.innerText = "Sem Rastro"; if (maxL) maxL.innerText = "Trilha Fresca";
      } else {
        if (info) info.innerText = "Modo: Bioma Composto HD (Lago Central | Várzea de Gramíneas | Floresta | Arroz & Harpias)";
        if (grad) grad.style.background = "linear-gradient(to right, #0044ff, #00ddff, #3fb950, #d29922, #ffffff)";
        if (minL) minL.innerText = "-100m"; if (maxL) maxL.innerText = "+2000m";
      }

      render();
    });
  });

  // Pincéis
  document.querySelectorAll('.brush-btn').forEach(btn => {
    btn.addEventListener('click', function() {
      document.querySelectorAll('.brush-btn').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      currentBrush = this.dataset.brush;
    });
  });

  // Gestão de População
  const popPreset = document.getElementById('popPreset');
  const chkLockRatio = document.getElementById('chkLockRatio');
  const ratsSlider = document.getElementById('initRatsSlider');
  const ratsInput = document.getElementById('initRatsInput');
  const catsSlider = document.getElementById('initCatsSlider');
  const catsInput = document.getElementById('initCatsInput');

  if (popPreset) {
    popPreset.addEventListener('change', () => {
      const p = popPreset.value;
      if (p === 'default') {
        setRatsUI(180); setCatsUI(6);
        if (chkLockRatio) chkLockRatio.checked = true;
      } else if (p === 'sparse') {
        setRatsUI(90); setCatsUI(3);
        if (chkLockRatio) chkLockRatio.checked = true;
      } else if (p === 'dense') {
        setRatsUI(300); setCatsUI(10);
        if (chkLockRatio) chkLockRatio.checked = true;
      } else if (p === 'herbivores') {
        if (chkLockRatio) chkLockRatio.checked = false;
        setRatsUI(250); setCatsUI(0);
      } else if (p === 'predators') {
        if (chkLockRatio) chkLockRatio.checked = false;
        setRatsUI(150); setCatsUI(15);
      } else if (p === 'extinction_test') {
        if (chkLockRatio) chkLockRatio.checked = false;
        setRatsUI(140); setCatsUI(35);
      }
    });
  }

  if (ratsSlider) {
    ratsSlider.addEventListener('input', () => {
      const rVal = parseInt(ratsSlider.value) || 0;
      setRatsUI(rVal);
      if (chkLockRatio && chkLockRatio.checked) {
        setCatsUI(Math.max(1, Math.round(rVal / 30)));
      }
      if (popPreset) popPreset.value = 'custom';
    });
  }

  if (ratsInput) {
    ratsInput.addEventListener('input', () => {
      const rVal = Math.max(0, parseInt(ratsInput.value) || 0);
      if (ratsSlider) ratsSlider.value = Math.min(600, rVal);
      setRatsUI(rVal);
      if (chkLockRatio && chkLockRatio.checked) {
        setCatsUI(Math.max(1, Math.round(rVal / 30)));
      }
      if (popPreset) popPreset.value = 'custom';
    });
  }

  if (catsSlider) {
    catsSlider.addEventListener('input', () => {
      const cVal = parseInt(catsSlider.value) || 0;
      setCatsUI(cVal);
      if (chkLockRatio && chkLockRatio.checked) {
        setRatsUI(cVal * 30);
      }
      if (popPreset) popPreset.value = 'custom';
    });
  }

  if (catsInput) {
    catsInput.addEventListener('input', () => {
      const cVal = Math.max(0, parseInt(catsInput.value) || 0);
      if (catsSlider) catsSlider.value = Math.min(200, cVal);
      setCatsUI(cVal);
      if (chkLockRatio && chkLockRatio.checked) {
        setRatsUI(cVal * 30);
      }
      if (popPreset) popPreset.value = 'custom';
    });
  }

  if (chkLockRatio) {
    chkLockRatio.addEventListener('change', () => {
      if (chkLockRatio.checked && catsInput) {
        const cVal = parseInt(catsInput.value) || 0;
        setRatsUI(cVal * 30);
      }
    });
  }

  const btnApplyAndStart = document.getElementById('btnApplyAndStart');
  if (btnApplyAndStart) {
    btnApplyAndStart.addEventListener('click', () => {
      initWorld();
      tickCount = 0;
      totalSimHours = 0;
      timeOfDay = 12.0;
      lastSimDay = 0;
      isPlaying = true;
      const btnPlay = document.getElementById('btnPlay');
      if (btnPlay) {
        btnPlay.innerText = "⏸ Pausar";
        btnPlay.classList.add('active');
      }
      updateStats();
      render();
    });
  }

  const btnApplyPopOnly = document.getElementById('btnApplyPopOnly');
  if (btnApplyPopOnly) {
    btnApplyPopOnly.addEventListener('click', () => {
      initWorld();
      tickCount = 0;
      totalSimHours = 0;
      timeOfDay = 12.0;
      lastSimDay = 0;
      updateStats();
      render();
    });
  }
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.UIController = {
    initUI,
    updateStats,
    inspectCell,
    setZoom,
    movePan,
    resetCamera,
    setRatsUI,
    setCatsUI,
    screenToWorld,
    getCanvasCoordinates
  };
  window.initUI = initUI;
  window.updateStats = updateStats;
  window.inspectCell = inspectCell;
  window.setZoom = setZoom;
  window.movePan = movePan;
  window.resetCamera = resetCamera;
  window.setRatsUI = setRatsUI;
  window.setCatsUI = setCatsUI;
}
