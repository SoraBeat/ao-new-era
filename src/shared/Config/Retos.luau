--!strict
--[[
	Retos (Fase 15c, docs/28 §4 y §14; investigación en docs/datos/fase15-investigacion/clanes-retos.md §3).

	Duelos 1v1, 2v2 y 3v3 al mejor de 3 en las 4 arenas del mapa 272 ("Arena de Clanes"), con apuesta de oro
	opcional (Retos.bas). Números: herramientas/fase15_ref.py retos.
]]

local Retos = {}

Retos.Mapa = 272
-- Dat/Retos.dat con las esquinas corregidas (DS15-26 A): en las arenas 1 a 3 un equipo caía en un tile bloqueado
-- fuera de la zona de pelea. a = equipo 1 (el que invita), b = equipo 2; zona = x0, x1, y0, y1 del trigger ZONAPELEA
Retos.Arenas = {
	{ a = { 15, 88 }, b = { 31, 72 }, zona = { 15, 34, 72, 88 } }, -- (11, 88) → (15, 88)
	{ a = { 31, 10 }, b = { 14, 26 }, zona = { 14, 33, 10, 26 } }, -- (11, 26) → (14, 26)
	{ a = { 30, 44 }, b = { 14, 57 }, zona = { 14, 31, 44, 57 } }, -- (12, 57) → (14, 57)
	{ a = { 58, 46 }, b = { 40, 59 }, zona = { 40, 58, 46, 59 } },
}

Retos.OroMax = 100000000 -- Retos.bas:461-465
-- Fase 26 (docs/46 §9, D26-21): el interruptor de las apuestas. Desde que el oro se vende por Robux, apostar oro en un
-- reto es jugarse algo que se puede comprar. Es una pelea (habilidad, no azar) y la norma de Roblox no lo nombra, así
-- que quedan; si Roblox lo objeta, con poner `false` acá los retos siguen pero sin oro en juego.
Retos.Apuestas = true
Retos.NivelApuesta = 18 -- docs/28 §4.2: con apuesta, todos desde el nivel 18 (como tirar oro, DA-13)
Retos.Cuenta = 10 -- Counters.TimeFight (Retos.bas:771)
Retos.RondasParaGanar = 2 -- mejor de 3 (Retos.bas:931)
Retos.VenceInvitacion = 60 -- DS15-26 A (el original no vence)
-- Fase 20 (docs/39 §6, D20-31 A y D20-32 A): cada ronda dura como mucho 5 minutos (el original no tiene límite)
Retos.RondaSeg = 300
Retos.RondaAvisos = { [60] = "Queda 1 minuto de round.", [10] = "Quedan 10 segundos de round." } :: { [number]: string }

Retos.Msg = {
	-- Validaciones (ValidateFight, Retos.bas:375-488)
	OroRango = "Oro Minimo: 0 . Oro Maximo 100.000.000",
	Offline = "El personaje %s esta offline",
	Muerto = "El personaje %s esta muerto.",
	EnEvento = "El personaje %s esta participando en otro evento.",
	NoDisponible = "El personaje %s no esta disponible en este momento.",
	SinOro = "El personaje %s no tiene las monedas en su billetera.",
	-- Nuestros (docs/28 §4.2)
	NoSegura = "El personaje %s tiene que estar en una ciudad o en una zona segura (y sin haber peleado recien).",
	Newbie = "El personaje %s es newbie: los newbies no participan de retos.",
	NivelApuesta = "Para apostar oro todos tienen que ser nivel 18 o mas (%s no lo es).",
	ApuestaNoPermitida = "No se puede apostar oro: la cuenta de %s no tiene permitido pasarle oro a otro jugador (una regla de Roblox).",
	ApuestaSinSaber = "No se pudo comprobar con Roblox si la cuenta de %s puede apostar oro. Proba de nuevo en un momento.",
	SinApuestas = "Los retos con apuesta estan desactivados: se pelea sin oro en juego.",
	TopeOro = "Con el premio, %s pasaria el maximo de oro que se puede llevar.",
	Navegando = "El personaje %s esta navegando: tiene que bajar del barco.", -- DT16-09 A (docs/34 §5)
	Prueba = "Los personajes de prueba solo pueden retar a otros personajes de prueba.",
	Cantidad = "Elegi a todos los participantes (sin repetir).",
	SinArena = "No hay arenas libres en este momento. Proba de nuevo en un rato.",
	Vencio = "El reto vencio: no aceptaron a tiempo.",
	Esperando = "Espera noticias para concretar el reto que has enviado. Recuerda que si vuelves a mandar, la anterior solicitud se cancela.",
	Aceptaste = "Has aceptado la invitacion.",
	-- En la arena
	CuentaEspera = "Espera que termine la cuenta.",
	AtacarReto = "No puedes atacar a alguien que esta en un reto.",
	AyudarReto = "No puedes ayudar a alguien que esta en un reto.",
	ResucitarReto = "No puedes resucitar durante un reto.",
	HogarReto = "No puedes volver a tu hogar durante un reto.",
	AccionReto = "No puedes hacer eso durante un reto.",
}

