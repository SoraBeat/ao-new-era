--!strict
--[[
	Domar, mascotas e invocaciones (Fase 16c, docs/33-spec-mascotas.md). Referencia: herramientas/fase16c_ref.py
	(los casos de las funciones puras están en docs/muestras/fase16c_vectores.json).
]]

local Mascotas = {}

Mascotas.Max = 3 -- MAXMASCOTAS (Declares.bas:544): domadas e invocadas juntas
-- Fase 33 (docs/53 §4, D33-05 y D33-06; pedido del autor): cuántas DOMADAS puede tener cada clase. El Druida, las
-- tres; las demás, una. Las invocadas no entran en esta cuenta: entre domadas e invocadas siguen siendo Max.
Mascotas.MaxDomadas = 1
Mascotas.MaxDomadasDruida = 3
Mascotas.MaxDomadasClase = { Druida = Mascotas.MaxDomadasDruida } :: { [string]: number }
function Mascotas.maxDomadas(clase: string?): number
	return (clase and Mascotas.MaxDomadasClase[clase]) or Mascotas.MaxDomadas
end
-- Fase 26 (docs/46 §5, pedido del autor): sin tope por tipo, las tres pueden ser iguales. El original no dejaba más
-- de 2 del mismo tipo (PuedeDomarMascota, Trabajo.bas:1636-1660): con 3 la regla nunca llega a aplicarse.
Mascotas.MaxMismoTipo = 3
Mascotas.DistDomar = 2 -- Manhattan (Protocol.bas:3727-3731); DM16-05 A: a la criatura, no al tile clickeado
Mascotas.IntervaloDomar = 850 -- ms (DM16-02 A: el intervalo de trabajar; el original no tiene)
Mascotas.DistOrden = 10 -- /QUIETO, /ACOMPANAR, /LIBERAR (Protocol.bas:6276-6417)
Mascotas.DistSeguir = 3 -- SeguirAmo: un paso si el amo está a más de 3 (AI_NPC.bas:844-884)
Mascotas.ProbPasoAlAzar = 12 -- Case SigueAmo: RandomNumber(1, 12) = 3 (AI_NPC.bas:1164-1172)
-- Fase 28 (docs/48 §4, pedido del autor): cada cuánto da un paso la mascota que sigue al amo. Antes, un paso por tick
-- de IA (Npcs.TickIA, 380 ms: 2,6 casillas por segundo) y se quedaban atrás; el amo camina a 222 ms por casilla
-- (Movimiento.MS_POR_PASO) y montado a 167. Con 240 van casi a su lado a pie. Perseguir y pegar no cambian.
Mascotas.PasoSeguirMs = 240
Mascotas.DuracionInvocacion = 1001 * 40 -- ms: IntervaloInvocacion (Server.ini:137) en ticks de 40 ms, ~40 s
Mascotas.BonoManaDruida = 0.7 -- invocaciones del Druida con Flauta Élfica (modHechizos.bas:561-563, :804-813)
Mascotas.Radio = 3 -- WarpMascotas: aparecen a ±3 del amo (Modulo_UsUaRiOs.bas:2289-2313)
-- Fase 28 (docs/48 §4.1): el lugar donde aparece. Se prueban IntentosLugar lugares al azar a ±Radio; si ninguno sirve
-- (libre y que no sea una salida del mapa), el que sirva más cercano al amo, hasta RadioLugar casillas
Mascotas.IntentosLugar = 10
Mascotas.RadioLugar = 12
Mascotas.EnvioMs = 1000 -- cada cuánto se le manda al dueño la vida y el tiempo de sus mascotas (ventana)

