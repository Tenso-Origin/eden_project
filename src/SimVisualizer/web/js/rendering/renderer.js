// =========================================================================
// MÓDULO RENDERIZADOR: DIRECT UINT32 BUFFER 1024x1024 E ÍCONES VISUAIS DE FAUNA
// =========================================================================

let canvas = null;
let ctx = null;
let imgData = null;
let pixelBuffer = null;
let offscreenCanvas = null;
let offscreenCtx = null;
let renderFrameCounter = 0;
let lastRenderedLayer = null;

// Tabela Mestra de Ícones e Identidade Visual das Espécies
const SPECIES_VISUALS = {
  // Mamíferos
  'rat':         { icon: '🐁', label: 'Rato', color: '#ffea79', bg: 'rgba(45, 35, 10, 0.88)', border: '#facc15', size: 12 },
  'cat':         { icon: '🐈', label: 'Gato', color: '#f87171', bg: 'rgba(55, 15, 15, 0.88)', border: '#ef4444', size: 14 },

  // Aves
  'harpy':       { icon: '🦅', label: 'Harpia', color: '#38bdf8', bg: 'rgba(10, 30, 60, 0.92)', border: '#0284c7', size: 20 },
  'toucan':      { icon: '🦜', label: 'Tucano', color: '#fbbf24', bg: 'rgba(45, 30, 10, 0.88)', border: '#f59e0b', size: 13 },
  'carcara':     { icon: '🪶', label: 'Carcará', color: '#fb923c', bg: 'rgba(55, 20, 10, 0.88)', border: '#ea580c', size: 13 },

  // Peixes do Lago
  'tambaqui':    { icon: '🐟', label: 'Tambaqui', color: '#34d399', bg: 'rgba(6, 40, 28, 0.88)', border: '#10b981', size: 12 },
  'traira':      { icon: '🎣', label: 'Traíra', color: '#4ade80', bg: 'rgba(15, 38, 22, 0.92)', border: '#16a34a', size: 13 },
  'piranha':     { icon: '🦈', label: 'Piranha', color: '#f43f5e', bg: 'rgba(55, 10, 20, 0.92)', border: '#e11d48', size: 12 },

  // Répteis
  'tortoise':    { icon: '🐢', label: 'Jabuti', color: '#a3e635', bg: 'rgba(25, 45, 10, 0.88)', border: '#84cc16', size: 13 },
  'caiman':      { icon: '🐊', label: 'Jacaré', color: '#4ade80', bg: 'rgba(12, 45, 22, 0.92)', border: '#22c55e', size: 16 },

  // Insetos (10 espécies)
  'ant':         { icon: '🐜', label: 'Saúva', color: '#d97706', bg: 'rgba(35, 20, 8, 0.80)', border: '#b45309', size: 9 },
  'bee':         { icon: '🐝', label: 'Jataí', color: '#fde047', bg: 'rgba(40, 35, 10, 0.80)', border: '#eab308', size: 9 },
  'butterfly':   { icon: '🦋', label: 'Morfo', color: '#60a5fa', bg: 'rgba(15, 30, 55, 0.80)', border: '#3b82f6', size: 10 },
  'dragonfly':   { icon: '🪰', label: 'Libélula', color: '#2dd4bf', bg: 'rgba(10, 40, 38, 0.80)', border: '#14b8a6', size: 10 },
  'beetle':      { icon: '🪲', label: 'Hércules', color: '#84cc16', bg: 'rgba(20, 35, 12, 0.80)', border: '#65a30d', size: 9 },
  'mosquito':    { icon: '🦟', label: 'Mosquito', color: '#cbd5e1', bg: 'rgba(25, 30, 35, 0.80)', border: '#64748b', size: 8 },
  'grasshopper': { icon: '🦗', label: 'Esperança', color: '#a3e635', bg: 'rgba(18, 38, 14, 0.80)', border: '#84cc16', size: 9 },
  'mantis':      { icon: '🍃', label: 'Louva-a-deus', color: '#4ade80', bg: 'rgba(14, 38, 18, 0.80)', border: '#22c55e', size: 10 },
  'roach':       { icon: '🪳', label: 'Barata-mata', color: '#b45309', bg: 'rgba(32, 18, 10, 0.80)', border: '#92400e', size: 9 },
  'termite':     { icon: '🪵', label: 'Cupim', color: '#a8a29e', bg: 'rgba(30, 30, 30, 0.80)', border: '#78716c', size: 8 }
};

