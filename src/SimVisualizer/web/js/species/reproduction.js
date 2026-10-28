// =========================================================================
// MÓDULO UNIFICADO DE REPRODUÇÃO E DINÂMICA POPULACIONAL (BIODIVERSIDADE)
// =========================================================================

/**
 * Tabela biométrica e dados ecológicos de reprodução para todas as espécies
 * Baseado em ontogenia real, parâmetros de PanTHERIA, FishBase, Birds of the World e AntWeb.
 */
const SPECIES_REPRODUCTION = {
  // Mamíferos
  rat: {
    maturityDays: 60.0,
    gestationDays: 21.0,
    litterMin: 8,
    litterMax: 13,
    postPartumCooldown: 15.0,
    estrusInterval: 4.5,
    estrusDuration: 0.8,
    maxCap: 500,
    matingDist: 1.5,
    femaleRatio: 0.50
  },
  cat: {
    maturityDays: 210.0,
    gestationDays: 64.0,
    litterMin: 3,
    litterMax: 5,
    postPartumCooldown: 45.0,
    estrusInterval: 18.0,
    estrusDuration: 5.0,
    maxCap: 90,
    matingDist: 2.0,
    femaleRatio: 0.50
  },

  // Peixes Lacustres
  tambaqui: {
    maturityDays: 120.0,
    gestationDays: 10.0, // Período de maturação e desova dos alevinos
    litterMin: 5,
    litterMax: 10,
    postPartumCooldown: 35.0,
    estrusInterval: 28.0,
    estrusDuration: 4.0,
    maxCap: 120,
    matingDist: 2.5,
    femaleRatio: 0.50
  },
  traira: {
    maturityDays: 180.0,
    gestationDays: 6.0,  // Cuidado parental em ninho aquático até natação livre
    litterMin: 2,
    litterMax: 4,
    postPartumCooldown: 60.0,
    estrusInterval: 45.0,
    estrusDuration: 3.5,
    maxCap: 20,
    matingDist: 2.5,
    femaleRatio: 0.50
  },

  // Répteis
  tortoise: {
    maturityDays: 365.0,
    gestationDays: 40.0, // Incubação dos ovos na cova arenosa
    litterMin: 3,
    litterMax: 6,
    postPartumCooldown: 90.0,
    estrusInterval: 60.0,
    estrusDuration: 8.0,
    maxCap: 45,
    matingDist: 2.2,
    femaleRatio: 0.50
  },
  caiman: {
    maturityDays: 450.0,
    gestationDays: 45.0, // Incubação em monte de folhiço e matéria orgânica
    litterMin: 3,
    litterMax: 5,
    postPartumCooldown: 120.0,
    estrusInterval: 90.0,
    estrusDuration: 10.0,
    maxCap: 18,
    matingDist: 3.0,
    femaleRatio: 0.50
  },

  // Aves
  toucan: {
    maturityDays: 150.0,
    gestationDays: 18.0, // Incubação no oco de árvore
    litterMin: 2,
    litterMax: 4,
    postPartumCooldown: 50.0,
    estrusInterval: 40.0,
    estrusDuration: 5.0,
    maxCap: 40,
    matingDist: 3.0,
    femaleRatio: 0.50
  },
  carcara: {
    maturityDays: 200.0,
    gestationDays: 30.0, // Incubação em ninho de gravetos
    litterMin: 2,
    litterMax: 3,
    postPartumCooldown: 60.0,
    estrusInterval: 45.0,
    estrusDuration: 6.0,
    maxCap: 25,
    matingDist: 3.5,
    femaleRatio: 0.50
  },
  harpy: {
    maturityDays: 1095.0,
    gestationDays: 56.0,
    litterMin: 1,
    litterMax: 2,
    postPartumCooldown: 365.0,
    estrusInterval: 180.0,
    estrusDuration: 15.0,
    maxCap: 6,
    matingDist: 5.0,
    femaleRatio: 0.50
  },

  // Insetos (10 espécies)
  ant: {
    maturityDays: 25.0,
    gestationDays: 12.0, // Fundação de câmara e desenvolvimento larval
    litterMin: 8,
    litterMax: 16,
    postPartumCooldown: 20.0,
    estrusInterval: 15.0,
    estrusDuration: 3.0,
    maxCap: 160,
    matingDist: 1.5,
    femaleRatio: 0.80
  },
  bee: {
    maturityDays: 20.0,
    gestationDays: 10.0,
    litterMin: 6,
    litterMax: 12,
    postPartumCooldown: 18.0,
    estrusInterval: 14.0,
    estrusDuration: 3.0,
    maxCap: 120,
    matingDist: 2.0,
    femaleRatio: 0.80
  },
  butterfly: {
    maturityDays: 15.0,
    gestationDays: 7.0, // Postura dos ovos sob folhas e metamorfose
    litterMin: 5,
    litterMax: 9,
    postPartumCooldown: 12.0,
    estrusInterval: 10.0,
    estrusDuration: 2.0,
    maxCap: 100,
    matingDist: 2.0,
    femaleRatio: 0.50
  },
  dragonfly: {
    maturityDays: 25.0,
    gestationDays: 10.0,
    litterMin: 4,
    litterMax: 7,
    postPartumCooldown: 15.0,
    estrusInterval: 14.0,
    estrusDuration: 3.0,
    maxCap: 80,
    matingDist: 2.0,
    femaleRatio: 0.50
  },
  beetle: {
    maturityDays: 40.0,
    gestationDays: 20.0,
    litterMin: 2,
    litterMax: 5,
    postPartumCooldown: 30.0,
    estrusInterval: 25.0,
    estrusDuration: 4.0,
    maxCap: 60,
    matingDist: 1.5,
    femaleRatio: 0.50
  },
  mosquito: {
    maturityDays: 10.0,
    gestationDays: 5.0, // Postura na lâmina d'água e eclosão de larvas
    litterMin: 8,
    litterMax: 18,
    postPartumCooldown: 8.0,
    estrusInterval: 7.0,
    estrusDuration: 2.0,
    maxCap: 180,
    matingDist: 1.5,
    femaleRatio: 0.60
  },
  grasshopper: {
    maturityDays: 30.0,
    gestationDays: 14.0,
    litterMin: 5,
    litterMax: 10,
    postPartumCooldown: 20.0,
    estrusInterval: 18.0,
    estrusDuration: 3.0,
    maxCap: 100,
    matingDist: 1.5,
    femaleRatio: 0.50
  },
  mantis: {
    maturityDays: 40.0,
    gestationDays: 18.0, // Construção da ooteca protetora
    litterMin: 3,
    litterMax: 7,
    postPartumCooldown: 25.0,
    estrusInterval: 20.0,
    estrusDuration: 4.0,
    maxCap: 50,
    matingDist: 1.8,
    femaleRatio: 0.50
  },
  roach: {
    maturityDays: 35.0,
    gestationDays: 20.0,
    litterMin: 6,
    litterMax: 12,
    postPartumCooldown: 22.0,
    estrusInterval: 18.0,
    estrusDuration: 4.0,
    maxCap: 100,
    matingDist: 1.5,
    femaleRatio: 0.50
  },
  termite: {
    maturityDays: 20.0,
    gestationDays: 10.0,
    litterMin: 10,
    litterMax: 20,
    postPartumCooldown: 16.0,
    estrusInterval: 12.0,
    estrusDuration: 3.0,
    maxCap: 160,
    matingDist: 1.5,
    femaleRatio: 0.70
  }
};

