--!strict
--[[
	Retos — la ventana de retos (FrmRetos, docs/28 §4 y §14; clanes-retos.md §3.2), sobre VentanaRetos.jpg (638×400)
	con "1vs1", "2vs2" y "3vs3" ya pintados.

	- Se elige el modo clickeando 1vs1 / 2vs2 / 3vs3 (queda marcado) y aparecen las cajas: Oponente 1 a 3 y
	  Aliado 1 y 2 según el modo, y las monedas de oro (0 a 100.000.000).
	- Los nombres se pueden escribir o elegir de la lista de los que están conectados, que se abre al tocar la caja y
	  se filtra con lo que se escribe (para el autor: más visual que tipear nicks).
	- Comenzar valida como el original (CheckDataReto) y manda la invitación; Salir cierra.
	Además: la invitación que le llega a cada uno (Aceptar / Rechazar con la cuenta de 60 s) y la cuenta regresiva
	grande en el centro antes de cada ronda. La abre el botón "Retos" del HUD o /RETOS.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Cfg = require(ReplicatedStorage.Shared.Config.Retos)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Retos = {}

-- Lo pone Main: escribe en la consola
Retos.aviso = nil :: ((string) -> ())?

local ANCHO, ALTO = 638, 400
local MODOS = { { 112, 96 }, { 272, 96 }, { 440, 96 } } -- lbl1vs1, lbl2vs2, lbl3vs3 (65×33)
local OPONENTES = { 152, 176, 200 } -- txtOponente(0 a 2): x 184, 121×19; etiqueta en x 96
local ALIADOS = { 163, 187 } -- txtAliado(0 y 1): x 416; etiqueta en x 328
local DORADO = Color3.fromRGB(252, 203, 130)
local ROJO = Color3.fromRGB(255, 120, 100)

local gui: ScreenGui? = nil

local function avisar(t: string)
	local f = Retos.aviso
	if f then
		f(t)
	end
end

local function etiqueta(parent: Instance, texto: string, x: number, y: number, w: number, h: number, tam: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.Font = Enum.Font.Arial
	t.TextSize = tam or 13
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = texto
	t.ZIndex = 4
	t.Parent = parent
	return t
end

local function caja(parent: Instance, nombre: string, x: number, y: number, w: number, tope: number, soloNumeros: boolean?): TextBox
	local c = Instance.new("TextBox")
	c.Name = nombre
	c.BackgroundColor3 = Color3.new(0, 0, 0)
	c.BorderSizePixel = 0
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(w, 19)
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
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 3)
	pad.Parent = c
	c:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = if soloNumeros then string.gsub(c.Text, "%D", "") else string.gsub(c.Text, "[%c]", "")
		limpio = string.sub(limpio, 1, tope)
		if limpio ~= c.Text then
			c.Text = limpio
		end
	end)
	return c
end

function Retos.abierta(): boolean
	return gui ~= nil
end

function Retos.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function Retos.abrir()
	Retos.cerrar()
	local g = Instance.new("ScreenGui")
	g.Name = "Retos"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Ventana"
	fondo.BackgroundTransparency = 1
	fondo.Image = UiAssets.retos
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(ANCHO, ALTO)
	fondo.Active = true
	fondo.Parent = g
	Encaje.ventana(fondo, ANCHO, ALTO)

	-- lblDesc: qué hacer o el último error
	local desc = etiqueta(fondo, "", 30, 18, 578, 38, 14)
	desc.Name = "lblDesc"
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextWrapped = true
	local function decir(t: string, error: boolean?)
		desc.Text = t
		desc.TextColor3 = if error then ROJO else DORADO
	end
	decir("Elegi el modo, a tus rivales, a tus companeros y el oro a apostar.")

	-- Los conectados, para elegir sin tipear
	local conectados: { string } = {}
	local function pedirLista()
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.funcion("Reto"):InvokeServer("jugadores")
			end)
			if ok and typeof(r) == "table" and typeof(r.lista) == "table" then
				conectados = r.lista
			end
		end)
	end
	pedirLista()

	-- La lista desplegable debajo de la caja que tiene el foco
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = 6
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.CanvasSize = UDim2.new()
	lista.Visible = false
	lista.ZIndex = 20
	lista.Parent = fondo
	local borde = Instance.new("UIStroke")
	borde.Color = DORADO
	borde.Transparency = 0.4
	borde.Parent = lista
	local orden = Instance.new("UIListLayout")
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista
	local duena: TextBox? = nil
	local function cerrarLista()
		lista.Visible = false
		duena = nil
	end
	local function llenarLista(c: TextBox)
		for _, h in lista:GetChildren() do
			if h:IsA("TextButton") then
				h:Destroy()
			end
		end
		local filtro = string.lower(c.Text)
		local n = 0
		for _, nombre in conectados do
			if filtro == "" or string.find(string.lower(nombre), filtro, 1, true) then
				n += 1
				local b = Instance.new("TextButton")
				b.Name = nombre
				b.AutoButtonColor = true
				b.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
				b.BorderSizePixel = 0
				b.Size = UDim2.new(1, -6, 0, 18)
				b.Font = Enum.Font.Arial
				b.TextSize = 13
				b.TextColor3 = Color3.new(1, 1, 1)
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.Text = " " .. nombre
				b.LayoutOrder = n
				b.ZIndex = 21
				b.Parent = lista
				Click.activado(b, function()
					c.Text = nombre
					cerrarLista()
				end)
			end
		end
		if n == 0 then
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.Size = UDim2.new(1, -6, 0, 18)
			b.Font = Enum.Font.Arial
			b.TextSize = 12
			b.TextColor3 = Color3.fromRGB(170, 170, 170)
			b.Text = if #conectados == 0 then "No hay nadie mas conectado" else "Nadie con ese nombre"
			b.ZIndex = 21
			b.Parent = lista
		end
		lista.Position = UDim2.fromOffset(c.Position.X.Offset, c.Position.Y.Offset + 20)
		lista.Size = UDim2.fromOffset(c.Size.X.Offset, math.min(math.max(n, 1), 6) * 18 + 2)
		lista.Visible = true
		duena = c
	end
	local function conLista(c: TextBox)
		c.Focused:Connect(function()
			pedirLista()
			llenarLista(c)
		end)
		c:GetPropertyChangedSignal("Text"):Connect(function()
			if duena == c then
				llenarLista(c)
			end
		end)
	end
	-- Un click en otro lado de la ventana cierra la lista (el click en un nombre llega antes)
	fondo.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			task.delay(0.15, function()
				if duena and not duena:IsFocused() then
					cerrarLista()
				end
			end)
		end
	end)

	-- Oponentes y aliados
	local oponentes: { TextBox } = {}
	local etOponentes: { TextLabel } = {}
	for i, y in OPONENTES do
		etOponentes[i] = etiqueta(fondo, `Oponente {i}:`, 96, y + 1, 86, 17)
		local c = caja(fondo, `txtOponente{i}`, 184, y, 121, 30)
		conLista(c)
		oponentes[i] = c
	end
	local aliados: { TextBox } = {}
	local etAliados: { TextLabel } = {}
	for i, y in ALIADOS do
		etAliados[i] = etiqueta(fondo, `Aliado {i}:`, 328, y + 1, 86, 17)
		local c = caja(fondo, `txtAliado{i}`, 416, y, 121, 30)
		conLista(c)
		aliados[i] = c
	end
	local soloVos = etiqueta(fondo, "En 1vs1 no hay aliados.", 330, 175, 205, 17, 12)
	soloVos.TextColor3 = Color3.fromRGB(170, 170, 170)
	soloVos.TextXAlignment = Enum.TextXAlignment.Center

	-- Monedas de oro
	etiqueta(fondo, "Monedas de oro:", 105, 288, 116, 17)
	local oro = caja(fondo, "txtOro", 224, 286, 113, 9, true)
	oro.Text = "0"

	-- El modo
	local modo = 1
	local marcas: { UIStroke } = {}
	local function elegir(m: number)
		modo = m
		for i, s in marcas do
			s.Enabled = i == m
		end
		for i = 1, 3 do
			local ve = i <= m
			oponentes[i].Visible = ve
			etOponentes[i].Visible = ve
		end
		for i = 1, 2 do
			local ve = i <= m - 1
			aliados[i].Visible = ve
			etAliados[i].Visible = ve
		end
		soloVos.Visible = m == 1
		cerrarLista()
	end
	for i, p in MODOS do
		local b = Instance.new("TextButton")
		b.Name = `lbl{i}vs{i}`
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Position = UDim2.fromOffset(p[1], p[2])
		b.Size = UDim2.fromOffset(65, 33)
		b.ZIndex = 5
		b.Parent = fondo
		local s = Instance.new("UIStroke")
		s.Color = DORADO
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(0, 6)
		esquina.Parent = b
		marcas[i] = s
		Click.activado(b, function()
			elegir(i)
		end)
	end
	elegir(1)

	-- Comenzar (CheckDataReto) y Salir
	local comenzar = Boton.nuevo(fondo, "Comenzar", UDim2.fromOffset(360, 288), UDim2.fromOffset(113, 41), { tamTexto = 15 })
	local salir = Boton.nuevo(fondo, "Salir", UDim2.fromOffset(480, 288), UDim2.fromOffset(65, 41), { tamTexto = 15 })
	comenzar.Name, salir.Name = "cmdComenzar", "cmdSalir"
	comenzar.ZIndex, salir.ZIndex = 5, 5
	Click.activado(salir, Retos.cerrar)
	local enviando = false
	Click.activado(comenzar, function()
		if enviando then
			return
		end
		cerrarLista()
		local function nombre(c: TextBox): string
			return string.match(c.Text, "^%s*(.-)%s*$") or ""
		end
		local ops, als = {}, {}
		for i = 1, modo do
			local n = nombre(oponentes[i])
			if n == "" then
				decir(`Debes seleccionar al oponente nro {i}`, true)
				return
			end
			table.insert(ops, n)
		end
		for i = 1, modo - 1 do
			local n = nombre(aliados[i])
			if n == "" then
				decir(if modo == 2 then "Debes seleccionar a tu aliado" else `Debes seleccionar a tu aliado nro {i}`, true)
				return
			end
			table.insert(als, n)
		end
		local cant = tonumber(oro.Text) or 0
		if cant < 0 or cant > Cfg.OroMax then
			decir(Cfg.Msg.OroRango, true)
			return
		end
		enviando = true
		decir("Enviando...")
		local ok, r = pcall(function()
			return Remotes.funcion("Reto"):InvokeServer("invitar", { modo = modo, oponentes = ops, aliados = als, oro = cant })
		end)
		enviando = false
		if gui ~= g then
			return
		end
		if not ok or typeof(r) ~= "table" then
			decir("No se pudo mandar el reto.", true)
		elseif r.error then
			decir(tostring(r.error), true)
		else
			avisar(tostring(r.mensaje or Cfg.Msg.Esperando))
			Retos.cerrar()
		end
	end)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

