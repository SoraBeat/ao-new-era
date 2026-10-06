--!strict
--[[
	Entrenador — la ventana del entrenador (Fase 20, docs/39 §4.2; frmEntrenador del cliente original:
	VentanaEntrenador.jpg, 282 × 245).

	Se abre con /ENTRENAR o con doble click sobre el entrenador: el servidor manda la lista de nombres (evento
	Entrenador, "lista"). Arriba el título, en el recuadro la lista y abajo "Luchar" y "Salir", en las posiciones del
	.frm. "Luchar" manda la posición elegida (evento Entrenar). A diferencia del original, la ventana queda abierta
	después de "Luchar" (D20-28 A): allá hay que volver a escribir el comando para cada criatura.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Cfg = require(ReplicatedStorage.Shared.Config.Entrenador)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Ventana = require(script.Parent.Ventana)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)

local Entrenador = {}

local FILA = 16
local COLOR_TITULO = Color3.fromRGB(255, 192, 128) -- &H0080C0FF& (frmEntrenador.frm)
local COLOR_ELEGIDA = Color3.fromRGB(60, 80, 140)

local gui: ScreenGui? = nil

function Entrenador.abierta(): boolean
	return gui ~= nil
end

function Entrenador.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function abrir(nombres: { string })
	Entrenador.cerrar()
	-- Queda abierta mientras se pelea: va contra el borde izquierdo y no pasa del 30 % del ancho, para no tapar al
	-- personaje (que está en el centro de la vista)
	local g, fondo = Ventana.crear("Entrenador", UiAssets.entrenador, 282, 245, { izquierda = 12, parteAncho = 0.3 })
	gui = g
	Ventana.label(fondo, Cfg.Msg.titulo, 40, 8, 201, 41, {
		TextSize = 15, TextColor3 = COLOR_TITULO, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
	})
	-- La lista (lstCriaturas: 58, 45, 157 × 145; fondo negro, letra blanca)
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.BackgroundColor3 = Color3.new(0, 0, 0)
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(58, 45)
	lista.Size = UDim2.fromOffset(157, 145)
	lista.CanvasSize = UDim2.fromOffset(0, #nombres * FILA)
	lista.ScrollBarThickness = 6
	lista.ZIndex = 3
	lista.Parent = fondo
	local elegida = 1
	local filas: { TextButton } = {}
	local function pintar()
		for i, f in filas do
			f.BackgroundTransparency = if i == elegida then 0 else 1
		end
	end
	for i, nombre in nombres do
		local f = Instance.new("TextButton")
		f.Name = `Fila{i}`
		f.AutoButtonColor = false
		f.BackgroundColor3 = COLOR_ELEGIDA
		f.BorderSizePixel = 0
		f.Position = UDim2.fromOffset(0, (i - 1) * FILA)
		f.Size = UDim2.new(1, 0, 0, FILA)
		f.Font = Enum.Font.ArialBold
		f.TextSize = 12
		f.TextColor3 = Color3.new(1, 1, 1)
		f.TextXAlignment = Enum.TextXAlignment.Left
		f.Text = " " .. nombre
		f.ZIndex = 4
		f.Parent = lista
		Click.activado(f, function()
			elegida = i
			pintar()
		end)
		filas[i] = f
	end
	pintar()
	local evEntrenar = Remotes.evento("Entrenar")
	local luchar = Boton.nuevo(fondo, "Luchar", UDim2.fromOffset(40, 208), UDim2.fromOffset(97, 25), { tamTexto = 14 })
	luchar.ZIndex = 3
	Click.activado(luchar, function()
		evEntrenar:FireServer(elegida)
	end)
	local salir = Boton.nuevo(fondo, "Salir", UDim2.fromOffset(144, 208), UDim2.fromOffset(97, 25), { tamTexto = 14 })
	salir.ZIndex = 3
	Click.activado(salir, Entrenador.cerrar)
end

function Entrenador.iniciar()
	Remotes.evento("Entrenador").OnClientEvent:Connect(function(que: string, d: any)
		if que == "lista" and typeof(d) == "table" then
			abrir(d)
		elseif que == "cerrar" then
			Entrenador.cerrar()
		end
	end)
end

return Entrenador
