// =========================================================================
// MÓDULO RENDERIZADOR: DIRECT UINT32 BUFFER 512x512 E SOBREPOSIÇÕES GRÁFICAS
// =========================================================================

let canvas = null;
let ctx = null;
let imgData = null;
let pixelBuffer = null;
let offscreenCanvas = null;
let offscreenCtx = null;

/**
 * Inicialização dos buffers de pixel e canvas
 */
function initRenderer() {
  canvas = document.getElementById('viewportCanvas');
  if (!canvas) return;
  ctx = canvas.getContext('2d');
  imgData = ctx.createImageData(CHUNK_SIZE, CHUNK_SIZE);
  pixelBuffer = new Uint32Array(imgData.data.buffer);

  offscreenCanvas = document.createElement('canvas');
  offscreenCanvas.width = CHUNK_SIZE;
  offscreenCanvas.height = CHUNK_SIZE;
  offscreenCtx = offscreenCanvas.getContext('2d');
}

/**
 * Renderização ultrarrápida 512x512 (60 FPS) via Direct Uint32 PixelBuffer
 */
function render() {
  if (!canvas || !ctx || !pixelBuffer) {
    initRenderer();
    if (!canvas || !ctx || !pixelBuffer) return;
  }

  // Loop contíguo sobre 262.144 pixels diretamente no buffer nativo
  for (let y = 0; y < CHUNK_SIZE; y++) {
    const rowOffset = y * CHUNK_SIZE;

    for (let x = 0; x < CHUNK_SIZE; x++) {
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

      if (y === 255 && currentLayer === 'composite') {
        r = Math.min(255, r + 50);
        g = Math.min(255, g + 40);
      }

      pixelBuffer[idx] = (255 << 24) | (b << 16) | (g << 8) | r;
    }
  }

  // Blit no offscreenCanvas
  offscreenCtx.putImageData(imgData, 0, 0);

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
    ctx.strokeStyle = 'rgba(88, 166, 255, 0.45)';
    ctx.lineWidth = 1.0 / zoomLevel;
    ctx.strokeRect(0, 0, CHUNK_SIZE, CHUNK_SIZE);
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
      } else {
        ctx.arc(n.x, n.y, 2.4, 0, Math.PI * 2);
        ctx.fillStyle = '#8b5a2b';
        ctx.strokeStyle = '#d29922';
        ctx.lineWidth = 0.9;
        ctx.fill();
        ctx.stroke();
      }
    }
  }

  // Fauna Terrestre (Ratos e Gatos)
  if (animals && animals.length > 0) {
    for (const a of animals) {
      const px = a.x;
      const py = a.y;

      if (currentLayer === 'fauna' || currentLayer === 'scent') {
        if (a.species === 'rat') {
          ctx.beginPath();
          ctx.arc(px, py, 15, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(255, 235, 59, 0.4)';
          ctx.lineWidth = 1;
          ctx.stroke();
        } else if (a.species === 'cat') {
          ctx.beginPath();
          ctx.arc(px, py, 25, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(255, 77, 77, 0.45)';
          ctx.lineWidth = 1.2;
          ctx.stroke();

          ctx.beginPath();
          ctx.setLineDash([4, 4]);
          ctx.arc(px, py, 90, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(88, 166, 255, 0.3)';
          ctx.lineWidth = 1;
          ctx.stroke();
          ctx.setLineDash([]);
        }
      }

      ctx.beginPath();
      const rad = (a.species === 'cat') ? 3.0 : 2.0;
      ctx.arc(px, py, rad, 0, Math.PI * 2);

      let animalColor = '#ffe135';
      let glowColor = 'rgba(255, 225, 53, 0.9)';

      if (a.species === 'cat') {
        if (a.sex === 'female') {
          animalColor = '#ff7b72';
          glowColor = 'rgba(255, 123, 114, 0.9)';
        } else {
          animalColor = '#991b1b';
          glowColor = 'rgba(153, 27, 27, 0.9)';
        }
      } else {
        if (a.sex === 'female') {
          animalColor = '#fff59d';
          glowColor = 'rgba(255, 245, 157, 0.9)';
        } else {
          animalColor = '#d48800';
          glowColor = 'rgba(212, 136, 0, 0.9)';
        }
      }

      ctx.fillStyle = animalColor;
      ctx.shadowColor = glowColor;
      ctx.shadowBlur = (a.species === 'cat') ? 6 : 4;
      ctx.fill();
      ctx.shadowBlur = 0;

      // Halo de prenhez ou cio
      if (a.isPregnant) {
        ctx.beginPath();
        ctx.arc(px, py, rad + 1.8, 0, Math.PI * 2);
        ctx.strokeStyle = (a.species === 'cat') ? 'rgba(255, 182, 193, 0.85)' : 'rgba(255, 255, 224, 0.85)';
        ctx.lineWidth = 1.2;
        ctx.stroke();
      } else if (a.sex === 'female' && a.estrusDurationRemaining > 0) {
        ctx.beginPath();
        ctx.arc(px, py, rad + 2.2, 0, Math.PI * 2);
        ctx.strokeStyle = (a.species === 'cat') ? 'rgba(255, 64, 129, 0.95)' : 'rgba(255, 152, 0, 0.95)';
        ctx.lineWidth = 1.4;
        ctx.stroke();
      }

      // Escudo de imunidade ativa
      if (typeof isProtectedInBurrowOrRefuge !== 'undefined' && isProtectedInBurrowOrRefuge(a)) {
        ctx.beginPath();
        ctx.arc(px, py, rad + 2.2, 0, Math.PI * 2);
        ctx.strokeStyle = '#38bdf8';
        ctx.lineWidth = 1.0;
        ctx.setLineDash([2, 2]);
        ctx.stroke();
        ctx.setLineDash([]);
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
