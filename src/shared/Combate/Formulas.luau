--!strict
--[[
	Formulas — combate cuerpo a cuerpo del servidor VB6 clásico, con su aritmética exacta.
	Especificación y citas: docs/14-spec-combate-slice.md §2. Vectores de prueba: §6 y
	herramientas/combate_ref.py. Funciones puras: el azar entra por parámetro.

	Aritmética de VB6 que se replica:
	- Double → Integer/Long redondea al par (bancario): vbRound.
	- ModifClase es Single: el multiplicador de daño pasa por float32: f32.
	- RandomNumber(a, b) es inclusivo en ambos extremos.
]]

local ReplicatedStorage = game and game:GetService("ReplicatedStorage")
local CFG = if ReplicatedStorage then require(ReplicatedStorage.Shared.Config.Combate) else nil :: any

local Formulas = {}

-- Permite usar el módulo fuera de Roblox (tests con el CLI de Luau)
function Formulas.usarConfig(cfg: any)
	CFG = cfg
end

-- ─── Aritmética VB6 ──────────────────────────────────────────────────────────
function Formulas.vbRound(x: number): number
	local f = math.floor(x)
	local d = x - f
	if d > 0.5 then
		return f + 1
	elseif d < 0.5 then
		return f
	end
	return if f % 2 == 0 then f else f + 1
end
local vbRound = Formulas.vbRound

function Formulas.f32(x: number): number
	return (string.unpack("<f", string.pack("<f", x)))
end

local function clampProb(x: number): number
	return math.max(CFG.ProbMin, math.min(CFG.ProbMax, vbRound(x)))
end

-- Porcentaje(Total, Porc) = CLng(Total * Porc / 100) (Matematicas.bas:32-41)
function Formulas.porcentaje(total: number, porc: number): number
	return vbRound(total * porc / 100)
end

-- ─── Tipos ───────────────────────────────────────────────────────────────────
export type Objeto = {
	minHit: number?,
	maxHit: number?,
	minDef: number?,
	maxDef: number?,
	refuerzo: number?,
	proyectil: boolean?,
	municiones: boolean?,
	guante: boolean?,
}
export type Combatiente = {
	elv: number,
	atrib: { [string]: number },
	skills: { [string]: number },
	mod: {
		Evasion: number,
		AtaqueArmas: number,
		DanoArmas: number,
		Escudo: number,
		AtaqueWrestling: number?,
		DanoWrestling: number?,
		AtaqueProyectiles: number?,
		DanoProyectiles: number?,
	},
	minHit: number,
	maxHit: number,
	-- Fase 14a (docs/27 §2 y §4): municion (flechas) y anillo (anillos, guantes, laúdes y flautas)
	-- P7 (docs/34 §1.3): barco, el que usa mientras navega (suma su golpe y resta su defensa en todo golpe físico)
	equipo: { arma: Objeto?, armadura: Objeto?, casco: Objeto?, escudo: Objeto?, municion: Objeto?, anillo: Objeto?, barco: Objeto? },
}
-- rnd(nombre, lo, hi): en el juego ignora el nombre; en los tests devuelve la tirada fijada
export type Rnd = (string, number, number) -> number

-- ─── Poderes (SistemaCombate.bas) ────────────────────────────────────────────
local function bonusNivel(elv: number): number
	return CFG.BonusNivelPorNivel * math.max(elv - CFG.NivelBaseBonus, 0)
end

-- :72-88
function Formulas.poderEvasion(p: Combatiente): number
	local tac, agi = p.skills.Tacticas, p.atrib.Agilidad
	local lTemp = vbRound((tac + tac / CFG.DivisorTacticas * agi) * p.mod.Evasion)
	return vbRound(lTemp + bonusNivel(p.elv))
end

-- :61-70
function Formulas.poderEvasionEscudo(p: Combatiente): number
	return vbRound(p.skills.Defensa * p.mod.Escudo / CFG.DivisorEscudo)
end

-- :90-116 (tramos 31 / 61 / 91)
function Formulas.poderAtaqueArma(p: Combatiente): number
	local s, agi, m = p.skills.Armas, p.atrib.Agilidad, p.mod.AtaqueArmas
	local temp
	if s < 31 then
		temp = vbRound(s * m)
	elseif s < 61 then
		temp = vbRound((s + agi) * m)
	elseif s < 91 then
		temp = vbRound((s + 2 * agi) * m)
	else
		temp = vbRound((s + 3 * agi) * m)
	end
	return vbRound(temp + bonusNivel(p.elv))
