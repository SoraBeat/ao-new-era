--!strict
--[[
	Cantidad — el diálogo para tirar parte de una pila (frmCantidad.frm; DF11-05 A, docs/20 §5.4).

	Título "Escriba la cantidad", un campo que solo acepta dígitos y se recorta a 10000 (txtCantidad_Change), y los
	botones "Tirar" (lo escrito; vacío no hace nada) y "Tirar Todo" (la pila entera). Los dos cierran el diálogo.
	La "x" de la esquina es nuestra: en Roblox no hay otra forma cómoda de cerrarlo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Inventario)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Cantidad = {}

local gui: ScreenGui? = nil

function Cantidad.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function Cantidad.abierto(): boolean
	return gui ~= nil
end

-- total: lo que hay en el slot. alTirar(n) recibe la cantidad elegida. tope: hasta cuánto deja escribir (por
-- defecto 10000, el de una pila; el oro, sin tope desde la Fase 24, pasa lo que lleva: docs/43 §13)
function Cantidad.abrir(total: number, alTirar: (number) -> (), tope: number?)
	Cantidad.cerrar()
	local maximo = tope or Config.MaxObjs
	local g = Instance.new("ScreenGui")
	g.Name = "Cantidad"
	g.ResetOnSpawn = false
	g.DisplayOrder = 50
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(260, 130))
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	-- (un diálogo chico: se agranda hasta 1,5 y no ocupa más del 40 % del ancho, como antes)
	Encaje.ventana(caja, 260, 130, { techo = 1.5, parteAncho = 0.42 })

	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.fromOffset(0, 12)
	titulo.Size = UDim2.new(1, 0, 0, 20)
	titulo.Font = Enum.Font.ArialBold
	titulo.TextSize = 15
	titulo.TextColor3 = Boton.ColorTexto
	titulo.Text = "Escriba la cantidad"
	titulo.Parent = caja

	local campo = Instance.new("TextBox")
	campo.Name = "txtCantidad"
	campo.Position = UDim2.fromOffset(55, 40)
	campo.Size = UDim2.fromOffset(150, 26)
	campo.BackgroundColor3 = Color3.new(0, 0, 0)
	campo.BorderColor3 = Boton.ColorTexto
	campo.Font = Enum.Font.Arial
	campo.TextSize = 16
	campo.TextColor3 = Color3.new(1, 1, 1)
	campo.PlaceholderText = ""
	campo.Text = ""
	campo.ClearTextOnFocus = false
	campo.Parent = caja
	-- txtCantidad_KeyPress + _Change: solo dígitos, tope 10000
	campo:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.gsub(campo.Text, "%D", "")
		local n = tonumber(limpio)
		if n and n > maximo then
			limpio = string.format("%d", maximo)
		end
		if limpio ~= campo.Text then
			campo.Text = limpio
		end
	end)

	local bTirar = Boton.nuevo(caja, "Tirar", UDim2.fromOffset(20, 80), UDim2.fromOffset(100, 32), { tamTexto = 15 })
	local bTodo = Boton.nuevo(caja, "Tirar Todo", UDim2.fromOffset(140, 80), UDim2.fromOffset(100, 32), { tamTexto = 15 })
	Click.activado(bTirar, function()
		local n = tonumber(campo.Text)
		Cantidad.cerrar()
		if n and n > 0 then
			alTirar(n)
		end
	end)
	Click.activado(bTodo, function()
		Cantidad.cerrar()
		alTirar(math.min(total, maximo))
	end)

	local cerrar = Instance.new("TextButton")
	cerrar.BackgroundTransparency = 1
	cerrar.AnchorPoint = Vector2.new(1, 0)
	cerrar.Position = UDim2.new(1, -6, 0, 4)
	cerrar.Size = UDim2.fromOffset(20, 20)
	cerrar.Font = Enum.Font.ArialBold
	cerrar.TextSize = 16
	cerrar.TextColor3 = Boton.ColorTexto
	cerrar.Text = "x"
	cerrar.Parent = caja
	Click.activado(cerrar, Cantidad.cerrar)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
	campo:CaptureFocus()
end

return Cantidad
