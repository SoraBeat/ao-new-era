--!strict
--[[
	Alineacion — la ventana para elegir ciudadano, neutral o criminal (docs/23 DN-02 A).

	El fondo es el de fundar clan del original (frmEligeAlineacion, VentanaFundarClan.jpg, 449×352) con tres de sus
	cinco figuras; cada opción es el título en su color y el texto debajo, en las posiciones del .frm (Legal, Neutral
	y Criminal). Tocar una pide confirmar.

	Fase 26 (docs/46 §3.3, pedido del autor): es obligatoria. No hay "Más tarde": tapa la pantalla y no se cierra
	hasta elegir (mientras tanto el personaje queda fuera del PvP).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Alineacion)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local Boton = require(script.Parent.Boton)
local Dialogo = require(script.Parent.Dialogo)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Alineacion = {}

-- Lo pone Main: el jugador eligió (Fase 25: se apaga el botón "Elegí tu camino")
Alineacion.alElegir = nil :: (() -> ())?

local ANCHO, ALTO = 449, 352
-- Top de cada título (frmEligeAlineacion.frm: lblTitleLegal 1080, lblTitleNeutral 2040, lblTitleCriminal 3000 twips)
local FILAS = { 72, 136, 200 }

local gui: ScreenGui? = nil

function Alineacion.abierta(): boolean
	return gui ~= nil
end

function Alineacion.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function Alineacion.abrir()
	Alineacion.cerrar()
	local g = Instance.new("ScreenGui")
	g.Name = "Alineacion"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 90
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- El velo: oscurece el juego y se queda con los clicks, para que la ventana no se pueda saltear
	local velo = Instance.new("TextButton")
	velo.Name = "Velo"
	velo.Text = ""
	velo.AutoButtonColor = false
	velo.Selectable = false -- que el mando no lo elija: solo las tres opciones
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 0.45
	velo.BorderSizePixel = 0
	velo.Size = UDim2.fromScale(1, 1)
	velo.Parent = g
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Ventana"
	fondo.BackgroundTransparency = 1
	fondo.Image = UiAssets.alineacion
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(ANCHO, ALTO)
	fondo.Parent = g
	Encaje.ventana(fondo, ANCHO, ALTO, { techo = 1.4 })

	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.fromOffset(0, 22)
	titulo.Size = UDim2.new(1, 0, 0, 24)
	titulo.Font = Enum.Font.ArialBold
	titulo.TextSize = 18
	titulo.TextColor3 = Color3.fromRGB(255, 255, 225)
	titulo.Text = Config.TituloVentana
	titulo.Parent = fondo

	for i, op in Config.Opciones do
		local b = Instance.new("TextButton")
		b.Name = op.clave
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 1
		b.Position = UDim2.fromOffset(20, FILAS[i] - 6)
		b.Size = UDim2.fromOffset(ANCHO - 40, 60)
		b.Parent = fondo
		Click.entra(b, function()
			b.BackgroundTransparency = 0.9
		end)
		Click.sale(b, function()
			b.BackgroundTransparency = 1
		end)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(36, 6)
		t.Size = UDim2.fromOffset(300, 18)
		t.Font = Enum.Font.ArialBold
		t.TextSize = 15
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Config.Colores[op.clave]
		t.TextStrokeTransparency = 0.5
		t.Text = op.titulo
		t.Parent = b
		local d = Instance.new("TextLabel")
		d.BackgroundTransparency = 1
		d.Position = UDim2.fromOffset(36, 25)
		d.Size = UDim2.fromOffset(ANCHO - 90, 32)
		d.Font = Enum.Font.Arial
		d.TextSize = 12
		d.TextWrapped = true
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextYAlignment = Enum.TextYAlignment.Top
		d.TextColor3 = Color3.fromRGB(230, 220, 200)
		d.Text = op.texto
		d.Parent = b
		Click.activado(b, function()
			local si = Dialogo.confirmar(Config.MsgConfirmar, op.titulo)
			if si then
				Remotes.evento("ElegirAlineacion"):FireServer(op.clave)
				Alineacion.cerrar()
				local f = Alineacion.alElegir
				if f then
					f()
				end
			end
		end)
	end

	local aviso = Instance.new("TextLabel")
	aviso.Name = "Obligatorio"
	aviso.BackgroundTransparency = 1
	aviso.Position = UDim2.fromOffset(20, 312)
	aviso.Size = UDim2.fromOffset(ANCHO - 40, 24)
	aviso.Font = Enum.Font.Arial
	aviso.TextSize = 13
	aviso.TextColor3 = Color3.fromRGB(230, 220, 200)
	aviso.Text = Config.MsgObligatorio
	aviso.Parent = fondo

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

return Alineacion