end

-- PoderAtaqueWrestling (:150-180): los mismos tramos, con la skill Wrestling y ModAtaqueWrestling
function Formulas.poderAtaqueWrestling(p: Combatiente): number
	local s, agi, m = p.skills.Wrestling or 0, p.atrib.Agilidad, p.mod.AtaqueWrestling or 0
	local temp
	if s < 31 then
		temp = vbRound(s * m)
	elseif s < 61 then
		temp = vbRound((s + agi) * m)
	elseif s < 91 then
		temp = vbRound((s + 2 * agi) * m)
	else
		temp = vbRound((s + 3 * agi) * m)
	end
	return vbRound(temp + bonusNivel(p.elv))
end

-- PoderAtaqueProyectil (:118-148, Fase 14a): los tramos de las armas con el skill Proyectiles y ModAtaqueProyectiles
function Formulas.poderAtaqueProyectil(p: Combatiente): number
	local s, agi, m = p.skills.Proyectiles or 0, p.atrib.Agilidad, p.mod.AtaqueProyectiles or 0
	local temp
	if s < 31 then
		temp = vbRound(s * m)
	elseif s < 61 then
		temp = vbRound((s + agi) * m)
	elseif s < 91 then
		temp = vbRound((s + 2 * agi) * m)
	else
		temp = vbRound((s + 3 * agi) * m)
	end
	return vbRound(temp + bonusNivel(p.elv))
end

-- Con arma, arco o los puños, según lo equipado (:199-236 contra NPCs, :1327 en PvP; DF11-06 A)
function Formulas.poderAtaque(p: Combatiente): number
	local arma = p.equipo.arma
	if arma and arma.proyectil then
		return Formulas.poderAtaqueProyectil(p)
	end
	if arma then
		return Formulas.poderAtaqueArma(p)
	end
	return Formulas.poderAtaqueWrestling(p)
end

function Formulas.evasionTotal(p: Combatiente): number
	local e = Formulas.poderEvasion(p)
	if p.equipo.escudo then
		e += Formulas.poderEvasionEscudo(p)
	end
	return e
end

-- :1333 (usuario → usuario)
function Formulas.probExito(ataque: number, evasion: number, base: number?): number
	return clampProb((base or CFG.ProbBase) + (ataque - evasion) * CFG.ProbPendiente)
end

-- UserImpactoNpc (:240) con la base, el piso y el techo del golpe a una criatura (Fase 24, docs/43 §15;
-- fase24_ref.prob_vs_criatura)
function Formulas.probExitoCriatura(ataque: number, evasion: number): number
	local x = CFG.ProbBaseVsCriatura + (ataque - evasion) * CFG.ProbPendiente
	return math.max(CFG.ProbMinVsCriatura, math.min(CFG.ProbMaxVsCriatura, vbRound(x)))
end

-- :1353-1356
function Formulas.probRechazo(v: Combatiente): number
	local suma = math.max(1, v.skills.Defensa + v.skills.Tacticas)
	return clampProb(100 * v.skills.Defensa / suma)
end