-- ─── Los carteles: la invitación a un reto y los del clan contra clan ────────
-- Un cartel con dos botones y una cuenta. Devuelve el ScreenGui; `cerrar` lo saca (también al vencer la cuenta).
-- y: a qué altura va (el de los retos y el del clan contra clan pueden estar a la vez: uno debajo del otro)
local function nuevoCartel(nombre: string, y: number, texto: string, segundos: number, si: string, no: string, alSi: () -> (), alNo: () -> (), cerrar: () -> (), vigente: (ScreenGui) -> boolean): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = nombre
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 60
	local marco = Boton.marco(g, UDim2.new(0.5, 0, 0, y), UDim2.fromOffset(340, 124))
	marco.AnchorPoint = Vector2.new(0.5, 0)
	marco.Name = "Caja"
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(10, 8)
	t.Size = UDim2.new(1, -20, 0, 62)
	t.Font = Enum.Font.ArialBold
	t.TextSize = 14
	t.TextWrapped = true
	t.TextColor3 = DORADO
	t.Text = texto
	t.ZIndex = 3
	t.Parent = marco
	local cuenta = Instance.new("TextLabel")
	cuenta.BackgroundTransparency = 1
	cuenta.Position = UDim2.new(1, -44, 0, 4)
	cuenta.Size = UDim2.fromOffset(40, 14)
	cuenta.Font = Enum.Font.Arial
	cuenta.TextSize = 11
	cuenta.TextColor3 = Color3.new(1, 1, 1)
	cuenta.ZIndex = 3
	cuenta.Parent = marco
	local bSi = Boton.nuevo(marco, si, UDim2.fromOffset(50, 78), UDim2.fromOffset(110, 32), { tamTexto = 14 })
	local bNo = Boton.nuevo(marco, no, UDim2.fromOffset(180, 78), UDim2.fromOffset(110, 32), { tamTexto = 14 })
	bSi.Name, bNo.Name = "Aceptar", "Rechazar"
	bSi.ZIndex, bNo.ZIndex = 3, 3
	Click.activado(bSi, function()
		cerrar()
		task.spawn(alSi)
	end)
	Click.activado(bNo, function()
		cerrar()
		task.spawn(alNo)
	end)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local fin = os.clock() + segundos
	cuenta.Text = `{math.ceil(segundos)} s`
	task.defer(function() -- diferido: el que llama todavía no guardó el cartel, y `vigente` lo mira
		while vigente(g) do
			local queda = math.ceil(fin - os.clock())
			if queda <= 0 then
				cerrar() -- venció (el servidor avisa por consola)
				break
			end
			cuenta.Text = `{queda} s`
			task.wait(0.25)
		end
	end)
	return g
