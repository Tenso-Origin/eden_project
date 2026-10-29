// =========================================================================
// MÓDULO UI: CONTROLE DE CÂMERA, INTERAÇÃO, INSPEÇÃO E TELEMETRIA
// =========================================================================

const MIN_ZOOM = 0.25;
const MAX_ZOOM = 8.0;

function clampPan() {
  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;
  if (zoomLevel <= 0.50) {
    panX = gw / 2.0;
    panY = gh / 2.0;
  } else {
    const halfW = (gw / 2) / zoomLevel;
    const halfH = (gh / 2) / zoomLevel;
    panX = Math.max(halfW, Math.min(gw - halfW, panX));
    panY = Math.max(halfH, Math.min(gh - halfH, panY));
  }
}

function setZoom(newZoom, centerX = panX, centerY = panY) {
  const oldZoom = zoomLevel;
  zoomLevel = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, newZoom));
  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  if (zoomLevel <= 0.50) {
    panX = gw / 2.0;
    panY = gh / 2.0;
  } else if (oldZoom !== zoomLevel) {
    panX = centerX;
    panY = centerY;
    clampPan();
  }

  const lbl = document.getElementById('lblZoomLevel');
  if (lbl) lbl.innerText = `${zoomLevel.toFixed(2)}x`;
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
  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;
  zoomLevel = 0.50; // Inicia em visão panorâmica 2048x1024
  panX = gw / 2.0;
  panY = gh / 2.0;
  const lbl = document.getElementById('lblZoomLevel');
  if (lbl) lbl.innerText = `0.50x`;
  render();
}

function getCanvasCoordinates(clientX, clientY) {
  const canvasElem = document.getElementById('viewportCanvas');
  const rect = canvasElem.getBoundingClientRect();
  const scaleX = canvasElem.width / rect.width;
  const scaleY = canvasElem.height / rect.height;
  const canvasX = (clientX - rect.left) * scaleX;
  const canvasY = (clientY - rect.top) * scaleY;
  return { canvasX, canvasY };
}

function screenToWorld(clientX, clientY) {
  const canvasElem = document.getElementById('viewportCanvas');
  const { canvasX, canvasY } = getCanvasCoordinates(clientX, clientY);
  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;
  const wx = (canvasX - canvasElem.width / 2) / zoomLevel + panX;
  const wy = (canvasY - canvasElem.height / 2) / zoomLevel + panY;
  return {
    x: Math.max(0, Math.min(gw - 1, Math.floor(wx))),
    y: Math.max(0, Math.min(gh - 1, Math.floor(wy)))
  };
}

var lastInspectedX = 512;
var lastInspectedY = 512;

