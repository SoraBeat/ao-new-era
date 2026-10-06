--!strict
--[[
	Fórmulas de magia del servidor VB6 clásico (docs/15-spec-magia-slice.md §3.1 y §5.2).
	Funciones puras; el azar entra por parámetro. Vectores: herramientas/magia_ref.py (dano, meditar).
]]

local FormulasMagia = {}

-- Porcentaje(Total, Porc) = CLng(Total * Porc / 100): redondeo bancario (Matematicas.bas:32-35)
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

function FormulasMagia.porcentaje(total: number, porc: number): number
	return vbRound(total * porc / 100)
end
local porcentaje = FormulasMagia.porcentaje

-- Curación: base + Porcentaje(base, 3 * ELV) (modHechizos.bas:2317-2318)
function FormulasMagia.cura(base: number, elv: number, bonusPorNivel: number?): number
	return base + porcentaje(base, (bonusPorNivel or 3) * elv)
end

-- Daño a un usuario (modHechizos.bas:2353-2387). Sin báculo ni laúd en el slice; el casco resta una
-- tirada entre su DefensaMagicaMin y Max (el 131 del preset: 0-0) y el resultado no baja de 0.
function FormulasMagia.dano(base: number, elv: number, restaCasco: number?, bonusPorNivel: number?): number
	local d = base + porcentaje(base, (bonusPorNivel or 3) * elv)
	d -= restaCasco or 0
	return math.max(0, d)
end

FormulasMagia.vbRound = vbRound

-- Fase 14b (docs/27 §12.3): el daño antes de las defensas, con el báculo del Mago y el laúd o la flauta élficos
-- (modHechizos.bas:2353-2373, :1954-1987). baculo: nil si no corre (no es Mago o el hechizo no es StaffAffected); -1
-- sin arma; si no, el StaffDamageBonus del arma (0 si no es un báculo). Cada paso es Double y se guarda en un Long
-- (bancario): 45 × 0,7 = 31,4999… → 31 (herramientas/fase14_ref.py dano_hechizo).
function FormulasMagia.danoBase(base: number, elv: number, bonusPorNivel: number, baculo: number?, elfico: boolean): number
	local d = base + porcentaje(base, bonusPorNivel * elv)
	if baculo then
		if baculo < 0 then
			d = vbRound(d * 0.7)
		else
			d = vbRound((d * (baculo + 70)) / 100)
		end
	end
	if elfico then
		d = vbRound(d * 1.04)
	end
	return d
end

-- Maná del hechizo (docs/27 §12.2): el chequeo sin redondear (Single) y el cobro redondeado (Integer/Long)
function FormulasMagia.mana(mana: number, bono: number): (number, number)
	return mana * bono, vbRound(mana * bono)
end

-- Vida del que resucita (modHechizos.bas:1508-1512): MinHp × (1 − ELV del revivido × 0,015), bancario
function FormulasMagia.vidaTrasResucitar(hp: number, elvRevivido: number): number
	return vbRound(hp * (1 - elvRevivido * 0.015))
end

-- Suerte de meditar según el skill (Trabajo.bas:2839-2862): 1 chance en `suerte` por tick de 40 ms
local TRAMOS = { { 10, 35 }, { 20, 30 }, { 30, 28 }, { 40, 24 }, { 50, 22 }, { 60, 20 }, { 70, 18 }, { 80, 15 }, { 90, 10 } }
function FormulasMagia.suerte(skill: number): number
	for _, t in TRAMOS do
		if skill <= t[1] then
			return t[2]
		end
	end
	return if skill < 100 then 7 else 5
end

-- Maná por pulso: Porcentaje(MaxMAN, 6), mínimo 1 (Trabajo.bas:2870-2872)
function FormulasMagia.manaPorPulso(maxMana: number, porc: number?): number
	local c = porcentaje(maxMana, porc or 6)
	return if c > 0 then c else 1
end

-- FX de meditar según nivel (Protocol.bas:6580-6596)
function FormulasMagia.fxMeditar(elv: number): number
	if elv < 13 then
		return 4
	elseif elv < 25 then
		return 5
	elseif elv < 35 then
		return 6
	elseif elv < 42 then
		return 16
	end
	return 34
end

return FormulasMagia
