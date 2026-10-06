--!strict
--[[
	Constantes de los NPCs del slice (docs/16-spec-npcs-slice.md §10). Los datos de cada criatura están
	en Shared.Generado.Npcs (generado de NPCs.dat por herramientas/npc_ref.py exportar).
]]

local Npcs = {}

Npcs.TickIA = 380 -- ms, TIMER_AI del frmMain.frm del servidor
Npcs.IntervaloAtaque = 3000 -- ms, modNuevoTimer.bas:52 (D-19 A)
Npcs.RangoVisionX, Npcs.RangoVisionY = 13, 11 -- RANGO_VISION_NPC (AI_NPC.bas:59-61)
Npcs.ProbPaseo = 11 -- RandomNumber(0, 10) = 0 (AI_NPC.bas:480)
Npcs.IntervaloPuedeSerAtacado = 5000 -- ms, Server.ini:113 (D-38 A, DF8-08 A)
Npcs.ProbVeneno = 30 -- RandomNumber(1, 100) < 30 (MODULO_NPCs.bas:941): 29 %
Npcs.IntervaloParalizado = 500 -- ticks de IA (+1), General.bas:1122-1141 (DF8-02 A: 190 s)
Npcs.MaxIntentosSpawn = 60 -- MAXSPAWNATTEMPS (se compara con >: 61 intentos)
Npcs.RangoSpawnLibreX, Npcs.RangoSpawnLibreY = 11, 9 -- HayPCarea (TCP.bas:963-964)
Npcs.Oro = 12 -- iORO
-- DF12-06 (cambiado el 2026-09-30 a pedido, como en otros servidores de AO): oro ×5 y experiencia ×10. Producción del
-- original: ×3 y ×5. Hasta la Fase 11: ×1 (D-06 C). Solo afecta a las criaturas; los skills (+50) y el PvP
-- (nivel × 2) no tienen multiplicador, como en el original.
Npcs.OroMulti = 5
-- La chance de cada uno de los 5 drops (NPC_TIRAR_ITEMS, Modulo_InventANDobj.bas:73-160; npc_ref.prob_drops): el
-- mapa del mundo la muestra (docs/35 §5)
Npcs.ProbDrop = { 0.8, 0.09, 0.009, 0.0009, 0.0001 }
-- Fase 25 (docs/44 §2, pedido del autor; fase25_ref.oro_piso): el piso de oro. Las criaturas flojas casi no daban oro
-- (una Rata, 10 con suerte; una Serpiente, nada). Toda criatura hostil que da experiencia deja al menos este oro: si
-- en la tirada de siempre le tocó oro, el mayor entre ese y el piso; si no le tocó oro, el piso con PisoProb %.
-- { vida menor que (nil = el resto), oro }
Npcs.OroPiso = { { 50, 100 }, { 150, 150 }, { nil :: number?, 200 } } :: { { any } }
Npcs.PisoProb = 80
-- d: la ficha de la criatura (Generado/Npcs). 0 = no le toca (no es hostil, no da experiencia o es un pretoriano)
function Npcs.oroPiso(d: any): number
	if not d or not d.hostil or (d.exp or 0) <= 0 or d.inventario then
		return 0
	end
	for _, f in Npcs.OroPiso do
		if f[1] == nil or d.hp < f[1] then
			return f[2]
		end
	end
	return 0
end
-- El oro que deja. drop: lo que salió en la tirada de siempre ({ objeto, cantidad }) o nil; tirada: de 1 a 100.
function Npcs.oroAlMorir(drop: { number }?, piso: number, tirada: number): number
	if drop and drop[1] == Npcs.Oro and drop[2] > 0 then
		return math.max(drop[2] * Npcs.OroMulti, piso)
	end
	if piso > 0 and tirada <= Npcs.PisoProb then
		return piso
	end
	return 0
end
-- El oro promedio por criatura, con el piso (el mapa del mundo lo muestra)
function Npcs.oroPromedio(d: any): number
	local piso = Npcs.oroPiso(d)
	local total, resto = 0, 1
	for k, p in Npcs.ProbDrop do
		local dr = d.drops and d.drops[k]
		resto -= p
		if dr and dr[1] == Npcs.Oro and dr[2] > 0 then
			total += p * math.max(dr[2] * Npcs.OroMulti, piso)
		else
			total += p * piso * Npcs.PisoProb / 100
		end
	end
	return total + resto * piso * Npcs.PisoProb / 100
