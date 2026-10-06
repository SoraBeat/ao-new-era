--!strict
--[[
	Constantes de magia del slice. Fuente: docs/15-spec-magia-slice.md §1 y §11 (cada valor citado ahí
	con archivo:línea del servidor VB6 clásico). La tabla de hechizos está verificada contra
	libre-server/Dat/Hechizos.dat y libre-client/INIT/Hechizos.dat (herramientas/magia_ref.py hechizos).
]]

local Magia = {}

export type Hechizo = {
	id: number,
	nombre: string,
	palabras: string,
	tipo: number, -- 1 propiedades, 2 estado
	target: number, -- 1 usuarios, 3 usuarios y NPCs, 4 terreno (Fase 16c: las invocaciones)
	minSkill: number,
	mana: number,
	sta: number,
	fx: number,
	loops: number,
	subeHP: number, -- 0 nada, 1 cura, 2 daña
	minHP: number,
	maxHP: number,
	envenena: boolean,
	curaVeneno: boolean,
	paraliza: boolean,
	removerParalisis: boolean,
	-- Fase 14b (docs/27 §12)
	subeAgilidad: number, -- 0 nada, 1 sube, 2 baja
	subeFuerza: number,
	subeHam: number, -- Fase 16a (docs/31 §1, DR16-06 A): 2 baja el hambre (Ataque de Hambre, Terrible hambre de Igôr)
	minHam: number,
	maxHam: number,
	minAtrib: number,
	maxAtrib: number,
	inmoviliza: boolean,
	estupidez: boolean,
	removerEstupidez: boolean,
	revivir: boolean,
	mimetiza: boolean,
	invisibilidad: boolean,
	needStaff: number, -- StaffPower que le pide al arma del Mago
	staffAffected: boolean, -- el daño del Mago depende del báculo
	hechicero: string, -- HechizeroMsg: "<texto> <nombre>."
	targetMsg: string, -- "<caster> <texto>"
	propio: string,
	desc: string,
	-- Fase 16c (docs/33 §3): tipo 4 = invocación (uInvocacion). NumNpc × Cant, o Warp = Invocar Mascota
	numNpc: number?,
	cant: number?,
	warp: boolean?,
	-- Fase 27 (docs/47 §2): los hechizos de clase. clases: las únicas que lo aprenden y lo lanzan (nil = todas las
	-- que tienen maná). especial: un efecto propio, que resuelve MagiaService (revelar, invisible, poder, crear, himno,
	-- melodia, disonancia, raices, manada, furia, aturdidor, sed). target 2: solo criaturas (Petrificación).
	clases: { [string]: boolean }?,
	especial: string?,
	radio: number?, -- casilleros (Chebyshev) alrededor del click (revelar, raices) o del que lanza (himno, melodia)
	ticks: number?, -- lo que dura la invisibilidad (ticks de 40 ms)
	segundos: number?, -- lo que dura furia, aturdidor o sed
	ticksNpc: number?, -- raices: lo que queda inmovilizada la criatura (ticks de IA)
	maxNpc: number?, -- raices: cuántas criaturas como mucho
	sigilo: boolean?, -- invisibilidad sin destellos, que se corta al pegar o lanzar (Paso Sigiloso)
	firme: boolean?, -- invisibilidad que Revelar Invisibilidad no saca (la del Paladín)
	sinEsfuerzo: boolean?, -- resucitar sin báculo y sin que le cueste vida al que lanza (Resurrección de Mago)
	ofensivo: boolean?, -- especial que se le lanza a un enemigo (para la tolerancia del click)
	crea: { number }?, -- crear: { objeto, cantidad }
}

local function h(t: any): Hechizo
	t.envenena = t.envenena or false
	t.curaVeneno = t.curaVeneno or false
	t.paraliza = t.paraliza or false
	t.removerParalisis = t.removerParalisis or false
	t.subeAgilidad = t.subeAgilidad or 0
	t.subeFuerza = t.subeFuerza or 0
	t.minAtrib = t.minAtrib or 0
	t.subeHam = t.subeHam or 0
	t.minHam = t.minHam or 0
	t.maxHam = t.maxHam or 0
	t.maxAtrib = t.maxAtrib or 0
	for _, k in { "inmoviliza", "estupidez", "removerEstupidez", "revivir", "mimetiza", "invisibilidad", "staffAffected" } do
		t[k] = t[k] or false
	end
	t.needStaff = t.needStaff or 0
	t.subeHP = t.subeHP or 0
	t.minHP = t.minHP or 0
	t.maxHP = t.maxHP or 0
	return t
end