-- CalcularDano, rama arma cuerpo a cuerpo (:417, :449, :455) y sin arma (:426-447: 4..9 con ModDanoWrestling)
-- Fase 14a (docs/27 §2.1): con un arco, el arco más la flecha (la flecha no entra en DanoMaxArma, :368-369) y
-- ModDanoProyectiles; las Cuchillas (sin Municiones) solo su golpe. Sin arma, los guantes del slot de anillo suman
-- su golpe a los 4..9 de los puños (:433-443).
-- Fase 21 (docs/40 §3): con la Espada Mata Dragones el arma vale 1 (:380-384, :412-415), salvo contra un dragón
-- grande (contraDragon), donde se tira como cualquier arma y el que llama pisa el resultado.
function Formulas.calcularDano(p: Combatiente, rnd: Rnd, contraDragon: boolean?): number
	local arma = p.equipo.arma
	local danoArma, danoMaxArma, modif
	if arma and arma.proyectil then
		danoArma = rnd("arma", arma.minHit :: number, arma.maxHit :: number)
		danoMaxArma = arma.maxHit :: number
		local flecha = p.equipo.municion
		if arma.municiones and flecha then
			danoArma += rnd("flecha", flecha.minHit :: number, flecha.maxHit :: number)
		end
		modif = Formulas.f32(p.mod.DanoProyectiles or 0)
	elseif arma then
		danoArma = rnd("arma", arma.minHit :: number, arma.maxHit :: number)
		danoMaxArma = arma.maxHit :: number
		if Formulas.esMataDragones(arma) and not contraDragon then
			danoArma, danoMaxArma = 1, 1
		end
		modif = Formulas.f32(p.mod.DanoArmas)
	else
		local lo, hi = CFG.DanoPunosMin, CFG.DanoPunosMax
		local g = p.equipo.anillo
		if g and g.guante then
			lo += g.minHit :: number
			hi += g.maxHit :: number
		end
		danoArma = rnd("arma", lo, hi)
		danoMaxArma = hi
		modif = Formulas.f32(p.mod.DanoWrestling or 0)
	end
	local danoUsuario = rnd("golpe_pj", p.minHit, p.maxHit)
	return vbRound(
		(CFG.MultArma * danoArma + (danoMaxArma / CFG.DivisorFuerza) * math.max(0, p.atrib.Fuerza - CFG.FuerzaBase) + danoUsuario)
			* modif
	)
end

export type Resultado = {
	resultado: string, -- "acierta" | "falla" | "rechazado"
	danio: number,
	lugar: number, -- 1 cabeza, 2..6 cuerpo; 0 si no acertó
	bruto: number,
	defCabeza: number,
	defCuerpo: number,
	mataDragon: boolean?, -- Fase 21: el golpe fue con la Espada Mata Dragones a un dragón grande (le saca toda la vida)
}

-- El objeto del equipo es la Espada Mata Dragones (los objetos llevan su número en `id`: InventarioService)
function Formulas.esMataDragones(arma: any): boolean
	return arma ~= nil and CFG.MataDragones ~= nil and arma.id == CFG.MataDragones
end

-- UsuarioImpacto (:1258-1396) + UserDanoUser (:1481-1715), sin efectos (mensajes, muerte)
function Formulas.golpeUsuarioUsuario(a: Combatiente, v: Combatiente, rnd: Rnd): Resultado
	local prob = Formulas.probExito(Formulas.poderAtaque(a), Formulas.evasionTotal(v))
	local impacta = rnd("impacto", 1, 100) <= prob
	if not impacta then
		if v.equipo.escudo and rnd("rechazo", 1, 100) <= Formulas.probRechazo(v) then
			return { resultado = "rechazado", danio = 0, lugar = 0, bruto = 0, defCabeza = 0, defCuerpo = 0 }
		end
		return { resultado = "falla", danio = 0, lugar = 0, bruto = 0, defCabeza = 0, defCuerpo = 0 }
	end

	local bruto = Formulas.calcularDano(a, rnd)
	-- El atacante navega: suma el golpe del barco (SistemaCombate.bas:1530-1541)
	local ba = a.equipo.barco
	if ba then
		bruto += rnd("barco", ba.minHit :: number, ba.maxHit :: number)
	end
	local refuerzo = (a.equipo.arma and a.equipo.arma.refuerzo) or 0
	local lugar = rnd("lugar", 1, 6)
	local defCabeza, defCuerpo = 0, 0
	if lugar == CFG.ZonaCabeza then
		local casco = v.equipo.casco
		if casco then
			defCabeza = rnd("defensa", casco.minDef :: number, casco.maxDef :: number)
		end
	else
		local lo, hi = 0, 0
		local armadura, escudo = v.equipo.armadura, v.equipo.escudo
		if armadura then
			lo, hi = armadura.minDef :: number, armadura.maxDef :: number
		end
		if escudo then
			lo += escudo.minDef :: number
			hi += escudo.maxDef :: number
		end
		defCuerpo = rnd("defensa", lo, hi) -- se tira aunque sea 0..0 (:1605)
	end
	-- La víctima navega: resta la defensa del barco (:1543-1554)
	local bv = v.equipo.barco
	local defBarco = if bv then rnd("defensa_barco", bv.minDef :: number, bv.maxDef :: number) else 0
	local danio = bruto + refuerzo - defCabeza - defCuerpo - defBarco
	if danio < 0 then
		danio = 1 -- :1611 (un 0 exacto queda en 0; D-08 A)
	end
	return { resultado = "acierta", danio = danio, lugar = lugar, bruto = bruto, defCabeza = defCabeza, defCuerpo = defCuerpo }
