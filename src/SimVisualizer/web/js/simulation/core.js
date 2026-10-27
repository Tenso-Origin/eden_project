// =========================================================================
// MÓDULO CORE: CONFIGURAÇÃO PLANETÁRIA 512x512, BUFFERS E INICIALIZAÇÃO
// =========================================================================

// Dimensões do Grid Planetário (262.144 células)
const CHUNK_SIZE = 512;
const CELL_COUNT = CHUNK_SIZE * CHUNK_SIZE;

// Catálogo de Materiais Físicos
const MAT_WATER = 1, MAT_STEAM = 2, MAT_ICE = 3, MAT_STONE = 30, MAT_SOIL = 22, MAT_SAND = 31;
const MATERIALS = {
  [MAT_WATER]: { name: "Água / Oceano", k: 0.60, perm: 1.0, erod: 0.0 },
  [MAT_STEAM]: { name: "Vapor d'Água", k: 0.03, perm: 1.0, erod: 0.0 },
  [MAT_ICE]:   { name: "Gelo / Neve Alpina", k: 2.20, perm: 0.0, erod: 0.01 },
  [MAT_STONE]: { name: "Granito / Rocha", k: 2.80, perm: 0.04, erod: 0.005 },
  [MAT_SOIL]:  { name: "Solo Fértil", k: 0.70, perm: 0.60, erod: 0.08 },
  [MAT_SAND]:  { name: "Areia Aluvial", k: 0.27, perm: 0.95, erod: 0.16 }
};

// Arrays SoA Contíguos em Memória Direta (Typed Arrays de Alta Performance)
const matId = new Uint16Array(CELL_COUNT);
const elevation = new Float32Array(CELL_COUNT);
const initialElevation = new Float32Array(CELL_COUNT);
const temp = new Float32Array(CELL_COUNT);
const nextTemp = new Float32Array(CELL_COUNT);
const moisture = new Float32Array(CELL_COUNT);
const nextMoisture = new Float32Array(CELL_COUNT);
const surfaceWater = new Float32Array(CELL_COUNT);
const nextSurfaceWater = new Float32Array(CELL_COUNT);
const biomass = new Float32Array(CELL_COUNT);
const cumulativeErosion = new Float32Array(CELL_COUNT);
const ratScent = new Float32Array(CELL_COUNT);
const grains = new Float32Array(CELL_COUNT);

// Entidades Vivas e Estruturas
var nests = [];           // Ninhos e tocas maternais
var harpies = [];         // Casal de Harpias Amazônicas (Macho e Fêmea)
var animals = [];         // Ratos e Gatos
var naturalRefuges = [];  // Refúgios naturais (troncos, pedras, moitas)
var currentScenario = 'amazon'; // 'amazon' ou 'temperate'

// Controle de Zoom e Câmera Interativa (1 chunk = 1 m²)
var zoomLevel = 1.0;
var panX = 256.0, panY = 256.0;

// Calendário Planetário (Ano com 365 dias)
const MONTHS = [
  { name: "janeiro", days: 31 },
  { name: "fevereiro", days: 28 },
  { name: "março", days: 31 },
  { name: "abril", days: 30 },
  { name: "maio", days: 31 },
  { name: "junho", days: 30 },
  { name: "julho", days: 31 },
  { name: "agosto", days: 31 },
  { name: "setembro", days: 30 },
  { name: "outubro", days: 31 },
  { name: "novembro", days: 30 },
  { name: "dezembro", days: 31 }
];

function getSimDate(totalHours) {
  const totalDays = Math.floor(totalHours / 24.0);
  const year = Math.floor(totalDays / 365);
  let dayInYear = totalDays % 365;
  let monthIdx = 0;
  for (let m = 0; m < MONTHS.length; m++) {
    if (dayInYear < MONTHS[m].days) {
      monthIdx = m;
      break;
    }
    dayInYear -= MONTHS[m].days;
  }
  const dayOfMonth = dayInYear + 1;
  const dayStr = dayOfMonth.toString().padStart(2, '0');
  const monthName = MONTHS[monthIdx].name;
  return {
    day: dayOfMonth,
    dayStr,
    monthIdx,
    monthName,
    year,
    fullStr: `${dayStr} de ${monthName} do ano ${year}`,
    shortStr: `${dayStr}/${monthName.substr(0, 3)}/Ano ${year}`
  };
}

