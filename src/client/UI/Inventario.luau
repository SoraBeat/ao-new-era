--!strict
--[[
	Inventario — el inventario gráfico del cliente original (clsGrapchicalInventory.cls, docs/17 §6).

	- Slots de 32 px (o del tamaño que pida el HUD) en 5 columnas. Fondo por slot: 1–25 Grh 26095 (negro),
	  26–30 6834 (violeta), 31–35 6840 (dorado); el seleccionado 26096 (rojo) debajo del ítem.
	- Cantidad arriba a la izquierda y "E" en (20, 20) si está equipado.
	- Click en un slot con ítem lo selecciona; en uno vacío, deselecciona (ClickItem devuelve 0). Al entrar no
	  hay nada seleccionado. Si el seleccionado se vacía, la selección queda (sin el fondo rojo).
	- Doble click (125 ms): equipo → EquiparItem (Fase 11, docs/20 §6.2); el resto → UseItem.
	- "X" roja (200, 30, 30) en el lugar de la "E" sobre lo que la clase, la raza o el género no pueden usar
	  (clsGrapchicalInventory.cls:486-491, ItemIncompatibleConUser; docs/20 §6.6).
	- U (450 ms) y el botón Usar del celular (125 ms, DF9-06 C) usan Inventario.usar(via).
	- Arrastrar con el botón derecho (o mantener apretado en el celular) intercambia dos slots (docs/28 §10).
	- Tooltip (PC): "<Nombre>", "<Nombre>, Ataque: max/min" o "<Nombre>, Defensa: max/min" (:544-586).
	- Fase 31 (pedido del autor): en el celular, el botón "Mover" del pie arma un modo en el que el toque siguiente
	  sobre un casillero (vacío u ocupado) es el destino de lo seleccionado: manda el mismo MoverItem que el arrastre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Inventario)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario)
local Timers = require(ReplicatedStorage.Shared.Combate.Timers)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Equipo = require(ReplicatedStorage.Shared.Jugador.Equipo)
local Grh = require(script.Parent.Parent.Render.Grh)
local Click = require(script.Parent.Click)

local Inventario = {}

local GRH_NEGRO, GRH_ROJO, GRH_VIOLETA, GRH_DORADO = 26095, 26096, 6834, 6840
local DOBLE_CLICK_S = 0.5 -- tiempo de doble click de Windows por defecto

export type Datos = { obj: number, cant: number, equipado: boolean }

local slots: { [number]: Datos } = {}
local seleccionado = 0
local timers = Timers.nuevoClienteUso()
local evUsar: RemoteEvent? = nil

type Celda = { boton: ImageButton, fondo: ImageLabel, item: ImageLabel, cant: TextLabel, e: TextLabel, x: TextLabel }
local celdas: { [number]: Celda } = {}
local alCambiarSeleccion: { (number, Datos?) -> () } = {}
local alCambiarInventario: { () -> () } = {}
local equiparCb: (() -> ())? = nil
local tooltip: TextLabel? = nil
local clase, raza, genero = "", "Humano", "Hombre"
-- Fase 39 (docs/59 §4): los skills propios, para la "X" de lo que todavía no se puede equipar (nil: no se mira)
local misSkills: { [string]: number }? = nil
-- Fase 16b (docs/32 §6.2): los slots usables (25, o 30 / 35 con la Mochila / la Alforja); llegan en las Estadisticas
local usables = Config.SlotsUsables
local ocultarSinUsar = false -- el celular no muestra los slots que no se usan
-- Fase 18 (docs/37 §7.2): las columnas de la grilla armada y el cursor del mando (un borde sobre un casillero, que
-- puede estar vacío)
local columnasGrilla = 5
local cursorMando = 0
local marcoMando: Frame? = nil

-- La clase, raza y género propios, para la "X" (Fase 12: con la raza y el género del personaje)
function Inventario.setClase(c: string, r: string?, g: string?)
	clase, raza, genero = c, r or "Humano", g or "Hombre"
end

