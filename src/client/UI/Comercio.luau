--!strict
--[[
	Comercio — la ventana del comerciante (frmComerciar, VentanaComercio.jpg 462×486; docs/22 §5.6).

	- Izquierda, lo que vende el NPC (35 casillas por página); derecha, tu inventario (25). Click en una casilla: el nombre, el
	  precio total de la cantidad ("$: N"), el golpe o la defensa y qué clases lo usan (Fase 32, docs/52 §4).
	  Cambiar la cantidad recalcula.
	- Fase 32 (docs/52 §3): el comerciante puede tener más de 35 cosas (los sastres). La grilla muestra una página de
	  Config.SlotsPagina y, si hay más, aparecen las flechas "<" y ">" a los lados del nombre, que dice "1/2".
	- "Comprar" y "Vender" mandan la operación; el servidor valida todo (DF13-18 A). Sin oro suficiente el cliente
	  avisa antes: "No tienes suficiente oro.".
	- La cantidad (1 a 10000) con −, + y Máx (nuestros, para el celular). La X cierra.
	El servidor la abre ("abrir") y la cierra al alejarse, morir o cambiar de mapa ("cerrar").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Comercio)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local Precios = require(ReplicatedStorage.Shared.Comercio.Precios)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Equipo = require(ReplicatedStorage.Shared.Jugador.Equipo)
local Boton = require(script.Parent.Boton)
local Ventana = require(script.Parent.Ventana)
local GrillaItems = require(script.Parent.GrillaItems)
local Inventario = require(script.Parent.Inventario)

local Sonido = require(script.Parent.Parent.Audio.Sonido)
local Click = require(script.Parent.Click)
local Comercio = {}

-- Lo pone Main: el oro actual (de las estadísticas) y cómo avisar en la consola
Comercio.oro = function(): number
	return 0
end
Comercio.aviso = nil :: ((string) -> ())?

type Estado = {
	gui: ScreenGui,
	npc: GrillaItems.Grilla,
	yo: GrillaItems.Grilla,
	lado: string?, -- "npc" o "yo": de qué grilla es la selección
	skill: number,
	nombre: TextLabel,
	precio: TextLabel,
	stat1: TextLabel,
	usan: TextLabel, -- Fase 32: "Lo usan: ..."
	-- Fase 32: todo lo que tiene el comerciante (por casillero) y la página que se ve
	todo: { [number]: GrillaItems.Item },
	pagina: number,
	nombreNpc: string,
	titulo: TextLabel,
	flechas: { GuiObject },
	cantidad: Ventana.Campo,
	conexion: RBXScriptConnection?,
}
local v: Estado? = nil

function Comercio.abierta(): boolean
	return v ~= nil
end

local function misItems(): { [number]: GrillaItems.Item }
	local t = {}
	for slot, d in Inventario.slots() do
		if slot <= Inventario.usables() then -- Fase 16b: con la mochila, 30 o 35
			t[slot] = d
		end
	end
	return t
end

-- ─── Las páginas del comerciante (Fase 32) ───────────────────────────────────
local POR_PAGINA = Config.SlotsPagina

-- Hasta la página del último casillero ocupado (una como mínimo)
local function paginasDe(todo: { [number]: GrillaItems.Item }): number
	local ultimo = 0
	for slot in todo do
		if slot > ultimo then
			ultimo = slot
		end
	end
	return math.max(1, math.ceil(ultimo / POR_PAGINA))
end

-- La grilla del comerciante muestra la página elegida: la casilla k es el casillero (página − 1) × POR_PAGINA + k
local function pintarNpc(e: Estado)
	local total = paginasDe(e.todo)
	local pagina = math.clamp(e.pagina, 1, total)
	if pagina ~= e.pagina then
		-- La página que se miraba ya no existe (se vació lo último que tenía): lo elegido era de esa página, y si
		-- quedara marcado pasaría a señalar la misma casilla de otra. Se suelta.
		e.pagina = pagina
		e.npc:seleccionar(0)
		if e.lado == "npc" then
			e.lado = nil
		end
	end
	local base = (e.pagina - 1) * POR_PAGINA
	local items = {}
	for k = 1, POR_PAGINA do
		items[k] = e.todo[base + k]
	end
	e.npc:set(items)
	for _, f in e.flechas do
		f.Visible = total > 1
	end
	e.titulo.Text = if total > 1 then `{e.nombreNpc}  {e.pagina}/{total}` else e.nombreNpc
	-- Sin flechas el nombre usa todo el ancho de la grilla; con flechas, lo que queda entre las dos
	e.titulo.Position = if total > 1 then UDim2.fromOffset(66, 108) else UDim2.fromOffset(40, 108)
	e.titulo.Size = if total > 1 then UDim2.fromOffset(108, 18) else UDim2.fromOffset(160, 18)
end

-- El casillero del comerciante que está elegido (0 si no hay) y lo que tiene
local function elegidoNpc(e: Estado): (number, GrillaItems.Item?)
	local casilla, it = e.npc:seleccionado()
	if casilla == 0 or not it then
		return 0, nil
	end
	return (e.pagina - 1) * POR_PAGINA + casilla, it
end

-- El nombre, el precio de la cantidad elegida, el golpe o la defensa (frmComerciar: lblInfo) y quién lo usa
local function mostrar()
	local e = v
	if not e then
		return
	end
	local grilla = if e.lado == "npc" then e.npc elseif e.lado == "yo" then e.yo else nil
	local item: any = nil
	if grilla then
		item = select(2, grilla:seleccionado())
	end
	local o = item and Objetos[item.obj]
	if not o then
		e.nombre.Text, e.precio.Text, e.stat1.Text, e.usan.Text = "", "", "", ""
		return
	end
	e.nombre.Text = o.nombre
	local cant = e.cantidad.valor()
	local precio = if e.lado == "npc" then Precios.compraDe(o, e.skill, if o.personal then 1 else cant) else Precios.venta(o.valor, math.min(cant, (item :: any).cant), o.newbie == true, o.crudo == true)
	e.precio.Text = `$: {precio}`
	-- Fase 32 (docs/52 §4): "Golpe 6-17" o "Defensa 35-40" en un renglón, y abajo qué clases lo usan.
	-- Fase 39 (docs/59 §4): y en otro renglón, el skill que pide para equiparse (la frase se achica si no entra)
	local dato, usan, pide = Equipo.ficha(o)
	e.stat1.Text = dato
	e.usan.Text = if pide ~= "" then (if usan ~= "" then usan .. "\n" else "") .. pide .. "." else usan
end

function Comercio.cerrar(avisarServidor: boolean?)
	local e = v
	if not e then
		return
	end
	v = nil
	if e.conexion then
		e.conexion:Disconnect()
	end
	e.gui:Destroy()
	if avisarServidor then
		Remotes.evento("CerrarComercio"):FireServer()
	end
end

local function abrir(d: any)
	Comercio.cerrar(false)
	local gui, fondo = Ventana.crear("Comercio", UiAssets.comercio, 462, 486)
	local marcoNpc = Instance.new("Frame")
	marcoNpc.Name = "Npc"
	marcoNpc.BackgroundTransparency = 1
	marcoNpc.Position = UDim2.fromOffset(40, 131)
	marcoNpc.Size = UDim2.fromOffset(160, 256)
	marcoNpc.Parent = fondo
	local marcoYo = marcoNpc:Clone()
	marcoYo.Name = "Yo"
	marcoYo.Position = UDim2.fromOffset(263, 131)
	marcoYo.Parent = fondo
	local e: Estado = {
		gui = gui,
		npc = GrillaItems.nueva(marcoNpc, POR_PAGINA, 5, 32),
		yo = GrillaItems.nueva(marcoYo, ConfigInv.Slots, 5, 32),
		lado = nil,
		skill = d.skill or 0,
		-- La placa de arriba (144..324 × 41..106): nombre; precio y golpe o defensa; y dos renglones para las clases
		nombre = Ventana.label(fondo, "", 144, 41, 180, 18),
		precio = Ventana.label(fondo, "", 144, 59, 84, 16),
		stat1 = Ventana.label(fondo, "", 228, 59, 96, 16, { Font = Enum.Font.Arial, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right }),
		usan = Ventana.label(fondo, "", 144, 76, 180, 30, {
			Font = Enum.Font.Arial,
			TextSize = 11,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Boton.ColorTexto,
		}),
		todo = {},
		pagina = 1,
		nombreNpc = d.nombre or "",
		titulo = Ventana.label(fondo, d.nombre or "", 64, 108, 112, 18, { TextColor3 = Boton.ColorTexto, TextXAlignment = Enum.TextXAlignment.Center }),
		flechas = {},
		cantidad = nil :: any,
	}
	v = e
	-- Los textos largos se achican en vez de cortarse: el nombre del objeto ("Vestido de Gala Turquesa (E/G-M)"),
	-- el del comerciante con la página ("Sir Gerard [Mercader]  1/2") y la frase de las clases cuando no entra en
	-- sus dos renglones
	for _, par in { { l = e.nombre, max = 13 }, { l = e.titulo, max = 13 }, { l = e.usan, max = 11 } } do
		par.l.TextScaled = true
		local tope = Instance.new("UITextSizeConstraint")
		tope.MaxTextSize = par.max
		tope.MinTextSize = 8
		tope.Parent = par.l
	end
	Ventana.label(fondo, "Tu inventario", 263, 108, 160, 18, { TextColor3 = Boton.ColorTexto, TextXAlignment = Enum.TextXAlignment.Center })
	for k, s in d.slots or {} do
		e.todo[tonumber(k) :: number] = s
	end
	-- Las flechas de página, a los lados del nombre (solo se ven si el comerciante pasa de una página)
	for _, f in { { texto = "<", x = 36, paso = -1 }, { texto = ">", x = 176, paso = 1 } } do
		local b = Boton.nuevo(fondo, f.texto, UDim2.fromOffset(f.x, 105), UDim2.fromOffset(28, 23), { tamTexto = 13 })
		b.Name = if f.paso < 0 then "PaginaAnterior" else "PaginaSiguiente"
		b.ZIndex = 5
		b.Visible = false
		local paso = f.paso
		Click.activado(b, function()
			local total = paginasDe(e.todo)
			local nueva = ((e.pagina - 1 + paso) % total) + 1 -- da la vuelta: de la última a la primera
			if nueva ~= e.pagina then
				e.pagina = nueva
				e.npc:seleccionar(0)
				if e.lado == "npc" then
					e.lado = nil
				end
				pintarNpc(e)
				mostrar()
			end
		end)
		table.insert(e.flechas, b)
	end
	pintarNpc(e)
	for slot, c in e.yo.celdas do
		c.boton.Visible = slot <= Inventario.usables()
	end
	e.yo:set(misItems())
	e.cantidad = Ventana.cantidad(fondo, 210, 438, 42, 19, Config.MaxCantidad, function(): number
		if e.lado == "npc" then
			local _, it = elegidoNpc(e)
			local o = it and Objetos[it.obj]
			if not it or not o then
				return 1
			end
			-- lo más que alcanza con el oro, sin pasar del stock (búsqueda binaria)
			local lo, hi = 1, math.min(it.cant, Config.MaxCantidad)
			while lo < hi do
				local m = (lo + hi + 1) // 2
				if Precios.compraDe(o, e.skill, m) <= Comercio.oro() then
					lo = m
				else
					hi = m - 1
				end
			end
			return lo
		elseif e.lado == "yo" then
			local _, it = e.yo:seleccionado()
			return if it then it.cant else 1
		end
		return 1
	end)
	e.cantidad.alCambiar = mostrar

	e.npc.alSeleccionar = function()
		e.lado = "npc"
		e.yo:seleccionar(0)
		mostrar()
	end
	e.yo.alSeleccionar = function()
		e.lado = "yo"
		e.npc:seleccionar(0)
		mostrar()
	end

	local comprar = Boton.nuevo(fondo, "Comprar", UDim2.fromOffset(32, 400), UDim2.fromOffset(177, 33), { tamTexto = 16 })
	comprar.Name = "Comprar"
	Click.activado(comprar, function()
		local slot, it = elegidoNpc(e) -- el casillero del comerciante, no la casilla de la página
		local o = it and Objetos[it.obj]
		if slot == 0 or not it or not o then
			return
		end
		local cant = e.cantidad.valor()
		if Precios.compraDe(o, e.skill, math.min(cant, it.cant)) > Comercio.oro() then
			local f = Comercio.aviso
			if f then
				f(Config.MsgSinOroCliente)
			end
			return
		end
		Remotes.evento("Comprar"):FireServer(slot, cant)
	end)
	local vender = Boton.nuevo(fondo, "Vender", UDim2.fromOffset(256, 400), UDim2.fromOffset(177, 33), { tamTexto = 16 })
	vender.Name = "Vender"
	Click.activado(vender, function()
		local slot, it = e.yo:seleccionado()
		if slot == 0 or not it then
			return
		end
		Remotes.evento("Vender"):FireServer(slot, e.cantidad.valor())
	end)
	Ventana.cerrar(fondo, 405, 24, 30, 30, function()
		Comercio.cerrar(true)
	end)
end

function Comercio.iniciar()
	-- Mi inventario cambia (compré, vendí): se redibuja y se recalcula el precio
	Inventario.alCambiarInventario(function()
		local e = v
		if e then
			e.yo:set(misItems())
			mostrar()
		end
	end)
	Remotes.evento("Comercio").OnClientEvent:Connect(function(accion: string, a: any, b: any)
		if accion == "abrir" then
			Sonido.saludo("comerciante") -- cli/Red/Protocol.bas:1704
			abrir(a)
		elseif accion == "cerrar" then
			Comercio.cerrar(false)
		elseif accion == "slot" then
			local e = v
			if e then
				e.todo[a] = b
				pintarNpc(e)
				mostrar()
			end
		elseif accion == "skill" then
			local e = v
			if e then
				e.skill = a
				mostrar()
			end
		end
	end)
end

return Comercio
