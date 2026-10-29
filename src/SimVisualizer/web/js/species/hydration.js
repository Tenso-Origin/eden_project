// =========================================================================
// MÓDULO DE HIDRATAÇÃO, SEDE UNIVERSAL E VULNERABILIDADE NA MARGEM D'ÁGUA
// Projeto Biosfera - Bacia Amazônica 2048x1024
// =========================================================================

/**
 * Sistema Universal de Hidratação e Predação de Emboscada em Margens Fluviais
 */
var HydrationSystem = (function() {

  /**
   * Localiza a margem de água doce mais próxima (borda de terra firme adjacente ao rio ou lago)
   */
  function findNearestWaterShoreline(x, y, ctx) {
    const { matId, surfaceWater, MAT_WATER, GRID_WIDTH, GRID_HEIGHT, getIdx } = ctx;
    const gridW = GRID_WIDTH || 2048;
    const gridH = GRID_HEIGHT || 1024;

    // 1. Verificação local em raio de 18 metros para corpos d'água imediatos
    const ix = Math.floor(x);
    const iy = Math.floor(y);

    for (let r = 2; r <= 18; r += 2) {
      for (let ang = 0; ang < Math.PI * 2; ang += Math.PI / 4) {
        const cx = Math.floor(x + Math.cos(ang) * r);
        const cy = Math.floor(y + Math.sin(ang) * r);
        if (cx >= 2 && cx < gridW - 2 && cy >= 2 && cy < gridH - 2) {
          const getCellIdx = (ctx && typeof ctx.getIdx === 'function') ? ctx.getIdx : ((px, py) => py * gridW + px);
          const cIdx = getCellIdx(cx, cy);
          if (matId && (matId[cIdx] === MAT_WATER || (surfaceWater && surfaceWater[cIdx] > 0.08))) {
            // Recua ligeiramente para parar na terra seca na beirada exata da água
            const shoreX = Math.max(4, Math.min(gridW - 4, x + Math.cos(ang) * Math.max(1.0, r - 1.6)));
            const shoreY = Math.max(4, Math.min(gridH - 4, y + Math.sin(ang) * Math.max(1.0, r - 1.6)));
            return { x: shoreX, y: shoreY, dist: r, isLocal: true };
          }
        }
      }
    }

    // 2. Se não houver água no raio imediato, calcula a margem do Rio Solimões/Amazonas
    const fnRiverY = (ctx && typeof ctx.getRiverMainY === 'function') ? ctx.getRiverMainY : ((typeof getRiverMainY === 'function') ? getRiverMainY : null);
    const yRiver = fnRiverY ? fnRiverY(x) : (gridH * 0.5);
    const riverHalfWidth = 28.0 + (x / gridW) * 12.0;

    // Margem norte ou sul mais próxima da calha principal
    const riverShoreY = (y < yRiver) ? (yRiver - riverHalfWidth - 2.0) : (yRiver + riverHalfWidth + 2.0);
    let bestTargetX = x;
    let bestTargetY = Math.max(12, Math.min(gridH - 12, riverShoreY));
    let minTargetDist = Math.abs(y - bestTargetY);

    // 3. Compara com os lagos de meandro / ferradura (Oxbow Lakes)
    const oxLakes = (ctx && ctx.OXBOW_LAKES && Array.isArray(ctx.OXBOW_LAKES)) ? ctx.OXBOW_LAKES : ((typeof OXBOW_LAKES !== 'undefined' && Array.isArray(OXBOW_LAKES)) ? OXBOW_LAKES : []);
    if (oxLakes.length > 0) {
      for (let k = 0; k < oxLakes.length; k++) {
        const ox = oxLakes[k];
        const dx = x - ox.cx;
        const dy = y - ox.cy;
        const dCenter = Math.hypot(dx, dy) || 1.0;
        const shoreDist = ox.r + (ox.width ? ox.width * 0.5 : 8.0) + 2.0;
        const oxShoreX = ox.cx + (dx / dCenter) * shoreDist;
        const oxShoreY = ox.cy + (dy / dCenter) * shoreDist;
        const dToOx = Math.hypot(x - oxShoreX, y - oxShoreY);
        if (dToOx < minTargetDist) {
          minTargetDist = dToOx;
          bestTargetX = oxShoreX;
          bestTargetY = oxShoreY;
        }
      }
    }

    return {
      x: Math.max(12, Math.min(gridW - 12, bestTargetX)),
      y: Math.max(12, Math.min(gridH - 12, bestTargetY)),
      dist: minTargetDist,
      isLocal: false
    };
  }

  /**
   * Verifica se o animal está posicionado na margem imediata da água ou em lâmina d'água rasa
   */
  function checkIsAtWaterBank(x, y, ctx) {
    const { matId, surfaceWater, MAT_WATER, GRID_WIDTH, GRID_HEIGHT, getIdx } = ctx;
    const gridW = GRID_WIDTH || 2048;
    const gridH = GRID_HEIGHT || 1024;
    const ix = Math.floor(x);
    const iy = Math.floor(y);
    if (ix < 1 || ix >= gridW - 1 || iy < 1 || iy >= gridH - 1) return false;

    const getCellIdx = (ctx && typeof ctx.getIdx === 'function') ? ctx.getIdx : ((px, py) => py * gridW + px);
    const curIdx = getCellIdx(ix, iy);
    if (surfaceWater && surfaceWater[curIdx] > 0.02) return true;
    if (matId && matId[curIdx] === MAT_WATER) return true;

    // Checagem em raio de 2 células vizinhas
    for (let dy = -2; dy <= 2; dy++) {
      for (let dx = -2; dx <= 2; dx++) {
        const nx = ix + dx, ny = iy + dy;
        if (nx >= 0 && nx < gridW && ny >= 0 && ny < gridH) {
          const nIdx = getIdx ? getIdx(nx, ny) : (ny * gridW + nx);
          if (matId && matId[nIdx] === MAT_WATER) return true;
          if (surfaceWater && surfaceWater[nIdx] > 0.06) return true;
        }
      }
    }

    // Margem calculada da calha do rio principal
    const fnRiverY = (ctx && typeof ctx.getRiverMainY === 'function') ? ctx.getRiverMainY : ((typeof getRiverMainY === 'function') ? getRiverMainY : null);
    if (fnRiverY) {
      const yRiver = fnRiverY(x);
      const riverHalfWidth = 28.0 + (x / gridW) * 12.0;
      const distToBank = Math.abs(Math.abs(y - yRiver) - riverHalfWidth);
      if (distToBank <= 4.8) return true;
    }

    return false;
  }

  /**
   * Atualização biológica universal da sede, consumo de água e vulnerabilidade
   */
  function updateThirstAndDrinking(a, dt, ctx) {
    if (!a || a.hp <= 0 || a.enteredNest) {
      return { isDrinking: false, isSeekingWater: false, targetX: a ? a.x : 0, targetY: a ? a.y : 0 };
    }

    // Peixes vivem 100% imersos em água doce: não acumulam sede
    const isFish = (a.species === 'tambaqui' || a.species === 'traira' || a.species === 'piranha');
    if (isFish) {
      a.thirst = 0.0;
      a.isDrinking = false;
      return { isDrinking: false, isSeekingWater: false, targetX: a.x, targetY: a.y };
    }

    if (a.thirst === undefined) a.thirst = 5.0 + Math.random() * 15.0;
    if (a.ambushTimer === undefined) a.ambushTimer = 0.0;
    else if (a.ambushTimer > 0) a.ambushTimer = Math.max(0, a.ambushTimer - dt);

    // Taxa de metabolismo de sede por espécie
    let thirstRate = 0.030;
    if (a.species === 'rat') thirstRate = 0.048;
    else if (a.species === 'cat') thirstRate = 0.038;
    else if (a.species === 'toucan' || a.species === 'carcara') thirstRate = 0.042;
    else if (a.species === 'tortoise') thirstRate = 0.016; // Répteis perdem água muito mais devagar
    else if (a.species === 'caiman') thirstRate = 0.012;  // Permanece na água a maior parte do tempo
    else if (a.species === 'ant' || a.species === 'termite' || a.species === 'bee') thirstRate = 0.026;

    // Atenuação de sede por orvalho/umidade local e chuva
    const gridW = ctx.GRID_WIDTH || 2048;
    const gridH = ctx.GRID_HEIGHT || 1024;
    const curX = Math.floor(a.x);
    const curY = Math.floor(a.y);
    const getCellIdx = (ctx && typeof ctx.getIdx === 'function') ? ctx.getIdx : ((cx, cy) => cy * gridW + cx);
    const curIdx = getCellIdx(curX, curY);
    const moistVal = (ctx.moisture && ctx.moisture[curIdx]) || 0.4;
    const isRaining = (ctx.weather === 'rain' || ctx.weather === 'storm');

    let moistureMitigation = (moistVal > 0.60) ? 0.75 : 1.0;
    if (isRaining) {
      // Chuva fornece hidratação direta das gotas
      moistureMitigation = -0.15;
    }

    a.thirst = Math.max(0, Math.min(100, a.thirst + thirstRate * moistureMitigation * dt));

    // Dano severo de desidratação crítica (> 88%)
    if (a.thirst >= 88.0) {
      a.hp -= 0.22 * dt;
      if (a.hp <= 0 && typeof totalThirstDeaths !== 'undefined') {
        totalThirstDeaths++;
      }
    }

    // Checagem de proximidade da margem d'água
    const atWaterEdge = checkIsAtWaterBank(a.x, a.y, ctx);

    // 1. INÍCIO DO COMPORTAMENTO DE BEBER ÁGUA
    if (atWaterEdge && a.thirst > 15.0 && !a.isDrinking && (!a.ambushTimer || a.ambushTimer <= 0)) {
      a.isDrinking = true;
      a.drinkingTimer = 3.5 + Math.random() * 3.0; // 3.5 a 6.5 segundos bebendo
      a.baseDefense = (a.baseDefense !== undefined) ? a.baseDefense : (a.defensePower || 0.0);
    }

    // 2. ANIMAL ATUALMENTE BEBENDO ÁGUA (ESTADO DE ALTA VULNERABILIDADE)
    if (a.isDrinking) {
      a.drinkingTimer = (a.drinkingTimer || 3.0) - dt;
      // Sede saciada rapidamente pelo fluxo contínuo de água doce
      a.thirst = Math.max(0, a.thirst - 32.0 * dt);

      // VULNERABILIDADE CRÍTICA:
      // Cabeça abaixada, foco total na água, audição e visão periférica comprometidas
      a.defensePower = 0.0;
      a.perceptionFactor = 0.25; // Alcance de detecção de perigo cai 75%
      a.currentSprintBoost = 0.0;

      // Se terminou de beber ou o timer esgotou:
      if (a.thirst <= 4.0 || a.drinkingTimer <= 0) {
        a.isDrinking = false;
        a.drinkingTimer = 0.0;
        a.waterTarget = null;
        if (a.baseDefense !== undefined) a.defensePower = a.baseDefense;
      }

      // Enquanto bebe, fica parado na margem
      return {
        isDrinking: true,
        isSeekingWater: false,
        targetX: a.x,
        targetY: a.y
      };
    }

    // 3. ANIMAL COM SEDE BUSCANDO ÁGUA
    if (a.thirst > 35.0 && (!a.ambushTimer || a.ambushTimer <= 0)) {
      // Atualiza ou reutiliza alvo de água
      if (!a.waterTarget || (Math.random() < 0.04)) {
        a.waterTarget = findNearestWaterShoreline(a.x, a.y, ctx);
      }

      const isUrgent = (a.thirst > 65.0);
      return {
        isDrinking: false,
        isSeekingWater: true,
        urgent: isUrgent,
        targetX: a.waterTarget.x,
        targetY: a.waterTarget.y
      };
    }

    return {
      isDrinking: false,
      isSeekingWater: false,
      targetX: a.x,
      targetY: a.y
    };
  }

  /**
   * Executa o ataque fulminante de emboscada de um predador contra presa bebendo na margem
   */
  function executeAmbushAttack(predator, prey, baseDmg, ctx) {
    if (!prey || prey.hp <= 0) return { damage: 0, isAmbush: false };

    let isAmbush = false;
    let finalDmg = baseDmg;

    // Presa bebendo água está completamente distraída e vulnerável
    if (prey.isDrinking) {
      isAmbush = true;
      finalDmg = baseDmg * 1.85; // Bote de emboscada: +85% de dano crítico fatal!
      prey.isDrinking = false;
      prey.isAmbushedWhileDrinking = true;
      prey.ambushTimer = 2.5;
      prey.currentSprintBoost = 2.4; // Pânico de fuga se sobreviver

      if (typeof console !== 'undefined' && console.log) {
        const predName = predator.name || predator.species;
        const preyName = prey.name || prey.species;
        console.log(`💥 [EMBOSCADA NA ÁGUA] ${predName} desferiu um bote fatal em ${preyName} enquanto bebia na margem! (${finalDmg.toFixed(1)} de dano crítico)`);
      }
    }

    prey.hp = Math.max(0, prey.hp - finalDmg);

    if (prey.hp <= 0) {
      if (ctx && typeof ctx.applyDeathDecomposition === 'function') {
        ctx.applyDeathDecomposition(prey.x, prey.y);
      }
      if (ctx && typeof ctx.onPredationSuccess === 'function') {
        ctx.onPredationSuccess(prey, predator);
      }
    }

    return { damage: finalDmg, isAmbush };
  }

  return {
    findNearestWaterShoreline,
    checkIsAtWaterBank,
    updateThirstAndDrinking,
    executeAmbushAttack
  };
})();

// Exportação para navegadores e Node.js
if (typeof window !== 'undefined') {
  window.HydrationSystem = HydrationSystem;
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = HydrationSystem;
}
