--!strict
--[[
	Clima — lo que se ve y se oye del ambiente (Fase 18, docs/37): la lluvia, el color del día y la fogata.

	Lluvia (§2.5 a §2.7): el servidor dice si llueve (atributo AO_Lluvia del Workspace). Si además llueve en este mapa
	(Ambiente.llueveEn):
	  - Dos capas de gotas encima de todo el lienzo: un mosaico que se desliza a la velocidad y con la inclinación de las
	    partículas del original (cli/Motor/mDx8_Particulas.bas:1024-1045, particulas.ini [8]). Van ancladas al mundo: al
	    caminar no se arrastran con la vista. Bajo techo no se dibujan (Char_Techo).
	  - El loop de afuera o el de bajo techo, y el final al parar (Sonido.lluvia / finLluvia).
	  - El aviso en la consola (DA18-06 A).
	El día (§5.2): solo visual. El color sale del reloj del servidor (workspace:GetServerTimeNow()), o de la fase fija
	del panel de Admin (atributo AO_Hora); multiplica el mapa y los personajes (Mundo.setLuz, Personajes.setLuz). En los
	dungeons, o con "Ver la noche" apagado, siempre es de día.
	Fogata (§6): mientras haya una a ±8 x ±6 tiles, su crepitar con posición (Map_CheckBonfire).
	Nieve (Fase 20, docs/39 §9): en los mapas de nieve (Cfg.MapasNieve) cae siempre. Dos capas de copos como las de la
	lluvia, más lentas y con un vaivén hacia los costados; bajo techo no se dibujan. Solo se ve: sin sonido ni efecto.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cfg = require(ReplicatedStorage.Shared.Config.Ambiente)
local Ambiente = require(ReplicatedStorage.Shared.Mundo.Ambiente)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets) :: any
local Mundo = require(script.Parent.Mundo)
local Personajes = require(script.Parent.Personajes)
local Sonido = require(script.Parent.Parent.Audio.Sonido)
local Consola = require(script.Parent.Parent.UI.Consola)

local Clima = {}

-- La caída del original: de 7 a 15 px hacia abajo y de 0 a 7 a la derecha por paso, unos 30 pasos por segundo
local VX, VY = 105, 330
local FUNDIDO_SEG = 1
local Z_LLUVIA = 600000 -- encima de la capa 4 (los techos)
-- { velocidad, lado del mosaico en px, transparencia }: la de atrás y, más grande y rápida, la de adelante
local CAPAS = { { 1, 256, 0.1 }, { 1.3, 384, 0.4 } }
local BLANCO = Color3.new(1, 1, 1)

type Capa = { label: ImageLabel, vel: number, tam: number, transp: number }

local capas: { Capa } = {}
local alfa = 0
-- Nieve: { velocidad, lado del mosaico en px, transparencia, desfase del vaivén }
local CAPAS_NIEVE = { { 1, 256, 0.05, 0 }, { 1.5, 384, 0.25, 1.7 } }
local capasNieve: { Capa & { fase: number } } = {}
local alfaNieve = 0
local llovia = false
local verNoche = true
local faseAnterior: number? = nil
local medianoche = false
local proximaRevision = 0
local mapaAnterior = 0

function Clima.setVerNoche(si: boolean)
	verNoche = si
	proximaRevision = 0
end

local function crearCapas()
	local gui = Mundo.lienzoGui()
	for i, d in CAPAS do
		local l = Instance.new("ImageLabel")
		l.Name = `Lluvia{i}`
		l.BackgroundTransparency = 1
		l.Image = UiAssets.lluvia
		l.ScaleType = Enum.ScaleType.Tile
		l.TileSize = UDim2.fromOffset(d[2], d[2])
		l.Size = UDim2.new(1, 2 * d[2], 1, 2 * d[2])
		l.ZIndex = Z_LLUVIA + i
		l.Visible = false
		l.Parent = gui
		table.insert(capas, { label = l, vel = d[1], tam = d[2], transp = d[3] })
	end
	for i, d in CAPAS_NIEVE do
		local l = Instance.new("ImageLabel")
		l.Name = `Nieve{i}`
		l.BackgroundTransparency = 1
		l.Image = UiAssets.nieve
		l.ScaleType = Enum.ScaleType.Tile
		l.TileSize = UDim2.fromOffset(d[2], d[2])
		l.Size = UDim2.new(1, 2 * d[2], 1, 2 * d[2])
		l.ZIndex = Z_LLUVIA + 2 + i
		l.Visible = false
		l.Parent = gui
		table.insert(capasNieve, { label = l, vel = d[1], tam = d[2], transp = d[3], fase = d[4] })
	end
end

-- La fogata más cercana a ±FogataX, ±FogataY del jugador
local function buscarFogata(cx: number, cy: number): (number?, number?)
	local mejor, fx, fy = math.huge, nil, nil
	for y = cy - Cfg.FogataY, cy + Cfg.FogataY do
		for x = cx - Cfg.FogataX, cx + Cfg.FogataX do
			if Mundo.grhObjeto(x, y) == Cfg.GrhFogata then
				local d = (x - cx) ^ 2 + (y - cy) ^ 2
				if d < mejor then
					mejor, fx, fy = d, x, y
				end
			end
		end
	end
	return fx, fy
end

-- El color del día y sus avisos
local function revisarDia(mapa: any)
	local meta = Mapas.meta(mapa.numero)
	local hay = verNoche and Ambiente.hayNoche(if meta then meta.zona else "")
	local fija = workspace:GetAttribute(Cfg.AtribHora)
	local color = BLANCO
	if hay and typeof(fija) == "string" and Cfg.Color[fija] then
		color = Cfg.Color[fija]
		faseAnterior = nil
	elseif hay then
		-- Fase 21 (docs/40 §6.2): cada servidor arranca en una hora al azar (el desfase lo pone AmbienteService)
		local t = workspace:GetServerTimeNow() + (tonumber(workspace:GetAttribute(Cfg.AtribDesfaseHora)) or 0)
		color = Ambiente.luz(t)
		local i, _, desde = Ambiente.fase(t)
		if faseAnterior and faseAnterior ~= i then
			local aviso = Cfg.Fases[i][3]
			if aviso then
				Consola.agregar(aviso, "info")
			end
			medianoche = false
		end
		-- "Es media noche.", a la mitad de la noche
		local f = Cfg.Fases[i]
		if f[1] ~= "noche" then
			medianoche = false
		end
		if f[1] == "noche" and not medianoche and faseAnterior and desde >= (Cfg.MedianocheMin - f[2]) * 60 then
			medianoche = true
			if desde < (Cfg.MedianocheMin - f[2]) * 60 + 5 then
				Consola.agregar(Cfg.MsgMedianoche, "info")
			end
		end
		faseAnterior = i
	else
		faseAnterior = nil
	end
	Mundo.setLuz(color)
	Personajes.setLuz(color)
end

function Clima.iniciar(posicion: () -> (number?, number?))
	crearCapas()
	workspace:GetAttributeChangedSignal(Cfg.AtribHora):Connect(function()
		proximaRevision = 0
	end)
	RunService:BindToRenderStep("AO_Clima", Enum.RenderPriority.Character.Value + 2, function(dt: number)
		local mapa = Mundo.mapa()
		local px, py = posicion()
		if not mapa or not px or not py then
			return
		end
		local cx, cy = math.floor(px + 0.5), math.floor(py + 0.5)
		local lloviendo = workspace:GetAttribute(Cfg.AtribLluvia) == true
		local llueveEnMapa = Ambiente.llueveEn(mapa.numero)
		local aca = lloviendo and llueveEnMapa
		local techo = Mapas.bajoTecho(mapa, cx, cy)

		-- El aviso y el sonido
		if aca and not llovia then
			Consola.agregar(Cfg.MsgLluvia, "info")
		elseif llovia and not aca then
			if llueveEnMapa then -- paró la lluvia
				Consola.agregar(Cfg.MsgFinLluvia, "info")
				Sonido.finLluvia(techo)
			end
		end
		llovia = aca
		Sonido.lluvia(if aca then (if techo then "techo" else "afuera") else nil)

		-- Las gotas
		local objetivo = if aca and not techo then 1 else 0
		if alfa < objetivo then
			alfa = math.min(objetivo, alfa + dt / FUNDIDO_SEG)
		elseif alfa > objetivo then
			alfa = math.max(objetivo, alfa - dt / FUNDIDO_SEG)
		end
		if alfa > 0 then
			local ox, oy = Mundo.pxDeTile(1, 1)
			local t = os.clock()
			for _, c in capas do
				local x = (VX * c.vel * t + ox) % c.tam
				local y = (VY * c.vel * t + oy) % c.tam
				c.label.Position = UDim2.fromOffset(x - c.tam, y - c.tam)
				c.label.ImageTransparency = 1 - (1 - c.transp) * alfa
				c.label.Visible = true
			end
		elseif capas[1].label.Visible then
			for _, c in capas do
				c.label.Visible = false
			end
		end

		-- La nieve (Fase 20, docs/39 §9): siempre, en sus mapas; bajo techo no
		local nieva = if Cfg.MapasNieve[mapa.numero] and not techo then 1 else 0
		if alfaNieve < nieva then
			alfaNieve = math.min(nieva, alfaNieve + dt / FUNDIDO_SEG)
		elseif alfaNieve > nieva then
			alfaNieve = math.max(nieva, alfaNieve - dt / FUNDIDO_SEG)
		end
		if alfaNieve > 0 then
			local ox, oy = Mundo.pxDeTile(1, 1)
			local t = os.clock()
			for _, c in capasNieve do
				local vaiven = Cfg.NieveVaiven * math.sin((t + c.fase) * 2 * math.pi / Cfg.NievePeriodo)
				local x = (vaiven * c.vel + ox) % c.tam
				local y = (Cfg.NieveVY * c.vel * t + oy) % c.tam
				c.label.Position = UDim2.fromOffset(x - c.tam, y - c.tam)
				c.label.ImageTransparency = 1 - (1 - c.transp) * alfaNieve
				c.label.Visible = true
			end
		elseif capasNieve[1].label.Visible then
			for _, c in capasNieve do
				c.label.Visible = false
			end
		end

		-- Cuatro veces por segundo (y enseguida al cambiar de mapa): el color del día y la fogata
		local ahora = os.clock()
		if mapa.numero ~= mapaAnterior then
			mapaAnterior = mapa.numero
			proximaRevision = 0
		end
		if ahora >= proximaRevision then
			proximaRevision = ahora + 0.25
			revisarDia(mapa)
			Sonido.fogata(buscarFogata(cx, cy))
		end
	end)
end

return Clima