Magia.Hechizos = {
	[1] = h({
		id = 1, nombre = "Antídoto Mágico", palabras = "NIHIL VED", tipo = 2, target = 1,
		minSkill = 10, mana = 12, sta = 1, fx = 2, loops = 2, curaVeneno = true,
		hechicero = "Le has detenido el envenenamiento a",
		targetMsg = "te ha detenido el envenenamiento.",
		propio = "Te has detenido el envenenamiento.",
		desc = "Con este conjuro podrás mutar los fluidos tóxicos de tu cuerpo para detener su vil accionar, contrarrestando los efectos nocivos de todo tipo de ponzoñas y venenos. Se trata de un conjuro tan simple como necesario, puesto que, además de los magos que provocan envenenamiento, son varias las criaturas que lanzan veneno en estas tierras.",
	}),
	[2] = h({
		id = 2, nombre = "Dardo Mágico", palabras = "OHL VOR PEK", tipo = 1, target = 3,
		minSkill = 0, mana = 10, sta = 1, fx = 15, loops = 2, subeHP = 2, minHP = 2, maxHP = 5, -- MinSkill 6 en Hechizos.dat; 0 por docs/24 DA-03 A
		hechicero = "Has lanzado un dardo mágico sobre",
		targetMsg = "ha lanzado un dardo mágico sobre ti.",
		propio = "",
		desc = "Éste es uno de los más elementales y sencillos hechizos de ataque que podrás aprender. No causa un gran daño a la víctima, pero al consumir muy pocos recursos, resulta una herramienta muy útil para el entrenamiento de los jóvenes hechiceros.",
	}),
	[3] = h({
		id = 3, nombre = "Curar Heridas Leves", palabras = "CORP SANC", tipo = 1, target = 3,
		minSkill = 15, mana = 10, sta = 1, fx = 0, loops = 0, subeHP = 1, minHP = 1, maxHP = 5,
		hechicero = "Le has curado algunas pequeñas heridas a",
		targetMsg = "te ha curado algunas pequeñas heridas.",
		propio = "Te has curado algunas pequeñas heridas.",
		desc = "Con este sencillo conjuro podrás efectuar la sanación inmediata de pequeñas heridas y devolver lentamente la salud a quien se lo lances. Suele ser de gran utilidad para los jóvenes aprendices de magia, para poder entrenar al resguardo del ataque de las fieras salvajes.",
	}),
	[4] = h({
		id = 4, nombre = "Toxina", palabras = "SERP XON IN", tipo = 2, target = 3,
		minSkill = 20, mana = 24, sta = 3, fx = 3, loops = 2, envenena = true,
		hechicero = "Has envenenado a",
		targetMsg = "te ha envenenado.",
		propio = "Te has envenenado.",
		desc = "Con este hechizo de aprendizaje simple y veloz, podrás inundar el cuerpo de la víctima de un mortal veneno, con el que lentamente irá perdiendo la vida hasta sucumbir. Por ser un hechizo que requiere poco conocimiento, resulta de gran utilidad en las primeras etapas, fundamentalmente como modo de defensa personal e incluso para el entrenamiento.",
	}),
	[6] = h({
		id = 6, nombre = "Flecha Mágica", palabras = "VAX PER", tipo = 1, target = 3,
		minSkill = 12, mana = 20, sta = 2, fx = 33, loops = 0, subeHP = 2, minHP = 6, maxHP = 12,
		hechicero = "Has lanzado una flecha mágica sobre",
		targetMsg = "ha lanzado una flecha mágica sobre ti.",
		propio = "",
		desc = "Con este sortilegio lograrás que una inmaterial flecha impacte en la víctima produciéndole heridas de mediana gravedad. Su aprendizaje es medianamente fácil, y puede resultar de mucha utilidad para combatir contra las criaturas menores que suelen habitar los suburbios de las ciudades.",
	}),
	[9] = h({
		id = 9, nombre = "Paralizar", palabras = "HOAX VORP", tipo = 2, target = 3,
		minSkill = 60, mana = 450, sta = 65, fx = 8, loops = 0, paraliza = true,
		hechicero = "Has paralizado a",
		targetMsg = "te ha paralizado.",
		propio = "Te has paralizado.",
		desc = "Con este arcano encantamiento podrás dejar completamente petrificado a la víctima durante un determinado lapso de tiempo. Se trata de uno de los hechizos más utilizado en estas tierras por su gran utilidad tanto en el combate como en el entrenamiento.",
	}),
	[10] = h({
		id = 10, nombre = "Devolver Movilidad", palabras = "AN HOAX VORP", tipo = 2, target = 3,
		minSkill = 45, mana = 300, sta = 44, fx = 0, loops = 0, removerParalisis = true,
		hechicero = "Le has devuelto la movilidad a",
		targetMsg = "te ha devuelto la movilidad.",
		propio = "Te has devuelto la movilidad.",
		desc = "Conjuro con el cual podrás contrarrestar los efectos tanto de la parálisis como de la inmovilización. En virtud de que los hechizos de estatismo son usados con mucha frecuencia por todos las clases mágicas que habitan estas tierras, éste conjuro se vuelve prácticamente vital para cualquier valiente que esté dispuesto a combatir.",
	}),
	-- Fase 14b (docs/27 §12.1): escritos por herramientas/fase14_ref.py luau desde los dos Hechizos.dat
	[5] = h({
		id = 5, nombre = "Curar Heridas Graves", palabras = "EN CORP SANCTIS", tipo = 1, target = 3,
		minSkill = 38, mana = 40, sta = 5, fx = 9, loops = 0, subeHP = 1, minHP = 12, maxHP = 35,
		hechicero = "Le has sanado graves heridas a",
		targetMsg = "te ha sanado graves heridas.",
		propio = "Te has sanado graves heridas.",
		desc = "Con esta milagrosa sanación para las heridas más profundas y dolorosas, podrás rápidamente devolver la salud a quienes agonizan. Se trata de un conjuro de una complejidad intermedia, pero que suele resultar fundamental para los jóvenes aventureros que desean recorrer el mundo y enfrentarse con sus peligros.",
	}),
	[7] = h({
		id = 7, nombre = "Flecha Eléctrica", palabras = "SUN VAP", tipo = 1, target = 3,
		minSkill = 22, mana = 40, sta = 5, fx = 32, loops = 0, subeHP = 2, minHP = 12, maxHP = 20,
		hechicero = "Has lanzado una flecha eléctrica sobre",
		targetMsg = "ha lanzado una flecha eléctrica sobre ti.",
		propio = "",
		desc = "Éste es un interesante hechizo que te permitirá canalizar las elergías eléctricas del mundo en ataques direccionados a un determinado objetivo. Si bien el daño que causa no es muy grande, es seguramente la mejor herramienta para el entrenamiento y la defensa de los hechiceros menos experimentados.",
	}),
	[8] = h({
		id = 8, nombre = "Proyectil Mágico", palabras = "VAX IN TAR", tipo = 1, target = 3,
		minSkill = 38, mana = 45, sta = 6, fx = 10, loops = 0, subeHP = 2, minHP = 30, maxHP = 35,
		hechicero = "Has lanzado un proyectil mágico sobre",
		targetMsg = "ha lanzado un proyectil mágico sobre ti.",
		propio = "",
		desc = "Este rentable hechizo de ataque resulta el ideal para los niveles intermedios, pues les permitirá un gran poder de ataque que no sólo facilitará entrenar velozmente, si no que además, puede ser utilizado como una respetable arma en los combates contra tus adversarios.",
	}),
	[11] = h({
		id = 11, nombre = "Resucitar", palabras = "AHIL KNÄ XÄR", tipo = 2, target = 1,
		minSkill = 75, mana = 550, sta = 400, fx = 0, loops = 0, revivir = true, needStaff = 2,
		hechicero = "Has resucitado a",
		targetMsg = "te ha resucitado.",
		propio = "",
		desc = "Encanto sagrado que te permitirá devolver la vida a los difuntos. Esta increíble habilidad fue enseñada personalmente por el mismo Gulfas Morgolock al otrora Rey de los hombres en las remotas épocas del Árbol Blanco. Su aprendizaje no es fácil y su utilización resulta muy desgastante, pero sin dudas es una de las piezas más importantes de la magia de las tierras del Argentum.",
	}),
	-- Fase 16a (docs/31 §1, DR16-06 A): Hechizos.dat; solo a usuarios, con PuedeAtacar (modHechizos.bas:2132-2165)
	[12] = h({
		id = 12, nombre = "Ataque de Hambre", palabras = "ÔL AEX", tipo = 1, target = 1,
		minSkill = 5, mana = 20, sta = 2, fx = 0, loops = 0, subeHam = 2, minHam = 20, maxHam = 50,
		hechicero = "Le has generado un fuerte hambre a",
		targetMsg = "te ha generado un fuerte hambre.",
		propio = "Te has generado un fuerte hambre.",
		desc = "Embrujo que tiene por objeto provocar un considerable desbalance nutricional en el destinatario, lo que conlleva a la pérdida de energía y de concentración. Ideal para lograr la debilitación del adversario durante los combates.",
	}),
	[13] = h({
		id = 13, nombre = "Terrible hambre de Igôr", palabras = "ÛX'ÔL AEX", tipo = 1, target = 1,
		minSkill = 35, mana = 55, sta = 7, fx = 0, loops = 0, subeHam = 2, minHam = 100, maxHam = 100,
		hechicero = "Le has lanzado terrible hambre de Igôr a",
		targetMsg = "te ha lanzado terrible hambre de Igôr.",
		propio = "Te has lanzado terrible hambre de Igôr.",
		desc = "Abominable hechizo que provoca en la víctima un estado de desnutrición absoluto. Este encantamiento fue creado por el mago Nimbul mientras estudiaba la conducta de los gigantes de las montañas, la primer víctima de este hechizo fue un gigante llamado Igôr, de ahí el nombre del mismo.",
	}),
	[14] = h({
		id = 14, nombre = "Invisibilidad", palabras = "", tipo = 2, target = 1,
		minSkill = 87, mana = 500, sta = 72, fx = 0, loops = 0, invisibilidad = true,
		hechicero = "Has vuelto invisible a",
		targetMsg = "te ha vuelto invisible.",
		propio = "Te has vuelto invisible.",
		desc = "Se trata de uno de los recursos mágicos más importante de estas tierras. Con él podrás volverte (tú o a quien se lo lances) completamente invisible a la vista de los demás. Esto lo convierte en una de las herramientas más importantes utilizadas por los combatientes guerreros.",
	}),
	[15] = h({
		id = 15, nombre = "Tormenta de Fuego", palabras = "EN VAX ON TAR", tipo = 1, target = 3,
		minSkill = 60, mana = 250, sta = 29, fx = 7, loops = 0, subeHP = 2, minHP = 45, maxHP = 55, staffAffected = true,
		hechicero = "Has lanzado una tormenta de fuego sobre",
		targetMsg = "lanzó una tormenta de fuego sobre ti.",
		propio = "",
		desc = "Poderoso hechizo de ataque. Su costo en relación al daño que provoca lo convierte en un arma más propia para el combate que para el entrenamiento. Es ideal para aquellos aprendices de magia que todavía no alcanzaron a conocer el secreto de los hechizos mayores y necesitan estar bien equipados para la guerra.",
	}),
	[18] = h({
		id = 18, nombre = "Celeridad", palabras = "YUP A'INC", tipo = 1, target = 1,
		minSkill = 20, mana = 40, sta = 5, fx = 20, loops = 0, subeAgilidad = 1, minAtrib = 2, maxAtrib = 5,
		hechicero = "Has aumentado la agilidad de",
		targetMsg = "ha aumentado tu agilidad.",
		propio = "Has aumentado tu agilidad.",
		desc = "Podrás aumentar la agilidad del destinatario a través de este muy útil sortilegio. Con él devolverás al cuerpo toda la ligereza y velocidad que necesita para adquirir una verdadera destreza guerrera. Su facilidad y los pocos recursos que insume su práctica, lo convierten en una herramienta sumamente útil que no puede faltarle a ningún buen combatiente.",
	}),
	[19] = h({
		id = 19, nombre = "Torpeza", palabras = "ASYNC YUP A'INC", tipo = 1, target = 1,
		minSkill = 20, mana = 20, sta = 2, fx = 0, loops = 0, subeAgilidad = 2, minAtrib = 2, maxAtrib = 5,
		hechicero = "Has lanzado torpeza sobre",
		targetMsg = "ha lanzado torpeza sobre ti.",
		propio = "Has lanzado torpeza sobre ti.",
		desc = "Este conjuro tiene por finalidad contrarrestar o anular los efectos del hechizo de celeridad, reduciendo la agilidad y destreza que hayan adquirido quienes fueron hechizados con aquél.",
	}),
	[20] = h({
		id = 20, nombre = "Fuerza", palabras = "Ar A'kron", tipo = 1, target = 1,
		minSkill = 35, mana = 50, sta = 6, fx = 17, loops = 0, subeFuerza = 1, minAtrib = 2, maxAtrib = 5,
		hechicero = "Has lanzado fuerza sobre",
		targetMsg = "ha lanzado fuerza sobre ti.",
		propio = "Has lanzado fuerza sobre ti.",
		desc = "El poder mágico que encierra este hechizo te permitirá aumentar notoriamente la fuerza y el poderío de la persona sobre quien lo invoques. Al igual que el hechizo de celeridad, su facilidad y los pocos recursos que insume su práctica, lo convierten en una herramienta sumamente útil que no puede faltarle a ningún buen combatiente.",
	}),
	[21] = h({
		id = 21, nombre = "Debilidad", palabras = "Xoom varp", tipo = 1, target = 1,
		minSkill = 35, mana = 45, sta = 6, fx = 0, loops = 0, subeFuerza = 2, minAtrib = 2, maxAtrib = 5,
		hechicero = "Has lanzado Debilidad sobre",
		targetMsg = "ha lanzado Debilidad sobre ti.",
		propio = "Has lanzado Debilidad sobre ti.",
		desc = "Este conjuro tiene por finalidad contrarrestar o anular los efectos del hechizo de Fuerza, reduciendo la fuerza y el poderío que hayan adquirido quienes fueron hechizados con aquél.",
	}),
	[23] = h({
		id = 23, nombre = "Descarga Eléctrica", palabras = "T'HY KOOOL", tipo = 1, target = 3,
		minSkill = 85, mana = 460, sta = 67, fx = 11, loops = 0, subeHP = 2, minHP = 55, maxHP = 85, staffAffected = true,
		hechicero = "Has lanzado una descarga eléctrica sobre",
		targetMsg = "ha lanzado una descarga eléctrica sobre ti.",
		propio = "",
		desc = "Éste es uno de los hechizos de daño más poderoso de todo el Argentum. Al controlarlo podrás manipular las fuerzas de la naturaleza de modo tal que del cielo mismo caiga una fuerte descarga de electricidad sobre el objetivo. El daño que provoca en sus vícitimas puede ser mortal frente a principiantes o aprendices.",
	}),
	[24] = h({
		id = 24, nombre = "Inmovilizar", palabras = "Är Prop s'uo", tipo = 2, target = 3,
		minSkill = 60, mana = 300, sta = 44, fx = 12, loops = 0, inmoviliza = true,
		hechicero = "Has inmovilizado a",
		targetMsg = "te ha inmovilizado.",
		propio = "Te has inmovilizado.",
		desc = "Este valioso sortilegio te permitirá dejar a la víctima sin la capacidad de desplazarse, tendrá la sensación de que una poderosa fuerza lo atrae hacia el piso, y si bien podrá mover sus miembros, no podrá dejar el lugar en el que se encuentra.",
	}),
	[25] = h({
		id = 25, nombre = "Apocalipsis", palabras = "Rahma Nañarak O'al", tipo = 1, target = 3,
		minSkill = 100, mana = 1000, sta = 131, fx = 13, loops = 0, subeHP = 2, minHP = 85, maxHP = 100, staffAffected = true,
		hechicero = "Has lanzado Apocalipsis sobre",
		targetMsg = "lanzó Apocalipsis sobre ti.",
		propio = "",
		desc = "El ataque mágico más letal de estas tierras. Sólo aquellos avezados en el arte de la magia pueden aprender este temible hechizo. Su poder es fulminante y suele ser mortal para quien es víctima de él.",
	}),
	[31] = h({
		id = 31, nombre = "Aturdir", palabras = "ASYNC GAM ALÛ", tipo = 2, target = 1,
		minSkill = 30, mana = 800, sta = 76, fx = 0, loops = 0, estupidez = true,
		hechicero = "Has aturdido a",
		targetMsg = "te ha aturdido.",
		propio = "Te has aturdido.",
		desc = "Este sortilegio provocará que la víctima pierda momentáneamente todo tipo de sentido de la orientación.",
	}),
	[41] = h({
		id = 41, nombre = "Desaturdir", palabras = "AN ASYNC GAM ALÛ", tipo = 2, target = 1,
		minSkill = 45, mana = 350, sta = 44, fx = 0, loops = 0, removerEstupidez = true,
		hechicero = "Le has quitado su aturdimiento a",
		targetMsg = "te ha quitado el aturdimiento.",
		propio = "Te has quitado el aturdimiento.",
		desc = "Con este conjuro podrás contrarrestar los nefastos efectos del hechizo aturdir.",
	}),
	[42] = h({
		id = 42, nombre = "Mimetismo", palabras = "Cimim Ux Maïo", tipo = 2, target = 3,
		minSkill = 75, mana = 800, sta = 44, fx = 0, loops = 0, mimetiza = true,
		hechicero = "Haz adquirido la apariencia de",
		targetMsg = "ha adquirido magicamente tu apariencia.",
		propio = "Generas una ilusión en tu apariencia actual.",
		desc = "Con este encantamiento adquirirás temporalmente la apariencia física de otra persona.",
	}),
	-- Fase 16c (docs/33 §3): las invocaciones e Invocar Mascota, escritas por herramientas/fase16c_ref.py luau
	[16] = h({
		id = 16, nombre = "Llamado a la Naturaleza", palabras = "Nature et worg", tipo = 4, target = 4,
		minSkill = 40, mana = 120, sta = 16, fx = 0, loops = 0, numNpc = 512, cant = 2,
		hechicero = "Has Llamado a la naturaleza contra",
		targetMsg = "ha llamado a la naturaleza sobre ti.",
		propio = "",
		desc = "El secreto druídico de la invocación se concentra en este embrujo, que te permitirá implorar por ayuda a la madre naturaleza. Al hacerlo, dos temibles lobos acudirán en tu auxilio, para socorrerte de cualquier peligro que pudieses estar padeciendo.",
	}),
	[17] = h({
		id = 17, nombre = "Llamado Nigromante", palabras = "MoÎ cámus", tipo = 4, target = 4,
		minSkill = 51, mana = 400, sta = 31, fx = 0, loops = 0, numNpc = 546, cant = 2, needStaff = 1,
		hechicero = "Has invocado la ayuda de los muertos contra",
		targetMsg = "ha utilizado la Nigromancia sobre ti.",
		propio = "",
		desc = "Con este espantoso ritual de magia negra podrás lograr que los restos mortales de quienes descansan en paz, se alcen en tu ayuda. Al hacerlo, dos tenebrosos zombies emergerán de la tierra para colaborar contigo.",
	}),
	[26] = h({
		id = 26, nombre = "Invocar Elemental de Fuego", palabras = "Fir Yur'rax", tipo = 4, target = 4,
		minSkill = 100, mana = 1100, sta = 145, fx = 7, loops = 0, numNpc = 93, cant = 1, needStaff = 2,
		hechicero = "Has invocado un elemental de fuego contra",
		targetMsg = "ha invocado un elemental de fuego sobre ti.",
		propio = "",
		desc = "Encontrarás la colaboración de uno de los elementos vitales del universo, el corazón mismo del ardoroso fuego vendrá en tu auxilio.",
	}),
	[27] = h({
		id = 27, nombre = "Invocar Elemental de Agua", palabras = "Wata Mantra'rax", tipo = 4, target = 4,
		minSkill = 100, mana = 980, sta = 131, fx = 7, loops = 0, numNpc = 92, cant = 1, needStaff = 1,
		hechicero = "Has invocado un elemental de agua contra",
		targetMsg = "ha invocado un elemental de agua sobre ti.",
		propio = "",
		desc = "Encontrarás la colaboración de uno de los elementos que conforman el universo, el agua vital vendrá en tu auxilio.",
	}),
	[28] = h({
		id = 28, nombre = "Invocar Elemental de Tierra", palabras = "Mu Mantra'rax", tipo = 4, target = 4,
		minSkill = 90, mana = 980, sta = 131, fx = 7, loops = 0, numNpc = 94, cant = 1, needStaff = 1,
		hechicero = "Has invocado un elemental de tierra contra",
		targetMsg = "ha invocado un elemental de tierra sobre ti.",
		propio = "",
		desc = "Encontrarás la colaboración de uno de los elementos vitales del universo, la sagrada tierra vendrá en tu auxilio.",
	}),
	[33] = h({
		id = 33, nombre = "Invocación de Ultratumba", palabras = "Cörpse Dûm Ex", tipo = 4, target = 4,
		minSkill = 62, mana = 650, sta = 60, fx = 0, loops = 0, numNpc = 520, cant = 1, needStaff = 1,
		hechicero = "Has invocado al guerrero de ultratumba contra",
		targetMsg = "ha invocado al guerrero de ultratumba sobre ti.",
		propio = "",
		desc = "Utilizando el obscuro y controvertido arte de la nigromancia eres capaz de reanimar los restos de un guerrero y ligarlos a tu voluntad.",
	}),
	[46] = h({
		id = 46, nombre = "Invocar Mascota", palabras = "Tsälo Kai'Tor", tipo = 4, target = 4,
		minSkill = 0, mana = 0, sta = 131, fx = 7, loops = 0, warp = true,
		hechicero = "Has invocado una mascota contra",
		targetMsg = "ha invocado una mascota sobre ti.",
		propio = "",
		desc = "Podrás lograr que tu más lejana mascota regrese a tí.",
	}),
	-- Fase 17a (docs/35 §3.2-§3.3): los hechizos que solo lanzan las criaturas (Hechizos.dat del servidor). La Ceguera
	-- del Rey Pretoriano se porta como aturdimiento (el port no tiene ceguera); la Tormenta Pretoriana (36), Remover
	-- Invisibilidad (38) y "Paralizar NPCs" (39) no tienen efecto sin la IA propia de los pretorianos.
	[30] = h({
		id = 30, nombre = "Ceguera", palabras = "CAE' XitA", tipo = 2, target = 1,
		minSkill = 101, mana = 1, sta = 1, fx = 0, loops = 0, estupidez = true,
		hechicero = "Has lanzado ceguera sobre", targetMsg = "lanzó ceguera vos.", propio = "", desc = "",
	}),
	[34] = h({
		id = 34, nombre = "Llamarada de Dragon", palabras = "L´l\"am D´rg", tipo = 1, target = 1,
		minSkill = 101, mana = 1, sta = 1, fx = 13, loops = 2, subeHP = 2, minHP = 170, maxHP = 230,
		hechicero = "Has Lanzado Llamarada de Dragon a", targetMsg = "Te ha Lanzado Llamarada de Dragon.", propio = "", desc = "",
	}),
	[37] = h({
		id = 37, nombre = "Flecha Cazador Pretoriano", palabras = "", tipo = 1, target = 3,
		minSkill = 101, mana = 1, sta = 1, fx = 14, loops = 0, subeHP = 2, minHP = 130, maxHP = 160,
		hechicero = "Has lanzado una flecha sobre", targetMsg = "lanzó un flechazo sobre vos.", propio = "", desc = "",
	}),
	[44] = h({
		id = 44, nombre = "Flecha Elfica", palabras = "", tipo = 1, target = 1,
		minSkill = 101, mana = 1, sta = 1, fx = 0, loops = 2, subeHP = 2, minHP = 30, maxHP = 35,
		hechicero = "Has lanzado una flecha elfica sobre", targetMsg = "ha lanzado una flecha elfica sobre ti.", propio = "", desc = "",
	}),
	[45] = h({
		id = 45, nombre = "Drenar", palabras = "", tipo = 1, target = 1,
		minSkill = 101, mana = 1, sta = 1, fx = 35, loops = 2, subeHP = 2, minHP = 35, maxHP = 40,
		hechicero = "Has drenado vida de", targetMsg = "te ha drenado vida.", propio = "", desc = "",
	}),
	[47] = h({
		id = 47, nombre = "Flecha Ladrón Pretoriano", palabras = "", tipo = 1, target = 3,
		minSkill = 101, mana = 1, sta = 1, fx = 14, loops = 0, subeHP = 2, minHP = 30, maxHP = 60,
		hechicero = "Has lanzado una flecha sobre", targetMsg = "lanzó un flechazo sobre vos.", propio = "", desc = "",
	}),
	[49] = h({
		id = 49, nombre = "Apocalipsis (NPC)", palabras = "Rahma Nañarak O'al", tipo = 1, target = 3,
		minSkill = 101, mana = 1, sta = 1, fx = 13, loops = 0, subeHP = 2, minHP = 170, maxHP = 190,
		hechicero = "Has lanzado Apocalipsis sobre", targetMsg = "lanzó Apocalipsis sobre ti.", propio = "", desc = "",
	}),
	[50] = h({
		id = 50, nombre = "Descarga Eléctrica (NPC)", palabras = "T'HY KOOOL", tipo = 1, target = 3,
		minSkill = 101, mana = 1, sta = 1, fx = 11, loops = 0, subeHP = 2, minHP = 150, maxHP = 170,
		hechicero = "Has lanzado una descarga eléctrica sobre", targetMsg = "ha lanzado una descarga eléctrica sobre ti.", propio = "", desc = "",
	}),
	-- Fase 27 (docs/47 §2): los hechizos de clase y Petrificación, escritos por herramientas/fase27_ref.py luau
	[51] = h({
		id = 51, nombre = "Revelar Invisibilidad", palabras = "AN VIS UMBRA", tipo = 2, target = 4,
		minSkill = 70, mana = 250, sta = 30, fx = 32, loops = 0, especial = "revelar", radio = 4,
		clases = { Mago = true },
		hechicero = "Has revelado a",
		targetMsg = "te ha quitado la invisibilidad.",
		propio = "",
		desc = "Un destello arcano barre la zona que elijas y deja a la vista a quienes se ocultan tras un hechizo de invisibilidad. No alcanza a quien se esconde por su propia habilidad, ni a la invisibilidad de los Paladines.",
	}),
	[52] = h({
		id = 52, nombre = "Resurrección de Mago", palabras = "AHIL KNA MAGUS", tipo = 2, target = 1,
		minSkill = 75, mana = 550, sta = 400, fx = 35, loops = 0, revivir = true, sinEsfuerzo = true,
		clases = { Mago = true },
		hechicero = "Has resucitado a",
		targetMsg = "te ha resucitado.",
		propio = "",
		desc = "La forma en que los magos devuelven la vida: sin báculo y sin que el esfuerzo les cueste la salud. Pide, como siempre, la barra de energía llena.",
	}),
	[53] = h({
		id = 53, nombre = "Paso Sigiloso", palabras = "", tipo = 2, target = 1,
		minSkill = 60, mana = 300, sta = 40, fx = 0, loops = 0, especial = "invisible", ticks = 1000, sigilo = true,
		clases = { Asesino = true },
		hechicero = "",
		targetMsg = "",
		propio = "Te desvaneces entre las sombras.",
		desc = "La invisibilidad de los asesinos: dura cuarenta segundos, no tiene destellos y nadie oye tus pasos. Se corta en el momento en que golpeas o lanzas un hechizo.",
	}),
	[54] = h({
		id = 54, nombre = "Poder de las Sombras", palabras = "UMBRA A'KRON INC", tipo = 1, target = 1,
		minSkill = 40, mana = 150, sta = 20, fx = 17, loops = 0, especial = "poder",
		clases = { Asesino = true },
		hechicero = "",
		targetMsg = "",
		propio = "Las sombras te dan fuerza y agilidad.",
		desc = "Celeridad y Fuerza a la vez, y de a mucho: con lanzarlo dos veces se llega al máximo de las dos.",
	}),
	[55] = h({
		id = 55, nombre = "Generar Comida", palabras = "PAN EX NIHIL", tipo = 2, target = 1,
		minSkill = 10, mana = 40, sta = 5, fx = 14, loops = 1, especial = "crear", crea = { 20023, 5 },
		clases = { Clerigo = true },
		hechicero = "",
		targetMsg = "",
		propio = "Has creado pan.",
		desc = "Una plegaria sencilla que pone cinco panes en tu inventario. El pan conjurado es solo para quien lo conjura: no se vende ni se pasa.",
	}),
	[56] = h({
		id = 56, nombre = "Generar Bebida", palabras = "VIN EX NIHIL", tipo = 2, target = 1,
		minSkill = 10, mana = 40, sta = 5, fx = 14, loops = 1, especial = "crear", crea = { 20042, 5 },
		clases = { Clerigo = true },
		hechicero = "",
		targetMsg = "",
		propio = "Has creado vino.",
		desc = "Una plegaria sencilla que pone cinco botellas de vino en tu inventario. El vino conjurado es solo para quien lo conjura: no se vende ni se pasa.",
	}),
	[57] = h({
		id = 57, nombre = "Resurrección Divina", palabras = "AHIL KNA SANCTIS", tipo = 2, target = 1,
		minSkill = 75, mana = 300, sta = 400, fx = 35, loops = 0, revivir = true,
		clases = { Clerigo = true },
		hechicero = "Has resucitado a",
		targetMsg = "te ha resucitado.",
		propio = "",
		desc = "El Resucitar de los clérigos: lo mismo, por mucho menos maná.",
	}),
	[58] = h({
		id = 58, nombre = "Descarga Mortal", palabras = "T'HY MORT KOOL", tipo = 1, target = 3,
		minSkill = 85, mana = 260, sta = 67, fx = 11, loops = 0, subeHP = 2, minHP = 55, maxHP = 85,
		clases = { Clerigo = true, Paladin = true },
		hechicero = "Has lanzado una descarga mortal sobre",
		targetMsg = "ha lanzado una descarga mortal sobre ti.",
		propio = "",
		desc = "La Descarga Eléctrica de clérigos y paladines: el mismo daño, por mucho menos maná.",
	}),
	[59] = h({
		id = 59, nombre = "Himno de Batalla", palabras = "CANT A'KRON YUP", tipo = 1, target = 1,
		minSkill = 40, mana = 150, sta = 20, fx = 20, loops = 0, minAtrib = 2, maxAtrib = 5, especial = "himno", radio = 8,
		clases = { Bardo = true },
		hechicero = "",
		targetMsg = "te alienta con su Himno de Batalla.",
		propio = "Entonas el Himno de Batalla.",
		desc = "Tu canto sube la agilidad y la fuerza, tuyas y de los compañeros de tu grupo que estén cerca.",
	}),
	[60] = h({
		id = 60, nombre = "Melodía Curativa", palabras = "CANT CORP SANCTIS", tipo = 1, target = 1,
		minSkill = 50, mana = 200, sta = 25, fx = 9, loops = 0, minHP = 20, maxHP = 40, especial = "melodia", radio = 8,
		clases = { Bardo = true },
		hechicero = "",
		targetMsg = "te cura con su Melodia Curativa.",
		propio = "Entonas la Melodia Curativa.",
		desc = "Una melodía que cura tus heridas y las de los compañeros de tu grupo que estén cerca.",
	}),
	[61] = h({
		id = 61, nombre = "Disonancia", palabras = "ASYNC CANT XOOM", tipo = 1, target = 1,
		minSkill = 45, mana = 150, sta = 20, fx = 33, loops = 0, especial = "disonancia", ofensivo = true,
		clases = { Bardo = true },
		hechicero = "Has desafinado los sentidos de",
		targetMsg = "te ha lanzado Disonancia: pierdes tu fuerza y tu agilidad extra.",
		propio = "",
		desc = "Una nota desafinada que le quita al enemigo lo que ganó con Celeridad, Fuerza o pociones: su agilidad y su fuerza vuelven a lo normal.",
	}),
	[62] = h({
		id = 62, nombre = "Raíces", palabras = "Nature et radix", tipo = 2, target = 4,
		minSkill = 55, mana = 350, sta = 45, fx = 12, loops = 0, especial = "raices", radio = 2, ticksNpc = 40, maxNpc = 6,
		clases = { Druida = true },
		hechicero = "",
		targetMsg = "",
		propio = "",
		desc = "Raíces que brotan del suelo e inmovilizan por unos quince segundos a las criaturas de la zona que elijas (hasta seis).",
	}),
	[63] = h({
		id = 63, nombre = "Sanar Manada", palabras = "Nature corp sanc", tipo = 1, target = 1,
		minSkill = 40, mana = 200, sta = 25, fx = 9, loops = 0, especial = "manada",
		clases = { Druida = true },
		hechicero = "",
		targetMsg = "",
		propio = "",
		desc = "Cura por completo a todas tus mascotas e invocaciones que tengas a la vista.",
	}),
	[64] = h({
		id = 64, nombre = "Furia Salvaje", palabras = "Nature et furor", tipo = 2, target = 1,
		minSkill = 60, mana = 300, sta = 40, fx = 33, loops = 0, especial = "furia", segundos = 30,
		clases = { Druida = true },
		hechicero = "",
		targetMsg = "",
		propio = "Tus criaturas entran en furia!",
		desc = "Durante treinta segundos, los golpes de tus mascotas e invocaciones hacen el doble de daño.",
	}),
	[65] = h({
		id = 65, nombre = "Invisibilidad Mejorada", palabras = "", tipo = 2, target = 1,
		minSkill = 75, mana = 400, sta = 60, fx = 0, loops = 0, especial = "invisible", ticks = 750, firme = true,
		clases = { Paladin = true },
		hechicero = "",
		targetMsg = "",
		propio = "Te has vuelto invisible.",
		desc = "La invisibilidad de los paladines: dura treinta segundos y Revelar Invisibilidad no te la puede quitar. Por lo demás es la de siempre: tiene destellos. Solo se lanza sobre uno mismo.",
	}),
	[66] = h({
		id = 66, nombre = "Golpe Aturdidor", palabras = "GAM ALU ICTUS", tipo = 2, target = 1,
		minSkill = 40, mana = 120, sta = 20, fx = 14, loops = 1, especial = "aturdidor", segundos = 20,
		clases = { Bandido = true },
		hechicero = "",
		targetMsg = "",
		propio = "Tu proximo golpe sera aturdidor.",
		desc = "Cargas tu arma: el próximo golpe cuerpo a cuerpo que aciertes en los siguientes veinte segundos aturde a un jugador por diez segundos, o deja quieta a una criatura por unos seis.",
	}),
	[67] = h({
		id = 67, nombre = "Sed de Sangre", palabras = "SANG HAUR", tipo = 2, target = 1,
		minSkill = 50, mana = 150, sta = 20, fx = 2, loops = 2, especial = "sed", segundos = 20,
		clases = { Bandido = true },
		hechicero = "",
		targetMsg = "",
		propio = "Sientes sed de sangre.",
		desc = "Durante veinte segundos, cada golpe cuerpo a cuerpo que aciertes te devuelve en vida la cuarta parte del daño que hiciste.",
	}),
	[68] = h({
		id = 68, nombre = "Petrificación", palabras = "HOAX PETRA", tipo = 2, target = 2,
		minSkill = 30, mana = 200, sta = 30, fx = 8, loops = 0, paraliza = true,
		clases = { Mago = true, Clerigo = true, Asesino = true, Bardo = true, Druida = true, Bandido = true, Paladin = true },
		hechicero = "Has petrificado a",
		targetMsg = "",
		propio = "",
		desc = "Paraliza a una criatura, igual que Paralizar, pero pide menos Magia y menos maná. No sirve contra jugadores. Es el premio del nivel 18 de las clases mágicas.",
	}),
}