// Relógio & Variáveis de Telemetria Global
var timeOfDay = 12.0;
var totalSimHours = 0.0;
var lastSimDay = 0;
var tickCount = 0;
var globalErosionTotal = 0;
var funKillsCount = 0;
var hungryKillsCount = 0;
var totalBirthsCount = 0;
var totalPredationDeaths = 0;
var totalStarvationDeaths = 0;
var totalThirstDeaths = 0;
var totalSenescenceDeaths = 0;
var isPlaying = false;
var currentLayer = 'composite';
var currentBrush = 'inspect';

// Sistema Pluviométrico Dinâmico
var weather = {
  isRaining: false,
  timerHours: 10.0,
  intensity: 0.0,
  frontX: 250.0,
  frontY: 250.0,
  speedX: -1.2,
  speedY: 0.2,
  cloudRadius: 160.0
};

// Conversão Rápida de Coordenadas
function getIdx(x, y) { return y * CHUNK_SIZE + x; }

// Limpa 10m de biomassa e grãos ao redor de tocas e refúgios
function clearBiomassRadius(centerX, centerY, radius = 10.0) {
  const minX = Math.max(0, Math.floor(centerX - radius));
  const maxX = Math.min(CHUNK_SIZE - 1, Math.ceil(centerX + radius));
  const minY = Math.max(0, Math.floor(centerY - radius));
  const maxY = Math.min(CHUNK_SIZE - 1, Math.ceil(centerY + radius));
  const rSq = radius * radius;
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const dx = x - centerX;
      const dy = y - centerY;
      if (dx * dx + dy * dy <= rSq) {
        const idx = getIdx(x, y);
        biomass[idx] = 0.0;
        grains[idx] = 0.0;
      }
    }
  }
}

/**
 * Inicialização Geográfica e Ecológica do Mundo 512x512
 */
