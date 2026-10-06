--!strict
--[[
	Dialogo — los MsgBox del cliente original, con el marco de los botones (Fase 12): avisos del panel y la creación y
	la confirmación de borrar un personaje (con el nombre escrito, docs/21 §2.2).
	Las funciones esperan (yield) hasta que se cierra.
]]

local Players = game:GetService("Players")

local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Dialogo = {}

local function armar(titulo: string?, texto: string, alto: number): (ScreenGui, ImageLabel)
	local g = Instance.new("ScreenGui")
	g.Name = "Dialogo"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 200
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local velo = Instance.new("TextButton") -- bloquea los clicks a lo de atrás
	velo.AutoButtonColor = false
	velo.Text = ""
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 0.5
	velo.Size = UDim2.fromScale(1, 1)
	velo.Parent = g
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(380, alto))
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	Encaje.ventana(caja, 380, alto, { techo = 1.4 })
	local y = 12
	if titulo then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(0, y)
		t.Size = UDim2.new(1, 0, 0, 18)
		t.Font = Enum.Font.ArialBold
		t.TextSize = 15
		t.TextColor3 = Boton.ColorTexto
		t.Text = titulo
		t.Parent = caja
		y += 24
	end
	local l = Instance.new("TextLabel")
	l.Name = "Texto"
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(20, y)
	l.Size = UDim2.new(1, -40, 0, 54)
	l.Font = Enum.Font.Arial
	l.TextSize = 14
	l.TextWrapped = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = texto
	l.Parent = caja
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g, caja
end

-- Aviso con "Aceptar"
function Dialogo.aviso(texto: string, titulo: string?)
	local g, caja = armar(titulo, texto, if titulo then 150 else 126)
	local listo = false
	local b = Boton.nuevo(caja, "Aceptar", UDim2.new(0.5, -50, 1, -44), UDim2.fromOffset(100, 32), { tamTexto = 15 })
	Click.activado(b, function()
		listo = true
	end)
	while not listo and g.Parent do
		task.wait()
	end
	g:Destroy()
end

-- Pregunta Sí / No. Con campo: además pide escribir un texto (devuelve lo escrito).
function Dialogo.confirmar(texto: string, titulo: string?, campo: string?): (boolean, string)
	local alto = (if titulo then 24 else 0) + (if campo then 190 else 140)
	local g, caja = armar(titulo, texto, alto)
	local escrito: TextBox? = nil
	if campo then
		local ayuda = Instance.new("TextLabel")
		ayuda.BackgroundTransparency = 1
		ayuda.Position = UDim2.new(0, 20, 1, -110)
		ayuda.Size = UDim2.new(1, -40, 0, 16)
		ayuda.Font = Enum.Font.Arial
		ayuda.TextSize = 13
		ayuda.TextColor3 = Boton.ColorTexto
		ayuda.Text = campo
		ayuda.Parent = caja
		local t = Instance.new("TextBox")
		t.Position = UDim2.new(0, 60, 1, -88)
		t.Size = UDim2.new(1, -120, 0, 26)
		t.BackgroundColor3 = Color3.new(0, 0, 0)
		t.BorderColor3 = Boton.ColorTexto
		t.Font = Enum.Font.Arial
		t.TextSize = 15
		t.TextColor3 = Color3.new(1, 1, 1)
		t.ClearTextOnFocus = false
		t.Text = ""
		t.PlaceholderText = ""
		t.Parent = caja
		escrito = t
	end
	local resultado: boolean? = nil
	local si = Boton.nuevo(caja, "Si", UDim2.new(0.5, -110, 1, -44), UDim2.fromOffset(100, 32), { tamTexto = 15 })
	local no = Boton.nuevo(caja, "No", UDim2.new(0.5, 10, 1, -44), UDim2.fromOffset(100, 32), { tamTexto = 15 })
	Click.activado(si, function()
		resultado = true
	end)
	Click.activado(no, function()
		resultado = false
	end)
	while resultado == nil and g.Parent do
		task.wait()
	end
	local txt = if escrito then escrito.Text else ""
	g:Destroy()
	return resultado == true, txt
end

return Dialogo