-- Fase 27 (docs/47 §2): ¿esa clase puede aprender y lanzar el hechizo? Los comunes, cualquiera; los de clase, las suyas.
function Magia.deClase(hz: Hechizo, clase: string): boolean
	return hz.clases == nil or hz.clases[clase] == true
end

-- Lista del personaje de prueba de cada clase (DF7-01 A: por MinSkill, con el Dardo en el slot 1; DF7-02 A: sin
-- hechizos las clases sin maná). Fase 14b (docs/27 §12.1): los 23, por MinSkill (a igual MinSkill, por número).
-- Fase 27 (docs/47 §2): cada clase lleva los comunes y los suyos.
local Clases = require(script.Parent.Clases)
Magia.Listas = {} :: { [string]: { number } }
local function listaDePrueba(clase: string): { number }
	local lista = { 2 }
	local resto = {}
	for id, x in Magia.Hechizos do
		if id ~= 2 and x.minSkill <= 100 and Magia.deClase(x, clase) then -- los de las criaturas (MinSkill 101, Fase 17a) no van
			table.insert(resto, x)
		end
	end
	table.sort(resto, function(a, b)
		return if a.minSkill ~= b.minSkill then a.minSkill < b.minSkill else a.id < b.id
	end)
	for _, x in resto do
		table.insert(lista, x.id)
	end
	return lista