end
-- Fase 25 (docs/44 §3, pedido del autor; fase25_ref.DROP_EXTRA): además del drop de siempre, con su propia tirada.
-- [criatura] = { objeto, cantidad, % de chance }. Serpientes: 10 pociones rojas; goblins: 10 azules.
Npcs.DropExtra = {
	[504] = { 38, 10, 50 }, [565] = { 38, 10, 50 },
	[505] = { 37, 10, 50 }, [516] = { 37, 10, 50 }, [626] = { 37, 10, 50 },
} :: { [number]: { number } }
Npcs.MsgMatar = "Has matado a la criatura!" -- (el tutorial lo reconoce para dar por cumplido "matá una criatura")
Npcs.ExpMulti = 7 -- Fase 25 (docs/44 §1, pedido del autor): bajó de 10 a 7
-- Fase 21 (docs/40 §1): personajes de Ullathorpe.
-- Sir Gerard [Mercader] (960; hasta la Fase 27, Gerardo) va en el lugar del Mercader (80) del mapa 1; los de las otras ciudades siguen igual.
-- [mapa] = { [el NPC del .inf] = el que va en su lugar }
-- Fase 27 (docs/47 §5): Alain [Artesano] (962) va en el lugar del Artesano (938), también solo en Ullathorpe.
Npcs.Reemplazos = { [1] = { [80] = 960, [938] = 962 } } :: { [number]: { [number]: number } }
-- Fase 25 (docs/44 §10): personajes que agregamos al mundo, { número, mapa, x, y }. El Subastador (961) va a dos
-- pasos del banquero de afuera de Ullathorpe, que está en (65, 46).
-- Fase 27 (docs/47 §3): el Archimago de Gotland (963), que vende los pergaminos de los hechizos de clase, en la plaza
-- de Gotland (mapa 296), junto a la fuente.
-- Fase 33 (docs/53 §7; pedido del autor): Falcon [Gato] (964), su gato naranja, en la plaza de Ullathorpe. Está en
-- esta lista porque su hoja de dibujos (varios33_01.png) ya está subida a Roblox (Generado/Grh.atlas): sin la hoja
-- caminaría por la ciudad un nombre sin dibujo. Lo vigila fase33_prueba.luau.
-- Fase 39 (docs/59 §5; pedido del autor): el Pirata de los viajes en barco (965), en el muelle de cada ciudad con
-- agua. Los lugares son los de Config/Barco.Puertos (lo vigila fase39_prueba.luau).
Npcs.Agregados = {
	{ 961, 1, 67, 46 }, { 963, 296, 56, 53 }, { 964, 1, 58, 50 },
	{ 965, 34, 26, 78 }, { 965, 61, 50, 50 }, { 965, 62, 72, 33 }, { 965, 197, 57, 48 }, { 965, 151, 40, 13 }, { 965, 296, 52, 12 },
} :: { { number } }
-- El paseo (los que tienen `pasea` en su ficha: Falcon). En vez de dar pasos al azar va de un lugar a otro: elige un
-- punto al aire libre y despejado a no más de Radio casillas, camina hasta ahí buscando camino (un paso por tick de
-- IA), se queda un rato y elige otro. No entra bajo techo ni pisa salidas, y nunca se sienta donde taparía un paso.
Npcs.Paseo = {
	Radio = 22, -- hasta dónde busca el destino siguiente, en cada eje
	DescansoMin = 6, -- segundos quieto al llegar
	DescansoMax = 22,
	Intentos = 12, -- puntos que prueba por vez hasta dar con uno que sirva
	MaxPasos = 140, -- si no llegó en tantos ticks, elige otro destino
	Nodos = 2500, -- casillas que mira al buscar el camino (cruza media ciudad)
	Margen = 10, -- no se acerca a menos de tantas casillas del borde del mapa
	TapadoMax = 3, -- con el paso tapado tantos ticks seguidos, elige otro destino (no se queda esperando)
}
-- Fase 34 (docs/54 §8; pedido del autor): Falcon juega con lo que encuentra tirado. Si ve un objeto del piso cerca
-- va hasta ahí, se lo lleva unos segundos corriendo, da unas vueltas y lo deja atrás, en una casilla por la que acaba
-- de pasar (al aire libre: nunca queda adentro de una casa ni se pierde). El oro no le interesa.
Npcs.Juguete = {
	Ve = 5, -- a cuántas casillas ve un objeto, en cada eje
	JugarMin = 6, -- segundos que se lo lleva
	JugarMax = 10,
	Giros = 4, -- vueltas sobre sí mismo antes de soltarlo (una por tick)
	PausaMin = 30, -- después de soltarlo, cuánto pasa hasta que le vuelve a interesar algo
	PausaMax = 60,
	NoSeg = 90, -- al que acaba de soltar, o al que no pudo llegar, no vuelve por este rato
	Rastro = 4, -- cuántas de sus últimas casillas recuerda (lo deja en la más lejana que esté libre)
	Reintento = 3, -- si no encontró dónde dejarlo, camina estos segundos más y prueba de nuevo
}
-- Lo que dice (sobre su cabeza, para los que lo tienen en pantalla); %s: el objeto
Npcs.JugueteAgarra = {
	"Miau! *se lleva %s*",
	"Mrrrau! *agarra %s y sale corriendo*",
	"*atrapa %s con los dientes* Mrr!",
	"*le salta encima a %s* Miaaau!",
}
Npcs.JugueteSuelta = {
	"*suelta %s y se hace el distraido*",
	"*le da un zarpazo a %s y lo deja ahi* Miau.",
	"*deja %s, bosteza y se lame una pata*",
	"Prrr... *%s ya no le interesa*",
	"*empuja %s con la pata, lo mira caer y se va*",
}
-- ¿Le sirve de juguete? o: la ficha del objeto (Generado/ObjetosInventario). Lo mismo que puede levantar un jugador:
-- ni lo fijo (árboles, carteles, puertas) ni lo personal. El oro no tiene ficha: no lo agarra.
function Npcs.jugueteSirve(o: any): boolean
	return o ~= nil and o.agarrable ~= false and not o.personal
