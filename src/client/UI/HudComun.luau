--!strict
--[[
	HudComun — lo que comparten el HUD de PC y el táctil (docs/17 §4): barras, experiencia, oro y la cuenta
	regresiva de la parálisis.

	Fase 13a (docs/22): el nombre del mapa al entrar, el cartel (ShowSignal) y el botón "Hogar" mientras se está
	muerto (DF13-07 A). Cada HUD los monta donde le queda bien.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ciudad = require(ReplicatedStorage.Shared.Config.Ciudad)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Precios = require(ReplicatedStorage.Shared.Comercio.Precios)
local ConfigProg = require(ReplicatedStorage.Shared.Config.Progresion)
local Grh = require(script.Parent.Parent.Render.Grh)
local Boton = require(script.Parent.Boton)
local Click = require(script.Parent.Click)

local HudComun = {}

-- Lo que el HUD necesita del resto del cliente
export type Contexto = {
	nombre: string,
	clase: string,
	mapa: number,
	mapaNombre: string,
	posicion: () -> (number, number),
	lanzar: (number) -> (),
	seguro: () -> (),
	raza: string?,
	genero: string?,
	abrirSkills: (() -> ())?, -- la estrella (Fase 12)
}

local function vbRound(x: number): number
	local f = math.floor(x)
	local d = x - f
	if d > 0.5 then
		return f + 1
	elseif d < 0.5 then
		return f
	end
	return if f % 2 == 0 then f else f + 1
end
HudComun.vbRound = vbRound

-- bWidth As Byte = min/max × ancho (Red/Protocol.bas:1855-1967); con max 0 queda vacía
function HudComun.bWidth(minv: number, maxv: number, ancho: number): number
	if maxv <= 0 then
		return 0
	end
	return math.clamp(vbRound(minv / maxv * ancho), 0, ancho)
end

-- ─── El reloj de la Poción de Experiencia (Fase 23, docs/42 §10) ─────────────
-- "Exp ×2  29:59" mientras dura. El servidor manda los segundos que quedan con cada actualización de las estadísticas;
-- entre una y otra, el reloj baja solo.
local COLOR_EXP = Color3.fromRGB(64, 224, 196) -- el turquesa de la poción
local relojExp: TextLabel? = nil
local expHasta = 0 -- os.clock() en que se termina
local relojCorriendo = false

local function pintarReloj()
	local l = relojExp
	if not l then
		return
	end
	local seg = math.max(0, math.ceil(expHasta - os.clock()))
	l.Visible = seg > 0
	if seg > 0 then
		local h, m, s = seg // 3600, (seg % 3600) // 60, seg % 60
		l.Text = if h > 0 then string.format("Exp x2  %d:%02d:%02d", h, m, s) else string.format("Exp x2  %d:%02d", m, s)
	end
end

-- El HUD dice en qué etiqueta va el reloj
function HudComun.montarRelojExp(l: TextLabel)
	l.TextColor3 = COLOR_EXP
	l.Visible = false
	relojExp = l
	pintarReloj()
end

-- Los segundos que quedan (nil o 0: no hay poción activa)
function HudComun.setExpBoost(seg: number?)
	expHasta = os.clock() + (seg or 0)
	pintarReloj()
	if (seg or 0) > 0 and not relojCorriendo then
		relojCorriendo = true
		task.spawn(function()
			while expHasta > os.clock() do
				task.wait(0.5)
				pintarReloj()
			end
			relojCorriendo = false
			pintarReloj()
		end)
	end
end

-- "[" & Round(exp * 100 / ELU, 2) & "%]" (frmMain.frm:3259-3270): sin ceros de más y con coma decimal. En el nivel
-- máximo (ELU 0), "[N/A]".
function HudComun.porcentajeExp(exp: number, elu: number): string
	if elu <= 0 then
		return "[N/A]"
	end
	local centesimos = vbRound(exp * 10000 / elu)
	local entero, dec = centesimos // 100, centesimos % 100
	local txt
	if dec == 0 then
		txt = tostring(entero)
	elseif dec % 10 == 0 then
		txt = `{entero},{dec // 10}`
	else
		txt = string.format("%d,%02d", entero, dec)
	end
	return `[{txt}%]`
end

-- getStrenghtColor / getDexterityColor (General.bas:1277-1290): m = 255 / MAXATRIBUTOS como Long (6)
function HudComun.colorFuerza(v: number): Color3
	return Color3.fromRGB(math.clamp(255 - 6 * v, 0, 255), math.clamp(6 * v, 0, 255), 0)
end
function HudComun.colorAgilidad(v: number): Color3
	return Color3.fromRGB(255, math.clamp(6 * v, 0, 255), 0)
end

-- Tocar el oro del HUD abre la ventana de cantidad para tirarlo (docs/22 §7.2). Lo pone Main.
HudComun.tocarOro = nil :: (() -> ())?

-- Un botón invisible sobre el oro del HUD
function HudComun.montarTocarOro(parent: Instance, pos: UDim2, tam: UDim2)
	local b = Instance.new("TextButton")
	b.Name = "TirarOro"
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Position = pos
	b.Size = tam
	b.ZIndex = 8
	b.Parent = parent
	Click.activado(b, function()
		local f = HudComun.tocarOro
		if f then
			f()
		end
	end)
end

-- SetGoldColor (frmMain.frm:3273-3283): amarillo si oro ≥ nivel × 10000 y nivel > 12; si no, cian
-- docs/24 DA-11: azul con billetera (el oro no se cae al morir), rojo sin billetera
function HudComun.colorOro(oro: number, elv: number): Color3
	if Precios.tieneBilletera(oro, elv, elv <= ConfigProg.LimiteNewbie) then
		return Color3.fromRGB(60, 150, 255)
	end
	return Color3.fromRGB(255, 60, 60)
end

-- Parálisis (cliente/Red/Protocol.bas:5117-5122, TileEngine.bas:1134-1136): segundos = ticks × 0,04 (Integer:
-- bancario), baja de a 1 por segundo
local paralisisHasta, paralisisSeg = 0, 0
function HudComun.setParalisis(ticks: number)
	if ticks <= 0 then
		paralisisSeg = 0
		return
	end
	paralisisSeg = vbRound(ticks * 0.04)
	paralisisHasta = os.clock() + paralisisSeg
end

function HudComun.textoParalisis(): string
	local restante = if paralisisSeg > 0 then math.ceil(paralisisHasta - os.clock()) else 0
	return if restante > 0 then `{restante} segundos restantes de Paralisis` else ""
end

-- Fase 14b (docs/27 §12.9): "N segundos restantes de Invisibilidad" (TileEngine.bas:1138-1140), con el tiempo real
-- del hechizo (el cliente clásico arrancaba en 24 y la mostraba también al ocultarse)
local inviHasta = 0
function HudComun.setInvisibilidad(ticks: number)
	inviHasta = if ticks > 0 then os.clock() + ticks * 0.04 else 0
end

-- P7 (docs/34 §4.2 y §6): "N segundos restantes para volver a montarte" (cli/Areas/TileEngine.bas:1146-1148). Va en
-- el renglón de la invisibilidad cuando no hay invisibilidad (nuestro: el original lo dibuja en su propio renglón)
local monturaHasta = 0
function HudComun.setMontura(espera: number)
	monturaHasta = if espera > 0 then os.clock() + espera else 0
end

function HudComun.textoInvisibilidad(): string
	local restante = math.ceil(inviHasta - os.clock())
	if restante > 0 then
		return `{restante} segundos restantes de Invisibilidad`
	end
	local m = math.ceil(monturaHasta - os.clock())
	return if m > 0 then `{m} segundos restantes para volver a montarte` else ""
end

-- Atributos de pociones y hechizos (correcciones de la 14b): "Tus atributos perderan efecto en N segundos" en (4, 40)
-- con Color_Invisibilidad (TileEngine.bas:1142-1144; TiempoDopas, Protocol.bas:2067). Nuestro: los últimos 5 s el
-- texto y los números de fuerza y agilidad titilan, y suena un aviso una vez.
HudComun.AvisoDopasSeg = 5
local SONIDO_AVISO = "rbxasset://sounds/electronicpingshort.wav"
local dopasHasta, dopasAvisado = 0, false
local sonidoAviso: Sound? = nil

function HudComun.setDopas(ticks: number)
	if ticks <= 0 then
		dopasHasta = 0
		return
	end
	local nuevo = os.clock() + ticks * 0.04
	if math.abs(nuevo - dopasHasta) > 0.5 then
		dopasAvisado = false -- efecto nuevo (otra poción u otro hechizo): vuelve a avisar
	end
	dopasHasta = nuevo
end

local function sonarAviso()
	local s = sonidoAviso
	if not s then
		local nuevo = Instance.new("Sound")
		nuevo.Name = "AvisoAtributos"
		nuevo.SoundId = SONIDO_AVISO
		nuevo.Volume = 0.6
		-- Respeta el volumen y el silencio de los sonidos de las opciones (docs/29 §5)
		nuevo.SoundGroup = game:GetService("SoundService"):FindFirstChild("Efectos") :: SoundGroup?
		nuevo.Parent = game:GetService("SoundService")
		sonidoAviso = nuevo
		s = nuevo
	end
	game:GetService("SoundService"):PlayLocalSound(s :: Sound)
end

-- El texto y si está en los últimos segundos (para titilar); suena el aviso al entrar en ellos
function HudComun.textoDopas(): (string, boolean)
	local r = dopasHasta - os.clock()
	if r <= 0 then
		return "", false
	end
	local aviso = r <= HudComun.AvisoDopasSeg
	if aviso and not dopasAvisado then
		dopasAvisado = true
		sonarAviso()
	end
	return `Tus atributos perderan efecto en {math.ceil(r)} segundos`, aviso
end

-- Fase de titileo (4 veces por segundo): true = apagado
function HudComun.titilaApagado(): boolean
	return math.floor(os.clock() * 4) % 2 == 1
end

-- ─── Nombre del mapa (cliente TileEngine.bas:1927-1956) ──────────────────────
-- Arriba al centro de la vista, blanco, y se desvanece (el alfa baja de 239 a 0, ~4 s)
local nombreMapa: TextLabel? = nil
function HudComun.montarNombreMapa(parent: Instance, pos: UDim2, tamTexto: number)
	local l = Instance.new("TextLabel")
	l.Name = "NombreMapa"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = UDim2.fromOffset(400, tamTexto + 6)
	l.Font = Enum.Font.ArialBold
	l.TextSize = tamTexto
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextTransparency = 1
	l.TextStrokeTransparency = 1
	l.ZIndex = 30
	l.Parent = parent
	nombreMapa = l
end

function HudComun.mostrarNombreMapa(texto: string)
	local l = nombreMapa
	if not l then
		return
	end
	l.Text = texto
	l.TextTransparency = 1 - 239 / 255
	l.TextStrokeTransparency = 0.5
	local info = TweenInfo.new(Ciudad.SegNombreMapa, Enum.EasingStyle.Linear)
	TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

-- ─── Cartel (cliente Carteles.bas) ──────────────────────────────────────────
-- DarFormato: corta en el primer espacio a partir de los 35 caracteres
local function lineasCartel(s: string): { string }
	local lineas = {}
	local anti, i = 1, 0
	while anti + i <= #s + 1 do
		if (i >= 35 and string.sub(s, anti + i, anti + i) == " ") or anti + i == #s then
			table.insert(lineas, string.sub(s, anti, anti + i))
			anti += i + 1
			i = 0
		else
			i += 1
		end
	end
	return lineas
end
HudComun.lineasCartel = lineasCartel

local cartelMarco: Frame? = nil
function HudComun.montarCartel(parent: Instance, centro: UDim2)
	local f = Instance.new("Frame")
	f.Name = "Cartel"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = centro
	f.Size = UDim2.fromOffset(10, 10)
	f.Visible = false
	f.ZIndex = 40
	f.Parent = parent
	cartelMarco = f
end

-- DibujarCartel: el Grh VGrande centrado y el texto a 30 px de su borde izquierdo, centrado en alto
function HudComun.mostrarCartel(texto: string, grh: number)
	local f = cartelMarco
	if not f then
		return
	end
	f:ClearAllChildren()
	local w, h = Grh.tamano(grh)
	f.Size = UDim2.fromOffset(w, h)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromOffset(w, h)
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.ZIndex = 40
	img.Parent = f
	Grh.aplicar(img, grh)
	local lineas = lineasCartel(texto)
	local alto = 13 -- frmMain.Font.Size + 5
	local y0 = h / 2 - alto * #lineas / 2
	for j, linea in lineas do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(30, y0 + (j - 1) * alto)
		l.Size = UDim2.fromOffset(math.max(w - 30, 10), alto)
		l.Font = Enum.Font.Arial
		l.TextSize = 12
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = linea
		l.ZIndex = 41
		l.Parent = f
	end
	f.Visible = true
end

function HudComun.cerrarCartel()
	local f = cartelMarco
	if f and f.Visible then
		f.Visible = false
	end
end

function HudComun.cartelAbierto(): boolean
	local f = cartelMarco
	return f ~= nil and f.Visible
end

-- ─── Botón "Hogar" (DF13-07 A) ───────────────────────────────────────────────
local botonHogar: ImageButton? = nil
local muertoHogar, viajando = false, false

local function refrescarHogar()
	local b = botonHogar
	if b then
		b.Visible = muertoHogar
		Boton.texto(b, if viajando then "Cancelar" else "Hogar")
	end
end

function HudComun.montarHogar(parent: Instance, pos: UDim2, tam: UDim2, tamTexto: number)
	local b = Boton.nuevo(parent, "Hogar", pos, tam, { tamTexto = tamTexto })
	b.Name = "Hogar"
	b.ZIndex = 20
	Click.activado(b, function()
		Remotes.evento("Hogar"):FireServer()
	end)
	botonHogar = b
	refrescarHogar()
end

function HudComun.setMuerto(m: boolean)
	muertoHogar = m
	if not m then
		viajando = false
	end
	refrescarHogar()
end

-- El servidor avisa el viaje (segundos) o que terminó (0)
function HudComun.setViaje(seg: number)
	viajando = seg > 0
	refrescarHogar()
end

-- ─── Botón "Elegí tu camino" (Fase 25, docs/44 §7; pedido del autor) ──────────
-- Mientras el personaje no eligió si es ciudadano, neutral o criminal (dejó la ventana para "Más tarde"), queda este
-- botón a la vista: antes había que salir y volver a entrar para que la ventana apareciera de nuevo.
local botonCamino: ImageButton? = nil
local caminoPendiente = false
HudComun.alCamino = nil :: (() -> ())?

function HudComun.montarCamino(parent: Instance, pos: UDim2, tam: UDim2, tamTexto: number)
	local b = Boton.nuevo(parent, "Elegí tu camino", pos, tam, { tamTexto = tamTexto, brillo = true })
	b.Name = "ElegirCamino"
	b.ZIndex = 20
	b.Visible = caminoPendiente
	Click.activado(b, function()
		local f = HudComun.alCamino
		if f then
			f()
		end
	end)
	botonCamino = b
end

function HudComun.setCaminoPendiente(si: boolean)
	caminoPendiente = si
	if botonCamino then
		botonCamino.Visible = si
	end
end

function HudComun.caminoPendiente(): boolean
	return caminoPendiente
end

-- ─── La cuenta de /SALIR (Fase 25, docs/44 §9) ───────────────────────────────
local etiquetaSalida: TextLabel? = nil
local salidaHasta = 0
local salidaVuelta = 0

function HudComun.montarSalida(parent: Instance, pos: UDim2, tamTexto: number)
	local l = Instance.new("TextLabel")
	l.Name = "Salida"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = UDim2.fromOffset(420, tamTexto + 8)
	l.Font = Enum.Font.ArialBold
	l.TextSize = tamTexto
	l.TextColor3 = Color3.fromRGB(255, 220, 120)
	l.TextStrokeTransparency = 0.3
	l.Visible = false
	l.ZIndex = 30
	l.Parent = parent
	etiquetaSalida = l
end

-- seg: los segundos que faltan para salir; 0 = se canceló (o ya salió)
function HudComun.setSalida(seg: number)
	salidaVuelta += 1
	local vuelta = salidaVuelta
	local l = etiquetaSalida
	if not l then
		return
	end
	if seg <= 0 then
		l.Visible = false
		return
	end
	salidaHasta = os.clock() + seg
	l.Visible = true
	task.spawn(function()
		while vuelta == salidaVuelta and l.Parent do
			local falta = math.max(0, math.ceil(salidaHasta - os.clock()))
			l.Text = if falta > 0 then `Saliendo en {falta}…` else "Saliendo…"
			task.wait(0.2)
		end
	end)
end

return HudComun
