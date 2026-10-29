// =========================================================================
// MÓDULO CORE: CONFIGURAÇÃO PLANETÁRIA 2048x1024, BUFFERS E BACIA AMAZÔNICA
// =========================================================================

// Dimensões do Grid Planetário Panorâmico Expandido (2.097.152 células SoA)
const GRID_WIDTH = 2048;
const GRID_HEIGHT = 1024;
const CHUNK_SIZE = GRID_WIDTH; // Compatibilidade retroativa
const CHUNK_WIDTH = GRID_WIDTH;
const CHUNK_HEIGHT = GRID_HEIGHT;
const CELL_COUNT = GRID_WIDTH * GRID_HEIGHT;

// Catálogo de Materiais Físicos
const MAT_WATER = 1, MAT_STEAM = 2, MAT_ICE = 3, MAT_STONE = 30, MAT_SOIL = 22, MAT_SAND = 31;
const MATERIALS = {
  [MAT_WATER]: { name: "Água Fluvial / Lago", k: 0.60, perm: 1.0, erod: 0.0 },
  [MAT_STEAM]: { name: "Vapor d'água", k: 0.03, perm: 1.0, erod: 0.0 },
  [MAT_ICE]:   { name: "Gelo / Neve de Altitude", k: 2.20, perm: 0.0, erod: 0.01 },
  [MAT_STONE]: { name: "Granito / Serras Residuais", k: 2.80, perm: 0.04, erod: 0.005 },
  [MAT_SOIL]:  { name: "Solo Fértil / Terra Firme", k: 0.70, perm: 0.60, erod: 0.08 },
  [MAT_SAND]:  { name: "Areia Aluvial / Praias Fluviais", k: 0.27, perm: 0.95, erod: 0.16 }
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
var animals = [];         // Fauna completa (Ratos, Gatos, Peixes, Répteis, Aves, Insetos)
var naturalRefuges = [];  // Refúgios naturais (troncos ocos, rochas, moitas densas)
var currentScenario = 'amazon'; // 'amazon' ou 'temperate'
var initialBiomassReference = 0;

// Controle de Zoom e Câmera Interativa (1 chunk = 1 m²)
var zoomLevel = 0.50; // Inicia com visão ampla panorâmica de 2048x1024
var panX = 1024.0, panY = 512.0;

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

  // Clima Amazônico: Inverno Amazônico (Chuvas e Cheia) vs Verão Amazônico (Estiagem e Vazante)
  const isRainySeason = (monthIdx >= 10 || monthIdx <= 3); // Novembro a Abril
  const seasonName = isRainySeason ? "Inverno Amazônico (Cheias)" : "Verão Amazônico (Vazante)";

  return {
    day: dayOfMonth,
    dayStr,
    monthIdx,
    monthName,
    year,
    isRainySeason,
    seasonName,
    fullStr: `${dayStr} de ${monthName} do ano ${year} [${seasonName}]`,
    shortStr: `${dayStr}/${monthName.substr(0, 3)}/A${year}`
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
var totalDecomposedCount = 0;
var totalNutrientsRecycledKg = 0.0;
var isPlaying = false;
var currentLayer = 'composite';
var currentBrush = 'inspect';

// Sistema Meteorológico Amazônico: Estações, Ventos Alísios e Pulso de Inundação
var weather = {
  isRaining: false,
  timerHours: 6.0,
  intensity: 0.0,
  frontX: 1800.0,
  frontY: 512.0,
  speedX: -1.8, // Ventos Alísios sopram de Leste para Oeste
  speedY: 0.3,
  cloudRadius: 180.0,
  windSpeedKmH: 15.0,
  floodPulseLevel: 0.0 // Nível do pulso anual de inundação das várzeas (0m na seca a +4.5m na cheia)
};

// Conversão Rápida de Coordenadas 2D -> 1D
function getIdx(x, y) { return y * GRID_WIDTH + x; }

// Limpa 10m de biomassa e grãos ao redor de tocas e refúgios
function clearBiomassRadius(centerX, centerY, radius = 10.0) {
  const minX = Math.max(0, Math.floor(centerX - radius));
  const maxX = Math.min(GRID_WIDTH - 1, Math.ceil(centerX + radius));
  const minY = Math.max(0, Math.floor(centerY - radius));
  const maxY = Math.min(GRID_HEIGHT - 1, Math.ceil(centerY + radius));
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

// =========================================================================
// MODELAGEM HIDROGRÁFICA NATURAL DA BACIA AMAZÔNICA
// =========================================================================

/**
 * Traçado meândrico natural do Rio Principal (Rio Solimões / Amazonas)
 * Flui de Oeste para Leste com sinuosidade meândrica realista.
 */
function getRiverMainY(x) {
  return 512.0 + 175.0 * Math.sin(x * 0.0032) + 90.0 * Math.cos(x * 0.0078 + 0.6) + 38.0 * Math.sin(x * 0.016 - 0.5);
}

/**
 * Traçado do Afluente Confluente (Rio Negro / Tapajós)
 * Nasce a Noroeste e converge no rio principal em x ~1250.
 */
function getRiverTributaryY(x) {
  if (x > 1250) return -9999.0;
  const u = x / 1250.0;
  const targetY = getRiverMainY(1250);
  const baseCurve = 160.0 + u * (targetY - 160.0);
  return baseCurve + 65.0 * Math.sin(x * 0.0062) + 25.0 * Math.cos(x * 0.014);
}

/**
 * Coleção de Lagos de Ferradura (Oxbow Lakes / Meandros Abandonados / Sacados)
 * Formados naturalmente pelo corte de meandros na planície de inundação da Amazônia.
 */
const OXBOW_LAKES = [
  { cx: 540,  cy: 350, r: 70, width: 17, startAng: -0.3, endAng: 3.3, depth: 6.0 },
  { cx: 890,  cy: 730, r: 75, width: 18, startAng: 2.8,  endAng: 6.4, depth: 7.0 },
  { cx: 1340, cy: 320, r: 65, width: 16, startAng: -0.2, endAng: 3.4, depth: 6.5 },
  { cx: 1680, cy: 750, r: 70, width: 18, startAng: 2.7,  endAng: 6.3, depth: 7.0 },
  { cx: 1880, cy: 400, r: 55, width: 15, startAng: -0.4, endAng: 3.2, depth: 5.5 }
];

/**
 * Testa se uma coordenada (x, y) está dentro da rede hidrográfica (rio principal, afluente ou lagos de ferradura)
 */
function isPointInWaterBody(x, y) {
  if (x < 0 || x >= GRID_WIDTH || y < 0 || y >= GRID_HEIGHT) return false;
  // 1. Rio Principal
  const yMain = getRiverMainY(x);
  const wMain = 28.0 + (x / GRID_WIDTH) * 12.0;
  if (Math.abs(y - yMain) <= wMain) return true;

  // 2. Afluente
  const yTrib = getRiverTributaryY(x);
  if (yTrib > -9000) {
    const wTrib = 18.0 + (x / 1250.0) * 8.0;
    if (Math.abs(y - yTrib) <= wTrib) return true;
  }

  // 3. Lagos de Ferradura
  for (let k = 0; k < OXBOW_LAKES.length; k++) {
    const ox = OXBOW_LAKES[k];
    const dx = x - ox.cx;
    const dy = y - ox.cy;
    const dCenter = Math.hypot(dx, dy);
    let ang = Math.atan2(dy, dx);
    if (ang < 0) ang += Math.PI * 2;
    const dr = Math.abs(dCenter - ox.r);
    if (dr <= ox.width) {
      if ((ox.startAng <= ang && ang <= ox.endAng) || (ox.startAng < 0 && (ang >= ox.startAng + Math.PI * 2 || ang <= ox.endAng))) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Inicialização Geográfica e Ecológica do Mundo Amazônico 2048x1024
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
  totalDecomposedCount = 0;
  totalNutrientsRecycledKg = 0.0;
  ratScent.fill(0);
  totalSimHours = 0.0;
  lastSimDay = 0;
  weather.isRaining = false;
  weather.timerHours = 6.0;
  weather.intensity = 0.0;
  weather.floodPulseLevel = 0.0;

  const scSelect = (typeof document !== 'undefined') ? document.getElementById('scenarioSelect') : null;
  if (scSelect) currentScenario = scSelect.value;

  const equatorY = (GRID_HEIGHT - 1) / 2.0;

  // =========================================================================
  // GERAÇÃO DO RELEVO E BIOMAS AMAZÔNICOS (2048 x 1024)
  // =========================================================================
  if (currentScenario === 'amazon') {
    for (let y = 0; y < GRID_HEIGHT; y++) {
      for (let x = 0; x < GRID_WIDTH; x++) {
        const idx = getIdx(x, y);

        // 1. Relevo Regional: Inclinação subindo suavemente para Oeste (contrafortes andinos/serras)
        let regionalElev = 35.0 + Math.sin(x * 0.006 + 0.3) * Math.cos(y * 0.008) * 18.0 + Math.sin(x * 0.015 + y * 0.012) * 8.0;
        if (x < 480) {
          // Serras residuais e relevo acidentado a Oeste
          const uWest = (480.0 - x) / 480.0;
          regionalElev += Math.pow(uWest, 1.7) * 490.0;
        } else if (x > 1650) {
          // Baixada litorânea / planície terminal a Leste
          const uEast = (x - 1650.0) / 398.0;
          regionalElev -= uEast * 22.0;
        }

        // 2. Rio Principal Meândrico
        const yMain = getRiverMainY(x);
        const wMain = 28.0 + (x / GRID_WIDTH) * 12.0;
        const dMain = Math.abs(y - yMain);

        // 3. Rio Afluente
        const yTrib = getRiverTributaryY(x);
        const wTrib = 18.0 + (x / 1250.0) * 8.0;
        const dTrib = (yTrib > -9000) ? Math.abs(y - yTrib) : 9999.0;

        // 4. Lagos de Ferradura (Oxbow Lakes)
        let inOxbow = false;
        let oxbowDepth = 0.0;
        for (let k = 0; k < OXBOW_LAKES.length; k++) {
          const ox = OXBOW_LAKES[k];
          const dx = x - ox.cx;
          const dy = y - ox.cy;
          const dCenter = Math.hypot(dx, dy);
          let ang = Math.atan2(dy, dx);
          if (ang < 0) ang += Math.PI * 2;
          const dr = Math.abs(dCenter - ox.r);
          if (dr <= ox.width) {
            if ((ox.startAng <= ang && ang <= ox.endAng) || (ox.startAng < 0 && (ang >= ox.startAng + Math.PI * 2 || ang <= ox.endAng))) {
              inOxbow = true;
              const norm = 1.0 - (dr / ox.width);
              oxbowDepth = ox.depth * (norm * norm);
              break;
            }
          }
        }

        let finalElev = regionalElev;
        let finalMat = MAT_SOIL;
        let finalWater = 0.0;
        let finalMoist = 0.70;
        let finalBio = 65.0;

        // Atribuição de Biótopos / Fitofisionomias
        if (dMain <= wMain) {
          // Calha do Rio Principal
          const depthNorm = 1.0 - Math.pow(dMain / wMain, 2.0);
          finalElev = -2.0 - (depthNorm * 14.0);
          finalMat = MAT_WATER;
          finalWater = -finalElev;
          finalMoist = 1.0;
          finalBio = 1.0;
        } else if (dTrib <= wTrib) {
          // Calha do Afluente
          const depthNorm = 1.0 - Math.pow(dTrib / wTrib, 2.0);
          finalElev = -2.0 - (depthNorm * 10.0);
          finalMat = MAT_WATER;
          finalWater = -finalElev;
          finalMoist = 1.0;
          finalBio = 1.0;
        } else if (inOxbow) {
          // Lago de Ferradura (Oxbow Lake)
          finalElev = -1.5 - oxbowDepth;
          finalMat = MAT_WATER;
          finalWater = -finalElev;
          finalMoist = 1.0;
          finalBio = 2.0;
        } else {
          // Proximidade hídrica mínima
          const distToWater = Math.min(dMain - wMain, dTrib - wTrib);

          if (distToWater <= 18.0) {
            // IGAPÓ: Margem imediata alagadiça, praias de areia aluvial e macrófitas
            finalElev = 1.2 + distToWater * 0.15;
            finalMat = MAT_SAND;
            finalWater = 0.0;
            finalMoist = 0.95;
            finalBio = 45.0 + Math.random() * 20.0;
          } else if (distToWater <= 160.0 && finalElev < 30.0) {
            // VÁRZEA: Planície de inundação sazonal rica em sedimentos, gramíneas e arroz selvagem
            finalElev = 2.5 + (distToWater * 0.08);
            finalMat = (distToWater < 30.0) ? MAT_SAND : MAT_SOIL;
            finalWater = 0.0;
            finalMoist = Math.max(0.60, 1.0 - (distToWater / 160.0) * 0.35);
            finalBio = 25.0 + Math.sin(x * 0.05 + y * 0.05) * 12.0;
            // Grãos de arroz de várzea germinando nas áreas férteis
            grains[idx] = (distToWater >= 15.0 && distToWater <= 120.0) ? (35.0 + Math.random() * 45.0) : 0.0;
          } else if (finalElev > 300.0) {
            // SERRAS OCIDENTAIS: Cumes rochosos graníticos
            finalMat = MAT_STONE;
            finalWater = 0.0;
            finalMoist = 0.35;
            finalBio = Math.max(5.0, 30.0 - (finalElev - 300.0) * 0.1);
          } else if (Math.sin(x * 0.02 + 1.2) * Math.cos(y * 0.02) > 0.65 && finalElev > 45.0) {
            // CAMPINARANAS / CAMPOS NATURAIS: Clareiras sobre solos arenosos
            finalMat = MAT_SAND;
            finalWater = 0.0;
            finalMoist = 0.40;
            finalBio = 20.0 + Math.random() * 15.0;
          } else {
            // MATA DE TERRA FIRME: Floresta ombrófila perene densa em platôs
            finalMat = MAT_SOIL;
            finalWater = 0.0;
            finalMoist = 0.85;
            finalBio = Math.min(100.0, 75.0 + Math.random() * 25.0);
          }
        }

        elevation[idx] = finalElev;
        initialElevation[idx] = finalElev;
        cumulativeErosion[idx] = 0.0;
        matId[idx] = finalMat;
        surfaceWater[idx] = finalWater;
        moisture[idx] = finalMoist;
        biomass[idx] = finalBio;
        temp[idx] = 28.0 - Math.max(0, finalElev) * 0.0065;
      }
    }

    // Inicialização da Harpia na Samaúma monumental em platô de terra firme a Nordeste
    // Harpia temporariamente desligada a pedido do usuario
    harpies = [];
    /*
if (typeof HarpySpecies !== 'undefined') {
      harpies = HarpySpecies.createInitialHarpies(GRID_WIDTH);
    }

    // Ninho permanente da Harpia
    nests.push({
      id: 9000,
      species: 'harpy',
      name: 'Ninho da Harpia (Samaúma de Terra Firme)',
      quality: 100,
      x: 1680.0,
      y: 180.0
    });
    */
  }

  // =========================================================================
  // POVOAMENTO ESTRATIFICADO POR HABITAT NATURAL (BIODIVERSIDADE AMAZÔNICA)
  // =========================================================================

  // 1. Mamíferos: Ratos e Gatos
  // Ratos em tocas na borda da várzea rica em grãos e terra firme
  const HERBIVORES_COUNT = 100;
  const X_PREDATORS = 16;

  for (let i = 0; i < HERBIVORES_COUNT; i++) {
    // Escolhe local em terra firme ou borda alta da várzea
    let rx = 80 + Math.random() * (GRID_WIDTH - 160);
    let ry = 80 + Math.random() * (GRID_HEIGHT - 160);
    while (isPointInWaterBody(rx, ry)) {
      rx = 80 + Math.random() * (GRID_WIDTH - 160);
      ry = 80 + Math.random() * (GRID_HEIGHT - 160);
    }

    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnant = (sex === 'female' && Math.random() < 0.30);
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

    animals.push({
      id: i + 1,
      species: 'rat',
      diet: 'herbivore',
      sex: sex,
      isPregnant: isPregnant,
      daysPregnant: daysPregnant,
      gestationRemaining: gestationRemaining,
      litterSize: isPregnant ? (8 + Math.floor(Math.random() * 6)) : 0,
      estrusCycleTimer: isPregnant ? gestationRemaining : (Math.random() * 4.5),
      estrusDurationRemaining: (!isPregnant && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 0.8) : 0.0,
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
      hunger: 10 + Math.random() * 15,
      thirst: 5.0 + Math.random() * 10,
      fatigue: 0.0,
      isSleeping: false,
      foodMemoryX: rx,
      foodMemoryY: ry,
      hasFoodMemory: false,
      chaseTimer: 0.0,
      chaseAbandonCooldown: 0.0,
      targetPreyId: null,
      breath: 7.0,
      maxBreath: 7.0,
      isDiving: false,
      speed: 2.4,
      ageInDays: 120.0 + Math.random() * 250.0,
      maxLifespan: 912.5,
      matingCooldown: isPregnant ? (gestationRemaining + 15.0) : (1.0 + Math.random() * 3.0),
      sensoryRadius: 55,
      dailyFunKills: 0
    });
  }

  // Gatos: patrulha territorial nas clareiras e bordas de floresta
  for (let i = 0; i < X_PREDATORS; i++) {
    let gx = 100 + Math.random() * (GRID_WIDTH - 200);
    let gy = 100 + Math.random() * (GRID_HEIGHT - 200);
    while (isPointInWaterBody(gx, gy)) {
      gx = 100 + Math.random() * (GRID_WIDTH - 200);
      gy = 100 + Math.random() * (GRID_HEIGHT - 200);
    }

    const sex = (i % 2 === 0) ? 'female' : 'male';
    const isPregnant = (sex === 'female' && Math.random() < 0.30);
    let daysPregnant = 0.0;
    let gestationRemaining = 0.0;
    let hasNest = false;
    let nestX = gx, nestY = gy;

    if (isPregnant) {
      daysPregnant = 2.0 + Math.random() * 60.0;
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

    animals.push({
      id: 1000 + i,
      species: 'cat',
      diet: 'carnivore',
      sex: sex,
      isPregnant: isPregnant,
      daysPregnant: daysPregnant,
      gestationRemaining: gestationRemaining,
      litterSize: isPregnant ? (3 + Math.floor(Math.random() * 3)) : 0,
      estrusCycleTimer: isPregnant ? gestationRemaining : (Math.random() * 18.0),
      estrusDurationRemaining: (!isPregnant && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 5.0) : 0.0,
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
      hunger: 15 + Math.random() * 20,
      thirst: 5.0 + Math.random() * 10,
      fatigue: 0.0,
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
      matingCooldown: isPregnant ? (gestationRemaining + 45.0) : (5.0 + Math.random() * 15.0),
      sensoryRadius: 60,
      dailyFunKills: 0
    });
  }

  // 2. Fauna Aquática: Tambaquis e Traíras na calha dos rios e lagos de ferradura
  if (typeof AquaticSpecies !== 'undefined') {
    const aquatic = AquaticSpecies.createInitialAquatic(OXBOW_LAKES, GRID_WIDTH, GRID_HEIGHT);
    animals.push(...aquatic);
  }

  // 3. Répteis: Jacarés nas praias e Jabutis nos platôs altos de terra firme
  if (typeof ReptileSpecies !== 'undefined') {
    const reptiles = ReptileSpecies.createInitialReptiles(OXBOW_LAKES, GRID_WIDTH, GRID_HEIGHT);
    animals.push(...reptiles);
  }

  // 4. Aves: Tucanos no dossel de terra firme e Carcarás nas várzeas abertas
  if (typeof BirdSpecies !== 'undefined') {
    const birds = BirdSpecies.createInitialBirds(GRID_WIDTH, GRID_HEIGHT);
    animals.push(...birds);
  }

  // 5. Insetos Neotropicais: 10 espécies distribuídas por seus biótopos preferenciais
  if (typeof InsectSpecies !== 'undefined') {
    const insects = InsectSpecies.createInitialInsects(GRID_WIDTH, GRID_HEIGHT, nests);
    animals.push(...insects);
  }

  // Registra a biomassa vegetal total inicial
  let totalInitBio = 0;
  for (let bi = 0; bi < CELL_COUNT; bi += 8) totalInitBio += biomass[bi];
  initialBiomassReference = totalInitBio * 8;
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.SimulationCore = {
    GRID_WIDTH,
    GRID_HEIGHT,
    CHUNK_SIZE,
    CHUNK_WIDTH,
    CHUNK_HEIGHT,
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
    OXBOW_LAKES,
    getRiverMainY,
    getRiverTributaryY,
    isPointInWaterBody,
    getSimDate,
    initWorld,
    getIdx,
    clearBiomassRadius
  };
}