end

local invitacion: ScreenGui? = nil
local function cerrarInvitacion()
	if invitacion then
		invitacion:Destroy()
		invitacion = nil
	end
end

local function mostrarInvitacion(de: string, texto: string, segundos: number)
	cerrarInvitacion()
	invitacion = nuevoCartel("InvitacionReto", 90, `{de} te desafia a un reto.\n{texto}`, segundos, "Aceptar", "Rechazar", function()
		local ok, r = pcall(function()
			return Remotes.funcion("Reto"):InvokeServer("aceptar", de)
		end)
		if ok and typeof(r) == "table" and r.error then
			avisar(tostring(r.error))
		end
	end, function()
		pcall(function()
			Remotes.funcion("Reto"):InvokeServer("rechazar")
		end)
	end, cerrarInvitacion, function(g)
		return invitacion == g
	end)
end

-- Clan contra clan (Fase 19, docs/38 §6.2): el desafío que le llega al líder y el "Entrar" de los miembros. Es un
-- cartel aparte del de los retos: cerrar uno no cierra el otro.
local cartelCvc: ScreenGui? = nil
local function cerrarCvc()
	if cartelCvc then
		cartelCvc:Destroy()
		cartelCvc = nil
	end
end

local function pedirCvc(accion: string)
	local ok, r = pcall(function()
		return Remotes.funcion("Clan"):InvokeServer("cvc", accion)
	end)
	if ok and typeof(r) == "table" and (r.error or r.mensaje) then
		avisar(tostring(r.error or r.mensaje))
	end
