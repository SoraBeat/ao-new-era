--!strict
--[[
	Intercambio entre jugadores (Fase 22, docs/41 §5): las reglas, sin tocar el juego.

	Este módulo no carga nada (ni servicios ni otros módulos): recibe copias de los inventarios y contesta qué pasaría.
	Así se puede probar entero fuera del juego contra herramientas/fase22_ref.py (`intercambio`, `sesion_*`,
	`motivo_no_ofrecer`), y el servidor (server/Comercio/IntercambioService) lo usa para decidir y después copia el
	resultado tal cual: lo que se validó es exactamente lo que se aplica.

	La oferta va por objeto y cantidad (no por lugar del inventario, que puede cambiar), y lo ofrecido no sale del
	inventario hasta el traspaso: ahí se vuelve a mirar que esté todo.
]]

local Intercambio = {}

Intercambio.MaxObjs = 10000 -- el tope de una pila (Config.Inventario.MaxObjs)
Intercambio.MaxOro = 200000000 -- el tope de la billetera (Config.Comercio.MaxOro)
Intercambio.NivelOro = 18 -- como tirar oro (Config.Comercio.NivelTirarOro)
Intercambio.Distancia = 3 -- tiles, como la tienda y el banco
Intercambio.Lugares = 10 -- objetos distintos por oferta (D22-29 A)
Intercambio.Slots = 35 -- lugares del inventario (Config.Inventario.Slots)
Intercambio.PedidoVenceSeg = 30 -- como la invitación al grupo
Intercambio.PedidoCadaSeg = 3
Intercambio.PedidoEsperaSeg = 30 -- para volver a pedirle al mismo, si rechazó o si el pedido venció
Intercambio.EntreIntercambiosSeg = 10

export type Slot = { obj: number, cant: number, equipado: boolean? }
export type Inventario = { [number]: Slot }
export type Lado = { oferta: { [number]: number }, oro: number, confirmo: boolean, acepto: boolean }
export type Sesion = { a: Lado, b: Lado }
-- Un personaje, para el traspaso: `disponible` resume lo que el juego mira en el mismo instante (conectado, sin
-- estar saliendo ni viajando a otro servidor, vivo, cerca y con su guardado activo)
export type Parte = {
	inv: Inventario, usables: number, oro: number, nivel: number,
	oferta: { [number]: number }, ofertaOro: number, prueba: boolean, disponible: boolean,
}

-- Un número entero de verdad dentro de un rango (ni decimales, ni NaN, ni infinito, ni otra cosa que un número)
function Intercambio.entero(v: any, minimo: number, maximo: number): boolean
	return typeof(v) == "number" and v == v and v == math.floor(v) and v >= minimo and v <= maximo
end
local entero = Intercambio.entero

-- Por qué un lugar del inventario no se puede ofrecer (nil = se puede). o: el objeto (ObjetosInventario).
function Intercambio.motivoNoOfrecer(o: any, slot: Slot): string?
	if o.newbie then
		return "newbie"
	elseif o.personal then
		return "personal"
	elseif o.faccion then
		return "faccion"
	elseif slot.equipado then
		return "equipado" -- incluye la mochila puesta y el barco o la montura en uso
	end
	return nil
end

-- Cuánto tiene de un objeto que se pueda ofrecer (sin lo equipado)
function Intercambio.tiene(inv: Inventario, obj: number, objetos: any): number
	local n = 0
	for i = 1, Intercambio.Slots do
		local s = inv[i]
		if s and s.obj == obj and Intercambio.motivoNoOfrecer(objetos[obj], s) == nil then
			n += s.cant
		end
	end
	return n
end

-- Saca de las pilas en orden de lugar, sin tocar lo equipado
local function sacar(inv: Inventario, obj: number, cant: number): boolean
	for i = 1, Intercambio.Slots do
		local s = inv[i]
		if cant > 0 and s and s.obj == obj and not s.equipado then
			local n = math.min(cant, s.cant)
			s.cant -= n
			cant -= n
			if s.cant == 0 then
				inv[i] = nil
			end
		end
	end
	return cant == 0
end

-- Como InventarioService.meter: una pila del mismo objeto donde entre TODO; si no, el primer lugar vacío
local function meter(inv: Inventario, usables: number, obj: number, cant: number): boolean
	for i = 1, usables do
		local s = inv[i]
		if s and s.obj == obj and s.cant + cant <= Intercambio.MaxObjs then
			s.cant += cant
			return true
		end
	end
	for i = 1, usables do
		if not inv[i] then
			inv[i] = { obj = obj, cant = math.min(cant, Intercambio.MaxObjs), equipado = false }
			return true
		end
	end
	return false
end

local function copiar(inv: Inventario): Inventario
	local r: Inventario = {}
	for i = 1, Intercambio.Slots do
		local s = inv[i]
		if s then
			r[i] = { obj = s.obj, cant = s.cant, equipado = s.equipado == true }
		end
	end
	return r
end

local function ordenados(oferta: { [number]: number }): { number }
	local r = {}
	for obj in oferta do
		table.insert(r, obj)
	end
	table.sort(r)
	return r
end

export type Resultado = { invA: Inventario, invB: Inventario, oroA: number, oroB: number }

