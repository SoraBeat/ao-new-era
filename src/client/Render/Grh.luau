--!strict
--[[
	Grh — dibujar gráficos de AO en ImageLabels.

	Un "Grh" es el índice de un gráfico de AO (docs/09-graficos-y-animaciones.md §2). Puede ser
	estático (un recorte de un atlas) o animado (una lista de Grh estáticos + velocidad).

	Uso:
		local Grh = require(path.to.Render.Grh)
		local label = Grh.nuevo(parent, 6008)              -- ImageLabel listo, frame 1
		Grh.ubicar(label, 6008, x, y)                       -- posición en px con el anclaje de AO
		Grh.animar(label, 1505)                             -- lo anima en loop
		Grh.animar(label, fxGrh, 2, function() ... end)     -- 2 vueltas y avisa al terminar
		Grh.animar(label, 1505, -1, nil, 0)                -- loop sincronizado con reloj global
		Grh.detener(label)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Datos = require(ReplicatedStorage.Shared.Generado.Grh)

local TILE_PX = 32

local Grh = {}

-- Frame estático que corresponde a un Grh (animado o no) en el frame n (1-based)
function Grh.frame(grhIndex: number, n: number?): number
	local a = Datos.anim[grhIndex]
	if not a then
		return grhIndex
	end
	return a.frames[(((n or 1) - 1) % #a.frames) + 1]
end

-- Milisegundos por frame de un Grh animado (0 si es estático)
function Grh.msPorFrame(grhIndex: number): number
	local a = Datos.anim[grhIndex]
	return if a then a.speed / #a.frames else 0
end

function Grh.existe(grhIndex: number): boolean
	return Datos.grh[Grh.frame(grhIndex)] ~= nil
end

-- Tamaño en px del Grh (del primer frame si es animado)
function Grh.tamano(grhIndex: number): (number, number)
	local g = Datos.grh[Grh.frame(grhIndex)]
	if not g then
		return 0, 0
	end
	return g[4], g[5]
end

-- Pone en el label la imagen de un Grh estático
local function aplicarEstatico(label: ImageLabel, estatico: number)
	local g = Datos.grh[estatico]
	if not g then
		return
	end
	label.Image = Datos.atlas[g[1]]
	label.ImageRectOffset = Vector2.new(g[2], g[3])
	label.ImageRectSize = Vector2.new(g[4], g[5])
	label.Size = UDim2.fromOffset(g[4], g[5])
end

function Grh.aplicar(label: ImageLabel, grhIndex: number, n: number?)
	aplicarEstatico(label, Grh.frame(grhIndex, n))
end

-- Posición con Center=1 de Draw_Grh (TileEngine.bas:1850-1858).
-- (x, y) = esquina superior izquierda del tile, en px del canvas.
function Grh.ubicar(label: ImageLabel, grhIndex: number, x: number, y: number)
	local w, h = Grh.tamano(grhIndex)
	if w ~= TILE_PX then
		x -= (w - TILE_PX) // 2
	end
	if h ~= TILE_PX then
		y -= h - TILE_PX
	end
	label.Position = UDim2.fromOffset(x, y)
end

function Grh.nuevo(parent: Instance, grhIndex: number, zIndex: number?): ImageLabel
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.ZIndex = zIndex or 1
	Grh.aplicar(label, grhIndex, 1)
	label.Parent = parent
	return label
end

-- ─── Animación ───────────────────────────────────────────────────────────────
-- Réplica de Draw_Grh: el frame depende del tiempo transcurrido y de Speed (ms por ciclo).
type Anim = {
	grh: number,
	t0: number,
	vueltas: number, -- -1 = infinito; n = se reproduce n+1 veces (loops de AO)
	velocidad: number,
	actual: number,
	alTerminar: (() -> ())?,
}
local animaciones: { [ImageLabel]: Anim } = {}

-- t0: instante de inicio (os.clock). Los tiles del mapa usan 0 para que toda el agua vaya sincronizada.
-- velocidad: multiplicador; los personajes caminan con 0,5 (Movement_Speed de CharRender, docs/09 §4.3).
function Grh.animar(label: ImageLabel, grhIndex: number, vueltas: number?, alTerminar: (() -> ())?, t0: number?, velocidad: number?)
	if not Datos.anim[grhIndex] then
		Grh.aplicar(label, grhIndex)
		return
	end
	animaciones[label] = {
		grh = grhIndex,
		t0 = t0 or os.clock(),
		vueltas = vueltas or -1,
		velocidad = velocidad or 1,
		actual = 0,
		alTerminar = alTerminar,
	}
end

function Grh.animando(label: ImageLabel): boolean
	return animaciones[label] ~= nil
end

function Grh.detener(label: ImageLabel, volverAlFrame1: boolean?)
	local a = animaciones[label]
	animaciones[label] = nil
	if a and volverAlFrame1 then
		Grh.aplicar(label, a.grh, 1)
	end
end

RunService.RenderStepped:Connect(function()
	local ahora = os.clock()
	for label, a in animaciones do
		if not label.Parent then
			animaciones[label] = nil
			continue
		end
		local d = Datos.anim[a.grh]
		local n = #d.frames
		local transcurrido = math.floor((ahora - a.t0) * 1000 * a.velocidad / (d.speed / n))
		if a.vueltas >= 0 and transcurrido // n > a.vueltas then
			animaciones[label] = nil
			if a.alTerminar then
				task.spawn(a.alTerminar)
			end
			continue
		end
		local f = d.frames[(transcurrido % n) + 1]
		if f ~= a.actual then
			aplicarEstatico(label, f)
			a.actual = f
		end
	end
end)

return Grh
