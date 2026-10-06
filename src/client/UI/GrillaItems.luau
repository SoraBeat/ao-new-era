--!strict
--[[
	GrillaItems — una grilla de objetos para las ventanas de comercio y banco (docs/22 §5.6 y §6): el mismo dibujo
	que el inventario (clsGrapchicalInventory: fondo negro, rojo el seleccionado, cantidad arriba a la izquierda y la
	"X" roja sobre lo que no podés usar), sin doble click ni equipar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local Grh = require(script.Parent.Parent.Render.Grh)
local Inventario = require(script.Parent.Inventario)
local Click = require(script.Parent.Click)

local GrillaItems = {}

local GRH_NEGRO, GRH_ROJO = 26095, 26096

export type Item = { obj: number, cant: number, equipado: boolean? }
export type Grilla = {
	pintar: (self: Grilla) -> (),
	set: (self: Grilla, items: { [number]: Item }) -> (),
	seleccionar: (self: Grilla, slot: number) -> (),
	seleccionado: (self: Grilla) -> (number, Item?),
	items: { [number]: Item },
	sel: number,
	celdas: { any },
	alSeleccionar: ((number, Item?, boolean) -> ())?, -- slot, item, shift
	-- Fase 31: el casillero tocado (aunque esté vacío), antes de seleccionar. Si devuelve true el toque queda ahí: no
	-- selecciona ni llama a alSeleccionar (el modo "Mover" del banco, que espera el lugar de destino)
	alTocar: ((number) -> boolean)?,
}

local function pintarCelda(g: Grilla, slot: number)
	local c = g.celdas[slot]
	local d = g.items[slot]
	local o = d and Objetos[d.obj]
	Grh.aplicar(c.fondo, if o and slot == g.sel then GRH_ROJO else GRH_NEGRO)
	c.fondo.Size = UDim2.fromScale(1, 1)
	c.item.Visible = o ~= nil
	if o then
		Grh.aplicar(c.item, o.grh)
		c.item.Size = UDim2.fromScale(1, 1)
	end
	c.cant.Text = if not o then "" elseif o.infinita then "∞" else tostring((d :: Item).cant) -- (la Flecha de Rama, docs/50 §1)
	c.e.Visible = o ~= nil and (d :: Item).equipado == true
	c.x.Visible = o ~= nil and not (d :: Item).equipado and Inventario.incompatible((d :: Item).obj)
end

local Metodos = {}
Metodos.__index = Metodos

function Metodos.pintar(self: Grilla)
	for slot in self.celdas do
		pintarCelda(self, slot)
	end
end

function Metodos.set(self: Grilla, items: { [number]: Item })
	self.items = items
	if self.sel ~= 0 and not items[self.sel] then
		self.sel = 0
	end
	self:pintar()
end

function Metodos.seleccionar(self: Grilla, slot: number)
	self.sel = if self.items[slot] then slot else 0
	self:pintar()
end

function Metodos.seleccionado(self: Grilla): (number, Item?)
	return self.sel, self.items[self.sel]
end

-- cantidad de casillas, en `columnas` columnas de `celda` px, arriba a la izquierda de `parent`
function GrillaItems.nueva(parent: GuiObject, cantidad: number, columnas: number, celda: number, tamTexto: number?): Grilla
	local tam = tamTexto or 11
	local g = setmetatable({ items = {}, sel = 0, celdas = {} }, Metodos) :: any
	for slot = 1, cantidad do
		local b = Instance.new("ImageButton")
		b.Name = `Slot{slot}`
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(celda, celda)
		b.Position = UDim2.fromOffset(((slot - 1) % columnas) * celda, ((slot - 1) // columnas) * celda)
		b.ZIndex = 3
		b.Parent = parent
		local fondo = Instance.new("ImageLabel")
		fondo.BackgroundTransparency = 1
		fondo.ResampleMode = Enum.ResamplerMode.Pixelated
		fondo.ZIndex = 3
		fondo.Parent = b
		local item = Instance.new("ImageLabel")
		item.BackgroundTransparency = 1
		item.ResampleMode = Enum.ResamplerMode.Pixelated
		item.ZIndex = 4
		item.Parent = b
		local cant = Instance.new("TextLabel")
		cant.BackgroundTransparency = 1
		cant.Position = UDim2.fromOffset(1, 0)
		cant.Size = UDim2.new(1, 0, 0, tam + 2)
		cant.Font = Enum.Font.Arial
		cant.TextSize = tam
		cant.TextColor3 = Color3.new(1, 1, 1)
		cant.TextStrokeTransparency = 0.3
		cant.TextXAlignment = Enum.TextXAlignment.Left
		cant.TextYAlignment = Enum.TextYAlignment.Top
		cant.ZIndex = 5
		cant.Parent = b
		local e = Instance.new("TextLabel")
		e.BackgroundTransparency = 1
		e.Position = UDim2.fromScale(20 / 32, 20 / 32)
		e.Size = UDim2.fromScale(12 / 32, 12 / 32)
		e.Font = Enum.Font.ArialBold
		e.TextSize = tam
		e.TextColor3 = Color3.new(1, 1, 1)
		e.TextStrokeTransparency = 0.3
		e.Text = "E"
		e.ZIndex = 5
		e.Parent = b
		local x = e:Clone()
		x.Name = "X"
		x.Text = "X"
		x.TextColor3 = Color3.fromRGB(200, 30, 30)
		x.Parent = b
		g.celdas[slot] = { boton = b, fondo = fondo, item = item, cant = cant, e = e, x = x }
		Click.activado(b, function(input: InputObject?)
			local shift = false
			local uis = game:GetService("UserInputService")
			shift = uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
			local tocar = g.alTocar
			if tocar and tocar(slot) then
				return
			end
			g:seleccionar(slot)
			local f = g.alSeleccionar
			if f then
				f(g.sel, g.items[g.sel], shift)
			end
		end)
	end
	g:pintar()
	return g :: Grilla
end

return GrillaItems
