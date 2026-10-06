--!strict
--[[
	Opciones — la ventana de opciones (paquete P2, docs/29 §5; frmOpciones del original, solo la parte de audio).

	- Música y Sonidos: prendido / apagado y volumen (0 a 100 %, en dB de -30 a 0; el 0 silencia). La barra se arrastra
	  con el mouse o el dedo; los botones − y + la mueven de a 10 (para el mando, que no arrastra: docs/37 §7.3).
	- Fase 20 (docs/39 §8): debajo de Sonidos, el volumen de sus tres grupos (combate y hechizos, ambiente y pasos,
	  interfaz); el de Sonidos los multiplica.
	- "Ver la noche" (Fase 18, docs/37 §5.2, DA18-12 A): el color del día es solo visual y se puede apagar. Va guardado
	  con el audio.
	- "Configurar teclas" abre la ventana de teclas de antes; "Controles del mando" muestra el mapa de botones del
	  gamepad (docs/37 §7.4); "Cerrar".
	- La abren el botón Opciones y la tecla de opciones (F5). M y N prenden y apagan la música y los sonidos.
	- Fase 33 (docs/53 §5): en el celular, dos barras más: qué tan visibles son el minimapa y los botones (las flechas
	  y los de acción). Con el minimapa en 0 % se esconde. Se guardan con lo demás.
	- Fase 38 (docs/58): en el celular, "Acomodar la interfaz" (en el lugar de "Configurar teclas", que ahí no va)
	  abre la pantalla de mover, achicar, esconder y sumar piezas (client/UI/HudEditor).
	- Se guarda en el servidor con las preferencias (remote GuardarAudio, como mucho una vez por segundo); al entrar
	  al juego llega lo guardado (remote Audio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local ConfigMando = require(ReplicatedStorage.Shared.Config.Mando)
local ConfigTactil = require(ReplicatedStorage.Shared.Config.Tactil)
local Boton = require(script.Parent.Boton)
local ConfigTeclas = require(script.Parent.ConfigTeclas)
local Sonido = require(script.Parent.Parent.Audio.Sonido)
local Musica = require(script.Parent.Parent.Audio.Musica)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Opciones = {}

export type Audio = {
	musica: boolean, volMusica: number, sonidos: boolean, volSonidos: number, noche: boolean,
	volCombate: number, volAmbiente: number, volInterfaz: number,
	sinIntercambio: boolean, -- Fase 22 (docs/41 §5.2): no recibir pedidos de intercambio
	opMini: number, opBotones: number, -- Fase 33 (docs/53 §5): opacidad del minimapa y de los botones del celular (%)
	velPuntero: number, -- Fase 34 (docs/54 §4): velocidad del puntero del mando (%)
}

local estado: Audio = {
	musica = true, volMusica = 80, sonidos = true, volSonidos = 100, noche = true,
	volCombate = 100, volAmbiente = 100, volInterfaz = 100,
	sinIntercambio = false,
	opMini = ConfigTactil.OpMini, opBotones = ConfigTactil.OpBotones,
	velPuntero = ConfigMando.Vel,
}
local gui: ScreenGui? = nil
local conexiones: { RBXScriptConnection } = {}
local refrescar: (() -> ())? = nil
local ANCHO, ALTO_BASE = 410, 500 -- Fase 23: una fila más de botones (Reglas); Fase 25: otra (Guía y Cambiar de personaje)
local ALTO_TACTIL = 76 -- Fase 33: en el celular, el título y las dos barras de transparencia

-- Lo pone Main: escribe en la consola
Opciones.aviso = nil :: ((string) -> ())?
-- Lo pone Main (Fase 22, docs/41 §6): "Ver el tutorial"
Opciones.alTutorial = nil :: (() -> ())?
-- Lo pone Main (Fase 23, docs/42 §5.5): "Reglas del juego"
Opciones.alReglas = nil :: (() -> ())?
-- Fase 25 (docs/44 §11 y §9): los ponen Main: abrir la guía del juego y pedir /SALIR
Opciones.alGuia = nil :: (() -> ())?
Opciones.alSalir = nil :: (() -> ())?
-- Lo pone Main: "Ver la noche" cambió (Render/Clima)
Opciones.alCambiarNoche = nil :: ((boolean) -> ())?
-- Fase 33 (docs/53 §5): los pone Main. Si la interfaz es la del celular, y qué hacer cuando cambia la transparencia
-- (opacidad del minimapa y de los botones, en %)
Opciones.esTactil = nil :: (() -> boolean)?
Opciones.alCambiarTactil = nil :: ((number, number) -> ())?
-- Fase 34 (docs/54 §4): lo pone Main. La velocidad del puntero del mando, en %
Opciones.alCambiarPuntero = nil :: ((number) -> ())?
-- Fase 38 (docs/58): lo pone Main. Abre la pantalla de acomodar la interfaz del celular
Opciones.alAcomodar = nil :: (() -> ())?

local function aplicar()
	Musica.setOpciones(estado.musica, estado.volMusica)
	Sonido.setOpciones(estado.sonidos, estado.volSonidos, {
		combate = estado.volCombate, ambiente = estado.volAmbiente, interfaz = estado.volInterfaz,
	})
	local noche = Opciones.alCambiarNoche
	if noche then
		noche(estado.noche)
	end
	local tactil = Opciones.alCambiarTactil
	if tactil then
		tactil(estado.opMini, estado.opBotones)
	end
	local puntero = Opciones.alCambiarPuntero
	if puntero then
		puntero(estado.velPuntero)
	end
	local f = refrescar
	if f then
		f()
	end
end

local guardarPendiente = false
local function guardar()
	if guardarPendiente then
		return
	end
	guardarPendiente = true
	task.delay(1, function()
		guardarPendiente = false
		Remotes.evento("GuardarAudio"):FireServer(table.clone(estado))
	end)
end

-- Lo guardado, al entrar al juego (nil = nunca se guardó: las de fábrica)
function Opciones.recibir(a: any)
	if typeof(a) == "table" then
		estado.musica = a.musica ~= false
		estado.sonidos = a.sonidos ~= false
		estado.volMusica = tonumber(a.volMusica) or estado.volMusica
		estado.volSonidos = tonumber(a.volSonidos) or estado.volSonidos
		estado.noche = a.noche ~= false
		estado.sinIntercambio = a.sinIntercambio == true
		for _, k in { "volCombate", "volAmbiente", "volInterfaz" } do -- las guardadas antes de la Fase 20 no los traen
			(estado :: any)[k] = math.clamp(tonumber(a[k]) or 100, 0, 100)
		end
		estado.opMini, estado.opBotones = ConfigTactil.opMini(a.opMini), ConfigTactil.opBotones(a.opBotones)
		estado.velPuntero = ConfigMando.vel(a.velPuntero)
	end
	aplicar()
end

function Opciones.estado(): Audio
	return table.clone(estado)
end

-- Las teclas M y N (mKeyToggleMusic / mKeyToggleSound)
function Opciones.alternar(cual: string)
	if cual == "musica" then
		estado.musica = not estado.musica
	else
		estado.sonidos = not estado.sonidos
	end
	aplicar()
	guardar()
	local f = Opciones.aviso
	if f then
		local prendido = if cual == "musica" then estado.musica else estado.sonidos
		f(`{if cual == "musica" then "Música" else "Sonidos"} {if prendido then "activados" else "desactivados"}.`)
	end
end

function Opciones.abierta(): boolean
	return gui ~= nil
end

function Opciones.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
	for _, c in conexiones do
		c:Disconnect()
	end
	table.clear(conexiones)
	refrescar = nil
end

local function texto(parent: Instance, t: string, x: number, y: number, w: number, h: number, alineacion: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 14
	l.TextColor3 = Boton.ColorTexto
	l.TextXAlignment = alineacion or Enum.TextXAlignment.Left
	l.Text = t
	l.ZIndex = 3
	l.Parent = parent
	return l
end

-- Una barra de volumen 0..100 que se arrastra con el mouse o el dedo
local function barra(parent: Instance, nombre: string, x: number, y: number, w: number, leer: () -> number, cambiar: (number) -> ()): () -> ()
	local fondo = Instance.new("TextButton")
	fondo.Name = nombre
	fondo.Text = ""
	fondo.AutoButtonColor = false
	fondo.BackgroundColor3 = Color3.fromRGB(25, 20, 14)
	fondo.BorderSizePixel = 0
	fondo.Position = UDim2.fromOffset(x, y)
	fondo.Size = UDim2.fromOffset(w, 12)
	fondo.ZIndex = 3
	fondo:SetAttribute("SinClick", true)
	fondo.Parent = parent
	local borde = Instance.new("UIStroke")
	borde.Color = Boton.ColorTexto
	borde.Transparency = 0.5
	borde.Parent = fondo
	local lleno = Instance.new("Frame")
	lleno.Name = "Lleno"
	lleno.BackgroundColor3 = Color3.fromRGB(178, 155, 111)
	lleno.BorderSizePixel = 0
	lleno.Size = UDim2.fromScale(0, 1)
	lleno.ZIndex = 4
	lleno.Parent = fondo
	local pct = texto(parent, "", x + w + 36, y - 3, 44, 18)
	local function pintar()
		local v = leer()
		lleno.Size = UDim2.fromScale(v / 100, 1)
		pct.Text = `{v}%`
	end
	local arrastrando: InputObject? = nil
	local function desde(pos: Vector3)
		local a = fondo.AbsolutePosition.X
		local b = fondo.AbsoluteSize.X
		local v = math.clamp(math.floor((pos.X - a) / math.max(b, 1) * 100 + 0.5), 0, 100)
		cambiar(v)
		pintar()
	end
	fondo.InputBegan:Connect(function(i: InputObject)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			arrastrando = i
			desde(i.Position)
		end
	end)
	-- El mando (Fase 34, docs/54 §4): A sobre la barra la lleva hasta el puntero
	Click.aprieta(fondo, function(p: Vector2)
		desde(Vector3.new(p.X, p.Y, 0))
		guardar()
	end)
	table.insert(conexiones, UserInputService.InputChanged:Connect(function(i: InputObject)
		if arrastrando and (i.UserInputType == Enum.UserInputType.MouseMovement or i == arrastrando) then
			desde(i.Position)
		end
	end))
	table.insert(conexiones, UserInputService.InputEnded:Connect(function(i: InputObject)
		if arrastrando and (i == arrastrando or i.UserInputType == Enum.UserInputType.MouseButton1) then
			arrastrando = nil
			guardar()
		end
	end))
	pintar()
	return pintar
end

-- La tabla de botones del gamepad (docs/37 §7.2 y §7.4): solo se lee; "Volver" regresa a Opciones
local function abrirMando(controlador: any)
	Opciones.cerrar()
	local filas = 0
	for _, seccion in ConfigMando.Tabla do
		filas += 1 + #seccion[2]
	end
	local ancho, fila = 590, 18
	local alto = 50 + filas * fila + #ConfigMando.Tabla * 6 + 56 + 34 -- (+ la fila de la velocidad del puntero)
	local g = Instance.new("ScreenGui")
	g.Name = "ControlesMando"
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(ancho, alto))
	caja.Name = "Caja"
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	Encaje.ventana(caja, ancho, alto)
	local titulo = texto(caja, "Controles del mando", 0, 14, ancho, 20, Enum.TextXAlignment.Center)
	titulo.TextSize = 17
	local y = 46
	for _, seccion in ConfigMando.Tabla do
		local t = texto(caja, seccion[1], 20, y, ancho - 40, fila)
		t.TextColor3 = Color3.new(1, 1, 1)
		y += fila
		for _, par in seccion[2] do
			local b = texto(caja, par[1], 30, y, 170, fila)
			b.TextSize = 12
			local q = texto(caja, par[2], 204, y, ancho - 220, fila)
			q.Font = Enum.Font.Arial
			q.TextSize = 12
			q.TextColor3 = Color3.fromRGB(235, 225, 205)
			y += fila
		end
		y += 6
	end
	-- Fase 34 (docs/54 §4): la velocidad del puntero, de a 10 %
	texto(caja, "Velocidad del puntero", 30, y + 6, 170, 22)
	local cuanto = texto(caja, `{estado.velPuntero} %`, 232, y + 6, 60, 22, Enum.TextXAlignment.Center)
	cuanto.Name = "VelPuntero"
	cuanto.TextColor3 = Color3.new(1, 1, 1)
	for _, par in { { "-", 204, -ConfigMando.VelPaso }, { "+", 296, ConfigMando.VelPaso } } do
		local bv = Boton.nuevo(caja, par[1] :: string, UDim2.fromOffset(par[2] :: number, y + 6), UDim2.fromOffset(24, 22), { tamTexto = 15 })
		bv.Name = (if par[1] == "-" then "Menos" else "Mas") .. "Puntero"
		bv.ZIndex = 3
		Click.activado(bv, function()
			estado.velPuntero = ConfigMando.vel(estado.velPuntero + (par[3] :: number))
			cuanto.Text = `{estado.velPuntero} %`
			aplicar()
			guardar()
		end)
	end
	local bVolver = Boton.nuevo(caja, "Volver", UDim2.fromOffset((ancho - 120) / 2, alto - 46), UDim2.fromOffset(120, 30), { tamTexto = 14 })
	bVolver.Name = "Volver"
	bVolver.ZIndex = 3
	Click.activado(bVolver, function()
		Opciones.abrir(controlador)
	end)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

function Opciones.abrir(controlador: any)
	Opciones.cerrar()
	local esTactil = Opciones.esTactil
	local tactil = esTactil ~= nil and esTactil()
	local ALTO = ALTO_BASE + (if tactil then ALTO_TACTIL else 0)
	local g = Instance.new("ScreenGui")
	g.Name = "Opciones"
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(ANCHO, ALTO))
	caja.Name = "Caja"
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	Encaje.ventana(caja, ANCHO, ALTO)

	local titulo = texto(caja, "Opciones", 0, 14, ANCHO, 20, Enum.TextXAlignment.Center)
	titulo.TextSize = 17

	local function fila(y: number, nombre: string, clave: string, claveVol: string): () -> ()
		texto(caja, nombre, 24, y, 90, 24)
		local b = Boton.nuevo(caja, "", UDim2.fromOffset(110, y), UDim2.fromOffset(84, 24), { tamTexto = 13 })
		b.Name = clave
		b.ZIndex = 3
		local pintarBarra = barra(caja, "Vol" .. clave, 232, y + 6, 90, function()
			return (estado :: any)[claveVol]
		end, function(v: number)
			(estado :: any)[claveVol] = v
			aplicar()
		end)
		-- − y +: de a 10 (docs/37 §7.3)
		for _, par in { { "-", 204, -10 }, { "+", 326, 10 } } do
			local bv = Boton.nuevo(caja, par[1] :: string, UDim2.fromOffset(par[2] :: number, y), UDim2.fromOffset(24, 24), { tamTexto = 15 })
			bv.Name = (if par[1] == "-" then "Menos" else "Mas") .. clave
			bv.ZIndex = 3
			Click.activado(bv, function()
				(estado :: any)[claveVol] = math.clamp((estado :: any)[claveVol] + (par[3] :: number), 0, 100)
				aplicar()
				guardar()
			end)
		end
		local function pintar()
			Boton.texto(b, if (estado :: any)[clave] then "Prendida" else "Apagada")
			pintarBarra()
		end
		Click.activado(b, function()
			(estado :: any)[clave] = not (estado :: any)[clave]
			aplicar()
			guardar()
		end)
		return pintar
	end
	local pMusica = fila(56, "Música", "musica", "volMusica")
	local pSonidos = fila(96, "Sonidos", "sonidos", "volSonidos")

	-- Fase 20 (docs/39 §8): el volumen de cada grupo de sonidos, sin botón de prender y apagar
	local function subfila(y: number, nombre: string, claveVol: string): () -> ()
		local l = texto(caja, nombre, 40, y, 160, 22)
		l.Font = Enum.Font.Arial
		l.TextSize = 13
		local pintarBarra = barra(caja, "Vol" .. claveVol, 232, y + 5, 90, function()
			return (estado :: any)[claveVol]
		end, function(v: number)
			(estado :: any)[claveVol] = v
			aplicar()
		end)
		for _, par in { { "-", 204, -10 }, { "+", 326, 10 } } do
			local bv = Boton.nuevo(caja, par[1] :: string, UDim2.fromOffset(par[2] :: number, y), UDim2.fromOffset(24, 22), { tamTexto = 15 })
			bv.Name = (if par[1] == "-" then "Menos" else "Mas") .. claveVol
			bv.ZIndex = 3
			Click.activado(bv, function()
				(estado :: any)[claveVol] = math.clamp((estado :: any)[claveVol] + (par[3] :: number), 0, 100)
				aplicar()
				guardar()
			end)
		end
		return pintarBarra
	end
	local pCombate = subfila(128, "Combate y hechizos", "volCombate")
	local pAmbiente = subfila(154, "Ambiente y pasos", "volAmbiente")
	local pInterfaz = subfila(180, "Interfaz", "volInterfaz")

	local nota = texto(caja, "M y N los prenden y apagan durante el juego.", 0, 210, ANCHO, 16, Enum.TextXAlignment.Center)
	nota.Font = Enum.Font.Arial
	nota.TextSize = 12

	-- Ver la noche (docs/37 §5.2)
	texto(caja, "Noche", 24, 240, 90, 24)
	local bNoche = Boton.nuevo(caja, "", UDim2.fromOffset(110, 240), UDim2.fromOffset(84, 24), { tamTexto = 13 })
	bNoche.Name = "noche"
	bNoche.ZIndex = 3
	local notaNoche = texto(caja, "Solo cambia como se ve el mapa.", 204, 240, ANCHO - 214, 24)
	notaNoche.Font = Enum.Font.Arial
	notaNoche.TextSize = 12
	Click.activado(bNoche, function()
		estado.noche = not estado.noche
		aplicar()
		guardar()
	end)
	-- Pedidos de intercambio (Fase 22, docs/41 §5.2): el que no quiere que le pidan, los apaga
	texto(caja, "Intercambio", 24, 272, 90, 24)
	local bInter = Boton.nuevo(caja, "", UDim2.fromOffset(110, 272), UDim2.fromOffset(84, 24), { tamTexto = 13 })
	bInter.Name = "sinIntercambio"
	bInter.ZIndex = 3
	local notaInter = texto(caja, "Los pedidos de otros jugadores.", 204, 272, ANCHO - 214, 24)
	notaInter.Font = Enum.Font.Arial
	notaInter.TextSize = 12
	Click.activado(bInter, function()
		estado.sinIntercambio = not estado.sinIntercambio
		aplicar()
		guardar()
	end)
	-- Fase 33 (docs/53 §5): solo en el celular, qué tan visibles son el minimapa y los botones
	local pintarTactil: { () -> () } = {}
	if tactil then
		local cab = texto(caja, "Transparencia en pantalla (100 % = se ve del todo)", 24, 304, ANCHO - 48, 16)
		cab.Font = Enum.Font.Arial
		cab.TextSize = 12
		for i, d in { { "Minimapa", "opMini", 0 }, { "Botones", "opBotones", ConfigTactil.OpBotonesMin } } do
			local y = 324 + (i - 1) * 26
			local clave, minimo = d[2] :: string, d[3] :: number
			texto(caja, d[1] :: string, 24, y, 160, 22)
			local function poner(v: number)
				(estado :: any)[clave] = math.clamp(v, minimo, 100)
				aplicar()
			end
			table.insert(pintarTactil, barra(caja, "Barra" .. clave, 232, y + 5, 90, function()
				return (estado :: any)[clave]
			end, poner))
			for _, par in { { "-", 204, -ConfigTactil.Paso }, { "+", 326, ConfigTactil.Paso } } do
				local bv = Boton.nuevo(caja, par[1] :: string, UDim2.fromOffset(par[2] :: number, y), UDim2.fromOffset(24, 22), { tamTexto = 15 })
				bv.Name = (if par[1] == "-" then "Menos" else "Mas") .. clave
				bv.ZIndex = 3
				Click.activado(bv, function()
					poner((estado :: any)[clave] + (par[3] :: number))
					guardar()
				end)
			end
		end
	end
	refrescar = function()
		for _, p in pintarTactil do
			p()
		end
		Boton.texto(bInter, if estado.sinIntercambio then "No recibo" else "Recibo")
		pMusica()
		pSonidos()
		pCombate()
		pAmbiente()
		pInterfaz()
		Boton.texto(bNoche, if estado.noche then "Se ve" else "No se ve")
	end

	local bTeclas = Boton.nuevo(caja, "Configurar teclas", UDim2.fromOffset(24, ALTO - 140), UDim2.fromOffset(170, 32), { tamTexto = 14 })
	local bCerrar = Boton.nuevo(caja, "Cerrar", UDim2.fromOffset(ANCHO - 24 - 190, ALTO - 56), UDim2.fromOffset(190, 32), { tamTexto = 14 })
	local bTutorial = Boton.nuevo(caja, "Ver el tutorial", UDim2.fromOffset(24, ALTO - 98), UDim2.fromOffset(170, 32), { tamTexto = 14 })
	bTutorial.Name = "VerTutorial"
	bTutorial.ZIndex = 3
	Click.activado(bTutorial, function()
		Opciones.cerrar()
		local f = Opciones.alTutorial
		if f then
			f()
		end
	end)
	-- Fase 23 (docs/42 §5.5, D23-27 A): las reglas del juego
	local bReglas = Boton.nuevo(caja, "Reglas del juego", UDim2.fromOffset(24, ALTO - 182), UDim2.fromOffset(170, 32), { tamTexto = 14 })
	bReglas.Name = "Reglas"
	bReglas.ZIndex = 3
	Click.activado(bReglas, function()
		Opciones.cerrar()
		local f = Opciones.alReglas
		if f then
			f()
		end
	end)
	-- Fase 25 (docs/44 §11): la guía del juego (lo principal de la wiki, sin salir del juego)
	local bGuia = Boton.nuevo(caja, "Guía del juego", UDim2.fromOffset(ANCHO - 24 - 190, ALTO - 182), UDim2.fromOffset(190, 32), { tamTexto = 14 })
	bGuia.Name = "Guia"
	bGuia.ZIndex = 3
	Click.activado(bGuia, function()
		Opciones.cerrar()
		local f = Opciones.alGuia
		if f then
			f()
		end
	end)
	-- Fase 25 (docs/44 §9): volver a la pantalla de personajes (lo mismo que /SALIR)
	local bSalir = Boton.nuevo(caja, "Cambiar de personaje", UDim2.fromOffset(ANCHO - 24 - 190, ALTO - 98), UDim2.fromOffset(190, 32), { tamTexto = 14 })
	bSalir.Name = "CambiarPersonaje"
	bSalir.ZIndex = 3
	Click.activado(bSalir, function()
		Opciones.cerrar()
		local f = Opciones.alSalir
		if f then
			f()
		end
	end)
	local bMando = Boton.nuevo(caja, "Controles del mando", UDim2.fromOffset(ANCHO - 24 - 190, ALTO - 140), UDim2.fromOffset(190, 32), { tamTexto = 14 })
	bMando.Name = "ControlesMando"
	bMando.ZIndex = 3
	Click.activado(bMando, function()
		abrirMando(controlador)
	end)
	bTeclas.Name, bCerrar.Name = "ConfigurarTeclas", "Cerrar"
	-- sin teclado no hay teclas que configurar; y en la interfaz del celular ese lugar es de "Acomodar la interfaz"
	bTeclas.Visible = game:GetService("UserInputService").KeyboardEnabled and not tactil
	if tactil then
		local bAcomodar = Boton.nuevo(caja, "Acomodar la interfaz", UDim2.fromOffset(24, ALTO - 140), UDim2.fromOffset(170, 32), { tamTexto = 14 })
		bAcomodar.Name = "AcomodarInterfaz"
		bAcomodar.ZIndex = 3
		Click.activado(bAcomodar, function()
			Opciones.cerrar()
			local f = Opciones.alAcomodar
			if f then
				f()
			end
		end)
	end
	bTeclas.ZIndex, bCerrar.ZIndex = 3, 3
	Click.activado(bTeclas, function()
		Opciones.cerrar()
		ConfigTeclas.abrir(controlador)
	end)
	Click.activado(bCerrar, Opciones.cerrar)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	aplicar()
end

function Opciones.alternarVentana(controlador: any)
	if gui then
		Opciones.cerrar()
	elseif ConfigTeclas.abierta() then
		ConfigTeclas.cerrar(controlador)
	else
		Opciones.abrir(controlador)
	end
end

return Opciones
