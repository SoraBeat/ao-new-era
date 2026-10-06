--!strict
--[[
	Intercambio — la ventana del intercambio entre jugadores (Fase 22, docs/41 §5; frmComerciarUsu del original, sobre
	VentanaComercioUsuario.jpg, 665×592) y la caja del pedido.

	- Arriba a la izquierda, mi inventario; arriba a la derecha, lo que ofrezco; abajo a la derecha, lo que ofrece el
	  otro. Las dos ofertas son LISTAS con el nombre y la cantidad escritos (D22-35): hay objetos de valor muy distinto
	  con el mismo dibujo, y en el celular no hay mouse para pasarles por encima.
	- Se elige algo del inventario, se pone la cantidad y ► lo agrega; se elige algo de la oferta propia y ◄ lo quita.
	  El oro se escribe en su casilla.
	- Confirmar (los dos) y después Aceptar (los dos). Cualquier cambio borra las marcas: lo decide el servidor
	  (server/Comercio/IntercambioService) y acá solo se dibuja el estado que manda.
	- Abajo a la izquierda, los avisos y el chat. El chat le susurra al otro por el canal de los susurros (el filtrado
	  de Roblox); si Roblox no permite el chat privado entre los dos, la caja no aparece (D22-34).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Comercio.Intercambio)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local ConfigChat = require(ReplicatedStorage.Shared.Config.Chat)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Grh = require(script.Parent.Parent.Render.Grh)
local Boton = require(script.Parent.Boton)
local Chat = require(script.Parent.Chat)
local GrillaItems = require(script.Parent.GrillaItems)
local Inventario = require(script.Parent.Inventario)
local Ventana = require(script.Parent.Ventana)
local Click = require(script.Parent.Click)

local Intercambio = {}

-- Lo pone Main: el oro de la billetera
Intercambio.oro = function(): number
	return 0
end

type Lado = { oferta: { { obj: number, cant: number } }, oro: number, confirmo: boolean, acepto: boolean }
type Fila = { boton: TextButton, icono: ImageLabel, texto: TextLabel }
type Estado = {
	gui: ScreenGui,
	con: string,
	yo: Lado,
	otro: Lado,
	grilla: GrillaItems.Grilla,
	filasYo: { Fila },
	filasOtro: { Fila },
	selOferta: number, -- la fila elegida de mi oferta (0 = ninguna)
	nombre: TextLabel,
	cantidad: Ventana.Campo,
	miOro: TextLabel,
	oroYo: TextBox,
	oroOtro: TextLabel,
	marcaYo: TextLabel,
	marcaOtro: TextLabel,
	confirmar: ImageButton,
	aceptar: ImageButton,
	consola: ScrollingFrame,
	lineas: number,
	canal: string?, -- el canal del susurro con el otro, si Roblox lo permite
	conexion: RBXScriptConnection?,
}
local v: Estado? = nil

local COLOR_AVISO = Color3.fromRGB(252, 203, 130)
local COLOR_SI = Color3.fromRGB(120, 230, 120)
local COLOR_NO = Color3.fromRGB(200, 200, 200)
local COLOR_ELEGIDA = Color3.fromRGB(120, 20, 20)
local FILA = 19

function Intercambio.abierta(): boolean
	return v ~= nil
end

local function accion(...: any)
	Remotes.evento("IntercambioAccion"):FireServer(...)
end

local function miles(n: number): string
	local s = string.reverse(tostring(math.floor(n)))
	s = string.gsub(s, "(%d%d%d)", "%1.")
	return (string.gsub(string.reverse(s), "^%.", ""))
end

-- ─── La consola de la ventana ────────────────────────────────────────────────
local function linea(texto: string, color: Color3)
	local e = v
	if not e then
		return
	end
	e.lineas += 1
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -6, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = Enum.Font.Arial
	l.TextSize = 12
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = texto
	l.LayoutOrder = e.lineas
	l.ZIndex = 4
	l.Parent = e.consola
	if e.lineas > 60 then -- no crece sin fin
		for _, c in e.consola:GetChildren() do
			if c:IsA("TextLabel") and c.LayoutOrder <= e.lineas - 60 then
				c:Destroy()
			end
		end
	end
	task.defer(function()
		if v == e then
			e.consola.CanvasPosition = Vector2.new(0, 1e6)
		end
	end)
end

-- Un susurro que llegó por el canal de los dos (lo llama Main): lo escrito, en la consola de la ventana
function Intercambio.chat(canal: string, nombre: string, texto: string)
	local e = v
	if e and e.canal == canal then
		linea(`{nombre}> {texto}`, Color3.new(1, 1, 1))
	end
end

-- ─── El dibujo ───────────────────────────────────────────────────────────────
local function misItems(): { [number]: GrillaItems.Item }
	local t = {}
	for slot, d in Inventario.slots() do
		if slot <= Inventario.usables() then
			t[slot] = d
		end
	end
	return t
end

local function pintarFilas(filas: { Fila }, lado: Lado, elegida: number)
	for i, f in filas do
		local it = lado.oferta[i]
		local o = it and Objetos[it.obj]
		f.boton.Visible = o ~= nil
		if it and o then
			Grh.aplicar(f.icono, o.grh)
			f.icono.Size = UDim2.fromOffset(FILA - 1, FILA - 1)
			f.texto.Text = `{it.cant} {o.nombre}`
			f.boton.BackgroundTransparency = if i == elegida then 0 else 1
		end
	end
end

local function marca(l: TextLabel, quien: string, lado: Lado)
	l.Text = `{quien}: {if lado.acepto then "aceptó" elseif lado.confirmo then "confirmó" else "sin confirmar"}`
	l.TextColor3 = if lado.confirmo then COLOR_SI else COLOR_NO
end

local function pintar()
	local e = v
	if not e then
		return
	end
	if e.selOferta > #e.yo.oferta then
		e.selOferta = 0
	end
	pintarFilas(e.filasYo, e.yo, e.selOferta)
	pintarFilas(e.filasOtro, e.otro, 0)
	e.miOro.Text = miles(Intercambio.oro())
	if not e.oroYo:IsFocused() then
		e.oroYo.Text = tostring(e.yo.oro)
	end
	e.oroOtro.Text = miles(e.otro.oro)
	marca(e.marcaYo, "Vos", e.yo)
	marca(e.marcaOtro, e.con, e.otro)
	Boton.texto(e.confirmar, if e.yo.confirmo then "Confirmado" else "Confirmar")
	Boton.texto(e.aceptar, if e.yo.acepto then "Aceptado" else "Aceptar")
	-- Aceptar se prende recién con las dos confirmaciones (igual, el que decide es el servidor)
	local listo = e.yo.confirmo and e.otro.confirmo
	e.aceptar.ImageTransparency = if listo then 0 else 0.5
	for _, t in e.aceptar:GetChildren() do
		if t:IsA("TextLabel") then
			t.TextTransparency = if listo then 0 else 0.5
		end
	end
end

local function mostrarNombre()
	local e = v
	if not e then
		return
	end
	local _, it = e.grilla:seleccionado()
	local o = it and Objetos[it.obj]
	e.nombre.Text = if o then o.nombre else ""
end

-- Cuánto ofrezco ya de un objeto
local function ofrecido(e: Estado, obj: number): number
	for _, it in e.yo.oferta do
		if it.obj == obj then
			return it.cant
		end
	end
	return 0
end

-- Cuánto tengo de un objeto sin contar lo equipado (lo que se puede ofrecer)
local function tengo(obj: number): number
	local n = 0
	for slot, d in Inventario.slots() do
		if slot <= Inventario.usables() and d.obj == obj and not d.equipado then
			n += d.cant
		end
	end
	return n
end

function Intercambio.cerrar(avisarServidor: boolean?)
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
		accion("cancelar")
	end
end

local function filas(parent: Instance, x: number, y: number, elegir: ((number) -> ())?): { Fila }
	local lista: { Fila } = {}
	for i = 1, Cfg.Lugares do
		local b = Instance.new("TextButton")
		b.Name = `Fila{i}`
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = COLOR_ELEGIDA
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.Position = UDim2.fromOffset(x, y + (i - 1) * FILA)
		b.Size = UDim2.fromOffset(160, FILA)
		b.Visible = false
		b.ZIndex = 3
		b:SetAttribute("SinClick", true)
		b.Parent = parent
		local icono = Instance.new("ImageLabel")
		icono.BackgroundTransparency = 1
		icono.ResampleMode = Enum.ResamplerMode.Pixelated
		icono.Size = UDim2.fromOffset(FILA - 1, FILA - 1)
		icono.ZIndex = 4
		icono.Parent = b
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(FILA + 2, 0)
		t.Size = UDim2.new(1, -(FILA + 4), 1, 0)
		t.Font = Enum.Font.Arial
		t.TextSize = 11
		t.TextScaled = true -- los nombres largos se achican y pasan a dos renglones: se leen enteros
		t.TextWrapped = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.ZIndex = 4
		t.Parent = b
		local tope = Instance.new("UITextSizeConstraint")
		tope.MaxTextSize = 11
		tope.MinTextSize = 7
		tope.Parent = t
		if elegir then
			Click.activado(b, function()
				elegir(i)
			end)
		end
		lista[i] = { boton = b, icono = icono, texto = t }
	end
	return lista
end

-- Un botón invisible sobre una flecha dibujada en el fondo (más grande que el dibujo, para el dedo)
local function flecha(parent: Instance, nombre: string, x: number, y: number, f: () -> ())
	local b = Ventana.cerrar(parent, x, y, 60, 26, f)
	b.Name = nombre
end

local function abrir(d: any)
	Intercambio.cerrar(false)
	local gui, fondo = Ventana.crear("Intercambio", UiAssets.intercambio, 665, 592)
	local rotulo = { TextColor3 = Boton.ColorTexto, TextSize = 14 }
	local chico = { Font = Enum.Font.Arial, TextSize = 11, TextColor3 = Boton.ColorTexto, TextXAlignment = Enum.TextXAlignment.Center }
	Ventana.label(fondo, "Tu inventario", 40, 28, 164, 18, rotulo)
	Ventana.label(fondo, "Tu oferta", 464, 28, 160, 18, rotulo)
	Ventana.label(fondo, `La oferta de {d.con}`, 464, 308, 180, 18, rotulo)
	Ventana.label(fondo, "Avisos y chat", 40, 378, 200, 18, rotulo)
	Ventana.label(fondo, "Tenés", 222, 38, 80, 14, chico)
	Ventana.label(fondo, "Ofrecés", 366, 38, 80, 14, chico)
	Ventana.label(fondo, "Ofrece", 366, 312, 80, 14, chico)
	Ventana.label(fondo, "Agregar", 300, 106, 69, 14, chico)
	Ventana.label(fondo, "Quitar", 300, 204, 69, 14, chico)

	-- Mi inventario: hasta 35 lugares en el recuadro de 160×192 del original (6 columnas de 26 px) y, debajo, el
	-- nombre de lo elegido
	local marco = Instance.new("Frame")
	marco.Name = "Yo"
	marco.BackgroundTransparency = 1
	marco.Position = UDim2.fromOffset(44, 64)
	marco.Size = UDim2.fromOffset(156, 156)
	marco.Parent = fondo
	local grilla = GrillaItems.nueva(marco, ConfigInv.Slots, 6, 26, 9)
	for slot, c in grilla.celdas do
		c.boton.Visible = slot <= Inventario.usables()
	end

	local oroCaja = { Font = Enum.Font.Arial, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(255, 220, 90) }
	local oroYo = Instance.new("TextBox")
	oroYo.Name = "OroYo"
	oroYo.BackgroundTransparency = 1
	oroYo.Position = UDim2.fromOffset(374, 62)
	oroYo.Size = UDim2.fromOffset(64, 32)
	oroYo.Font = Enum.Font.Arial
	oroYo.TextSize = 13
	oroYo.TextColor3 = Color3.fromRGB(255, 220, 90)
	oroYo.ClearTextOnFocus = false
	oroYo.Text = "0"
	oroYo.ZIndex = 4
	oroYo.Parent = fondo

	local consola = Instance.new("ScrollingFrame")
	consola.Name = "Consola"
	consola.BackgroundTransparency = 1
	consola.BorderSizePixel = 0
	consola.Position = UDim2.fromOffset(38, 406)
	consola.Size = UDim2.fromOffset(398, 100)
	consola.CanvasSize = UDim2.new()
	consola.AutomaticCanvasSize = Enum.AutomaticSize.Y
	consola.ScrollBarThickness = 5
	consola.ScrollingDirection = Enum.ScrollingDirection.Y
	consola.ZIndex = 3
	consola.Parent = fondo
	local orden = Instance.new("UIListLayout")
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = consola

	local e: Estado = {
		gui = gui,
		con = tostring(d.con),
		yo = d.estado.yo,
		otro = d.estado.otro,
		grilla = grilla,
		filasYo = {},
		filasOtro = {},
		selOferta = 0,
		nombre = Ventana.label(fondo, "", 44, 222, 156, 32, { Font = Enum.Font.Arial, TextSize = 11, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top }),
		cantidad = nil :: any,
		miOro = Ventana.label(fondo, "", 230, 62, 64, 32, oroCaja),
		oroYo = oroYo,
		oroOtro = Ventana.label(fondo, "", 374, 336, 64, 32, oroCaja),
		marcaYo = Ventana.label(fondo, "", 249, 240, 174, 20, { TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center }),
		marcaOtro = Ventana.label(fondo, "", 249, 266, 174, 20, { TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center }),
		confirmar = Boton.nuevo(fondo, "Confirmar", UDim2.fromOffset(496, 270), UDim2.fromOffset(97, 25), { tamTexto = 13 }),
		aceptar = Boton.nuevo(fondo, "Aceptar", UDim2.fromOffset(448, 544), UDim2.fromOffset(97, 25), { tamTexto = 13 }),
		consola = consola,
		lineas = 0,
		canal = nil,
		conexion = nil,
	}
	v = e
	e.confirmar.Name, e.aceptar.Name = "Confirmar", "Aceptar"
	e.confirmar.ZIndex, e.aceptar.ZIndex = 3, 3
	e.filasYo = filas(fondo, 464, 63, function(i: number)
		e.selOferta = if e.selOferta == i then 0 else i
		grilla:seleccionar(0)
		mostrarNombre()
		local it = e.yo.oferta[i]
		if it and e.selOferta == i then
			e.cantidad.set(it.cant)
		end
		pintar()
	end)
	e.filasOtro = filas(fondo, 465, 337, nil)
	grilla:set(misItems())
	grilla.alSeleccionar = function(_slot: number, it: GrillaItems.Item?, shift: boolean)
		e.selOferta = 0
		mostrarNombre()
		e.cantidad.set(if it and shift then tengo(it.obj) else 1)
		pintar()
	end

	-- La cantidad, con "Todo" para no escribirla en el celular
	e.cantidad = Ventana.cantidad(fondo, 300, 153, 69, 18, Cfg.MaxObjs, function(): number
		return 1
	end, { botones = false })
	local todo = Boton.nuevo(fondo, "Todo", UDim2.fromOffset(376, 150), UDim2.fromOffset(46, 24), { tamTexto = 12 })
	todo.Name = "Todo"
	todo.ZIndex = 3
	Click.activado(todo, function()
		local _, it = grilla:seleccionado()
		local mio = e.yo.oferta[e.selOferta]
		if it then
			e.cantidad.set(math.max(1, tengo(it.obj) - ofrecido(e, it.obj)))
		elseif mio then
			e.cantidad.set(mio.cant)
		end
	end)

	flecha(fondo, "Agregar", 305, 122, function()
		local _, it = grilla:seleccionado()
		if not it then
			linea("Elegí primero algo de tu inventario.", COLOR_AVISO)
			return
		end
		if it.equipado and tengo(it.obj) == 0 then
			linea("Tenés que sacártelo antes de ofrecerlo.", COLOR_AVISO)
			return
		end
		accion("ofrecer", it.obj, math.min(Cfg.MaxObjs, ofrecido(e, it.obj) + e.cantidad.valor()))
	end)
	flecha(fondo, "Quitar", 305, 178, function()
		local it = e.yo.oferta[e.selOferta]
		if not it then
			linea("Elegí primero algo de tu oferta.", COLOR_AVISO)
			return
		end
		accion("ofrecer", it.obj, math.max(0, it.cant - e.cantidad.valor()))
	end)

	-- El oro que ofrezco: solo números; se manda al salir de la casilla
	oroYo:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.gsub(oroYo.Text, "%D", "")
		local n = tonumber(limpio)
		if n and n > Cfg.MaxOro then
			limpio = tostring(Cfg.MaxOro)
		end
		if limpio ~= oroYo.Text then
			oroYo.Text = limpio
		end
	end)
	oroYo.FocusLost:Connect(function()
		local n = math.min(tonumber(oroYo.Text) or 0, Intercambio.oro())
		oroYo.Text = tostring(n)
		if n ~= e.yo.oro then
			accion("oro", n)
		end
	end)

	Click.activado(e.confirmar, function()
		accion("confirmar")
	end)
	Click.activado(e.aceptar, function()
		accion("aceptar")
	end)
	local cancelar = Boton.nuevo(fondo, "Cancelar", UDim2.fromOffset(32, 312), UDim2.fromOffset(97, 25), { tamTexto = 13 })
	local rechazar = Boton.nuevo(fondo, "Rechazar", UDim2.fromOffset(552, 544), UDim2.fromOffset(97, 25), { tamTexto = 13 })
	cancelar.Name, rechazar.Name = "Cancelar", "Rechazar"
	for _, b in { cancelar, rechazar } do
		b.ZIndex = 3
		Click.activado(b, function()
			Intercambio.cerrar(true)
		end)
	end

	-- El chat: solo si Roblox deja que estos dos se hablen en privado (el canal lo abre el servidor)
	local caja = Instance.new("TextBox")
	caja.Name = "Chat"
	caja.BackgroundTransparency = 1
	caja.Position = UDim2.fromOffset(38, 531)
	caja.Size = UDim2.fromOffset(396, 17)
	caja.Font = Enum.Font.Arial
	caja.TextSize = 12
	caja.TextColor3 = Color3.fromRGB(224, 224, 224)
	caja.PlaceholderText = "Escribile y apretá Enter"
	caja.PlaceholderColor3 = Color3.fromRGB(128, 128, 128)
	caja.TextXAlignment = Enum.TextXAlignment.Left
	caja.ClearTextOnFocus = false
	caja.Text = ""
	caja.Visible = false
	caja.ZIndex = 4
	caja.Parent = fondo
	local nick = string.gsub(e.con, " ", "+")
	caja.FocusLost:Connect(function(enter: boolean)
		if not enter then
			return
		end
		local t = string.sub(string.match(caja.Text, "^%s*(.-)%s*$") or "", 1, ConfigChat.Largo)
		caja.Text = ""
		if t ~= "" then
			Chat.enviar(`\\{nick} {t}`)
		end
	end)
	task.spawn(function()
		local ok, canal = pcall(function()
			return Remotes.funcion("Susurrar"):InvokeServer(nick)
		end)
		if v == e and ok and typeof(canal) == "string" then
			e.canal = canal
			caja.Visible = true
		end
	end)

	e.conexion = nil
	pintar()
