--!strict
--[[
	Hechizos — la lista de hechizos (hlst) con "Lanzar" e "Info" (docs/15 §2.1, docs/17 §8).

	- Una fila por lugar (MAXUSERHECHIZOS, 35 en el original; Magia.MaxHechizos = 40 desde la Fase 27): los hechizos del
	  PJ y "Nada" en cada slot vacío (Red/Protocol.bas:3565-3578, spanish.json "NADA"). El Guerrero ve todas en "Nada"
	  (DF7-02 A).
	- Click en una fila: sólo cambia la selección (local).
	- "Lanzar" (frmMain.frm:2437-2451): con un "Nada" seleccionado no hace nada; sin selección manda el slot 0
	  (el servidor contesta "Primero selecciona el hechizo que quieres lanzar!"); si no, arma el cursor.
	- "Info" (frmMain.frm:2461-2473): nombre, descripción, skill, maná y energía en la consola.
	Los botones los pone el HUD (en PC van en su lugar del frmMain; en celular, en el panel).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Magia = require(ReplicatedStorage.Shared.Config.Magia)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Consola = require(script.Parent.Consola)
local Click = require(script.Parent.Click)

local Hechizos = {}

local FILAS = Magia.MaxHechizos
local NADA = "Nada"

local lista: { number } = {}
local seleccionado = 0
local filas: { TextButton } = {}
local alCambiar: ((number, number?) -> ())? = nil

-- La lista traslúcida (el celular, cuando el mando cambia de hechizo: Fase 35, docs/56 §3): nil = se ve entera
local tenue: number? = nil

local function pintar()
	for i, b in filas do
		local sel = i == seleccionado
		b.BackgroundColor3 = if sel then Color3.fromRGB(0, 0, 128) else Color3.new(0, 0, 0)
		-- traslúcida: las filas sin fondo (queda el velo del panel) y la elegida a medias; las letras, con borde
		b.BackgroundTransparency = if tenue == nil then 0 elseif sel then tenue else 1
		b.TextStrokeTransparency = if tenue == nil then 1 else 0.25
	end
end

-- k: cuánto se transparenta (0 a 1), o nil para verla entera. Las letras no se transparentan: hay que poder leerlas.
function Hechizos.setTenue(k: number?)
	if k == tenue then
		return
	end
	tenue = k
	local primera = filas[1]
	local marco = primera and primera.Parent
	if marco and marco:IsA("ScrollingFrame") then
		marco.BackgroundTransparency = if k == nil then 0 else 1
	end
	pintar()
end

function Hechizos.nombre(slot: number): string
	local h = Magia.Hechizos[lista[slot] or 0]
	return if h then h.nombre else NADA
end

function Hechizos.seleccionado(): (number, number?)
	return seleccionado, lista[seleccionado]
end

function Hechizos.tieneHechizos(): boolean
	return #lista > 0
end

-- Fase 22 (docs/41 §1): los atajos buscan el hechizo por su id y se enteran cuando la lista cambia
function Hechizos.lista(): { number }
	return lista
end

-- Lo pone el HUD del celular (Fase 22): el jugador tocó una fila (no cuando la selección cambia por otra vía)
local alTocarFila: ((number) -> ())? = nil
function Hechizos.alTocarFila(f: (number) -> ())
	alTocarFila = f
end

local alCambiarLista: { () -> () } = {}
function Hechizos.alCambiarLista(f: () -> ())
	table.insert(alCambiarLista, f)
end

function Hechizos.alCambiarSeleccion(f: (number, number?) -> ())
	alCambiar = f
end

export type Opciones = { fila: number?, tamTexto: number? }

function Hechizos.montar(parent: GuiObject, opciones: Opciones?)
	local o = opciones or {}
	local alto = o.fila or 14
	for _, b in filas do
		b:Destroy()
	end
	filas = {}
	local sf = parent:FindFirstChild("ListaHechizos") :: ScrollingFrame?
	if sf then
		sf:Destroy()
	end
	local marco = Instance.new("ScrollingFrame")
	marco.Name = "ListaHechizos"
	marco.BackgroundColor3 = Color3.new(0, 0, 0)
	marco.BorderSizePixel = 0
	marco.Size = UDim2.fromScale(1, 1)
	marco.CanvasSize = UDim2.fromOffset(0, FILAS * alto)
	marco.ScrollingDirection = Enum.ScrollingDirection.Y
	marco.ScrollBarThickness = 8
	marco.ScrollBarImageColor3 = Color3.fromRGB(120, 100, 70)
	marco.BackgroundTransparency = if tenue == nil then 0 else 1
	marco.Parent = parent
	for i = 1, FILAS do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, -8, 0, alto)
		b.Position = UDim2.fromOffset(0, (i - 1) * alto)
		b.Font = Enum.Font.Arial
		b.TextSize = o.tamTexto or 12
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = " " .. Hechizos.nombre(i)
		b:SetAttribute("SinClick", true) -- lstHechizos es una lista: sin click (docs/29 §3.2)
		b.Parent = marco
		Click.activado(b, function()
			seleccionado = i
			pintar()
			if alCambiar then
				alCambiar(i, lista[i])
			end
			if alTocarFila then
				alTocarFila(i)
			end
		end)
		filas[i] = b
	end
	pintar()
end

function Hechizos.iniciar(l: { number })
	lista = l
end

-- Otro personaje (Fase 25, docs/44 §9: se volvió a la pantalla de personajes y se entró de nuevo): su lista, con las
-- filas ya armadas
function Hechizos.reiniciar(l: { number })
	lista = l
	seleccionado = 0
	for i, b in filas do
		b.Text = " " .. Hechizos.nombre(i)
	end
	pintar()
	for _, f in alCambiarLista do
		f()
	end
end

-- Aprendió un hechizo con un pergamino (docs/22 §9): va al slot que dijo el servidor
function Hechizos.actualizar(slot: number, id: number)
	lista[slot] = id
	local b = filas[slot]
	if b then
		b.Text = " " .. Hechizos.nombre(slot)
	end
	for _, f in alCambiarLista do
		f()
	end
end

-- cmdMoverHechi_Click (frmMain.frm:1528-1560): sube o baja el seleccionado. En el primero no sube y en el último no
-- baja (sin mensaje); el servidor intercambia y manda los dos slots, y la selección acompaña al hechizo.
function Hechizos.mover(arriba: boolean)
	if seleccionado == 0 then
		return
	end
	local otro = if arriba then seleccionado - 1 else seleccionado + 1
	if otro < 1 or otro > FILAS then
		return
	end
	Remotes.evento("MoverHechizo"):FireServer(arriba, seleccionado)
	seleccionado = otro
	pintar()
	local b = filas[otro]
	local sf = b and b.Parent :: ScrollingFrame?
	if b and sf and sf:IsA("ScrollingFrame") then
		-- que la fila seleccionada quede a la vista
		local y, alto = b.Position.Y.Offset, b.Size.Y.Offset
		local vista = sf.AbsoluteWindowSize.Y
		if y < sf.CanvasPosition.Y then
			sf.CanvasPosition = Vector2.new(0, y)
		elseif y + alto > sf.CanvasPosition.Y + vista then
			sf.CanvasPosition = Vector2.new(0, y + alto - vista)
		end
	end
	if alCambiar then
		alCambiar(otro, lista[otro])
	end
end

-- El mando (Fase 18, docs/37 §7.2): RB / LB pasan al hechizo siguiente o anterior, salteando los "Nada" y dando la vuelta
function Hechizos.elegir(paso: number)
	local function hay(i: number): boolean
		local id = lista[i]
		return id ~= nil and id ~= 0 -- 0 también es "Nada" (lo que deja MoverHechizo)
	end
	local n = if seleccionado == 0 and paso < 0 then 1 else seleccionado -- sin selección, LB arranca del último
	for _ = 1, FILAS do
		n = (n - 1 + paso) % FILAS + 1
		if hay(n) then
			break
		end
	end
	if not hay(n) or n == seleccionado then
		return
	end
	seleccionado = n
	pintar()
	local b = filas[n]
	local sf = b and b.Parent :: ScrollingFrame?
	if b and sf and sf:IsA("ScrollingFrame") then
		local y, alto = b.Position.Y.Offset, b.Size.Y.Offset
		local vista = sf.AbsoluteWindowSize.Y
		if y < sf.CanvasPosition.Y then
			sf.CanvasPosition = Vector2.new(0, y)
		elseif y + alto > sf.CanvasPosition.Y + vista then
			sf.CanvasPosition = Vector2.new(0, y + alto - vista)
		end
	end
	if alCambiar then
		alCambiar(n, lista[n])
	end
end

-- btnLanzar_Click: alLanzar(slot) es Controlador.lanzar
function Hechizos.lanzar(alLanzar: (number) -> ())
	if seleccionado ~= 0 and not lista[seleccionado] then
		return -- "Nada" seleccionado (frmMain.frm:2439)
	end
	alLanzar(seleccionado)
end

-- Fase 27 (docs/47 §2): "Asesino", "Clerigo y Paladin", o "las clases magicas" si son todas
local ORDEN_CLASES = { "Mago", "Clerigo", "Asesino", "Bardo", "Druida", "Bandido", "Paladin" }
local function soloPara(clases: { [string]: boolean }): string
	local l = {}
	for _, c in ORDEN_CLASES do
		if clases[c] then
			table.insert(l, c)
		end
	end
	if #l == #ORDEN_CLASES then
		return "las clases magicas"
	end
	return table.concat(l, " y ")
end

function Hechizos.info()
	local h = Magia.Hechizos[lista[seleccionado] or 0]
	if not h then
		return
	end
	Consola.agregar(
		"%%%%%%%%%%%% INFO. DEL HECHIZO %%%%%%%%%%%%\n"
			.. `Nombre: {h.nombre}\n`
			.. (if h.clases then `Solo para: {soloPara(h.clases)}\n` else "")
			.. `Descripcion: {h.desc}\n`
			.. `Puntos de Habilidad requerida: {h.minSkill}\n`
			.. `Coste de Mana requerido: {h.mana}\n`
			.. `Energia necesaria: {h.sta}\n`
			.. "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
		"infoHechizo"
	)
end

return Hechizos
