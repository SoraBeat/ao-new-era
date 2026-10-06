--!strict
--[[
	Ciudad (Fase 13a, docs/22 §2-§4): cruce de mapas, sacerdote, hogar, puertas, carteles, antipiquete y NPCs de
	ciudad. Los textos son los del original salvo los marcados "nuestro".
]]

local Ciudad = {}

-- ─── Hogar (DF13-05 A, docs/22 §3.2) ───────────────────────────────────────────
Ciudad.Hogar = { nombre = "Ullathorpe", mapa = 1, x = 58, y = 45 } -- Dat/Ciudades.Dat; el de por defecto (docs/35 §2.3)
-- Fase 17a (docs/35 §2.3): las ciudades de Dat/Ciudades.Dat (sin el Totem, que no se porta, ni la prisión)
Ciudad.Ciudades = {
	{ nombre = "Ullathorpe", mapa = 1, x = 58, y = 45 },
	{ nombre = "Nix", mapa = 34, x = 44, y = 88 },
	{ nombre = "Banderbill", mapa = 59, x = 50, y = 50 },
	{ nombre = "Lindos", mapa = 62, x = 72, y = 41 },
	{ nombre = "Arghal", mapa = 196, x = 52, y = 75 },
	{ nombre = "Nemahuak", mapa = 286, x = 50, y = 65 },
	{ nombre = "Arkhein", mapa = 151, x = 40, y = 48 },
	{ nombre = "Perdida", mapa = 171, x = 37, y = 65 },
	{ nombre = "Gotland", mapa = 296, x = 50, y = 56 },
} :: { { nombre: string, mapa: number, x: number, y: number } }
-- El campo Ciudad de los gobernadores (NPCs.dat) es eCiudad (Declares.bas:192-203); Nemahuak no tiene gobernador
Ciudad.PorNumero = { "Ullathorpe", "Nix", "Banderbill", "Lindos", "Arghal", "Arkhein", "Gotland", "Perdida" }
Ciudad.TipoGobernador = 11 -- eNPCType.Gobernador
-- setHome (Modulo_UsUaRiOs.bas:3055-3075): lo dice el gobernador sobre su cabeza
Ciudad.MsgNuevoHogar = "Bienvenido a nuestra humilde comunidad, este es ahora tu nuevo hogar!!!"
Ciudad.MsgYaMiembro = "Ya eres miembro de nuestra humilde comunidad!!!"

-- La ciudad de un hogar guardado (el nombre de Ciudades.Dat); si no se conoce, la de por defecto
function Ciudad.de(nombre: string?): { nombre: string, mapa: number, x: number, y: number }
	for _, c in Ciudad.Ciudades do
		if c.nombre == nombre then
			return c
		end
	end
	return Ciudad.Hogar
end
-- El original tarda (distancia + 1) × 20 s con tope de 60 (Modulo_UsUaRiOs.bas:2979-2983). Pedido del autor
-- (2026-09-30, cambio a DF13-07): siempre 5 s, total ya está muerto.
Ciudad.SegViaje = 5
Ciudad.RadioLlegada = 5 -- FindLegalPos: radio 1 a 5
Ciudad.FxWarp = 1 -- FXWARP (Declares.bas:281)
Ciudad.MsgHogarVivo = "Debes estar muerto para utilizar este comando."
Ciudad.MsgHogarAqui = "No puedes usar este comando aqui." -- HandleHome (Protocol.bas:1586): mapa con Restringir
-- Fase 17a (docs/35 §2.2): los mapas NEWBIE (DoTileEvents, GameLogic.bas:167-190; UserLevelUp,
-- Modulo_UsUaRiOs.bas:928-938 y QuitarNewbieObj, InvUsuario.bas:189-213)
Ciudad.MsgSoloNewbies = "Mapa exclusivo para newbies."
Ciudad.MsgDejaNewbie = "Debes abandonar el Dungeon Newbie."
-- Entrar a un mapa con InviSinEfecto (WarpUserChar, Modulo_UsUaRiOs.bas:2089-2113)
Ciudad.MsgVisibleMapa = "Has vuelto a ser visible ya que no esta permitida la invisibilidad en este mapa."
-- Fase 30 (docs/50 §5): al entrar al Reino Helado, donde la magia no anda (MapasIndice: restricciones.magia)
Ciudad.MsgSinMagia = "En estas tierras la magia no funciona: ni la tuya ni la de las criaturas."
Ciudad.MsgVisibleOculto = "Has vuelto a ser visible ya que no esta permitido ocultarse en este mapa."
Ciudad.MsgYaEnHogar = "Ya te encuentras en tu hogar."
Ciudad.MsgViajeCancelado = "El viaje a tu hogar ha sido cancelado."
Ciudad.MsgLlegaste = "Has llegado a tu hogar."
Ciudad.MsgViajando = "No puedes moverte mientras estas viajando a tu hogar con el comando /HOGAR."