-- ItemIncompatibleConUser (InvUsuario.bas:124-160): clase, y para la ropa también género (SexoPuedeUsarItem) y raza
-- (CheckRazaUsaRopa)
function Inventario.incompatible(obj: number): boolean
	local o = Objetos[obj]
	if not o then
		return false
	end
	if o.clasesProhibidas and o.clasesProhibidas[clase] then
		return true
	end
	-- Fase 39 (docs/59 §4): no llega al skill que pide para equiparse
	if misSkills and Equipo.leFalta(o, misSkills) ~= nil then
		return true
	end
	if o.tipo ~= "armadura" then
		return false
	end
	if (o.mujer and genero == "Hombre") or (o.hombre and genero == "Mujer") then
		return true
	end
	local alta = raza == "Humano" or raza == "Elfo" or raza == "Drow"
	local puede = if alta then not o.razaEnana else o.razaEnana == true
	if raza ~= "Drow" and o.razaDrow then
		puede = false
	end
	return not puede
end

-- El nombre con todo: además, el skill que pide para equiparse (el cartelito de la PC, donde hay lugar)
function Inventario.nombreLargo(d: Datos?): string
	local base = Inventario.nombre(d)
	local pide = if d then Equipo.frasePide(Objetos[d.obj]) else ""
	return if pide ~= "" then `{base} ({string.lower(string.sub(pide, 1, 1))}{string.sub(pide, 2)})` else base
end

function Inventario.nombre(d: Datos?): string
	if not d then
		return ""
	end
	local o = Objetos[d.obj]
	if not o then
		return ""
	end
	if o.tipo == "arma" then
		return `{o.nombre}, Ataque: {o.maxHit}/{o.minHit}`
	elseif o.tipo == "armadura" or o.tipo == "escudo" or o.tipo == "casco" then
		return `{o.nombre}, Defensa: {o.maxDef}/{o.minDef}`
	elseif o.infinita then
		return `{o.nombre} (no se gasta)` -- Fase 30 (docs/50 §1): la Flecha de Rama
	end
	return o.nombre
end

local function fondoDe(slot: number): number
	if slot > 30 then
		return GRH_DORADO
	elseif slot > 25 then
		return GRH_VIOLETA
	end
	return GRH_NEGRO
end

local function pintar(slot: number)
	local c = celdas[slot]
	if not c then
		return
	end
	local d = slots[slot]
	local o = d and Objetos[d.obj]
	Grh.aplicar(c.fondo, if o and slot == seleccionado then GRH_ROJO else fondoDe(slot))
	c.fondo.Size = UDim2.fromScale(1, 1)
	c.item.Visible = o ~= nil
	if o then
		Grh.aplicar(c.item, o.grh)
		c.item.Size = UDim2.fromScale(1, 1)
	end
	c.cant.Text = if not o then "" elseif o.infinita then "∞" else tostring(d.cant)
	c.e.Visible = o ~= nil and d.equipado
	c.x.Visible = o ~= nil and not d.equipado and Inventario.incompatible(d.obj)
end

-- Fase 39 (docs/59 §4): los skills del personaje (por clave), cada vez que cambian. Con ellos la "X" marca también
-- lo que todavía no se puede equipar. sinRequisito: al personaje de prueba no se le pide nada.
function Inventario.setSkills(valores: any, sinRequisito: boolean?)
	misSkills = if sinRequisito or typeof(valores) ~= "table" then nil else valores
	for slot in celdas do
		pintar(slot)
	end
end

-- ─── Mover con toques (Fase 31, pedido del autor) ──────────────────────────────
-- En el celular el arrastre (mantener apretado) casi no se descubre y pelea con el desplazamiento de la grilla. El
-- botón "Mover" del pie (HudTactil) arma este modo con el objeto seleccionado, y el toque siguiente sobre un casillero
-- cualquiera, vacío u ocupado, lo manda ahí. Mientras está armado, ese toque no selecciona, no cuenta para el doble
-- toque y no empieza un arrastre.
local moviendo = 0 -- el slot de origen (0 = el modo está apagado)
local alCambiarMover: { (boolean) -> () } = {}

local function setMoviendo(slot: number)
	if slot == moviendo then
		return
	end
	moviendo = slot
	for _, f in alCambiarMover do
		f(slot > 0)
	end
end

function Inventario.moviendo(): boolean
	return moviendo > 0
end

