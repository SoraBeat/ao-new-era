--!strict
--[[
	Party — la ventana "Grupo" (frmParty, docs/28 §2.3 y fase15-investigacion/party.md §12), sobre
	VentanaPartyLider_spanish.jpg (377×402) o VentanaPartyMiembro_spanish.jpg (377×298) con los botones ya pegados.

	- Lista "Nombre (exp)" de los miembros y la exp total (lstMembers, lblTotalExp).
	- Líder: Agregar (txtToAdd → /ACCEPTPARTY nick, si no es un número), Expulsar y Líder del grupo sobre el
	  seleccionado (/ECHARPARTY, /PARTYLIDER), Disolver (/SALIRPARTY). Miembro: Salir del grupo (/SALIRPARTY).
	- Cuadro de chat arriba: Enter manda "/PMSG texto" (hasta 160 caracteres, frmParty.frm:367).
	- DS15-10 A: Expulsar anda (en el original la condición estaba al revés, frmParty.frm:316) y la ventana se refresca
	  sola con el evento "estado" del servidor; si pasás a ser líder (o dejás de serlo) se rearma con el otro fondo.
	La abre el botón "Grupo" del HUD (el servidor contesta "abrir" o "No perteneces a ningun grupo!").

	Correcciones del autor (docs/28 §10):
	- Al lado de cada miembro, su % de la experiencia. El líder los puede cambiar (tienen que sumar 100) con
	  "Aplicar %", y volver al reparto por nivel del original con "Por nivel".
	- Botón derecho sobre otro jugador (mantener apretado en el celular; docs/28 §11) muestra "Invitar al grupo" al lado
	  del click; al invitado le aparece una ventana con Aceptar / Rechazar que vence sola.

	Fase 31 (docs/51, D31-10 a D31-12): el grupo es de hasta 8 según el Liderazgo del líder.
	- Al lado del título "Miembros", cuántos son y cuántos entran ("4 de 6").
	- A la izquierda de la lista, lo que da el Liderazgo del líder: el bono de experiencia y desde dónde se cobra.
	- La lista está dibujada para 6 renglones: con 7 u 8 miembros los renglones se achican para que entren todos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Chat = require(script.Parent.Chat)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Party = {}

type Miembro = { nombre: string, exp: number, pct: number? }
-- Fase 31 (docs/51): liderazgo, tope, bono (%) y alcance (casilleros; nil = todo el mapa) salen del Liderazgo del líder
type Datos = {
	lider: boolean, miembros: { Miembro }, total: number, porcentajes: boolean?,
	liderazgo: number?, tope: number?, bono: number?, alcance: number?,
}

local gui: ScreenGui? = nil
local esLider = false
local seleccionado: string? = nil
local refrescar: ((Datos) -> ())? = nil

-- Filas de botones_party.png (97×24; columnas normal, rollover y click)
local FILA = { Agregar = 0, Expulsar = 1, LiderGrupo = 2, Disolver = 3, SalirGrupo = 4, Cerrar = 5 }
local POS_LIDER = { Expulsar = { 88, 232 }, LiderGrupo = { 192, 232 }, Agregar = { 136, 322 }, Disolver = { 20, 358 }, Cerrar = { 256, 358 } }
local POS_MIEMBRO = { SalirGrupo = { 20, 254 }, Cerrar = { 256, 254 } }
local COLOR_SEL = Color3.fromRGB(0, 0, 128)
-- Fase 31 (docs/51, D31-11): la lista mide 93 de alto. Hasta 6 miembros, el renglón de siempre; con más, el que entre.
local ALTO_LISTA = 93
local ALTO_FILA = 15

local function altoFila(cuantos: number): number
	return if cuantos * ALTO_FILA <= ALTO_LISTA then ALTO_FILA else math.max(10, ALTO_LISTA // cuantos)
end

-- Un número con un decimal como mucho ("5", "5.5")
local function numero(v: number): string
	return if v == math.floor(v) then tostring(v) else string.format("%.1f", v)
end

local function comando(cmd: string, arg: string?)
	Remotes.evento("Comando"):FireServer(cmd, arg)
end

local function boton(parent: Instance, nombre: string, x: number, y: number): ImageButton
	local oy = FILA[nombre] * 24
	local b = Instance.new("ImageButton")
	b.Name = "img" .. nombre
	b.BackgroundTransparency = 1
	b.Image = UiAssets.botonesParty
	b.ImageRectSize = Vector2.new(97, 24)
	b.ImageRectOffset = Vector2.new(0, oy)
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(97, 24)
	b.ZIndex = 3
	b.Parent = parent
	Click.entra(b, function()
		b.ImageRectOffset = Vector2.new(97, oy)
	end)
	Click.sale(b, function()
		b.ImageRectOffset = Vector2.new(0, oy)
	end)
	b.MouseButton1Down:Connect(function()
		b.ImageRectOffset = Vector2.new(194, oy)
	end)
	b.MouseButton1Up:Connect(function()
		b.ImageRectOffset = Vector2.new(97, oy)
	end)
	return b
end

local function caja(parent: Instance, nombre: string, x: number, y: number, w: number, h: number, tope: number): TextBox
	local c = Instance.new("TextBox")
	c.Name = nombre
	c.BackgroundColor3 = Color3.new(0, 0, 0)
	c.BorderSizePixel = 0
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(w, h)
	c.Font = Enum.Font.Arial
	c.TextSize = 13
	c.TextColor3 = Color3.new(1, 1, 1)
	c.TextXAlignment = Enum.TextXAlignment.Left
	c.ClearTextOnFocus = false
	c.PlaceholderText = ""
	c.Text = ""
	c.ClipsDescendants = true
	c.ZIndex = 4
	c.Parent = parent
	-- Solo caracteres imprimibles y hasta `tope` (SendTxt_Change / txtToAdd_KeyPress)
	c:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.sub(string.gsub(c.Text, "[%c]", ""), 1, tope)
		if limpio ~= c.Text then
			c.Text = limpio
		end
	end)
	return c
end

function Party.abierta(): boolean
	return gui ~= nil
end

function Party.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
	refrescar = nil
	seleccionado = nil
end

function Party.abrir(d: Datos)
	Party.cerrar()
	esLider = d.lider == true
	local ancho, alto = 377, if esLider then 402 else 298

	local g = Instance.new("ScreenGui")
	g.Name = "Party"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Ventana"
	fondo.BackgroundTransparency = 1
	fondo.Image = if esLider then UiAssets.partyLider else UiAssets.partyMiembro
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(ancho, alto)
	fondo.Active = true
	fondo.Parent = g
	Encaje.ventana(fondo, ancho, alto, { techo = 1.3 })

	-- Chat de la party (SendTxt): Enter manda /PMSG y deja el foco en la caja
	local chat = caja(fondo, "SendTxt", 37, 48, 302, 17, 160)
	chat.FocusLost:Connect(function(enter: boolean)
		if enter then
			local t = chat.Text
			chat.Text = ""
			if string.match(t, "%S") then
				Chat.enviar("/PMSG " .. t)
			end
			task.defer(function()
				if chat.Parent then
					chat:CaptureFocus()
				end
			end)
		end
	end)

	-- Miembros (lstMembers) y exp total (lblTotalExp)
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "lstMembers"
	lista.BackgroundColor3 = Color3.new(0, 0, 0)
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(102, 106)
	lista.Size = UDim2.fromOffset(173, ALTO_LISTA)
	lista.ScrollBarThickness = 6
	lista.CanvasSize = UDim2.new()
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.ZIndex = 4
	lista.Parent = fondo
	local orden = Instance.new("UIListLayout")
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista
	local total = Instance.new("TextLabel")
	total.Name = "lblTotalExp"
	total.BackgroundTransparency = 1
	total.Position = UDim2.fromOffset(205, 210)
	total.Size = UDim2.fromOffset(89, 17)
	total.Font = Enum.Font.ArialBold
	total.TextSize = 13
	total.TextColor3 = Color3.new(1, 1, 1)
	total.TextXAlignment = Enum.TextXAlignment.Left
	total.ZIndex = 4
	total.Parent = fondo
	-- Fase 31 (docs/51, D31-11): al lado del título "Miembros" del dibujo, cuántos son y cuántos entran: "4 de 6"
	local cuantos = Instance.new("TextLabel")
	cuantos.Name = "lblMiembros"
	cuantos.BackgroundTransparency = 1
	cuantos.Position = UDim2.fromOffset(220, 81)
	cuantos.Size = UDim2.fromOffset(80, 17)
	cuantos.Font = Enum.Font.ArialBold
	cuantos.TextSize = 12
	cuantos.TextColor3 = Color3.fromRGB(252, 203, 130)
	cuantos.TextXAlignment = Enum.TextXAlignment.Left
	cuantos.ZIndex = 4
	cuantos.Parent = fondo
	-- Fase 31 (docs/51, D31-10 y D31-12): a la izquierda de la lista, lo que da el Liderazgo del líder
	local mando = Instance.new("TextLabel")
	mando.Name = "lblLiderazgo"
	mando.BackgroundTransparency = 1
	mando.Position = UDim2.fromOffset(10, 106)
	mando.Size = UDim2.fromOffset(88, ALTO_LISTA)
	mando.Font = Enum.Font.Arial
	mando.TextSize = 11
	mando.TextWrapped = true
	mando.TextColor3 = Color3.new(1, 1, 1)
	mando.TextXAlignment = Enum.TextXAlignment.Left
	mando.TextYAlignment = Enum.TextYAlignment.Top
	mando.ZIndex = 4
	mando.Parent = fondo

	-- Cada fila: "Nombre (exp)" y su % (docs/28 §10). Las filas se actualizan sin rearmarse, así no se pierde lo que el
	-- líder está escribiendo en un %.
	local reparto = Instance.new("TextLabel")
	reparto.Name = "Reparto"
	reparto.BackgroundTransparency = 1
	reparto.Position = UDim2.fromOffset(282, if esLider then 156 else 106)
	reparto.Size = UDim2.fromOffset(84, 30)
	reparto.Font = Enum.Font.Arial
	reparto.TextSize = 11
	reparto.TextWrapped = true
	reparto.TextColor3 = Color3.new(1, 1, 1)
	reparto.TextXAlignment = Enum.TextXAlignment.Left
	reparto.TextYAlignment = Enum.TextYAlignment.Top
	reparto.ZIndex = 4
	reparto.Parent = fondo
	type Fila = { boton: TextButton, pct: TextBox | TextLabel }
	local filas: { [string]: Fila } = {}
	local sucio: { [string]: boolean } = {}
	local ultimo: Datos = d
	local function pintarSeleccion()
		for nombre, f in filas do
			f.boton.BackgroundTransparency = if nombre == seleccionado then 0 else 1
		end
	end
	local function nuevaFila(nombre: string): Fila
		local f = Instance.new("TextButton")
		f.Name = nombre
		f.AutoButtonColor = false
		f.BackgroundColor3 = COLOR_SEL
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, -6, 0, 15)
		f.Font = Enum.Font.Arial
		f.TextSize = 12
		f.TextColor3 = Color3.new(1, 1, 1)
		f.TextXAlignment = Enum.TextXAlignment.Left
		f.TextTruncate = Enum.TextTruncate.AtEnd
		f.ZIndex = 5
		f.Parent = lista
		Click.activado(f, function()
			seleccionado = nombre
			pintarSeleccion()
		end)
		local pct: TextBox | TextLabel
		if esLider then
			local c = Instance.new("TextBox")
			c.ClearTextOnFocus = false
			c.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			c.BorderSizePixel = 0
			c:GetPropertyChangedSignal("Text"):Connect(function()
				local limpio = string.sub(string.gsub(c.Text, "%D", ""), 1, 3)
				if limpio ~= c.Text then
					c.Text = limpio
				end
			end)
			c.Focused:Connect(function()
				sucio[nombre] = true
			end)
			pct = c
		else
			pct = Instance.new("TextLabel")
			pct.BackgroundTransparency = 1
		end
		pct.Name = "Pct"
		pct.AnchorPoint = Vector2.new(1, 0)
		pct.Position = UDim2.new(1, -2, 0, 0)
		pct.Size = UDim2.fromOffset(34, 15)
		pct.Font = Enum.Font.Arial
		pct.TextSize = 12
		pct.TextColor3 = Color3.fromRGB(252, 203, 130)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		pct.ZIndex = 6
		pct.Parent = f
		return { boton = f, pct = pct }
	end
	local function llenar(datos: Datos)
		ultimo = datos
		local presentes: { [string]: boolean } = {}
		-- Fase 31 (docs/51, D31-11): con 7 u 8 miembros los renglones se achican para que se vean todos sin deslizar
		local alto = altoFila(#datos.miembros)
		local letra = math.clamp(alto - 1, 9, 12) -- 12 con el renglón de 15 (y con el de 13); 10 con el de 11
		for i, m in datos.miembros do
			presentes[m.nombre] = true
			local f = filas[m.nombre] or nuevaFila(m.nombre)
			filas[m.nombre] = f
			f.boton.LayoutOrder = i
			f.boton.Size = UDim2.new(1, -6, 0, alto)
			f.boton.TextSize = letra
			f.pct.Size = UDim2.fromOffset(34, alto)
			f.pct.TextSize = letra
			f.boton.Text = ` {m.nombre} ({m.exp})`
			local p = m.pct or 0
			local texto = if p == math.floor(p) then tostring(p) else string.format("%.1f", p)
			if f.pct:IsA("TextBox") then
				if not sucio[m.nombre] and not (f.pct :: TextBox):IsFocused() then
					f.pct.Text = tostring(math.floor(p + 0.5))
				end
			else
				f.pct.Text = texto .. "%"
			end
		end
		for nombre, f in filas do
			if not presentes[nombre] then
				f.boton:Destroy()
				filas[nombre] = nil
				sucio[nombre] = nil
			end
		end
		if seleccionado and not presentes[seleccionado] then
			seleccionado = nil
		end
		pintarSeleccion()
		total.Text = tostring(datos.total or 0)
		reparto.Text = if datos.porcentajes then "Reparto elegido por el lider" else "Reparto por nivel"
		-- Fase 31 (docs/51): el tope del grupo y lo que da el Liderazgo del líder
		local tope = datos.tope
		cuantos.Text = if tope then `{#datos.miembros} de {tope}` else tostring(#datos.miembros)
		if datos.liderazgo then
			local alcance = datos.alcance
			mando.Text = `Liderazgo del lider: {numero(datos.liderazgo)}\nBono de exp.: +{numero(datos.bono or 0)}%\n`
				.. (if alcance then `Se cobra a {numero(alcance)} casilleros` else "Se cobra en todo el mapa")
		else
			mando.Text = ""
		end
	end
	llenar(d)
	refrescar = llenar

	if esLider then
		local aplicar = Boton.nuevo(fondo, "Aplicar %", UDim2.fromOffset(282, 106), UDim2.fromOffset(84, 22), { tamTexto = 12 })
		local porNivel = Boton.nuevo(fondo, "Por nivel", UDim2.fromOffset(282, 131), UDim2.fromOffset(84, 22), { tamTexto = 12 })
		aplicar.Name, porNivel.Name = "AplicarPct", "PorNivel"
		aplicar.ZIndex, porNivel.ZIndex = 5, 5
		Click.activado(aplicar, function()
			local t = {}
			for _, m in ultimo.miembros do
				local f = filas[m.nombre]
				t[m.nombre] = if f then tonumber(f.pct.Text) or 0 else 0
			end
			table.clear(sucio)
			Remotes.evento("PartyAccion"):FireServer("porcentajes", t)
		end)
		Click.activado(porNivel, function()
			table.clear(sucio)
			Remotes.evento("PartyAccion"):FireServer("porcentajes", nil)
			llenar(ultimo)
		end)
	end

	local pos = if esLider then POS_LIDER else POS_MIEMBRO
	for nombre, p in pos do
		local b = boton(fondo, nombre, p[1], p[2])
		Click.activado(b, function()
			if nombre == "Cerrar" then
				Party.cerrar()
			elseif nombre == "Disolver" or nombre == "SalirGrupo" then
				comando("SALIRPARTY")
				Party.cerrar()
			elseif nombre == "Expulsar" then
				if seleccionado then
					comando("ECHARPARTY", seleccionado)
				end
			elseif nombre == "LiderGrupo" then
				if seleccionado then
					comando("PARTYLIDER", seleccionado)
				end
			end
		end)
	end

	if esLider then
		local agregar = caja(fondo, "txtToAdd", 102, 291, 172, 16, 30)
		local function agregarNick()
			local nick = string.match(agregar.Text, "^%s*(.-)%s*$") or ""
			if nick ~= "" and not tonumber(nick) then
				comando("ACCEPTPARTY", nick)
				agregar.Text = ""
			end
		end
		agregar.FocusLost:Connect(function(enter: boolean)
			if enter then
				agregarNick()
			end
		end)
		for _, b in fondo:GetChildren() do
			if b.Name == "imgAgregar" then
				Click.activado((b :: ImageButton), agregarNick)
			end
		end
	end

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

-- ─── Invitar clickeando a un jugador (docs/28 §10) ───────────────────────────
local burbuja: ScreenGui? = nil
local miembros: { [string]: boolean } = {} -- los de mi party (del último estado)

local function sacarBurbuja()
	if burbuja then
		burbuja:Destroy()
		burbuja = nil
	end
end

-- Lo pone Main (Fase 22, docs/41 §5): pedirle un intercambio a ese jugador
Party.alIntercambiar = nil :: ((number) -> ())?
-- Lo pone Main (Fase 23, docs/42 §3.3): abrir la ventana de denuncia para ese nombre
Party.alDenunciar = nil :: ((string) -> ())?

-- El Controlador avisa que se clickeó a otro jugador (id) en la posición pos de la pantalla: el menú sobre él, con
-- "Invitar al grupo" (si no es ya de mi grupo) e "Intercambiar"
function Party.alClickearJugador(id: number, nombre: string?, pos: Vector2)
	sacarBurbuja()
	local g = Instance.new("ScreenGui")
	g.Name = "InvitarGrupo"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 45
	local y = pos.Y - 14
	if not (nombre and miembros[nombre]) then
		local b = Boton.nuevo(g, "Invitar al grupo", UDim2.fromOffset(pos.X + 18, y), UDim2.fromOffset(120, 28), { tamTexto = 13 })
		b.Name = "Invitar"
		Click.activado(b, function()
			Remotes.evento("PartyAccion"):FireServer("invitar", id)
			sacarBurbuja()
		end)
		y += 30
	end
	local bi = Boton.nuevo(g, "Intercambiar", UDim2.fromOffset(pos.X + 18, y), UDim2.fromOffset(120, 28), { tamTexto = 13 })
	bi.Name = "Intercambiar"
	Click.activado(bi, function()
		local f = Party.alIntercambiar
		if f then
			f(id)
		end
		sacarBurbuja()
	end)
	-- Fase 23 (docs/42 §3.3, D23-12 A): denunciarlo, eligiendo el motivo de una lista
	if nombre then
		local bd = Boton.nuevo(g, "Denunciar", UDim2.fromOffset(pos.X + 18, y + 30), UDim2.fromOffset(120, 28), { tamTexto = 13 })
		bd.Name = "Denunciar"
		Click.activado(bd, function()
			local f = Party.alDenunciar
			if f then
				f(nombre)
			end
			sacarBurbuja()
		end)
	end
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	burbuja = g
	task.delay(4, function()
		if burbuja == g then
			sacarBurbuja()
		end
	end)
end

-- Un click en el mapa que no fue a otro jugador saca el botón
function Party.alClickearMapa()
	sacarBurbuja()
end

local invitacion: ScreenGui? = nil
local function mostrarInvitacion(de: string, segundos: number)
	if invitacion then
		invitacion:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "InvitacionGrupo"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 60
	local caja = Boton.marco(g, UDim2.new(0.5, 0, 0, 90), UDim2.fromOffset(320, 104))
	caja.AnchorPoint = Vector2.new(0.5, 0)
	caja.Name = "Caja"
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(10, 10)
	t.Size = UDim2.new(1, -20, 0, 40)
	t.Font = Enum.Font.ArialBold
	t.TextSize = 14
	t.TextWrapped = true
	t.TextColor3 = Color3.fromRGB(252, 203, 130)
	t.Text = `{de} te invita a su grupo.`
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
		if invitacion == g then
			invitacion = nil
			g:Destroy()
			if respuesta ~= nil then
				Remotes.evento("PartyAccion"):FireServer("responder", respuesta)
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
	invitacion = g
	task.spawn(function()
		local fin = os.clock() + segundos
		while invitacion == g do
			local queda = math.ceil(fin - os.clock())
			if queda <= 0 then
				cerrar(nil) -- venció: el servidor ya no la acepta
				break
			end
			cuenta.Text = `{queda} s`
			task.wait(0.25)
		end
	end)
end

-- Sin grupo, sin invitación y sin menú (Fase 25, docs/44 §9: al volver a la pantalla de personajes)
function Party.reiniciar()
	table.clear(miembros)
	sacarBurbuja()
	if invitacion then
		invitacion:Destroy()
		invitacion = nil
	end
	Party.cerrar()
end

-- El servidor: "abrir" (pidió la ventana), "estado" (cambió la party; nil = ya no está en ninguna) o "invitacion"
function Party.evento(tipo: string, d: any)
	if tipo == "invitacion" and d then
		mostrarInvitacion(tostring(d.lider), tonumber(d.segundos) or 30)
		return
	end
	if tipo == "estado" or tipo == "abrir" then
		table.clear(miembros)
		for _, m in (d and d.miembros) or {} do
			miembros[m.nombre] = true
		end
	end
	if tipo == "abrir" and d then
		Party.abrir(d)
	elseif tipo == "estado" and gui then
		local f = refrescar
		if not d then
			Party.cerrar()
		elseif (d.lider == true) ~= esLider then
			Party.abrir(d) -- cambió el líder: el otro fondo y los otros botones
		elseif f then
			f(d)
		end
	end
end

return Party
