--!strict
--[[
	Mapas — los mapas del port y lo que se sabe de ellos sin estado (Fase 13, docs/22 §2; Fase 17a, docs/35 §1.2).

	Compartido por servidor y cliente. Los mapas están en formato AOM1 (`Generado/Mapas/MapaN`, lo decodifica
	`MapaBinario`) y sus metadatos en `Generado/MapasIndice`, que también dice qué mapas existen.

	`Mapas.cargar(n)` devuelve la tabla del mapa: lo decodificado (capa1 y bloqueos como `buffer`, el resto como
	tablas), los metadatos del índice (`numero`, `nombre`, `zonaSegura`, `terreno`, `zona`, `musica`, `restricciones`)
	y `dinamico` armado: las salidas a mapas que no están en el port quedan bloqueadas (DF13-04 A), así el cliente no
	predice pasos que el servidor va a rechazar. Las puertas también escriben en `dinamico` (MundoService y el
	cliente). Cada lado guarda su caché: el servidor, todos; el cliente, los últimos `Mapas.limiteCache`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local MapaBinario = require(ReplicatedStorage.Shared.Mundo.MapaBinario)
local Indice = require(ReplicatedStorage.Shared.Generado.MapasIndice)

local Mapas = {}

local carpeta = ReplicatedStorage.Shared.Generado.Mapas

-- Los mapas del port, en el orden en que los carga el servidor (DF13-03 A; docs/35: todos los del índice)
Mapas.PORTADOS = {} :: { number }
for n in Indice do
	table.insert(Mapas.PORTADOS, n)
end
table.sort(Mapas.PORTADOS)

-- eTrigger (Declares.bas): los que usa el port
Mapas.TRIGGER = { BAJOTECHO = 1, CASA = 2, POSINVALIDA = 3, ZONASEGURA = 4, ANTIPIQUETE = 5, ZONAPELEA = 6 }

-- Cuántos mapas decodificados guarda este lado (el cliente lo baja a 3, docs/35 §1.2)
Mapas.limiteCache = math.huge

local cache: { [number]: any } = {}
local usoCache: { number } = {} -- del menos al más reciente

function Mapas.existe(n: number): boolean
	return Indice[n] ~= nil
end

-- Se puede entrar: está en el port y no está cerrado (los anillos de la Armada y la Legión hasta el P8, DW17-03 A)
function Mapas.abierto(n: number): boolean
	local m = Indice[n]
	return m ~= nil and not m.cerrado
end

function Mapas.meta(n: number): Indice.Meta?
	return Indice[n]
end

local function usar(n: number)
	local k = table.find(usoCache, n)
	if k then
		table.remove(usoCache, k)
	end
	table.insert(usoCache, n)
	while #usoCache > Mapas.limiteCache do
		cache[table.remove(usoCache, 1) :: number] = nil
	end
end

function Mapas.cargar(n: number): any
	local m = cache[n]
	if not m then
		local meta = Indice[n]
		assert(meta, `El mapa {n} no está en el port`)
		m = MapaBinario.leer(require(carpeta:FindFirstChild(`Mapa{n}`) :: ModuleScript) :: any) :: any
		m.numero = n
		m.nombre = meta.nombre
		m.zonaSegura = meta.zonaSegura
		m.terreno = meta.terreno
		m.zona = meta.zona
		m.musica = meta.musica
		m.restricciones = table.clone(meta.restricciones)
		m.dinamico = {}
		for i, t in m.traslados do
			if not Mapas.abierto(t[1]) then
				m.dinamico[i] = true
			end
		end
		cache[n] = m
	end
	usar(n)
	return m
end

-- TileExit del tile: { mapa, x, y } o nil
function Mapas.salida(m: any, x: number, y: number): { number }?
	if not Grilla.dentroDelMapa(x, y) then
		return nil
	end
	return m.traslados[Grilla.indice(x, y)]
end

-- Salida a un mapa que no está: nil si no es; "borde" o "interior" (bajadas y teleports, DF13-04)
function Mapas.salidaCerrada(m: any, x: number, y: number): string?
	local s = Mapas.salida(m, x, y)
	if not s or Mapas.abierto(s[1]) then
		return nil
	end
	local enBorde = x == Grilla.MIN_X + 1 or x == Grilla.MAX_X - 1 or y == Grilla.MIN_Y or y == Grilla.MAX_Y
	return if enBorde then "borde" else "interior"
end

function Mapas.trigger(m: any, x: number, y: number): number
	if not Grilla.dentroDelMapa(x, y) then
		return 0
	end
	return m.triggers[Grilla.indice(x, y)] or 0
end

-- Char_Techo (cliente mPooChar.bas:133-151): BAJOTECHO o CASA
function Mapas.bajoTecho(m: any, x: number, y: number): boolean
	local t = Mapas.trigger(m, x, y)
	return t == Mapas.TRIGGER.BAJOTECHO or t == Mapas.TRIGGER.CASA
end

-- Distancia en mapas (docs/35 §2.1): Manhattan en la grilla del mundo, más 5 desde un mapa que no es de superficie
-- (su `grilla` es la de su ancla, GOHOME_PENALTY); nil si alguno no está en la grilla (Nemahuak, la arena)
function Mapas.distancia(a: number, b: number): number?
	local ma, mb = Indice[a], Indice[b]
	local pa, pb = ma and ma.grilla, mb and mb.grilla
	if not pa or not pb then
		return nil
	end
	return math.abs(pa[1] - pb[1]) + math.abs(pa[2] - pb[2]) + pa[3]
end

return Mapas
