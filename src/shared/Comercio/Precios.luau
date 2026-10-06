--!strict
--[[
	Precios — fórmulas del comercio y del oro al morir (docs/22 §5.4 y §7.3), sin dependencias para poder probarlas
	fuera de Roblox contra muestras/fase13_vectores.json (herramientas/fase13_ref.py).

	Descuento    = 1 + Comerciar / 100 (Single)                  Comercio.bas:257
	PrecioCompra = CLng(Valor / Descuento × Cantidad + 0,5)      Comercio.bas:94 (CLng: redondeo al par, DF13-13 A)
	PrecioVenta  = Fix(Single(Valor / 3) × Cantidad), 0 newbie   Comercio.bas:166, :338-347
	               los crudos (madera, peces, minerales): Int(Valor × Cantidad / 30)   DR16-18 A (docs/31 §2.3)
]]

local Precios = {}

local function f32(x: number): number
	return (string.unpack("<f", string.pack("<f", x)))
end

-- CLng / CInt de VB6: redondeo bancario (x.5 → par)
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

local function fix(x: number): number
	return if x >= 0 then math.floor(x) else -math.floor(-x)
end

function Precios.descuento(skill: number): number
	return f32(1 + skill / 100)
end

function Precios.compra(valor: number, skill: number, cant: number): number
	return vbRound(valor / Precios.descuento(skill) * cant + 0.5)
end

-- Fase 21 (docs/40 §9, D21-34 A): los objetos de precio fijo (la Gema de Fundación) valen lo que dice el objeto,
-- sin el descuento del skill Comerciar
function Precios.compraDe(o: { valor: number, precioFijo: boolean? }, skill: number, cant: number): number
	if o.precioFijo then
		return o.valor * cant
	end
	return Precios.compra(o.valor, skill, cant)
end

-- crudo (Fase 16a, DR16-18 A, docs/31 §2.3): madera, peces y minerales se venden a un décimo, Valor / 30 sobre el
-- total y hacia abajo (el ×10 de los oficios no infla el oro)
function Precios.venta(valor: number, cant: number, newbie: boolean?, crudo: boolean?): number
	if newbie then
		return 0
	end
	if crudo then
		return math.floor(valor * cant / Precios.DivisorCrudo)
	end
	return fix(f32(f32(valor / 3) * cant))
end
Precios.DivisorCrudo = 30

-- TirarOro (InvUsuario.bas:269-396): parte `cant` en pilas de hasta 10000 (500000 como mucho; lo que pasa se
-- destruye si cayó al menos una pila). `lugar(i, cantidad)` dice si la pila i encontró lugar (y la pone). Devuelve las pilas que caen y
-- el oro que queda.
function Precios.pilasOro(cant: number, gld: number, lugar: (number, number) -> boolean, maxPila: number?): ({ number }, number)
	local tope = maxPila or 10000
	if not (cant > 0 and cant <= gld) then
		return {}, gld
	end
	local tenia = gld
	local extra = 0
	if cant > 500000 then
		extra, cant = cant - 500000, 500000
	end
	local pilas = {}
	local vueltas = 0
	while cant > 0 do
		local a = if cant > tope and gld > tope then tope else cant
		cant -= a
		if lugar(#pilas + 1, a) then
			table.insert(pilas, a)
			gld -= a
		end
		vueltas += 1
		if vueltas > 100 then
			break
		end
	end
	if tenia == gld then
		extra = 0
	end
	return pilas, gld - extra
end

-- Billetera (docs/24 DA-11, decidido por el autor): al morir no se cae el oro si sos de nivel 17 o menos (newbie
-- incluido), o si sos nivel 18 o más y llevás 100.000 o más. Reemplaza DF13-21 A (el original protegía
-- nivel × 10.000).
Precios.NivelBilletera = 18
Precios.OroBilletera = 100000

function Precios.tieneBilletera(gld: number, elv: number, newbie: boolean): boolean
	return newbie or elv < Precios.NivelBilletera or gld >= Precios.OroBilletera
end

-- Cuánto oro cae al morir (TirarTodo, Modulo_UsUaRiOs.bas:1772-1797): nada en un mapa seguro o con billetera; si
-- no, todo (en pilas, con el tope de 500.000 de pilasOro)
function Precios.oroAlMorir(gld: number, elv: number, newbie: boolean, mapaSeguro: boolean): number
	if mapaSeguro or Precios.tieneBilletera(gld, elv, newbie) then
		return 0
	end
	return math.max(0, gld)
end

return Precios
