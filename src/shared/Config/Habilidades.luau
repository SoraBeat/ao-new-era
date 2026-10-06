--!strict
--[[
	Ocultarse y robar (Fase 14a, docs/27 §5 y §6). Fórmulas: herramientas/fase14_ref.py ocultar / robar.
]]

local Habilidades = {}

-- Ocultarse (Trabajo.bas:36-173)
Habilidades.IntervaloOculto = 500 -- Server.ini:127: el multiplicador de la duración (en ticks de 40 ms)
Habilidades.SkillCazadorPermanente = 90 -- DoPermanecerOculto: el Cazador con más de 90 y su armadura
Habilidades.ArmadurasCazador = { [360] = true, [648] = true } :: { [number]: boolean }
-- DC14-10 A: un intento cada IntervaloTrabajo (el original no tiene límite para ocultarse); robar ya lo usa
Habilidades.IntervaloTrabajo = 850 -- Server.ini:134 (IntervaloPermiteTrabajar)

-- Robar (Trabajo.bas:2049-2258)
Habilidades.StaRobar = 15
-- Tramos del skill: { hasta, Suerte }; éxito si RandomNumber(1, Suerte) < 3. Arriba de 90: 7, y 5 con 100.
Habilidades.TramosRobar = { { 10, 35 }, { 20, 30 }, { 30, 28 }, { 40, 24 }, { 50, 22 }, { 60, 20 }, { 70, 18 }, { 80, 15 }, { 90, 10 } }
-- Correcciones de la 15a (docs/28 §11, el autor): el Ladrón roba un objeto el 75% de las veces (el resto, oro) y desde
-- hasta 5 tiles (Chebyshev); el Cazador con la Armadura de Cazador camina oculto
Habilidades.ProbRobarObjeto = 75
Habilidades.AlcanceRoboLadron = 5
-- DC14-12 A: a un newbie no se le roba (mensaje nuestro)
Habilidades.MsgNoRobarNewbie = "No puedes robarle a un newbie."

-- ─── Talar, pescar y minar (Fase 16a, docs/31 §2; herramientas/fase16_ref.py trabajo) ───────────────────────────
-- Éxito si RandomNumber(1, Suerte) <= Dificultad, con Suerte = Int(-0,00125·s² - 0,3·s + 49) (Trabajo.bas:2624-2629)
Habilidades.DificultadOficio = 6 -- Server.ini:102-104
-- DR16-08 (el autor): ×10 por éxito; el Trabajador, RandomNumber(1, MaxItemsExtraibles(nivel)) × 10
Habilidades.OficioMulti = 10
-- P8 (docs/36 §9; Protocol.bas:3644-3660): los árboles élficos (ObjType 36) se talan solo con el Hacha de madera
-- Élfica y dan Madera Élfica; esa hacha no sirve para los árboles comunes
Habilidades.HachaElfica, Habilidades.MaderaElfica = 1005, 1006
Habilidades.MsgHachaComun = "El hacha utilizado no es suficientemente poderosa."
Habilidades.MsgHachaElfica = "No puedes extraer lena de este arbol con este hacha."
Habilidades.DistanciaOficio = 2 -- Manhattan (la caña: cualquier agua a la vista, DR16-11 A)
-- Fase 20 (docs/39 §5; DoPescarRed, Trabajo.bas:1945-2041; Protocol.bas:3513-3540): la Red de Pesca solo sirve sobre un
-- "Pez saltando" (el único objeto de tipo 38, otYacimientoPez), a 2 tiles o menos y no desde su mismo tile; saca uno de
-- los cinco peces de ListaPeces al azar (Declares.bas:568-580)
Habilidades.Red, Habilidades.PezSaltando = 543, 1130
Habilidades.PecesRed = { 139, 544, 545, 546, 775 } -- Pescado, Trucha, Pez Espada, Merluza, Hipocampo
Habilidades.MsgRed = {
	sinPeces = "No hay un yacimiento de peces donde pescar.",
	lejos = "Estas demasiado lejos para pescar.",
	propio = "No puedes pescar desde alli.",
	exito = "Has pescado algunos peces!",
} :: { [string]: string }
-- Por oficio (el skill es la clave de Config.Skills): las herramientas que sirven, la energía (Trabajador, resto,
-- Declares.bas:374-384), el objeto que sale, el sonido y los mensajes (Trabajo.bas). marca: la de consolaUnaVez para
-- no repetir el fallo (2, 4 y 7 ya se usan)
Habilidades.Oficios = {
	Talar = {
		herramientas = { [127] = true, [561] = true, [1005] = true }, -- la 1005, el Hacha de madera Élfica (P8)
		sta = { 2, 4 },
		obtiene = 58,
		sonido = 13,
		marca = 8,
		exito = "Has conseguido algo de lena!",
		fallo = "No has obtenido lena!",
	},
	Pesca = {
		herramientas = { [138] = true, [563] = true, [543] = true }, -- la 543, la Red de Pesca (Fase 20)
		sta = { 1, 3 },
		obtiene = 139,
		sonido = 14,
		marca = 6,
		exito = "Has pescado un lindo pez!",
		fallo = "No has pescado nada!",
	},
	Mineria = {
		herramientas = { [187] = true, [562] = true },
		sta = { 2, 5 },
		obtiene = nil, -- el mineral del yacimiento (ObjetosPiso.mineral)
		sonido = 15,
		marca = 9,
		exito = "Has extraido algunos minerales!",
		fallo = "No has conseguido nada!",
	},
} :: { [string]: any }

return Habilidades