end

-- viaje (Fase 20, docs/39 §7): la pelea es en una sala aparte, y "Ir" lleva hasta ahí
local function mostrarCvc(desafio: boolean, clan: string, segundos: number, viaje: boolean?)
	cerrarCvc()
	local texto = if desafio then `El clan {clan} desafia a tu clan a un clan contra clan.`
		else string.format(if viaje then Cfg.MsgCvc.InvitaViaje else Cfg.MsgCvc.Invita, clan)
	cartelCvc = nuevoCartel("InvitacionCvc", 224, texto, segundos, if desafio then "Aceptar" elseif viaje then "Ir" else "Entrar", if desafio then "Rechazar" else "No", function()
		pedirCvc(if desafio then "aceptar" else "entrar")
	end, function()
		if desafio then
			pedirCvc("rechazar")
		end
	end, cerrarCvc, function(g)
		return cartelCvc == g
	end)
end

-- ─── La cuenta regresiva antes de cada ronda ─────────────────────────────────
local cartel: ScreenGui? = nil
local function mostrarCuenta(n: number)
	if not cartel then
		local g = Instance.new("ScreenGui")
		g.Name = "CuentaReto"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 55
		local t = Instance.new("TextLabel")
		t.Name = "Numero"
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.38)
		t.Size = UDim2.fromOffset(300, 120)
		t.Font = Enum.Font.Garamond
		t.TextSize = 96
		t.TextColor3 = DORADO
		t.TextStrokeTransparency = 0.2
		t.Parent = g
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		cartel = g
	end
	local g = cartel :: ScreenGui
	local t = g:FindFirstChild("Numero") :: TextLabel
	t.Text = if n > 0 then tostring(n) else "¡YA!"
	if n <= 0 then
		task.delay(1.2, function()
			if cartel == g and t.Text == "¡YA!" then
				g:Destroy()
				cartel = nil
			end
		end)
	end