end
function Npcs.jugueteNombre(o: any, cantidad: number): string
	local nombre = if o and o.nombre then o.nombre else "algo"
	return if cantidad > 1 then `{cantidad} {nombre}` else nombre
end
-- Dónde lo deja: la casilla más lejana de su rastro que sirva y, si ninguna, donde está parado. rastro: sus últimas
-- casillas, de la más nueva a la más vieja; sirve(x, y): se puede dejar ahí. Devuelve x, y o nil (se lo queda un rato más).
function Npcs.jugueteDonde(rastro: { { number } }, x: number, y: number, sirve: (number, number) -> boolean): (number?, number?)
	for i = #rastro, 1, -1 do
		local p = rastro[i]
		if not (p[1] == x and p[2] == y) and sirve(p[1], p[2]) then
			return p[1], p[2]
		end
	end
	if sirve(x, y) then
		return x, y
	end
	return nil, nil
end

function Npcs.reemplazo(mapa: number, numero: number): number
	local r = Npcs.Reemplazos[mapa]
	return if r and r[numero] then r[numero] else numero
end
-- El pregonero (Claudius; hasta la Fase 27, Claudio) habla solo: cada 60 a 90 s dice una frase al azar a los que lo tienen en pantalla. Después
-- de contestar un click espera 10 s, para no pisar esa frase.
Npcs.PregonMinSeg, Npcs.PregonMaxSeg = 60, 90
Npcs.PregonEsperaClickSeg = 10 -- al que le acaba de contestar un click no le pisa la frase
Npcs.PregonSinOyentesSeg = 5 -- sin nadie para oírlo, vuelve a mirar en un rato
Npcs.PregonAlcanceX, Npcs.PregonAlcanceY = 12, 10
-- Fase 25 (docs/44 §6, pedido del autor; fase25_ref.claudio_toca): una vez por hora, con un jugador vivo a
-- CaidaAlcance casilleros o menos, al pregonero se le cae algo al piso (una broma): una moneda de oro o el Parche de
-- Pirata, y dice la frase que le toca. Si no hay nadie cerca, espera a que alguien se acerque.
Npcs.CaidaCadaSeg = 3600
Npcs.CaidaAlcance = 5
Npcs.Parche = 20060 -- "Parche de Pirata" (Generado/ObjetosInventario): un objeto sin valor
-- { objeto, cantidad, frase }
Npcs.Caidas = {
	{ 12, 1, "Que, mi oro no vale? Levantalo, que es tuyo." },
	{ 12, 1, "Uy, se me cayo una moneda. No la vayas a gastar toda junta." },
	{ 20060, 1, "No has visto mi parche? Estaba seguro de que lo tenia puesto." },
	{ 20060, 1, "Otra vez se me cayo el parche! Quedatelo, tengo mas." },
} :: { { any } }
-- distancias: { { dx, dy } } de los jugadores vivos de su mapa
function Npcs.caidaToca(ahora: number, proxima: number, distancias: { { number } }): boolean
	if ahora < proxima then
		return false
	end
	for _, d in distancias do
		if math.abs(d[1]) <= Npcs.CaidaAlcance and math.abs(d[2]) <= Npcs.CaidaAlcance then
			return true
		end
	end
	return false