-- Arma el modo con el objeto seleccionado. Devuelve false, sin armarlo, si no hay ninguno elegido
function Inventario.empezarMover(): boolean
	if seleccionado < 1 or seleccionado > usables or not slots[seleccionado] then
		return false
	end
	setMoviendo(seleccionado)
	return true
end

function Inventario.cancelarMover()
	setMoviendo(0)
end

-- f(armado): el modo se armó o se apagó (porque se movió, se canceló o lo que se iba a mover ya no está)
function Inventario.alCambiarMover(f: (boolean) -> ())
	table.insert(alCambiarMover, f)
end

-- Pide el intercambio de dos slots (MoverItem) y deja la selección en el de destino (InvSelectedItem = TempSlot). Lo
-- usan el arrastre y el modo "Mover", que con esto se apaga
local function pedirMover(desde: number, hasta: number)
	setMoviendo(0)
	Remotes.evento("MoverItem"):FireServer(desde, hasta)
	local anterior = seleccionado
	seleccionado = hasta
	pintar(anterior)
	pintar(hasta)
end

-- El toque sobre un casillero con el modo armado: es el destino. El mismo casillero de origen solo lo apaga.
local function terminarMover(hasta: number)
	local desde = moviendo
	setMoviendo(0)
	if desde > 0 and hasta ~= desde and desde <= usables and hasta <= usables and slots[desde] then
		pedirMover(desde, hasta)
	end
end

local function seleccionar(slot: number)
	setMoviendo(0) -- (el cursor del mando cambió la selección: lo que se iba a mover ya no es lo elegido)
	local anterior = seleccionado
	seleccionado = if slots[slot] then slot else 0
	pintar(anterior)
	pintar(seleccionado)
	for _, f in alCambiarSeleccion do
		f(seleccionado, slots[seleccionado])
	end
end

function Inventario.seleccionado(): (number, Datos?)
	return seleccionado, slots[seleccionado]
end

-- El cursor del mando (docs/37 §7.2): marca el casillero y, si tiene algo, lo selecciona. nil o 0 lo saca
function Inventario.setCursorMando(slot: number?)
	cursorMando = slot or 0
	local c = celdas[cursorMando]
	if not c then
		if marcoMando then
			marcoMando.Visible = false
		end
		return
	end
	local m = marcoMando
	if not m or not m.Parent then
		m = Instance.new("Frame")
		m.Name = "CursorMando"
		m.BackgroundTransparency = 1
		m.Size = UDim2.fromScale(1, 1)
		m.ZIndex = 5
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(255, 220, 80)
		borde.Thickness = 2
		borde.Parent = m
		marcoMando = m
	end
	local marco = m :: Frame
	marco.Parent = c.boton
	marco.Visible = true
	seleccionar(cursorMando)
end

function Inventario.cursorMando(): number
	return cursorMando
end

function Inventario.columnas(): number
	return columnasGrilla
end

-- Lo pone el Controlador: usar un objeto apaga el macro de trabajo (Fase 16a)
Inventario.alUsar = nil :: (() -> ())?
-- Lo pone Main (Fase 25, docs/44 §12): el jugador pidió usar o equipar lo de ese slot (el tutorial lo espera)
Inventario.alPedirUso = nil :: ((number) -> ())?
local function avisarUso(slot: number)
	local f = Inventario.alPedirUso
	if f then
		f(slot)
	end
end
function Inventario.avisarUso(slot: number)
	avisarUso(slot)
end

local function mandar()
	if seleccionado >= 1 and seleccionado <= Config.Slots then -- UsarItem (frmMain.frm:2406-2416)
		if Inventario.alUsar then
			Inventario.alUsar()
		end
		(evUsar :: RemoteEvent):FireServer(seleccionado)
		avisarUso(seleccionado)
	end
end

-- via: "U" (450 ms) o "doble" (125 ms: el botón Usar del celular, DF9-06 C)
function Inventario.usar(via: string)
	local intervalo = if via == "U" then Config.ClienteU else Config.ClienteDobleClick
	if Timers.clienteUsar(timers, via, intervalo, os.clock() * 1000) then
		mandar()
	end
end

