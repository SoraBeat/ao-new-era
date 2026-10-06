--!strict
--!native
--[[
	MapaBinario — decodifica los mapas en formato AOM1 (Fase 17a, docs/35 §1.2, DW17-01 A).

	Cada `Generado/Mapas/MapaN` es `{ v = 1, n = <tamaño crudo>, d = "<base64>" }`: el AOM1 comprimido con LZ4 en
	bloque (sin tamaño adelante) y en base64. Lo genera `herramientas/mapas.py` con el mismo código que verifica
	`herramientas/fase17a_ref.py`. El AOM1, todo little-endian:

		"AOM1" · capa1 u16 × 10000 · capas 2, 3 y 4: u16 n + n × (u16 i, u16 grh) · bloqueos: bitset de 1250 B
		· triggers: u16 n + (u16 i, i16 t) · traslados: u16 n + (u16 i, u16 mapa, u8 x, u8 y)
		· npcs: u16 n + (u16 id, u8 x, u8 y) · objetos: u16 n + (u16 id, u16 cant, u8 x, u8 y, u16 grh)

	Los índices i van de 1 a 10000 (Grilla.indice). La capa 1 y los bloqueos quedan como `buffer` (se leen con
	`Grilla.piso` y `Grilla.estaBloqueado`); el resto, como las tablas de siempre.
]]

local MapaBinario = {}

export type Datos = {
	capa1: buffer, -- u16 por tile, en (i - 1) * 2
	capa2: { [number]: number },
	capa3: { [number]: number },
	capa4: { [number]: number },
	bloqueos: buffer, -- bit (i - 1) % 8 del byte (i - 1) // 8
	triggers: { [number]: number },
	traslados: { [number]: { number } }, -- { mapa, x, y }
	npcs: { { number } }, -- { id, x, y }
	objetos: { { number } }, -- { id, cantidad, x, y, grh }
}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local inversa = buffer.create(256)
for i = 1, 64 do
	buffer.writeu8(inversa, string.byte(B64, i), i - 1)
end

function MapaBinario.base64(s: string): buffer
	local n = #s
	local pad = 0
	if string.byte(s, n) == 61 then
		pad += 1
	end
	if string.byte(s, n - 1) == 61 then
		pad += 1
	end
	local out = buffer.create(n // 4 * 3 - pad)
	local src = buffer.fromstring(s)
	local largo = buffer.len(out)
	local o = 0
	for i = 0, n - 1, 4 do
		local v = bit32.bor(
			bit32.lshift(buffer.readu8(inversa, buffer.readu8(src, i)), 18),
			bit32.lshift(buffer.readu8(inversa, buffer.readu8(src, i + 1)), 12),
			bit32.lshift(buffer.readu8(inversa, buffer.readu8(src, i + 2)), 6),
			buffer.readu8(inversa, buffer.readu8(src, i + 3))
		)
		if o + 2 < largo then
			buffer.writeu8(out, o, bit32.rshift(v, 16))
			buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255))
			buffer.writeu8(out, o + 2, bit32.band(v, 255))
		else
			if o < largo then
				buffer.writeu8(out, o, bit32.rshift(v, 16))
			end
			if o + 1 < largo then
				buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255))
			end
		end
		o += 3
	end
	return out
end

-- LZ4 en bloque (el formato de lz4.block sin tamaño adelante): secuencias de literales y coincidencias
function MapaBinario.lz4(src: buffer, n: number): buffer
	local dst = buffer.create(n)
	local ip, op, ilen = 0, 0, buffer.len(src)
	while ip < ilen do
		local tok = buffer.readu8(src, ip)
		ip += 1
		local lit = bit32.rshift(tok, 4)
		if lit == 15 then
			repeat
				local b = buffer.readu8(src, ip)
				ip += 1
				lit += b
			until b ~= 255
		end
		if lit > 0 then
			buffer.copy(dst, op, src, ip, lit)
			ip += lit
			op += lit
		end
		if ip >= ilen then
			break
		end
		local off = buffer.readu16(src, ip)
		ip += 2
		local ml = bit32.band(tok, 15)
		if ml == 15 then
			repeat
				local b = buffer.readu8(src, ip)
				ip += 1
				ml += b
			until b ~= 255
		end
		ml += 4
		local desde = op - off
		if off >= ml then
			buffer.copy(dst, op, dst, desde, ml)
		else -- se superpone: byte a byte
			for k = 0, ml - 1 do
				buffer.writeu8(dst, op + k, buffer.readu8(dst, desde + k))
			end
		end
		op += ml
	end
	assert(op == n, "LZ4: tamaño distinto del esperado")
	return dst
end

function MapaBinario.decodificar(b: buffer): Datos
	assert(buffer.readstring(b, 0, 4) == "AOM1", "no es un mapa AOM1")
	local capa1 = buffer.create(20000)
	buffer.copy(capa1, 0, b, 4, 20000)
	local p = 20004
	local capas = {}
	for c = 1, 3 do
		local t = {}
		local k = buffer.readu16(b, p)
		p += 2
		for _ = 1, k do
			t[buffer.readu16(b, p)] = buffer.readu16(b, p + 2)
			p += 4
		end
		capas[c] = t
	end
	local bloqueos = buffer.create(1250)
	buffer.copy(bloqueos, 0, b, p, 1250)
	p += 1250
	local triggers = {}
	local k = buffer.readu16(b, p)
	p += 2
	for _ = 1, k do
		triggers[buffer.readu16(b, p)] = buffer.readi16(b, p + 2)
		p += 4
	end
	local traslados = {}
	k = buffer.readu16(b, p)
	p += 2
	for _ = 1, k do
		traslados[buffer.readu16(b, p)] = { buffer.readu16(b, p + 2), buffer.readu8(b, p + 4), buffer.readu8(b, p + 5) }
		p += 6
	end
	local npcs = {}
	k = buffer.readu16(b, p)
	p += 2
	for j = 1, k do
		npcs[j] = { buffer.readu16(b, p), buffer.readu8(b, p + 2), buffer.readu8(b, p + 3) }
		p += 4
	end
	local objetos = {}
	k = buffer.readu16(b, p)
	p += 2
	for j = 1, k do
		objetos[j] = {
			buffer.readu16(b, p),
			buffer.readu16(b, p + 2),
			buffer.readu8(b, p + 4),
			buffer.readu8(b, p + 5),
			buffer.readu16(b, p + 6),
		}
		p += 8
	end
	assert(p == buffer.len(b), "AOM1: sobran o faltan bytes")
	return {
		capa1 = capa1,
		capa2 = capas[1],
		capa3 = capas[2],
		capa4 = capas[3],
		bloqueos = bloqueos,
		triggers = triggers,
		traslados = traslados,
		npcs = npcs,
		objetos = objetos,
	}
end

-- El módulo generado ({ v, n, d }) a los datos del mapa
function MapaBinario.leer(modulo: { v: number, n: number, d: string }): Datos
	assert(modulo.v == 1, `versión de mapa desconocida: {modulo.v}`)
	return MapaBinario.decodificar(MapaBinario.lz4(MapaBinario.base64(modulo.d), modulo.n))
end

return MapaBinario
