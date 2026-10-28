// =========================================================================
// MÓDULO DE INSETOS NEOTROPICAIS (10 ESPÉCIES DA BIODIVERSIDADE AMAZÔNICA)
// =========================================================================

/**
 * Criação da população inicial de insetos (10 espécies)
 */
function createInitialInsects(lakeCenterX = 512.0, lakeCenterY = 512.0, lakeRadius = 100.0, CHUNK_SIZE = 1024) {
  const insectList = [];

  const SPECIES_CONFIG = [
    { species: 'ant', count: 35, name: 'Formiga-saúva', diet: 'herbivore', spd: 1.1, icon: '🐜', zone: 'forest' },
    { species: 'bee', count: 25, name: 'Abelha-jataí', diet: 'herbivore', spd: 2.8, icon: '🐝', zone: 'flowers' },
    { species: 'butterfly', count: 25, name: 'Borboleta-morfo', diet: 'herbivore', spd: 2.2, icon: '🦋', zone: 'clearings' },
    { species: 'dragonfly', count: 20, name: 'Libélula-imperador', diet: 'carnivore', spd: 3.8, icon: '🪰', zone: 'lake' },
    { species: 'beetle', count: 22, name: 'Besouro-hércules', diet: 'decomposer', spd: 0.9, icon: '🪲', zone: 'forest' },
    { species: 'mosquito', count: 35, name: 'Mosquito-prego', diet: 'carnivore', spd: 2.0, icon: '🦟', zone: 'lake' },
    { species: 'grasshopper', count: 30, name: 'Gafanhoto-esperança', diet: 'herbivore', spd: 2.4, icon: '🦗', zone: 'grassland' },
    { species: 'mantis', count: 18, name: 'Louva-a-deus', diet: 'carnivore', spd: 1.2, icon: '🍃', zone: 'vegetation' },
    { species: 'roach', count: 25, name: 'Barata-da-mata', diet: 'decomposer', spd: 1.8, icon: '🪳', zone: 'forest' },
    { species: 'termite', count: 30, name: 'Cupim-da-terra', diet: 'decomposer', spd: 0.8, icon: '🪵', zone: 'wood' }
  ];

  let idCounter = 8000;

  for (const cfg of SPECIES_CONFIG) {
    for (let i = 0; i < cfg.count; i++) {
      let x, y;
      if (cfg.zone === 'lake') {
        // Perto da água do lago
        const angle = Math.random() * Math.PI * 2;
        const r = lakeRadius * (0.8 + Math.random() * 0.35);
        x = lakeCenterX + Math.cos(angle) * r;
        y = lakeCenterY + Math.sin(angle) * r;
      } else if (cfg.zone === 'grassland') {
        // Várzea aberta de gramíneas e arroz
        const angle = Math.random() * Math.PI * 2;
        const r = lakeRadius + 20.0 + Math.random() * 120.0;
        x = lakeCenterX + Math.cos(angle) * r;
        y = lakeCenterY + Math.sin(angle) * r;
      } else {
        // Floresta densa
        x = 40 + Math.random() * (CHUNK_SIZE - 80);
        y = 40 + Math.random() * (CHUNK_SIZE - 80);
      }

      x = Math.max(10, Math.min(CHUNK_SIZE - 10, x));
      y = Math.max(10, Math.min(CHUNK_SIZE - 10, y));

      insectList.push({
        id: idCounter++,
        species: cfg.species,
        diet: cfg.diet,
        name: cfg.name,
        icon: cfg.icon,
        x: x,
        y: y,
        hp: 30.0,
        maxHp: 30.0,
        hunger: 10.0 + Math.random() * 20.0,
        speed: cfg.spd,
        attackPower: (cfg.diet === 'carnivore' ? 12.0 : 2.0),
        defensePower: (cfg.species === 'beetle' ? 25.0 : 2.0),
        ageInDays: Math.random() * 60.0,
        maxLifespan: 180.0,
        matingCooldown: 15.0,
        wanderAngle: Math.random() * Math.PI * 2,
        actionTimer: 1.0 + Math.random() * 3.0
      });
    }
  }

  return insectList;
}

/**
 * Atualização comportamental da microfauna de insetos
 */
