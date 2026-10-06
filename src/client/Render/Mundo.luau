--!strict
--[[
	Mundo — render del mapa (decisión D-03: SurfaceGui + pool de ImageLabels).

	Cómo funciona (igual que el motor original, que redibuja el viewport cada frame):
	- Una Part plana ("lienzo") cubre la vista más un margen. Tiene un SurfaceGui en la cara de arriba.
	- El lienzo está anclado a un tile "origen". Mientras la cámara se mueve dentro del mismo tile,
	  no se toca nada: la cámara se desliza sobre el lienzo quieto.
	- Cuando la cámara cruza a otro tile, el lienzo se mueve un tile entero y se reasignan los
	  sprites de un pool de ImageLabels (imagen, recorte, posición, ZIndex). No se crean ni se
	  destruyen instancias en el camino.

	Orden de dibujado (docs/09-graficos-y-animaciones.md §7):
	  capas 1 y 2 (piso) → pasada 2 por fila y columna: objeto, [personaje], capa 3 → capa 4 encima de todo.
	Los personajes (Fase 5) se dibujan en el mismo SurfaceGui usando Mundo.z().

	Fase 13a (docs/22): `Mundo.iniciar()` arma el lienzo y `Mundo.cargar(n)` cambia de mapa (sin fundido, como
	SwitchMap). Las puertas cambian el bloqueo del cliente (`mapa.dinamico`). Techos (DF13-08 A): bajo techo, toda la
	capa 4 visible baja de 250 a 150 de alfa y brillo, de a 1 por frame (a 60 fps).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Ciudad = require(ReplicatedStorage.Shared.Config.Ciudad)
local ObjetosPiso = require(ReplicatedStorage.Shared.Generado.ObjetosPiso)
local Recursos = require(ReplicatedStorage.Shared.Mundo.Recursos)
local Grh = require(script.Parent.Grh)
local Camara = require(script.Parent.Camara)

local Mundo = {}

local TILE_PX = Grilla.TILE_PX
local TS = Grilla.TILE_STUDS
local PPS = TILE_PX / TS -- PixelsPerStud del SurfaceGui: 8
local MARGEN = 1 -- tiles extra alrededor de la vista
-- Los sprites grandes se anclan a un tile y desbordan hacia arriba y a los costados (árboles de
-- hasta 256×320 px): hay que mirar tiles fuera del lienzo para no cortarlos.
local EXTRA_ABAJO, EXTRA_LADOS, EXTRA_ARRIBA = 10, 4, 1

-- Sub-orden dentro de un tile en la pasada 2 (docs/09 §7)
Mundo.SUB = { objeto = 0, sombra = 1, cuerpo = 3, cabeza = 4, casco = 5, arma = 6, escudo = 7, nombre = 8, capa3 = 9, fx = 11 }

local mapa: any = nil
local objetosPorTile: { [number]: { number } } = {}
local techos: { ImageLabel } = {} -- labels de la capa 4 del último redibujo
local colorTecho = Ciudad.TechoMax
local ultimoTecho = os.clock()
-- Fase 18 (docs/37 §5.2): el color del día, que multiplica todo lo que se dibuja del mapa (Engine_Light del original)
local luz = Color3.new(1, 1, 1)

-- Fase 26 (docs/46 §9, pedido del autor): el árbol que tapa al personaje propio se vuelve translúcido, y solo ese
-- (los techos se aclaran todos juntos). El original lo hace con los Grh 735 y 6994 a 7002 (TileEngine.bas:779-786:
-- a menos de 2 columnas y hasta 4 filas por debajo del personaje); acá, con todos los árboles (los objetos "recurso"
-- 4 y 36 de ObjetosPiso, que se talan, y los de decorado de ARBOLES_DECORADO, que son solo un dibujo de la capa 3) y
-- una zona proporcional al tamaño del dibujo, con un fundido corto.
-- Los de decorado, mirados uno por uno en las hojas: los árboles gigantes de los bosques (18478-18481 y 18804), los
-- secos (12305, 12306, 12309, 12310, 12426 y 12703), el nevado (30684), los de colores (32469 a 32501) y el de la
-- casa del árbol (428).
local ARBOLES_DECORADO = { 428, 12305, 12306, 12309, 12310, 12426, 12703, 18478, 18479, 18480, 18481, 18804, 30684, 32469, 32471, 32473, 32474, 32475, 32501 }
local ARBOL_TRANSP = 0.55 -- transparencia del árbol que lo tapa
local ARBOL_VEL = 4 -- por segundo
type Arbol = { label: ImageLabel, i: number, x: number, y: number, dx: number, dy: number }
local grhArbol: { [number]: boolean } = {}
for _, o in ObjetosPiso :: any do
	if o.recurso == 4 or o.recurso == 36 then
		grhArbol[o.grh] = true
	end
end
for _, g in ARBOLES_DECORADO do
	grhArbol[g] = true
end
local arboles: { Arbol } = {} -- los de la capa 3 del último redibujo
local transpArbol: { [number]: number } = {} -- por tile: la transparencia de ahora (sobrevive a los redibujos)
local ultimoArbol = os.clock()

local lienzo: Part
local gui: SurfaceGui
local pool: { ImageLabel } = {}
local usados = 0

local cols, filas = 0, 0
local origenX, origenY = 1, 1
local centroTileX, centroTileY = -1, -1
local oyentes: { () -> () } = {}

-- ─── Coordenadas ─────────────────────────────────────────────────────────────
-- Píxel del lienzo donde empieza el tile (x, y)
function Mundo.pxDeTile(x: number, y: number): (number, number)
	return (x - origenX) * TILE_PX, (y - origenY) * TILE_PX
end

-- ZIndex del orden de pintor de AO. Offsets positivos porque se dibuja fuera del lienzo.
function Mundo.z(x: number, y: number, sub: number): number
	return 10 + ((y - origenY + EXTRA_ARRIBA + 1) * 128 + (x - origenX + EXTRA_LADOS + 1)) * 16 + sub
end

local Z_CAPA4 = 10 + 128 * 128 * 16

function Mundo.lienzoGui(): SurfaceGui
	return gui
end

-- Se llama cada vez que el lienzo cambia de origen (los sprites dinámicos se reubican)
function Mundo.alRedibujar(f: () -> ())
	table.insert(oyentes, f)
end

-- ─── Pool ────────────────────────────────────────────────────────────────────
local function tomar(): ImageLabel
	usados += 1
	local label = pool[usados]
	if not label then
		label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.Parent = gui
		pool[usados] = label
	end
	label.Visible = true
	return label
end

local function dibujar(g: number, x: number, y: number, z: number): boolean
	if g == 0 or not Grh.existe(g) then
		return false
	end
	local label = tomar()
	local px, py = Mundo.pxDeTile(x, y)
	Grh.aplicar(label, g)
	Grh.ubicar(label, g, px, py)
	label.ZIndex = z
	if Grh.frame(g, 2) ~= Grh.frame(g, 1) then
		Grh.animar(label, g, -1, nil, 0) -- reloj global: toda el agua en fase
	else
		Grh.detener(label)
	end
	label.ImageTransparency = 0
	label.ImageColor3 = luz
	return true
end

-- DesvanecimientoTechos (cliente TileEngine.bas:1913-1925): alfa y brillo iguales a ColorTecho
local function pintarTechos()
	local c = colorTecho
	local transp = if c >= Ciudad.TechoMax then 0 else 1 - c / 255
	local brillo = if c >= Ciudad.TechoMax then 1 else c / 255
	local color = Color3.new(luz.R * brillo, luz.G * brillo, luz.B * brillo)
	for _, l in techos do
		l.ImageTransparency = transp
		l.ImageColor3 = color
	end
end

-- ─── Redibujo ────────────────────────────────────────────────────────────────
local GRH_VACIO = 1 -- un tile de color 17, 17, 17 (docs/40 §7)
-- En tres mapas ese tile es además el piso por donde se camina (Laberinto Oscuro 162, Profundidades de la Pirámide
-- 306 y Veriil 142). Ahí se dibuja siempre, como el original: si se pintara de negro solo donde no se pisa, el
-- laberinto quedaría dibujado en el piso. Se decide al cargar el mapa, contando los tiles de ese gris que se pisan.
-- En los demás mapas hay unos pocos tiles de ese gris que se pisan (el 284 tiene 70, el 275 tiene 50...): esos se
-- dibujan, así nadie camina sobre el negro; el resto queda negro.
local PISO_GRIS_MIN = 100
local grisEsPiso = false

local function ubicarLienzo()
	local esquina = Grilla.esquinaMundo(origenX, origenY)
	-- Rotado -90° en Y: el ancho del SurfaceGui queda sobre +X del mundo y el alto sobre +Z
	lienzo.Size = Vector3.new(filas * TS, 0.2, cols * TS)
	lienzo.CFrame = CFrame.new(esquina + Vector3.new(cols * TS / 2, -0.1, filas * TS / 2)) * CFrame.Angles(0, -math.pi / 2, 0)
end

local function redibujar()
	usados = 0
	local x0, y0 = origenX, origenY
	local x1, y1 = origenX + cols - 1, origenY + filas - 1

	-- Pasada 1: piso
	for y = math.max(1, y0), math.min(Grilla.ALTO, y1) do
		for x = math.max(1, x0), math.min(Grilla.ANCHO, x1) do
			local i = Grilla.indice(x, y)
			local g1 = Grilla.piso(mapa, i)
			-- D21-27 A: el tile gris muy oscuro que decenas de mapas usan de vacío (Grh 1) no se dibuja donde no se pisa: queda
			-- el fondo negro
			if g1 ~= GRH_VACIO or grisEsPiso or not Grilla.estaBloqueado(mapa, x, y) then
				dibujar(g1, x, y, 1)
			end
			local g2 = mapa.capa2[i]
			if g2 then
				dibujar(g2, x, y, 2)
			end
		end
	end

	-- Pasadas 2 y 3: objetos, capa 3 y capa 4 (con margen para sprites que desbordan)
	table.clear(techos)
	table.clear(arboles)
	for y = math.max(1, y0 - EXTRA_ARRIBA), math.min(Grilla.ALTO, y1 + EXTRA_ABAJO) do
		for x = math.max(1, x0 - EXTRA_LADOS), math.min(Grilla.ANCHO, x1 + EXTRA_LADOS) do
			local i = Grilla.indice(x, y)
			local obj = objetosPorTile[i]
			if obj then
				dibujar(obj[5], x, y, Mundo.z(x, y, Mundo.SUB.objeto))
			end
			local g3 = mapa.capa3[i]
			if g3 and dibujar(g3, x, y, Mundo.z(x, y, Mundo.SUB.capa3)) and grhArbol[g3] then
				-- La zona en la que tapa a un personaje: el 30 % del ancho a cada lado y el 70 % del alto por debajo de él
				local w, h = Grh.tamano(g3)
				local a: Arbol = {
					label = pool[usados], i = i, x = x, y = y,
					dx = math.max(1, math.floor(w / TILE_PX * 0.3)), dy = math.max(1, math.floor(h / TILE_PX * 0.7)),
				}
				table.insert(arboles, a)
				local t = transpArbol[i]
				if t then
					a.label.ImageTransparency = t -- dibujar() la había vuelto a 0
				end
			end
			local g4 = mapa.capa4[i]
			if g4 and dibujar(g4, x, y, Z_CAPA4 + i) then
				table.insert(techos, pool[usados])
			end
		end
	end

	-- Sobrantes del pool: ocultos
	for k = usados + 1, #pool do
		local label = pool[k]
		if label.Visible then
			label.Visible = false
			Grh.detener(label)
		end
	end

	pintarTechos()
	ubicarLienzo()
	for _, f in oyentes do
		f()
	end
end

-- Tiles de la vista que tiene que cubrir el lienzo y el margen extra de cada lado (los fija el HUD; si no,
-- toda la pantalla con MARGEN). En PC la skin tapa los bordes; en celular se ven y hace falta más margen para
-- que no aparezcan tiles "en vivo" en los costados al caminar.
local vistaCols: number?, vistaFilas: number? = nil, nil
local margenX, margenY = MARGEN, MARGEN

local function calcularTamano()
	filas = (vistaFilas or Camara.VISTA_ALTO) + 2 * margenY
	cols = (vistaCols or math.ceil(Camara.VISTA_ALTO * Camara.aspecto())) + 2 * margenX
end

-- Tiles que se ven en pantalla (sin el margen): el chat de voz lo usa para "toda la pantalla" (docs/28 §11)
function Mundo.vista(): (number, number)
	return vistaCols or math.ceil(Camara.VISTA_ALTO * Camara.aspecto()), vistaFilas or Camara.VISTA_ALTO
end

function Mundo.setVista(c: number?, f: number?, mx: number?, my: number?)
	vistaCols, vistaFilas = c, f
	margenX, margenY = mx or MARGEN, my or MARGEN
	calcularTamano()
	centroTileX = -1 -- fuerza redibujo
end

-- ─── API ─────────────────────────────────────────────────────────────────────
-- El lienzo y su SurfaceGui (una sola vez, antes de escuchar eventos: los personajes se dibujan sobre él)
function Mundo.iniciar()
	if lienzo then
		return
	end
	lienzo = Instance.new("Part")
	lienzo.Name = "LienzoMundo"
	lienzo.Anchored = true
	lienzo.CanCollide = false
	lienzo.CanQuery = false
	lienzo.CastShadow = false
	lienzo.Color = Color3.new(0, 0, 0)
	lienzo.Material = Enum.Material.SmoothPlastic
	lienzo.TopSurface = Enum.SurfaceType.Smooth
	lienzo.Parent = workspace

	gui = Instance.new("SurfaceGui")
	gui.Name = "Mundo"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	gui.Adornee = lienzo
	-- Fase 21 (docs/40 §7): un fondo negro debajo de todo. Donde el mapa no dibuja nada (tiles sin piso de minas y
	-- dungeons, agujeros de los gráficos, fuera del mapa) se veía el lienzo, que es una pieza iluminada por el sol
	-- del lugar: gris. El SurfaceGui no recibe luz (LightInfluence 0), así que este negro es negro. El original
	-- limpia la pantalla a negro en cada cuadro (cli/Motor/mDx8_Engine.bas:304-315).
	local fondo = Instance.new("Frame")
	fondo.Name = "Fondo"
	fondo.BackgroundColor3 = Color3.new(0, 0, 0)
	fondo.BorderSizePixel = 0
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.ZIndex = 0
	fondo.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			calcularTamano()
			centroTileX = -1 -- fuerza redibujo
		end)
	end
	calcularTamano()
end

-- SwitchMap (cliente General.bas:420-571): el mapa nuevo, sin los objetos del anterior
function Mundo.cargar(numero: number)
	Mundo.iniciar()
	mapa = Mapas.cargar(numero)
	local pisables = 0
	for y = 1, Grilla.ALTO do
		for x = 1, Grilla.ANCHO do
			if Grilla.piso(mapa, Grilla.indice(x, y)) == GRH_VACIO and not Grilla.estaBloqueado(mapa, x, y) then
				pisables += 1
			end
		end
	end
	grisEsPiso = pisables >= PISO_GRIS_MIN
	objetosPorTile = {}
	for _, o in mapa.objetos do
		-- Fase 16a (docs/31 §2.2): árboles y yacimientos ya están en la capa 3; dibujarlos de nuevo los duplica
		local op = ObjetosPiso[o[1]]
		if not (op and op.recurso) then
			objetosPorTile[Grilla.indice(o[3], o[4])] = o
		end
	end
	-- Lo que estaba dinámico de una visita anterior (puertas) vuelve al .map; el servidor manda el estado actual
	for i in mapa.dinamico do
		local s = mapa.traslados[i]
		if not s or Mapas.abierto(s[1]) then
			mapa.dinamico[i] = nil
		end
	end
	colorTecho = Ciudad.TechoMax
	table.clear(transpArbol)
	calcularTamano()
	centroTileX, centroTileY = -1, -1
	print(`[Mundo] cliente: mapa {mapa.numero} "{mapa.nombre}" — lienzo {cols}×{filas} tiles`)
end

function Mundo.mapa(): any
	return mapa
end

-- Objeto del piso creado o borrado por el servidor (Fase 11, remote ObjetoPiso): grh 0 = vacío
function Mundo.objetoPiso(x: number, y: number, grh: number)
	local i = Grilla.indice(x, y)
	objetosPorTile[i] = if grh ~= 0 then { 0, 0, x, y, grh } else nil
	centroTileX = -1 -- se redibuja en el próximo cuadro
end

-- Una puerta se abrió o cerró (remote Puerta): la puerta ocupa (x, y) y (x - 1, y)
function Mundo.puerta(x: number, y: number, cerrada: boolean)
	if not mapa then
		return
	end
	mapa.dinamico[Grilla.indice(x, y)] = cerrada
	mapa.dinamico[Grilla.indice(x - 1, y)] = cerrada
end

-- Bloqueos de puertas que cambiaron antes de entrar: { ["índice"] = bloqueado }
function Mundo.puertasIniciales(t: { [string]: boolean })
	for k, v in t do
		local i = tonumber(k)
		if i and mapa then
			mapa.dinamico[i] = v
		end
	end
end

-- Los tiles que cambiaron antes de entrar (respuesta de Unirse): { ["índice"] = grh }
function Mundo.pisoInicial(t: { [string]: number })
	for k, grh in t do
		local i = tonumber(k)
		if i then
			local x, y = (i - 1) % Grilla.ANCHO + 1, (i - 1) // Grilla.ANCHO + 1
			objetosPorTile[i] = if grh ~= 0 then { 0, 0, x, y, grh } else nil
		end
	end
	centroTileX = -1
end

-- Centra la vista en una posición en tiles (puede ser fraccionaria durante un paso)
function Mundo.centrarEn(tx: number, ty: number)
	if not mapa then
		return
	end
	local cx, cy = math.floor(tx + 0.5), math.floor(ty + 0.5)
	-- Techos: el trigger del tile del personaje propio
	local ahora = os.clock()
	local pasos = math.floor((ahora - ultimoTecho) * 60)
	if pasos > 0 then
		ultimoTecho += pasos / 60
		local antes = colorTecho
		if Mapas.bajoTecho(mapa, cx, cy) then
			colorTecho = math.max(Ciudad.TechoMin, colorTecho - pasos)
		else
			colorTecho = math.min(Ciudad.TechoMax, colorTecho + pasos)
		end
		if colorTecho ~= antes then
			pintarTechos()
		end
	end

	if cx ~= centroTileX or cy ~= centroTileY then
		centroTileX, centroTileY = cx, cy
		origenX = cx - cols // 2
		origenY = cy - filas // 2
		redibujar()
	end
	-- Árboles (Fase 26): el que tapa al personaje propio se va haciendo translúcido; los demás vuelven a opacos
	local dt = math.min(ahora - ultimoArbol, 0.1)
	ultimoArbol = ahora
	for _, a in arboles do
		local d = a.y - cy
		local objetivo = if d >= 1 and d <= a.dy and math.abs(a.x - cx) <= a.dx then ARBOL_TRANSP else 0
		local t = transpArbol[a.i] or 0
		if t ~= objetivo then
			t = if t < objetivo then math.min(objetivo, t + ARBOL_VEL * dt) else math.max(objetivo, t - ARBOL_VEL * dt)
			transpArbol[a.i] = if t > 0 then t else nil
			a.label.ImageTransparency = t
		end
	end
	Camara.centrarEn(Grilla.centroMundo(tx, ty))
end

-- Fase 18: el color del día. Repinta lo que está dibujado; lo nuevo ya sale con ese color
function Mundo.setLuz(c: Color3)
	if c == luz then
		return
	end
	luz = c
	for k = 1, usados do
		pool[k].ImageColor3 = c
	end
	pintarTechos()
end

function Mundo.luz(): Color3
	return luz
end

-- Fase 18 (docs/37 §6): el Grh del objeto del piso en (x, y), o nil. Lo usa el sonido de la fogata
function Mundo.grhObjeto(x: number, y: number): number?
	if not Grilla.dentroDelMapa(x, y) then
		return nil
	end
	local o = objetosPorTile[Grilla.indice(x, y)]
	return if o then o[5] else nil
end

-- Fase 34 (docs/54 §3): el árbol o el yacimiento al que se le hizo click en (u, v), en casillas continuas, contando
-- todo su dibujo y no solo la casilla donde está parado. oficio: "Talar" o "Mineria". (yoX, yoY): el que trabaja;
-- alcance: Habilidades.DistanciaOficio. Devuelve la casilla del objeto, o nil si el click no cayó sobre ninguno.
function Mundo.recursoBajo(u: number, v: number, oficio: string, yoX: number, yoY: number, alcance: number): (number?, number?)
	local sirve = Recursos.DeOficio[oficio]
	if not sirve or not mapa then
		return nil, nil
	end
	local candidatos: { Recursos.Candidato } = {}
	-- (los árboles y yacimientos no están en objetosPorTile: se dibujan con la capa 3; se buscan en el mapa)
	for _, o in mapa.objetos do
		-- solo los que pueden tener el click encima: a lo sumo a una pantalla
		if math.abs(o[3] - u) <= 12 and math.abs(o[4] - v) <= 14 then
			local op = ObjetosPiso[o[1]]
			if op and op.recurso and sirve[op.recurso] and op.grh and Grh.existe(op.grh) then
				local w, h = Grh.tamano(op.grh)
				table.insert(candidatos, { x = o[3], y = o[4], w = w, h = h, alcance = Recursos.alcance(op.recurso, alcance) })
			end
		end
	end
	return Recursos.elegir(u, v, candidatos, TILE_PX, yoX, yoY)
end

function Mundo.cantidadSprites(): number
	return usados
end

return Mundo
