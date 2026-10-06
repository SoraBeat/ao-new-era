--!strict
--[[
	HudTactil — la interfaz de celular y tableta (DF9-02 B, diseño nuevo; docs/17 §3).

	La vista ocupa toda la pantalla (13 tiles de alto en teléfonos, 19 en tabletas: DF9-03 B) y la interfaz
	flota encima, dentro del área segura (debajo de la barra de Roblox y fuera de los notch):
	  - arriba a la izquierda: vida, maná, energía, oro y % de experiencia;
	  - arriba al centro: la consola (4 líneas, o 12, 1 o 0 con el botón ▼);
	  - abajo a la izquierda: el D-pad (mantener = caminar);
	  - abajo a la derecha: Golpe, Usar, Agarrar y Más; Lanzar y Meditar en las clases con magia; Navegar con un
	    barco encima; y el Seguro. Con la espera de Golpe y Lanzar (DF9-08 B).
	Piezas del original (DF9-10 A): marco de uAOButton, fondos de slot y colores de las barras de la skin.

	Fase 22 (docs/41 §2): de 26 botones a 14 (16 con magia).
	  - La fila de arriba ([Chat] [▼] [Menú] y las pestañas [Inventario] [Hechizos]) va en otra ScreenGui, que usa el
	    lugar libre de la barra de Roblox, al lado de sus botones (TopbarSafeInsets): antes quedaba 58 px más abajo.
	  - Menú abre una lista con Grupo, Clanes, Retos, Quests, Estadísticas, Mapa, Opciones y Diagnóstico.
	  - Más abre Ocultarse, Robar y Domar. Tirar y Equipar están dentro del panel del inventario.
	  - El panel del inventario y de los hechizos va por encima de los botones de acción (antes quedaba detrás) y se
	    cierra tocando afuera; la lista de hechizos se cierra sola al elegir uno, para que Lanzar quede a la vista.

	Fase 33 (docs/53 §5, pedido del autor): un minimapa chico a la izquierda, debajo de las barras. En una tableta
	entra entre las barras y las flechas (hasta 100 px, como el de la PC); en un teléfono no hay lugar ahí y va en el
	hueco de arriba a la izquierda de la cruz de flechas (58 px). Muestra el mapa, el punto propio, el recuadro de lo
	que se ve y los puntos del grupo y del clan; tocarlo abre el mapa del mundo. El minimapa, las flechas y los
	botones de acción van cada uno en un CanvasGroup: así se les cambia la transparencia entera desde Opciones
	(HudTactil.setTransparencia; se guarda con las opciones del jugador).

	Fase 31 (pedido del autor): ordenar el inventario. El pie tiene un tercer botón, "Mover": con un objeto elegido,
	queda resaltado, el pie dice "Tocá el lugar adonde va" y el toque siguiente sobre un casillero (vacío u ocupado) lo
	manda ahí (Inventario.empezarMover). Tocar "Mover" otra vez, cambiar de pestaña o cerrar el panel lo cancela.

	Fase 38 (docs/58, pedido del autor): el jugador acomoda la interfaz a su gusto. Las barras, la consola, el
	minimapa, las flechas y cada botón de acción son "piezas" sueltas: cada una se mueve, cambia de tamaño y se
	esconde por separado, y se pueden sumar las opcionales (Ocultarse, Robar y Domar sueltos, y atajos a un hechizo o
	a un objeto). Dónde va cada una lo dice shared/Config/Disposicion: de fábrica, donde iba siempre. Se acomoda desde
	Opciones ⟩ "Acomodar la interfaz" (client/UI/HudEditor) y se guarda con la cuenta, una disposición para el teléfono
	y otra para la tableta. La fila de arriba (Chat, Menú, Inventario, Hechizos) y el panel no se mueven: desde el Menú
	siempre se llega a Opciones, y de ahí a "Restablecer". Las barras se mueven pero no se esconden.
	Cada botón va en su propio CanvasGroup (antes iban todos en uno), para que la transparencia siga andando.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local Objetos = require(ReplicatedStorage.Shared.Generado.ObjetosInventario)
local UiAssets = require(ReplicatedStorage.Shared.Generado.UiAssets)
local ChatCfg = require(ReplicatedStorage.Shared.Config.Chat)
local ConfigTactil = require(ReplicatedStorage.Shared.Config.Tactil)
local Disp = require(ReplicatedStorage.Shared.Config.Disposicion)
local ReglasAliados = require(ReplicatedStorage.Shared.Mundo.Aliados)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Hud = require(script.Parent.HudComun)
local Boton = require(script.Parent.Boton)
local MapaMundo = require(script.Parent.MapaMundo)
local Consola = require(script.Parent.Consola)
local Inventario = require(script.Parent.Inventario)
local Hechizos = require(script.Parent.Hechizos)
local Diagnostico = require(script.Parent.Diagnostico)
local Estadisticas = require(script.Parent.Estadisticas)
local Tienda = require(script.Parent.Tienda)
local Mascotas = require(script.Parent.Mascotas)
local Chat = require(script.Parent.Chat)
local Atajos = require(script.Parent.Atajos)
local Aliados = require(script.Parent.Aliados)
local Grh = require(script.Parent.Parent.Render.Grh)
local Camara = require(script.Parent.Parent.Render.Camara)
local Mundo = require(script.Parent.Parent.Render.Mundo)
local Click = require(script.Parent.Click)

local HudTactil = {}

local LINEA = 15 -- alto de una línea de la consola
local consolaIdx = 1 -- Chat.TamanosConsola: arranca en 4 líneas

-- Colores de las barras, sampleados de la skin (docs/17 §2.3)
local COLOR = {
	Vida = Color3.fromRGB(210, 2, 2),
	Mana = Color3.fromRGB(2, 85, 215),
	Energia = Color3.fromRGB(199, 83, 0),
	-- Fase 16a (DR16-03 A): hambre y sed, dos barras finas al costado
	Hambre = Color3.fromRGB(40, 170, 40),
	Sed = Color3.fromRGB(0, 160, 220),
}
local ANCHO_BARRA = 146 -- deja lugar a las dos finas (Fase 16a)
local AMARILLO_CLARO = Color3.fromRGB(255, 255, 225)
local CELDA = 40 -- px de un slot del inventario en celular
-- El pie del inventario (Fase 31): [Mover] nombre [Equipar] [Tirar], en los 200 px del panel
local ANCHO_BOTON_PIE = 44
local X_NOMBRE_PIE = ANCHO_BOTON_PIE + 3 -- el nombre empieza después de "Mover"
local MSG_MOVER_DESTINO = "Tocá el lugar adonde va"
local MSG_MOVER_ELEGIR = "Elegí un objeto"
local COLOR_MOVER = Color3.fromRGB(255, 220, 80)
local ALTO_TELEFONO, ALTO_TABLETA = 13, 19
local TAM_DPAD = 58 -- lado de cada flecha
local X_DPAD, BORDE_DPAD = 16, 12 -- la cruz: a 16 px del costado y 12 del borde de abajo
-- Fase 33 (docs/53 §5): opacidad del minimapa y de los botones, en % (de Opciones; puede llegar antes que el HUD)
local opMini, opBotones = ConfigTactil.OpMini, ConfigTactil.OpBotones
local contexto: Hud.Contexto? = nil
-- Fase 38 (docs/58): las piezas que el jugador puede acomodar y lo que eligió (puede llegar antes que el HUD)
type Pieza = { marco: GuiObject, escala: UIScale? }
local piezas: { [string]: Pieza } = {}
local guardado: Disp.Guardado? = nil -- lo guardado con la cuenta: la del teléfono y la de la tableta
local disposicion: Disp.Datos? = nil -- la que vale ahora, para esta pantalla (la calcula acomodarPiezas)
local previa: Disp.Datos? = nil -- lo que se está armando en la pantalla de acomodar...
local enPrevia = false -- ...mientras está abierta y ya se tocó algo
local editando = false -- con la pantalla de acomodar abierta se ven todos los botones, también los que aparecen solos
local dinamicos: { [string]: boolean } = {} -- Lanzar, Meditar, Navegar y Seguir: si ahora les toca verse
local botonesDinamicos: { [string]: GuiObject } = {}
local ctl: any = nil -- el Controlador (lo recibe iniciar)
local coordX, coordY, coordMapa = -1, -1, -1 -- lo último que mostraron las coordenadas

type Tactil = {
	gui: ScreenGui,
	barras: { [string]: { relleno: Frame, texto: TextLabel, marco: Frame } },
	oro: TextLabel,
	porc: TextLabel,
	paralisis: TextLabel,
	invisibilidad: TextLabel,
	dopas: TextLabel,
	consola: Frame,
	arriba: ScreenGui,
	menu: Frame,
	mas: Frame,
	meditar: ImageButton,
	navegar: ImageButton,
	tamConsola: ImageButton,
	panel: Frame,
	tenue: boolean, -- la lista de hechizos, traslúcida (el mando, al cambiar de hechizo: Fase 35)
	botonesLista: { ImageButton }, -- Info y las flechas de la lista de hechizos
	pieInv: Frame,
	picInv: GuiObject,
	hlst: Frame,
	nombreItem: TextLabel,
	-- Fase 31: los botones del pie del inventario y el borde de "Mover" mientras el modo está armado
	equiparPie: ImageButton,
	tirarPie: ImageButton,
	resalteMover: UIStroke,
	pestana: string?,
	usar: ImageButton,
	usarIcono: ImageLabel,
	usarCant: TextLabel,
	lanzar: ImageButton?,
	seguro: ImageButton,
	esperaGolpe: Frame,
	esperaLanzar: Frame?,
	-- Fase 33: el minimapa y los grupos a los que se les cambia la transparencia
	mini: CanvasGroup,
	miniImagen: ImageLabel,
	miniEscala: UIScale,
	miniPunto: Frame,
	miniArea: Frame,
	miniLado: number,
	dpad: CanvasGroup,
	coord: TextLabel,
	izq: Frame,
	cajaChat: GuiObject?,
	botonMas: GuiObject,
	anchoConsola: number,
}
local t: Tactil

local function texto(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.ArialBold
	l.TextSize = 14
	l.TextColor3 = AMARILLO_CLARO
	l.TextStrokeTransparency = 0.4
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function fondo(parent: Instance, pos: UDim2, tam: UDim2, transparencia: number?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = tam
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = transparencia or 0.35
	f.BorderSizePixel = 0
	f.Parent = parent
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 100, 70)
	borde.Parent = f
	return f
end

-- ─── Cámara (DF9-03 B) ───────────────────────────────────────────────────────
local function acomodar()
	local camara = workspace.CurrentCamera
	if not camara then
		return
	end
	local vp = camara.ViewportSize
	local alto = if math.min(vp.X, vp.Y) >= 600 then ALTO_TABLETA else ALTO_TELEFONO
	Camara.configurar(alto, 0, 0)
	Mundo.setVista(math.ceil(alto * vp.X / math.max(1, vp.Y)), alto, 3, 2) -- margen: 3 tiles a los costados, 2 arriba y abajo
end

-- ─── Barras ──────────────────────────────────────────────────────────────────
local function barra(parent: Instance, nombre: string, y: number)
	local m = Instance.new("Frame")
	m.Name = nombre
	m.Position = UDim2.fromOffset(0, y)
	m.Size = UDim2.fromOffset(ANCHO_BARRA, 18)
	m.BackgroundColor3 = Color3.new(0, 0, 0)
	m.BorderSizePixel = 0
	m.Parent = parent
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 100, 70)
	borde.Parent = m
	local r = Instance.new("Frame")
	r.BackgroundColor3 = COLOR[nombre]
	r.BorderSizePixel = 0
	r.Size = UDim2.fromScale(1, 1)
	r.Parent = m
	local tx = texto(m, { Size = UDim2.fromScale(1, 1), TextSize = 13, ZIndex = 2 })
	t.barras[nombre] = { relleno = r, texto = tx, marco = m }
end

-- Hambre y sed (Fase 16a, DR16-03 A): finas y verticales, se llenan desde abajo; en 0 el borde titila (DR16-02 A)
local finas: { [string]: { relleno: Frame, borde: UIStroke, vacia: boolean } } = {}
local function barraFina(parent: Instance, nombre: string, x: number)
	local m = Instance.new("Frame")
	m.Name = nombre
	m.Position = UDim2.fromOffset(x, 0)
	m.Size = UDim2.fromOffset(5, 62)
	m.BackgroundColor3 = Color3.new(0, 0, 0)
	m.BorderSizePixel = 0
	m.Parent = parent
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 100, 70)
	borde.Parent = m
	local r = Instance.new("Frame")
	r.Name = "Relleno"
	r.BackgroundColor3 = COLOR[nombre]
	r.BorderSizePixel = 0
	r.AnchorPoint = Vector2.new(0, 1)
	r.Position = UDim2.fromScale(0, 1)
	r.Size = UDim2.fromScale(1, 1)
	r.Parent = m
	finas[nombre] = { relleno = r, borde = borde, vacia = false }
end
task.spawn(function()
	local on = false
	while true do
		task.wait(0.5)
		on = not on
		for _, f in finas do
			f.borde.Color = if f.vacia and on then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(120, 100, 70)
		end
	end
end)
local function setFina(nombre: string, v: number)
	local f = finas[nombre]
	if f then
		f.relleno.Size = UDim2.fromScale(1, math.clamp(v / 100, 0, 1))
		f.vacia = v <= 0
	end
end

local function setBarra(nombre: string, minv: number, maxv: number, ancho: number)
	local b = t.barras[nombre]
	-- Mismo redondeo que el original (bWidth sobre 90 u 83 px), estirado al ancho de la barra
	b.relleno.Size = UDim2.fromScale(Hud.bWidth(minv, maxv, ancho) / ancho, 1)
	b.texto.Text = `{minv}/{maxv}`
end

-- ─── Pie del inventario (Fase 31) ────────────────────────────────────────────
-- Dice el nombre del objeto elegido. Con el modo "Mover" armado dice dónde tocar, a todo lo ancho: Equipar y Tirar se
-- esconden hasta que termine (así tampoco se tocan sin querer) y "Mover", resaltado, queda para cancelar.
local avisoPie: string? = nil -- "Elegí un objeto": tocaron "Mover" sin nada elegido
local turnoAviso = 0

local function pintarPie()
	if not t or not t.resalteMover then
		return -- todavía no está armado
	end
	local moviendo = Inventario.moviendo()
	local slot, d = Inventario.seleccionado()
	local aviso = if moviendo then MSG_MOVER_DESTINO elseif slot > 0 and d then nil else avisoPie
	t.resalteMover.Enabled = moviendo
	t.equiparPie.Visible = not moviendo
	t.tirarPie.Visible = not moviendo
	t.nombreItem.Size = UDim2.new(1, -X_NOMBRE_PIE - (if moviendo then 0 else 2 * (ANCHO_BOTON_PIE + 2)), 1, 0)
	t.nombreItem.Text = if aviso then aviso elseif slot > 0 then Inventario.nombre(d) else ""
	t.nombreItem.TextColor3 = if aviso then COLOR_MOVER else AMARILLO_CLARO
end

-- Un aviso corto en el lugar del nombre: se va solo, o al elegir un objeto
local function avisarPie(texto_: string)
	turnoAviso += 1
	local turno = turnoAviso
	avisoPie = texto_
	pintarPie()
	task.delay(2.5, function()
		if turno == turnoAviso then
			avisoPie = nil
			pintarPie()
		end
	end)
end

-- ─── Panel plegable ──────────────────────────────────────────────────────────
-- tenue (Fase 35, docs/56 §3): lo abrió el mando para elegir un hechizo; se ve traslúcido
-- La lista de hechizos traslúcida (Fase 35, docs/56 §3): el velo del panel, las filas y los botones de abajo se
-- transparentan; las letras no. (No es un CanvasGroup: con la calidad gráfica baja podría verse borroso el inventario.)
local TRANSPARENCIA_PANEL = 0.2
local function ponerTenue(si: boolean)
	if t.tenue == si then
		return
	end
	t.tenue = si
	local k = ConfigTactil.PanelTenue
	t.panel.BackgroundTransparency = if si then 1 - (1 - TRANSPARENCIA_PANEL) * (1 - k) else TRANSPARENCIA_PANEL
	Hechizos.setTenue(if si then k else nil)
	for _, b in t.botonesLista do
		b.ImageTransparency = if si then k else 0
	end
end

local function mostrarPanel(cual: string?, tenue: boolean?)
	if t.pestana == cual then
		cual = nil -- el mismo botón lo cierra
	end
	ponerTenue(cual == "hechizos" and tenue == true)
	-- Fase 31: cambiar de pestaña o cerrar el panel cancela el modo "Mover" del inventario
	Inventario.cancelarMover()
	if avisoPie then
		turnoAviso += 1
		avisoPie = nil
		pintarPie()
	end
	t.pestana = cual
	t.panel.Visible = cual ~= nil
	t.picInv.Visible = cual == "inventario"
	t.hlst.Visible = cual == "hechizos"
	t.pieInv.Visible = cual == "inventario"
	if cual then
		t.menu.Visible = false
		t.mas.Visible = false
	end
end

-- Lo que está desplegado (el panel, el Menú o Más) se cierra. Devuelve si había algo abierto.
local function cerrarDesplegados(): boolean
	local habia = t.pestana ~= nil or t.menu.Visible or t.mas.Visible
	if t.pestana ~= nil then
		mostrarPanel(nil)
	end
	t.menu.Visible = false
	t.mas.Visible = false
	return habia
end

-- Una lista desplegable de botones (Menú y Más)
local function lista(parent: Instance, nombre: string, items: { { any } }, ancho: number): Frame
	-- Fase 26: con la Guía el Menú tiene diez ítems; en una pantalla baja se achican para que entren todos (cuelga de
	-- la barra de arriba, a unos 60 px del borde)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
	local ALTO_ITEM = math.clamp(math.floor((vp.Y - 70) / math.max(1, #items)), 24, 32)
	local f = Instance.new("Frame")
	f.Name = nombre
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(ancho + 8, #items * ALTO_ITEM + 6)
	f.Visible = false
	f.Active = true -- que el toque no pase al mapa
	f.ZIndex = 20
	f.Parent = parent
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 100, 70)
	borde.Parent = f
	for i, item in items do
		local b = Boton.nuevo(f, item[1], UDim2.fromOffset(4, 4 + (i - 1) * ALTO_ITEM), UDim2.fromOffset(ancho, ALTO_ITEM - 3), { tamTexto = 14 })
		b.Name = "Item" .. string.gsub(item[1], "%W", "")
		b.ZIndex = 21
		for _, hijo in b:GetChildren() do
			if hijo:IsA("TextLabel") then
				hijo.ZIndex += 20
			end
		end
		Click.activado(b, function()
			f.Visible = false
			item[2]()
		end)
	end
	return f
end

local function actualizarUsar()
	local slot, d = Inventario.seleccionado()
	local o = d and Objetos[d.obj]
	t.usarIcono.Visible = o ~= nil
	if o then
		Grh.aplicar(t.usarIcono, o.grh)
		t.usarIcono.Size = UDim2.fromOffset(32, 32)
	end
	t.usarCant.Text = if o and d then tostring(d.cant) else ""
	pintarPie() -- el nombre de lo elegido (o lo que pide el modo "Mover", Fase 31)
end

-- ─── Piezas (Fase 38, docs/58) ───────────────────────────────────────────────
-- Una pieza suelta para un botón: un CanvasGroup del tamaño del botón (se le cambia la transparencia entera, Fase 33)
-- con su escala. Lo que va adentro se ubica en (0, 0).
local function marcoPieza(gui: Instance, id: string): CanvasGroup
	local p = Disp.porId[id]
	local g = Instance.new("CanvasGroup")
	g.Name = "Pieza" .. string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromOffset(p.w, p.h)
	g.GroupTransparency = 1 - opBotones / 100
	g.Parent = gui
	local e = Instance.new("UIScale")
	e.Parent = g
	piezas[id] = { marco = g, escala = e }
	return g
end

-- Algo que ya existe (las barras, la consola, las flechas) pasa a ser una pieza
local function hacerPieza(id: string, marco: GuiObject, conEscala: boolean)
	local e: UIScale? = nil
	if conEscala then
		local nueva = Instance.new("UIScale")
		nueva.Parent = marco
		e = nueva
	end
	piezas[id] = { marco = marco, escala = e }
end

-- Los botones que aparecen solos (Lanzar con un hechizo, Meditar con maná, Navegar con un barco, Seguir trabajando):
-- mientras se acomoda la interfaz se ven todos, para poder ubicarlos
local function setDinamico(id: string, si: boolean)
	dinamicos[id] = si
	local b = botonesDinamicos[id]
	if b then
		b.Visible = si or editando
	end
end

local function seTocan(ax: number, ay: number, aw: number, ah: number, bx: number, by: number, bw: number, bh: number): boolean
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- Lo que el jugador tiene elegido, para guardarlo en un atajo vacío: con el inventario abierto, el objeto; si no, el
-- hechizo elegido (el que dice el botón Lanzar) y, sin hechizo, el objeto (el del botón Usar)
local function elegidoParaAtajo(): (string?, number?)
	local slotO, d = Inventario.seleccionado()
	local slotH, idH = Hechizos.seleccionado()
	local objeto = if slotO > 0 and d then d.obj else nil
	local hechizo = if slotH > 0 and idH and idH ~= 0 then idH else nil
	if t.pestana == "inventario" and objeto then
		return "o", objeto
	elseif hechizo then
		return "h", hechizo
	elseif objeto then
		return "o", objeto
	end
	return nil, nil
end

-- ─── Botones de acción ───────────────────────────────────────────────────────
local function espera(b: GuiObject): Frame
	-- La espera que falta, como una sombra que baja (DF9-08 B)
	local s = Instance.new("Frame")
	s.Name = "Espera"
	s.AnchorPoint = Vector2.new(0, 1)
	s.Position = UDim2.fromScale(0, 1)
	s.Size = UDim2.fromScale(1, 0)
	s.BackgroundColor3 = Color3.new(0, 0, 0)
	s.BackgroundTransparency = 0.45
	s.BorderSizePixel = 0
	s.ZIndex = 5
	s.Parent = b
	return s
end

local function dpad(parent: Instance, controlador: any): CanvasGroup
	local TAM = TAM_DPAD
	-- (un CanvasGroup: se le cambia la transparencia entera; Fase 33)
	local marco = Instance.new("CanvasGroup")
	marco.Name = "DPad"
	marco.BackgroundTransparency = 1
	marco.Size = UDim2.fromOffset(TAM * 3, TAM * 3) -- (dónde va lo dice acomodarPiezas)
	marco.Parent = parent
	hacerPieza("cruz", marco, true)
	local flechas = { [Grilla.NORTE] = { 1, 0, "▲" }, [Grilla.OESTE] = { 0, 1, "◀" }, [Grilla.ESTE] = { 2, 1, "▶" }, [Grilla.SUR] = { 1, 2, "▼" } }
	for h, d in flechas do
		local b = Boton.nuevo(marco, d[3], UDim2.fromOffset(d[1] * TAM, d[2] * TAM), UDim2.fromOffset(TAM - 4, TAM - 4), { tamTexto = 26 })
		b:SetAttribute("SinClick", true) -- son las flechas del teclado: sin click (docs/29 §3.2)
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				controlador.setDireccionTactil(h)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				controlador.setDireccionTactil(nil)
			end
		end)
	end
	return marco
end

-- ─── Minimapa y transparencia (Fase 33, docs/53 §5) ──────────────────────────
-- Los minimapas van de a 100 por hoja (UiAssets.minimapa[n] = { hoja, x, y }), como en HudPC
local function ponerMinimapa(label: ImageLabel, n: number)
	local u = (UiAssets :: any).minimapa[n]
	if u then
		label.Image = (UiAssets :: any)[`minimapas{u[1]}`]
		label.ImageRectOffset = Vector2.new(u[2], u[3])
		label.ImageRectSize = Vector2.new(100, 100)
	else
		label.Image = ""
	end
end

-- La opacidad elegida, en los tres grupos. El minimapa en 0 se esconde (y deja de atajar toques).
local function aplicarTransparencia()
	if not t or not t.mini then
		return
	end
	t.mini.GroupTransparency = 1 - opMini / 100
	t.mini.Visible = opMini > 0 and Disp.seVe("minimapa", disposicion)
	-- las flechas y cada botón (Fase 38: cada uno es una pieza con su CanvasGroup)
	local tb = 1 - opBotones / 100
	for id, pz in piezas do
		local m = pz.marco
		if id ~= "minimapa" and m:IsA("CanvasGroup") then
			m.GroupTransparency = tb
		end
	end
end

local ubicarMinimapa: () -> ()

function HudTactil.setTransparencia(mini: number, botones: number)
	opMini, opBotones = ConfigTactil.opMini(mini), ConfigTactil.opBotones(botones)
	aplicarTransparencia()
	ubicarMinimapa() -- (con el minimapa escondido, los avisos vuelven a su lugar)
end

-- Dónde va el minimapa: de fábrica, según el alto de la pantalla (ConfigTactil.lugarMini); si el jugador lo movió o
-- le cambió el tamaño, donde lo dejó (Fase 38). Y lo que se corre para no quedar debajo.
function ubicarMinimapa()
	if not t or not t.mini then
		return
	end
	local ancho, alto = t.gui.AbsoluteSize.X, t.gui.AbsoluteSize.Y
	if alto <= 0 then
		return
	end
	local x, y, lado0, _, escala, ver = Disp.lugar("minimapa", disposicion, ancho, alto)
	local tocado = Disp.tocada("minimapa", disposicion)
	local lado = math.max(24, math.floor(lado0 * escala + 0.5))
	local seVe = ver and opMini > 0
	t.miniLado = lado
	t.mini.Visible = seVe
	-- pegado a las flechas no se abre el mapa al tocarlo: se tocaría sin querer en plena pelea (queda en Menú → Mapa)
	local enEsquina: boolean
	if tocado or Disp.tocada("cruz", disposicion) then
		-- (movido el minimapa o movidas las flechas: se mira dónde quedó cada uno de verdad)
		local cx, cy, cw, ch, cs, cver = Disp.lugar("cruz", disposicion, ancho, alto)
		enEsquina = cver and seTocan(x - 4, y - 4, lado + 8, lado + 8, cx, cy, cw * cs, ch * cs)
	else
		local _, _, _, esquina = ConfigTactil.lugarMini(X_DPAD, alto - BORDE_DPAD - 3 * TAM_DPAD)
		enEsquina = esquina
	end
	local abrir = t.mini:FindFirstChild("AbrirMapa")
	if abrir and abrir:IsA("GuiObject") then
		abrir.Visible = not enEsquina
	end
	t.mini.Position = UDim2.fromOffset(x, y)
	t.mini.Size = UDim2.fromOffset(lado, lado)
	t.miniEscala.Scale = lado / 100
	-- achicado se ve mejor suavizado; a tamaño real, pixel por pixel
	t.miniImagen.ResampleMode = if lado >= 100 then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default
	-- los avisos de estado (parálisis, invisibilidad, dopas), el diagnóstico y la ventana de mascotas van a la derecha
	-- del minimapa si les quedaría encima. (Movido por el jugador: solo si de verdad cae sobre ese lugar.)
	local tapa = seVe and (if tocado then seTocan(x, y, lado, lado, 12, 94, 190, 80) else y < 150)
	local xLibre = if tapa then x + lado + 8 else 12
	-- los avisos cuelgan de las barras: si el jugador las movió, van con ellas, justo debajo
	local xAvisos = if Disp.tocada("barras", disposicion) then 0 else xLibre - 12
	t.paralisis.Position = UDim2.fromOffset(xAvisos, 86)
	t.invisibilidad.Position = UDim2.fromOffset(xAvisos, 102)
	t.dopas.Position = UDim2.fromOffset(xAvisos, 118)
	local diag = t.gui:FindFirstChild("Diagnostico")
	if diag and diag:IsA("GuiObject") then
		diag.Position = UDim2.fromOffset(xLibre, 118)
	end
	local masc = t.gui:FindFirstChild("Mascotas")
	if masc and masc:IsA("GuiObject") then
		masc.Position = UDim2.fromOffset(if tocado then xLibre elseif seVe then x + lado + 8 else 12, 146)
	end
end

-- ─── Acomodar las piezas (Fase 38, docs/58) ──────────────────────────────────
-- Un atajo suelto: se arma la primera vez que el jugador lo suma
local function crearAtajo(i: number)
	Atajos.montarSuelta(marcoPieza(t.gui, `atajo{i}`), i, Disp.AtajoLado, ctl, elegidoParaAtajo)
end

-- La consola: dónde va y con qué ancho (el que deja libre la pantalla), y la caja para escribir, que va en su lugar
-- aunque la consola esté escondida. Crece hacia abajo: movida por el jugador, con 12 líneas no se sale por el borde.
-- La llaman acomodarPiezas y setConsola (al cambiarle el tamaño).
local function ubicarConsola()
	local pz = piezas.consola
	if not t or not pz then
		return
	end
	local ancho, alto = t.gui.AbsoluteSize.X, t.gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	local x, y, w, _, s = Disp.lugar("consola", disposicion, ancho, alto)
	t.anchoConsola = w
	if Disp.tocada("consola", disposicion) then
		local lineas = ChatCfg.TamanosConsola[consolaIdx] or 0
		y = math.max(0, math.min(y, math.floor(alto - (lineas * LINEA + 6) * s)))
	end
	pz.marco.Position = UDim2.fromOffset(x, y)
	local e = pz.escala
	if e then
		e.Scale = s
	end
	local caja = t.cajaChat
	if caja then
		caja.Position = UDim2.fromOffset(x, y)
		caja.Size = UDim2.fromOffset(math.floor(w * s + 0.5), 32)
	end
end

-- Cada pieza a su lugar, con su tamaño, y a la vista o no: lo de fábrica o lo que eligió el jugador
-- (Config/Disposicion). Se llama al armar el HUD, cuando cambia el tamaño de la pantalla y cuando cambia lo elegido.
local function acomodarPiezas()
	if not t or not t.mini or not t.mas then
		return -- todavía no está armado
	end
	local ancho, alto = t.gui.AbsoluteSize.X, t.gui.AbsoluteSize.Y
	if ancho <= 0 or alto <= 0 then
		return
	end
	-- la que vale para esta pantalla: lo que se está armando o, de lo guardado, la del teléfono o la de la tableta
	disposicion = if enPrevia then previa else Disp.deGuardado(guardado, Disp.clase(ancho, alto))
	for i = 1, Disp.Atajos do
		local id = `atajo{i}`
		if not piezas[id] and Disp.seVe(id, disposicion) then
			crearAtajo(i)
		end
	end
	for id, pz in piezas do
		-- (el minimapa cambia de lado, no de escala: ubicarMinimapa; la consola, en ubicarConsola, desde setConsola)
		if id ~= "minimapa" and id ~= "consola" then
			local x, y, _, _, s, ver = Disp.lugar(id, disposicion, ancho, alto)
			pz.marco.Position = UDim2.fromOffset(x, y)
			local e = pz.escala
			if e then
				e.Scale = s
			end
			pz.marco.Visible = ver
		end
	end
	HudTactil.setConsola(consolaIdx)
	ubicarMinimapa()
	t.mas.Visible = false
end

-- La lista de "Más" se abre al lado de su botón, esté donde esté: a la izquierda (o a la derecha si no entra), con
-- el pie 40 px más abajo que el del botón (de fábrica, a la altura del pie de Agarrar)
local function ubicarListaMas()
	local b = t.botonMas
	local p, tam = b.AbsolutePosition - t.gui.AbsolutePosition, b.AbsoluteSize
	local lista, pantalla = t.mas.AbsoluteSize, t.gui.AbsoluteSize
	local x = p.X - 6 - lista.X
	if x < 0 then
		x = p.X + tam.X + 6
	end
	local y = p.Y + tam.Y + 40 * tam.Y / 36 - lista.Y
	t.mas.AnchorPoint = Vector2.zero
	t.mas.Position = UDim2.fromOffset(
		math.clamp(math.floor(x + 0.5), 0, math.max(0, pantalla.X - lista.X)),
		math.clamp(math.floor(y + 0.5), 0, math.max(0, pantalla.Y - lista.Y))
	)
end

-- Lo guardado con la cuenta (nil o false: todo de fábrica). Puede llegar antes que el HUD. Lo que no sirve se ignora.
function HudTactil.setGuardado(g: any)
	local limpio, bien = Disp.validarGuardado(g)
	if not bien then
		return
	end
	guardado = limpio
	acomodarPiezas()
	aplicarTransparencia() -- (los atajos recién armados toman la transparencia de los botones)
end

function HudTactil.guardado(): Disp.Guardado?
	return guardado
end

-- La pantalla de acomodar va mostrando lo que se arma (una disposición para ESTA pantalla), sin guardarlo. Vale
-- hasta que se cierra (HudTactil.editar(false)).
function HudTactil.setDisposicion(d: any)
	local limpio, bien = Disp.validar(d)
	if not bien or not editando then
		return
	end
	previa, enPrevia = limpio, true
	acomodarPiezas()
	aplicarTransparencia()
end

-- La disposición guardada para esta pantalla (nil = de fábrica)
function HudTactil.disposicion(): Disp.Datos?
	if not t then
		return nil
	end
	return Disp.deGuardado(guardado, Disp.clase(t.gui.AbsoluteSize.X, t.gui.AbsoluteSize.Y))
end

-- La pantalla de acomodar (client/UI/HudEditor) avisa que se abrió o se cerró: abierta, se ven todos los botones
-- (también los que aparecen solos), no queda nada desplegado y la fila de arriba se esconde
function HudTactil.editar(si: boolean)
	editando = si
	if not t then
		previa, enPrevia = nil, false
		return
	end
	-- Abierta, se muestra lo que se va armando: arranca en lo guardado y no cambia aunque justo llegue otra cosa del
	-- servidor. Cerrada, vuelve lo guardado.
	if si then
		previa, enPrevia = HudTactil.disposicion(), true
	else
		previa, enPrevia = nil, false
	end
	if ctl then
		ctl.setDireccionTactil(nil) -- una flecha que quedó apretada debajo del velo no sigue caminando al salir
	end
	cerrarDesplegados()
	Atajos.cerrarBurbuja()
	for id, b in botonesDinamicos do
		b.Visible = si or dinamicos[id] == true
	end
	t.arriba.Enabled = t.gui.Enabled and not si
	acomodarPiezas()
	aplicarTransparencia()
end

-- La ScreenGui de la interfaz y su tamaño, para la pantalla de acomodar (nil en la PC: no hay qué acomodar)
function HudTactil.area(): (ScreenGui?, number, number)
	if not t then
		return nil, 0, 0
	end
	return t.gui, t.gui.AbsoluteSize.X, t.gui.AbsoluteSize.Y
end

-- Los aliados que están en este mapa: grupo en verde, clan en azul (como en HudPC)
local puntosAliados: { Frame } = {}
function HudTactil.aliados()
	local ctx = contexto
	if not t or not t.mini or not ctx then
		return
	end
	local n = 0
	for _, a in Aliados.lista() do
		if a.mapa == ctx.mapa then
			n += 1
			local p = puntosAliados[n]
			if not p then
				p = Instance.new("Frame")
				p.Name = "Aliado"
				p.BorderSizePixel = 0
				p.Size = UDim2.fromOffset(5, 5) -- más grande que en la PC: el minimapa va achicado
				p.ZIndex = 3
				local borde = Instance.new("UIStroke")
				borde.Color = Color3.new(0, 0, 0)
				borde.Thickness = 1
				borde.Parent = p
				p.Parent = t.miniImagen
				puntosAliados[n] = p
			end
			local x, y = ReglasAliados.puntoMinimapa(a.x, a.y)
			p.Position = UDim2.fromOffset(x - 1, y - 1)
			p.BackgroundColor3 = Aliados.color(a.tipo)
			p.Visible = true
		end
	end
	for i = n + 1, #puntosAliados do
		puntosAliados[i].Visible = false
	end
end

local function minimapa(gui: ScreenGui, ctx: Hud.Contexto)
	local grupo = Instance.new("CanvasGroup")
	grupo.Name = "MiniMapa"
	grupo.BackgroundColor3 = Color3.new(0, 0, 0)
	grupo.BackgroundTransparency = 0.35
	grupo.BorderSizePixel = 0
	grupo.Size = UDim2.fromOffset(100, 100)
	grupo.ZIndex = 2
	grupo.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(120, 100, 70)
	borde.Parent = grupo
	-- adentro todo va en casilleros (100 × 100) y se achica junto
	local imagen = Instance.new("ImageLabel")
	imagen.Name = "Mapa"
	imagen.BackgroundTransparency = 1
	imagen.Size = UDim2.fromOffset(100, 100)
	imagen.ClipsDescendants = true
	imagen.Parent = grupo
	local escala = Instance.new("UIScale")
	escala.Parent = imagen
	ponerMinimapa(imagen, ctx.mapa)
	local area = Instance.new("Frame")
	area.Name = "Vista"
	area.BackgroundTransparency = 1
	area.Size = UDim2.fromOffset(25, 21)
	area.ZIndex = 3
	area.Parent = imagen
	local bordeArea = Instance.new("UIStroke")
	bordeArea.Color = Color3.fromRGB(153, 180, 209)
	bordeArea.Thickness = 1
	bordeArea.Parent = area
	local punto = Instance.new("Frame")
	punto.Name = "Yo"
	punto.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	punto.BorderSizePixel = 0
	punto.Size = UDim2.fromOffset(5, 5)
	punto.ZIndex = 4
	punto.Parent = imagen
	-- tocarlo abre el mapa del mundo (como el de la PC)
	local abrir = Instance.new("TextButton")
	abrir.Name = "AbrirMapa"
	abrir.BackgroundTransparency = 1
	abrir.Text = ""
	abrir.Size = UDim2.fromScale(1, 1)
	abrir.ZIndex = 5
	abrir.Parent = grupo
	Click.activado(abrir, function()
		MapaMundo.abrir()
	end)
	t.mini, t.miniImagen, t.miniEscala, t.miniPunto, t.miniArea = grupo, imagen, escala, punto, area
	hacerPieza("minimapa", grupo, false) -- (su tamaño no va con una escala: cambia el lado, ubicarMinimapa)
	t.miniLado = 100
	Aliados.alCambiar(HudTactil.aliados)
end

-- ─── Arranque ────────────────────────────────────────────────────────────────
function HudTactil.iniciar(ctx: Hud.Contexto, controlador: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudAO"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	t = { gui = gui, barras = {}, anchoConsola = 0 } :: any
	contexto = ctx
	ctl = controlador

	-- Barras, oro y experiencia (arriba a la izquierda)
	local izq = Instance.new("Frame")
	izq.Name = "Barras"
	izq.BackgroundTransparency = 1
	izq.Position = UDim2.fromOffset(12, 8)
	izq.Size = UDim2.fromOffset(160, 100)
	izq.Parent = gui
	t.izq = izq
	hacerPieza("barras", izq, true)
	barra(izq, "Vida", 0)
	barra(izq, "Mana", 22)
	barra(izq, "Energia", 44)
	barraFina(izq, "Hambre", 149)
	barraFina(izq, "Sed", 156)
	t.oro = texto(izq, { Position = UDim2.fromOffset(0, 66), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Left })
	Hud.montarTocarOro(izq, UDim2.fromOffset(0, 62), UDim2.fromOffset(52, 24)) -- tocar el oro lo tira (docs/22 §7.2)
	t.porc = texto(izq, {
		Position = UDim2.fromOffset(80, 66),
		Size = UDim2.fromOffset(80, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(0, 255, 255),
	})
	-- Nivel y estrella de skills al lado de las barras (docs/21 §7.2)
	t.nivel = texto(izq, { Position = UDim2.fromOffset(162, 34), Size = UDim2.fromOffset(36, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center })
	local estrella = Instance.new("ImageButton")
	estrella.Name = "Estrella"
	estrella.BackgroundTransparency = 1
	estrella.Image = UiAssets.estrella
	estrella.Position = UDim2.fromOffset(169, 2)
	estrella.Size = UDim2.fromOffset(30, 30)
	estrella.Visible = false
	estrella.Parent = izq
	Click.activado(estrella, function()
		if ctx.abrirSkills then
			ctx.abrirSkills()
		end
	end)
	t.estrella = estrella
	-- Panel de diagnóstico (DF10-02 B): se abre desde el Menú (Fase 22; antes, con un botón "i" junto a las barras)
	t.porc.Position = UDim2.fromOffset(52, 66)
	-- El reloj de la Poción de Experiencia (Fase 23, docs/42 §10): al lado del porcentaje, solo mientras dura
	Hud.montarRelojExp(texto(izq, { Name = "ExpBoost", Position = UDim2.fromOffset(138, 66), Size = UDim2.fromOffset(120, 16), TextXAlignment = Enum.TextXAlignment.Left, Text = "" }))
	Diagnostico.montar(gui, UDim2.fromOffset(12, 118), Vector2.zero, controlador.descartes, 12)
	Mascotas.montar(gui, UDim2.fromOffset(12, 146), 0.9) -- Fase 16c (docs/33 §6): debajo de los avisos de estado
	t.paralisis = texto(izq, {
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.fromOffset(300, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(230, 230, 250),
	})
	t.dopas = texto(izq, {
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.fromOffset(300, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(236, 136, 66),
	})
	t.invisibilidad = texto(izq, {
		Position = UDim2.fromOffset(0, 102),
		Size = UDim2.fromOffset(300, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(236, 136, 66),
	})

	-- Consola (arriba al centro), entre las barras (12 + 160 + 12 px) y el panel de la derecha (212 + 6 px)
	t.consola = fondo(gui, UDim2.fromOffset(212, 8), UDim2.new(1, -212 - 224, 0, 4 * LINEA + 6))
	t.consola.Name = "Consola"
	Consola.montar(t.consola, { tamTexto = 13, trazo = true, barra = 4 })
	hacerPieza("consola", t.consola, true)

	-- La fila de arriba (Fase 22, docs/41 §2.2): en el lugar libre de la barra de Roblox, al lado de sus botones.
	-- TopbarSafeInsets da justo ese rectángulo y se acomoda solo si Roblox cambia sus botones.
	local arriba = Instance.new("ScreenGui")
	arriba.Name = "HudAOArriba"
	arriba.ResetOnSpawn = false
	arriba.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	arriba.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	arriba.DisplayOrder = 1
	arriba.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	t.arriba = arriba
	-- A la izquierda: Chat, el tamaño de la consola (4 / 12 / 1 / 0 líneas, docs/23 DN-09 A) y Menú
	local Y_FILA, ALTO_FILA = 0.5, 30
	local function botonArriba(texto_: string, x: UDim, ancho: number, nombre: string): ImageButton
		local b = Boton.nuevo(arriba, texto_, UDim2.new(x.Scale, x.Offset, Y_FILA, 0), UDim2.fromOffset(ancho, ALTO_FILA), { tamTexto = 14 })
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Name = nombre
		return b
	end
	local bChat = botonArriba("Chat", UDim.new(0, 8), 56, "BotonChat")
	Click.activado(bChat, function()
		cerrarDesplegados()
		Chat.abrir()
	end)
	t.tamConsola = botonArriba("▼", UDim.new(0, 67), 30, "TamConsola")
	Click.activado(t.tamConsola, function()
		local n = consolaIdx % #ChatCfg.TamanosConsola + 1
		HudTactil.setConsola(n)
		Remotes.evento("GuardarConsola"):FireServer(n)
	end)
	local bMenu = botonArriba("Menú", UDim.new(0, 100), 64, "BotonMenu")
	-- Menú (D22-13 A): las ventanas que se abren de vez en cuando
	local function comando(c: string): () -> ()
		return function()
			Remotes.evento("Comando"):FireServer(c)
		end
	end
	t.menu = lista(arriba, "Menu", {
		{ "Grupo", comando("GRUPO") }, -- btnGrupo del original (docs/28 §2.3)
		{ "Clanes", comando("CLANES") }, -- docs/28 §3
		{ "Retos", comando("RETOS") }, -- docs/28 §14
		{ "Quests", comando("INFOQUEST") }, -- Fase 20 (docs/39 §2.6)
		{ "Estadísticas", Estadisticas.abrir }, -- Fase 22 (docs/41 §3)
		{ "Mapa", MapaMundo.abrir }, -- Fase 17a (docs/35 §5)
		{ "Tienda", function() -- Fase 23 (docs/42 §8.4, D23-50 A)
			Tienda.abrir()
		end },
		{ "Guía", function() -- Fase 26 (docs/46 §10)
			if controlador.alGuia then
				controlador.alGuia()
			end
		end },
		{ "Opciones", function() -- docs/29 §5
			if controlador.alOpciones then
				controlador.alOpciones()
			end
		end },
		{ "Diagnóstico", Diagnostico.alternar }, -- DF10-02 B
	}, 130)
	t.menu.AnchorPoint = Vector2.new(0, 0)
	t.menu.Position = UDim2.new(0, 100, 1, 2)
	Click.activado(bMenu, function()
		local abrir = not t.menu.Visible
		cerrarDesplegados()
		t.menu.Visible = abrir
	end)
	HudTactil.setConsola(consolaIdx)
	-- La caja para escribir, encima de la consola
	Chat.montar(gui, UDim2.fromOffset(212, 8), UDim2.new(1, -212 - 224, 0, 32), 15)
	local cajaChat = gui:FindFirstChild("SendTxt")
	t.cajaChat = if cajaChat and cajaChat:IsA("GuiObject") then cajaChat else nil

	-- Fase 13a: el nombre del mapa debajo de la consola, el cartel en el centro y el botón Hogar abajo al centro
	Hud.montarNombreMapa(gui, UDim2.new(0.5, 0, 0, 4 * LINEA + 24), 18)
	Hud.montarCartel(gui, UDim2.fromScale(0.5, 0.5))
	Hud.montarHogar(gui, UDim2.new(0.5, -60, 1, -104), UDim2.fromOffset(120, 44), 16)
	-- Fase 25 (docs/44 §7 y §9): el botón "Elegí tu camino", debajo del nombre del mapa, y la cuenta de /SALIR
	Hud.montarCamino(gui, UDim2.new(0.5, -80, 0, 4 * LINEA + 52), UDim2.fromOffset(160, 40), 15)
	Hud.montarSalida(gui, UDim2.new(0.5, 0, 0, 4 * LINEA + 96), 20)

	-- Pestañas (en la fila de arriba) y panel (debajo, arriba a la derecha)
	local bInv = botonArriba("Inventario", UDim.new(1, -212), 100, "BotonInventario")
	local bHech = botonArriba("Hechizos", UDim.new(1, -106), 100, "BotonHechizos")
	-- El panel va por encima de los botones de acción (ZIndex 10) y se queda con los toques: antes quedaba detrás
	-- (D22-16 A). Abajo, el pie del inventario: el nombre del objeto elegido y Equipar y Tirar (D22-15 A), y desde la
	-- Fase 31 también Mover.
	local ALTO_PIE = 34
	-- Cuántas filas se ven: 5 si entran sin tapar Golpe ni Usar (docs/41 §2.2); en una pantalla baja, 4 o 3 (el resto
	-- se desplaza con el dedo). Golpe empieza 102 px arriba del borde de abajo.
	local camaraPanel = workspace.CurrentCamera
	local altoHud = (if camaraPanel then camaraPanel.ViewportSize.Y else 400) - game:GetService("GuiService"):GetGuiInset().Y
	local FILAS = math.clamp(math.floor((altoHud - 106 - 10 - ALTO_PIE) / CELDA), 3, 5)
	t.panel = fondo(gui, UDim2.new(1, -212, 0, 4), UDim2.fromOffset(206, FILAS * CELDA + 6 + ALTO_PIE), TRANSPARENCIA_PANEL)
	t.panel.Name = "Panel"
	t.tenue = false
	t.botonesLista = {}
	t.panel.Active = true
	t.panel.ZIndex = 10
	-- Fase 16b (docs/32 §6.2): con la mochila hay 30 o 35 slots; se ven 5 filas y el resto se desplaza con el dedo
	local picInv = Instance.new("ScrollingFrame")
	picInv.BackgroundTransparency = 1
	picInv.BorderSizePixel = 0
	picInv.Position = UDim2.fromOffset(3, 3)
	picInv.Size = UDim2.fromOffset(5 * CELDA + 6, FILAS * CELDA)
	picInv.CanvasSize = UDim2.fromOffset(5 * CELDA, 5 * CELDA)
	picInv.ScrollBarThickness = 5
	picInv.ScrollingDirection = Enum.ScrollingDirection.Y
	picInv.ZIndex = 10
	picInv.Parent = t.panel
	t.picInv = picInv
	Inventario.montar(picInv, { celda = CELDA, columnas = 5, cantidad = ConfigInv.Slots, tamTexto = 12, ocultarSinUsar = true })
	Inventario.alCambiarInventario(function()
		picInv.CanvasSize = UDim2.fromOffset(5 * CELDA, math.ceil(Inventario.usables() / 5) * CELDA)
	end)
	local pie = Instance.new("Frame")
	pie.Name = "PieInventario"
	pie.BackgroundTransparency = 1
	pie.Position = UDim2.fromOffset(3, FILAS * CELDA + 5)
	pie.Size = UDim2.new(1, -6, 0, ALTO_PIE - 4)
	pie.ZIndex = 10
	pie.Parent = t.panel
	t.pieInv = pie
	-- Fase 31: tres botones de 44 px (antes dos de 56). "Mover" va a la izquierda del nombre, y Equipar y Tirar siguen
	-- contra el borde derecho, donde estaban: el dedo acostumbrado a Equipar no cae en Tirar. (pintarPie acomoda el
	-- ancho del nombre y qué botones se ven)
	t.nombreItem = texto(pie, {
		Name = "NombreItem",
		Position = UDim2.fromOffset(X_NOMBRE_PIE, 0),
		Size = UDim2.new(1, -X_NOMBRE_PIE - 2 * (ANCHO_BOTON_PIE + 2), 1, 0),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
	})
	local function botonPie(texto_: string, x: UDim, f: () -> ()): ImageButton
		local b = Boton.nuevo(pie, texto_, UDim2.new(x.Scale, x.Offset, 0, 0), UDim2.fromOffset(ANCHO_BOTON_PIE, ALTO_PIE - 4), { tamTexto = 11 })
		b.ZIndex = 11
		for _, hijo in b:GetChildren() do
			if hijo:IsA("TextLabel") then
				hijo.ZIndex += 10
				hijo.TextWrapped = false -- una sola palabra: que no se parta en dos renglones
			end
		end
		Click.activado(b, function()
			f()
		end)
		return b
	end
	t.equiparPie = botonPie("Equipar", UDim.new(1, -2 * ANCHO_BOTON_PIE - 2), controlador.equipar)
	t.tirarPie = botonPie("Tirar", UDim.new(1, -ANCHO_BOTON_PIE), controlador.tirar)
	local mover = botonPie("Mover", UDim.new(0, 0), function()
		if Inventario.moviendo() then
			Inventario.cancelarMover()
		elseif not Inventario.empezarMover() then
			avisarPie(MSG_MOVER_ELEGIR) -- sin objeto elegido no hay qué mover
		end
	end)
	local resalte = Instance.new("UIStroke")
	resalte.Name = "Resalte"
	resalte.Color = COLOR_MOVER
	resalte.Thickness = 2
	resalte.Enabled = false
	resalte.Parent = mover
	t.resalteMover = resalte
	Inventario.alCambiarMover(function(_armado: boolean)
		pintarPie()
	end)
	t.hlst = Instance.new("Frame")
	t.hlst.BackgroundTransparency = 1
	t.hlst.Position = UDim2.fromOffset(3, 3)
	t.hlst.Size = UDim2.new(1, -6, 0, FILAS * CELDA - 22)
	t.hlst.ZIndex = 10
	t.hlst.Parent = t.panel
	Hechizos.montar(t.hlst, { fila = 24, tamTexto = 15 })
	local bInfo = Boton.nuevo(t.hlst, "Info", UDim2.new(1, -70, 1, 4), UDim2.fromOffset(70, 26), { tamTexto = 14 })
	Click.activado(bInfo, function()
		Hechizos.info()
	end)
	-- Mover el hechizo seleccionado (cmdMoverHechi del original, docs/28 §10)
	local subir = Boton.nuevo(t.hlst, "▲", UDim2.new(0, 0, 1, 4), UDim2.fromOffset(40, 26), { tamTexto = 14 })
	local bajar = Boton.nuevo(t.hlst, "▼", UDim2.new(0, 44, 1, 4), UDim2.fromOffset(40, 26), { tamTexto = 14 })
	subir.Name, bajar.Name = "SubirHechizo", "BajarHechizo"
	t.botonesLista = { bInfo, subir, bajar }
	Click.activado(subir, function()
		Hechizos.mover(true)
	end)
	Click.activado(bajar, function()
		Hechizos.mover(false)
	end)
	-- Todo lo del panel, por encima de los botones de acción
	for _, d in t.panel:GetDescendants() do
		if d:IsA("GuiObject") and d.ZIndex < 10 then
			d.ZIndex += 10
		end
	end
	Click.activado(bInv, function()
		mostrarPanel("inventario")
	end)
	Click.activado(bHech, function()
		mostrarPanel("hechizos")
	end)
	-- Al tocar un hechizo de la lista, el panel se cierra solo: tapa a Lanzar (D22-16 A)
	Hechizos.alTocarFila(function()
		if t.pestana == "hechizos" then
			mostrarPanel(nil)
		end
	end)

	-- Acciones (de fábrica, abajo a la derecha). Cada botón va en su pieza, un CanvasGroup al que se le cambia la
	-- transparencia entera (Fase 33; hasta la Fase 38 iban todos en un solo grupo de 250 × 190). Dónde va cada uno lo
	-- dice Config/Disposicion; acá cada botón llena su pieza.
	local ORIGEN = UDim2.fromOffset(0, 0)
	-- Con un arco o Cuchillas equipados, Golpe pasa a ser Disparar: usa el arma y el toque siguiente elige el blanco
	-- (Fase 14a, docs/27 §2.2)
	local golpe = Boton.nuevo(marcoPieza(gui, "golpe"), "Golpe", ORIGEN, UDim2.fromOffset(88, 88), { tamTexto = 20 })
	golpe.Name = "Golpe"
	golpe:SetAttribute("SinClick", true) -- la tecla de atacar: suena el golpe, no el click
	Click.activado(golpe, function()
		local arco = Inventario.slotProyectil()
		if arco > 0 then
			Inventario.usarSlot(arco)
		else
			controlador.golpe()
		end
	end)
	t.esperaGolpe = espera(golpe)
	local function textoGolpe()
		Boton.texto(golpe, if Inventario.slotProyectil() > 0 then "Disparar" else "Golpe")
	end
	Inventario.alCambiarInventario(textoGolpe)
	textoGolpe()

	t.usar = Boton.nuevo(marcoPieza(gui, "usar"), "", ORIGEN, UDim2.fromOffset(64, 64), { tamTexto = 13 })
	t.usar.Name = "Usar"
	t.usar:SetAttribute("SinClick", true)
	t.usarIcono = Instance.new("ImageLabel")
	t.usarIcono.BackgroundTransparency = 1
	t.usarIcono.AnchorPoint = Vector2.new(0.5, 0.5)
	t.usarIcono.Position = UDim2.fromScale(0.5, 0.45)
	t.usarIcono.ResampleMode = Enum.ResamplerMode.Pixelated
	t.usarIcono.ZIndex = 4
	t.usarIcono.Parent = t.usar
	t.usarCant = texto(t.usar, { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 14), TextSize = 12, ZIndex = 4 })
	texto(t.usar, { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 12), TextSize = 11, ZIndex = 4, Text = "Usar" })
	Click.activado(t.usar, function()
		Inventario.usar("doble") -- 125 ms, como el doble click (DF9-06 C)
	end)

	-- Lanzar: se crea siempre y se ve en cuanto el personaje tiene un hechizo (D22-18 A; antes no aparecía si el
	-- primero se aprendía jugando)
	local lanzar = Boton.nuevo(marcoPieza(gui, "lanzar"), "Lanzar", ORIGEN, UDim2.fromOffset(88, 64), { tamTexto = 15 })
	lanzar.Name = "Lanzar"
	botonesDinamicos.lanzar = lanzar
	Click.activado(lanzar, function()
		Hechizos.lanzar(ctx.lanzar)
	end)
	t.lanzar = lanzar
	t.esperaLanzar = espera(lanzar)
	Hechizos.alCambiarSeleccion(function(slot)
		Boton.texto(lanzar, if slot > 0 then Hechizos.nombre(slot) else "Lanzar")
	end)
	local function verLanzar()
		local hay = false
		for _, id in Hechizos.lista() do
			if id and id ~= 0 then
				hay = true
				break
			end
		end
		setDinamico("lanzar", hay)
	end
	Hechizos.alCambiarLista(verLanzar)
	verLanzar()

	-- Meditar: solo en las clases con maná (D22-18 A; lo decide `estadisticas` con el maná máximo)
	local meditar = Boton.nuevo(marcoPieza(gui, "meditar"), "Meditar", ORIGEN, UDim2.fromOffset(64, 44), { tamTexto = 13 })
	meditar.Name = "Meditar"
	botonesDinamicos.meditar = meditar
	setDinamico("meditar", false)
	Click.activado(meditar, function()
		controlador.meditar()
	end)
	t.meditar = meditar

	-- La columna de la izquierda, de abajo hacia arriba: Agarrar, Más, Navegar (con un barco) y Seguir (trabajando)
	local agarrar = Boton.nuevo(marcoPieza(gui, "agarrar"), "Agarrar", ORIGEN, UDim2.fromOffset(80, 36), { tamTexto = 13 })
	agarrar.Name = "Agarrar"
	Click.activado(agarrar, function()
		controlador.agarrar()
	end)
	-- Más (D22-14 A): lo que se usa poco. Ocultarse y Robar (Fase 14a, docs/27 §5 y §6) y Domar (Fase 16c, docs/33)
	local mas = Boton.nuevo(marcoPieza(gui, "mas"), "Más", ORIGEN, UDim2.fromOffset(80, 36), { tamTexto = 13 })
	mas.Name = "Mas"
	t.botonMas = mas
	t.mas = lista(gui, "ListaMas", {
		{ "Ocultarse", function()
			controlador.ocultarse()
		end },
		{ "Robar", function()
			controlador.robar()
		end },
		{ "Domar", function()
			controlador.domar()
		end },
	}, 84)
	Click.activado(mas, function()
		local abrir = not t.mas.Visible
		cerrarDesplegados()
		if abrir then
			ubicarListaMas() -- al lado del botón, esté donde esté
		end
		t.mas.Visible = abrir
	end)
	-- Fase 38 (docs/58): los mismos tres, como botones sueltos. De fábrica no se ven: los suma el jugador.
	for _, d in { { "ocultarse", "Ocultarse", controlador.ocultarse }, { "robar", "Robar", controlador.robar }, { "domar", "Domar", controlador.domar } } do
		local b = Boton.nuevo(marcoPieza(gui, d[1] :: string), d[2] :: string, ORIGEN, UDim2.fromOffset(80, 36), { tamTexto = 13 })
		b.Name = d[2] :: string
		local hacer = d[3] :: () -> ()
		Click.activado(b, function()
			hacer()
		end)
	end
	-- Navegar (D22-17 A): aparece con un barco en el inventario; navegando dice "Bajar". Si todavía no puede usar el
	-- barco, el servidor contesta por qué, como al usarlo desde el inventario.
	local navegar = Boton.nuevo(marcoPieza(gui, "navegar"), "Navegar", ORIGEN, UDim2.fromOffset(80, 36), { tamTexto = 13 })
	navegar.Name = "Navegar"
	botonesDinamicos.navegar = navegar
	setDinamico("navegar", false)
	Click.activado(navegar, function()
		controlador.navegar()
	end)
	t.navegar = navegar
	local function verNavegar()
		local tiene, navegando = false, false
		for _, d in Inventario.slots() do
			local o = Objetos[d.obj] :: any
			if o and o.tipo == "barco" then
				tiene = true
				navegando = navegando or d.equipado == true
			end
		end
		setDinamico("navegar", tiene)
		Boton.texto(navegar, if navegando then "Bajar" else "Navegar")
	end
	Inventario.alCambiarInventario(verNavegar)
	verNavegar()
	-- Fase 16a (DR16-12 A): "Seguir" repite el último click de trabajo (el F8 de la PC); aparece después de trabajar
	local seguir = Boton.nuevo(marcoPieza(gui, "seguir"), "Seguir", ORIGEN, UDim2.fromOffset(80, 36), { tamTexto = 13 })
	seguir.Name = "Seguir"
	botonesDinamicos.seguir = seguir
	setDinamico("seguir", false)
	Click.activado(seguir, function()
		controlador.alternarMacro()
	end)
	controlador.alCambiarMacro = function(estadoMacro: string)
		setDinamico("seguir", estadoMacro ~= "nada")
		Boton.texto(seguir, if estadoMacro == "activo" then "Parar" else "Seguir")
	end

	t.seguro = Instance.new("ImageButton")
	t.seguro.Name = "Seguro"
	t.seguro.BackgroundTransparency = 1
	t.seguro.AutoButtonColor = false
	t.seguro.ResampleMode = Enum.ResamplerMode.Pixelated
	t.seguro.Parent = marcoPieza(gui, "seguro")
	Click.activado(t.seguro, function()
		ctx.seguro()
	end)
	HudTactil.setSeguro(true)
	mostrarPanel(nil)

	t.dpad = dpad(gui, controlador)
	minimapa(gui, ctx)
	-- Las coordenadas (Fase 39, docs/59 §2; pedido del autor: "arriba del mapa, en chiquito"): como en la PC, el
	-- mapa y el casillero. Es una pieza más: se mueve, se achica y se esconde desde "Acomodar la interfaz".
	local coord = texto(gui, {
		Name = "Coordenadas",
		Size = UDim2.fromOffset(Disp.CoordAncho, Disp.CoordAlto),
		Font = Enum.Font.Code,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(255, 255, 0),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Text = "",
	})
	hacerPieza("coord", coord, true)
	t.coord = coord
	acomodarPiezas() -- cada pieza a su lugar: el de fábrica o el que eligió el jugador (también ubica el minimapa)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(acomodarPiezas)
	aplicarTransparencia()
	HudTactil.aliados()

	Inventario.alCambiarSeleccion(function()
		actualizarUsar()
	end)
	actualizarUsar()

	acomodar()
	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("ViewportSize"):Connect(acomodar)
	end

	RunService.RenderStepped:Connect(function()
		local g, gt, h, ht = controlador.enfriamientos()
		t.esperaGolpe.Size = UDim2.fromScale(1, g / gt)
		if t.esperaLanzar then
			t.esperaLanzar.Size = UDim2.fromScale(1, h / ht)
		end
		t.paralisis.Text = Hud.textoParalisis()
		t.invisibilidad.Text = Hud.textoInvisibilidad()
		local txt, aviso = Hud.textoDopas()
		t.dopas.Text = if aviso and Hud.titilaApagado() then "" else txt
		-- el minimapa (el punto propio y el recuadro de lo que se ve) y las coordenadas
		if t.mini.Visible or t.coord.Visible then
			local x, y = ctx.posicion()
			local tx, ty = math.floor(x + 0.5), math.floor(y + 0.5)
			t.miniPunto.Position = UDim2.fromOffset(tx - 3, ty - 3)
			t.miniArea.Position = UDim2.fromOffset(tx - 13, ty - 11)
			if tx ~= coordX or ty ~= coordY or ctx.mapa ~= coordMapa then
				coordX, coordY, coordMapa = tx, ty, ctx.mapa
				t.coord.Text = `Map:{ctx.mapa} X:{tx} Y:{ty}` -- (el mismo formato que en la PC)
			end
		end
	end)
end

-- Tamaño de la consola: índice de Chat.TamanosConsola (4, 12, 1 o 0 líneas; 0 la esconde). Puede llegar antes del HUD.
function HudTactil.setConsola(n: number)
	if not ChatCfg.TamanosConsola[n] then
		return
	end
	consolaIdx = n
	if not t or not t.consola or not t.tamConsola then
		return
	end
	local lineas = ChatCfg.TamanosConsola[n]
	local alto = if lineas > 0 then lineas * LINEA + 6 else 0
	ubicarConsola() -- (con más líneas puede tener que subir para no salirse de la pantalla)
	t.consola.Visible = lineas > 0 and Disp.seVe("consola", disposicion)
	t.consola.Size = UDim2.fromOffset(t.anchoConsola, alto) -- (el ancho lo pone ubicarConsola: el que deja libre la pantalla)
	local siguiente = ChatCfg.TamanosConsola[n % #ChatCfg.TamanosConsola + 1]
	Boton.texto(t.tamConsola, if siguiente > lineas then "▼" else "▲")
end

function HudTactil.setSeguro(puesto: boolean)
	Grh.aplicar(t.seguro, if puesto then 4979 else 4983)
	t.seguro.Size = UDim2.fromOffset(42, 45)
end

function HudTactil.estadisticas(s: any)
	setBarra("Vida", s.hp, s.maxHp, 90)
	setBarra("Energia", s.sta, s.maxSta, 83)
	local b = t.barras.Mana
	b.marco.Visible = s.maxMana > 0
	setDinamico("meditar", s.maxMana > 0)
	setBarra("Mana", s.mana, s.maxMana, 90)
	setFina("Hambre", s.hambre or 100)
	setFina("Sed", s.sed or 100)
	local oro = s.oro or 0
	t.oro.Text = `Oro {oro}`
	t.oro.TextColor3 = Hud.colorOro(oro, s.elv or 1)
	t.porc.Text = Hud.porcentajeExp(s.exp or 0, s.elu or 0)
	Hud.setExpBoost(s.expBoost)
	t.estrella.Visible = (s.skillPts or 0) > 0
	t.nivel.Text = `Nivel {s.elv or 1}`
	HudTactil.setSeguro(s.seguro)
	Hud.setMuerto(s.muerto == true)
end

-- Sin etiqueta de mapa en el táctil (docs/17 §3); el minimapa, desde la Fase 33
function HudTactil.cambiarMapa(n: number, _nombre: string)
	local ctx = contexto
	if ctx then
		ctx.mapa = n
	end
	if t and t.miniImagen then
		ponerMinimapa(t.miniImagen, n)
		HudTactil.aliados()
	end
end
function HudTactil.setNombre(_nombre: string) end -- (el celular no muestra el nombre propio)

-- El mando en el celular (Fase 18, docs/37 §7.1): abre el panel del inventario o el de los hechizos
function HudTactil.pestana(inventario: boolean, tenue: boolean?)
	local cual = if inventario then "inventario" else "hechizos"
	if t and t.pestana ~= cual then
		mostrarPanel(cual, tenue)
	elseif t then
		-- ya estaba abierta: solo cambia cómo se ve (el mando la deja traslúcida)
		ponerTenue(cual == "hechizos" and tenue == true)
	end
end

-- El mando (Fase 35, docs/56 §3): qué panel está abierto ("inventario", "hechizos" o nil) y cerrarlo
function HudTactil.panelAbierto(): string?
	return if t then t.pestana else nil
end

function HudTactil.cerrarPanel()
	if t and t.pestana ~= nil then
		mostrarPanel(nil)
	end
end

-- La lista de hechizos, si está abierta y traslúcida: el mando lanza y dispara a través de ella
function HudTactil.panelTenue(): GuiObject?
	if t and t.pestana == "hechizos" and t.panel.Visible and t.tenue then
		return t.panel
	end
	return nil
end

-- Dónde está en la pantalla una parte del HUD, para la marca del tutorial (Fase 22, docs/41 §6): posición y tamaño,
-- o nil si no está a la vista
function HudTactil.parte(nombre: string): (Vector2?, Vector2?)
	if not t then
		return nil, nil
	end
	local donde: { [string]: { any } } = {
		cruz = { t.gui, "DPad" },
		barras = { t.gui, "Barras" },
		golpe = { t.gui, "Golpe" },
		estrella = { t.gui, "Estrella" },
		inventario = { t.arriba, "BotonInventario" },
		hechizos = { t.arriba, "BotonHechizos" },
		chat = { t.arriba, "BotonChat" },
	}
	local d = donde[nombre]
	local o = d and (d[1] :: Instance):FindFirstChild(d[2], true)
	if not o or not o:IsA("GuiObject") then
		return nil, nil
	end
	local p: Instance? = o
	while p and p:IsA("GuiObject") do
		if not p.Visible then
			return nil, nil
		end
		p = p.Parent
	end
	return o.AbsolutePosition, o.AbsoluteSize
end

-- Toda la pantalla, en el espacio de una ScreenGui común (el que descuenta la barra de Roblox)
function HudTactil.rectVista(): (Vector2, Vector2)
	local camara = workspace.CurrentCamera
	local barra = game:GetService("GuiService"):GetGuiInset()
	return Vector2.new(0, -barra.Y), if camara then camara.ViewportSize else Vector2.new(800, 600)
end

-- En celular todo toque que no cae en un botón cae en la vista. Con el panel, el Menú o Más abiertos, ese toque los
-- cierra y no cuenta como toque en el mapa (Fase 22, docs/41 §2.2).
-- Lo mismo, solo la pregunta (dentroDeLaVista además cierra lo desplegado): la usa el puntero del mando (Fase 34)
function HudTactil.enLaVista(_pos: Vector2): boolean
	return true
end

function HudTactil.dentroDeLaVista(_pos: Vector2): boolean
	if t and cerrarDesplegados() then
		return false
	end
	return true
end

return HudTactil
