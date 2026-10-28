// =========================================================================
// MÓDULO DE RÉPTEIS: JABUTI-TINGA (HERBÍVORO) E JACARÉ-AÇU (PREDADOR DE TOPO)
// =========================================================================

/**
 * Criação da população de répteis
 */
function createInitialReptiles(lakeCenterX = 512.0, lakeCenterY = 512.0, lakeRadius = 100.0) {
  const reptileList = [];
  const TORTOISE_COUNT = 18;
  const CAIMAN_COUNT = 8;

  // 1. Jabuti-tinga (Chelonoidis denticulatus) - Terrestre lento com carapaça
  for (let i = 0; i < TORTOISE_COUNT; i++) {
    const angle = Math.random() * Math.PI * 2;
    const distFromCenter = lakeRadius + 60.0 + Math.random() * 260.0;
    const x = Math.max(30, Math.min(1024 - 30, lakeCenterX + Math.cos(angle) * distFromCenter));
    const y = Math.max(30, Math.min(1024 - 30, lakeCenterY + Math.sin(angle) * distFromCenter));
    const sex = (i % 2 === 0) ? 'female' : 'male';

    reptileList.push({
      id: 4000 + i,
      species: 'tortoise',
      diet: 'herbivore',
      name: 'Jabuti-tinga',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 10.0 + Math.random() * 20.0,
      thirst: 5.0 + Math.random() * 10.0,
      speed: 0.65, // Lento e metódico
      attackPower: 4.0,
      defensePower: 85.0, // Alta proteção de carapaça
      isRetracted: false,
      retractedTimer: 0.0,
      ageInDays: 1200.0 + Math.random() * 2500.0,
      maxLifespan: 18250.0, // ~50 anos
      matingCooldown: 60.0 + Math.random() * 60.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      wanderAngle: Math.random() * Math.PI * 2
    });
  }

  // 2. Jacaré-açu / Jacaré-coroa (Melanosuchus niger) - Predador de margem e lago
  for (let i = 0; i < CAIMAN_COUNT; i++) {
    const angle = (i / CAIMAN_COUNT) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
    // Posição nas margens e praias do lago
    const distFromCenter = lakeRadius * (0.85 + Math.random() * 0.25);
    const x = lakeCenterX + Math.cos(angle) * distFromCenter;
    const y = lakeCenterY + Math.sin(angle) * distFromCenter;
    const sex = (i % 2 === 0) ? 'female' : 'male';

    reptileList.push({
      id: 5000 + i,
      species: 'caiman',
      diet: 'carnivore',
      name: 'Jacaré-açu',
      sex: sex,
      x: x,
      y: y,
      hp: 100,
      maxHp: 100,
      hunger: 15.0 + Math.random() * 20.0,
      thirst: 0.0,
      speed: 1.6, // Velocidade de nado/terra
      burstSpeed: 6.5, // Bote explosivo
      isLungeActive: false,
      lungeCooldown: 0.0,
      isBasking: false,
      baskingTimer: 0.0,
      attackPower: 88.0,
      defensePower: 42.0,
      ageInDays: 2000.0 + Math.random() * 3000.0,
      maxLifespan: 21900.0, // ~60 anos
      matingCooldown: 120.0,
      isPregnant: false,
      gestationRemaining: 0,
      litterSize: 0,
      targetPreyId: null,
      wanderAngle: angle
    });
  }

  return reptileList;
}

/**
 * Comportamento do Jabuti-tinga
 */
function updateTortoiseBehavior(a, dt, ctx) {
  const { animals, biomass, getIdx, matId, MAT_WATER, temp, CHUNK_SIZE } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  // 1. Defesa por retração: se um predador terrestre (Gato, Carcará) estiver por perto (< 6m)
  if (a.retractedTimer > 0) {
    a.retractedTimer -= dt;
    if (a.retractedTimer <= 0) a.isRetracted = false;
    return { targetX: a.x, targetY: a.y }; // Fica imóvel dentro da carapaça
  }

  for (let j = 0; j < animals.length; j++) {
    const pred = animals[j];
    if (pred.hp > 0 && (pred.species === 'cat' || pred.species === 'carcara')) {
      const d = Math.hypot(pred.x - a.x, pred.y - a.y);
      if (d < 5.5) {
        a.isRetracted = true;
        a.retractedTimer = 8.0; // Recolhe membros e cabeça
        return { targetX: a.x, targetY: a.y };
      }
    }
  }

  // 2. Evitar água profunda (jabuti não nada)
  const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
  if (matId && matId[curIdx] === MAT_WATER) {
    // Afasta-se da água em direção à terra firme
    targetX = a.x + (Math.random() - 0.5) * 8.0;
    targetY = a.y + (Math.random() - 0.5) * 8.0;
    return { targetX, targetY };
  }

  // 3. Alimentação com biomassa e frutos caídos
  if (a.hunger > 20.0 && biomass && biomass[curIdx] > 10.0) {
    const bite = Math.min(biomass[curIdx], 2.5 * dt);
    biomass[curIdx] -= bite;
    a.hunger = Math.max(0, a.hunger - bite * 3.5);
  }

  // 4. Locomoção lenta e termorregulação
  a.wanderAngle += (Math.random() - 0.5) * 0.3 * dt;
  targetX = Math.max(10, Math.min(CHUNK_SIZE - 10, a.x + Math.cos(a.wanderAngle) * a.speed * 2.0));
  targetY = Math.max(10, Math.min(CHUNK_SIZE - 10, a.y + Math.sin(a.wanderAngle) * a.speed * 2.0));

  return { targetX, targetY };
}