function initWorld() {
  animals = [];
  nests = [];
  harpies = [];
  grains.fill(0);
  globalErosionTotal = 0;
  funKillsCount = 0;
  hungryKillsCount = 0;
  totalBirthsCount = 0;
  totalPredationDeaths = 0;
  totalStarvationDeaths = 0;
  totalThirstDeaths = 0;
  totalSenescenceDeaths = 0;
  ratScent.fill(0);
  totalSimHours = 0.0;
  lastSimDay = 0;
  weather.isRaining = false;
  weather.timerHours = 10.0;
  weather.intensity = 0.0;

  const scSelect = (typeof document !== 'undefined') ? document.getElementById('scenarioSelect') : null;
  if (scSelect) currentScenario = scSelect.value;

  const equatorY = 255.5;

  // -------------------------------------------------------------------------
  // CENÁRIO 1: AMAZÔNIA - OESTE DO ESTADO DO PARÁ (Várzea, Floresta & Lago)
  // -------------------------------------------------------------------------
  if (currentScenario === 'amazon') {
    const lakeCenterX = 256.0, lakeCenterY = 256.0;

    for (let y = 0; y < CHUNK_SIZE; y++) {
      for (let x = 0; x < CHUNK_SIZE; x++) {
        const idx = getIdx(x, y);

        let regionalElev = 8.0 + Math.sin(x * 0.02 + y * 0.015) * 4.0;
        if (x < 150) {
          const uWest = (150 - x) / 150.0;
          regionalElev += Math.pow(uWest, 1.8) * 540.0;
        } else if (x > 465) {
          const uEast = (x - 465) / 47.0;
          regionalElev -= uEast * 18.0;
        }

        const dx = x - lakeCenterX;
        const dy = y - lakeCenterY;
        const d = Math.hypot(dx, dy);
        const angle = Math.atan2(dy, dx);
        const lakeR = 50.5 * (1.0 + 0.20 * Math.sin(3 * angle) + 0.15 * Math.cos(5 * angle + 0.5) + 0.08 * Math.sin(7 * angle));

        let finalElev = regionalElev;
        let finalMat = MAT_SOIL;
        let finalWater = 0.0;
        let finalMoist = 0.70;
        let finalBio = 65.0;

        if (d <= lakeR) {
          const depthNorm = Math.pow(Math.max(0, 1.0 - (d / lakeR)), 1.4);
          finalElev = -2.0 - (depthNorm * 18.0);
          finalMat = MAT_WATER;
          finalWater = -finalElev;
          finalMoist = 1.0;
          finalBio = 1.0;
        } else if (d <= lakeR + 145.0) {
          // Várzea de gramíneas aberta (zona da harpia e grãos de arroz)
          const floodD = d - lakeR;
          finalElev = 1.5 + (floodD * 0.06);
          finalMat = (floodD < 6.0) ? MAT_SAND : MAT_SOIL;
          finalWater = 0.0;
          finalMoist = Math.max(0.60, 1.0 - (floodD / 150.0) * 0.40);
          finalBio = 15.0 + Math.sin(d * 0.15) * 10.0 + (floodD * 0.18);
          grains[idx] = (floodD >= 4.0 && floodD <= 95.0) ? (30.0 + Math.random() * 45.0) : 0.0;
        } else {
          // Floresta densa de terra firme
          finalElev = regionalElev + 6.0 + Math.sin(x * 0.05 + y * 0.04) * 3.0;
          finalMat = (finalElev > 350.0) ? MAT_STONE : MAT_SOIL;
          finalWater = 0.0;
          finalMoist = 0.85;
          finalBio = Math.min(100.0, 75.0 + Math.random() * 25.0);
        }

        elevation[idx] = finalElev;
        initialElevation[idx] = finalElev;
        cumulativeErosion[idx] = 0.0;
        matId[idx] = finalMat;
        surfaceWater[idx] = finalWater;
        moisture[idx] = finalMoist;
        biomass[idx] = finalBio;
        temp[idx] = 27.5 - Math.max(0, finalElev) * 0.0065;
      }
    }

    // Inicialização do casal monogâmico de Harpias Amazônicas via HarpySpecies
    if (typeof HarpySpecies !== 'undefined') {
      harpies = HarpySpecies.createInitialHarpies();
    } else if (typeof createInitialHarpies !== 'undefined') {
      harpies = createInitialHarpies();
    }

    // Ninho permanente da Harpia na Samaúma a Nordeste (435, 85)
    nests.push({
      id: 9000,
      species: 'harpy',
      name: 'Ninho da Harpia (Samaúma)',
      quality: 100,
      x: 435.0,
      y: 85.0
    });
  } else {
    // -------------------------------------------------------------------------
    // CENÁRIO 2: PLANALTO CONTINENTAL TEMPERADO (-100m a +2000m)
    // -------------------------------------------------------------------------
    for (let y = 0; y < CHUNK_SIZE; y++) {
      const latDist = Math.abs(y - equatorY) / 255.5;
      const latFactor = Math.max(0, 1.0 - latDist);

      for (let x = 0; x < CHUNK_SIZE; x++) {
        const idx = getIdx(x, y);
        const diag = (511 - x + 511 - y) / 1022.0;
        const baseElev = -100.0 + diag * 2100.0;
        const rot1 = (x - y) * 0.08;
        const rot2 = (x + y) * 0.03;
        const striation = (Math.sin(rot1 * 2.0) * 1.8 + Math.cos(rot2 * 1.5 + rot1) * 1.2);
        const finalElev = Math.max(-100.0, Math.min(2000.0, baseElev + striation));

        elevation[idx] = finalElev;
        initialElevation[idx] = finalElev;
        cumulativeErosion[idx] = 0.0;

        if (finalElev < 0.0) {
          matId[idx] = MAT_WATER;
          surfaceWater[idx] = -finalElev;
          moisture[idx] = 1.0;
          biomass[idx] = 2.0;
        } else if (finalElev > 1600.0) {
          matId[idx] = MAT_ICE;
          surfaceWater[idx] = 0.0;
          moisture[idx] = 0.15;
          biomass[idx] = 0.0;
        } else if (finalElev > 950.0) {
          matId[idx] = MAT_STONE;
          surfaceWater[idx] = 0.0;
          moisture[idx] = 0.25;
          biomass[idx] = 6.0;
        } else if (latFactor > 0.88 && finalElev < 250.0 && x > 280) {
          matId[idx] = MAT_SAND;
          surfaceWater[idx] = 0.0;
          moisture[idx] = 0.10;
          biomass[idx] = 14.0;
        } else {
          matId[idx] = MAT_SOIL;
          surfaceWater[idx] = 0.0;
          moisture[idx] = 0.65;
          biomass[idx] = 45.0 + latFactor * 30.0;
        }

        temp[idx] = 20.0 + (latFactor * 16.0) - (Math.max(0, finalElev) * 0.0065);
      }
    }
  }

  // População inicial configurada pela UI ou valores padrão (180 ratos e 6 gatos)
  const ratsInput = (typeof document !== 'undefined') ? document.getElementById('initRatsInput') : null;
  const catsInput = (typeof document !== 'undefined') ? document.getElementById('initCatsInput') : null;
  const HERBIVORES_COUNT = ratsInput ? Math.max(0, parseInt(ratsInput.value) || 0) : 180;
  const X_PREDATORS = catsInput ? Math.max(0, parseInt(catsInput.value) || 0) : 6;

  // Refúgios Naturais: limitados a 10% dos ratos iniciais (75% floresta, 25% várzea)
  if (typeof initNaturalRefuges !== 'undefined') {
    initNaturalRefuges(HERBIVORES_COUNT);
  }

  // Herbívoros (Ratos)
  for (let i = 0; i < HERBIVORES_COUNT; i++) {
    let rx = 40 + Math.random() * (CHUNK_SIZE - 120);
    let ry = 40 + Math.random() * (CHUNK_SIZE - 120);
    if (currentScenario === 'amazon' && Math.hypot(rx - 256, ry - 256) < 40.0) {
      rx += (rx >= 256 ? 50 : -50);
    }

    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnant = (sex === 'female' && Math.random() < 0.35);
    let daysPregnant = 0.0;
    let gestationRemaining = 0.0;
    let hasNest = false;
    let nestX = rx, nestY = ry;

    if (isPregnant) {
      daysPregnant = 1.0 + Math.random() * 20.0;
      gestationRemaining = Math.max(0.5, 22.0 - daysPregnant);
      if (daysPregnant >= 3.0 && typeof findLocalNestLocation !== 'undefined') {
        const loc = findLocalNestLocation({ x: rx, y: ry });
        hasNest = true;
        nestX = loc.x;
        nestY = loc.y;
        nests.push({ id: i + 1, motherId: i + 1, species: 'rat', name: 'Toca de Roedores (Maternal)', quality: 80, x: nestX, y: nestY });
        clearBiomassRadius(nestX, nestY, 10.0);
      }
    }
    const litterSize = isPregnant ? (8 + Math.floor(Math.random() * 6)) : 0;
    const matingCooldown = isPregnant ? (gestationRemaining + 15.0) : (1.0 + Math.random() * 3.0);
    const inEstrusInit = (!isPregnant && sex === 'female' && Math.random() < (0.8 / 4.5));
    const estrusDurationRemaining = inEstrusInit ? (Math.random() * 0.8) : 0.0;
    const estrusCycleTimer = isPregnant ? gestationRemaining : (inEstrusInit ? 0.0 : Math.random() * 4.5);

    const initGenome = (typeof RatSpecies !== 'undefined') ? RatSpecies.createDefaultRatGenome() : {
      alertRadius: 12.0 + (Math.random() * 4.0 - 2.0),
      refugeAffinity: 0.45 + (Math.random() * 0.20 - 0.10),
      sprintBurst: 1.35 + (Math.random() * 0.20 - 0.10),
      epigeneticBonus: 0.0,
      memoryRetention: 0.70 + (Math.random() * 0.20 - 0.10),
      generation: 0
    };

    animals.push({
      id: i + 1,
      species: 'rat',
      diet: 'herbivore',
      sex: sex,
      isPregnant: isPregnant,
      daysPregnant: daysPregnant,
      gestationRemaining: gestationRemaining,
      litterSize: litterSize,
      estrusCycleTimer: estrusCycleTimer,
      estrusDurationRemaining: estrusDurationRemaining,
      x: rx,
      y: ry,
      hasNest: hasNest,
      nestX: nestX,
      nestY: nestY,
      hp: 100,
      stamina: 100.0,
      maxStamina: 100.0,
      isExhausted: false,
      attackPower: 10.0,
      defensePower: 3.0,
      isCornered: false,
      hunger: 15 + Math.random() * 15,
      thirst: 5.0 + Math.random() * 10.0,
      fatigue: Math.random() * 20.0,
      isSleeping: false,
      foodMemoryX: rx,
      foodMemoryY: ry,
      hasFoodMemory: false,
      breath: 7.0,
      maxBreath: 7.0,
      isDiving: false,
      speed: 2.2,
      ageInDays: 75.0 + Math.random() * 20.0,
      maxLifespan: 912.5,
      matingCooldown: matingCooldown,
      sensoryRadius: 5,
      dailyFunKills: 0,
      genome: initGenome,
      mateGenome: initGenome
    });
  }

  // Predadores (Gatos) - 49% fêmeas, 51% machos
  const maleCatsCount = Math.round(X_PREDATORS * 0.51);
  for (let i = 0; i < X_PREDATORS; i++) {
    let gx = 60 + Math.random() * (CHUNK_SIZE - 140);
    let gy = 60 + Math.random() * (CHUNK_SIZE - 140);
    if (currentScenario === 'amazon' && Math.hypot(gx - 256, gy - 256) < 40.0) {
      gx += (gx >= 256 ? 55 : -55);
    }

    const sex = (i < maleCatsCount) ? 'male' : 'female';
    const isPregnant = (sex === 'female' && Math.random() < 0.45);
    let daysPregnant = 0.0;
    let gestationRemaining = 0.0;
    let hasNest = false;
    let nestX = gx, nestY = gy;

    if (isPregnant) {
      daysPregnant = 1.0 + Math.random() * 60.0;
      gestationRemaining = Math.max(1.0, 65.0 - daysPregnant);
      if (daysPregnant >= 3.0 && typeof findLocalNestLocation !== 'undefined') {
        const loc = findLocalNestLocation({ x: gx, y: gy });
        hasNest = true;
        nestX = loc.x;
        nestY = loc.y;
        nests.push({ id: 1000 + i, motherId: 1000 + i, species: 'cat', name: 'Covil Felino (Maternal)', quality: 85, x: nestX, y: nestY });
        clearBiomassRadius(nestX, nestY, 10.0);
      }
    }
    const litterSize = isPregnant ? (3 + Math.floor(Math.random() * 3)) : 0;
    const matingCooldown = isPregnant ? (gestationRemaining + 45.0) : (5.0 + Math.random() * 15.0);
    const inEstrusInit = (!isPregnant && sex === 'female' && Math.random() < (5.0 / 18.0));
    const estrusDurationRemaining = inEstrusInit ? (Math.random() * 5.0) : 0.0;
    const estrusCycleTimer = isPregnant ? gestationRemaining : (inEstrusInit ? 0.0 : Math.random() * 18.0);

    const initCatGenome = (typeof CatSpecies !== 'undefined') ? CatSpecies.createDefaultCatGenome() : {
      harpyVigilance: 1.0,
      ambushPatience: 1.0,
      combatFerocity: 1.0,
      staminaEfficiency: 1.0,
      memoryRetention: 0.75,
      generation: 0
    };

    animals.push({
      id: 1000 + i,
      species: 'cat',
      diet: 'carnivore',
      sex: sex,
      isPregnant: isPregnant,
      daysPregnant: daysPregnant,
      gestationRemaining: gestationRemaining,
      litterSize: litterSize,
      estrusCycleTimer: estrusCycleTimer,
      estrusDurationRemaining: estrusDurationRemaining,
      x: gx,
      y: gy,
      hasNest: hasNest,
      nestX: nestX,
      nestY: nestY,
      hp: 100,
      stamina: 100.0,
      maxStamina: 100.0,
      isExhausted: false,
      attackPower: 42.0,
      defensePower: 14.0,
      isCornered: false,
      catGenome: initCatGenome,
      mateCatGenome: initCatGenome,
      hunger: 5 + Math.random() * 10,
      thirst: 5.0 + Math.random() * 10.0,
      fatigue: Math.random() * 20.0,
      isSleeping: false,
      foodMemoryX: gx,
      foodMemoryY: gy,
      hasFoodMemory: false,
      chaseTimer: 0.0,
      chaseAbandonCooldown: 0.0,
      targetPreyId: null,
      breath: 0.0,
      maxBreath: 0.0,
      isDiving: false,
      speed: 2.8,
      ageInDays: 400.0 + Math.random() * 60.0,
      maxLifespan: 5110.0,
      matingCooldown: matingCooldown,
      sensoryRadius: 15,
      dailyFunKills: 0
    });
  }
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.SimulationCore = {
    CHUNK_SIZE,
    CELL_COUNT,
    MATERIALS,
    matId,
    elevation,
    initialElevation,
    temp,
    nextTemp,
    moisture,
    nextMoisture,
    surfaceWater,
    nextSurfaceWater,
    biomass,
    cumulativeErosion,
    ratScent,
    grains,
    nests,
    harpies,
    animals,
    naturalRefuges,
    weather,
    getIdx,
    clearBiomassRadius,
    getSimDate,
    initWorld
  };
  window.CHUNK_SIZE = CHUNK_SIZE;
  window.CELL_COUNT = CELL_COUNT;
  window.MATERIALS = MATERIALS;
  window.MAT_WATER = MAT_WATER;
  window.MAT_STEAM = MAT_STEAM;
  window.MAT_ICE = MAT_ICE;
  window.MAT_STONE = MAT_STONE;
  window.MAT_SOIL = MAT_SOIL;
  window.MAT_SAND = MAT_SAND;
  window.matId = matId;
  window.elevation = elevation;
  window.initialElevation = initialElevation;
  window.temp = temp;
  window.nextTemp = nextTemp;
  window.moisture = moisture;
  window.nextMoisture = nextMoisture;
  window.surfaceWater = surfaceWater;
  window.nextSurfaceWater = nextSurfaceWater;
  window.biomass = biomass;
  window.cumulativeErosion = cumulativeErosion;
  window.ratScent = ratScent;
  window.grains = grains;
  window.nests = nests;
  window.harpies = harpies;
  window.animals = animals;
  window.naturalRefuges = naturalRefuges;
  window.weather = weather;
  window.getIdx = getIdx;
  window.clearBiomassRadius = clearBiomassRadius;
  window.zoomLevel = zoomLevel;
  window.panX = panX;
  window.panY = panY;
  window.currentLayer = currentLayer;
  window.currentBrush = currentBrush;
  window.isPlaying = isPlaying;
  window.getSimDate = getSimDate;
  window.initWorld = initWorld;
}
