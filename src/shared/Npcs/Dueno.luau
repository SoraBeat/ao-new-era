--!strict
--[[
	Dueno — las reglas puras de las criaturas con dueño y del estado atacable (Fase 19, docs/38 §4 y §5). Las mismas de
	herramientas/fase19_ref.py, verificadas contra muestras/fase19_vectores.json.

	PuedeAtacarNPC (SistemaCombate.bas:2210-2474), ApropioNpc (Modulo_UsUaRiOs.bas:2693-2740), CanSupportNpc
	(modHechizos.bas:2685-2800), ToogleToAtackable (Modulo_UsUaRiOs.bas:2997-3053), PuedeAtacar (SistemaCombate.bas:1892-1919).

	Lo que cambia del original (docs/38 §7): el neutral cuenta como ciudadano (DC19-08 A) y con un newbie de por medio
	no se roba (DC19-09 A); lo mismo entre un personaje de prueba y uno real.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Dueno)

local Dueno = {}

local M = Cfg.Msg

-- Lo que las reglas miran de un jugador. clan y party: cualquier valor que sea igual entre compañeros (nil = no tiene).
-- atacablePor y comparte: el id del otro jugador.
export type Jugador = {
	id: number,
	estado: string, -- newbie | ciudadano | neutral | criminal
	faccion: string?, -- armada | caos
	seguro: boolean,
	clan: any?,
	party: any?,
	atacablePor: number?,
	comparte: number?,
	prueba: boolean,
}

export type Golpe = {
	paraliza: boolean?, -- el golpe es un hechizo que paraliza o inmoviliza
	yaParalizada: boolean?, -- la criatura ya está paralizada o inmovilizada
	tieneOtra: boolean?, -- el que pega ya es dueño de otra criatura
	especial: boolean?, -- pretoriano o dragón: no tiene dueño nunca
	mascota: boolean?, -- el golpe es de una mascota
	lugarSeguro: boolean?, -- mapa seguro o parado en un tile de zona segura: ahí nadie se queda con nada
}

-- puede: el golpe sale. msg: lo que dice la consola (el motivo, o el aviso de atacable). dueno: el id del dueño que
-- queda (nil = sin dueño). renueva: reinicia los 18 s. atacable: el id de quién pasa a poder pegarle (nil = nadie).
export type Resultado = { puede: boolean, msg: string?, dueno: number?, renueva: boolean, atacable: number? }

local function criminal(j: Jugador): boolean
	return j.estado == "criminal"
end

-- SistemaCombate.bas:2446 (Not criminal Or esCaos). El neutral y el newbie cuentan como ciudadanos.
function Dueno.puedeSerDueno(j: Jugador): boolean
	return not criminal(j) or j.faccion == "caos"
end

-- Qué pasa cuando `a` le pega a una criatura. dueno: su dueño, o nil; seg: segundos desde el último golpe del dueño.
function Dueno.golpe(a: Jugador, dueno: Jugador?, seg: number, g: Golpe?): Resultado
	local o: Golpe = g or {}
	-- A los 18 s la criatura queda sin dueño (ValidarPermanenciaNpc, MODULO_NPCs.bas:1328): el que le pega entonces
	-- pasa por la rama "sin dueño", con sus condiciones
	local d: Jugador? = if dueno and seg < Cfg.OwnedSeg then dueno else nil
	local r: Resultado = { puede = true, msg = nil, dueno = if d then d.id else nil, renueva = false, atacable = nil }
	if not d then
		-- ApropioNpc: el primero que le pega; con un hechizo que paraliza no cambia la que ya tenía
		if Dueno.puedeSerDueno(a) and not o.especial and not o.mascota and not o.lugarSeguro and not (o.tieneOtra and o.paraliza) then
			r.dueno, r.renueva = a.id, true
		end
		return r
	end
	if d.id == a.id then
		r.renueva = true
		return r
	end
	if d.comparte == a.id then
		return r
	end
	if (a.clan ~= nil and a.clan == d.clan) or (a.party ~= nil and a.party == d.party) then
		return r
	end
	local function no(msg: string): Resultado
		r.puede, r.msg = false, msg
		return r
	end
	-- DC19-09 A: con un newbie de por medio no se roba. Tampoco entre un personaje de prueba y uno real
	if a.prueba ~= d.prueba or a.estado == "newbie" then
		return no(M.newbie)
	end
	if d.estado == "newbie" then
		return no(M.deNewbie)
	end
	if o.paraliza and not o.yaParalizada then
		return r -- siempre se puede paralizar a la que no lo está
	end
	local p = if o.paraliza then "Para" else ""
	if not criminal(d) then
		if not criminal(a) then
			if a.faccion == "armada" and d.faccion == "armada" then
				return no(M["armada" .. p])
			end
			if a.seguro then
				return no(if o.paraliza then M.seguroPara elseif a.faccion == "armada" then M.seguroArmada else M.seguro)
			end
			if a.atacablePor ~= nil and a.atacablePor ~= d.id then
				return no(M.castigo)
			end
			r.msg, r.atacable = M["atacable" .. p], d.id
			return r
		end
		if o.paraliza then
			return r -- criminal que paraliza: "puede hacer lo que quiera"
		end
		if a.seguro then
			return no(M.seguro)
		end
		return r
	end
	if a.faccion == "caos" and d.faccion == "caos" then
		return no(M["caos" .. p])
	end
	return r
end

-- Curar a la criatura de otro (CanSupportNpc; solo se llama al curar, modHechizos.bas:1917-1919). No mira compartir,
-- clan ni party: curar a la criatura con la que pelea otro es ir contra él.
function Dueno.ayuda(a: Jugador, dueno: Jugador?, seg: number): Resultado
	local r: Resultado = { puede = true, msg = nil, dueno = nil, renueva = false, atacable = nil }
	if not dueno or seg >= Cfg.OwnedSeg or dueno.id == a.id then
		return r
	end
	local d = dueno
	local function no(msg: string): Resultado
		r.puede, r.msg = false, msg
		return r
	end
	if a.prueba ~= d.prueba or a.estado == "newbie" then
		return no(M.newbie)
	end
	if d.estado == "newbie" then
		return no(M.deNewbie)
	end
	if criminal(d) then
		if a.faccion == "caos" and d.faccion == "caos" then
			return no(M.ayudaFaccion)
		end
		return r
	end
	if criminal(a) then
		return r
	end
	if a.faccion == "armada" and d.faccion == "armada" then
		return no(M.ayudaFaccion)
	end
	if a.seguro then
		return no(M.ayudaSeguro)
	end
	-- :2775-2776 no mira lo que devuelve ToogleToAtackable: cura igual aunque ya sea atacable por otro
	if a.atacablePor == nil or a.atacablePor == d.id then
		r.atacable = d.id
	end
	return r
end

-- PuedeAtacar: entre dos que no son criminales, el dueño le pega al que le robó, con o sin seguro y esté donde esté
-- (va antes que el seguro, :1940, y que el tile de zona segura, :2001). No en un mapa seguro (ToogleToAtackable
-- devuelve falso, Modulo_UsUaRiOs.bas:3010-3014).
function Dueno.pegaPorAtacable(a: Jugador, v: Jugador, mapaSeguro: boolean): boolean
	return v.atacablePor == a.id and not criminal(a) and not criminal(v) and not mapaSeguro
end

-- ToogleToAtackable(a, v, False): el que le pega al atacable queda atacable por él, salvo que ya lo sea por otro. En
-- los dos casos se renueva su reloj (el del que pega), no el de la víctima. Devuelve si toma a la víctima.
function Dueno.contraataque(a: Jugador): boolean
	return a.atacablePor == nil
end

return Dueno
