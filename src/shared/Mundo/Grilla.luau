--!strict
--[[
	Grilla — reglas de coordenadas de AO, compartidas por servidor y cliente.

	Mapas de 100×100 tiles, índices 1..100. (1,1) = esquina superior izquierda; x crece al este
	e y al sur. Área jugable: x ∈ [12, 89], y ∈ [10, 91]; el resto es borde decorativo para que la
	cámara tenga qué dibujar (docs/06-mapas.md §2).

	En el mundo de Roblox: el tile (x, y) ocupa el cuadrado de 4×4 studs que empieza en
	((x - 1) * 4, 0, (y - 1) * 4). Norte = -Z, este = +X.
]]

local Grilla = {}

Grilla.ANCHO = 100
Grilla.ALTO = 100
Grilla.TILE_PX = 32
Grilla.TILE_STUDS = 4
Grilla.MIN_X, Grilla.MAX_X = 12, 89
Grilla.MIN_Y, Grilla.MAX_Y = 10, 91

-- Headings de AO (Declares.bas:233-239)
Grilla.NORTE, Grilla.ESTE, Grilla.SUR, Grilla.OESTE = 1, 2, 3, 4
Grilla.DELTA = {
	[1] = { 0, -1 },
	[2] = { 1, 0 },
	[3] = { 0, 1 },
	[4] = { -1, 0 },
}

function Grilla.indice(x: number, y: number): number
	return (y - 1) * Grilla.ANCHO + x
end

function Grilla.dentroDelMapa(x: number, y: number): boolean
	return x >= 1 and x <= Grilla.ANCHO and y >= 1 and y <= Grilla.ALTO
end

function Grilla.dentroDelAreaJugable(x: number, y: number): boolean
	return x >= Grilla.MIN_X and x <= Grilla.MAX_X and y >= Grilla.MIN_Y and y <= Grilla.MAX_Y
end

-- El Grh de la capa 1 (el piso) del tile i: la capa 1 es un buffer de u16 (MapaBinario, docs/35 §1.2)
function Grilla.piso(mapa: any, i: number): number
	return buffer.readu16(mapa.capa1, (i - 1) * 2)
end

-- HayAgua (General.bas:142-167 del server): se deduce del Grh de la capa 1, con capa 2 vacía
function Grilla.esAgua(mapa: any, x: number, y: number): boolean
	local i = Grilla.indice(x, y)
	if mapa.capa2[i] then
		return false
	end
	local g = Grilla.piso(mapa, i)
	return (g >= 1505 and g <= 1520)
		or (g >= 12439 and g <= 12454)
		or (g >= 5665 and g <= 5680)
		or (g >= 13547 and g <= 13562)
end

-- Fase 13 (docs/22 §2.3): `mapa.dinamico[i]` (true/false) pisa el bloqueo del .map: puertas abiertas o cerradas y
-- salidas a mapas que todavía no están (DF13-04). Cada lado (servidor y cliente) lo arma sobre su copia del módulo.
function Grilla.estaBloqueado(mapa: any, x: number, y: number): boolean
	local i = Grilla.indice(x, y)
	local d = mapa.dinamico
	if d then
		local v = d[i]
		if v ~= nil then
			return v
		end
	end
	-- Los bloqueos del .map, en bits (MapaBinario): el bit (i - 1) % 8 del byte (i - 1) // 8
	return bit32.btest(buffer.readu8(mapa.bloqueos, (i - 1) // 8), bit32.lshift(1, (i - 1) % 8))
end

-- Esquina noroeste del tile en el mundo (a la altura del piso)
function Grilla.esquinaMundo(x: number, y: number): Vector3
	return Vector3.new((x - 1) * Grilla.TILE_STUDS, 0, (y - 1) * Grilla.TILE_STUDS)
end

-- Centro del tile en el mundo. Acepta coordenadas fraccionarias (personajes en movimiento).
function Grilla.centroMundo(x: number, y: number): Vector3
	return Vector3.new((x - 0.5) * Grilla.TILE_STUDS, 0, (y - 0.5) * Grilla.TILE_STUDS)
end

return Grilla