/**
 * Comportamento do Jacaré-açu (Emboscada na margem, Bote e Aquecimento solar)
 */
function updateCaimanBehavior(a, dt, ctx) {
  const { animals, lakeCenterX, lakeCenterY, lakeRadius, getIdx, matId, MAT_WATER, applyDeathDecomposition, onPredationSuccess, timeOfDay } = ctx;
  let targetX = a.x;
  let targetY = a.y;

  if (a.lungeCooldown > 0) a.lungeCooldown -= dt;

  // 1. Basking (Aquecimento solar nas praias durante horas quentes do dia 10h-15h)
  const isHotHours = (timeOfDay >= 10.0 && timeOfDay <= 15.0);
  const dToLake = Math.hypot(a.x - lakeCenterX, a.y - lakeCenterY);

  if (isHotHours && a.hunger < 50.0 && dToLake >= lakeRadius * 0.90 && dToLake <= lakeRadius * 1.15) {
    a.isBasking = true;
    // Regenera HP sob sol
    if (a.hp < 100) a.hp = Math.min(100, a.hp + 0.3 * dt);
    // Permanece quieto na margem
    if (Math.random() < 0.95) return { targetX: a.x, targetY: a.y };
  } else {
    a.isBasking = false;
  }

  // 2. Caça e Emboscada: Detecta animais próximos à margem ou na água
  let targetPrey = null;
  let minDist = 24.0;

  for (let j = 0; j < animals.length; j++) {
    const prey = animals[j];
    if (prey === a || prey.hp <= 0 || prey.species === 'caiman') continue;

    // Presas potenciais: Peixes (tambaqui, piranha), Ratos bebendo água na margem, Gatos na borda do lago
    const d = Math.hypot(prey.x - a.x, prey.y - a.y);
    if (d < minDist) {
      minDist = d;
      targetPrey = prey;
    }
  }

  // 3. Execução do Bote de Emboscada (Lunge)
  if (targetPrey && a.hunger > 18.0) {
    const dirX = targetPrey.x - a.x;
    const dirY = targetPrey.y - a.y;
    const dist = Math.hypot(dirX, dirY) || 1.0;

    if (dist <= 3.5 && a.lungeCooldown <= 0) {
      // Bote veloz com mordida esmagadora
      a.lungeCooldown = 4.5;
      const damage = a.attackPower * (0.85 + Math.random() * 0.4);
      targetPrey.hp -= damage;
      a.hunger = Math.max(0, a.hunger - 40.0);

      if (targetPrey.hp <= 0) {
        if (applyDeathDecomposition) applyDeathDecomposition(targetPrey.x, targetPrey.y);
        if (onPredationSuccess) onPredationSuccess(targetPrey, a);
      }
      return { targetX: targetPrey.x, targetY: targetPrey.y };
    } else {
      // Aproximação furtiva na lâmina d'água / margem
      targetX = a.x + (dirX / dist) * a.speed * 2.0;
      targetY = a.y + (dirY / dist) * a.speed * 2.0;
      return { targetX, targetY };
    }
  }

  // 4. Patrulha anfíbia suave entre o lago e a praia
  a.wanderAngle += (Math.random() - 0.5) * 0.4 * dt;
  const targetDist = lakeRadius * (0.92 + Math.sin(a.wanderAngle) * 0.12);
  targetX = lakeCenterX + Math.cos(a.wanderAngle) * targetDist;
  targetY = lakeCenterY + Math.sin(a.wanderAngle) * targetDist;

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.ReptileSpecies = {
    createInitialReptiles,
    updateTortoiseBehavior,
    updateCaimanBehavior
  };
}
