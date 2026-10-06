--!strict
--[[
	PanelCuenta — el panel de personajes de la cuenta (frmPanelAccount, docs/21 §2; reemplaza a SelectorClase).

	La ventana original (frmPanelAccount.jpg, 800×600) escalada a la pantalla, con los 10 cuadros (picChar), el nombre
	debajo de cada uno (lblAccData), los datos del elegido (lblCharData: nombre, clase, raza, nivel, oro, mapa) y los
	botones "Entrar", "Crear Personaje", "Borrar Personaje" y, para los probadores, "Personaje de prueba" (en el lugar
	de "Salir", que en Roblox no hace falta).
	- Click en un cuadro lo elige; doble click entra (o crea, si está vacío).
	- Borrar pide confirmación y escribir el nombre (docs/21 §2.2).
	PanelCuenta.elegir() espera hasta que se elige y devuelve el pedido para Unirse: { id } o { prueba = clase }.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage.Shared.Config.Cuenta)
local CfgTienda = require(ReplicatedStorage.Shared.Config.Tienda)
local ConfigPJ = require(ReplicatedStorage.Shared.Config.Personajes)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local CrearPersonaje = require(script.Parent.CrearPersonaje)
local SelectorClase = require(script.Parent.SelectorClase)
local Tienda = require(script.Parent.Tienda)
local Musica = require(script.Parent.Parent.Audio.Musica)
local Retrato = require(script.Parent.Parent.Render.Retrato)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local PanelCuenta = {}

local ANCHO, ALTO = 800, 600
-- picChar(0..9) y lblAccData(1..10) (frmPanelAccount.frm, en px)
local CUADROS = {
	{ 128, 113, 76, 79 }, { 245, 113, 76, 80 }, { 355, 113, 76, 80 }, { 467, 113, 73, 80 }, { 584, 113, 73, 80 },
	{ 131, 238, 76, 80 }, { 244, 238, 76, 80 }, { 357, 238, 76, 80 }, { 467, 238, 76, 80 }, { 584, 238, 76, 80 },
}
local NOMBRES = {
	{ 126, 206 }, { 242, 206 }, { 354, 206 }, { 464, 206 }, { 582, 206 },
	{ 126, 329 }, { 240, 329 }, { 352, 329 }, { 462, 329 }, { 580, 329 },
}
local DATOS_Y = { 368, 389, 412, 436, 459, 481 } -- lblCharData(0..5)
local AMARILLO = Color3.fromRGB(255, 255, 225)

local function texto(parent: Instance, t: string, x: number, y: number, w: number, h: number, alinear: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 13
	l.TextColor3 = AMARILLO
	l.TextXAlignment = alinear or Enum.TextXAlignment.Left
	l.Text = t
	l.ZIndex = 3
	l.Parent = parent
	return l
end

-- La ventana de fondo, centrada y escalada a la pantalla (sirve también para la creación)
function PanelCuenta.ventana(nombre: string, imagen: string, ancho: number, alto: number): (ScreenGui, ImageLabel, () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = nombre
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Detrás, el menú de inicio recortado y oscurecido (docs/26), en lugar del negro
	local negro = Instance.new("ImageLabel")
	negro.Name = "Fondo"
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BorderSizePixel = 0
	negro.Image = UiAssets.menu
	negro.ScaleType = Enum.ScaleType.Crop
	negro.ImageColor3 = Color3.fromRGB(55, 48, 40)
	negro.Size = UDim2.fromScale(1, 1)
	negro.Parent = gui
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Ventana"
	fondo.BackgroundTransparency = 1
	fondo.Image = imagen
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(ancho, alto)
	fondo.Parent = gui
	local escala = Instance.new("UIScale")
	escala.Parent = fondo
	local camara = workspace.CurrentCamera
	local function ajustar()
		local vp = camara.ViewportSize
		escala.Scale = math.min(vp.X / ancho, vp.Y / alto)
	end
	ajustar()
	local con = camara:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, fondo, function()
		con:Disconnect()
		gui:Destroy()
	end
end

-- ─── El Cambio de cara (Fase 24, docs/43 §18) ────────────────────────────────
-- Una ventana por delante del panel: el personaje con cada una de las caras de su raza y su género, y dos flechas.
-- Devuelve la cabeza elegida, o nil si se canceló.
local function elegirCara(p: any): number?
	local rango = Cfg.Cabezas[p.raza] and Cfg.Cabezas[p.raza][p.genero]
	if not rango then
		return nil
	end
	local primera, cuantas = rango[1], rango[2] - rango[1] + 1
	local actual = if typeof(p.cabeza) == "number" and Cfg.cabezaValida(p.raza, p.genero, p.cabeza) then p.cabeza else primera
	local cabeza = actual
	local g = Instance.new("ScreenGui")
	g.Name = "CambioDeCara"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 120
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local velo = Instance.new("TextButton") -- tapa el panel: los clicks no pasan
	velo.Text = ""
	velo.AutoButtonColor = false
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 0.45
	velo.Size = UDim2.fromScale(1, 1)
	velo.Parent = g
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(300, 270))
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	Encaje.ventana(caja, 300, 270, { techo = 1.5 })
	local titulo = texto(caja, `Cambio de cara: {p.nombre}`, 0, 12, 300, 18, Enum.TextXAlignment.Center)
	titulo.TextSize = 15
	titulo.TextColor3 = Boton.ColorTexto
	local vista = Instance.new("Frame")
	vista.Name = "Vista"
	vista.BackgroundColor3 = Color3.fromRGB(46, 54, 46)
	vista.BorderSizePixel = 0
	vista.Position = UDim2.fromOffset(90, 42)
	vista.Size = UDim2.fromOffset(120, 130)
	vista.ClipsDescendants = true
	vista.ZIndex = 2
	vista.Parent = caja
	local r = Retrato.nuevo(vista, 22, 44, 3)
	local agrandar = Instance.new("UIScale")
	agrandar.Scale = 2.4
	agrandar.Parent = r.marco
	local cual = texto(caja, "", 0, 178, 300, 16, Enum.TextXAlignment.Center)
	local function pintar()
		-- Vivo: como está vestido, sin el casco (que tapa la cara). Muerto: el cuerpo desnudo de su raza
		local ap = if p.muerto or typeof(p.apariencia) ~= "table"
			then { cuerpo = ConfigPJ.cuerpoDesnudoDe(p.raza, p.genero), cabeza = cabeza, casco = 0, arma = 0, escudo = 0 }
			else table.clone(p.apariencia)
		ap.cabeza, ap.casco = cabeza, 0
		Retrato.dibujar(r, ap, 3)
		cual.Text = `Cara {cabeza - primera + 1} de {cuantas}{if cabeza == actual then " (la de ahora)" else ""}`
	end
	local function mover(d: number)
		cabeza = primera + ((cabeza - primera) + d) % cuantas
		pintar()
	end
	local bAntes = Boton.nuevo(caja, "<", UDim2.fromOffset(40, 90), UDim2.fromOffset(36, 36), { tamTexto = 18 })
	bAntes.Name = "Anterior"
	Click.activado(bAntes, function()
		mover(-1)
	end)
	local bDespues = Boton.nuevo(caja, ">", UDim2.fromOffset(224, 90), UDim2.fromOffset(36, 36), { tamTexto = 18 })
	bDespues.Name = "Siguiente"
	Click.activado(bDespues, function()
		mover(1)
	end)
	pintar()
	local resultado: number? = nil
	local listo = false
	local bOk = Boton.nuevo(caja, "Aceptar", UDim2.fromOffset(40, 216), UDim2.fromOffset(100, 34), { tamTexto = 15 })
	bOk.Name = "Aceptar"
	Click.activado(bOk, function()
		resultado = cabeza
		listo = true
	end)
	local bNo = Boton.nuevo(caja, "Cancelar", UDim2.fromOffset(160, 216), UDim2.fromOffset(100, 34), { tamTexto = 15 })
	bNo.Name = "Cancelar"
	Click.activado(bNo, function()
		listo = true
	end)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	while not listo and g.Parent do
		task.wait()
	end
	g:Destroy()
	return resultado
end

-- Pide la cuenta al servidor (reintenta si todavía está cargando)
local function pedirCuenta(): any
	while true do
		local ok, r = pcall(function()
			return Remotes.funcion("Cuenta"):InvokeServer()
		end)
		if ok and r and not r.error then
			return r
		end
		Dialogo.aviso(if ok and r and r.error then r.error else Cfg.MsgNoCargo)
	end
end

function PanelCuenta.elegir(): any
	local cuenta = pedirCuenta()
	local lista: { any } = cuenta.personajes
	local gui, fondo, cerrar = PanelCuenta.ventana("PanelCuenta", UiAssets.panel, ANCHO, ALTO)
	-- Fase 23 (docs/42 §5.2, D23-19 A): con un personaje preso, la cuenta solo entra con él; acá dice cuánto falta
	if typeof(cuenta.pena) == "table" then
		local aviso = Instance.new("TextLabel")
		aviso.Name = "Pena"
		aviso.BackgroundColor3 = Color3.new(0, 0, 0)
		aviso.BackgroundTransparency = 0.35
		aviso.BorderSizePixel = 0
		aviso.AnchorPoint = Vector2.new(0.5, 0)
		aviso.Position = UDim2.new(0.5, 0, 0, 6)
		aviso.Size = UDim2.new(1, -40, 0, 22)
		aviso.Font = Enum.Font.ArialBold
		aviso.TextSize = 13
		aviso.TextColor3 = Color3.fromRGB(255, 120, 100)
		aviso.Text = `Tu cuenta tiene un personaje preso ({cuenta.pena.nombre}): le faltan {cuenta.pena.min} min. Hasta que cumpla, solo podés entrar con él.`
		aviso.TextTruncate = Enum.TextTruncate.AtEnd
		aviso.ZIndex = 6
		aviso.Parent = fondo
	end
	local seleccionado = 0
	local pedido: any = nil
	local ocupado = false
	local pintar: () -> () = function() end

	-- DN-08 A (docs/23): un nombre que no pasa el filtro de Roblox se cambia antes de entrar
	local function entrar(p: any)
		if not p.renombrar then
			pedido = { id = p.id }
			return
		end
		ocupado = true
		local si, escrito = Dialogo.confirmar(Cfg.MsgRenombrar, Cfg.MsgTituloRenombrar, Cfg.MsgEscribirNuevoNombre)
		if si then
			local r = Remotes.funcion("RenombrarPersonaje"):InvokeServer(p.id, escrito)
			if r and r.ok then
				lista = r.personajes
				pintar()
			else
				Dialogo.aviso(if r and r.error then r.error else Cfg.MsgErrorGuardado)
			end
		end
		ocupado = false
	end

	texto(fondo, Players.LocalPlayer.DisplayName, 184, 58, 431, 25, Enum.TextXAlignment.Center).TextSize = 18 -- lblAccData(0)
	local marcos: { Frame } = {}
	local retratos = {}
	local nombres: { TextLabel } = {}
	local datos: { TextLabel } = {}
	for i, c in CUADROS do
		local b = Instance.new("TextButton")
		b.Name = `picChar{i - 1}`
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Position = UDim2.fromOffset(c[1], c[2])
		b.Size = UDim2.fromOffset(c[3], c[4])
		b.ZIndex = 2
		b.Parent = fondo
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(255, 255, 0)
		borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- en un TextButton, si no, se aplica al texto
		borde.Thickness = 1
		borde.Enabled = false
		borde.Parent = b
		marcos[i] = b
		-- El personaje parado en el medio del cuadro
		retratos[i] = Retrato.nuevo(b, c[3] // 2 - 16, c[4] // 2 + 4, 3)
		nombres[i] = texto(fondo, "", NOMBRES[i][1], NOMBRES[i][2], 83, 13, Enum.TextXAlignment.Center)
		local ultimoClick = 0
		Click.activado(b, function()
			if ocupado then
				return
			end
			local ahora = os.clock()
			local doble = seleccionado == i and ahora - ultimoClick < 0.4
			ultimoClick = ahora
			seleccionado = i
			for j, m in marcos do
				(m:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = j == i and lista[j] ~= nil
			end
			local p = lista[i]
			for k, l in datos do
				l.Text = ""
				if p then
					local valores = {
						`Nombre: {p.nombre}`,
						`Clase: {p.clase}`,
						`Raza: {p.raza}`,
						`Nivel: {p.elv}`,
						`Oro: {p.oro}`,
						`Mapa: {p.mapa}`,
					}
					l.Text = valores[k]
				end
			end
			if doble then
				if p then
					task.spawn(entrar, p)
				elseif #lista < Cfg.MaxPersonajes then
					task.spawn(function()
						(PanelCuenta :: any)._crear()
					end)
				end
			end
		end)
	end
	for k, y in DATOS_Y do
		datos[k] = texto(fondo, "", 216, y, 380, 16)
	end

	local function pintarLista()
		for i = 1, #CUADROS do
			local p = lista[i]
			Retrato.visible(retratos[i], p ~= nil)
			if p then
				Retrato.dibujar(retratos[i], p.apariencia, 3, p.muerto)
			end
			nombres[i].Text = if p then p.nombre else ""
		end
	end
	pintarLista()
	pintar = pintarLista

	local function crear()
		if ocupado then
			return
		end
		if #lista >= Cfg.MaxPersonajes then
			Dialogo.aviso(Cfg.MsgCuentaLlena) -- ERROR_DEMASIADOS_PJS (frmPanelAccount.frm:717-719)
			return
		end
		ocupado = true
		gui.Enabled = false
		Musica.creacion(true) -- 7.mp3 (DSO-06 A)
		local nueva = CrearPersonaje.abrir()
		Musica.creacion(false)
		gui.Enabled = true
		ocupado = false
		if nueva then
			lista = nueva.personajes
			pintarLista()
		end
	end
	;(PanelCuenta :: any)._crear = crear

	local bBorrar = Boton.nuevo(fondo, "Borrar Personaje", UDim2.fromOffset(56, 424), UDim2.fromOffset(113, 41), { tamTexto = 13, animado = true })
	local bCrear = Boton.nuevo(fondo, "Crear Personaje", UDim2.fromOffset(336, 528), UDim2.fromOffset(113, 41), { tamTexto = 13, animado = true })
	local bEntrar = Boton.nuevo(fondo, "Entrar", UDim2.fromOffset(608, 528), UDim2.fromOffset(113, 41), { tamTexto = 15, animado = true })
	for _, b in { bBorrar, bCrear, bEntrar } do
		b.ZIndex = 4
	end
	-- La tienda también se abre desde acá, sin personaje en el mundo (Fase 23, docs/42 §8.4, D23-50 A)
	local bTienda = Boton.nuevo(fondo, "Tienda", UDim2.fromOffset(608, 424), UDim2.fromOffset(113, 41), { tamTexto = 14, animado = true })
	bTienda.Name = "Tienda"
	bTienda.ZIndex = 4
	Click.activado(bTienda, function()
		if not ocupado then
			Tienda.abrir(110) -- por delante de este panel (100)
		end
	end)
	-- Fase 24 (docs/43 §18): el Cambio de nombre y el Cambio de cara de la tienda se usan acá, con un personaje elegido.
	-- Sin un cambio comprado, el botón lleva a la pestaña "Personaje" de la tienda.
	local cambios = if typeof(cuenta.cambios) == "table" then cuenta.cambios else { nombre = 0, cara = 0 }
	local function tengoCambio(que: string, cosa: string): boolean
		local d = Tienda.datos()
		if d and d.cargada and typeof(d.bandeja) == "table" then
			return (d.bandeja[cosa] or 0) > 0
		end
		return (cambios[que] or 0) > 0
	end
	local function despuesDelCambio(r: any)
		lista = r.personajes
		if typeof(r.bandeja) == "table" then
			cambios = { nombre = r.bandeja.cambioNombre or 0, cara = r.bandeja.cambioCara or 0 }
			local d = Tienda.datos()
			if d then
				d.bandeja = r.bandeja
			end
		end
		pintarLista()
		local p = lista[seleccionado]
		if p and datos[1] then
			datos[1].Text = `Nombre: {p.nombre}`
		end
	end
	local function cambio(que: string, cosa: string)
		if ocupado then
			return
		end
		local p = lista[seleccionado]
		if not p then
			Dialogo.aviso(Cfg.MsgNoSeleccionado)
			return
		end
		ocupado = true
		if not tengoCambio(que, cosa) then
			Dialogo.aviso(if que == "nombre" then CfgTienda.Msg.SinCambioNombre else CfgTienda.Msg.SinCambioCara)
			ocupado = false
			Tienda.abrir(110, "Personaje")
			return
		end
		local valor: any = nil
		if que == "nombre" then
			local si, escrito = Dialogo.confirmar(
				`Vas a gastar un Cambio de nombre en {p.nombre}. Si el nombre nuevo no se acepta, no se gasta.`,
				"Cambio de nombre", Cfg.MsgEscribirNuevoNombre
			)
			valor = if si then escrito else nil
		else
			valor = elegirCara(p)
			if valor == p.cabeza then
				valor = nil -- eligió la que ya tiene: no se gasta nada
			end
		end
		if valor ~= nil and valor ~= "" then
			-- (con pcall: si la llamada falla, el panel no puede quedar trabado en "ocupado")
			local llego, r = pcall(function()
				return Remotes.funcion("CambiarPersonaje"):InvokeServer(p.id, que, valor)
			end)
			if llego and typeof(r) == "table" and r.ok then
				despuesDelCambio(r)
			else
				local sinCambio = llego and typeof(r) == "table" and r.sinCambio == true
				if sinCambio then
					-- El servidor dice que no queda ninguno: lo que tenía anotado este panel estaba viejo
					cambios[que] = 0
					local d = Tienda.datos()
					if d and typeof(d.bandeja) == "table" then
						d.bandeja[cosa] = nil
					end
				end
				Dialogo.aviso(if llego and typeof(r) == "table" and r.error then r.error else Cfg.MsgErrorGuardado)
				if sinCambio then
					ocupado = false
					Tienda.abrir(110, "Personaje")
					return
				end
			end
		end
		ocupado = false
	end
	-- Sin el producto a la venta (todavía no se cargó su número) y sin ninguno comprado, el botón no va: llevaría a
	-- una pestaña de la tienda que no existe. En Studio se ven siempre, para revisar la pantalla.
	local function ofrecer(clave: string, que: string): boolean
		local item = CfgTienda.item(clave)
		return RunService:IsStudio() or (item ~= nil and CfgTienda.enVenta(item)) or tengoCambio(que, clave)
	end
	if ofrecer("cambioNombre", "nombre") then
		local bNombre = Boton.nuevo(fondo, "Cambiar nombre", UDim2.fromOffset(608, 376), UDim2.fromOffset(113, 36), { tamTexto = 12, animado = true })
		bNombre.Name = "CambiarNombre"
		bNombre.ZIndex = 4
		Click.activado(bNombre, function()
			task.spawn(cambio, "nombre", "cambioNombre")
		end)
	end
	if ofrecer("cambioCara", "cara") then
		local bCara = Boton.nuevo(fondo, "Cambiar cara", UDim2.fromOffset(608, 477), UDim2.fromOffset(113, 36), { tamTexto = 12, animado = true })
		bCara.Name = "CambiarCara"
		bCara.ZIndex = 4
		Click.activado(bCara, function()
			task.spawn(cambio, "cara", "cambioCara")
		end)
	end
	if cuenta.probador then
		local bPrueba = Boton.nuevo(fondo, "Personaje de prueba", UDim2.fromOffset(56, 528), UDim2.fromOffset(129, 41), { tamTexto = 12, animado = true })
		bPrueba.ZIndex = 4
		Click.activado(bPrueba, function()
			if ocupado then
				return
			end
			ocupado = true
			gui.Enabled = false
			local clase = SelectorClase.elegir()
			pedido = { prueba = clase }
		end)
	end
	Click.activado(bEntrar, function()
		if ocupado then
			return
		end
		local p = lista[seleccionado]
		if not p then
			Dialogo.aviso(Cfg.MsgNoSeleccionado) -- ERROR_PERSONAJE_NO_SELECCIONADO
			return
		end
		entrar(p)
	end)
	Click.activado(bCrear, crear)
	Click.activado(bBorrar, function()
		if ocupado then
			return
		end
		local p = lista[seleccionado]
		if not p then
			Dialogo.aviso(Cfg.MsgNoSeleccionado)
			return
		end
		ocupado = true
		local si, escrito = Dialogo.confirmar(Cfg.MsgConfirmarBorrar, Cfg.MsgTituloBorrar, Cfg.MsgEscribirNombre)
		if si then
			local r = Remotes.funcion("BorrarPersonaje"):InvokeServer(p.id, escrito)
			if r and r.ok then
				lista = r.personajes
				seleccionado = 0
				for _, m in marcos do
					(m:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false
				end
				for _, l in datos do
					l.Text = ""
				end
				pintarLista()
			else
				Dialogo.aviso(if r and r.error then r.error else Cfg.MsgErrorGuardado)
			end
		end
		ocupado = false
	end)

	while not pedido do
		task.wait()
	end
	cerrar()
	return pedido
end

return PanelCuenta
