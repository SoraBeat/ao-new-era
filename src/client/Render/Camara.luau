--!strict
--[[
	Camara — cámara cenital casi ortográfica (decisión D-03, docs/13-spike-render.md).

	Mira derecho hacia abajo, de modo que se vean VISTA_ALTO tiles en vertical.
	"Arriba" en pantalla = norte = -Z del mundo.

	FOV 40 (docs/26 §4): todo el mundo es un solo plano (el SurfaceGui del lienzo), así que la perspectiva no
	deforma nada y no hace falta un FOV bajo. Con FOV 10 la cámara quedaba a ~800 studs, y con la calidad gráfica
	baja (la automática la baja sola cuando caen los fps) Roblox recorta lo que está tan lejos: la vista quedaba
	celeste. Con FOV 40 queda a ~190 studs.
]]

local Grilla = require(game:GetService("ReplicatedStorage").Shared.Mundo.Grilla)

local Camara = {}

Camara.FOV = 40
Camara.VISTA_ALTO = 19 -- tiles en vertical, como el viewport del cliente original (23×19)

local objetivo = Vector3.zero
local DISTANCIA = (Camara.VISTA_ALTO * Grilla.TILE_STUDS / 2) / math.tan(math.rad(Camara.FOV / 2))
-- Corrimiento del centro de la pantalla respecto del PJ, en tiles (x al este, y al sur). En PC el PJ va en el
-- centro del hueco de la vista de la ventana original, no en el de la pantalla (docs/17 §2.2).
local offX, offY = 0, 0

local function mira(): Vector3
	return objetivo + Vector3.new(offX * Grilla.TILE_STUDS, 0, offY * Grilla.TILE_STUDS)
end

local function aplicar(camara: Camera)
	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = Camara.FOV
	local m = mira()
	camara.CFrame = CFrame.lookAt(m + Vector3.new(0, DISTANCIA, 0), m, Vector3.new(0, 0, -1))
end

-- Cuántos tiles de alto abarca la pantalla y cuánto se corre el centro respecto del PJ (lo decide el HUD)
function Camara.configurar(altoTiles: number, dx: number, dy: number)
	Camara.VISTA_ALTO = altoTiles
	DISTANCIA = (altoTiles * Grilla.TILE_STUDS / 2) / math.tan(math.rad(Camara.FOV / 2))
	offX, offY = dx, dy
	local camara = workspace.CurrentCamera
	if camara then
		aplicar(camara)
	end
end

local conexion: RBXScriptConnection? = nil
local function enganchar()
	local camara = workspace.CurrentCamera
	if not camara then
		return
	end
	if conexion then
		conexion:Disconnect()
	end
	aplicar(camara)
	-- El CameraModule de Roblox vuelve a poner CameraType = Custom al arrancar: se corrige al vuelo
	conexion = camara:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camara.CameraType ~= Enum.CameraType.Scriptable then
			aplicar(camara)
		end
	end)
end

function Camara.iniciar()
	enganchar()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(enganchar)
end

-- Centra la cámara en un punto del mundo (sobre el piso)
function Camara.centrarEn(punto: Vector3)
	objetivo = punto
	local camara = workspace.CurrentCamera
	if camara then
		local m = mira()
		camara.CFrame = CFrame.lookAt(m + Vector3.new(0, DISTANCIA, 0), m, Vector3.new(0, 0, -1))
	end
end

-- Relación ancho/alto de la pantalla
function Camara.aspecto(): number
	local camara = workspace.CurrentCamera
	if not camara or camara.ViewportSize.Y == 0 then
		return 16 / 9
	end
	return camara.ViewportSize.X / camara.ViewportSize.Y
end

return Camara
