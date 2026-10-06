--!strict
--[[
	Consola — los mensajes del servidor, como el RecTxt del cliente original (docs/17 §5).

	- Colores y negrita: los FontTypes del cliente original (cliente/Red/Protocol.bas:395-535, docs/15 §9.1) y
	  los de spanish.json (combate en rojo, seguro en verde/rojo).
	- AddtoRichTextBox (General.bas:80-130): agrega abajo y va al final; cuando el texto pasa de 1000 caracteres
	  borra la primera línea. Rueda del mouse (o arrastrar, en celular) para leer hacia atrás.
	- El HUD la monta donde corresponde (Consola.montar): en PC dentro de RecTxt, en celular arriba al centro.
	  Lo que llega antes de montarla se guarda.
]]

local Consola = {}

local COLORES = {
	combate = Color3.fromRGB(255, 0, 0), -- spanish.json (golpes, muertes)
	fight = Color3.fromRGB(255, 102, 102), -- FONTTYPE_FIGHT
	info = Color3.fromRGB(255, 204, 153), -- FONTTYPE_INFO
	infoBold = Color3.fromRGB(255, 204, 153), -- FONTTYPE_INFOBOLD (cliente/Red/Protocol.bas:429-433)
	aviso = Color3.fromRGB(255, 255, 102), -- FONTTYPE_WARNING
	talk = Color3.fromRGB(204, 255, 255), -- FONTTYPE_TALK
	veneno = Color3.fromRGB(128, 255, 0), -- FONTTYPE_VENENO
	citizen = Color3.fromRGB(78, 78, 252), -- FONTTYPE_CITIZEN
	criminal = Color3.fromRGB(224, 52, 17), -- FONTTYPE_CRIMINAL (cliente/Red/Protocol.bas:543-548), en negrita
	neutral = Color3.fromRGB(170, 170, 170), -- nuestro: el click sobre un neutral (docs/36 §10)
	consejo = Color3.fromRGB(130, 130, 255), -- FONTTYPE_CONSEJO (:476-481): el llamado del cuerno de la Armada
	consejoCaos = Color3.fromRGB(255, 60, 0), -- FONTTYPE_CONSEJOCAOS (:483-487): el de la Legión
	hechizo = Color3.fromRGB(210, 220, 220), -- mensajes de InfoHechizo
	objetivo = Color3.fromRGB(100, 100, 120), -- "Haz click sobre el objetivo..."
	infoHechizo = Color3.fromRGB(170, 138, 198), -- botón Info
	blanco = Color3.fromRGB(255, 255, 255), -- MENSAJE_USER_MUERTO
	seguroOn = Color3.fromRGB(0, 255, 0),
	seguroOff = Color3.fromRGB(255, 0, 0),
	servidor = Color3.fromRGB(250, 150, 237), -- FONTTYPE_SERVER (cliente/Red/Protocol.bas:463-468), en negrita
	party = Color3.fromRGB(252, 203, 130), -- FONTTYPE_PARTY (cliente/Red/Protocol.bas:443-447), sin negrita
	guild = Color3.fromRGB(205, 101, 236), -- FONTTYPE_GUILD (cliente/Red/Protocol.bas:456-461), en negrita (Fase 15b)
	guildMsg = Color3.fromRGB(228, 199, 27), -- FONTTYPE_GUILDMSG (:470-474): el chat de clan, sin negrita
}
-- En negrita en el original: FIGHT, WARNING, VENENO, CITIZEN, INFOBOLD (y los de spanish.json se ven fuertes igual)
local NORMAL = { info = true, talk = true, hechizo = true, objetivo = true, infoHechizo = true, blanco = true, party = true, guildMsg = true }
local MAX_CARACTERES = 1000 -- General.bas:101

type Entrada = { texto: string, tipo: string, label: TextLabel?, rico: string? }
local entradas: { Entrada } = {}
local caracteres = 0
local orden = 0

local marco: ScrollingFrame? = nil
local tamTexto = 14
local conTrazo = false