end

-- ─── NPCs (docs/14 §2.4 y §2.5, docs/16) ─────────────────────────────────────
-- dragon y hp (Fase 21, docs/40 §3): es un dragón grande, y la vida que le queda
export type NpcStats = { ataque: number, evasion: number, def: number, minHit: number, maxHit: number, dragon: boolean?, hp: number? }

-- UsuarioAtacaNpc: UserImpactoNpc (:182-251) + UserDanoNpc (:463-512), sin efectos.
-- Tiradas: impacto; si acierta: arma, golpe_pj. (La stamina 1..10 la tira el servicio, siempre.)
function Formulas.golpeUsuarioNpc(a: Combatiente, n: NpcStats, rnd: Rnd): Resultado
	local prob = Formulas.probExitoCriatura(Formulas.poderAtaque(a), n.evasion) -- docs/24 DA-09 A y docs/43 §15
	if rnd("impacto", 1, 100) > prob then
		return { resultado = "falla", danio = 0, lugar = 0, bruto = 0, defCabeza = 0, defCuerpo = 0 }
	end
	-- Fase 21 (docs/40 §3; :375-379, :452-453): la Espada Mata Dragones contra un dragón grande saca toda la vida
	local mata = n.dragon == true and Formulas.esMataDragones(a.equipo.arma)
	local bruto = Formulas.calcularDano(a, rnd, mata)
	-- Navegando: el golpe del barco se suma antes de restar la defensa de la criatura (:489-499)
	local ba = a.equipo.barco
	if ba then
		bruto += rnd("barco", ba.minHit :: number, ba.maxHit :: number)
	end
	if mata then
		bruto = (n.hp or 0) + n.def -- "CalcularDano = vida actual + defensa"
	end
	local danio = bruto - n.def
	if danio < 0 then
		danio = 0 -- :504 piso 0
	end
	return { resultado = "acierta", danio = danio, lugar = 0, bruto = bruto, defCabeza = 0, defCuerpo = 0, mataDragon = mata or nil }
end

-- NpcAtacaUser: NpcImpacto (:253-320) + NpcDano (:600-699), sin efectos.
-- Tiradas: impacto; [rechazo si falla y hay escudo]; si acierta: npc_golpe, lugar, defensa.
function Formulas.golpeNpcUsuario(n: NpcStats, v: Combatiente, rnd: Rnd): Resultado
	local prob = Formulas.probExito(n.ataque, Formulas.evasionTotal(v))
	if rnd("impacto", 1, 100) > prob then
		if v.equipo.escudo and rnd("rechazo", 1, 100) <= Formulas.probRechazo(v) then
			return { resultado = "rechazado", danio = 0, lugar = 0, bruto = 0, defCabeza = 0, defCuerpo = 0 }
		end
		return { resultado = "falla", danio = 0, lugar = 0, bruto = 0, defCabeza = 0, defCuerpo = 0 }
	end
	local bruto = rnd("npc_golpe", n.minHit, n.maxHit)
	local lugar = rnd("lugar", 1, 6)
	local defCabeza, defCuerpo = 0, 0
	if lugar == CFG.ZonaCabeza then
		local casco = v.equipo.casco
		if casco then
			defCabeza = rnd("defensa", casco.minDef :: number, casco.maxDef :: number)
		end
	else
		local lo, hi = 0, 0
		local armadura, escudo = v.equipo.armadura, v.equipo.escudo
		if armadura then
			lo, hi = armadura.minDef :: number, armadura.maxDef :: number
		end
		if escudo then
			lo += escudo.minDef :: number
			hi += escudo.maxDef :: number
		end
		defCuerpo = rnd("defensa", lo, hi)
	end
	-- La defensa del barco se resta además del casco o de la armadura y el escudo (:631-642)
	local bv = v.equipo.barco
	local defBarco = if bv then rnd("defensa_barco", bv.minDef :: number, bv.maxDef :: number) else 0
	local danio = bruto - defCabeza - defCuerpo - defBarco
	if danio < 1 then
		danio = 1 -- :692 piso 1
	end
	return { resultado = "acierta", danio = danio, lugar = lugar, bruto = bruto, defCabeza = defCabeza, defCuerpo = defCuerpo }
