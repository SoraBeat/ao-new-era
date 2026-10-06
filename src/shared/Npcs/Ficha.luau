--!strict
--[[
	Ficha — lo que se sabe de una criatura, para mostrarlo (Fase 28, docs/48 §2; pedido del autor: "Inspeccionar").

	Sale todo de datos que el cliente ya tiene: Generado/Npcs (la ficha del .dat), Config/Npcs (el multiplicador de
	experiencia y de oro, la chance de cada drop, el piso de oro y el drop extra), Config/Mascotas (qué pide domarla) y
	Config/Magia (los nombres de los hechizos que lanza). Los mismos números que usa el servidor al pegar, dar
	experiencia y tirar objetos. La referencia con los casos: herramientas/fase28_ref.py (ficha).
]]

local Config = script.Parent.Parent.Config
local Generado = script.Parent.Parent.Generado

local Cfg = require(Config.Npcs)
local CfgMascotas = require(Config.Mascotas)
local Magia = require(Config.Magia)
local Npcs = require(Generado.Npcs) :: any
local Objetos = require(Generado.ObjetosInventario) :: any
local ObjetosPiso = require(Generado.ObjetosPiso) :: any

local Ficha = {}

export type Drop = {
	obj: number, -- 0 = oro
	nombre: string,
	cant: number,
	prob: number, -- de 0 a 1 (la del oro, sumada: con el piso, varias tiradas dan la misma cantidad)
	grh: number, -- el dibujo del objeto (0 = sin dibujo)
}

export type Datos = {
	numero: number,
	nombre: string,
	cuerpo: number,
	cabeza: number,
	vida: number,
	golpeMin: number,
	golpeMax: number,
	defensa: number,
	defensaMagica: number,
	ataque: number,
	evasion: number,
	exp: number, -- la que reparte entera, ya multiplicada
	ataca: boolean,
	envenena: boolean,
	inmune: boolean, -- a Paralizar e Inmovilizar
	agua: string?, -- "anfibia" | "agua"
	domar: { skill: number, nivel: number }?,
	hechizos: { string },
	drops: { Drop }, -- de la más probable a la menos
	oroPiso: number, -- el oro que deja como mínimo (0 = no tiene); ya está contado en los drops
	oroPromedio: number,
}

-- ¿Se la puede inspeccionar? Las criaturas: lo que se puede atacar y es hostil o da experiencia. Los comerciantes,
-- los sacerdotes y el resto de la gente de las ciudades, no.
function Ficha.inspeccionable(numero: number): boolean
	local d = Npcs[numero]
	return d ~= nil and d.atacable == true and (d.hostil == true or (d.exp or 0) > 0)
end

function Ficha.de(numero: number): Datos?
	local d = Npcs[numero]
	if not d then
		return nil
	end
	local drops: { Drop } = {}
	local piso = Cfg.oroPiso(d)
	if d.inventario then -- los pretorianos tiran todo lo que llevan
		for _, o in d.inventario do
			local obj = Objetos[o[1]]
			if obj then
				table.insert(drops, { obj = o[1], nombre = obj.nombre, cant = o[2], prob = 1, grh = obj.grh or 0 })
			elseif o[1] == Cfg.Oro then -- (Fase 31, D31-30: el oro que llevan también cae)
				local grhOro = if ObjetosPiso[Cfg.Oro] then ObjetosPiso[Cfg.Oro].grh or 0 else 0
				table.insert(drops, { obj = 0, nombre = "Monedas de oro", cant = o[2], prob = 1, grh = grhOro })
			end
		end
	else
		-- El drop extra tiene su propia tirada (Config/Npcs.DropExtra: { objeto, cantidad, % })
		local extra = Cfg.DropExtra[numero]
		if extra and Objetos[extra[1]] then
			table.insert(drops, { obj = extra[1], nombre = Objetos[extra[1]].nombre, cant = extra[2], prob = extra[3] / 100, grh = Objetos[extra[1]].grh or 0 })
		end
		-- El oro, como lo da el servidor (Config/Npcs.oroAlMorir): si en la tirada sale oro, el mayor entre ese y el
		-- piso; si no sale, el piso con PisoProb %. Acá se suma la chance de cada cantidad, así se ve lo que de verdad
		-- deja: un Murciélago, 100 monedas casi siempre (y no las 5 del .dat).
		local oro: { [number]: number } = {}
		local cantidades: { number } = {}
		local function sumar(cant: number, p: number)
			if oro[cant] == nil then
				oro[cant] = 0
				table.insert(cantidades, cant)
			end
			oro[cant] += p
		end
		local resto = 1 -- la chance de que no salga ningún drop
		for k, p in Cfg.ProbDrop do
			local dr = d.drops and d.drops[k]
			resto -= p
			if dr and dr[1] == Cfg.Oro and dr[2] > 0 then
				sumar(math.max(dr[2] * Cfg.OroMulti, piso), p)
			else
				if dr and dr[1] > 0 and dr[2] > 0 and Objetos[dr[1]] then
					table.insert(drops, { obj = dr[1], nombre = Objetos[dr[1]].nombre, cant = dr[2], prob = p, grh = Objetos[dr[1]].grh or 0 })
				end
				if piso > 0 then
					sumar(piso, p * Cfg.PisoProb / 100)
				end
			end
		end
		if piso > 0 then
			sumar(piso, resto * Cfg.PisoProb / 100)
		end
		local grhOro = if ObjetosPiso[Cfg.Oro] then ObjetosPiso[Cfg.Oro].grh or 0 else 0
		for _, cant in cantidades do
			table.insert(drops, { obj = 0, nombre = "Monedas de oro", cant = cant, prob = oro[cant], grh = grhOro })
		end
	end
	-- de la más probable a la menos (a igual chance, en el orden del .dat)
	local orden: { [Drop]: number } = {}
	for i, x in drops do
		orden[x] = i
	end
	table.sort(drops, function(a, b)
		return if a.prob ~= b.prob then a.prob > b.prob else orden[a] < orden[b]
	end)
	local hechizos: { string } = {}
	local visto: { [number]: boolean } = {}
	for _, h in d.hechizos or {} do
		local x = Magia.Hechizos[h]
		if x and not visto[h] then
			visto[h] = true
			table.insert(hechizos, (string.gsub(x.nombre, " %(NPC%)$", ""))) -- "Apocalipsis (NPC)": la versión de las criaturas
		end
	end
	local doma = CfgMascotas.Domables[numero]
	return {
		numero = numero,
		nombre = d.nombre,
		cuerpo = d.cuerpo,
		cabeza = d.cabeza or 0,
		vida = d.hp,
		golpeMin = d.minHit,
		golpeMax = d.maxHit,
		defensa = d.def,
		defensaMagica = d.defM,
		ataque = d.ataque,
		evasion = d.evasion,
		exp = (d.exp or 0) * Cfg.ExpMulti,
		ataca = d.hostil == true,
		envenena = d.veneno == true,
		inmune = (d.afectaParalisis or 0) ~= 0,
		agua = if d.aguaValida then (if d.tierraInvalida then "agua" else "anfibia") else nil,
		domar = if doma then { skill = doma[1], nivel = doma[2] } else nil,
		hechizos = hechizos,
		drops = drops,
		oroPiso = piso,
		oroPromedio = if piso > 0 or #drops > 0 then math.floor(Cfg.oroPromedio(d) + 0.5) else 0,
	}
end

return Ficha
