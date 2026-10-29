// =========================================================================
// MÓDULO DE INSETOS NEOTROPICAIS (10 ESPÉCIES - BACIA AMAZÔNICA 2048x1024)
// INCLUINDO INSETOS SOCIAIS (FORMIGAS, CUPINS E ABELHAS), NINHOS E REVOADA
// =========================================================================

/**
 * Criação da população inicial de insetos distribuída por nicho ecológico
 * Cria ninhos centrais para insetos sociais e vincula operárias ao raio do ninho.
 */
function createInitialInsects(gridWidth = 2048, gridHeight = 1024, nests = null) {
  const insectList = [];

  // Configuração dos Ninhos de Insetos Sociais na Bacia Amazônica
  const SOCIAL_NESTS = {
    ant: [
      { name: 'Formigueiro Oeste (Saúva)', x: 420, y: 360, radius: 85.0, res: 40.0 },
      { name: 'Formigueiro Sul (Saúva)', x: 1050, y: 780, radius: 85.0, res: 35.0 },
      { name: 'Formigueiro Leste (Saúva)', x: 1680, y: 390, radius: 85.0, res: 35.0 }
    ],
    termite: [
      { name: 'Cupinzeiro da Mata Oeste', x: 380, y: 720, radius: 45.0, res: 30.0 },
      { name: 'Cupinzeiro da Floresta Central', x: 1180, y: 320, radius: 45.0, res: 30.0 },
      { name: 'Cupinzeiro da Mata Leste', x: 1740, y: 690, radius: 45.0, res: 30.0 }
    ],
    bee: [
      { name: 'Colmeia Jataí (Oco Oeste)', x: 520, y: 460, radius: 130.0, res: 25.0 },
      { name: 'Colmeia Jataí (Oco Central)', x: 960, y: 410, radius: 130.0, res: 25.0 },
      { name: 'Colmeia Jataí (Oco Leste)', x: 1560, y: 560, radius: 130.0, res: 25.0 }
    ]
  };

  const assignedNests = { ant: [], termite: [], bee: [] };
  let nestSeq = 5000;

  if (nests && Array.isArray(nests)) {
    for (const [sp, list] of Object.entries(SOCIAL_NESTS)) {
      for (const nConf of list) {
        const nestObj = {
          id: nestSeq++,
          species: sp,
          name: nConf.name,
          x: nConf.x,
          y: nConf.y,
          quality: 90,
          resourcesKg: nConf.res,
          forageRadius: nConf.radius,
          lastNuptialFlightYear: -1
        };
        nests.push(nestObj);
        assignedNests[sp].push(nestObj);
      }
    }
  }

  const SPECIES_CONFIG = [
    { species: 'ant', count: 40, name: 'Formiga-saúva', diet: 'herbivore', spd: 1.1, icon: '🐜', zone: 'nest', isSocial: true, femaleRatio: 0.95 },
    { species: 'bee', count: 30, name: 'Abelha-jataí', diet: 'herbivore', spd: 2.8, icon: '🐝', zone: 'nest', isSocial: true, femaleRatio: 0.95 },
    { species: 'termite', count: 35, name: 'Cupim-da-terra', diet: 'decomposer', spd: 0.8, icon: '🪵', zone: 'nest', isSocial: true, femaleRatio: 0.90 },
    { species: 'butterfly', count: 30, name: 'Borboleta-morfo', diet: 'herbivore', spd: 2.2, icon: '🦋', zone: 'clearings', isSocial: false, femaleRatio: 0.50, gest: 7.0, litter: [5, 9], mat: 15.0, est: 10.0 },
    { species: 'dragonfly', count: 25, name: 'Libélula-imperador', diet: 'carnivore', spd: 3.8, icon: '🪰', zone: 'water', isSocial: false, femaleRatio: 0.50, gest: 10.0, litter: [4, 7], mat: 25.0, est: 14.0 },
    { species: 'beetle', count: 25, name: 'Besouro-hércules', diet: 'decomposer', spd: 0.9, icon: '🪲', zone: 'forest', isSocial: false, femaleRatio: 0.50, gest: 20.0, litter: [2, 5], mat: 40.0, est: 25.0 },
    { species: 'mosquito', count: 40, name: 'Mosquito-prego', diet: 'carnivore', spd: 2.0, icon: '🦟', zone: 'water', isSocial: false, femaleRatio: 0.60, gest: 5.0, litter: [8, 18], mat: 10.0, est: 7.0 },
    { species: 'grasshopper', count: 35, name: 'Gafanhoto-esperança', diet: 'herbivore', spd: 2.4, icon: '🦗', zone: 'varzea', isSocial: false, femaleRatio: 0.50, gest: 14.0, litter: [5, 10], mat: 30.0, est: 18.0 },
    { species: 'mantis', count: 20, name: 'Louva-a-deus', diet: 'carnivore', spd: 1.2, icon: '🍃', zone: 'varzea', isSocial: false, femaleRatio: 0.50, gest: 18.0, litter: [3, 7], mat: 40.0, est: 20.0 },
    { species: 'roach', count: 28, name: 'Barata-da-mata', diet: 'decomposer', spd: 1.8, icon: '🪳', zone: 'forest', isSocial: false, femaleRatio: 0.50, gest: 20.0, litter: [6, 12], mat: 35.0, est: 18.0 }
  ];

  let idCounter = 8000;

  for (const cfg of SPECIES_CONFIG) {
    const isSoc = cfg.isSocial;

    for (let i = 0; i < cfg.count; i++) {
      let x, y;
      let myNest = null;

      if (isSoc && assignedNests[cfg.species] && assignedNests[cfg.species].length > 0) {
        // Vincula a um ninho da espécie e posiciona no raio imediato do ninho
        myNest = assignedNests[cfg.species][i % assignedNests[cfg.species].length];
        x = myNest.x + (Math.random() - 0.5) * 12.0;
        y = myNest.y + (Math.random() - 0.5) * 12.0;
      } else if (cfg.zone === 'water') {
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 35.0;
      } else if (cfg.zone === 'varzea') {
        x = 100 + Math.random() * (gridWidth - 200);
        const yRiver = (typeof getRiverMainY === 'function') ? getRiverMainY(x) : 512.0;
        y = yRiver + (Math.random() - 0.5) * 160.0;
      } else {
        x = 60 + Math.random() * (gridWidth - 120);
        y = 60 + Math.random() * (gridHeight - 120);
      }

      x = Math.max(15, Math.min(gridWidth - 15, x));
      y = Math.max(15, Math.min(gridHeight - 15, y));

      const sex = (Math.random() < cfg.femaleRatio) ? 'female' : 'male';
      const isPregnantInit = (!isSoc && sex === 'female' && Math.random() < 0.20);
      const gestationRem = isPregnantInit ? (1.0 + Math.random() * (cfg.gest - 1.0)) : 0.0;

      const fRadius = isSoc ? (myNest ? myNest.forageRadius : (cfg.species === 'termite' ? 45.0 : (cfg.species === 'ant' ? 85.0 : 130.0))) : 0.0;

      insectList.push({
        id: idCounter++,
        species: cfg.species,
        diet: cfg.diet,
        name: cfg.name,
        icon: cfg.icon,
        sex: sex,
        x: x,
        y: y,
        hp: 100,             // Cada ponto de HP = 1 indivíduo (100 formigas/abelhas/cupins por token)
        maxHp: 100,
        hunger: 5.0 + Math.random() * 15.0,
        speed: cfg.spd,

        // Atributos de combate: Insetos sociais possuem defesa 0, ataque 0.1 e atacam em quantidade igual ao seu HP
        attackPower: isSoc ? 0.1 : (cfg.diet === 'carnivore' ? 18.0 : 2.0),
        defensePower: isSoc ? 0.0 : 2.0,

        isSocial: isSoc,
        nestId: myNest ? myNest.id : null,
        nestX: myNest ? myNest.x : x,
        nestY: myNest ? myNest.y : y,
        maxForageRadius: fRadius,
        foodCarried: 0.0,
        isReturningToNest: false,

        ageInDays: 20.0 + Math.random() * 100.0,
        maxLifespan: 365.0,
        pollinateTimer: 0.0,
        wanderAngle: Math.random() * Math.PI * 2,

        // Ciclo Reprodutivo para espécies não-sociais
        isPregnant: isPregnantInit,
        daysPregnant: isPregnantInit ? (cfg.gest - gestationRem) : 0.0,
        gestationRemaining: gestationRem,
        litterSize: isPregnantInit ? (cfg.litter[0] + Math.floor(Math.random() * (cfg.litter[1] - cfg.litter[0] + 1))) : 0,
        matingCooldown: isPregnantInit ? (gestationRem + 15.0) : (5.0 + Math.random() * 20.0),
        estrusCycleTimer: isPregnantInit ? gestationRem : (Math.random() * (cfg.est || 15.0)),
        estrusDurationRemaining: (!isPregnantInit && sex === 'female' && Math.random() < 0.25) ? (Math.random() * 3.0) : 0.0
      });
    }
  }

  return insectList;
}