end

-- Umbral para dejar de meditar por un golpe de NPC (SistemaCombate.bas:702). hpDespues ya tiene el daño restado.
function Formulas.umbralMeditacion(hpDespues: number, inteligencia: number, skillMeditar: number, rnd05: number): number
	local x = hpDespues / 100 * inteligencia * skillMeditar / 100 * 12 / (rnd05 + 7)
	return if x >= 0 then math.floor(x) else math.ceil(x) -- Fix()
end

-- CalcularDarExp (:2529-2584). Devuelve la exp a dar y el ExpCount que queda.
function Formulas.expPorDanio(dano: number, hpRestante: number, giveExp: number, maxHp: number, expCount: number): (number, number)
	dano = math.max(0, dano)
	if maxHp <= 0 then
		return 0, expCount
	end
	if dano > hpRestante then
		dano = hpRestante
	end
	local e = vbRound(dano * (giveExp / maxHp))
	if e <= 0 then
		return 0, expCount
	end
	if e > expCount then
		return expCount, 0
	end
	return e, expCount - e
end

-- ─── Mecánicas de clase en el golpe (Fase 14a, docs/27 §3; herramientas/fase14_ref.py) ─────────────────
-- PuedeApunalar (Modulo_UsUaRiOs.bas:1504-1527): arma con Apunala y skill >= MIN_APUNALAR (10), o Asesino
function Formulas.puedeApunalar(clase: string, skill: number, armaApunala: boolean): boolean
	return armaApunala and (skill >= CFG.MinApunalar or clase == "Asesino")
end

-- DoApunalar (Trabajo.bas:2388-2419): apuñala si RandomNumber(0, 100) < Suerte
function Formulas.suerteApunalar(clase: string, s: number): number
	local x
	if clase == "Asesino" then
		x = ((0.00003 * s - 0.002) * s + 0.098) * s + 4.25
	elseif clase == "Clerigo" or clase == "Paladin" or clase == "Pirata" then
		x = ((0.000003 * s + 0.0006) * s + 0.0107) * s + 4.93
	elseif clase == "Bardo" then
		x = ((0.000002 * s + 0.0002) * s + 0.032) * s + 4.81
	else
		x = 0.0361 * s + 4.39
	end
	return math.floor(x)
end

-- Daño extra de la apuñalada (Trabajo.bas:2422-2451): contra criaturas Int(daño × 2); en PvP Round(daño × 1,4) el
-- Asesino y × 1,5 el resto
function Formulas.extraApunalar(clase: string, dano: number, vsNpc: boolean): number
	if vsNpc then
		return math.floor(dano * 2)
	end
	return vbRound(dano * (if clase == "Asesino" then 1.4 else 1.5))
end

-- DoGolpeCritico (Trabajo.bas:2498-2566): Bandido con Espada Vikinga; RandomNumber(1, 100) <= Suerte, con Wrestling
function Formulas.suerteCritico(wrestling: number): number
	local s = wrestling
	return math.floor((((0.00000003 * s + 0.000006) * s + 0.000107) * s + 0.0893) * 100)
end

function Formulas.extraCritico(dano: number): number
	return math.floor(dano * 0.75)
end

-- DoAcuchillar (Trabajo.bas:2465-2496): Pirata con un arma Acuchilla; RandomNumber(1, 100) <= 20 → Int(daño × 0,2)
function Formulas.extraAcuchillar(dano: number): number
	return math.floor(dano * 0.2)
end

-- Desarmar y DoDesequipar (Trabajo.bas:2897-3125): Probabilidad = Wrestling × 0,2 + ELV × 0,66 (Integer: redondea);
-- sale si RandomNumber(1, 100) <= Probabilidad
function Formulas.probDesarmar(wrestling: number, elv: number): number
	return vbRound(wrestling * 0.2 + elv * 0.66)
end

return Formulas