-- picInv_DblClick (frmMain.frm:2744-2777): slot vacío → nada; el timer se consume antes de mirar el tipo
local function dobleClick()
	local d = slots[seleccionado]
	if seleccionado == 0 or not d then
		return
	end
	if not Timers.clienteUsar(timers, "doble", Config.ClienteDobleClick, os.clock() * 1000) then
		return
	end
	local o = Objetos[d.obj] :: any
	-- Arco o Cuchillas equipados: se usan (arma el cursor); el resto del equipo se equipa (frmMain.frm:2750-2762).
	-- Fase 14a: también flechas y anillos (otFlechas, otAnillo).
	-- Fase 16a: también las herramientas (arman el cursor de trabajo). Desde el 2026-10-04, estén o no equipadas: el
	-- servidor equipa la que no lo está y arma el cursor en el mismo gesto (docs/31 §2.2, "Cambió")
	if o and o.tipo == "arma" and (o.herramienta or (o.proyectil and d.equipado)) then
		mandar()
		return
	end
	if o and (o.tipo == "arma" or o.tipo == "armadura" or o.tipo == "casco" or o.tipo == "escudo" or o.tipo == "municion" or o.tipo == "anillo") then
		if equiparCb then
			equiparCb() -- EquiparItem
		end
		return
	end
	mandar()
end

-- Fase 14a (docs/27 §2.2): el slot del arco o las Cuchillas equipados (0 si no hay), para el botón Disparar
function Inventario.slotProyectil(): number
	for i, d in slots do
		local o = Objetos[d.obj] :: any
		if d.equipado and o and o.tipo == "arma" and o.proyectil then
			return i
		end
	end
	return 0
end

-- Usa el arco equipado (el botón Disparar del celular): el servidor contesta con el cursor armado
function Inventario.usarSlot(slot: number)
	if slot >= 1 and slot <= Config.Slots and Timers.clienteUsar(timers, "doble", Config.ClienteDobleClick, os.clock() * 1000) then
		(evUsar :: RemoteEvent):FireServer(slot)
		avisarUso(slot)
	end
end

-- Lo pone el Controlador: equipar el seleccionado (con el chequeo de muerto del cliente)
function Inventario.alEquipar(f: () -> ())
	equiparCb = f
end

-- Fase 22 (docs/41 §1): los atajos. Hace sobre un slot cualquiera lo mismo que su doble click, sin cambiar la
-- selección y con el mismo reloj de 125 ms: usa lo que se usa, equipa lo que se equipa. `accion` ("usar" o
-- "equipar") la decide shared/Config/Atajos. Devuelve si mandó algo.
local equiparSlotCb: ((number) -> ())? = nil
function Inventario.alEquiparSlot(f: (number) -> ())
	equiparSlotCb = f
end

function Inventario.accionSlot(slot: number, accion: string): boolean
	if slot < 1 or slot > Config.Slots or not slots[slot] then
		return false
	end
	if not Timers.clienteUsar(timers, "doble", Config.ClienteDobleClick, os.clock() * 1000) then
		return false
	end
	if accion == "equipar" then
		if equiparSlotCb then
			equiparSlotCb(slot)
		end
		return true
	end
	if Inventario.alUsar then
		Inventario.alUsar() -- usar un objeto apaga el macro de trabajo, igual que con la U
	end
	(evUsar :: RemoteEvent):FireServer(slot)
	avisarUso(slot)
	return true
end

-- ─── Arrastrar (clsGrapchicalInventory.cls:587-686, docs/28 §10) ────────────────
-- Con el botón derecho se "levanta" el ítem de un slot con algo (del inventario usable, 1-25) y se suelta sobre otro:
-- el servidor intercambia los dos (MoverItem) y la selección pasa al slot de destino. En el celular, mantener
-- apretado un momento y arrastrar.
local MANTENER_S = 0.35
local arrastre: { desde: number, gui: ScreenGui, img: ImageLabel, input: InputObject? }? = nil

local function slotEn(pos: Vector3 | Vector2): number?
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	for _, g in pg:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		for slot, c in celdas do
			if g == c.boton or g:IsDescendantOf(c.boton) then
				return slot
			end
		end
	end
	return nil
end

local function moverImagen(pos: Vector3 | Vector2)
	local a = arrastre
	if a then
		a.img.Position = UDim2.fromOffset(pos.X, pos.Y)
	end