end
-- TipoAI (AI_NPC.bas:33-49). Fase 16c (docs/33 §2): 8 sigue al amo y 9 ataca a otra criatura
Npcs.Movement = { Estatico = 1, AlAzar = 2, MaloAtacaBuenos = 3, Defensa = 4, SigueAmo = 8, NpcAtacaNpc = 9 }
-- Fase 17a (docs/35 §3.2): 5 persigue criminales (los guardias); 10 (pathfinding, el Enano de las Profundidades) y
-- 20-24 (la IA propia de los pretorianos) se portan como 3
Npcs.Movement.GuardiasPersiguen = 5
Npcs.ComoMaloAtacaBuenos = { [10] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true } :: { [number]: boolean }
-- eNPCType (Declares.bas:480-495)
Npcs.TipoGuardiaReal, Npcs.TipoGuardiaCaos = 2, 8
Npcs.TipoDragon = 6 -- eNPCType.DRAGON: el Gran Dragón Rojo; no tiene dueño nunca (Fase 19, docs/38 §4.1)
-- Fase 21 (docs/40 §3, D21-07 A y D21-11 A): los "dragones grandes". La Espada Mata Dragones los mata de un golpe y
-- no tienen dueño. Son los tres de tipo dragón del original (Gran Dragón Rojo 542, Negro 935 y Dorado 936) y los dos
-- legendarios, que en el .dat son de tipo 0 (Ryu 798 y Smaug 799).
Npcs.DragonesGrandes = { [542] = true, [935] = true, [936] = true, [798] = true, [799] = true } :: { [number]: boolean }
-- Fase 33 (docs/53 §2, D33-01; pedido del autor): la Espada Mata Dragones mata de un golpe SOLO al Gran Dragón Rojo.
-- Contra los demás dragones grandes pega como contra cualquier otra criatura (el arma vale 1). Lo demás de los
-- dragones grandes (no tienen dueño, no se paralizan) no cambia.
Npcs.DragonesMataDragones = { [542] = true } :: { [number]: boolean }
Npcs.TipoNoble = 5 -- eNPCType.Noble: el Rey (72) y el Demonio (98) (P8, docs/36)
-- (hasta el P8 los guardias no se podían atacar; las reglas de hoy, en docs/36 §6.2 y NpcService.puedeAtacarNpc)
Npcs.TipoRevividor = 1 -- eNPCType.Revividor (Declares.bas:480-495): el sacerdote
Npcs.TipoEntrenador = 3 -- eNPCType.Entrenador: O'Riley de Banderbill (Fase 20, docs/39 §4)
Npcs.TipoBanquero = 4 -- eNPCType.Banquero (Fase 29: los bots van al banco)

-- ─── La criatura inmovilizada (Fase 24, docs/43 §16; fase24_ref.en_la_linea) ───────────────────────────────────────
-- AI_NPC.bas:362-388: inmovilizada, le lanza solo al que está en la línea recta hacia donde mira (Sgn(dx) = SignoEO y
-- Sgn(dy) = SignoNS: mirando al norte SignoEO es 0, o sea la misma columna). Hasta la Fase 23 el port tomaba ese 0
-- como "da igual" y le lanzaba a cualquiera que estuviera de ese lado de la pantalla.
local DELTA = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- norte, este, sur, oeste (Grilla.DELTA)
function Npcs.enLaLinea(heading: number, nx: number, ny: number, ux: number, uy: number): boolean
	local d = DELTA[heading]
	return d ~= nil and math.sign(ux - nx) == d[1] and math.sign(uy - ny) == d[2]
end

return Npcs
