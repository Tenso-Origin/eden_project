// =========================================================================
// MÓDULO DE AVES ADICIONAIS: TUCANO-TOCO E CARCARÁ (NEOTROPICAL)
// =========================================================================

/**
 * Criação da população de aves adicionais (Tucanos e Carcarás)
 */
function createInitialBirds(lakeCenterX = 512.0, lakeCenterY = 512.0, CHUNK_SIZE = 1024) {
  const birdsList = [];
  const TOUCAN_COUNT = 16;
  const CARCARA_COUNT = 10;

  // 1. Tucanos (Ramphastos toco) - Frugívoros pacíficos das copas
  for (let i = 0; i < TOUCAN_COUNT; i++) {
    // Espalham-se pela floresta densa (fora da várzea central)
    const angle = Math.random() * Math.PI * 2;
    const dist = 320.0 + Math.random() * 160.0;
    const x = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterX + Math.cos(angle) * dist));
    const y = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterY + Math.sin(angle) * dist));
    const sex = (i % 2 === 0) ? 'female' : 'male';

    birdsList.push({
      id: 6000 + i,
      species: 'toucan',
      diet: 'omnivore',
      name: 'Tucano-toco',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      hunger: 10.0 + Math.random() * 20.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 4.2,
      attackPower: 12.0,
      defensePower: 10.0,
      ageInDays: 400.0 + Math.random() * 600.0,
      maxLifespan: 7300.0, // ~20 anos
      matingCooldown: 90.0,
      perchTimer: 2.0 + Math.random() * 5.0,
      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  // 2. Carcarás (Caracara plancus) - Predadores e necrófagos oportunistas de solo e ar
  for (let i = 0; i < CARCARA_COUNT; i++) {
    // Várzea aberta e bordas de lago
    const angle = (i / CARCARA_COUNT) * Math.PI * 2;
    const dist = 120.0 + Math.random() * 140.0;
    const x = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterX + Math.cos(angle) * dist));
    const y = Math.max(40, Math.min(CHUNK_SIZE - 40, lakeCenterY + Math.sin(angle) * dist));
    const sex = (i % 2 === 0) ? 'female' : 'male';

    birdsList.push({
      id: 7000 + i,
      species: 'carcara',
      diet: 'carnivore',
      name: 'Carcará',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      hunger: 15.0 + Math.random() * 25.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 4.8,
      groundSpeed: 2.3,
      isGrounded: true,
      groundSearchTimer: 5.0 + Math.random() * 5.0,
      attackPower: 38.0,
      defensePower: 16.0,
      ageInDays: 500.0 + Math.random() * 700.0,
      maxLifespan: 6200.0, // ~17 anos
      matingCooldown: 120.0,
      wanderAngle: angle
    });
  }

  return birdsList;
}

/**
 * Comportamento do Tucano (Salto de copas, consumo de frutos e dispersão)
 */
function updateToucanBehavior(a, dt, ctx) {
  const { biomass, grains, getIdx, CHUNK_SIZE } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  if (a.perchTimer > 0) {
    a.perchTimer -= dt;
    // Alimentação enquanto pousado na copa
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (a.hunger > 15.0 && biomass && biomass[curIdx] > 40.0) {
      biomass[curIdx] -= 0.5 * dt;
      a.hunger = Math.max(0, a.hunger - 4.0 * dt);
      // Efeito de dispersão de sementes (regeneração de brotos vizinhos)
      if (Math.random() < 0.15 && curIdx + 1 < biomass.length) {
        biomass[curIdx + 1] = Math.min(100.0, biomass[curIdx + 1] + 0.8);
      }
    }
    return { targetX: a.x, targetY: a.y };
  }

  // Voo para outra árvore frutífera ou copa densa
  a.perchTimer = 4.0 + Math.random() * 6.0;
  a.wanderAngle += (Math.random() - 0.5) * 1.2;
  const flightDist = 25.0 + Math.random() * 35.0;
  targetX = Math.max(30, Math.min(CHUNK_SIZE - 30, a.x + Math.cos(a.wanderAngle) * flightDist));
  targetY = Math.max(30, Math.min(CHUNK_SIZE - 30, a.y + Math.sin(a.wanderAngle) * flightDist));

  return { targetX, targetY };
}

/**
 * Comportamento do Carcará (Varredura de solo, caça de gafanhotos/roedores e carcaças)
 */
function updateCarcaraBehavior(a, dt, ctx) {
  const { animals, grains, getIdx, CHUNK_SIZE, applyDeathDecomposition, onPredationSuccess } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Busca por presas pequenas no solo (Gafanhotos, Besouros, Filhotes de Rato)
  let targetPrey = null;
  let minDist = 20.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0) continue;
    if (prey.species === 'grasshopper' || prey.species === 'beetle' || (prey.species === 'rat' && prey.hp < 40)) {
      const d = Math.hypot(prey.x - a.x, prey.y - a.y);
      if (d < minDist) {
        minDist = d;
        targetPrey = prey;
      }
    }
  }

  if (targetPrey && a.hunger > 20.0) {
    const dirX = targetPrey.x - a.x;
    const dirY = targetPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    if (dist <= 2.0) {
      // Bote de bico rápido
      targetPrey.hp -= a.attackPower * dt * 2.0;
      a.hunger = Math.max(0, a.hunger - 25.0);

      if (targetPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(targetPrey.x, targetPrey.y);
        if (onPredationSuccess) onPredationSuccess(targetPrey, a);
      }
    } else {
      targetX = a.x + (dirX / dist) * a.groundSpeed * 3.0;
      targetY = a.y + (dirY / dist) * a.groundSpeed * 3.0;
    }
    return { targetX, targetY };
  }

  // 2. Patrulha mista (alterna voo rasante e corrida no chão)
  a.wanderAngle += (Math.random() - 0.5) * 0.5 * dt;
  const spd = a.isGrounded ? a.groundSpeed : a.speed;
  targetX = Math.max(20, Math.min(CHUNK_SIZE - 20, a.x + Math.cos(a.wanderAngle) * spd * 2.5));
  targetY = Math.max(20, Math.min(CHUNK_SIZE - 20, a.y + Math.sin(a.wanderAngle) * spd * 2.5));

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.BirdSpecies = {
    createInitialBirds,
    updateToucanBehavior,
    updateCarcaraBehavior
  };
}