end

local function sacarCuenta()
	if cartel then
		cartel:Destroy()
		cartel = nil
	end
end

-- ─── El reloj de la ronda (Fase 20, docs/39 §6): arriba, al centro; en rojo el último minuto ─────
local reloj: ScreenGui? = nil
local function sacarReloj()
	if reloj then
		reloj:Destroy()
		reloj = nil
	end
end

local function mostrarReloj(segundos: number)
	sacarReloj()
	if segundos <= 0 then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "RelojReto"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 30
	local t = Instance.new("TextLabel")
	t.Name = "Tiempo"
	t.BackgroundColor3 = Color3.new(0, 0, 0)
	t.BackgroundTransparency = 0.45
	t.BorderSizePixel = 0
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, 0, 0, 44)
	t.Size = UDim2.fromOffset(92, 26)
	t.Font = Enum.Font.ArialBold
	t.TextSize = 18
	t.TextColor3 = DORADO
	t.Parent = g
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	reloj = g
	local fin = os.clock() + segundos
	task.spawn(function()
		while reloj == g do
			local queda = math.max(0, math.ceil(fin - os.clock()))
			t.Text = string.format("%d:%02d", queda // 60, queda % 60)
			t.TextColor3 = if queda <= 60 then Color3.fromRGB(255, 90, 70) else DORADO
			if queda <= 0 then
				break
			end
			task.wait(0.25)
		end
	end)
end

-- Sin ventana, invitación, cuenta ni reloj (Fase 25, docs/44 §9: al volver a la pantalla de personajes)
function Retos.reiniciar()
	cerrarInvitacion()
	cerrarCvc()
	sacarCuenta()
	sacarReloj()
	Retos.cerrar()
end

-- El servidor (RetoEvento): "abrir" | "invitacion" | "cerrarInvitacion" | "empieza" | "cuenta" | "tiempo" | "termina" |
-- "cvcDesafio" | "cvcEntrar" | "cvcCerrar"
function Retos.evento(tipo: string, d: any)
	if tipo == "abrir" then
		Retos.abrir()
	elseif tipo == "invitacion" and typeof(d) == "table" then
		mostrarInvitacion(tostring(d.de), tostring(d.texto or ""), tonumber(d.segundos) or Cfg.VenceInvitacion)
	elseif tipo == "cerrarInvitacion" then
		cerrarInvitacion()
	elseif tipo == "empieza" then
		cerrarInvitacion()
		Retos.cerrar()
	elseif tipo == "cuenta" then
		mostrarCuenta(tonumber(d) or 0)
	elseif tipo == "tiempo" then
		mostrarReloj(tonumber(d) or 0)
	elseif tipo == "termina" then
		sacarCuenta()
		sacarReloj()
	-- Fase 19 (docs/38 §6.2): clan contra clan
	elseif tipo == "cvcDesafio" and typeof(d) == "table" then
		mostrarCvc(true, tostring(d.clan), tonumber(d.segundos) or Cfg.CvcAceptarSeg)
	elseif tipo == "cvcEntrar" and typeof(d) == "table" then
		mostrarCvc(false, tostring(d.clan), tonumber(d.segundos) or Cfg.CvcAnotarseSeg, d.viaje == true)
	elseif tipo == "cvcCerrar" then
		cerrarCvc()
	end
end

return Retos
