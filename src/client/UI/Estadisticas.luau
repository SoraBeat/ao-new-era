--!strict
--[[
	Estadisticas — la ventana de Estadísticas del personaje (Fase 22, docs/41 §3).

	El original (frmEstadisticas) muestra atributos, reputación, skills y los contadores de matados. Acá la ventana es
	propia (D22-19 A: la imagen del original trae dibujados los rótulos de la reputación y de la cárcel, que el port
	no tiene): tres columnas con el personaje y el combate, los atributos y el historial, y los 20 skills con su barra.
	Es ancha y baja para que en el celular se lea sin achicarla a la mitad.

	Los datos se piden al abrirla (PedirEstadisticas) y no se actualizan solos mientras está abierta.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillsCfg = require(ReplicatedStorage.Shared.Config.Skills)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)
local Encaje = require(script.Parent.Encaje)

local Estadisticas = {}

local ANCHO, ALTO = 720, 424
local FILA = 15
local COLOR_ROTULO = Boton.ColorTexto
local COLOR_VALOR = Color3.new(1, 1, 1)
local COLOR_SUBIDO = Color3.fromRGB(120, 230, 120) -- un atributo subido con una poción
local COLOR_BAJADO = Color3.fromRGB(240, 110, 110)
local ALINEACION = { newbie = "Newbie", ciudadano = "Ciudadano", neutral = "Neutral", criminal = "Criminal" }
local ATRIBUTOS = { "Fuerza", "Agilidad", "Inteligencia", "Carisma", "Constitucion" }
local NOMBRE_ATRIBUTO = { Constitucion = "Constitución" }

local gui: ScreenGui? = nil
local pidiendo = false

-- El tiempo jugado: "45 min", "3 h 20 min", "5 d 4 h" (tiempo_texto de herramientas/fase22_ref.py)
function Estadisticas.tiempoTexto(seg: number): string
	local m = math.max(0, math.floor(seg)) // 60
	if m < 60 then
		return `{m} min`
	end
	local h = m // 60
	if h < 24 then
		return `{h} h {m % 60} min`
	end
	return `{h // 24} d {h % 24} h`
end

-- 1234567 → "1.234.567"
local function miles(n: number): string
	local s = tostring(math.floor(n))
	local r = string.reverse(s)
	r = string.gsub(r, "(%d%d%d)", "%1.")
	r = string.reverse(r)
	return (string.gsub(r, "^%.", ""))
end

local function texto(parent: Instance, t: string, x: number, y: number, w: number, h: number, color: Color3, alineacion: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.Font = Enum.Font.Arial
	l.TextSize = 12
	l.TextColor3 = color
	l.TextXAlignment = alineacion or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = t
	l.ZIndex = 3
	l.Parent = parent
	return l
end

local ultima: any = nil

function Estadisticas.abierta(): boolean
	return gui ~= nil
end

function Estadisticas.cerrar()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

local function armar(d: any)
	local g = Instance.new("ScreenGui")
	g.Name = "Estadisticas"
	g.ResetOnSpawn = false
	g.DisplayOrder = 40
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local caja = Boton.marco(g, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(ANCHO, ALTO))
	caja.Name = "Caja"
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	caja.Active = true
	Encaje.ventana(caja, ANCHO, ALTO)

	local titulo = texto(caja, "Estadísticas del personaje", 0, 12, ANCHO, 22, COLOR_ROTULO, Enum.TextXAlignment.Center)
	titulo.Font = Enum.Font.ArialBold
	titulo.TextSize = 17

	-- Una columna: bloques con título y filas "rótulo: valor"
	local function columna(x: number, ancho: number)
		local y = 44
		local c = {}
		function c.titulo(t: string)
			local l = texto(caja, t, x, y, ancho, 18, COLOR_ROTULO)
			l.Font = Enum.Font.ArialBold
			l.TextSize = 14
			local raya = Instance.new("Frame")
			raya.BackgroundColor3 = COLOR_ROTULO
			raya.BackgroundTransparency = 0.5
			raya.BorderSizePixel = 0
			raya.Position = UDim2.fromOffset(x, y + 18)
			raya.Size = UDim2.fromOffset(ancho, 1)
			raya.ZIndex = 3
			raya.Parent = caja
			y += 23
		end
		function c.fila(rotulo: string, valor: any, color: Color3?)
			local l = texto(caja, rotulo, x, y, ancho, FILA, COLOR_ROTULO)
			l.Name = "R_" .. rotulo
			local v = texto(caja, tostring(valor), x, y, ancho, FILA, color or COLOR_VALOR, Enum.TextXAlignment.Right)
			v.Name = "V_" .. rotulo
			y += FILA
		end
		function c.espacio()
			y += 8
		end
		return c
	end

	-- 1. El personaje y el combate
	local c1 = columna(22, 212)
	c1.titulo("Personaje")
	c1.fila("Nombre", d.nombre)
	c1.fila("Clase", `{d.clase} {d.raza}`)
	c1.fila("Nivel", d.elv)
	c1.fila("Experiencia", `{miles(d.exp)} / {miles(d.elu)}`)
	c1.fila("Oro", miles(d.oro))
	c1.fila("Alineación", ALINEACION[d.alineacion] or tostring(d.alineacion))
	if d.multa then
		c1.fila("Multa para ser ciudadano", miles(d.multa), COLOR_BAJADO)
	end
	c1.fila("Facción", d.faccion or "Ninguna")
	if d.rango then
		c1.fila("Rango", d.rango)
	end
	c1.fila("Clan", d.clan or "Ninguno")
	c1.fila("Hogar", d.hogar or "-")
	c1.espacio()
	c1.titulo("Combate")
	c1.fila("Golpe", `{d.minHit} / {d.maxHit}`)
	c1.fila("Vida máxima", d.maxHp)
	if (d.maxMana or 0) > 0 then
		c1.fila("Maná máximo", d.maxMana)
	end
	c1.fila("Energía máxima", d.maxSta)

	-- 2. Los atributos y el historial
	local c2 = columna(254, 212)
	c2.titulo("Atributos")
	for _, k in ATRIBUTOS do
		local ahora, base = d.atrib[k] or 0, d.atribBase[k] or 0
		c2.fila(NOMBRE_ATRIBUTO[k] or k, ahora, if ahora > base then COLOR_SUBIDO elseif ahora < base then COLOR_BAJADO else nil)
	end
	c2.espacio()
	c2.titulo("Historial")
	c2.fila("Ciudadanos matados", d.ciudadanos)
	c2.fila("Criminales matados", d.criminales)
	c2.fila("Usuarios matados", d.usuarios)
	c2.fila("Criaturas matadas", miles(d.npcs))
	c2.fila("Muertes", d.muertes)
	c2.fila("Retos ganados / perdidos", `{d.retosG} / {d.retosP}`)
	c2.fila("Quests completadas", d.quests)
	c2.fila("Tiempo jugado", Estadisticas.tiempoTexto(d.seg))
	c2.fila("Creado el", if typeof(d.creado) == "number" then os.date("%d/%m/%Y", d.creado :: number) else "-")

	-- 3. Los skills: el valor y una barra de 0 a 100
	local x3, w3 = 486, 212
	local l = texto(caja, "Skills", x3, 44, w3, 18, COLOR_ROTULO)
	l.Font = Enum.Font.ArialBold
	l.TextSize = 14
	local libres = texto(caja, if (d.skillPts or 0) > 0 then `{d.skillPts} puntos libres` else "", x3, 44, w3, 18, COLOR_SUBIDO, Enum.TextXAlignment.Right)
	libres.Name = "Libres"
	local raya = Instance.new("Frame")
	raya.BackgroundColor3 = COLOR_ROTULO
	raya.BackgroundTransparency = 0.5
	raya.BorderSizePixel = 0
	raya.Position = UDim2.fromOffset(x3, 62)
	raya.Size = UDim2.fromOffset(w3, 1)
	raya.ZIndex = 3
	raya.Parent = caja
	for i, s in SkillsCfg.Lista do
		local y = 67 + (i - 1) * FILA
		local valor = math.clamp(tonumber(d.skills[s.clave]) or 0, 0, SkillsCfg.Max)
		local n = texto(caja, s.nombre, x3, y, 128, FILA, COLOR_ROTULO)
		n.Name = "S_" .. s.clave
		texto(caja, tostring(valor), x3 + 128, y, 24, FILA, COLOR_VALOR, Enum.TextXAlignment.Right)
		local fondo = Instance.new("Frame")
		fondo.BackgroundColor3 = Color3.new(0, 0, 0)
		fondo.BorderColor3 = Color3.fromRGB(70, 60, 45)
		fondo.Position = UDim2.fromOffset(x3 + 158, y + 4)
		fondo.Size = UDim2.fromOffset(w3 - 158, 7)
		fondo.ZIndex = 3
		fondo.Parent = caja
		local relleno = Instance.new("Frame")
		relleno.BackgroundColor3 = Color3.fromRGB(190, 150, 60)
		relleno.BorderSizePixel = 0
		relleno.Size = UDim2.fromScale(valor / SkillsCfg.Max, 1)
		relleno.ZIndex = 4
		relleno.Parent = fondo
	end

	local cerrar = Boton.nuevo(caja, "Cerrar", UDim2.fromOffset(ANCHO / 2 - 55, ALTO - 44), UDim2.fromOffset(110, 28), { tamTexto = 14 })
	cerrar.ZIndex = 3
	Click.activado(cerrar, Estadisticas.cerrar)

	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = g
end

-- Fase 23 (docs/42 §4.2, D23-31 A): la ficha de otro jugador, que le llegó a un administrador. Por delante del panel
-- de administración.
function Estadisticas.mostrar(d: any)
	Estadisticas.cerrar()
	armar(d)
	if gui then
		gui.DisplayOrder = 65
	end
end

-- Abre la ventana (si ya está abierta, la cierra). Los datos se piden en el momento.
function Estadisticas.abrir()
	if gui then
		Estadisticas.cerrar()
		return
	end
	if pidiendo then
		return -- ya se pidió y todavía no llegó: un segundo click no la pierde
	end
	pidiendo = true
	task.spawn(function()
		local ok, d = pcall(function()
			return Remotes.funcion("PedirEstadisticas"):InvokeServer()
		end)
		pidiendo = false
		if gui then
			return
		end
		if ok and typeof(d) == "table" then
			ultima = d
			armar(d)
		elseif ultima then
			armar(ultima) -- el servidor contesta una por segundo: mientras tanto, la última
		end
	end)
end

return Estadisticas
