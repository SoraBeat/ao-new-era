--!strict
-- GENERADO por herramientas/fase20_ref.py exportar (desde libre-server/Dat/Quests.DAT) — no editar a mano.
-- Las 22 quests del port (docs/39 §2): con los datos corregidos (§2.2) y los premios y niveles de docs/43 §1 (Fase 24).
-- matar = { { criatura, cantidad } }, traer y premios = { { objeto, cantidad } }. exp y oro, la primera vez;
-- expRepetir y oroRepetir, las siguientes (sin objetos). El NPC que da cada una: Generado/Npcs (campo quest).
-- nuevos: los NPC de quest que el original nunca colocó, { npc, mapa, x, y } (el servidor los suma al mapa).

local M = {}

M.quests = {
	[1] = { id = 1, nombre = "Bichos molestos", nivel = 1, matar = { { 500, 3 } }, traer = {}, premios = {}, exp = 500, oro = 100, expRepetir = 210, oroRepetir = 25,
		desc = "Se ha reportado una plaga de molestos murcielagos en todo el territorio. Por favor mata a 3 de ellos para colaborar." },
	[2] = { id = 2, nombre = "Caceria de lobos", nivel = 2, matar = { { 501, 15 } }, traer = { { 414, 15 } }, premios = {}, exp = 10500, oro = 525, expRepetir = 10500, oroRepetir = 525,
		desc = "Se han reportado muchas muertes en los alrededores de la ciudad de Banderbill. La milicia ha hecho un llamado a la comunidad para intentar solucionar este problema. Debes matar 15 lobos y traerme sus pieles para recibir una recompensa." },
	[3] = { id = 3, nombre = "Caceria salvaje", nivel = 5, matar = {}, traer = { { 414, 10 }, { 415, 10 } }, premios = { { 238, 1 } }, exp = 66500, oro = 3325, expRepetir = 66500, oroRepetir = 3325,
		desc = "Matheus, el mago, precisa controlar la sobrepoblacion de lobos y osos en las cercanias de Ullathorpe. Ayudalo a retomar el control y te recompensara..." },
	[4] = { id = 4, nombre = "Contra los muertos vivos", nivel = 15, matar = { { 503, 10 } }, traer = {}, premios = { { 559, 1 } }, exp = 8032, oro = 3000, expRepetir = 8032, oroRepetir = 750,
		desc = "Ayuda por favor!! Una horda de esqueletos esta acechando mi granja... Por favor deshazte de ellos y te recompensare con parte de mis ganancias." },
	[5] = { id = 5, nombre = "El peligroso Dorck", nivel = 20, matar = { { 510, 10 }, { 523, 10 } }, traer = { { 3, 10 } }, premios = { { 851, 1 } }, exp = 129150, oro = 6457, expRepetir = 129150, oroRepetir = 6457,
		desc = "Selenna, una importante miembro del circulo de druidas del Imperio, se encuentra preocupada por el peligro que significan las malignas criaturas que habitan en el bosque de Dorck. Cualquier aventurero que asesine a los aracnidos Gigantes y orcos con sus Hachas, tendra una justa recompesa." },
	[6] = { id = 6, nombre = "Justicia divina", nivel = 18, matar = { { 531, 10 }, { 530, 10 } }, traer = {}, premios = { { 1003, 1 }, { 404, 1 } }, exp = 123620, oro = 7000, expRepetir = 123620, oroRepetir = 6181,
		desc = "Icaro, el pregonero de Banderbill, ha dictaminado una caceria furtiva de asesinos y bandidos debido a multiples actos ilicitos que los pobladores del imperio han sufrido. Acaba con ellos y seras bien recompensado." },
	[7] = { id = 7, nombre = "Capricho del Rey", nivel = 35, matar = { { 715, 3 }, { 716, 3 }, { 717, 3 } }, traer = {}, premios = { { 129, 1 }, { 659, 1 } }, exp = 897007, oro = 44850, expRepetir = 897007, oroRepetir = 44850,
		desc = "Los caprichos de Rey deben de ser cumplidos a rajatabla y nos ha pedido construir un anillo de bodas. Para ello necesitamos que nos ayudes matando a las diferentes razas de etogniles que yacen escondidos por aqui. Consigue lo solicitado y la recompensa sera tan grande como tu valentia." },
	[8] = { id = 8, nombre = "Sombras colosales", nivel = 40, matar = { { 930, 1 }, { 933, 3 }, { 934, 3 } }, traer = {}, premios = { { 1146, 1 }, { 403, 6 } }, exp = 8000000, oro = 367500, expRepetir = 7350000, oroRepetir = 367500,
		desc = "Sir Arthur es el protector del Reino y esta reclutando gente con agallas para mantener alejado de la superficie a los titanes que amenazan con salir y destruir todo a su paso. Consigue matarlos y obtendras la mayor de todas las recompensas." },
	[9] = { id = 9, nombre = "Espiritu Guerrero", nivel = 25, matar = { { 531, 100 }, { 530, 100 }, { 523, 100 } }, traer = {}, premios = { { 1138, 1 }, { 532, 1 } }, exp = 1512700, oro = 100000, expRepetir = 1512700, oroRepetir = 75635,
		desc = "Mithandrill es un elfo del bosque radicado en Arghal que no puede salir a recolectar moras por una constante amenaza de criaturas salvajes, asesinos y bandidos. Ayuda al elfo y seras recompensado con objetos y monedas." },
	[10] = { id = 10, nombre = "Ojo por ojo", nivel = 30, matar = { { 510, 20 }, { 518, 5 }, { 552, 2 } }, traer = {}, premios = { { 1134, 1 } }, exp = 861700, oro = 500000, expRepetir = 861700, oroRepetir = 125000,
		desc = "Orfeo, el huerfano, ha jurado vengar la muerte de sus padres y por ello a decidido entregar parte de su herencia a quienes maten las criaturas que asaltaron su ciudad." },
	[12] = { id = 12, nombre = "Un cazador en apuros.", nivel = 15, matar = { { 515, 15 }, { 510, 15 }, { 523, 25 } }, traer = {}, premios = { { 664, 1 } }, exp = 366275, oro = 18313, expRepetir = 366275, oroRepetir = 18313,
		desc = "Ayudame a controlar las plagas del bosque y te recompenzare!" },
	[13] = { id = 13, nombre = "Un mago en apuros.", nivel = 15, matar = { { 515, 15 }, { 510, 15 }, { 523, 25 } }, traer = {}, premios = { { 37, 5000 }, { 394, 1 } }, exp = 366275, oro = 18313, expRepetir = 366275, oroRepetir = 18313,
		desc = "Ayudame a controlar las plagas del bosque y te recompenzare!" },
	[14] = { id = 14, nombre = "Bestias de las profundidades.", nivel = 25, matar = { { 706, 5 } }, traer = {}, premios = { { 500, 1 }, { 131, 1 }, { 128, 1 }, { 36, 500 } }, exp = 367500, oro = 25000, expRepetir = 367500, oroRepetir = 18375,
		desc = "Temibles bestias estan aterrorizando a mi grupo de exploradores! Ayudame con ellas vere que seas recompenzado." },
	[15] = { id = 15, nombre = "Un elfo embarrado.", nivel = 30, matar = { { 505, 250 }, { 611, 100 }, { 539, 100 }, { 534, 50 } }, traer = {}, premios = { { 496, 1 } }, exp = 5661250, oro = 283062, expRepetir = 5661250, oroRepetir = 283062,
		desc = "Esta mancha de lodo que no se quita! Por favor ayudame con estas criaturas y vere que estes bien vestido." },
	[16] = { id = 16, nombre = "La energia de las islas.", nivel = 30, matar = { { 551, 50 }, { 549, 50 }, { 513, 50 }, { 550, 25 }, { 706, 5 } }, traer = {}, premios = { { 536, 1 } }, exp = 6369300, oro = 318465, expRepetir = 6369300, oroRepetir = 318465,
		desc = "La vida en esperanza esta sucumbiendo frente a terribles hechizos del mal. Por favor ayudame a recomponer el balance de las islas." },
	[17] = { id = 17, nombre = "Protector de las islas.", nivel = 30, matar = { { 554, 20 }, { 511, 25 }, { 513, 25 }, { 537, 10 }, { 517, 10 } }, traer = {}, premios = { { 537, 1 }, { 536, 1 } }, exp = 2827650, oro = 141382, expRepetir = 2827650, oroRepetir = 141382,
		desc = "Una horda de deformidades malignas hace peligrar el balance natural de estas islas, por favor ayudame a restaurarlo." },
	[18] = { id = 18, nombre = "Peligros del mar abierto.", nivel = 30, matar = { { 602, 25 }, { 518, 25 }, { 606, 25 }, { 604, 25 } }, traer = {}, premios = { { 537, 1 } }, exp = 1277500, oro = 63875, expRepetir = 1277500, oroRepetir = 63875,
		desc = "Cientos de navegantes estan siendo atacados por los mas peligrosos monstruos marinos. Sube a tu barca y ayudame con ellos. Prometo una paella y grandes recompensas al terminar." },
	[19] = { id = 19, nombre = "Huye cobarde!.", nivel = 25, matar = { { 511, 50 }, { 554, 50 }, { 543, 5 } }, traer = {}, premios = { { 37, 1500 }, { 38, 1500 } }, exp = 2635500, oro = 131775, expRepetir = 2635500, oroRepetir = 131775,
		desc = "Por favor ayudame a salir de aqui! Esta oscuro y lleno de bichos feos, juro recompensarte!" },
	[21] = { id = 21, nombre = "El coleccionista de huesos.", nivel = 35, matar = { { 553, 200 }, { 550, 100 }, { 551, 50 }, { 517, 25 } }, traer = {}, premios = { { 37, 10000 }, { 38, 10000 }, { 36, 2000 }, { 39, 2000 } }, exp = 23852500, oro = 1192625, expRepetir = 23852500, oroRepetir = 1192625,
		desc = "Este es un calabozo lleno de oscuras criaturas. Derrotalas y asi podre hacerte algunas pocimas que te ayudaran en el camino." },
	[22] = { id = 22, nombre = "En busca de las jaurias.", nivel = 25, matar = { { 501, 100 }, { 765, 15 }, { 703, 15 }, { 766, 15 }, { 701, 5 } }, traer = {}, premios = { { 37, 7000 }, { 38, 5000 }, { 36, 3000 }, { 39, 2000 } }, exp = 1116500, oro = 75000, expRepetir = 1116500, oroRepetir = 55825,
		desc = "Jaurias de lobos atacan mis mineros por todo el mundo y pronto dejaremos de poder pagarle la cuota al rey. Necesitamos un viajero audaz que termine con estos lobos!" },
	[23] = { id = 23, nombre = "Todos a estribor!", nivel = 26, matar = { { 548, 200 } }, traer = {}, premios = { { 403, 1 } }, exp = 11900000, oro = 595000, expRepetir = 11900000, oroRepetir = 595000,
		desc = "El mundo entero cree que por que somos pocos somos un pueblo debil. ja! Traeme escamas de Leviatan y armare fuertes armaduras." },
	[24] = { id = 24, nombre = "Cava tu propia tumba.", nivel = 16, matar = { { 598, 20 }, { 596, 20 }, { 599, 20 }, { 545, 20 }, { 600, 10 } }, traer = {}, premios = { { 37, 1500 }, { 38, 1500 }, { 380, 1 } }, exp = 980000, oro = 49000, expRepetir = 980000, oroRepetir = 49000,
		desc = "Llevo mucho tiempo en el mercado negro de la muerte pero nunca antes me habian hecho un pedido de huesos tan grande. Ayudame a completar mi pedido y te pagare." },
}

M.nuevos = {
	{ 957, 10, 50, 49 }, -- Meef
	{ 958, 61, 46, 82 }, -- Lyso
	{ 959, 281, 46, 84 }, -- YIYO
}

return M
