--!strict
--[[
	Fórmulas de la progresión (docs/21 §6 y §7), puras: sin red ni estado del servidor. Verificadas contra
	herramientas/fase12_ref.py (muestras/fase12_vectores.json).

	- aumentoHp: el dado de vida de CheckUserLevel (Modulo_UsUaRiOs.bas:728-778).
	- subirNivel: el bucle de CheckUserLevel (:646-966) sobre una tabla con los campos del personaje.
	- sumarExpSkill: SubirSkill (:1555-1622) + CheckEluSkill (:2855-2875), sin los mensajes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Progresion)
local Clases = require(ReplicatedStorage.Shared.Config.Clases)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Tablas = require(ReplicatedStorage.Shared.Generado.Progresion)

local Formulas = {}

-- Lo que subirNivel necesita y modifica
export type Stats = {
	clase: string,
	elv: number,
	exp: number,
	elu: number,
	atrib: { [string]: number }, -- los atributos actuales (con el efecto de las pociones, como UserAtributos)
	hp: number,
	maxHp: number,
	maxSta: number,
	maxMana: number,
	minHit: number,
	maxHit: number,
	skillPts: number,
}

function Formulas.elu(elv: number): number
	return Tablas.elu[elv] or 0
end

function Formulas.esNewbie(elv: number): boolean -- EsNewbie (GameLogic.bas:32-40)
	return elv <= Cfg.LimiteNewbie
end

-- Promedio = ModVida - (21 - Constitución) × 0,5
function Formulas.promedioVida(clase: string, con: number): number
	local d = Clases.datos[clase]
	return (if d then d.modVida else 0) - (21 - con) * 0.5
end

-- aux = RandomNumber(0, 100). Los resultados son exactos (promedio ± entero o ± medio), sin redondeo.
function Formulas.aumentoHp(clase: string, con: number, aux: number): number
	local p = Formulas.promedioVida(clase, con)
	local acum = 0
	if p - math.floor(p) == 0.5 then
		local deltas = { 1.5, 0.5, -0.5, -1.5 }
		for i, d in Cfg.DistribucionSemientera do
			acum += d
			if aux <= acum then
				return p + deltas[i]
			end
		end
		return p - 1.5
	end
	local deltas = { 2, 1, 0, -1, -2 }
	for i, d in Cfg.DistribucionEntera do
		acum += d
		if aux <= acum then
			return p + deltas[i]
		end
	end
	return p - 2
end

-- Redondeo de VB6 (CInt / asignación a Integer): bancario
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
Formulas.vbRound = vbRound

-- AumentoHIT / AumentoMANA / AumentoSTA de cada clase (docs/27 §1.1). elv = el nivel nuevo. El maná se redondea
-- (AumentoMANA es Integer): el Mago suma 2,8 × INT y el Bandido ⅔ × INT.
function Formulas.aumentos(clase: string, elv: number, inteligencia: number): (number, number, number)
	local d = Clases.datos[clase]
	if not d then
		return 2, 0, 15 -- Case Else
	end
	local hit = if elv > 35 then d.golpe[2] else d.golpe[1]
	return hit, vbRound(d.manaPorInt * inteligencia), d.energia
end

export type Subida = { mensajes: { string }, puntos: number, niveles: number, dejoDeSerNewbie: boolean }

-- CheckUserLevel. dado() = RandomNumber(0, 100), uno por nivel. Modifica s y devuelve los mensajes (INFO) y los
-- skillpoints ganados (ya sumados a s.skillPts). No toca experiencia de skills ni objetos newbie: eso lo hace quien
-- llama con dejoDeSerNewbie.
function Formulas.subirNivel(s: Stats, dado: () -> number): Subida
	local r: Subida = { mensajes = {}, puntos = 0, niveles = 0, dejoDeSerNewbie = false }
	local eraNewbie = Formulas.esNewbie(s.elv)
	while s.exp >= s.elu do
		if s.elv >= Cfg.NivelMaximo then
			s.exp, s.elu = 0, 0
			return r -- Exit Sub: sin mensaje de skillpoints ni objetos newbie
		end
		table.insert(r.mensajes, "Has subido de nivel!")
		r.puntos = if s.elv == 1 then 10 else r.puntos + 5
		s.elv += 1
		r.niveles += 1
		s.exp -= s.elu
		s.elu = Formulas.elu(s.elv)
		local ahp = Formulas.aumentoHp(s.clase, s.atrib.Constitucion, dado())
		local ahit, aman, asta = Formulas.aumentos(s.clase, s.elv, s.atrib.Inteligencia)
		s.maxHp = math.min(Cfg.MaxHp, s.maxHp + ahp)
		s.maxSta = math.min(Cfg.MaxSta, s.maxSta + asta)
		s.maxMana = math.min(Cfg.MaxMana, s.maxMana + aman)
		local tope = if s.elv < 36 then Cfg.MaxHitMenos36 else Cfg.MaxHitDesde36
		s.maxHit = math.min(tope, s.maxHit + ahit)
		s.minHit = math.min(tope, s.minHit + ahit)
		if ahp > 0 then
			table.insert(r.mensajes, `Has ganado {ahp} puntos de vida.`)
		end
		if asta > 0 then
			table.insert(r.mensajes, `Has ganado {asta} puntos de energia.`)
		end
		if aman > 0 then
			table.insert(r.mensajes, `Has ganado {aman} puntos de mana.`)
		end
		if ahit > 0 then
			table.insert(r.mensajes, `Tu golpe maximo aumento en {ahit} puntos.`)
			table.insert(r.mensajes, `Tu golpe minimo aumento en {ahit} puntos.`)
		end
		s.hp = s.maxHp -- MinHp = MaxHp (el maná y la stamina no se llenan)
	end
	r.dejoDeSerNewbie = eraNewbie and not Formulas.esNewbie(s.elv)
	if r.puntos > 0 then
		s.skillPts += r.puntos
		table.insert(r.mensajes, `Has ganado un total de {r.puntos} skillpoints.`)
	end
	return r
end

-- ─── Skills ──────────────────────────────────────────────────────────────────
-- Fase 30 (docs/50 §2; fase30_ref.puntos_totales): todos los puntos de habilidad que recibió un personaje de ese
-- nivel: los del principio, 10 al llegar al nivel 2 y 5 por cada nivel siguiente (subirNivel, más arriba)
function Formulas.puntosTotales(elv: number): number
	if elv <= 1 then
		return Skills.PuntosIniciales
	end
	return Skills.PuntosIniciales + 10 + 5 * (elv - 2)
end

-- El reinicio de habilidades (Fase 30, docs/50 §2): todas a 0 y todos los puntos del nivel para repartir. Modifica
-- valores y exps; devuelve los puntos libres que le quedan, o nil si no había nada que reiniciar (todas en 0).
function Formulas.reiniciarSkills(valores: { [string]: number }, exps: { [string]: number }, elv: number): number?
	local hay = false
	for _, s in Skills.Lista do
		if (valores[s.clave] or 0) > 0 then
			hay = true
		end
	end
	if not hay then
		return nil
	end
	for _, s in Skills.Lista do
		valores[s.clave] = 0
		exps[s.clave] = 0
	end
	return Formulas.puntosTotales(elv)
end

function Formulas.topeSkill(elv: number): number -- LevelSkill(min(ELV, UBound))
	local t = Tablas.levelSkill
	return t[math.clamp(elv, 1, #t)]
end

function Formulas.eluSkill(valor: number): number -- CheckEluSkill: 0 en 100
	if valor >= Skills.Max then
		return 0
	end
	return Tablas.eluSkill[valor + 1]
end

-- SubirSkill sin la condición de los 10 puntos asignados ni el hambre (las mira quien llama). Modifica valores y
-- exps. Devuelve true si el skill subió un punto (quien llama suma la experiencia y manda los mensajes).
function Formulas.sumarExpSkill(valores: { [string]: number }, exps: { [string]: number }, clave: string, elv: number, acerto: boolean): boolean
	local v = valores[clave] or 0
	if v >= Skills.Max then
		return false
	end
	if v >= Formulas.topeSkill(elv) then
		return false
	end
	if Skills.PuntoPorAccion then -- Fase 26 (docs/46 §8): un punto por acción, sin contador
		valores[clave] = v + 1
		exps[clave] = 0
		return true
	end
	local e = (exps[clave] or 0) + (if acerto then Skills.ExpAcierto else Skills.ExpFallo)
	local elu = Formulas.eluSkill(v)
	if e >= elu then
		valores[clave] = v + 1
		-- CheckEluSkill(…, False): ExpSkills -= EluSkills (el viejo); en 100 queda en 0
		exps[clave] = if v + 1 >= Skills.Max then 0 else e - elu
		return true
	end
	exps[clave] = e
	return false
end

return Formulas