end
-- Los que tiene un personaje nuevo (DF13-23 A, como AddItemsToNewUser): Dardo Mágico las clases con maná (DM16-09 A:
-- el Druida además Invocar Mascota); el resto se aprende con pergaminos. Los creados en la Fase 12 conservan los 7.
Magia.Iniciales = {} :: { [string]: { number } }
for nombre, d in Clases.datos do
	Magia.Listas[nombre] = if d.magica then listaDePrueba(nombre) else {}
	Magia.Iniciales[nombre] = d.iniciales
end
-- Fase 27 (docs/47 §2): 40 lugares (el original, 35): un Clérigo con todos los comunes y los suyos pasa de 35
Magia.MaxHechizos = 40
-- docs/28 §11: el objetivo apuntado por id (flechas y hechizos) vale si quedó a esta distancia del tile (Chebyshev)
Magia.ToleranciaId = 2

-- ─── Fórmulas ────────────────────────────────────────────────────────────────
Magia.BonusNivelHechizo = 3 -- % por nivel del caster (modHechizos.bas:2318, :2355): curaciones y daño a jugadores
Magia.BonusNivelDanoCriaturas = 10 -- docs/24 DA-02 A + C: daño de hechizos a criaturas (el original usa 3)

-- ─── Estados (ticks de 40 ms) ────────────────────────────────────────────────
Magia.IntervaloParalizado = 500 -- Server.ini:125 (20 s)
Magia.IntervaloParalizadoReducido = 37 -- Admin.bas:82 (≈1,5 s)
-- Fase 28 (docs/48 §3, pedido del autor): al que no tiene maná (no puede sacársela solo), Paralizar e Inmovilizar le
-- duran la mitad: 10 s
Magia.IntervaloParalizadoSinMana = 250
-- Fase 31 (docs/51 §4, D31-02, pedido del autor): el Trabajador, desde el nivel 18, es inmune a la parálisis y a la
-- inmovilización que le tire OTRO JUGADOR (los hechizos Paralizar e Inmovilizar y el golpe con Guantes de Hurto), en
-- cualquier mapa. Las de las criaturas le siguen entrando. Es el que mina, tala y pesca: quieto era presa fácil.
Magia.InmuneParalisisClase = "Trabajador"
Magia.InmuneParalisisNivel = 18
function Magia.inmuneAParalisis(clase: string?, elv: number?): boolean
	return clase == Magia.InmuneParalisisClase and (elv or 0) >= Magia.InmuneParalisisNivel