function updateInsectBehavior(ins, dt, ctx) {
  const { animals, biomass, grains, getIdx, matId, MAT_WATER, CHUNK_SIZE, timeOfDay } = ctx;
  let targetX = ins.x;
  let targetY = ins.y;

  const curIdx = getIdx(Math.floor(ins.x), Math.floor(ins.y));

  // 1. Dinâmica trófica específica
  switch (ins.species) {
    case 'ant':
      // Formiga-saúva: colhe biomassa vegetal
      if (biomass && biomass[curIdx] > 10.0) {
        biomass[curIdx] -= 0.15 * dt;
        ins.hunger = Math.max(0, ins.hunger - 3.0 * dt);
      }
      break;

    case 'bee':
      // Abelha-jataí: poliniza flores, estimulando regeneração floral vizinha
      if (biomass && biomass[curIdx] > 20.0) {
        ins.hunger = Math.max(0, ins.hunger - 4.0 * dt);
        if (Math.random() < 0.10 && curIdx + 1 < biomass.length) {
          biomass[curIdx + 1] = Math.min(100.0, biomass[curIdx + 1] + 0.3);
        }
      }
      break;

    case 'butterfly':
      // Borboleta-morfo: voo ondulante no sol
      if (timeOfDay >= 8.0 && timeOfDay <= 16.0) {
        ins.speed = 2.6;
      } else {
        ins.speed = 0.5; // Pousa à noite
      }
      break;

    case 'dragonfly':
      // Libélula: caça mosquitos no ar perto do lago
      for (let j = 0; j < animals.length; j++) {
        const other = animals[j];
        if (other.species === 'mosquito' && other.hp > 0 && Math.hypot(other.x - ins.x, other.y - ins.y) < 12.0) {
          other.hp -= 20.0 * dt;
          ins.hunger = Math.max(0, ins.hunger - 10.0 * dt);
          targetX = other.x;
          targetY = other.y;
          return { targetX, targetY };
        }
      }
      break;

    case 'grasshopper':
      // Gafanhoto: consome grãos e gramíneas na várzea
      if (grains && grains[curIdx] > 1.0) {
        grains[curIdx] -= 0.3 * dt;
        ins.hunger = Math.max(0, ins.hunger - 6.0 * dt);
      } else if (biomass && biomass[curIdx] > 10.0) {
        biomass[curIdx] -= 0.2 * dt;
        ins.hunger = Math.max(0, ins.hunger - 4.0 * dt);
      }
      break;

    case 'mantis':
      // Louva-a-deus: emboscada de gafanhotos e moscas
      for (let j = 0; j < animals.length; j++) {
        const other = animals[j];
        if ((other.species === 'grasshopper' || other.species === 'bee' || other.species === 'butterfly') && other.hp > 0) {
          const d = Math.hypot(other.x - ins.x, other.y - ins.y);
          if (d < 4.0) {
            other.hp -= 25.0 * dt;
            ins.hunger = Math.max(0, ins.hunger - 15.0 * dt);
            return { targetX: ins.x, targetY: ins.y };
          }
        }
      }
      break;

    case 'mosquito':
      // Mosquito: pica mamíferos para sugar sangue
      for (let j = 0; j < animals.length; j++) {
        const other = animals[j];
        if ((other.species === 'rat' || other.species === 'cat') && other.hp > 0) {
          const d = Math.hypot(other.x - ins.x, other.y - ins.y);
          if (d < 5.0) {
            ins.hunger = Math.max(0, ins.hunger - 8.0 * dt);
            other.fatigue = Math.min(100.0, (other.fatigue || 0) + 0.1 * dt);
            break;
          }
        }
      }
      break;

    case 'beetle':
    case 'roach':
    case 'termite':
      // Decompositores: reciclagem de matéria orgânica no solo
      if (ins.hunger > 15.0) {
        ins.hunger = Math.max(0, ins.hunger - 2.5 * dt);
      }
      break;
  }

  // 2. Movimento cinemático característico
  ins.wanderAngle += (Math.random() - 0.5) * 1.4 * dt;
  const spd = ins.speed;
  targetX = Math.max(10, Math.min(CHUNK_SIZE - 10, ins.x + Math.cos(ins.wanderAngle) * spd * 2.0));
  targetY = Math.max(10, Math.min(CHUNK_SIZE - 10, ins.y + Math.sin(ins.wanderAngle) * spd * 2.0));

  // Evita cair no fundo da água para insetos terrestres (não-libélulas/mosquitos)
  if (ins.species !== 'dragonfly' && ins.species !== 'mosquito' && matId && matId[curIdx] === MAT_WATER) {
    targetX = ins.x - Math.cos(ins.wanderAngle) * 5.0;
    targetY = ins.y - Math.sin(ins.wanderAngle) * 5.0;
  }

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.InsectSpecies = {
    createInitialInsects,
    updateInsectBehavior
  };
}