-- DM16-13 A (docs/33 §1.2, pedido del autor): el skill de Domar y el nivel que pide cada criatura (por número de
-- NPCs.dat); con los dos, se doma siempre. Lobo, Goblin y Gorila Salvaje con valores nuestros (DM16-14 A). Las que no
-- están en los mapas portados quedan para cuando lleguen. Referencia: herramientas/fase16c_ref.py DOMAR.
Mascotas.Domables = {
	[76] = { 10, 0 }, [535] = { 10, 0 }, -- Hormiga, Hormiga Marabunta
	[77] = { 10, 0 }, [536] = { 10, 0 }, -- Rata, Rata Salvaje
	[500] = { 10, 0 }, -- Murciélago
	[504] = { 10, 0 }, [565] = { 10, 0 }, -- Serpiente (las dos)
	[2] = { 10, 0 }, [506] = { 10, 0 }, -- Gallo, Gallo Salvaje
	[501] = { 10, 0 }, -- Lobo
	[505] = { 30, 12 }, -- Goblin
	[539] = { 45, 18 }, [507] = { 45, 18 }, -- Tortuga Gigante, Lord Zombie
	[510] = { 55, 21 }, [538] = { 55, 21 }, [515] = { 55, 21 }, -- Araña (Arácnido) Gigante, Oso Pardo, Gorila Salvaje
	[555] = { 63, 25 }, [537] = { 63, 25 }, [549] = { 63, 25 }, -- Lord Orco, Beholder, Orco Brujo
	[541] = { 65, 25 }, -- Ogro
	[554] = { 80, 32 }, [550] = { 80, 32 }, [531] = { 80, 32 }, -- Liche, Bruja, Asesino
} :: { [number]: { number } }

-- Las flautas del Druida (anillo) bajan el skill pedido (DM16-16 A; el original bajaba el Domable: Trabajo.bas:1555-1568)
Mascotas.Flautas = { [1050] = 0.8, [208] = 0.89 } :: { [number]: number }

-- Los elementales (AI_NPC.bas, SistemaCombate.bas:811): Fuego y Tierra no defienden de criaturas (CheckPets); el de
-- Agua no le pega a jugadores; el de Fuego lanza su hechizo también a las criaturas
Mascotas.ElementalFuego, Mascotas.ElementalAgua, Mascotas.ElementalTierra = 93, 92, 94

Mascotas.Msg = {
	-- Domar (Protocol.bas:3716-3748, Trabajo.bas:1512-1628)
	NoHay = "No hay ninguna criatura alli!",
	NoDomable = "No puedes domar a esa criatura.",
	Lejos = "Estas demasiado lejos.",
	Golpeada = "No puedes domar una criatura que fue atacada por un jugador.", -- nuestro (DM16-15 A)
	YaDomada = "Ya domaste a esa criatura.",
	Maximo = "No puedes controlar mas criaturas.",
	MaximoDomadas = "Tu clase solo puede tener una criatura domada (el Druida, tres). El intento igual te sirve de practica.", -- Fase 33
	TieneAmo = "La criatura ya tiene amo.",
	MismoTipo = "No puedes domar mas criaturas del mismo tipo.", -- (con MaxMismoTipo = Max ya no se llega)
	FaltaSkill = "Necesitas %d de skill en Domar para domar esta criatura.", -- nuestro (DM16-13 A)
	FaltaNivel = "Necesitas ser nivel %d para domar esta criatura.", -- nuestro
	Exito = "La criatura te ha aceptado como su amo.",
	Afuera = "No se permiten mascotas en zona segura. estas te esperaran afuera.",
	EsperanBarco = "Tus mascotas no te siguen por el agua: apareceran a tu lado cuando desembarques.", -- nuestro (docs/34 §2)
	-- Mapas (WarpMascotas)
	Invocadas = "Pierdes el control de tus mascotas invocadas.",
	NoTransitan = "Tus mascotas no pueden transitar este mapa.",
	-- Órdenes (Protocol.bas:6276-6417)
	Seleccionar = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el.",
	SeleccionarMascota = "Primero tienes que seleccionar una mascota, haz click izquierdo sobre ella.",
	-- Invocaciones (modHechizos.bas:573-585, :663-768; Modulo_UsUaRiOs.bas:2333-2393)
	ZonaSegura = "No puedes invocar criaturas en zona segura.",
	EnReto = "No puedes invocar criaturas durante un reto.", -- nuestro (DM16-12 A)
	AfueraArena = "No se permiten mascotas en la arena de practica. Te esperaran afuera.", -- Fase 26 (docs/46 §8)
	EnArena = "En la arena de practica no se puede invocar: las mascotas esperan afuera.", -- Fase 26 (docs/46 §8)
	ManaLlena = "Debes poseer toda tu mana para poder lanzar este hechizo.",
	SinMascota = "Debes poseer alguna mascota para poder lanzar este hechizo.",
	NoTransitaSector = "Tu mascota no pueden transitar este sector del mapa, intenta invocarla en otra parte.",
	-- Peleas
	AtacanTuMascota = "%s esta atacando tu mascota!!", -- Modulo_UsUaRiOs.bas:1389-1407
	NoAtacaJugador = "La mascota no atacara a ese jugador.", -- nuestro (DM16-07 A, en lugar del de la Armada)
	TuMascota = "No puedes atacar a tu mascota.", -- nuestro (DM16-05 A, bug 1)
	SoloAmo = "Solo puedes remover la paralisis de los NPCs que te consideren su amo.", -- modHechizos.bas:1762
	-- Cursor (nuestro: el original no avisa)
	Cursor = "Haz click sobre la criatura...",
}