end

-- ─── El pedido ───────────────────────────────────────────────────────────────
local pedido: ScreenGui? = nil
local function mostrarPedido(de: string, segundos: number)
	if pedido then
		pedido:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "PedidoIntercambio"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 60
	local caja = Boton.marco(g, UDim2.new(0.5, 0, 0, 90), UDim2.fromOffset(320, 104))
	caja.AnchorPoint = Vector2.new(0.5, 0)
	caja.Name = "Caja"
	caja.Active = true -- un toque sobre la caja no pasa al mapa
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(10, 10)
	t.Size = UDim2.new(1, -20, 0, 40)
	t.Font = Enum.Font.ArialBold
	t.TextSize = 14
	t.TextWrapped = true
	t.TextColor3 = COLOR_AVISO
	t.Text = `{de} quiere intercambiar con vos.`
	t.ZIndex = 3
	t.Parent = caja
	local cuenta = Instance.new("TextLabel")
	cuenta.BackgroundTransparency = 1
	cuenta.Position = UDim2.new(1, -44, 0, 4)
	cuenta.Size = UDim2.fromOffset(40, 14)
	cuenta.Font = Enum.Font.Arial
	cuenta.TextSize = 11
	cuenta.TextColor3 = Color3.new(1, 1, 1)
	cuenta.ZIndex = 3
	cuenta.Parent = caja
	local si = Boton.nuevo(caja, "Aceptar", UDim2.fromOffset(40, 60), UDim2.fromOffset(110, 30), { tamTexto = 14 })
	local no = Boton.nuevo(caja, "Rechazar", UDim2.fromOffset(170, 60), UDim2.fromOffset(110, 30), { tamTexto = 14 })
	si.Name, no.Name = "Aceptar", "Rechazar"
	si.ZIndex, no.ZIndex = 3, 3
	local function cerrar(respuesta: boolean?)
		if pedido == g then
			pedido = nil
			g:Destroy()
			if respuesta ~= nil then
				accion("responder", respuesta)
			end
		end
	end
	Click.activado(si, function()
		cerrar(true)
	end)
	Click.activado(no, function()
		cerrar(false)
	end)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	pedido = g
	task.spawn(function()
		local fin = os.clock() + segundos
		while pedido == g do
			local queda = math.ceil(fin - os.clock())
			if queda <= 0 then
				cerrar(nil) -- venció: el servidor ya no lo acepta
				break
			end
			cuenta.Text = `{queda} s`
			task.wait(0.25)
		end
	end)
