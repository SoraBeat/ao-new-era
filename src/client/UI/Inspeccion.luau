--!strict
--[[
	Inspeccion — "Inspeccionar" una criatura (Fase 28, docs/48 §2; pedido del autor).

	Botón derecho sobre una criatura (mantener apretado en el celular; LT + A con el mando) muestra el botón
	"Inspeccionar" al lado del puntero, como el "Invitar al grupo" de los jugadores. El botón abre una ventana con el
	dibujo de la criatura y lo que se sabe de ella: vida, golpe, defensa, experiencia, oro y lo que deja al morir, con la
	chance de cada cosa.

	No le pide nada al servidor: el número de la criatura llega con sus datos (solo de las que se pueden inspeccionar,
	NpcService.datosPublicos) y la ficha se arma con Shared.Npcs.Ficha, de datos que el cliente ya tiene.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ficha = require(ReplicatedStorage.Shared.Npcs.Ficha)
local Indices = require(ReplicatedStorage.Shared.Generado.Indices) :: any
local Grh = require(script.Parent.Parent.Render.Grh)
local Retrato = require(script.Parent.Parent.Render.Retrato)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Inspeccion = {}

local ANCHO, ALTO = 400, 430
local CAJA = 124 -- el recuadro del dibujo
local DORADO = Color3.fromRGB(235, 215, 170)
local COLOR_SUB = Color3.fromRGB(252, 203, 130)
local COLOR_DATO = Color3.fromRGB(225, 225, 225)
local COLOR_ORO = Color3.fromRGB(255, 215, 94)

local gui: ScreenGui? = nil
local burbuja: ScreenGui? = nil

local function miles(v: number): string
	local s = tostring(math.floor(v))
	local r = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (r:gsub("^%.", ""))
end

-- 80 %, 9 %, 0,9 %, 0,09 %, 0,01 %
local function porc(p: number): string
	local v = p * 100
	local t = if v >= 1 then string.format("%d", math.floor(v + 0.5)) elseif v >= 0.1 then string.format("%.1f", v) else string.format("%.2f", v)
	return (string.gsub(t, "%.", ",")) .. " %"
end

local function sacarBurbuja()
	if burbuja then
		burbuja:Destroy()
		burbuja = nil
	end
end

function Inspeccion.abierta(): boolean
	return gui ~= nil
end

function Inspeccion.cerrar()
	sacarBurbuja()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function texto(parent: Instance, t: string, tam: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arial
	l.TextSize = tam
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.RichText = true
	l.Text = t
	l.Parent = parent
	return l
end

-- El dibujo de la criatura, parado mirando al sur y achicado o agrandado para que entre en el recuadro
local function dibujar(caja: Frame, cuerpo: number, cabeza: number)
	local c = Indices.cuerpos[cuerpo]
	local g = c and c.walk[3]
	if not g or not Grh.existe(g) then
		return
	end
	local w, h = Grh.tamano(g)
	local alto = h
	local cab = if cabeza ~= 0 then Indices.cabezas[cabeza] else nil
	if cab and cab[3] then
		local _, hc = Grh.tamano(cab[3])
		alto = math.max(alto, 32 - c.headOffset[2] + math.min(hc, 20)) -- la cabeza sobresale por arriba del cuerpo
	end
	local escala = math.min(2, (CAJA - 16) / math.max(w, 32), (CAJA - 16) / math.max(alto, 32))
	local lado = 32 * escala
	local r = Retrato.nuevo(caja, math.floor((CAJA - lado) / 2), math.floor(CAJA - 8 - lado), 3)
	local e = Instance.new("UIScale")
	e.Scale = escala
	e.Parent = r.marco
	Retrato.dibujar(r, { cuerpo = cuerpo, cabeza = cabeza, casco = 0, arma = 0, escudo = 0 }, 3)
end

-- La ventana con la ficha de esa criatura (su número de NPCs.dat)
function Inspeccion.abrir(numero: number)
	local f = Ficha.de(numero)
	Inspeccion.cerrar()
	if not f then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "Inspeccion"
	g.ResetOnSpawn = false
	g.DisplayOrder = 46
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Se la mira con la criatura al lado: va contra el borde izquierdo y no pasa de un tercio del ancho, para no
	-- tapar al personaje (que está en el centro de la vista), como la ventana del entrenador
	local caja = Boton.marco(g, UDim2.new(0, 12, 0.5, 0), UDim2.fromOffset(ANCHO, ALTO))
	caja.Name = "Caja"
	caja.AnchorPoint = Vector2.new(0, 0.5)
	caja.Active = true
	Encaje.ventana(caja, ANCHO, ALTO, { parteAncho = 0.32 })
	local base = Instance.new("Frame")
	base.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
	base.BackgroundTransparency = 0.05
	base.BorderSizePixel = 0
	base.Position = UDim2.fromOffset(6, 6)
	base.Size = UDim2.new(1, -12, 1, -12)
	base.ZIndex = 0
	base.Parent = caja

	local titulo = texto(caja, f.nombre, 19, DORADO)
	titulo.Name = "Titulo"
	titulo.Font = Enum.Font.ArialBold
	titulo.TextXAlignment = Enum.TextXAlignment.Center
	titulo.TextWrapped = false
	titulo.TextTruncate = Enum.TextTruncate.AtEnd
	titulo.Position = UDim2.fromOffset(40, 14)
	titulo.Size = UDim2.new(1, -80, 0, 24)

	local x = Boton.nuevo(caja, "X", UDim2.new(1, -40, 0, 12), UDim2.fromOffset(26, 26), { tamTexto = 13 })
	x.Name = "Cerrar"
	Click.activado(x, Inspeccion.cerrar)

	-- El dibujo
	local cuadro = Instance.new("Frame")
	cuadro.Name = "Dibujo"
	cuadro.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
	cuadro.BorderColor3 = Color3.fromRGB(110, 86, 50)
	cuadro.Position = UDim2.fromOffset(20, 48)
	cuadro.Size = UDim2.fromOffset(CAJA, CAJA)
	cuadro.ClipsDescendants = true
	cuadro.Parent = caja
	dibujar(cuadro, f.cuerpo, f.cabeza)

	-- Los números, a la derecha del dibujo
	local datos: { { string } } = {
		{ "Vida", miles(f.vida) },
		{ "Golpe", if f.golpeMax > 0 then `{miles(f.golpeMin)} a {miles(f.golpeMax)}` else "No pega" },
		{ "Defensa", miles(f.defensa) },
		{ "Defensa mágica", miles(f.defensaMagica) },
		{ "Experiencia", miles(f.exp) },
	}
	if f.oroPromedio > 0 then
		table.insert(datos, { "Oro", `{miles(f.oroPromedio)} en promedio` })
	end
	for i, d in datos do
		local y = 48 + (i - 1) * 21
		local n = texto(caja, d[1], 14, COLOR_SUB)
		n.Position = UDim2.fromOffset(CAJA + 36, y)
		n.Size = UDim2.fromOffset(112, 20)
		local v = texto(caja, d[2], 14, if d[1] == "Oro" then COLOR_ORO else COLOR_DATO)
		v.Name = d[1]
		v.TextWrapped = false
		v.Position = UDim2.fromOffset(CAJA + 150, y)
		v.Size = UDim2.new(1, -(CAJA + 166), 0, 20)
	end

	-- Abajo, lo que se despliega: cómo es, qué lanza y qué deja
	local lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.Position = UDim2.fromOffset(20, 48 + CAJA + 12)
	lista.Size = UDim2.new(1, -40, 1, -(48 + CAJA + 12 + 18))
	lista.CanvasSize = UDim2.new()
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.ScrollBarThickness = 6
	lista.ScrollingDirection = Enum.ScrollingDirection.Y
	lista.Parent = caja
	local orden = Instance.new("UIListLayout")
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Padding = UDim.new(0, 4)
	orden.Parent = lista
	local n = 0
	local function linea(t: string, tam: number, color: Color3): TextLabel
		n += 1
		local l = texto(lista, t, tam, color)
		l.LayoutOrder = n
		l.Size = UDim2.new(1, -10, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		return l
	end

	local rasgos = { if f.ataca then '<font color="#ff7b6b">Te ataca</font>' else "No ataca" }
	if f.envenena then
		table.insert(rasgos, "Envenena")
	end
	if f.inmune then
		table.insert(rasgos, "Inmune a Paralizar e Inmovilizar")
	end
	if f.agua then
		table.insert(rasgos, if f.agua == "agua" then "Solo en el agua" else "Anfibia")
	end
	linea(table.concat(rasgos, " · "), 14, COLOR_DATO)
	if f.domar then
		linea(
			if f.domar.nivel > 0 then `Se doma con {f.domar.skill} de Domar animales y nivel {f.domar.nivel}.` else `Se doma con {f.domar.skill} de Domar animales.`,
			14,
			Color3.fromRGB(170, 220, 170)
		)
	end
	if #f.hechizos > 0 then
		linea("Lanza: " .. table.concat(f.hechizos, ", "), 14, Color3.fromRGB(190, 160, 255))
	end
	local sub = linea("<b>Lo que deja al morir</b>", 15, COLOR_SUB)
	sub.Name = "Deja"
	if #f.drops == 0 then
		linea("Nada.", 14, COLOR_DATO)
	end
	for _, d in f.drops do
		n += 1
		local fila = Instance.new("Frame")
		fila.Name = "Drop"
		fila.BackgroundTransparency = 1
		fila.Size = UDim2.new(1, -10, 0, 34)
		fila.LayoutOrder = n
		fila.Parent = lista
		if d.grh ~= 0 and Grh.existe(d.grh) then
			local icono = Grh.nuevo(fila, d.grh, 2)
			local w, h = Grh.tamano(d.grh)
			icono.Position = UDim2.fromOffset((32 - w) // 2, (34 - h) // 2)
		end
		local nombre = texto(fila, if d.obj == 0 then `{miles(d.cant)} monedas de oro` else if d.cant > 1 then `{d.nombre} ×{miles(d.cant)}` else d.nombre, 14, if d.obj == 0 then COLOR_ORO else COLOR_DATO)
		nombre.TextYAlignment = Enum.TextYAlignment.Center
		nombre.TextWrapped = false
		nombre.TextTruncate = Enum.TextTruncate.AtEnd
		nombre.Position = UDim2.fromOffset(40, 0)
		nombre.Size = UDim2.new(1, -110, 1, 0)
		local chance = texto(fila, if d.prob >= 1 then "siempre" else porc(d.prob), 14, COLOR_SUB)
		chance.TextYAlignment = Enum.TextYAlignment.Center
		chance.TextXAlignment = Enum.TextXAlignment.Right
		chance.Position = UDim2.new(1, -68, 0, 0)
		chance.Size = UDim2.fromOffset(64, 34)
	end
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

-- El Controlador avisa que se hizo click derecho (o se mantuvo apretado) sobre una criatura que se puede inspeccionar,
-- en la posición pos de la pantalla: el botón "Inspeccionar" al lado
function Inspeccion.alClickearNpc(_id: number, numero: number, pos: Vector2)
	sacarBurbuja()
	if not Ficha.inspeccionable(numero) then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "InspeccionarCriatura"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 45
	local b = Boton.nuevo(g, "Inspeccionar", UDim2.fromOffset(pos.X + 18, pos.Y - 14), UDim2.fromOffset(120, 28), { tamTexto = 13 })
	b.Name = "Inspeccionar"
	Click.activado(b, function()
		sacarBurbuja()
		Inspeccion.abrir(numero)
	end)
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	burbuja = g
	task.delay(4, function()
		if burbuja == g then
			sacarBurbuja()
		end
	end)
end

-- Un click en el mapa que no fue a una criatura saca el botón
function Inspeccion.alClickearMapa()
	sacarBurbuja()
end

return Inspeccion