-- ─── Funciones puras (fase16c_ref.py) ────────────────────────────────────────
-- Redondeo de VB6 al guardar un Double en un Integer: bancario (378,25 → 378; 400,5 → 400; 401,5 → 402)
local function vbRound(x: number): number
	local f = math.floor(x)
	local d = x - f
	if d > 0.5 then
		return f + 1
	elseif d < 0.5 then
		return f
	end
	return if f % 2 == 0 then f else f + 1
end
Mascotas.vbRound = vbRound

-- El skill de Domar que pide la criatura, con el descuento de la flauta (nil: no se doma)
function Mascotas.skillRequerido(numero: number, anillo: number?): number?
	local r = Mascotas.Domables[numero]
	if not r then
		return nil
	end
	local f = anillo and Mascotas.Flautas[anillo]
	return if f then vbRound(r[1] * f) else r[1]
end

function Mascotas.nivelRequerido(numero: number): number?
	local r = Mascotas.Domables[numero]
	return r and r[2]
end

-- nil si alcanza (se doma siempre, DM16-13 A); si no, "Skill" o "Nivel"
function Mascotas.falta(skill: number, nivel: number, numero: number, anillo: number?): string?
	local s = Mascotas.skillRequerido(numero, anillo)
	if not s then
		return "Skill"
	end
	if skill < s then
		return "Skill"
	end
	if nivel < (Mascotas.nivelRequerido(numero) :: number) then
		return "Nivel"
	end
	return nil
end

-- Validaciones del click, en el orden del original (mascotas.md §1.2); "Golpeada" (un jugador le pegó alguna vez)
-- reemplaza a "luchando con un jugador" (DM16-15 A). Devuelve la clave del mensaje o nil.
-- Fase 33 (docs/53 §4): `domadas` y `topeDomadas` son las domadas que ya tiene y las que deja su clase (si no vienen,
-- no se mira: como antes).
function Mascotas.validar(dx: number, dy: number, domable: boolean, golpeada: boolean, yaMia: boolean, total: number, mismoTipo: number, conAmo: boolean,
	domadas: number?, topeDomadas: number?): string?
	if not domable then
		return "NoDomable"
	end
	if math.abs(dx) + math.abs(dy) > Mascotas.DistDomar then
		return "Lejos"
	end
	if golpeada then
		return "Golpeada"
	end
	if yaMia then
		return "YaDomada"
	end
	if total >= Mascotas.Max then
		return "Maximo"
	end
	if conAmo then
		return "TieneAmo"
	end
	if mismoTipo >= Mascotas.MaxMismoTipo then
		return "MismoTipo"
	end
	-- al final: es el único de estos avisos con el que el intento igual sube la habilidad (MascotaService.domar)
	if domadas and topeDomadas and domadas >= topeDomadas then
		return "MaximoDomadas"
	end
	return nil
end

-- NpcImpactoNpc (SistemaCombate.bas:936-957): % de acierto de una criatura contra otra
function Mascotas.impactoNpc(ataque: number, evasion: number): number
	return math.clamp(vbRound(50 + (ataque - evasion) * 0.4), 10, 90)
end

-- Cuántas salen de una invocación: de a una mientras haya lugar (HechizoInvocacion :719-750)
function Mascotas.invocadas(cant: number, actuales: number): number
	return math.max(0, math.min(cant, Mascotas.Max - actuales))
end

return Mascotas
