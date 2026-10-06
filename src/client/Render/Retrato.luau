--!strict
--[[
	Retrato — un personaje quieto dibujado en la interfaz (el panel de cuenta y la vista previa de la creación, Fase 12).
	Arma cuerpo, cabeza, casco, arma y escudo con el mismo armado que Render/Personajes (CharRender): la cabeza con el
	headOffset del cuerpo y el casco 34 px más arriba (OFFSET_HEAD, Declares.bas:983).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Indices = require(ReplicatedStorage.Shared.Generado.Indices)
local Grh = require(script.Parent.Grh)

local Retrato = {}

local OFFSET_HEAD = -34

export type Retrato = {
	marco: Frame,
	partes: { [string]: ImageLabel },
}

-- Crea el retrato dentro de parent. (x, y) = esquina superior izquierda del tile donde "está parado", en px de parent.
function Retrato.nuevo(parent: Instance, x: number, y: number, zIndex: number?): Retrato
	local marco = Instance.new("Frame")
	marco.Name = "Retrato"
	marco.BackgroundTransparency = 1
	marco.Position = UDim2.fromOffset(x, y)
	marco.Size = UDim2.fromOffset(32, 32)
	marco.ZIndex = zIndex or 1
	marco.Parent = parent
	local partes = {}
	for i, nombre in { "cuerpo", "cabeza", "casco", "arma", "escudo" } do
		local l = Instance.new("ImageLabel")
		l.Name = nombre
		l.BackgroundTransparency = 1
		l.ResampleMode = Enum.ResamplerMode.Pixelated
		l.ZIndex = (zIndex or 1) + i
		l.Visible = false
		l.Parent = marco
		partes[nombre] = l
	end
	return { marco = marco, partes = partes }
end

-- apariencia: { cuerpo, cabeza, casco, arma, escudo }; heading 1=N 2=E 3=S 4=O. muerto: translúcido y celeste.
function Retrato.dibujar(r: Retrato, apariencia: any, heading: number?, muerto: boolean?)
	local h = heading or 3
	local p = r.partes
	local cuerpo = Indices.cuerpos[apariencia.cuerpo]
	local cabeza = Indices.cabezas[apariencia.cabeza]
	local casco = apariencia.casco ~= 0 and Indices.cascos[apariencia.casco] or nil
	local arma = apariencia.arma ~= 0 and Indices.armas[apariencia.arma] or nil
	local escudo = apariencia.escudo ~= 0 and Indices.escudos[apariencia.escudo] or nil
	local hox, hoy = 0, 0
	if cuerpo then
		hox, hoy = cuerpo.headOffset[1], cuerpo.headOffset[2]
	end
	local function poner(label: ImageLabel, g: number?, x: number, y: number)
		label.Visible = g ~= nil and g ~= 0
		if g and g ~= 0 then
			Grh.aplicar(label, g, 1)
			Grh.ubicar(label, g, x, y)
		end
	end
	poner(p.cuerpo, cuerpo and cuerpo.walk[h], 0, 0)
	poner(p.cabeza, cabeza and cabeza[h], hox, hoy)
	poner(p.casco, casco and casco[h], hox + 1, hoy + OFFSET_HEAD)
	poner(p.arma, arma and arma[h], 0, 0)
	poner(p.escudo, escudo and escudo[h], 0, 0)
	for _, l in { p.cuerpo, p.cabeza } do
		l.ImageTransparency = if muerto then 1 - 100 / 255 else 0
		l.ImageColor3 = if muerto then Color3.fromRGB(150, 200, 255) else Color3.new(1, 1, 1)
	end
end

function Retrato.visible(r: Retrato, v: boolean)
	r.marco.Visible = v
end

-- Solo una cabeza (el carrusel de la creación), centrada en un cuadro de w × h
function Retrato.cabeza(label: ImageLabel, cabeza: number, w: number, h: number)
	local c = Indices.cabezas[cabeza]
	local g = c and c[3]
	label.Visible = g ~= nil
	if g then
		Grh.aplicar(label, g, 1)
		-- Los Grh de cabeza miden 17 × 50 con la cara arriba (unos 16 px): se centra esa parte
		local gw = Grh.tamano(g)
		label.Position = UDim2.fromOffset((w - gw) // 2, (h - 16) // 2 - 1)
	end
end

return Retrato