local function crearLabel(e: Entrada)
	local sf = marco
	if not sf then
		return
	end
	orden += 1
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -4, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.Font = if NORMAL[e.tipo] then Enum.Font.Arial else Enum.Font.ArialBold
	l.TextSize = tamTexto
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextColor3 = COLORES[e.tipo] or COLORES.info
	l.TextStrokeTransparency = if conTrazo then 0.4 else 1
	l.Text = e.texto
	if e.rico then
		l.RichText = true
		l.Text = e.rico
	end
	l.LayoutOrder = orden
	l.Parent = sf
	e.label = l
end

local function alFinal()
	local sf = marco
	if sf then
		task.defer(function()
			sf.CanvasPosition = Vector2.new(0, math.max(0, sf.AbsoluteCanvasSize.Y))
		end)
	end
end

export type Opciones = { tamTexto: number?, trazo: boolean?, barra: number? }

-- Monta la consola dentro de `parent` (la llena). Se puede volver a montar en otro lado.
function Consola.montar(parent: GuiObject, opciones: Opciones?)
	local o = opciones or {}
	tamTexto = o.tamTexto or 14
	conTrazo = o.trazo == true
	if marco then
		marco:Destroy()
	end
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "Consola"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.CanvasSize = UDim2.new()
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ScrollBarThickness = o.barra or 6
	sf.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 70)
	sf.Parent = parent
	local lista = Instance.new("UIListLayout")
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = sf
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingTop = UDim.new(0, 2)
	pad.Parent = sf
	marco = sf
	sf:GetPropertyChangedSignal("AbsoluteSize"):Connect(alFinal) -- el celular la cambia de tamaño (docs/23 DN-09)
	for _, e in entradas do
		crearLabel(e)
	end
	alFinal()
end

-- La deja vacía (Fase 25, docs/44 §9: al volver a la pantalla de personajes)
function Consola.limpiar()
	entradas = {}
	caracteres = 0
	if marco then
		for _, h in marco:GetChildren() do
			if h:IsA("TextLabel") then
				h:Destroy()
			end
		end
	end
end

function Consola.agregar(texto: string, tipo: string?)
	-- Textos de varias líneas (el Info del hechizo): una entrada por línea
	if string.find(texto, "\n") then
		for linea in string.gmatch(texto, "[^\n]+") do
			Consola.agregar(linea, tipo)
		end
		return
	end
	-- Si ya pasó de 1000 caracteres, se va la primera línea (antes de agregar, como el original)
	if caracteres > MAX_CARACTERES and #entradas > 0 then
		local primera = table.remove(entradas, 1) :: Entrada
		caracteres -= #primera.texto + 2
		if primera.label then
			primera.label:Destroy()
		end
	end
	local e: Entrada = { texto = texto, tipo = tipo or "info", label = nil }
	table.insert(entradas, e)
	caracteres += #texto + 2 -- + vbCrLf
	crearLabel(e)
	alFinal()
end

-- Chat (docs/23 DN-06): "Nombre> texto", el nombre en negrita con su color y el texto con el del chat
-- (WriteChatOverHeadInConsole, cliente Red/Protocol.bas:2187-2234)
local function escapar(t: string): string
	return (string.gsub(t, "[<>&\"']", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;", ["'"] = "&apos;" }))
end
local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Consola.agregarChat(nombre: string, colorNombre: Color3, texto: string, colorTexto: Color3)
	local plano = `{nombre}> {texto}`
	if caracteres > MAX_CARACTERES and #entradas > 0 then
		local primera = table.remove(entradas, 1) :: Entrada
		caracteres -= #primera.texto + 2
		if primera.label then
			primera.label:Destroy()
		end
	end
	local rico = `<font color="{hex(colorNombre)}"><b>{escapar(nombre)}&gt;</b></font> <font color="{hex(colorTexto)}">{escapar(texto)}</font>`
	local e: Entrada = { texto = plano, tipo = "talk", label = nil, rico = rico }
	table.insert(entradas, e)
	caracteres += #plano + 2
	crearLabel(e)
	alFinal()
end

return Consola