end

local function empezarArrastre(slot: number, pos: Vector3 | Vector2, input: InputObject?)
	local d = slots[slot]
	local o = d and Objetos[d.obj]
	-- (con el modo "Mover" armado no se arrastra: el toque, aunque sea largo, elige el destino; Fase 31)
	if arrastre or moviendo > 0 or not o or slot > usables then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "ArrastreInventario"
	g.IgnoreGuiInset = false -- las posiciones de InputObject no cuentan la barra de arriba
	g.DisplayOrder = 100
	g.ResetOnSpawn = false
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	Grh.aplicar(img, (o :: any).grh)
	local tam = celdas[slot].boton.AbsoluteSize
	img.Size = UDim2.fromOffset(tam.X, tam.Y)
	img.Active = false
	img.Parent = g
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	arrastre = { desde = slot, gui = g, img = img, input = input }
	moverImagen(pos)
end

local function soltar(pos: Vector3 | Vector2?)
	local a = arrastre
	if not a then
		return
	end
	arrastre = nil
	a.gui:Destroy()
	local hasta = if pos then slotEn(pos) else nil
	if hasta and hasta ~= a.desde and hasta <= usables then
		pedirMover(a.desde, hasta)
	end
end

UserInputService.InputChanged:Connect(function(input)
	local a = arrastre
	if not a then
		return
	end
	if (a.input == nil and input.UserInputType == Enum.UserInputType.MouseMovement) or input == a.input then
		moverImagen(input.Position)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local a = arrastre
	if not a then
		return
	end
	if (a.input == nil and input.UserInputType == Enum.UserInputType.MouseButton2) or input == a.input then
		soltar(input.Position)
	end
end)

local function conectarArrastre(b: ImageButton, slot: number)
	b.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			empezarArrastre(slot, input.Position, nil)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local inicio = input.Position
			task.delay(MANTENER_S, function()
				if input.UserInputState ~= Enum.UserInputState.End and (input.Position - inicio).Magnitude < 12 then
					empezarArrastre(slot, input.Position, input)
				end
			end)
		end
	end)
end

function Inventario.usables(): number
	return usables
end

local function mostrarCeldas()
	for slot, c in celdas do
		c.boton.Visible = not ocultarSinUsar or slot <= usables
	end
end

-- Las Estadisticas traen los slots usables (Fase 16b): cambian al equipar o sacar la mochila
function Inventario.setUsables(n: number?)
	local nuevo = n or Config.SlotsUsables
	if nuevo == usables then
		return
	end
	usables = nuevo
	if moviendo > usables then
		setMoviendo(0) -- sin la mochila, lo que se iba a mover quedó en un slot que ya no se usa
	end
	mostrarCeldas()
	for _, f in alCambiarInventario do
		f()
	end
end

export type Opciones = {
	celda: number?, -- px del slot (32 en PC)
	columnas: number?,
	cantidad: number?, -- slots que se muestran (35)
	ocultarSinUsar: boolean?, -- el celular esconde los que no se pueden usar (sin mochila, del 26 en adelante)
	tamTexto: number?,
	tooltip: boolean?,
}