end
Magia.RangoParalisisX = 12 -- MinXBorder (General.bas:534)
Magia.RangoParalisisY = 10 -- MinYBorder; el original lo ignora por un And (DF7-15 B: corregido)
Magia.IntervaloVeneno = 500 -- Server.ini:124
-- Fase 25 (docs/44 §4, pedido del autor; fase25_ref.veneno): el veneno ya no es eterno. Pega VenenoGolpes veces (una
-- cada IntervaloVeneno: 20 s) y se va solo: un minuto. Volver a envenenarse arranca la cuenta de nuevo.
Magia.VenenoGolpes = 3
Magia.MsgVenenoFin = "El veneno ha dejado de hacerte efecto."
-- Fase 25 (docs/44 §5; fase25_ref.paralisis_npc): la parálisis y la inmovilización que lanza una criatura
Magia.ParalisisNpcSinMana = 125 -- ticks: 5 s para el que no tiene maná
Magia.InmunidadParalisisNpcSeg = 10 -- al zafar, por este rato ninguna criatura lo vuelve a paralizar
-- Fase 14b (docs/27 §12)
Magia.IntervaloInvisible = 500 -- Server.ini:126: invisibilidad y mimetismo (cuentan hasta acá: 501 ticks)
-- Fase 21 (docs/40 §5; nuestro, el AO clásico no lo tiene): el invisible por hechizo se deja ver cada 10 s durante 2 s,
-- translúcido y sin nombre. Con 20 s de invisibilidad, una vez: del segundo 10 al 12. (fase21_ref.destello)
Magia.DestelloCada = 175 -- ticks de 40 ms: cada 7 s, o sea dos destellos en los 20 s (del 7 al 9 y del 14 al 16)
Magia.DestelloDura = 50
Magia.MsgAlguienInvisible = "Ves a alguien invisible."
-- ¿Se ve el invisible cuando su contador (ticks desde que lanzó el hechizo) vale `cont`? En el último tick ya no.
-- Fase 27 (docs/47 §2.2): tope = lo que dura esa invisibilidad (la común, IntervaloInvisible; la del Paladín, más)
function Magia.destello(cont: number, tope: number?): boolean
	return cont >= Magia.DestelloCada and cont < (tope or Magia.IntervaloInvisible) and cont % Magia.DestelloCada < Magia.DestelloDura
