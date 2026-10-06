--!strict
--[[
	Ventana — piezas comunes de las ventanas sobre una imagen del original (comercio y banco, docs/22 §5.6 y §6):
	el fondo centrado y escalado a la pantalla, etiquetas en px del .frm, la X de cerrar y el campo de cantidad
	(solo dígitos, 1 a tope) con los botones −, + y Máx para el celular (docs/22 §5.6: nuestros).
]]

local Players = game:GetService("Players")

local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Ventana = {}

-- encaje (Fase 35, docs/56 §2): cómo se acomoda a la pantalla. izquierda: va contra el borde izquierdo, a tantos px
-- (las que quedan abiertas mientras se juega); lo demás, las opciones de UI/Encaje
function Ventana.crear(nombre: string, imagen: string, ancho: number, alto: number, encaje: { izquierda: number?, parteAncho: number?, abajo: number?, techo: number? }?): (ScreenGui, ImageLabel)
	local g = Instance.new("ScreenGui")
	g.Name = nombre
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local fondo = Instance.new("ImageLabel")
	fondo.Name = "Ventana"
	fondo.BackgroundTransparency = 1
	fondo.Image = imagen
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromOffset(ancho, alto)
	fondo.Active = true
	local en = encaje or {}
	if en.izquierda then
		fondo.AnchorPoint = Vector2.new(0, 0.5)
		fondo.Position = UDim2.new(0, en.izquierda, 0.5, 0)
	end
	fondo.Parent = g
	Encaje.ventana(fondo, ancho, alto, { techo = en.techo or 1.3, parteAncho = en.parteAncho, abajo = en.abajo })
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g, fondo
end

function Ventana.label(parent: Instance, texto: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = texto
	l.ZIndex = 3
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- La X de la esquina (el dibujo ya está en la imagen): un botón invisible encima
function Ventana.cerrar(parent: Instance, x: number, y: number, w: number, h: number, alCerrar: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Cerrar"
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.ZIndex = 6
	b.Parent = parent
	Click.activado(b, alCerrar)
	return b
end

export type Campo = { caja: TextBox, valor: () -> number, set: (number) -> (), alCambiar: (() -> ())? }

-- Campo numérico de 1 a `tope` (vacío cuenta como 1). maximo() da lo que pone "Máx".
function Ventana.cantidad(parent: Instance, x: number, y: number, w: number, h: number, tope: number, maximo: () -> number, opciones: { botones: boolean? }?): Campo
	local caja = Instance.new("TextBox")
	caja.Name = "Cantidad"
	caja.BackgroundColor3 = Color3.new(0, 0, 0)
	caja.BorderColor3 = Boton.ColorTexto
	caja.Position = UDim2.fromOffset(x, y)
	caja.Size = UDim2.fromOffset(w, h)
	caja.Font = Enum.Font.Arial
	caja.TextSize = math.max(11, h - 5)
	caja.TextColor3 = Color3.new(1, 1, 1)
	caja.ClearTextOnFocus = false
	caja.Text = "1"
	caja.ZIndex = 4
	caja.Parent = parent
	local campo: Campo = {} :: any
	campo.caja = caja
	function campo.valor(): number
		local n = tonumber(caja.Text)
		return if n and n >= 1 then math.min(n, tope) else 1
	end
	function campo.set(n: number)
		caja.Text = tostring(math.clamp(math.floor(n), 1, tope))
	end
	caja:GetPropertyChangedSignal("Text"):Connect(function()
		local limpio = string.gsub(caja.Text, "%D", "")
		local n = tonumber(limpio)
		if n and n > tope then
			limpio = tostring(tope)
		end
		if limpio ~= caja.Text then
			caja.Text = limpio
			return
		end
		local f = campo.alCambiar
		if f then
			f()
		end
	end)
	if not (opciones and opciones.botones == false) then
		local bh = math.max(h + 4, 22)
		local by = y + (h - bh) / 2
		local menos = Boton.nuevo(parent, "−", UDim2.fromOffset(x - bh - 4, by), UDim2.fromOffset(bh, bh), { tamTexto = 14 })
		local mas = Boton.nuevo(parent, "+", UDim2.fromOffset(x + w + 4, by), UDim2.fromOffset(bh, bh), { tamTexto = 14 })
		local max = Boton.nuevo(parent, "Máx", UDim2.fromOffset(x + w + bh + 8, by), UDim2.fromOffset(40, bh), { tamTexto = 12 })
		menos.Name, mas.Name, max.Name = "Menos", "Mas", "Max"
		for _, b in { menos, mas, max } do
			b.ZIndex = 4
		end
		Click.activado(menos, function()
			campo.set(campo.valor() - 1)
		end)
		Click.activado(mas, function()
			campo.set(campo.valor() + 1)
		end)
		Click.activado(max, function()
			campo.set(math.max(1, maximo()))
		end)
	end
	return campo
end

return Ventana