-- ─── Clan contra clan (Fase 19, docs/38 §6) ──────────────────────────────────
-- El del original no funciona (Mod_ClanvsClan.bas; clanes-retos.md §2.3): va armado sobre los retos, en estas arenas.
-- Los retos comunes empiezan por las dos chicas y el clan contra clan por las dos grandes (331 tiles pisables cada una)
Retos.OrdenArenas = { 3, 4, 1, 2 }
Retos.OrdenArenasCvc = { 1, 2, 4, 3 }
Retos.CvcMin, Retos.CvcMax = 2, 6 -- por lado (DC19-16 A)
Retos.CvcAceptarSeg = 60 -- lo que tiene el otro líder para contestar
Retos.CvcAnotarseSeg = 60 -- lo que tienen los miembros para anotarse
Retos.CvcEnfriamientoSeg = 300 -- después de un rechazo o de un desafío vencido, contra el mismo clan
-- Fase 20 (docs/39 §7): entre servidores, la pelea es en una sala (un servidor reservado para esa pelea)
Retos.CvcLlegarSeg = 120 -- lo que tienen los miembros para viajar a la sala (D20-34 A)
Retos.CvcGraciaSeg = 30 -- lo que la sala espera de más a los que ya están viajando (el viaje, la carga y el perfil)
Retos.CvcVolverSeg = 20 -- al terminar, lo que tarda la sala en devolver a todos al juego normal
Retos.CvcViajeCadaSeg = 8 -- entre un pedido de viaje y el siguiente, por jugador

-- Cuántos juegan por lado con `a` y `b` anotados: el mínimo de los dos, hasta el tope. 0 = no llegan al mínimo.
-- minimo: el del desafío (el panel de Admin lo puede bajar para probar); si no se pasa, CvcMin.
function Retos.equiposCvc(a: number, b: number, minimo: number?): number
	local n = math.min(a, b, Retos.CvcMax)
	return if n < (minimo or Retos.CvcMin) then 0 else n
end

Retos.MsgTiempo = {
	Gana = "Se acabo el tiempo: gana el round %s.",
	Repite = "Se acabo el tiempo y nadie saco ventaja: el round se juega de nuevo.",
	SinGanador = "Dos rounds seguidos sin ventaja: el reto termina sin ganador y cada uno recupera lo apostado.",
	Anuncio = "Retos: %s vs %s. Sin ganador.",
	AnuncioCvc = "El clan contra clan entre %s y %s termino sin ganador.",
} :: { [string]: string }

-- Quién gana una ronda que se termina por tiempo (herramientas/fase20_ref.py ganador_por_tiempo): el equipo con más
-- vivos; a igual cantidad, el que conserva más vida (por cada vivo, su vida en milésimas de su máximo, con enteros).
-- 0 = empate.
export type Peleador = { vivo: boolean, hp: number, maxHp: number }
function Retos.ganadorPorTiempo(equipos: { { Peleador } }): number
	local function cuenta(eq: { Peleador }): (number, number)
		local vivos, vida = 0, 0
		for _, p in eq do
			if p.vivo then
				vivos += 1
				if p.maxHp > 0 then
					vida += (p.hp * 1000) // p.maxHp
				end
			end
		end
		return vivos, vida
	end
	local v1, h1 = cuenta(equipos[1])
	local v2, h2 = cuenta(equipos[2])
	if v1 ~= v2 then
		return if v1 > v2 then 1 else 2
	end
	if h1 ~= h2 then
		return if h1 > h2 then 1 else 2
	end
	return 0
end

-- Qué pasa cuando se termina el tiempo (fase20_ref.py fin_por_tiempo): "ronda" (suma una ronda al ganador), "fin"
-- (con esa ronda gana el reto), "repetir" (empate: la ronda no cuenta) o "empate" (dos empates seguidos: sin ganador)
function Retos.finPorTiempo(rondas: { number }, empatesSeguidos: number, ganador: number): string
	if ganador == 0 then
		return if empatesSeguidos >= 1 then "empate" else "repetir"
	end
	return if rondas[ganador] + 1 >= Retos.RondasParaGanar then "fin" else "ronda"