-- Arma la grilla dentro de `parent` (arriba a la izquierda)
function Inventario.montar(parent: GuiObject, opciones: Opciones?)
	local o = opciones or {}
	local celda = o.celda or 32
	local columnas = o.columnas or 5
	local cantidad = o.cantidad or Config.Slots
	local tam = o.tamTexto or 11
	columnasGrilla = columnas
	ocultarSinUsar = o.ocultarSinUsar == true
	setMoviendo(0)
	for _, c in celdas do
		c.boton:Destroy()
	end
	celdas = {}
	for slot = 1, cantidad do
		local b = Instance.new("ImageButton")
		b.Name = `Slot{slot}`
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(celda, celda)
		b.Position = UDim2.fromOffset(((slot - 1) % columnas) * celda, ((slot - 1) // columnas) * celda)
		b.Parent = parent
		local fondo = Instance.new("ImageLabel")
		fondo.BackgroundTransparency = 1
		fondo.ResampleMode = Enum.ResamplerMode.Pixelated
		fondo.Parent = b
		local item = Instance.new("ImageLabel")
		item.BackgroundTransparency = 1
		item.ResampleMode = Enum.ResamplerMode.Pixelated
		item.ZIndex = 2
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
		cant.ZIndex = 3
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
		e.ZIndex = 3
		e.Parent = b
		local x = e:Clone()
		x.Name = "X"
		x.Text = "X"
		x.TextColor3 = Color3.fromRGB(200, 30, 30)
		x.Parent = b
		celdas[slot] = { boton = b, fondo = fondo, item = item, cant = cant, e = e, x = x }
		conectarArrastre(b, slot)

		local ultimo = 0
		Click.activado(b, function()
			-- Fase 31: con el modo "Mover" armado, el toque elige el destino: ni selecciona ni cuenta para el doble toque
			if moviendo > 0 then
				ultimo = 0
				terminarMover(slot)
				return
			end
			local ahora = os.clock()
			local doble = ahora - ultimo < DOBLE_CLICK_S and seleccionado == slot
			ultimo = ahora
			seleccionar(slot)
			if doble then
				ultimo = 0
				dobleClick()
			end
		end)
		-- El mando (Fase 34, docs/54 §4): LT + A es el botón derecho. Con el mouse ese botón levanta el objeto para
		-- arrastrarlo; el puntero del mando no arrastra, así que arma "Mover": el click siguiente elige el destino
		Click.derechoMando(b, function()
			if moviendo > 0 then
				terminarMover(slot)
			elseif slots[slot] and slot <= usables then
				seleccionar(slot)
				Inventario.empezarMover()
			end
		end)
		if o.tooltip then
			Click.entra(b, function()
				local t = tooltip
				if t and slots[slot] then
					t.Text = " " .. Inventario.nombreLargo(slots[slot]) .. " "
					t.Position = UDim2.fromOffset(b.Position.X.Offset + celda // 2, b.Position.Y.Offset + celda + 2)
					t.Visible = true
				end
			end)
			Click.sale(b, function()
				if tooltip then
					tooltip.Visible = false
				end
			end)
		end
		pintar(slot)
	end
	mostrarCeldas()
	if o.tooltip then
		local t = Instance.new("TextLabel")
		t.Name = "Tooltip"
		t.AutomaticSize = Enum.AutomaticSize.XY
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.BackgroundColor3 = Color3.fromRGB(255, 255, 225) -- tooltip de Windows
		t.BorderColor3 = Color3.new(0, 0, 0)
		t.Font = Enum.Font.Arial
		t.TextSize = 12
		t.TextColor3 = Color3.new(0, 0, 0)
		t.ZIndex = 10
		t.Visible = false
		t.Parent = parent
		tooltip = t
	end
end

function Inventario.alCambiarSeleccion(f: (number, Datos?) -> ())
	table.insert(alCambiarSeleccion, f)
end

function Inventario.alCambiarInventario(f: () -> ())
	table.insert(alCambiarInventario, f)
end

-- Los slots actuales (para calcular ataque y defensa de lo equipado en el HUD)
function Inventario.slots(): { [number]: Datos }
	return slots
end

local function avisar()
	for _, f in alCambiarInventario do
		f()
	end
	for _, f in alCambiarSeleccion do
		f(seleccionado, slots[seleccionado])
	end
end

function Inventario.iniciar()
	evUsar = Remotes.evento("Usar")
	Remotes.evento("Inventario").OnClientEvent:Connect(function(t: any)
		slots = {}
		for k, d in t do
			local slot = tonumber(k)
			if slot then
				slots[slot] = d
			end
		end
		for slot in celdas do
			pintar(slot)
		end
		setMoviendo(0) -- el inventario entero es otro (entró con un personaje): el modo "Mover" no sigue
		avisar()
	end)
	Remotes.evento("InventarioSlot").OnClientEvent:Connect(function(slot: number, d: any)
		local antes = slots[slot]
		slots[slot] = d
		pintar(slot)
		-- Fase 31: si lo que se iba a mover ya no está ahí (se usó, se tiró, se vendió), el modo "Mover" se apaga
		if slot == moviendo and (not d or not antes or d.obj ~= antes.obj) then
			setMoviendo(0)
		end
		avisar()
	end)
end

return Inventario
