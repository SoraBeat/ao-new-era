--!strict
--[[
	ConfigTeclas — la ventana para configurar las teclas (frmCustomKeys.frm; DF11-03 C y DF11-04 A, docs/20 §4.3).

	Mientras está abierta, el juego no toma teclas. Una fila por acción con su tecla. Click en la tecla → "Apretá una tecla…" y toma la próxima. Si la tecla ya
	la usa otra acción, esa casilla queda vacía y parpadea en rojo (el beep del original, frmCustomKeys.frm:733-758).
	Las teclas que no se pueden asignar se ignoran. Abajo: "Flechas" y "WASD" (los juegos de fábrica), "Guardar" y
	"Cerrar". Guardar con alguna vacía muestra "Hay una o mas teclas invalidas. Por favor verifique."
	(CUSTOMKEYS_TECLA_INVALIDA). Se abre con la tecla de Opciones (F5) o el botón Opciones de la ventana principal.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Teclas = require(ReplicatedStorage.Shared.Config.Teclas)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Boton = require(script.Parent.Boton)
local Consola = require(script.Parent.Consola)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local ConfigTeclas = {}

local FILA = 26
local ANCHO = 380

local gui: ScreenGui? = nil
local conexion: RBXScriptConnection? = nil

function ConfigTeclas.cerrar(controlador: any)
	if conexion then
		conexion:Disconnect()
		conexion = nil
	end
	controlador.capturando = false
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function ConfigTeclas.abierta(): boolean
	return gui ~= nil
end

local function texto(parent: Instance, t: string, pos: UDim2, tam: UDim2, alineacion: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = tam
	l.Font = Enum.Font.ArialBold
	l.TextSize = 14
	l.TextColor3 = Boton.ColorTexto
	l.TextXAlignment = alineacion or Enum.TextXAlignment.Left
	l.Text = t
	l.Parent = parent
	return l
end

function ConfigTeclas.abrir(controlador: any)
	ConfigTeclas.cerrar(controlador)
	local edicion: { [string]: string? } = controlador.teclas()

	local g = Instance.new("ScreenGui")
	g.Name = "ConfigTeclas"
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local alto = 50 + #Teclas.Acciones * FILA + 90
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(ANCHO, alto))
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	-- (Fase 22: con los diez atajos la lista es más alta; se achica lo que haga falta para que entre. Fase 35: y
	-- si ni así entra, se corre)
	Encaje.ventana(caja, ANCHO, alto, { techo = 1.1 })

	local titulo = texto(caja, "Configurar teclas", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 20), Enum.TextXAlignment.Center)
	titulo.TextSize = 17

	local botones: { [string]: ImageButton } = {}
	local esperando: string? = nil

	local function pintar()
		for id, b in botones do
			Boton.texto(b, if esperando == id then "Apretá una tecla…" else Teclas.mostrar(edicion[id]))
		end
	end

	local function parpadear(b: ImageButton)
		task.spawn(function()
			for _ = 1, 3 do
				b.ImageColor3 = Color3.fromRGB(255, 80, 80)
				task.wait(0.12)
				b.ImageColor3 = Color3.new(1, 1, 1)
				task.wait(0.12)
			end
		end)
	end

	for i, a in Teclas.Acciones do
		local y = 44 + (i - 1) * FILA
		texto(caja, a.nombre, UDim2.fromOffset(24, y), UDim2.fromOffset(190, FILA - 2))
		local b = Boton.nuevo(caja, "", UDim2.fromOffset(ANCHO - 24 - 150, y), UDim2.fromOffset(150, FILA - 2), { tamTexto = 13 })
		b.Name = a.id
		botones[a.id] = b
		Click.activado(b, function()
			esperando = a.id
			pintar()
		end)
	end

	local aviso = texto(caja, "", UDim2.fromOffset(0, alto - 86), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center)
	aviso.TextColor3 = Color3.fromRGB(255, 80, 80)
	aviso.TextSize = 12

	local yb = alto - 64
	local bFlechas = Boton.nuevo(caja, "Flechas", UDim2.fromOffset(20, yb), UDim2.fromOffset(80, 30), { tamTexto = 14 })
	local bWasd = Boton.nuevo(caja, "WASD", UDim2.fromOffset(106, yb), UDim2.fromOffset(80, 30), { tamTexto = 14 })
	local bGuardar = Boton.nuevo(caja, "Guardar", UDim2.fromOffset(194, yb), UDim2.fromOffset(80, 30), { tamTexto = 14 })
	local bCerrar = Boton.nuevo(caja, "Cerrar", UDim2.fromOffset(280, yb), UDim2.fromOffset(80, 30), { tamTexto = 14 })
	local function cargar(juego: string)
		edicion = Teclas.copia(Teclas.Juegos[juego])
		esperando = nil
		aviso.Text = ""
		pintar()
	end
	Click.activado(bFlechas, function()
		cargar("flechas")
	end)
	Click.activado(bWasd, function()
		cargar("wasd")
	end)
	Click.activado(bGuardar, function()
		for _, a in Teclas.Acciones do
			if not edicion[a.id] then
				aviso.Text = "Hay una o mas teclas invalidas. Por favor verifique." -- CUSTOMKEYS_TECLA_INVALIDA
				return
			end
		end
		local t = edicion :: Teclas.Mapa
		controlador.setTeclas(t)
		Remotes.evento("GuardarTeclas"):FireServer(t)
		Consola.agregar("Configuración de teclas guardada.", "info")
		ConfigTeclas.cerrar(controlador)
	end)
	Click.activado(bCerrar, function()
		ConfigTeclas.cerrar(controlador)
	end)

	-- Text1_KeyDown (frmCustomKeys.frm:733-758): la tecla que ya usa otra acción se rechaza
	conexion = UserInputService.InputBegan:Connect(function(input)
		local id = esperando
		if not id or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local nombre = Teclas.desdeKeyCode(input.KeyCode)
		if not nombre then
			return -- no se puede asignar: se sigue esperando
		end
		esperando = nil
		for otro, tecla in edicion do
			if otro ~= id and tecla == nombre then
				edicion[id] = nil
				pintar()
				parpadear(botones[id])
				return
			end
		end
		edicion[id] = nombre
		aviso.Text = ""
		pintar()
	end)

	pintar()
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	controlador.capturando = true -- con la ventana abierta el juego no toma teclas (como el formulario del original)
end

function ConfigTeclas.alternar(controlador: any)
	if gui then
		ConfigTeclas.cerrar(controlador)
	else
		ConfigTeclas.abrir(controlador)
	end
end

return ConfigTeclas