end

-- Saca el pedido que quedó en pantalla, sin contestarlo (al volver a la pantalla de personajes: Fase 25, docs/44 §9)
function Intercambio.olvidarPedido()
	local g = pedido
	pedido = nil
	if g then
		g:Destroy()
	end
end

-- Pedirle un intercambio al jugador `id` (el menú sobre otro jugador)
function Intercambio.pedir(id: number)
	accion("pedir", id)
end

-- Cambió el oro de la billetera (lo llama Main con cada Estadisticas)
function Intercambio.refrescarOro()
	pintar()
end

function Intercambio.iniciar()
	Inventario.alCambiarInventario(function()
		local e = v
		if e then
			e.grilla:set(misItems())
			mostrarNombre()
		end
	end)
	Remotes.evento("Intercambio").OnClientEvent:Connect(function(tipo: string, d: any)
		if tipo == "pedido" and typeof(d) == "table" then
			mostrarPedido(tostring(d.de), tonumber(d.segundos) or Cfg.PedidoVenceSeg)
		elseif tipo == "pedidoAnulado" then
			if pedido then
				pedido:Destroy()
				pedido = nil
			end
		elseif tipo == "abrir" and typeof(d) == "table" then
			if pedido then
				pedido:Destroy()
				pedido = nil
			end
			abrir(d)
		elseif tipo == "estado" and typeof(d) == "table" then
			local e = v
			if e then
				-- la fila elegida de mi oferta sigue al objeto, no al renglón
				local elegido = e.yo.oferta[e.selOferta]
				e.yo, e.otro = d.yo, d.otro
				e.selOferta = 0
				for i, it in e.yo.oferta do
					if elegido and it.obj == elegido.obj then
						e.selOferta = i
					end
				end
				pintar()
			end
		elseif tipo == "aviso" then
			linea(tostring(d), COLOR_AVISO)
		elseif tipo == "cerrar" then
			Intercambio.cerrar(false)
		end
	end)
end

return Intercambio
