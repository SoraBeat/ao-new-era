--!strict
--[[
	Liderazgo — para qué sirve la habilidad Liderazgo (Fase 31, docs/51; pedido del autor, D31-10 a D31-14).

	Hasta acá solo servía para fundar un clan (Config.Clanes.LiderazgoFundar) y no se entrenaba usándola. Estas son las
	cuentas puras de lo nuevo. Todas van con el Liderazgo del LÍDER (el del grupo o el del clan), acotado a 0..100:
	  - D31-11: cuántos entran en un grupo (maxMiembros).
	  - D31-12: desde qué distancia de la criatura cobra un miembro su parte de experiencia y de oro (distancia).
	  - D31-10: el bono de experiencia del grupo (bono, conBono).
	  - D31-14: cuántos miembros admite un clan (topeClan).
	(D31-13, que se entrene liderando un grupo, no tiene cuentas: lo hace PartyService.liderar.)

	Sin Roblox ni servicios: lo usan PartyService, ClanService y las pruebas con Lune (tools/luau/fase31_liderazgo.luau).
]]

local Liderazgo = {}

local MAX = 100 -- Config.Skills.Max (MAXSKILLPOINTS)

-- El Liderazgo que cuenta: de 0 a 100 (lo que no es un número, 0)
local function acotar(l: number): number
	if typeof(l) ~= "number" or l ~= l then
		return 0
	end
	return math.clamp(l, 0, MAX)
end

-- ─── D31-11: el tope de miembros de un grupo ─────────────────────────────────
Liderazgo.MiembrosBase = 5 -- los de siempre (PARTY_MAXMEMBERS, mdParty.bas:38)
Liderazgo.Miembros = { { 50, 6 }, { 75, 7 }, { 100, 8 } } -- { Liderazgo mínimo, tope del grupo }

-- 5; 6 con 50; 7 con 75; 8 con 100
function Liderazgo.maxMiembros(l: number): number
	local v = acotar(l)
	local tope = Liderazgo.MiembrosBase
	for _, par in Liderazgo.Miembros do
		if v >= par[1] and par[2] > tope then
			tope = par[2]
		end
	end
	return tope
end

-- ─── D31-12: desde dónde se cobra ────────────────────────────────────────────
Liderazgo.DistanciaBase = 18 -- PARTY_MAXDISTANCIA (mdParty.bas:55)

-- Los casilleros (distancia euclídea a la criatura) hasta los que un miembro cobra su parte: 18 + Liderazgo. Con 100
-- o más, nil: desde cualquier lugar del mapa de la criatura.
function Liderazgo.distancia(l: number): number?
	local v = acotar(l)
	if v >= MAX then
		return nil
	end
	return Liderazgo.DistanciaBase + v
end

-- ─── D31-10: el bono de experiencia del grupo ────────────────────────────────
Liderazgo.BonoMax = 10 -- % de experiencia con 100

-- El porcentaje: Liderazgo / 10 (de 0 a 10; con decimales: 55 → 5,5)
function Liderazgo.bono(l: number): number
	return acotar(l) * Liderazgo.BonoMax / MAX
end

-- Por cuánto se multiplica lo que reparte el grupo: 1 + bono / 100 (1,055 con 55; 1,1 con 100). PartyService multiplica
-- con esto sin redondear (lleva los decimales de cada miembro y paga los enteros), así el bono no se pierde en los
-- golpes chicos: redondeando cada golpe, con 10 de Liderazgo un golpe de 70 puntos no sumaba nada.
function Liderazgo.factor(l: number): number
	local den = 100 * MAX
	return (den + acotar(l) * Liderazgo.BonoMax) / den
end
-- Para que el bono cuente tienen que cobrar 2 o más, y cada uno de esos, por lo menos esta parte del reparto (%): así
-- no alcanza con sumar al grupo a un personaje de nivel 1 que se queda parado (se llevaría menos del 1 %).
Liderazgo.ParteMinBono = 10

-- La experiencia con el bono: exp × (100 + bono) / 100, redondeado para abajo. La cuenta va con enteros (el bono
-- tiene un decimal: 55 → 5,5 %) para que no se pierda un punto por el redondeo de los decimales.
function Liderazgo.conBono(exp: number, l: number): number
	local den = 100 * MAX
	return math.floor(exp * (den + acotar(l) * Liderazgo.BonoMax) / den)
end

-- ─── D31-14: el tope de miembros de un clan ──────────────────────────────────
Liderazgo.ClanBase = 20
Liderazgo.ClanCada = 5 -- un miembro más cada 5 puntos

-- 20 + floor(Liderazgo / 5): 38 con 90 (lo que pide fundar), 40 con 100
function Liderazgo.topeClan(l: number): number
	return Liderazgo.ClanBase + math.floor(acotar(l) / Liderazgo.ClanCada)
end

return Liderazgo