/**
 * Cria um novo filhote herdando características biológicas da mãe e da espécie
 */
function createOffspring(mother, father, x, y, options = {}) {
  const cfg = SPECIES_REPRODUCTION[mother.species] || SPECIES_REPRODUCTION.rat;
  const femaleRatio = cfg.femaleRatio || 0.50;
  const sex = (Math.random() < femaleRatio) ? 'female' : 'male';

  const pup = {
    id: Date.now() + Math.random(),
    species: mother.species,
    diet: mother.diet || 'herbivore',
    name: mother.name || mother.species,
    sex: sex,
    x: x,
    y: y,
    hp: 100,
    maxHp: 100,
    hunger: 10.0 + Math.random() * 10.0,
    thirst: 5.0,
    fatigue: 0.0,
    speed: mother.speed || 1.5,
    attackPower: mother.attackPower ? Math.max(1.0, mother.attackPower * 0.4) : 5.0,
    defensePower: mother.defensePower ? Math.max(1.0, mother.defensePower * 0.5) : 5.0,
    ageInDays: 0.0,
    maxLifespan: mother.maxLifespan || 3650.0,

    // Ciclo reprodutivo inicial (juvenil / imaturo)
    isPregnant: false,
    daysPregnant: 0.0,
    gestationRemaining: 0.0,
    litterSize: 0,
    matingCooldown: cfg.maturityDays + Math.random() * 10.0,
    estrusCycleTimer: cfg.estrusInterval,
    estrusDurationRemaining: 0.0,

    motherId: mother.id,
    fatherId: father ? father.id : null,
    hasNest: !!mother.hasNest,
    nestX: mother.nestX || x,
    nestY: mother.nestY || y
  };

  // Traços específicos por reino
  if (mother.species === 'rat') {
    pup.stamina = 100.0;
    pup.maxStamina = 100.0;
    pup.breath = 7.0;
    pup.maxBreath = 7.0;
    pup.sensoryRadius = mother.sensoryRadius || 55;
    if (mother.genome && father && father.genome && typeof recombineRatGenome !== 'undefined') {
      pup.genome = recombineRatGenome(mother.genome, father.genome);
      pup.mateGenome = pup.genome;
    }
  } else if (mother.species === 'cat') {
    pup.stamina = 100.0;
    pup.maxStamina = 100.0;
    pup.sensoryRadius = mother.sensoryRadius || 60;
    if (mother.catGenome && father && father.catGenome && typeof recombineCatGenome !== 'undefined') {
      pup.catGenome = recombineCatGenome(mother.catGenome, father.catGenome);
      pup.mateCatGenome = pup.catGenome;
    }
  } else if (mother.species === 'tambaqui' || mother.species === 'traira') {
    pup.fearTimer = 0.0;
    pup.wanderAngle = Math.random() * Math.PI * 2;
    if (mother.species === 'traira') {
      pup.isLurking = true;
      pup.lungeCooldown = 0.0;
      pup.lungeSpeed = mother.lungeSpeed || 6.2;
    }
  } else if (mother.species === 'tortoise') {
    pup.isRetracted = false;
    pup.retractedTimer = 0.0;
    pup.wanderAngle = Math.random() * Math.PI * 2;
  } else if (mother.species === 'caiman') {
    pup.isBasking = false;
    pup.baskingTimer = 0.0;
    pup.lungeCooldown = 0.0;
    pup.wanderAngle = Math.random() * Math.PI * 2;
  } else if (mother.species === 'toucan' || mother.species === 'carcara') {
    pup.perchTimer = 2.0;
    pup.wanderAngle = Math.random() * Math.PI * 2;
  } else {
    // Insetos
    pup.icon = mother.icon;
    pup.pollinateTimer = 0.0;
    pup.wanderAngle = Math.random() * Math.PI * 2;
  }

  return pup;
}