function inspectCell(x, y) {
  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;
  if (x < 0 || x >= gw || y < 0 || y >= gh) return;
  lastInspectedX = x;
  lastInspectedY = y;
  const idx = getIdx(x, y);

  const elCoord = document.getElementById('inspCoord');
  if (elCoord) elCoord.innerText = `(X: ${x}, Y: ${y})`;

  let region = "Planalto Continental";
  if (currentScenario === 'amazon') {
    const lakeCX = CHUNK_SIZE / 2.0, lakeCY = CHUNK_SIZE / 2.0;
    const distCenter = Math.hypot(x - lakeCX, y - lakeCY);
    if (distCenter <= 105.0) region = "Lago de Várzea Central (~35.000m²)";
    else if (distCenter <= 390.0) region = "Faixa de Gramíneas de Várzea (Zona da Harpia e Carcará)";
    else if (x < 300) region = "Serra Ocidental Elevada (550m)";
    else if (x > 930) region = "Delta / Mar Estuarino Leste";
    else region = "Floresta Equatorial de Terra Firme";
  } else {
    if (x <= 50 && y <= 50 && Math.hypot(x, y) <= 40) region = "Maciço Montanhoso NW (2km)";
    else if (x >= (CHUNK_SIZE - 50) && y >= (CHUNK_SIZE - 50)) region = "Oceano / Fossa Abissal SE (-100m)";
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
    const nestHere = nests.find(n => Math.hypot(n.x - x, n.y - y) < 4.5);
    if (nestHere) {
      if (nestHere.isSocialColony || ['ant', 'termite', 'bee'].includes(nestHere.species)) {
        const intPop = (nestHere.charges || 0) * 100;
        const extPop = (nestHere.activeSwarmsCount || 0) * 100;
        const totPop = intPop + extPop;
        let queenStr = "Sem rainha";
        if (nestHere.queen) {
          const qAge = (nestHere.queen.ageDays / 365).toFixed(1);
          const qMax = (nestHere.queen.maxLifespanDays / 365).toFixed(1);
          queenStr = nestHere.queen.isAlive ? `👑 Rainha ${qAge}/${qMax}a (${nestHere.queen.eggsPerDay} ovos/d, ovos:${(nestHere.queen.eggBuffer||0).toFixed(0)}%)` : "💀 Rainha Morta";
        }
        elNest.innerText = `${nestHere.name} | Pop: ${totPop} (${intPop} int. [${nestHere.charges}📦], ${extPop} ext.) | ${queenStr} | Res: ${(nestHere.resourcesKg||0).toFixed(1)}kg${nestHere.totalInvadersRepelled ? ` | ⚔️ Invasores rechaçados: ${nestHere.totalInvadersRepelled}` : ''}`;
      } else {
        elNest.innerText = `${nestHere.name} (${nestHere.species})`;
      }
    } else {
      elNest.innerText = "Nenhum";
    }
  }
  const elEroded = document.getElementById('inspEroded');
  if (elEroded) elEroded.innerText = cumulativeErosion[idx].toFixed(2) + " m";

  // Telemetria detalhada de animais próximos
  const nearbyAnimals = animals.filter(a => Math.hypot(a.x - x, a.y - y) < 2.0);
  const elFauna = document.getElementById('inspFauna');
  if (elFauna) {
    if (nearbyAnimals.length > 0) {
      const names = nearbyAnimals.map(a => {
        if (a.isSocial) {
          const icon = a.species === 'ant' ? '🐜' : (a.species === 'termite' ? '🪵' : '🐝');
          const pop = Math.max(1, Math.floor(a.hp));
          if (a.isVirginQueen) {
            return `👑 Rainha Virgem (${a.subspecies || a.species}) [Voo Nupcial, HP:1]`;
          }
          const carried = a.foodCarried ? ` Carga:${a.foodCarried.toFixed(1)}kg` : '';
          return `${icon} ${a.name || a.species} [Enxame:${pop} indiv., Atk:${pop}x0.1=${(pop*0.1).toFixed(1)}/Def:0.0] (Ninho #${a.nestId}${carried}, Fome:${(a.hunger||0).toFixed(0)}%)`;
        }
        let sp = (a.species === 'rat') ? '🐁 Rato' : (a.species === 'cat' ? '🐈 Gato' : a.species);
        if (a.species === 'tambaqui') sp = '🐟 Tambaqui';
        else if (a.species === 'traira') sp = '🐡 Traíra';
        else if (a.species === 'tortoise') sp = '🐢 Jabuti';
        else if (a.species === 'caiman') sp = '🐊 Jacaré';
        else if (a.species === 'toucan') sp = '🦜 Tucano';
        else if (a.species === 'carcara') sp = '🦅 Carcará';
        const sx = (a.sex === 'female') ? '♀' : '♂';
        let estrusStr = '';
        if (a.sex === 'female') {
          if (a.isPregnant) estrusStr = ` [Prenhe: ${(a.gestationRemaining||0).toFixed(1)}d rest., Ninhada: ${a.litterSize||0}]`;
          else if (a.estrusDurationRemaining > 0) estrusStr = ` 🔥[EM CIO: ${a.estrusDurationRemaining.toFixed(1)}d]`;
          else estrusStr = ` [Cio em ${(a.estrusCycleTimer || 0).toFixed(1)}d]`;
        }
        const genStr = a.genome ? ` [G${a.genome.generation}]` : (a.catGenome ? ` [G${a.catGenome.generation}]` : '');
        const hpStr = ` HP:${Math.max(0, a.hp).toFixed(0)}`;
        const stamStr = a.stamina !== undefined ? ` St:${a.stamina.toFixed(0)}` : '';
        const atkDefStr = ` Atk:${a.attackPower !== undefined ? a.attackPower.toFixed(1) : 10}/Def:${a.defensePower !== undefined ? a.defensePower.toFixed(1) : 3}`;
        const tagStr = `${a.isCornered ? ' ⚠️ACUADO' : ''}${a.isExhausted ? ' 💨EXAUSTO' : ''}${a.isDiving ? ' 🤿MERGULHADO' : ''}${a.isSleeping ? ' 💤DORMINDO' : ''}${a.isDrinking ? ' 💧BEBENDO (VULNERÁVEL)' : ''}`;
        const thirstStr = ` Th:${(a.thirst || 0).toFixed(0)}%`;
        const fatigueStr = ` Slp:${(a.fatigue || 0).toFixed(0)}%`;
        return `${sp} ${sx}${estrusStr}${genStr}${hpStr}${stamStr}${thirstStr}${fatigueStr}${atkDefStr}${tagStr} (Idade: ${(a.ageInDays||0).toFixed(0)}d, Fome: ${(a.hunger||0).toFixed(0)}%)`;
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
        if (nx >= 0 && nx < GRID_WIDTH && ny >= 0 && ny < GRID_HEIGHT) {
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
        if (nx >= 0 && nx < GRID_WIDTH && ny >= 0 && ny < GRID_HEIGHT) {
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

let lastStatsTick = -1;
let cachedGrainsText = "0 kg";

function updateStats(force = false) {
  if (!force && tickCount === lastStatsTick) return;
  if (!force && (tickCount % 6 !== 0)) return;
  lastStatsTick = tickCount;
  const elTicks = document.getElementById('statTicks');
  if (elTicks) elTicks.innerText = tickCount;

  const simDate = getSimDate(totalSimHours);
  const elDateBadge = document.getElementById('dateBadge');
  if (elDateBadge) elDateBadge.innerText = `📅 ${simDate.fullStr}`;
  const elStatDate = document.getElementById('statDate');
  if (elStatDate) {
    const floodTxt = (weather && weather.floodPulseLevel != null) ? `+${weather.floodPulseLevel.toFixed(2)}m` : '0.00m';
    const windDir = (weather && weather.speedX < 0) ? 'Leste -> Oeste (Alísios)' : 'Oeste -> Leste';
    const windSpd = (weather && weather.windSpeedKmH) ? weather.windSpeedKmH.toFixed(0) : '15';
    elStatDate.innerHTML = `${simDate.fullStr}<br><span style="color:#38bdf8; font-size:0.80rem;">🌊 Pulso Fluvial: ${floodTxt} | 💨 ${windDir} (${windSpd} km/h)</span>`;
  }

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
  if (elAvgTemp) {
    let tSum = 0;
    let count = 0;
    const gW = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
    const gH = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;
    for (let py = 64; py < gH; py += 128) {
      for (let px = 64; px < gW; px += 128) {
        const val = temp[getIdx(px, py)];
        if (!isNaN(val)) {
          tSum += val;
          count++;
        }
      }
    }
    elAvgTemp.innerText = (count > 0 ? (tSum / count).toFixed(1) : "26.5") + "°C";
  }

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
      elHarpies.innerText = "Desativada temporariamente";
    }
  }

  // Grãos de Arroz (Amostragem rápida a cada 30 ticks)
  const elGrains = document.getElementById('statGrains');
  if (elGrains) {
    if (tickCount % 30 === 0 || cachedGrainsText === "0 kg") {
      let totalG = 0;
      for (let i = 0; i < CELL_COUNT; i += 32) totalG += grains[i];
      cachedGrainsText = `${Math.round(totalG * 32)} kg`;
    }
    elGrains.innerText = cachedGrainsText;
  }

  // Ninhos
  const elNests = document.getElementById('statNests');
  if (elNests) {
    let ratN = 0, catN = 0, antN = 0, termiteN = 0, beeN = 0;
    for (let i = 0; i < nests.length; i++) {
      const sp = nests[i].species;
      if (sp === 'rat') ratN++;
      else if (sp === 'cat') catN++;
      else if (sp === 'ant') antN++;
      else if (sp === 'termite') termiteN++;
      else if (sp === 'bee') beeN++;
    }
    elNests.innerText = `${nests.length} (${ratN} tocas, ${catN} covis, ${antN} formig., ${termiteN} cupinz., ${beeN} colm.)`;
  }

  // Censo de Fauna em passagem única O(N) ultraveloz
  let ratsCount = 0, ratsF = 0, ratsM = 0, pregRats = 0;
  let catsCount = 0, catsF = 0, catsM = 0, pregCats = 0;
  let tambaquis = 0, pregTambaqui = 0;
  let trairas = 0, pregTraira = 0;
  let tortoises = 0, pregTortoise = 0;
  let caimans = 0, pregCaiman = 0;
  let toucans = 0, pregToucan = 0;
  let carcaras = 0, pregCarcara = 0;
  let totalInsects = 0, pregInsects = 0;
  let totalPregnantAll = 0;

  // Genomas
  let sumAlert = 0, sumRefuge = 0, sumSprint = 0, sumGen = 0;
  let sumVig = 0, sumFer = 0, sumStam = 0, sumCatGen = 0;

  for (let i = 0; i < animals.length; i++) {
    const a = animals[i];
    if (a.hp <= 0) continue;

    const isF = (a.sex === 'female');
    const isP = !!a.isPregnant;
    if (isF && isP) totalPregnantAll++;

    const sp = a.species;
    if (sp === 'rat') {
      ratsCount++;
      if (isF) { ratsF++; if (isP) pregRats++; }
      else ratsM++;
      if (a.genome) {
        sumAlert += a.genome.alertRadius + (a.genome.epigeneticBonus || 0);
        sumRefuge += a.genome.refugeAffinity;
        sumSprint += a.genome.sprintBurst;
        sumGen += a.genome.generation;
      }
    } else if (sp === 'cat') {
      catsCount++;
      if (isF) { catsF++; if (isP) pregCats++; }
      else catsM++;
      if (a.catGenome) {
        sumVig += a.catGenome.harpyVigilance;
        sumFer += a.catGenome.combatFerocity;
        sumStam += a.catGenome.staminaEfficiency;
        sumCatGen += (a.catGenome.generation || 0);
      }
    } else if (sp === 'tambaqui') {
      tambaquis++;
      if (isP) pregTambaqui++;
    } else if (sp === 'traira' || sp === 'piranha') {
      trairas++;
      if (isP) pregTraira++;
    } else if (sp === 'tortoise') {
      tortoises++;
      if (isP) pregTortoise++;
    } else if (sp === 'caiman') {
      caimans++;
      if (isP) pregCaiman++;
    } else if (sp === 'toucan') {
      toucans++;
      if (isP) pregToucan++;
    } else if (sp === 'carcara') {
      carcaras++;
      if (isP) pregCarcara++;
    } else {
      totalInsects++;
      if (isP) pregInsects++;
    }
  }

  const elRats = document.getElementById('statRats');
  if (elRats) elRats.innerText = `${ratsCount} (♀${ratsF} | ♂${ratsM})`;
  const elCats = document.getElementById('statCats');
  if (elCats) elCats.innerText = `${catsCount} (♀${catsF} | ♂${catsM})`;

  const elPreg = document.getElementById('statPregnant');
  if (elPreg) {
    elPreg.innerHTML = `🐭${pregRats} | 🐱${pregCats} | 🐟${pregTambaqui} | 🎣${pregTraira} | 🐢${pregTortoise} | 🐊${pregCaiman} | 🦜${pregToucan} | 🪶${pregCarcara} | 🐜${pregInsects} <span style="font-size:0.75rem; color:#fbcfe8;">(Total: ${totalPregnantAll} fêmeas gestantes/ovos)</span>`;
  }

  const elAquatic = document.getElementById('statAquatic');
  if (elAquatic) elAquatic.innerText = `🐟 ${tambaquis} Tambaquis (${pregTambaqui}♀ prenhes) | 🎣 ${trairas} Traíras (${pregTraira}♀ prenhes)`;

  const elReptiles = document.getElementById('statReptiles');
  if (elReptiles) elReptiles.innerText = `🐢 ${tortoises} Jabutis (${pregTortoise}♀ ovos) | 🐊 ${caimans} Jacarés (${pregCaiman}♀ ninho)`;

  const elBirds = document.getElementById('statBirds');
  if (elBirds) elBirds.innerText = `🦜 ${toucans} Tucanos (${pregToucan}♀ chocando) | 🪶 ${carcaras} Carcarás (${pregCarcara}♀ chocando)`;

  const elInsects = document.getElementById('statInsects');
  if (elInsects) elInsects.innerText = `🐜 Insetos Totais: ${totalInsects} (${pregInsects}♀ em postura)`;

  const elPeak = document.getElementById('statPeak');
  if (elPeak) {
    const peakElev = (currentScenario === 'amazon') ? elevation[getIdx(80, 512)] : elevation[getIdx(10, 10)];
    elPeak.innerText = peakElev.toFixed(1) + " m";
  }
  const elAbyss = document.getElementById('statAbyss');
  if (elAbyss) {
    const minElev = (currentScenario === 'amazon') ? elevation[getIdx(2000, 512)] : elevation[getIdx(GRID_WIDTH - 20, GRID_HEIGHT - 20)];
    elAbyss.innerText = minElev.toFixed(1) + " m";
  }

  // 1. Homeostase Ecológica e Razão Predador-Presa (Lotka-Volterra)
  const elHomeoVal = document.getElementById('lblHomeostasisVal');
  const elRatio = document.getElementById('lblPredPreyRatio');
  const aliveRatsCount = ratsCount;
  const aliveCatsCount = catsCount;
  const curRatio = (aliveCatsCount > 0) ? (aliveRatsCount / aliveCatsCount) : 0;

  // Proporção ótima da pirâmide trófica: 20:1 a 40:1 (ideal 30:1)
  let homeoScore = 98.0;
  if (aliveRatsCount === 0 || aliveCatsCount === 0) {
    homeoScore = 0.0;
  } else {
    let penalty = 0.0;
    if (curRatio < 18.0) {
      penalty += (18.0 - curRatio) * 3.0; // Superpredação excessiva
    } else if (curRatio > 45.0) {
      penalty += (curRatio - 45.0) * 1.2; // Superpopulação descontrolada de herbívoros
    }
    if (aliveRatsCount < 40) penalty += (40 - aliveRatsCount) * 1.0;
    homeoScore = Math.max(0.0, Math.min(100.0, 98.0 - penalty));
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
  const elAvgGen = document.getElementById('lblAvgGen');
  const elAvgAlert = document.getElementById('lblAvgAlert');
  const elAvgRefuge = document.getElementById('lblAvgRefuge');
  if (ratsCount > 0) {
    const n = ratsCount;
    if (elAvgGen) elAvgGen.innerText = `G${(sumGen / n).toFixed(1)}`;
    if (elAvgAlert) elAvgAlert.innerText = `${(sumAlert / n).toFixed(1)}c`;
    if (elAvgRefuge) elAvgRefuge.innerText = `${((sumRefuge / n) * 100).toFixed(0)}%`;
  } else {
    if (elAvgGen) elAvgGen.innerText = "G0";
    if (elAvgAlert) elAvgAlert.innerText = "--";
    if (elAvgRefuge) elAvgRefuge.innerText = "--";
  }

  // 3. Média genética dos Felinos (DNA Herdável & Combate)
  const elCatGen = document.getElementById('lblCatGen');
  const elCatVig = document.getElementById('lblCatVigilance');
  const elCatFer = document.getElementById('lblCatFerocity');
  const elCatStam = document.getElementById('lblCatStamina');
  if (catsCount > 0) {
    const nc = catsCount;
    if (elCatGen) elCatGen.innerText = `G${(sumCatGen / nc).toFixed(1)}`;
    if (elCatVig) elCatVig.innerText = `${(sumVig / nc).toFixed(2)}x`;
    if (elCatFer) elCatFer.innerText = `${(sumFer / nc).toFixed(2)}x`;
    if (elCatStam) elCatStam.innerText = `${(sumStam / nc).toFixed(2)}x`;
  } else {
    if (elCatGen) elCatGen.innerText = "G0";
    if (elCatVig) elCatVig.innerText = "--";
    if (elCatFer) elCatFer.innerText = "--";
    if (elCatStam) elCatStam.innerText = "--";
  }

  // 4. Contadores de Caças (Diversão vs Fome)
  const elFunKills = document.getElementById('statFunKills');
  if (elFunKills && typeof funKillsCount !== 'undefined') elFunKills.innerText = funKillsCount;
  const elHungryKills = document.getElementById('statHungryKills');
  if (elHungryKills && typeof hungryKillsCount !== 'undefined') elHungryKills.innerText = hungryKillsCount;

  // 5. Contadores de Nascimentos e Mortes
  const elBirths = document.getElementById('statBirths');
  if (elBirths && typeof totalBirthsCount !== 'undefined') elBirths.innerText = totalBirthsCount;
  const elPred = document.getElementById('statPredDeaths');
  if (elPred && typeof totalPredationDeaths !== 'undefined') elPred.innerText = totalPredationDeaths;
  const elStarv = document.getElementById('statStarvDeaths');
  if (elStarv && typeof totalStarvationDeaths !== 'undefined') elStarv.innerText = totalStarvationDeaths;
  const elThirst = document.getElementById('statThirstDeaths');
  if (elThirst && typeof totalThirstDeaths !== 'undefined') elThirst.innerText = totalThirstDeaths;
  const elSenesc = document.getElementById('statSenescDeaths');
  if (elSenesc && typeof totalSenescenceDeaths !== 'undefined') elSenesc.innerText = totalSenescenceDeaths;

  // 6. Reciclagem de Carcaças e Nutrientes no Solo
  const elNutrient = document.getElementById('statNutrientRecycle');
  if (elNutrient) {
    if (typeof totalDecomposedCount !== 'undefined' && totalDecomposedCount > 0) {
      elNutrient.innerText = `${totalDecomposedCount} carcaças recicladas (+${totalNutrientsRecycledKg.toFixed(1)} kg biomassa)`;
    } else {
      elNutrient.innerText = "Decomposição ativa nutrindo biomassa vegetal";
    }
  }

  // 7. Atualização dinâmica contínua do Inspetor de Célula (ao vivo)
  if (typeof inspectCell === 'function') {
    inspectCell(lastInspectedX, lastInspectedY);
  }
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
    const hoverCoord = screenToWorld(e.clientX, e.clientY);
    const elHover = document.getElementById('liveHoverCoord');
    if (elHover) {
      elHover.innerText = `X: ${hoverCoord.x} | Y: ${hoverCoord.y}`;
    }

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