end
Magia.IntervaloEstupidez = 500 -- Counters.Ceguera = IntervaloParalizado (modHechizos.bas:1621)
Magia.DuracionBuff, Magia.DuracionDebuff = 1200, 700 -- flags.DuracionEfecto (modHechizos.bas:2228, :2248)
Magia.MinAtributo = 6 -- MINATRIBUTOS (Declares.bas:424); el tope es ConfigProg.MaxAtributo (40)
Magia.Apocalipsis = 25 -- APOCALIPSIS_SPELL_INDEX: sin el descuento del Druida
Magia.FlautaElfica, Magia.FlautaMagica, Magia.LaudElfico, Magia.LaudMagico = 1050, 208, 1049, 696
Magia.BonusElfico = 1.04 -- Laúd y Flauta Élficos (modHechizos.bas:2370-2373)
Magia.VenenoMin, Magia.VenenoMax = 1, 5 -- General.bas:1322

-- ─── Hechizos de clase (Fase 27, docs/47 §2; herramientas/fase27_ref.py) ────
Magia.Petrificacion = 68 -- el premio del nivel 18 de las clases mágicas (Config/Progresion.ExtraNivel)
Magia.SedPorc = 25 -- Sed de Sangre: el % del daño del golpe que vuelve como vida
Magia.FuriaMulti = 2 -- Furia Salvaje: por cuánto se multiplica el golpe de las mascotas
Magia.AturdidorTicks = 250 -- Golpe Aturdidor a un jugador: 10 s aturdido (ticks de 40 ms)
Magia.AturdidorTicksNpc = 16 -- a una criatura: unos 6 s paralizada (ticks de IA)
Magia.Msg = {
	Clase = "Tu clase no puede lanzar este hechizo.",
	SoloCriaturas = "Este hechizo actua solo sobre criaturas.",
	Inmune = "%s es inmune a la paralisis.", -- (Fase 31: al que le tira Paralizar o Inmovilizar a un Trabajador de nivel 18 o más)
	InmuneVos = "Intentaron paralizarte, pero eres inmune.",
	YaInvisible = "Ya eres invisible.",
	NadieInvisible = "No hay nadie invisible ahi.",
	Revelaste = "Has dejado a la vista a %d.",
	Revelado = "%s te ha quitado la invisibilidad.",
	SigiloRoto = "Has salido de las sombras.",
	SinLugar = "No tienes lugar en el inventario.",
	Himno = "Tu agilidad y tu fuerza aumentan.",
	SinCriaturas = "No hay criaturas a tu alcance ahi.",
	Raices = "Las raices atrapan a %d.",
	SinManada = "No tienes criaturas a la vista.",
	Manada = "Has sanado a %d.",
	FuriaFin = "La furia de tus criaturas se apaga.",
	AturdidorFin = "Tu golpe aturdidor se disipa.",
	Aturdiste = "Tu golpe ha aturdido a %s!",
	Aturdido = "El golpe de %s te ha aturdido!",
	AturdisteNpc = "Tu golpe ha dejado quieta a la criatura!",
	SedFin = "Tu sed de sangre se apaga.",
}