-- "Te encuentras a N mapas de X, este viaje durara …" (cliente Protocol.bas:1380-1414: 60 s o más, en minutos)
function Ciudad.msgViaje(distancia: number, segundos: number, destino: string): string
	local t
	if segundos >= 60 then
		if segundos % 60 == 0 then
			t = `{segundos // 60} minutos.`
		else
			t = `{segundos // 60} minutos y {segundos % 60} segundos.`
		end
	else
		t = `{segundos} segundos.`
	end
	return `Te encuentras a {distancia} mapas de {destino}, este viaje durara {t}`
end

-- ─── Sacerdote (docs/22 §3.1) ─────────────────────────────────────────────────
Ciudad.SacerdoteCaminar = 5 -- HaySacerdote: Distancia < 5 (General.bas:210)
Ciudad.SacerdoteVentanaX, Ciudad.SacerdoteVentanaY = 11, 9 -- la búsqueda recorre ±11 × ±9 (General.bas:198-230)
Ciudad.SacerdoteDobleClick = 10 -- Acciones.bas:127
Ciudad.MsgResucitado = "Has sido resucitado!!"
Ciudad.MsgCurado = "El sacerdote te ha curado!!"
Ciudad.MsgSacerdoteLejos = "El sacerdote no puede curarte debido a que estas demasiado lejos."
Ciudad.MsgCuraVeneno = "El sacerdote te ha curado del envenenamiento."
Ciudad.MsgCuraMana = "El sacerdote te ha restaurado el mana completamente."
Ciudad.MsgNewbie = "Cuando dejes de ser newbie no lo hara mas el sacerdote y deberas comprar pociones o curarte con hechizos"

-- ─── Doble click (Accion) y NPCs de ciudad ────────────────────────────────────
Ciudad.DobleClickSeg = 0.4 -- nuestro: dos clicks o toques en el mismo tile
Ciudad.MsgSinInteres = "No tengo ningun interes en comerciar." -- DF13-12 A (nuestro en el doble click)
Ciudad.MsgNoAtacable = "No puedes atacar a este NPC." -- SistemaCombate.bas:1240
Ciudad.MsgNoAtacableHechizo = "No puedes atacar esta criatura." -- PuedeAtacarNPC (SistemaCombate.bas:2059-2061)
Ciudad.ProbPasoAlAzar = 12 -- MueveAlAzar: RandomNumber(1, 12) = 3 (AI_NPC.bas:1145)

-- ─── Puertas y carteles (docs/22 §4.3 y §4.5) ─────────────────────────────────
Ciudad.DistanciaPuerta = 2 -- Distance (euclídea) > 2 (Acciones.bas:275)
Ciudad.MsgPuertaLlave = "La puerta esta cerrada con llave."
Ciudad.MsgLejos = "Estas demasiado lejos."
Ciudad.SonidoPuerta = 5 -- SND_PUERTA, al abrir y al cerrar, en la puerta (Acciones.bas:295, :314; docs/29)

-- ─── Antipiquete (DF13-10 A: sin cárcel) ─────────────────────────────────────
Ciudad.PiqueteAviso = 6 -- cada 6 s (mMainLoop.bas:451-472)
Ciudad.MsgPiquete = "Estas obstruyendo la via publica, muevete o seras encarcelado!!!"

-- ─── Zona segura de tile (trigger 4) ─────────────────────────────────────────
Ciudad.MsgZonaSeguraTile = "No puedes pelear aqui." -- SistemaCombate.bas:2002

-- ─── Salidas a mapas que no están (DF13-04 A, nuestro) ─────────────────────────
Ciudad.MsgSalidaBorde = "El camino sigue, pero todavía no está abierto."
Ciudad.MsgSalidaInterior = "Este lugar todavía no está abierto."
Ciudad.SegAvisoSalida = 10

-- ─── Arena de práctica de Ullathorpe (Fase 26, docs/46 §8; pedido del autor) ───
-- El portal de al lado de la fuente lleva al mapa 273, una arena cerrada donde todo el piso es zona de pelea: se pelea
-- sin mirar el bando y sin perder nada (ni los objetos, ni el oro, ni cuenta como muerte o como matado). Cuatro
-- portales cerca de las esquinas devuelven a la plaza (los pone herramientas/mapas.py). El que muere adentro aparece,
-- muerto, al lado del sacerdote de Ullathorpe: con dar un paso ya lo resucita.
Ciudad.Arena = {
	mapa = 273,
	sacerdote = { mapa = 1, x = 77, y = 64 }, -- delante del Sacerdote (77, 63)
	radio = 4,
	Msg = "Caíste en la arena: el sacerdote de Ullathorpe te espera. No perdiste nada.",
	MsgEntrada = "Arena de práctica: acá se pelea contra cualquiera y al morir no se pierde nada.",
}

-- ─── Nombre del mapa al entrar (cliente TileEngine.bas:1927-1956) ─────────────
Ciudad.SegNombreMapa = 4 -- el alfa baja de 239 a 0, de a 1 por frame (~4 s a 60 fps)

-- ─── Techos (DF13-08 A, cliente TileEngine.bas:1913-1925) ─────────────────────
Ciudad.TechoMin, Ciudad.TechoMax = 150, 250 -- de a 1 por frame (a 60 fps)

return Ciudad