/**
 * Tenta executar o cortejo e acasalamento entre dois indivíduos elegíveis da mesma espécie
 */
function tryMatePair(female, male) {
  if (female.species !== male.species) return false;
  const cfg = SPECIES_REPRODUCTION[female.species];
  if (!cfg) return false;

  // Ambos devem estar nutridos e com saúde mínima
  if (female.hunger > 55.0 || male.hunger > 60.0) return false;
  if (female.hp < 40 || male.hp < 40) return false;
  if (female.isPregnant || female.matingCooldown > 0 || male.matingCooldown > 0) return false;

  // Inicia gestação/incubação da fêmea
  female.isPregnant = true;
  female.daysPregnant = 0.0;
  female.gestationRemaining = cfg.gestationDays + (Math.random() - 0.5) * (cfg.gestationDays * 0.15);
  female.litterSize = cfg.litterMin + Math.floor(Math.random() * (cfg.litterMax - cfg.litterMin + 1));
  female.estrusDurationRemaining = 0.0;
  female.estrusCycleTimer = female.gestationRemaining;
  female.matingCooldown = female.gestationRemaining + cfg.postPartumCooldown;
  female.fatherId = male.id;

  // Macho entra em cooldown pós-cópula
  male.matingCooldown = cfg.postPartumCooldown * 0.35 + Math.random() * 5.0;

  return true;
}

// Vinculação de escopo para ambiente browser / node
if (typeof window !== 'undefined') {
  window.SpeciesReproduction = {
    SPECIES_REPRODUCTION,
    createOffspring,
    tryMatePair
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    SPECIES_REPRODUCTION,
    createOffspring,
    tryMatePair
  };
}