-- ─── Meditar ─────────────────────────────────────────────────────────────────
Magia.TiempoInicioMeditar = 0 -- ms; el original tiene 2000 (Declares.bas:249), sacado en docs/24 DA-01 A
Magia.PorcentajeRecuperoMana = 6 -- Balance.dat [EXTRA]
-- docs/24 DA-01 A: el maná sube en un pulso fijo cada 25 ticks (1 s), con la misma velocidad promedio que la tirada
-- del original (manaPorPulso / suerte por tick). La tirada de cada tick queda para el skill Meditar.
Magia.TicksPorPulsoMana = 25
Magia.FxMeditar = { { hasta = 12, fx = 4 }, { hasta = 24, fx = 5 }, { hasta = 34, fx = 6 }, { hasta = 41, fx = 16 }, { hasta = math.huge, fx = 34 } }

-- ─── Rango del click (ModAreas.bas:52-53; D-40 C) ────────────────────────────
Magia.RangoVisionX = 11
Magia.RangoVisionY = 9

-- ─── Anti-spam de mensajes (UltimoMensaje, DF7-09 A) ─────────────────────────
Magia.MsgParalizado = 1
Magia.MsgManaRecuperado = 22

-- ─── Cliente ─────────────────────────────────────────────────────────────────
Magia.ColorPalabras = Color3.fromRGB(200, 250, 150)
Magia.ColorCurar = Color3.fromRGB(173, 216, 230) -- colores.dat [55]
Magia.ColorTrabajo = Color3.fromRGB(173, 216, 230) -- colores.dat [56]
Magia.ColorParalisis = Color3.fromRGB(230, 230, 250) -- mDx8_Engine.bas:287, alfa 180
Magia.DialogoMs = 5000 -- + 100 ms por carácter (clsDialogs.cls)
Magia.DialogoMsPorCaracter = 100
Magia.DialogoMaxLinea = 18

return Magia