-- El traspaso, todo o nada: ("ok", nil, resultado) con los inventarios y el oro como quedan, o (motivo, "a" | "b")
-- sin haber tocado nada. Orden: validar a los dos, sacarles a los dos y recién después darles a los dos (así lo que
-- uno entrega le hace lugar a lo que recibe).
function Intercambio.traspaso(a: Parte, b: Parte, objetos: any): (string, string?, Resultado?)
	if a == b then
		return "unoMismo", "a", nil
	end
	if a.prueba ~= b.prueba then
		return "mezcla", "a", nil
	end
	local partes: { { any } } = { { "a", a }, { "b", b } }
	for _, par in partes do
		if not (par[2] :: Parte).disponible then
			return "noDisponible", par[1], nil
		end
	end
	if next(a.oferta) == nil and next(b.oferta) == nil and a.ofertaOro == 0 and b.ofertaOro == 0 then
		return "vacio", "a", nil
	end
	for _, par in partes do
		local quien, p = par[1] :: string, par[2] :: Parte
		local distintos = 0
		for _ in p.oferta do
			distintos += 1
		end
		if distintos > Intercambio.Lugares then
			return "lugares", quien, nil
		end
		for _, obj in ordenados(p.oferta) do
			local cant = p.oferta[obj]
			-- de 1 a 10.000 por objeto: una pila (más que eso no entra en un solo lugar del que recibe)
			if not entero(cant, 1, Intercambio.MaxObjs) or not objetos[obj] then
				return "cantidad", quien, nil
			end
			if Intercambio.tiene(p.inv, obj, objetos) < cant then
				return "falta", quien, nil
			end
		end
		if not entero(p.ofertaOro, 0, Intercambio.MaxOro) then
			return "cantidad", quien, nil
		end
		if p.ofertaOro > p.oro then
			return "faltaOro", quien, nil
		end
		if p.ofertaOro > 0 and p.nivel < Intercambio.NivelOro then
			return "nivelOro", quien, nil
		end
	end
	local invA, invB = copiar(a.inv), copiar(b.inv)
	for _, obj in ordenados(a.oferta) do
		sacar(invA, obj, a.oferta[obj])
	end
	for _, obj in ordenados(b.oferta) do
		sacar(invB, obj, b.oferta[obj])
	end
	for _, obj in ordenados(a.oferta) do
		if not meter(invB, b.usables, obj, a.oferta[obj]) then
			return "sinLugar", "b", nil
		end
	end
	for _, obj in ordenados(b.oferta) do
		if not meter(invA, a.usables, obj, b.oferta[obj]) then
			return "sinLugar", "a", nil
		end
	end
	local oroA = a.oro - a.ofertaOro + b.ofertaOro
	local oroB = b.oro - b.ofertaOro + a.ofertaOro
	if oroA > Intercambio.MaxOro then
		return "topeOro", "a", nil
	end
	if oroB > Intercambio.MaxOro then
		return "topeOro", "b", nil
	end
	return "ok", nil, { invA = invA, invB = invB, oroA = oroA, oroB = oroB }
end

-- ─── La sesión de a dos: ofrecer → confirmar los dos → aceptar los dos (D22-28 A) ─────────────────────────────
-- Cualquier cambio en una oferta borra las confirmaciones y las aceptaciones de los dos: nadie acepta algo distinto
-- de lo que confirmó.
local function ladoDe(s: Sesion, quien: string): Lado
	return if quien == "b" then s.b else s.a
end

function Intercambio.sesionNueva(): Sesion
	return {
		a = { oferta = {}, oro = 0, confirmo = false, acepto = false },
		b = { oferta = {}, oro = 0, confirmo = false, acepto = false },
	}
end

Intercambio.ladoDe = ladoDe

-- Borra las cuatro marcas. Devuelve si había alguna.
function Intercambio.borrarMarcas(s: Sesion): boolean
	local habia = s.a.confirmo or s.a.acepto or s.b.confirmo or s.b.acepto
	s.a.confirmo, s.a.acepto, s.b.confirmo, s.b.acepto = false, false, false, false
	return habia
end

-- Pone (cant > 0) o saca (cant = 0) un objeto de la oferta. Devuelve nil o el motivo.
function Intercambio.ofrecer(s: Sesion, quien: string, obj: number, cant: any): string?
	local o = ladoDe(s, quien).oferta
	if cant == 0 then
		o[obj] = nil
	elseif not entero(cant, 1, Intercambio.MaxObjs) then
		return "cantidad"
	else
		local n = 0
		for _ in o do
			n += 1
		end
		if o[obj] == nil and n >= Intercambio.Lugares then
			return "lugares"
		end
		o[obj] = cant
	end
	Intercambio.borrarMarcas(s)
	return nil
end

function Intercambio.oro(s: Sesion, quien: string, oro: any): string?
	if not entero(oro, 0, Intercambio.MaxOro) then
		return "cantidad"
	end
	ladoDe(s, quien).oro = oro
	Intercambio.borrarMarcas(s)
	return nil
end

function Intercambio.vacia(s: Sesion): boolean
	return next(s.a.oferta) == nil and next(s.b.oferta) == nil and s.a.oro == 0 and s.b.oro == 0
end

function Intercambio.confirmar(s: Sesion, quien: string): string?
	if Intercambio.vacia(s) then
		return "vacio"
	end
	ladoDe(s, quien).confirmo = true
	return nil
end

-- "traspasar" cuando aceptaron los dos, nil si falta el otro, o el motivo si todavía no se puede
function Intercambio.aceptar(s: Sesion, quien: string): string?
	if not (s.a.confirmo and s.b.confirmo) then
		return "sinConfirmar"
	end
	ladoDe(s, quien).acepto = true
	return if s.a.acepto and s.b.acepto then "traspasar" else nil
end

return Intercambio