/**
 * Inicialização dos buffers de pixel e canvas 1024x1024
 */
function initRenderer() {
  canvas = document.getElementById('viewportCanvas');
  if (!canvas) return;

  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  canvas.width = gw;
  canvas.height = gh;
  ctx = canvas.getContext('2d');
  imgData = ctx.createImageData(gw, gh);
  pixelBuffer = new Uint32Array(imgData.data.buffer);

  offscreenCanvas = document.createElement('canvas');
  offscreenCanvas.width = gw;
  offscreenCanvas.height = gh;
  offscreenCtx = offscreenCanvas.getContext('2d');
}

/**
 * Renderização ultrarrápida 1024x1024 (60 FPS) via Direct Uint32 PixelBuffer
 */
function render() {
  if (!canvas || !ctx || !pixelBuffer) {
    initRenderer();
    if (!canvas || !ctx || !pixelBuffer) return;
  }

  const gw = (typeof GRID_WIDTH !== 'undefined') ? GRID_WIDTH : 2048;
  const gh = (typeof GRID_HEIGHT !== 'undefined') ? GRID_HEIGHT : 1024;

  renderFrameCounter++;
  const needsTerrainUpdate = (renderFrameCounter % 2 === 1) || (lastRenderedLayer !== currentLayer);

  // 1. Atualização do Terreno (Throttle inteligente a cada 2 frames ou na troca de camada)
  if (needsTerrainUpdate) {
    lastRenderedLayer = currentLayer;
    for (let y = 0; y < gh; y++) {
    const rowOffset = y * gw;

    for (let x = 0; x < gw; x++) {
      const idx = rowOffset + x;
      let r = 0, g = 0, b = 0;

      if (currentLayer === 'composite') {
        if (matId[idx] === MAT_WATER || surfaceWater[idx] > 0.8) {
          const depthFactor = Math.min(1.0, Math.max(0, -elevation[idx] / 100.0));
          r = Math.floor(15 - depthFactor * 10);
          g = Math.floor(95 - depthFactor * 65);
          b = Math.floor(220 - depthFactor * 70);
        } else if (matId[idx] === MAT_ICE || (elevation[idx] > 1600.0 && temp[idx] < 2.0)) {
          r = 230; g = 245; b = 255;
        } else if (matId[idx] === MAT_STONE && elevation[idx] > 300.0) {
          const rockBright = Math.min(1.0, elevation[idx] / 2000.0);
          r = Math.floor(100 + rockBright * 70);
          g = Math.floor(100 + rockBright * 70);
          b = Math.floor(105 + rockBright * 70);
        } else if (biomass[idx] > 20) {
          const f = Math.min(1.0, biomass[idx] / 85.0);
          r = Math.floor(20 * (1 - f) + 25 * f);
          g = Math.floor(90 * (1 - f) + 175 * f);
          b = Math.floor(20 * (1 - f) + 30 * f);
        } else if (matId[idx] === MAT_SAND || moisture[idx] < 0.1) {
          r = 215; g = 185; b = 110;
        } else {
          r = 110; g = 80; b = 50;
        }

        if (cumulativeErosion[idx] > 0.05) {
          r = Math.floor(r * 0.7);
          g = Math.floor(g * 0.7);
          b = Math.floor(b * 0.85 + 20);
        }
      } else if (currentLayer === 'temp') {
        const tNorm = Math.max(0, Math.min(1.0, (temp[idx] + 15) / 60));
        r = Math.floor(tNorm * 255);
        b = Math.floor((1 - tNorm) * 255);
        g = Math.floor(Math.sin(tNorm * Math.PI) * 200);
      } else if (currentLayer === 'moisture') {
        if (surfaceWater[idx] > 0.2) {
          r = 10; g = 90; b = 255;
        } else {
          const m = Math.max(0, Math.min(1.0, moisture[idx]));
          r = 12;
          g = Math.floor(m * 160 + 25);
          b = Math.floor(m * 220 + 35);
        }
      } else if (currentLayer === 'erosion') {
        if (elevation[idx] < 0) {
          const seaD = Math.min(1.0, -elevation[idx] / 100.0);
          r = 0; g = Math.floor(40 * (1 - seaD)); b = Math.floor(180 - seaD * 80);
        } else {
          const altN = Math.min(1.0, elevation[idx] / 2000.0);
          r = Math.floor(altN * 240 + 25);
          g = Math.floor(altN * 240 + 25);
          b = Math.floor(altN * 240 + 25);

          if (cumulativeErosion[idx] > 0.02) {
            r = 255;
            g = Math.floor(180 - Math.min(1.0, cumulativeErosion[idx]) * 120);
            b = 30;
          }
        }
      } else if (currentLayer === 'biomass') {
        const bioN = Math.max(0, Math.min(1.0, biomass[idx] / 100));
        r = Math.floor((1 - bioN) * 50 + 15);
        g = Math.floor(bioN * 230 + 25);
        b = 15;
      } else if (currentLayer === 'fauna') {
        r = 30; g = 40; b = 45;
        if (matId[idx] === MAT_WATER) { r = 15; g = 35; b = 80; }
        else if (elevation[idx] > 1600.0) { r = 180; g = 190; b = 200; }
      } else if (currentLayer === 'scent') {
        r = 24; g = 28; b = 32;
        if (matId[idx] === MAT_WATER) { r = 10; g = 25; b = 60; }
        else if (ratScent[idx] > 0.02) {
          const s = Math.min(1.0, ratScent[idx]);
          r = Math.floor(255 * s + 24 * (1 - s));
          g = Math.floor(210 * s + 28 * (1 - s));
          b = Math.floor(40 * s + 32 * (1 - s));
        }
      } else if (currentLayer === 'grains') {
        if (matId[idx] === MAT_WATER) {
          r = 15; g = 35; b = 75;
        } else if (grains[idx] > 0.5) {
          const gN = Math.min(1.0, grains[idx] / 60.0);
          r = Math.floor(255 * gN + 40 * (1 - gN));
          g = Math.floor(190 * gN + 60 * (1 - gN));
          b = Math.floor(20 * gN + 25 * (1 - gN));
        } else {
          r = 28; g = 38; b = 32;
        }
      } else if (currentLayer === 'nests') {
        if (matId[idx] === MAT_WATER) {
          r = 15; g = 35; b = 75;
        } else {
          const bioN = Math.min(1.0, biomass[idx] / 100.0);
          r = Math.floor(25 + bioN * 35);
          g = Math.floor(35 + bioN * 80);
          b = Math.floor(25 + bioN * 35);
        }
      }

      if (y === Math.floor(gh / 2 - 1) && currentLayer === 'composite') {
        r = Math.min(255, r + 50);
        g = Math.min(255, g + 40);
      }

      pixelBuffer[idx] = (255 << 24) | (b << 16) | (g << 8) | r;
    }
  }
  // Blit no offscreenCanvas
  offscreenCtx.putImageData(imgData, 0, 0);
  }

  // Limpa e aplica zoom/pan na tela principal
  ctx.fillStyle = '#05080e';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.save();
  ctx.translate(canvas.width / 2, canvas.height / 2);
  ctx.scale(zoomLevel, zoomLevel);
  ctx.translate(-panX, -panY);
  ctx.imageSmoothingEnabled = (zoomLevel <= 1.0);
  ctx.drawImage(offscreenCanvas, 0, 0);

  if (zoomLevel < 1.0) {
    ctx.save();
    // Borda exterior do mundo 2048x1024
    ctx.strokeStyle = '#58a6ff';
    ctx.lineWidth = Math.max(1.5, 2.0 / zoomLevel);
    ctx.strokeRect(0, 0, gw, gh);

    // Linhas guias do grid a cada 256 metros
    ctx.strokeStyle = 'rgba(88, 166, 255, 0.22)';
    ctx.lineWidth = Math.max(0.8, 1.0 / zoomLevel);
    ctx.setLineDash([4 / zoomLevel, 4 / zoomLevel]);
    
    // Linhas verticais (X de 256 a 2048)
    for (let gx = 256; gx < gw; gx += 256) {
      ctx.beginPath();
      ctx.moveTo(gx, 0);
      ctx.lineTo(gx, gh);
      ctx.stroke();
    }
    // Linhas horizontais (Y de 256 a 1024)
    for (let gy = 256; gy < gh; gy += 256) {
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(gw, gy);
      ctx.stroke();
    }
    ctx.setLineDash([]);

    // Rótulos numéricos no eixo X (Oeste -> Leste)
    const fontSize = Math.max(12, Math.round(14 / zoomLevel));
    ctx.font = `bold ${fontSize}px 'JetBrains Mono', monospace`;
    ctx.fillStyle = '#58a6ff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillText('0m (Oeste/Serras)', 70, -6 / zoomLevel);
    ctx.fillText('512m', 512, -6 / zoomLevel);
    ctx.fillText('1024m (Centro Fluvial)', 1024, -6 / zoomLevel);
    ctx.fillText('1536m', 1536, -6 / zoomLevel);
    ctx.fillText('2048m (Leste/Foz)', gw - 70, -6 / zoomLevel);

    // Rótulos numéricos no eixo Y (Norte -> Sul)
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    ctx.fillText('0m', -8 / zoomLevel, 15);
    ctx.fillText('256m', -8 / zoomLevel, 256);
    ctx.fillText('512m (Rio Solimões)', -8 / zoomLevel, 512);
    ctx.fillText('768m', -8 / zoomLevel, 768);
    ctx.fillText('1024m', -8 / zoomLevel, gh - 15);

    // Título de Dimensão da Bacia Amazônica
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    ctx.fillStyle = '#3fb950';
    ctx.font = `bold ${Math.max(14, Math.round(18 / zoomLevel))}px 'Outfit', sans-serif`;
    ctx.fillText('BACIA AMAZÔNICA: 2048 METROS (OESTE-LESTE) x 1024 METROS (NORTE-SUL) [2.097.152 CÉLULAS]', gw / 2, gh + 12 / zoomLevel);

    ctx.restore();
  }

  // Refúgios Naturais
  if (naturalRefuges && naturalRefuges.length > 0) {
    for (let ri = 0; ri < naturalRefuges.length; ri++) {
      const ref = naturalRefuges[ri];
      ctx.beginPath();
      if (ref.type === 'log') {
        ctx.ellipse(ref.x, ref.y, 3.2, 1.3, 0.5, 0, Math.PI * 2);
        ctx.fillStyle = '#5c3a21';
        ctx.strokeStyle = '#382314';
        ctx.lineWidth = 0.8;
        ctx.fill();
        ctx.stroke();
      } else if (ref.type === 'rock') {
        ctx.arc(ref.x, ref.y, 2.3, 0, Math.PI * 2);
        ctx.fillStyle = '#64748b';
        ctx.strokeStyle = '#334155';
        ctx.lineWidth = 0.8;
        ctx.fill();
        ctx.stroke();
      } else {
        ctx.arc(ref.x, ref.y, 2.7, 0, Math.PI * 2);
        ctx.fillStyle = '#14532d';
        ctx.strokeStyle = '#16a34a';
        ctx.lineWidth = 0.7;
        ctx.fill();
        ctx.stroke();
      }
    }
  }

  // Touceiras de Flores Silvestres Amazônicas (Orquídeas, Bromélias, Ipês - Néctar para Abelhas)
  if (typeof flowerPatches !== 'undefined' && flowerPatches && flowerPatches.length > 0) {
    for (let fpi = 0; fpi < flowerPatches.length; fpi++) {
      const fp = flowerPatches[fpi];
      if (fp.x < minVisX - 15 || fp.x > maxVisX + 15 || fp.y < minVisY - 15 || fp.y > maxVisY + 15) continue;

      const r = fp.radius || 4.2;
      const color = fp.color || '#f43f5e';

      // Halo floral e pétalas
      ctx.beginPath();
      ctx.arc(fp.x, fp.y, r, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = 4;
      ctx.fill();
      ctx.shadowBlur = 0;

      // Miolo da flor
      ctx.beginPath();
      ctx.arc(fp.x, fp.y, r * 0.42, 0, Math.PI * 2);
      ctx.fillStyle = '#facc15';
      ctx.fill();

      // Indicador com ícone em zoom aproximado
      if (zoomLevel >= 1.0) {
        ctx.fillStyle = '#ffffff';
        ctx.font = '7px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(fp.icon || '🌸', fp.x, fp.y - r - 2.0);
      }
    }
  }

  // Ninhos e Tocas Maternais
  if (nests && nests.length > 0) {
    for (let ni = 0; ni < nests.length; ni++) {
      const n = nests[ni];
      ctx.beginPath();
      if (n.species === 'harpy') {
        ctx.arc(n.x, n.y, 5.0, 0, Math.PI * 2);
        ctx.fillStyle = '#10b981';
        ctx.shadowColor = 'rgba(16, 185, 129, 0.9)';
        ctx.shadowBlur = 8;
        ctx.fill();
        ctx.strokeStyle = '#58a6ff';
        ctx.lineWidth = 1.4;
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (n.species === 'cat') {
        ctx.arc(n.x, n.y, 3.5, 0, Math.PI * 2);
        ctx.fillStyle = '#cd853f';
        ctx.shadowColor = 'rgba(205, 133, 63, 0.8)';
        ctx.shadowBlur = 5;
        ctx.fill();
        ctx.strokeStyle = '#f85149';
        ctx.lineWidth = 1.0;
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (n.species === 'ant') {
        // Formigueiro de Saúva
        ctx.arc(n.x, n.y, 4.2, 0, Math.PI * 2);
        ctx.fillStyle = '#b45309';
        ctx.shadowColor = 'rgba(180, 83, 9, 0.8)';
        ctx.shadowBlur = 6;
        ctx.fill();
        ctx.strokeStyle = '#f59e0b';
        ctx.lineWidth = 1.2;
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (n.species === 'termite') {
        // Cupinzeiro de Montículo
        ctx.arc(n.x, n.y, 3.8, 0, Math.PI * 2);
        ctx.fillStyle = '#78350f';
        ctx.shadowColor = 'rgba(120, 53, 15, 0.8)';
        ctx.shadowBlur = 5;
        ctx.fill();
        ctx.strokeStyle = '#d97706';
        ctx.lineWidth = 1.1;
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else if (n.species === 'bee') {
        // Colmeia Jataí
        ctx.arc(n.x, n.y, 3.6, 0, Math.PI * 2);
        ctx.fillStyle = '#facc15';
        ctx.shadowColor = 'rgba(250, 204, 21, 0.85)';
        ctx.shadowBlur = 6;
        ctx.fill();
        ctx.strokeStyle = '#ca8a04';
        ctx.lineWidth = 1.2;
        ctx.stroke();
        ctx.shadowBlur = 0;
      } else {
        ctx.arc(n.x, n.y, 2.4, 0, Math.PI * 2);
        ctx.fillStyle = '#8b5a2b';
        ctx.strokeStyle = '#d29922';
        ctx.lineWidth = 0.9;
        ctx.fill();
        ctx.stroke();
      }

      // Representação das Cargas Internas da Colônia (Ícones de Carga / População no Ninho)
      if (n.isSocialColony || ['ant', 'termite', 'bee'].includes(n.species)) {
        const charges = (n.charges !== undefined) ? n.charges : 4;
        const color = (n.species === 'ant' ? '#f59e0b' : (n.species === 'bee' ? '#facc15' : '#d97706'));

        ctx.save();
        ctx.fillStyle = 'rgba(9, 13, 19, 0.88)';
        ctx.strokeStyle = color;
        ctx.lineWidth = 0.8;
        const badgeW = 20.0;
        const badgeH = 9.0;
        const bx = n.x - badgeW / 2;
        const by = n.y - 12.0;
        ctx.beginPath();
        if (ctx.roundRect) ctx.roundRect(bx, by, badgeW, badgeH, 2.5);
        else ctx.rect(bx, by, badgeW, badgeH);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#f0f6fc';
        ctx.font = 'bold 7px "JetBrains Mono", monospace';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(`${charges}📦`, n.x, by + badgeH / 2);

        // Pontos de carga orbitando a colônia
        const visibleDots = Math.min(charges, 8);
        for (let d = 0; d < visibleDots; d++) {
          const ang = (d / visibleDots) * Math.PI * 2;
          const dotDist = 6.2;
          ctx.beginPath();
          ctx.arc(n.x + Math.cos(ang) * dotDist, n.y + Math.sin(ang) * dotDist, 0.9, 0, Math.PI * 2);
          ctx.fillStyle = color;
          ctx.fill();
        }

        // Coroa da Rainha se viva
        if (n.queen && n.queen.isAlive) {
          ctx.fillStyle = '#facc15';
          ctx.font = '6px sans-serif';
          ctx.fillText('👑', n.x + 8.5, by + 1.0);
        }
        ctx.restore();
      }

      // Raio de forrageamento / atuação da colônia
      if (currentLayer === 'nests' && n.forageRadius) {
        ctx.beginPath();
        ctx.setLineDash([3, 3]);
        ctx.arc(n.x, n.y, n.forageRadius, 0, Math.PI * 2);
        ctx.strokeStyle = (n.species === 'ant' ? 'rgba(245, 158, 11, 0.35)' : (n.species === 'bee' ? 'rgba(250, 204, 21, 0.35)' : 'rgba(217, 119, 6, 0.35)'));
        ctx.lineWidth = 1.0;
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }
  }

  // Frustum Culling: calcula a janela visível no espaço do mundo
  const halfViewW = (canvas.width / 2) / zoomLevel;
  const halfViewH = (canvas.height / 2) / zoomLevel;
  const minVisX = panX - halfViewW - 30;
  const maxVisX = panX + halfViewW + 30;
  const minVisY = panY - halfViewH - 30;
  const maxVisY = panY + halfViewH + 30;

  // Fauna Completa com Frustum Culling e Batching Inteligente
  if (animals && animals.length > 0) {
    const isZoomOut = (zoomLevel < 0.65);
    let currentSetFont = "";

    for (const a of animals) {
      if (a.hp <= 0) continue;
      const px = a.x;
      const py = a.y;

      // Descarta animais fora do campo de visão da câmera (Zero custo GPU)
      if (px < minVisX || px > maxVisX || py < minVisY || py > maxVisY) continue;

      const spec = SPECIES_VISUALS[a.species] || { icon: '●', label: a.species, color: '#ffffff', bg: 'rgba(0,0,0,0.8)', border: '#ffffff', size: 9 };
      // Ajuste de escala dinâmico proporcional ao zoom para manter nitidez
      const baseSize = spec.size;
      const scaleAdj = (zoomLevel >= 1.5) ? 1.0 : (zoomLevel >= 0.8 ? 1.15 : 1.35);
      const iconPx = Math.max(7, Math.round((baseSize * scaleAdj) / Math.sqrt(zoomLevel)));
      const badgeR = iconPx * 0.72;

      // Círculos sensoriais em camadas de debug/telemetria
      if (currentLayer === 'fauna' || currentLayer === 'scent') {
        if (a.species === 'rat') {
          ctx.beginPath();
          ctx.arc(px, py, 15, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(255, 235, 59, 0.35)';
          ctx.lineWidth = 1;
          ctx.stroke();
        } else if (a.species === 'cat') {
          ctx.beginPath();
          ctx.arc(px, py, 25, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(255, 77, 77, 0.40)';
          ctx.lineWidth = 1.2;
          ctx.stroke();

          ctx.beginPath();
          ctx.setLineDash([4, 4]);
          ctx.arc(px, py, 90, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(88, 166, 255, 0.25)';
          ctx.lineWidth = 1;
          ctx.stroke();
          ctx.setLineDash([]);
        } else if (a.species === 'caiman') {
          ctx.beginPath();
          ctx.arc(px, py, 24, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(74, 222, 128, 0.35)';
          ctx.lineWidth = 1.2;
          ctx.stroke();
        }
      }

      // 1. Placa/Badge de Fundo (Alto Contraste contra qualquer terreno)
      ctx.beginPath();
      ctx.arc(px, py, badgeR, 0, Math.PI * 2);
      ctx.fillStyle = spec.bg;
      ctx.fill();
      ctx.strokeStyle = spec.border;
      ctx.lineWidth = Math.max(0.8, 1.2 / Math.sqrt(zoomLevel));
      ctx.stroke();

      // 2. Ícone Expressivo de Alta Legibilidade
      ctx.font = `${iconPx}px 'Segoe UI Emoji', 'Apple Color Emoji', 'Noto Color Emoji', sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(spec.icon, px, py);

      // 3. Indicadores de Estado Especial:
      // Fêmea Grávida ou em Cio
      if (a.isPregnant) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 2.2, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 182, 193, 0.95)';
        ctx.lineWidth = 1.4;
        ctx.stroke();
      } else if (a.sex === 'female' && a.estrusDurationRemaining > 0) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 2.4, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 64, 129, 0.95)';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }

      // Rainha Virgem em Voo Nupcial (Revoada)
      if (a.isVirginQueen) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 3.2, 0, Math.PI * 2);
        ctx.strokeStyle = '#facc15';
        ctx.lineWidth = 1.8;
        ctx.stroke();
      }

      // Traíra em Tocaia / Emboscada
      if (a.isLurking) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 2.5, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(74, 222, 128, 0.75)';
        ctx.lineWidth = 1.4;
        ctx.setLineDash([2, 2]);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Piranha / Predador em Frenesi
      if (a.frenzyTimer > 0) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 3.0, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(239, 68, 68, 0.95)';
        ctx.lineWidth = 1.6;
        ctx.stroke();
      }

      // Jabuti Retraído na Carapaça
      if (a.isRetracted) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 2.5, 0, Math.PI * 2);
        ctx.strokeStyle = '#84cc16';
        ctx.lineWidth = 2.0;
        ctx.stroke();
      }

      // Jacaré em Banho de Sol (Basking)
      if (a.isBasking) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 3.0, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(250, 204, 21, 0.85)';
        ctx.lineWidth = 1.4;
        ctx.setLineDash([2, 2]);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Escudo de Imunidade em Toca / Refúgio
      if (typeof isProtectedInBurrowOrRefuge !== 'undefined' && isProtectedInBurrowOrRefuge(a)) {
        ctx.beginPath();
        ctx.arc(px, py, badgeR + 2.6, 0, Math.PI * 2);
        ctx.strokeStyle = '#38bdf8';
        ctx.lineWidth = 1.2;
        ctx.setLineDash([2, 2]);
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // Indicador de Sono
      if (a.isSleeping) {
        ctx.font = `bold ${Math.max(6, Math.round(iconPx * 0.65))}px sans-serif`;
        ctx.fillStyle = '#38bdf8';
        ctx.fillText('z', px + badgeR + 1, py - badgeR);
      }
    }
  }

  // Harpias Amazônicas
  if (currentScenario === 'amazon' && harpies && harpies.length > 0) {
    for (let hi = 0; hi < harpies.length; hi++) {
      const h = harpies[hi];
      if (h.hp <= 0 || h.migrated) continue;

      const shadowDist = h.z * 0.25;
      const shadowScale = Math.max(1.2, 5.0 - h.z * 0.08);
      ctx.beginPath();
      ctx.ellipse(h.x + shadowDist * 0.5, h.y + shadowDist * 0.8, shadowScale * 1.6, shadowScale * 0.8, 0.4, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
      ctx.fill();

      const renderAirY = h.y - h.z * 0.35;
      const wingspan = (h.state === 'dive') ? 4.5 : 7.2;

      ctx.save();
      ctx.translate(h.x, renderAirY);

      let rotAngle = h.flightAngle + Math.PI / 2;
      if (h.state === 'dive' && h.target) {
        rotAngle = Math.atan2(h.target.y - h.y, h.target.x - h.x) + Math.PI / 2;
      }
      ctx.rotate(rotAngle);

      ctx.beginPath();
      ctx.moveTo(-wingspan, 1.2);
      ctx.quadraticCurveTo(-wingspan * 0.4, -2.5, 0, -1.0);
      ctx.quadraticCurveTo(wingspan * 0.4, -2.5, wingspan, 1.2);
      ctx.lineTo(wingspan * 0.7, 2.5);
      ctx.lineTo(0, 0.5);
      ctx.lineTo(-wingspan * 0.7, 2.5);
      ctx.closePath();
      ctx.fillStyle = (h.sex === 'female') ? '#263238' : '#37474f';
      ctx.fill();

      ctx.beginPath();
      ctx.ellipse(0, 0, 1.3, 3.2, 0, 0, Math.PI * 2);
      ctx.fillStyle = '#eceff1';
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(-0.8, -3.2);
      ctx.lineTo(0, -4.5);
      ctx.lineTo(0.8, -3.2);
      ctx.fillStyle = '#263238';
      ctx.fill();

      if (h.hp < 50) {
        ctx.beginPath();
        ctx.arc(0, 0, wingspan * 0.8, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(248, 81, 73, 0.7)';
        ctx.lineWidth = 1.0;
        ctx.stroke();
      }

      ctx.restore();
    }
  }

  ctx.restore();
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.Renderer = {
    initRenderer,
    render
  };
  window.initRenderer = initRenderer;
  window.render = render;
}
