--!strict
--[[
	Sonido — los efectos de sonido del cliente (paquete P2, docs/29 §2 y §3).

	- Todos los WAV del original están en fila en un solo audio (Generado/Sonidos: `efectos` y `tramos`). Cada efecto
	  es un tramo: PlaybackRegion con PlaybackRegionsEnabled.
	- Volumen como el original (cli/Audio/clsAudio.cls:284-334): lineal en dB, -100 dB a 150 tiles (-0,67 dB por tile),
	  según la distancia al jugador; se recalcula en cada frame mientras suena (el original, en cada paso).
	- Paneo: el Sound va en un Attachment en el tile de la fuente y el oyente (SoundService:SetListener) se pone en
	  cada frame en el tile del jugador mirando al norte de la pantalla. Roblox no atenúa (Linear 1 a 10000 studs).
	- Grupos fijos, armados al arrancar (no se clonan Sound en el juego): 24 para efectos, 8 para los pasos y 8 sin
	  posición (interfaz, clan). Si están todos ocupados, el nuevo corta al más viejo (el original: 30 canales).
	- Volumen y silencio de las opciones: SoundGroup "Efectos" (docs/29 §5).
	- Fase 20 (docs/39 §8): tres grupos adentro de "Efectos", cada uno con su volumen: Combate (golpes, hechizos,
	  criaturas: todo lo que no está en las otras dos listas), Ambiente (pasos, lluvia, fogata, mar, puertas, oficios,
	  comer y beber) e Interfaz (clicks, saludos, subir de nivel, los avisos del clan). El volumen general los multiplica.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sonidos = require(ReplicatedStorage.Shared.Generado.Sonidos) :: any
local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local Click = require(script.Parent.Parent.UI.Click)

local Sonido = {}

Sonido.AlcanceX, Sonido.AlcanceY = 24, 20 -- como el servidor (SonidoService, DSO-03)
Sonido.Base = 1 -- volumen de un efecto a 0 tiles (el slider va en el SoundGroup)

-- Volumen del original a `d` tiles (sonido_ref.py ganancia)
function Sonido.ganancia(d: number): number
	return 10 ^ (-100 * math.min(d, 150) / 150 / 20)
end

-- Slider 0..100 → volumen del SoundGroup: en dB de -30 a 0; el 0 silencia (docs/29 §5)
function Sonido.volumenDeSlider(v: number): number
	if v <= 0 then
		return 0
	end
	return 10 ^ (-30 * (1 - math.min(v, 100) / 100) / 20)
end

type Canal = { s: Sound, a: Attachment?, inicio: number, x: number?, y: number? }

local grupoEfectos: SoundGroup
-- Fase 20 (docs/39 §8): los tres grupos. Qué número de sonido va a cada uno (los nombres, todos a Interfaz salvo los
-- de la lluvia y el fuego); lo que no figura es de Combate.
local grupos: { [string]: SoundGroup } = {}
local AMBIENTE: { [any]: boolean } = {
	[3] = true, -- llegar con el efecto de traslado
	[5] = true, -- puerta
	[7] = true, [46] = true, [82] = true, -- comer, beber, la manzana
	[13] = true, [14] = true, [15] = true, [41] = true, [42] = true, -- talar, pescar, minar, herrería y carpintería
	[23] = true, [24] = true, [50] = true, -- los pasos y el mar
	lluviain = true, lluviaout = true, lluviainend = true, lluviaoutend = true, Fuego = true,
}
local INTERFAZ: { [any]: boolean } = {
	[6] = true, -- subir de nivel
	[43] = true, [44] = true, [45] = true, -- clan: aceptado, fundado, guerra
}
local function grupoDe(n: any): SoundGroup
	if AMBIENTE[n] then
		return grupos.ambiente
	elseif INTERFAZ[n] or typeof(n) == "string" then
		return grupos.interfaz
	end
	return grupos.combate
end
Sonido.grupoDe = function(n: any): string
	return grupoDe(n).Name
end
local efectos: { Canal } = {}
local pasos: { Canal } = {}
local planos: { Canal } = {}
local fijos: { Canal } = {} -- loops con posición (la fogata)
local iniciado = false
local posicion: () -> (number?, number?) = function()
	return nil, nil
end
local pieDe: { [number]: boolean } = {} -- el pie de cada personaje (los pasos alternan 23 y 24)

local function mundo(x: number, y: number): Vector3
	return Vector3.new((x - 1) * Grilla.TILE_STUDS, 0, (y - 1) * Grilla.TILE_STUDS)
end

local function nuevoSound(padre: Instance): Sound
	local s = Instance.new("Sound")
	s.SoundId = Sonidos.efectos
	s.SoundGroup = grupoEfectos
	s.PlaybackRegionsEnabled = true
	s.RollOffMode = Enum.RollOffMode.Linear
	s.RollOffMinDistance = 1
	s.RollOffMaxDistance = 10000
	s.Volume = Sonido.Base
	s.Parent = padre
	return s
end

local function armar(lista: { Canal }, n: number, conPosicion: boolean)
	for i = 1, n do
		if conPosicion then
			local a = Instance.new("Attachment")
			a.Name = "SonidoAO"
			a.Parent = workspace.Terrain
			table.insert(lista, { s = nuevoSound(a), a = a, inicio = 0 })
		else
			table.insert(lista, { s = nuevoSound(SoundService), inicio = 0 })
		end
	end
end

function Sonido.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	grupoEfectos = SoundService:FindFirstChild("Efectos") :: SoundGroup
	if not grupoEfectos then
		grupoEfectos = Instance.new("SoundGroup")
		grupoEfectos.Name = "Efectos"
		grupoEfectos.Volume = 1
		grupoEfectos.Parent = SoundService
	end
	for clave, nombre in { combate = "Combate", ambiente = "Ambiente", interfaz = "Interfaz" } do
		local g = grupoEfectos:FindFirstChild(nombre) :: SoundGroup
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = nombre
			g.Volume = 1
			g.Parent = grupoEfectos -- anidado: el volumen general lo multiplica
		end
		grupos[clave] = g
	end
	SoundService.DopplerScale = 0 -- el Doppler del original era de ±1,3 %: no vale la pena
	armar(efectos, 24, true)
	armar(pasos, 8, true)
	armar(planos, 8, false)
	-- El oyente sigue al jugador (en su tile, a la altura de las fuentes, mirando al norte = -Z)
	RunService.RenderStepped:Connect(function()
		local px, py = posicion()
		if not px or not py then
			return
		end
		local p = mundo(px, py)
		SoundService:SetListener(Enum.ListenerType.CFrame, CFrame.lookAt(p, p + Vector3.new(0, 0, -1)))
		for _, lista in { efectos, pasos, fijos } do
			for _, c in lista do
				if c.s.IsPlaying and c.x and c.y then
					c.s.Volume = Sonido.Base * Sonido.ganancia(math.sqrt((c.x - px) ^ 2 + (c.y - py) ^ 2))
				end
			end
		end
	end)
end

-- La posición del jugador en tiles (la visual, que se mueve suave); la pone Main
function Sonido.setPosicion(f: () -> (number?, number?))
	posicion = f
end

-- Volumen y silencio de los efectos (docs/29 §5). porGrupo (Fase 20): { combate, ambiente, interfaz }, de 0 a 100
function Sonido.setOpciones(prendido: boolean, volumen: number, porGrupo: { [string]: number }?)
	if grupoEfectos then
		grupoEfectos.Volume = if prendido then Sonido.volumenDeSlider(volumen) else 0
	end
	if porGrupo then
		for clave, g in grupos do
			g.Volume = Sonido.volumenDeSlider(porGrupo[clave] or 100)
		end
	end
end

local function canalLibre(lista: { Canal }): Canal
	local elegido = lista[1]
	for _, c in lista do
		if not c.s.IsPlaying then
			return c
		end
		if c.inicio < elegido.inicio then
			elegido = c
		end
	end
	elegido.s:Stop() -- todos ocupados: corta al más viejo
	return elegido
end

local function tocarEn(lista: { Canal }, n: any, x: number?, y: number?): boolean
	if not iniciado or Sonidos.efectos == "" then
		return false
	end
	local t = Sonidos.tramos[n]
	if not t then
		return false -- un número sin WAV (el 174 del original)
	end
	local c = canalLibre(lista)
	c.inicio = os.clock()
	c.x, c.y = x, y
	local vol = Sonido.Base
	if x and y and c.a then
		c.a.WorldPosition = mundo(x, y)
		local px, py = posicion()
		if px and py then
			vol = Sonido.Base * Sonido.ganancia(math.sqrt((x - px) ^ 2 + (y - py) ^ 2))
		end
	end
	local s = c.s
	s.SoundGroup = grupoDe(n)
	s.Volume = vol
	s.PlaybackRegion = NumberRange.new(t[1], t[1] + t[2])
	s.TimePosition = t[1]
	s:Play()
	return true
end

-- Un efecto: en (x, y) con distancia y paneo, o plano si no tiene posición
function Sonido.tocar(n: any, x: number?, y: number?)
	if x and y then
		local px, py = posicion()
		if px and py and (math.abs(x - px) > Sonido.AlcanceX or math.abs(y - py) > Sonido.AlcanceY) then
			return
		end
		tocarEn(efectos, n, x, y)
	else
		tocarEn(planos, n)
	end
end

-- Un paso de un personaje vivo que se movió (cli/Red/Protocol.bas:2796-2809): 23 y 24 alternados, en el tile de antes
function Sonido.paso(id: number, x: number, y: number)
	local px, py = posicion()
	if not px or not py or math.abs(x - px) > Sonido.AlcanceX or math.abs(y - py) > Sonido.AlcanceY then
		return
	end
	local pie = not pieDe[id]
	pieDe[id] = pie
	tocarEn(pasos, if pie then 23 else 24, x, y)
end

-- P7 (docs/34 §1.3): mientras navegás suena el 50 (SND_NAVEGANDO, cli/Declares.bas:108) en bucle, en vez de uno por
-- paso (dura 5 s). Un Sound propio, sin posición.
local mar: Sound? = nil
function Sonido.navegando(si: boolean)
	if not iniciado or Sonidos.efectos == "" then
		return
	end
	local t = Sonidos.tramos[50]
	if not t then
		return
	end
	if not mar then
		local s = nuevoSound(SoundService)
		s.SoundGroup = grupos.ambiente
		s.Name = "AONavegando"
		s.Looped = true
		s.PlaybackRegion = NumberRange.new(t[1], t[1] + t[2])
		s.LoopRegion = NumberRange.new(t[1], t[1] + t[2])
		s.Volume = Sonido.Base * 0.5
		mar = s
	end
	local s = mar :: Sound
	if si and not s.IsPlaying then
		s.TimePosition = t[1]
		s:Play()
	elseif not si and s.IsPlaying then
		s:Stop()
	end
end

-- Fase 18 (docs/37 §2.6): la lluvia. Mientras llueve en el mapa del jugador, lluviaout en loop afuera y lluviain bajo
-- techo (cli/Areas/TileEngine.bas:950-978); sin posición. modo: "afuera" | "techo" | nil (corta)
local lluvia: Sound? = nil
local modoLluvia: string? = nil
function Sonido.lluvia(modo: string?)
	if modo == modoLluvia or not iniciado or Sonidos.efectos == "" then
		return
	end
	modoLluvia = modo
	if not lluvia then
		local s = nuevoSound(SoundService)
		s.SoundGroup = grupos.ambiente
		s.Name = "AOLluvia"
		s.Looped = true
		s.Volume = Sonido.Base * 0.6
		lluvia = s
	end
	local s = lluvia :: Sound
	local t = if modo then Sonidos.tramos[if modo == "techo" then "lluviain" else "lluviaout"] else nil
	if not t then
		s:Stop()
		return
	end
	s.PlaybackRegion = NumberRange.new(t[1], t[1] + t[2])
	s.LoopRegion = NumberRange.new(t[1], t[1] + t[2])
	s.TimePosition = t[1]
	s:Play()
end

-- Al parar la lluvia: lluviainend o lluviaoutend, una vez (cli/Red/Protocol.bas:3180-3193)
function Sonido.finLluvia(techo: boolean)
	Sonido.lluvia(nil)
	tocarEn(planos, if techo then "lluviainend" else "lluviaoutend")
end

-- Fase 18 (docs/37 §6): el crepitar de la fogata, en loop y con posición (cli/Areas/TileEngine.bas:980-994). Sin
-- posición, se corta
local fogata: Canal? = nil
function Sonido.fogata(x: number?, y: number?)
	if not iniciado or Sonidos.efectos == "" then
		return
	end
	local t = Sonidos.tramos["Fuego"]
	if not t then
		return
	end
	if not fogata then
		local a = Instance.new("Attachment")
		a.Name = "SonidoAOFogata"
		a.Parent = workspace.Terrain
		local s = nuevoSound(a)
		s.SoundGroup = grupos.ambiente
		s.Looped = true
		s.PlaybackRegion = NumberRange.new(t[1], t[1] + t[2])
		s.LoopRegion = NumberRange.new(t[1], t[1] + t[2])
		local c: Canal = { s = s, a = a, inicio = 0 }
		fogata = c
		table.insert(fijos, c)
	end
	local c = fogata :: Canal
	if x and y then
		if c.x ~= x or c.y ~= y then
			c.x, c.y = x, y
			local a = c.a :: Attachment
			a.WorldPosition = mundo(x, y)
		end
		if not c.s.IsPlaying then
			local px, py = posicion()
			if px and py then
				c.s.Volume = Sonido.Base * Sonido.ganancia(math.sqrt((x - px) ^ 2 + (y - py) ^ 2))
			end
			c.s.TimePosition = t[1]
			c.s:Play()
		end
	elseif c.s.IsPlaying then
		c.s:Stop()
	end
end

function Sonido.olvidar(id: number)
	pieDe[id] = nil
end

-- El click de los botones (SND_CLICK, cli/Declares.bas:105)
function Sonido.click()
	tocarEn(planos, "click")
end

-- Todos los botones de la interfaz hacen click (los del original, frmMain, inventario, ventanas). Los que no deben
-- (las filas de la lista de hechizos, el joystick) llevan el atributo SinClick.
function Sonido.engancharClicks(raiz: Instance)
	-- (Fase 34, docs/54 §4: lo que aprieta el puntero del mando no pasa por Activated; suena desde el registro)
	Click.alDisparar = function(b: GuiButton)
		if b:IsDescendantOf(raiz) and not b:GetAttribute("SinClick") then
			Sonido.click()
		end
	end
	local function enganchar(d: Instance)
		if d:IsA("GuiButton") and not d:GetAttribute("SinClick") then
			(d :: GuiButton).Activated:Connect(function()
				if not d:GetAttribute("SinClick") then
					Sonido.click()
				end
			end)
		end
	end
	for _, d in raiz:GetDescendants() do
		enganchar(d)
	end
	raiz.DescendantAdded:Connect(enganchar)
end

-- El saludo al abrir el comercio o el banco (cli/Red/Protocol.bas:1704, :1755)
function Sonido.saludo(quien: string)
	if quien == "banquero" then
		tocarEn(planos, "banquero" .. math.random(1, 7))
	else
		tocarEn(planos, "comerciante" .. math.random(1, 9))
	end
end

Sonido._interno = { efectos = efectos, pasos = pasos, planos = planos }

return Sonido