/**
 * Atualização comportamental dos insetos (Sociais e Solitários)
 */
function updateInsectBehavior(a, dt, ctx) {
  const { animals, nests, biomass, grains, getIdx, matId, MAT_WATER, GRID_WIDTH, GRID_HEIGHT, timeOfDay, totalSimHours, weather, applyDeathDecomposition } = ctx;
  const gridW = GRID_WIDTH || 2048;
  const gridH = GRID_HEIGHT || 1024;
  let targetX = a.x;
  let targetY = a.y;

  // =========================================================================
  // CASO 1: RAINHA VIRGEM EM VOO NUPCIAL (REVOADA / DISPERSÃO REPRODUTIVA)
  // =========================================================================
  if (a.isVirginQueen) {
    a.flightTimer = (a.flightTimer || 30.0) - dt;
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));

    // Morte por afogamento se cair em água navegável
    const inWater = (matId && matId[curIdx] === MAT_WATER) || (ctx.surfaceWater && ctx.surfaceWater[curIdx] > 0.20);
    if (inWater) {
      a.hp = 0;
      return { targetX: a.x, targetY: a.y };
    }

    // Voo de dispersão radial rápido
    targetX = a.x + Math.cos(a.flightAngle) * (a.speed * 2.2);
    targetY = a.y + Math.sin(a.flightAngle) * (a.speed * 2.2);

    // Pouso ao final do fôlego de voo
    if (a.flightTimer <= 0) {
      let isTooCloseToOtherNest = false;
      if (nests && nests.length > 0) {
        for (let ni = 0; ni < nests.length; ni++) {
          const nest = nests[ni];
          if (nest.species === a.species && Math.hypot(a.x - nest.x, a.y - nest.y) < 65.0) {
            isTooCloseToOtherNest = true;
            break;
          }
        }
      }

      // Se pousar em terra firme segura longe de colônias rivais:
      if (!isTooCloseToOtherNest && !inWater) {
        // TAXA DE SUCESSO REALISTA DA NATUREZA: apenas ~4% das tanajuras/aleluias fundam novo ninho
        const success = (Math.random() < 0.04);
        if (success && nests) {
          const newNestId = 9100 + Math.floor(Math.random() * 80000);
          const nestTitle = (a.species === 'ant' ? 'Novo Formigueiro' : (a.species === 'bee' ? 'Nova Colmeia' : 'Novo Cupinzeiro'));
          const currentSimYear = (typeof getSimDate === 'function' && totalSimHours != null) ? getSimDate(totalSimHours).year : 1;

          nests.push({
            id: newNestId,
            motherId: a.id,
            species: a.species,
            name: `${nestTitle} (#${newNestId % 100})`,
            x: a.x,
            y: a.y,
            quality: 75,
            resourcesKg: 6.0,
            forageRadius: a.maxForageRadius || (a.species === 'termite' ? 45.0 : (a.species === 'ant' ? 85.0 : 130.0)),
            lastNuptialFlightYear: currentSimYear
          });

          // Notifica console da fundação bem-sucedida
          console.log(`👑 [REVOADA BEM-SUCEDIDA] ${nestTitle} fundado em (${a.x.toFixed(0)}, ${a.y.toFixed(0)})!`);
        }
      }

      // A rainha penetra no solo para fundar a câmara ou perece por dessecação/fungos
      a.hp = 0;
      return { targetX: a.x, targetY: a.y };
    }

    return { targetX, targetY };
  }

  // =========================================================================
  // CASO 2: INSETOS SOCIAIS (FORMIGAS, CUPINS E ABELHAS EM ENXAME)
  // Cada token representa 1 indivíduo por ponto de HP (ex: 100 HP = 100 formigas)
  // Atua em torno do ninho com raio de forrageamento radial biológico
  // =========================================================================
  if (a.isSocial) {
    let myNest = null;
    if (nests && Array.isArray(nests)) {
      myNest = nests.find(n => n.id === a.nestId);
    }
    const nestX = myNest ? myNest.x : (a.nestX || a.x);
    const nestY = myNest ? myNest.y : (a.nestY || a.y);
    const dNest = Math.hypot(a.x - nestX, a.y - nestY);
    const maxR = a.maxForageRadius || (a.species === 'termite' ? 45.0 : (a.species === 'ant' ? 85.0 : 130.0));

    // 1. REVOADA ANUAL / VOO NUPCIAL DISPARADO PELO NINHO
    // Ocorre na época do ano real para a espécie amazônica (Início da estação de chuvas)
    if (myNest && totalSimHours != null && typeof getSimDate === 'function') {
      const simDate = getSimDate(totalSimHours);
      let isNuptialSeason = false;

      if (a.species === 'ant') {
        // Saúvas: Outubro a Dezembro (meses 9, 10, 11), após chuvas quentes
        isNuptialSeason = (simDate.monthIdx >= 9 && simDate.monthIdx <= 11);
      } else if (a.species === 'termite') {
        // Cupins: Novembro a Janeiro (meses 10, 11, 0)
        isNuptialSeason = (simDate.monthIdx >= 10 || simDate.monthIdx === 0);
      } else if (a.species === 'bee') {
        // Abelhas Jataí: Dezembro a Fevereiro (meses 11, 0, 1)
        isNuptialSeason = (simDate.monthIdx >= 11 || simDate.monthIdx <= 1);
      }

      // Se a colônia acumulou recursos suficientes e ainda não revoou neste ano da simulação:
      if (isNuptialSeason && myNest.lastNuptialFlightYear !== simDate.year && (myNest.resourcesKg || 0) >= 16.0) {
        myNest.lastNuptialFlightYear = simDate.year;
        myNest.resourcesKg = Math.max(0, myNest.resourcesKg - 10.0);

        // Dispara a saída de múltiplas futuras rainhas virgens (tanajuras / içás / aleluias)
        if (animals && Array.isArray(animals)) {
          const numQueens = 8 + Math.floor(Math.random() * 6);
          for (let q = 0; q < numQueens; q++) {
            animals.push({
              id: 90000 + Math.floor(Math.random() * 100000),
              species: a.species,
              isVirginQueen: true,
              isSocial: false,
              name: (a.species === 'ant' ? 'Tanajura (Rainha Virgem)' : (a.species === 'bee' ? 'Princesa Jataí' : 'Aleluia (Rainha Virgem)')),
              icon: (a.species === 'ant' ? '🐜' : (a.species === 'bee' ? '🐝' : '🪵')),
              sex: 'female',
              x: nestX + (Math.random() - 0.5) * 4.0,
              y: nestY + (Math.random() - 0.5) * 4.0,
              hp: 1, // 1 indivíduo singular
              maxHp: 1,
              speed: 2.5,
              attackPower: 0.1,
              defensePower: 0.0,
              flightTimer: 25.0 + Math.random() * 25.0,
              flightAngle: Math.random() * Math.PI * 2,
              maxForageRadius: maxR,
              hunger: 5.0,
              ageInDays: 1.0,
              maxLifespan: 100.0,
              wanderAngle: Math.random() * Math.PI * 2
            });
          }
          console.log(`✨ [REVOADA AMAZÔNICA] Colônia '${myNest.name}' liberou ${numQueens} rainhas virgens em voo nupcial!`);
        }
      }
    }

    // 2. MULTI-ATAQUE COLETIVO DO ENXAME (1 ATAQUE POR PONTO DE HP)
    // Se atacado ou defendendo o ninho, realiza ataques igual ao HP atual
    const numIndividuals = Math.floor(Math.max(1, a.hp));
    const swarmDamageTotal = numIndividuals * a.attackPower; // ex: 100 HP * 0.1 = 10.0 dano

    // 3. RETORNO AO NINHO COM ALIMENTO OU PARA REGENERAÇÃO
    if (a.isReturningToNest) {
      targetX = nestX;
      targetY = nestY;

      if (dNest < 3.0) {
        // Descarrega recursos no ninho
        if (myNest) {
          myNest.resourcesKg = (myNest.resourcesKg || 0) + (a.foodCarried || 0);
        }
        a.foodCarried = 0.0;
        a.hunger = 0.0;

        // Regeneração biológica de operárias pela colônia (1 HP = 1 indivíduo)
        if (a.hp < 100) {
          a.hp = Math.min(100, a.hp + 20.0 * dt);
        }

        if (a.hp >= 95) {
          a.isReturningToNest = false;
          a.wanderAngle = Math.random() * Math.PI * 2;
        }
      }
      return { targetX, targetY };
    }

    // 4. FORRAGEAMENTO RADIAL EM TORNO DO NINHO
    // Se ultrapassou o raio máximo de atuação da espécie ou coletou carga suficiente:
    if (dNest > maxR || (a.foodCarried || 0) >= 3.5) {
      a.isReturningToNest = true;
      return { targetX: nestX, targetY: nestY };
    }

    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));

    // Formigas cortadeiras: colheita de biomassa foliar
    if (a.species === 'ant') {
      if (biomass && biomass[curIdx] > 4.0) {
        const cut = Math.min(biomass[curIdx], 1.6 * dt);
        biomass[curIdx] -= cut;
        a.foodCarried = (a.foodCarried || 0) + cut;
        a.hunger = Math.max(0, a.hunger - cut * 2.5);
        if (a.foodCarried >= 3.5) a.isReturningToNest = true;
      }
    }
    // Cupins: decomposição e forrageamento de celulose/madeira
    else if (a.species === 'termite') {
      if (biomass && biomass[curIdx] > 2.0) {
        const cut = Math.min(biomass[curIdx], 1.2 * dt);
        biomass[curIdx] -= cut;
        a.foodCarried = (a.foodCarried || 0) + cut;
        a.hunger = Math.max(0, a.hunger - cut * 2.5);
        if (a.foodCarried >= 2.8) a.isReturningToNest = true;
      }
    }
    // Abelhas: polinização e coleta de néctar
    else if (a.species === 'bee') {
      if (biomass && biomass[curIdx] > 10.0) {
        const nectar = 1.0 * dt;
        a.foodCarried = (a.foodCarried || 0) + nectar;
        a.hunger = Math.max(0, a.hunger - nectar * 3.0);
        if (a.foodCarried >= 2.8) a.isReturningToNest = true;
      }
    }

    // Movimentação em torno do ninho com curvatura radial de contenção
    a.wanderAngle += (Math.random() - 0.5) * 0.8 * dt;
    if (dNest > maxR * 0.80) {
      // Força de atração suave para não desgarrar do raio da colônia
      const angleToNest = Math.atan2(nestY - a.y, nestX - a.x);
      a.wanderAngle = angleToNest + (Math.random() - 0.5) * 0.6;
    }

    targetX = a.x + Math.cos(a.wanderAngle) * (a.speed * 1.3);
    targetY = a.y + Math.sin(a.wanderAngle) * (a.speed * 1.3);

    return { targetX, targetY };
  }

  // =========================================================================
  // CASO 3: INSETOS SOLITÁRIOS (LIBÉLULA, LOUVA-A-DEUS, BORBOLETA, ETC.)
  // =========================================================================

  // 1. Cortejo Reprodutivo para Espécies Solitárias
  const isReadyToMate = (!a.isPregnant && a.matingCooldown <= 0 && a.hunger < 50.0 && (
    (a.sex === 'female' && a.estrusDurationRemaining > 0) ||
    (a.sex === 'male')
  ));

  if (isReadyToMate) {
    let closestMate = null;
    let mateDist = 30.0;
    for (let j = 0; j < animals.length; j++) {
      const other = animals[j];
      if (other.id === a.id || other.hp <= 0 || other.species !== a.species) continue;
      if (other.sex !== a.sex && other.matingCooldown <= 0 && other.hunger < 55.0) {
        if (a.sex === 'male' && other.isPregnant) continue;
        if (a.sex === 'male' && (!other.estrusDurationRemaining || other.estrusDurationRemaining <= 0)) continue;
        const d = Math.hypot(other.x - a.x, other.y - a.y);
        if (d < mateDist) {
          mateDist = d;
          closestMate = other;
        }
      }
    }

    if (closestMate) {
      targetX = closestMate.x;
      targetY = closestMate.y;
      if (mateDist < 2.0) {
        const female = (a.sex === 'female') ? a : closestMate;
        const male = (a.sex === 'male') ? a : closestMate;
        if (typeof SpeciesReproduction !== 'undefined') {
          SpeciesReproduction.tryMatePair(female, male);
        }
      }
      return { targetX, targetY };
    }
  }

  // 2. Comportamentos tróficos específicos
  if (a.species === 'dragonfly' || a.species === 'mantis') {
    let targetBug = null;
    let minDist = 22.0;
    for (let j = 0; j < animals.length; j++) {
      const prey = animals[j];
      if (prey === a || prey.hp <= 0) continue;
      if (prey.species === 'mosquito' || prey.species === 'butterfly' || (a.species === 'mantis' && prey.species === 'grasshopper')) {
        const d = Math.hypot(prey.x - a.x, prey.y - a.y);
        if (d < minDist) {
          minDist = d;
          targetBug = prey;
        }
      }
    }

    if (targetBug && a.hunger > 3.0) {
      const dirX = targetBug.x - a.x;
      const dirY = targetBug.y - a.y;
      const dist = Math.hypot(dirX, dirY) || 1.0;
      targetX = targetBug.x;
      targetY = targetBug.y;
      if (dist <= 1.8) {
        targetBug.hp -= 25.0;
        a.hunger = Math.max(0, a.hunger - 25.0);
        if (targetBug.hp <= 0 && applyDeathDecomposition) {
          applyDeathDecomposition(targetBug.x, targetBug.y);
        }
      }
      return { targetX, targetY };
    }
  } else if (a.species === 'butterfly') {
    if (a.pollinateTimer > 0) {
      a.pollinateTimer -= dt;
      a.hunger = Math.max(0, a.hunger - 5.0 * dt);
      return { targetX: a.x, targetY: a.y };
    }
    const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
    if (biomass && biomass[curIdx] > 12.0 && Math.random() < 0.05) {
      a.pollinateTimer = 3.0 + Math.random() * 4.0;
      return { targetX: a.x, targetY: a.y };
    }
  } else if (a.species === 'mosquito') {
    // Hematofagia em mamíferos (Rato ou Gato)
    if (a.hunger > 20.0 && animals) {
      for (let j = 0; j < animals.length; j++) {
        const host = animals[j];
        if (host.hp > 0 && (host.species === 'rat' || host.species === 'cat')) {
          const hd = Math.hypot(host.x - a.x, host.y - a.y);
          if (hd < 18.0) {
            targetX = host.x;
            targetY = host.y;
            if (hd < 1.8) {
              host.hp = Math.max(1, host.hp - 0.08 * dt);
              a.hunger = Math.max(0, a.hunger - 15.0 * dt);
            }
            return { targetX, targetY };
          }
        }
      }
    }
  } else if (a.species === 'beetle' || a.species === 'roach' || a.species === 'grasshopper') {
    if (a.hunger > 15.0) {
      const curIdx = getIdx(Math.floor(a.x), Math.floor(a.y));
      if (biomass && biomass[curIdx] > 2.0) {
        const bite = Math.min(biomass[curIdx], 2.0 * dt);
        biomass[curIdx] -= bite;
        a.hunger = Math.max(0, a.hunger - bite * 3.0);
      }
    }
  }

  // 3. Deslocamento característico de inseto solitário
  a.wanderAngle += (Math.random() - 0.5) * 0.8 * dt;
  targetX = Math.max(10, Math.min(gridW - 10, a.x + Math.cos(a.wanderAngle) * (a.speed * 1.5)));
  targetY = Math.max(10, Math.min(gridH - 10, a.y + Math.sin(a.wanderAngle) * (a.speed * 1.5)));

  return { targetX, targetY };
}

// Vinculação de escopo para ambiente browser
if (typeof window !== 'undefined') {
  window.InsectSpecies = {
    createInitialInsects,
    updateInsectBehavior
  };
}
