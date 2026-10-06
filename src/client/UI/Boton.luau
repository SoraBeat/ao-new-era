--!strict
--[[
	Boton — el botón de la interfaz del cliente original (uAOButton, uAOButton.ctl:395-505).

	El arte (Graficos/Botones/b*.bmp) viene armado en Generado.UiAssets.botones: un botón de 80×60 por estado
	(normal, encima, apretado) que se estira con SliceCenter (borde de 11 px). El texto va centrado con las dos
	sombras del original: (40, 10, 10) corrida (-1, -1) y (90, 90, 90) corrida (+1, +1). Color del texto: el
	FCOL del botón en el .frm y blanco (OCOL) con el mouse encima.
]]

local TweenService = game:GetService("TweenService")

local UiAssets = require(game:GetService("ReplicatedStorage").Shared.Generado.UiAssets)
local Click = require(script.Parent.Click)

local Boton = {}

local B = UiAssets.boton
Boton.ColorTexto = Color3.fromRGB(178, 155, 111) -- FCOL 7314354 (frmMain.frm:475)
Boton.ColorEncima = Color3.new(1, 1, 1) -- OCOL 16777215

export type Opciones = {
	tamTexto: number?,
	fuente: Enum.Font?,
	color: Color3?,
	-- Fase 22 (docs/41 §4.2, D22-25 A): crece apenas con el mouse encima. Solo los del menú, el panel de personajes y la
	-- creación; el botón queda anclado en su centro (para crecer parejo), así que después no hay que moverlo.
	animado: boolean?,
	brillo: boolean?, -- además, un borde que late (el botón Jugar)
}

local function sombra(parent: Instance, texto: string, dx: number, dy: number, color: Color3, o: Opciones): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Position = UDim2.fromOffset(dx, dy)
	t.Font = o.fuente or Enum.Font.Arial
	t.TextSize = o.tamTexto or 16
	t.TextColor3 = color
	t.TextWrapped = true
	t.Text = texto
	t.ZIndex = 2
	t.Parent = parent
	return t
end

function Boton.nuevo(parent: Instance, texto: string, pos: UDim2, tam: UDim2, opciones: Opciones?): ImageButton
	local o = opciones or {}
	local b = Instance.new("ImageButton")
	b.Name = texto
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Image = UiAssets.botones
	b.ImageRectSize = Vector2.new(B.ancho, B.alto)
	b.ImageRectOffset = Vector2.zero
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Rect.new(B.borde, B.borde, B.ancho - B.borde, B.alto - B.borde)
	b.ResampleMode = Enum.ResamplerMode.Pixelated
	b.Position = pos
	b.Size = tam
	b.Parent = parent

	sombra(b, texto, -1, -1, Color3.fromRGB(40, 10, 10), o)
	sombra(b, texto, 1, 1, Color3.fromRGB(90, 90, 90), o)
	local principal = sombra(b, texto, 0, 0, o.color or Boton.ColorTexto, o)
	principal.ZIndex = 3

	local escala: UIScale? = nil
	if o.animado then
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = pos + UDim2.new(tam.X.Scale / 2, tam.X.Offset / 2, tam.Y.Scale / 2, tam.Y.Offset / 2)
		local e = Instance.new("UIScale")
		e.Parent = b
		escala = e
	end
	if o.brillo then
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(255, 220, 130)
		borde.Thickness = 2
		borde.Transparency = 0.25
		borde.Parent = b
		TweenService:Create(borde, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.9 }):Play()
	end

	local encima, apretado = false, false
	local function pintar()
		local estado = if apretado then 2 elseif encima then 1 else 0
		b.ImageRectOffset = Vector2.new(B.ancho * estado, 0)
		principal.TextColor3 = if estado > 0 then Boton.ColorEncima else (o.color or Boton.ColorTexto)
		if escala then
			local destino = if apretado then 0.97 elseif encima then 1.06 else 1
			TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = destino }):Play()
		end
	end
	Click.entra(b, function()
		encima = true
		pintar()
	end)
	Click.sale(b, function()
		encima, apretado = false, false
		pintar()
	end)
	b.MouseButton1Down:Connect(function()
		apretado = true
		pintar()
	end)
	b.MouseButton1Up:Connect(function()
		apretado = false
		pintar()
	end)
	return b
end

-- Un panel con el marco del botón (estado normal, 9-slice): lo usan los diálogos nuevos de la Fase 11
function Boton.marco(parent: Instance, pos: UDim2, tam: UDim2): ImageLabel
	local m = Instance.new("ImageLabel")
	m.BackgroundTransparency = 1
	m.Image = UiAssets.botones
	m.ImageRectSize = Vector2.new(B.ancho, B.alto)
	m.ImageRectOffset = Vector2.zero
	m.ScaleType = Enum.ScaleType.Slice
	m.SliceCenter = Rect.new(B.borde, B.borde, B.ancho - B.borde, B.alto - B.borde)
	m.ResampleMode = Enum.ResamplerMode.Pixelated
	m.Position = pos
	m.Size = tam
	m.Parent = parent
	return m
end

-- Cambia el texto de un botón creado con Boton.nuevo
function Boton.texto(b: ImageButton, texto: string)
	for _, t in b:GetChildren() do
		if t:IsA("TextLabel") then
			t.Text = texto
		end
	end
end

return Boton