end

Retos.MsgCvc = {
	-- Del original (Mod_ClanvsClan.bas), adaptados: ahí se aceptaba haciéndole click al otro líder
	Desafio = "El clan %s desafia tu clan a un duelo de modalidad Clan vs Clan, si aceptas tipea /ACVC.",
	Espera = "Ahora debes esperar que el lider acepte.",
	Empieza = "CLAN VS CLAN > %s vs %s, hasta %d participantes por clan. Para participar tipea /IRCVC.",
	Ingreso = "%s ingreso al cvc para el clan %s!",
	Lleno = "El clan llego al limite de usuarios en este clan vs clan.",
	SinCvc = "Tu clan no esta en ningun CVC.",
	YaEsta = "Estas en el cvc!",
	SinClan = "No perteneces a ningun clan.!",
	NoLider = "No eres el lider de ningun clan.",
	NoSolicito = "Nadie le solicito un Clan vs Clan a tu clan.",
	Vencio = "%s vencio a %s en un duelo %d vs %d.",
	-- Nuestros
	Uso = "Escribi /CVC y el nombre del clan al que queres desafiar.",
	NoExiste = "No existe ningun clan con ese nombre.",
	Propio = "No puedes desafiar a tu propio clan.",
	Prueba = "Un clan de prueba solo puede desafiar a otro clan de prueba.",
	LiderAusente = "El lider del clan %s no esta conectado en este servidor.",
	Pocos = "Tiene que haber por lo menos %d miembros de cada clan conectados en este servidor.",
	Ocupado = "El clan %s ya tiene un clan contra clan en curso o pendiente.",
	Enfriamiento = "Ya desafiaste a ese clan hace poco: espera %d minutos.",
	Rechazo = "El clan %s rechazo el clan contra clan.",
	Rechazaste = "Has rechazado el clan contra clan.",
	VencioDesafio = "El desafio de clan contra clan vencio: no lo contestaron a tiempo.",
	LiderSeFue = "Un lider se desconecto: el clan contra clan se cancela.",
	Faltan = "No se anotaron suficientes participantes (hacen falta %d por clan): el clan contra clan se cancela.",
	Afuera = "Quedaste afuera: se juega %d contra %d y entraron los primeros en anotarse.",
	YaNoPuede = "%s ya no puede participar y queda afuera.",
	SinArena = "No hay arenas libres en este momento: el clan contra clan se cancela.",
	YaAnotado = "Ya estas anotado.",
	Tarde = "El clan contra clan ya empezo.",
	Gano = "Tu clan ha ganado el clan contra clan.",
	Perdio = "Tu clan ha perdido el clan contra clan.",
	Invita = "Tu clan pelea contra %s. Queres participar?",
	-- Fase 20 (docs/39 §7): entre servidores
	PocosTotal = "Tiene que haber por lo menos %d miembros de cada clan conectados.",
	LiderOffline = "El lider del clan %s no esta conectado.",
	SinSala = "No se pudo armar la sala del clan contra clan. Proba de nuevo en un rato.",
	Acepto = "El clan %s acepto el clan contra clan.",
	SalaLista = "CLAN VS CLAN > %s vs %s, en una sala aparte, hasta %d participantes por clan. Tenes %d segundos para ir: tipea /IRCVC.",
	InvitaViaje = "Tu clan pelea contra %s en una sala aparte. Queres ir?",
	Viajando = "Yendo a la sala del clan contra clan...",
	ViajeFallo = "No se pudo viajar. Seguis aca con tu personaje: proba de nuevo con /IRCVC.",
	ViajeEspera = "Ya pediste viajar: espera unos segundos.",
	EnOtro = "Tu clan tiene un clan contra clan en otro servidor.",
	EnSala = "Desde la sala no se puede desafiar a otro clan.",
	Llegaste = "Llegaste a la sala del clan contra clan %s vs %s. Empieza en %d segundos.",
	NoEsTuSala = "Esta sala es de un clan contra clan que no es de tu clan.",
	SalaCerrada = "El clan contra clan de esta sala ya termino.",
	Vuelta = "En %d segundos volves al juego.",
	Volviendo = "Volviendo al juego...",
	SalaSinRetos = "En la sala de un clan contra clan no se arman retos.",
	Espera1 = "Espera un momento.",
}

return Retos
