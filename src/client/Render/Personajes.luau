--!strict
--[[
	Personajes — dibuja los personajes compuestos (cuerpo, cabeza, casco, arma, escudo, nombre) en el
	mismo lienzo que el mapa, con el orden de pintor de AO (docs/09-graficos-y-animaciones.md §4).

	Cada personaje tiene una posición lógica (x, y), que es SIEMPRE el tile destino, y un
	desplazamiento de caminata que va de -32 px a 0 en MS_POR_PASO (MoveCharbyHead, TileEngine.bas:427-486).
	El orden de dibujado usa la posición lógica, igual que el cliente original.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local Fantasma = require(ReplicatedStorage.Shared.Jugador.Fantasma)
local MovConfig = require(ReplicatedStorage.Shared.Config.Movimiento)
local Transporte = require(ReplicatedStorage.Shared.Config.Transporte)
local CfgSupervivencia = require(ReplicatedStorage.Shared.Config.Supervivencia)
local Indices = require(ReplicatedStorage.Shared.Generado.Indices)
local Alineacion = require(game:GetService("ReplicatedStorage").Shared.Config.Alineacion)
local CfgDueno = require(game:GetService("ReplicatedStorage").Shared.Config.Dueno)
local CfgAdmin = require(game:GetService("ReplicatedStorage").Shared.Config.Admin)
local Grh = require(script.Parent.Grh)
local Mundo = require(script.Parent.Mundo)

local Personajes = {}

local TILE_PX = Grilla.TILE_PX
local OFFSET_HEAD = -34 -- Declares.bas:983
local VEL_CAMINAR = 0.5 -- Movement_Speed en CharRender
local SEG_PASO = MovConfig.MS_POR_PASO / 1000
local SEG_PASO_MONTADO = Transporte.MsPasoMontado / 1000

type Partes = {
	cuerpo: ImageLabel,
	cabeza: ImageLabel,
	casco: ImageLabel,
	arma: ImageLabel,
	escudo: ImageLabel,
	nombre: TextLabel,
}

export type Personaje = {
	id: number,
	nombre: string,
	apariencia: { cuerpo: number, cabeza: number, casco: number, arma: number, escudo: number },
	x: number,
	y: number,
	heading: number,
	-- Caminata en curso: de (desdeX, desdeY) a (x, y), empezó en t0
	caminando: boolean,
	desdeX: number,
	desdeY: number,
	t0: number,
	muerto: boolean,
	atacandoHasta: number, -- os.clock() en que termina la animación de ataque del arma
	fx: ImageLabel?,
	fxId: number,
	fxPersistente: number?, -- FX infinito (meditar): vuelve después de un FX temporal (DF7-11)
	dialogo: TextLabel?,
	dialogoHasta: number,
	dialogoT0: number,
	-- Fase 13 (docs/23): el estado (color del nombre), si es NPC y los puntitos de "escribiendo"
	estado: string?,
	atacable: boolean?, -- Fase 19 (docs/38 §5): le robó la criatura a otro; el nombre va en naranja
	npc: boolean,
	numero: number?, -- Fase 28 (docs/48 §2): el número de la criatura, si se la puede inspeccionar
	puntos: TextLabel?,
	-- Fase 14a (docs/27 §5): oculto o invisible; solo lo recibe el propio jugador, que se ve translúcido
	invisible: boolean,
	destello: boolean?, -- Fase 21 (docs/40 §5): un invisible que se ve solo por el destello (sin nombre)
	-- P7 (docs/34 §1.3): navega (el cuerpo es un barco). El propio lo usa para predecir el paso; nadie hace pasos.
	navegando: boolean,
	-- Montado camina a 167 ms por paso, cada personaje a su velocidad (docs/34 §4.2, DT16-10 A)
	montado: boolean,
	rapido: boolean, -- Fase 23 (docs/42 §9.2): con una montura del juego; el dragón de la tienda solo va a paso normal
	-- Fase 23 (docs/42 §2.3, D23-08 A): el clan (segunda línea del nombre) y la marca dorada de administrador
	clan: string?,
	admin: boolean,
	espectador: boolean, -- Fase 23 (docs/42 §2.3): un administrador en modo espectador; no bloquea el paso
	partes: Partes,
}

local personajes: { [number]: Personaje } = {}
local enMovimiento: { [Personaje]: true } = {}

-- ─── Grh de cada parte según el heading ──────────────────────────────────────
local function grhDe(pj: Personaje): (number, number, number, number, number)
	local a, h = pj.apariencia, pj.heading
	local cuerpo = Indices.cuerpos[a.cuerpo]
	local cabeza = Indices.cabezas[a.cabeza]
	local casco = a.casco ~= 0 and Indices.cascos[a.casco] or nil
	local arma = a.arma ~= 0 and Indices.armas[a.arma] or nil
	local escudo = a.escudo ~= 0 and Indices.escudos[a.escudo] or nil
	return cuerpo and cuerpo.walk[h] or 0,
		cabeza and cabeza[h] or 0,
		casco and casco[h] or 0,
		arma and arma[h] or 0,
		escudo and escudo[h] or 0
end

local function nuevoLabel(): ImageLabel
	local l = Instance.new("ImageLabel")
	l.BackgroundTransparency = 1
	l.ResampleMode = Enum.ResamplerMode.Pixelated
	l.Parent = Mundo.lienzoGui()
	return l
end

-- Lo que dura un paso de este personaje
local function segPaso(pj: Personaje): number
	return if pj.rapido then SEG_PASO_MONTADO else SEG_PASO
end

-- ─── Dibujo ──────────────────────────────────────────────────────────────────
-- Desplazamiento de caminata en px (negativo = todavía viene desde atrás)
local function desplazamiento(pj: Personaje, ahora: number): (number, number)
	if not pj.caminando then
		return 0, 0
	end
	local restante = 1 - math.clamp((ahora - pj.t0) / segPaso(pj), 0, 1)
	return (pj.desdeX - pj.x) * TILE_PX * restante, (pj.desdeY - pj.y) * TILE_PX * restante
end

local function ubicar(pj: Personaje, ahora: number)
	local p = pj.partes
	local bx, by = Mundo.pxDeTile(pj.x, pj.y)
	local dx, dy = desplazamiento(pj, ahora)
	bx += dx
	by += dy
	local gCuerpo, gCabeza, gCasco, gArma, gEscudo = grhDe(pj)
	local cuerpo = Indices.cuerpos[pj.apariencia.cuerpo]
	local hox, hoy = cuerpo.headOffset[1], cuerpo.headOffset[2]

	Grh.ubicar(p.cuerpo, gCuerpo, bx, by)
	Grh.ubicar(p.cabeza, gCabeza, bx + hox, by + hoy)
	if gCasco ~= 0 then
		Grh.ubicar(p.casco, gCasco, bx + hox + 1, by + hoy + OFFSET_HEAD)
	end
	Grh.ubicar(p.arma, gArma, bx, by)
	Grh.ubicar(p.escudo, gEscudo, bx, by)
	-- Nombre centrado debajo de los pies: (X+16, Y+30) en TileEngine.bas:1711
	p.nombre.Position = UDim2.fromOffset(bx + 16 - p.nombre.Size.X.Offset / 2, by + 30)

	local x, y, S = pj.x, pj.y, Mundo.SUB
	p.cuerpo.ZIndex = Mundo.z(x, y, S.cuerpo)
	p.cabeza.ZIndex = Mundo.z(x, y, S.cabeza)
	p.casco.ZIndex = Mundo.z(x, y, S.casco)
	p.arma.ZIndex = Mundo.z(x, y, S.arma)
	p.escudo.ZIndex = Mundo.z(x, y, S.escudo)
	p.nombre.ZIndex = Mundo.z(x, y, S.nombre)
	if pj.fx then
		local f = Indices.fx[pj.fxId]
		Grh.ubicar(pj.fx, f.grh, bx + f.offsetX, by + f.offsetY)
		pj.fx.ZIndex = Mundo.z(x, y, S.fx)
	end
end

-- Fase 18 (docs/37 §5.2): el color del día multiplica el dibujo de los personajes (no los nombres ni los textos)
local luz = Color3.new(1, 1, 1)
local CELESTE = Color3.fromRGB(150, 200, 255)
local function tenir(pj: Personaje)
	local p = pj.partes
	-- Muerto: celeste (TileEngine.bas:1333-1347)
	local c = if pj.muerto then Color3.new(CELESTE.R * luz.R, CELESTE.G * luz.G, CELESTE.B * luz.B) else luz
	p.cuerpo.ImageColor3 = c
	p.cabeza.ImageColor3 = c
	p.casco.ImageColor3 = luz
	p.arma.ImageColor3 = luz
	p.escudo.ImageColor3 = luz
end

-- Fase 21 (docs/40 §5): el destello de un invisible aparece y se va de a poco
local TRANSP_DESTELLO = 0.75
local FUNDIDO_SEG = 0.3
local function fundir(partes: { ImageLabel }, hasta: number, alTerminar: (() -> ())?)
	local info = TweenInfo.new(FUNDIDO_SEG, Enum.EasingStyle.Linear)
	for _, label in partes do
		if label.Image ~= "" then
			TweenService:Create(label, info, { ImageTransparency = hasta }):Play()
		end
	end
	if alTerminar then
		task.delay(FUNDIDO_SEG, alTerminar)
	end
end

-- Aplica las imágenes según heading y si camina (cuerpo, arma y escudo se animan; quieto = frame 1)
local function vestir(pj: Personaje)
	local p = pj.partes
	local gCuerpo, gCabeza, gCasco, gArma, gEscudo = grhDe(pj)
	local atacando = os.clock() < pj.atacandoHasta
	for _, par in { { p.cuerpo, gCuerpo }, { p.arma, gArma }, { p.escudo, gEscudo } } do
		local label, g = par[1] :: ImageLabel, par[2] :: number
		label.Visible = g ~= 0
		if g ~= 0 and not (atacando and label == p.arma) then
			if pj.caminando then
				Grh.animar(label, g, -1, nil, pj.t0, VEL_CAMINAR)
			else
				Grh.detener(label)
				Grh.aplicar(label, g, 1)
			end
		end
	end
	p.cabeza.Visible = gCabeza ~= 0
	if gCabeza ~= 0 then
		Grh.aplicar(p.cabeza, gCabeza)
	end
	p.casco.Visible = gCasco ~= 0
	if gCasco ~= 0 then
		Grh.aplicar(p.casco, gCasco)
	end
	-- Muerto: translúcido y celeste (TileEngine.bas:1333-1347, alfa 100)
	for _, label in { p.cuerpo, p.cabeza } do
		label.ImageTransparency = if pj.muerto then 1 - 100 / 255 else 0
	end
	tenir(pj)
	-- Oculto o invisible: el propio personaje se ve translúcido (TileEngine.bas:1416-1450; docs/27 §5)
	if pj.invisible and not pj.muerto then
		-- Fase 21 (docs/40 §5): el que se ve solo por el destello, más tenue que un compañero de clan
		local t = if (pj :: any).destello then TRANSP_DESTELLO else 0.6
		for _, label in { p.cuerpo, p.cabeza, p.casco, p.arma, p.escudo } do
			label.ImageTransparency = t
		end
	elseif not pj.muerto then
		for _, label in { p.casco, p.arma, p.escudo } do
			label.ImageTransparency = 0
		end
	end
end

-- Color del nombre (RenderName, TileEngine.bas:1679-1718; docs/23 DN-01 A)
local function colorNombre(pj: Personaje): Color3
	if pj.muerto then
		return Alineacion.ColorMuerto
	end
	if pj.npc then
		return Alineacion.ColorNpc
	end
	-- Fase 19 (docs/38 §5, DC19-11 A): el atacable, en naranja (el original solo lo pinta en la consola)
	if pj.atacable then
		return CfgDueno.ColorAtacable
	end
	return Alineacion.Colores[pj.estado or ""] or Alineacion.Colores[Alineacion.PorDefecto]
end

-- El texto bajo el personaje: el nombre, el clan en una segunda línea (TileEngine.bas:1711-1715) y, si la tiene
-- prendida, la marca dorada de administrador (Fase 23, docs/42 §2.3). La marca va con RichText para tener su color:
-- ahí el nombre y el clan se escapan (el clan va entre "<" y ">").
local function escapar(t: string): string
	return (string.gsub(string.gsub(string.gsub(t, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end
local MARCA = string.format('\n<font color="#%s">%s</font>', CfgAdmin.MarcaColor:ToHex(), CfgAdmin.MarcaTexto)

local function ponerNombre(pj: Personaje)
	local l = pj.partes.nombre
	local t = if pj.clan then `{pj.nombre}\n<{pj.clan}>` else pj.nombre
	if pj.admin then
		l.RichText = true
		l.Text = escapar(t) .. MARCA
		l.Size = UDim2.fromOffset(160, 46)
	else
		l.RichText = false
		l.Text = t
		l.Size = UDim2.fromOffset(160, 30)
	end
end

-- ─── API ─────────────────────────────────────────────────────────────────────
function Personajes.crear(id: number, datos: any): Personaje
	Personajes.quitar(id)
	local nombre = Instance.new("TextLabel")
	nombre.BackgroundTransparency = 1
	nombre.Size = UDim2.fromOffset(160, 30)
	nombre.TextYAlignment = Enum.TextYAlignment.Top
	nombre.Font = Enum.Font.SourceSansBold
	nombre.TextSize = 14
	nombre.TextColor3 = Color3.new(1, 1, 1)
	nombre.TextStrokeTransparency = 0.3
	nombre.Parent = Mundo.lienzoGui()

	local pj: Personaje = {
		id = id,
		nombre = datos.nombre,
		apariencia = datos.apariencia,
		x = datos.x,
		y = datos.y,
		heading = datos.heading,
		caminando = false,
		desdeX = datos.x,
		desdeY = datos.y,
		t0 = 0,
		muerto = datos.muerto == true,
		atacandoHasta = 0,
		fx = nil,
		fxId = 0,
		fxPersistente = nil,
		dialogo = nil,
		dialogoHasta = 0,
		dialogoT0 = 0,
		estado = datos.estado,
		atacable = datos.atacable == true,
		npc = datos.npc == true,
		numero = if typeof(datos.numero) == "number" then datos.numero else nil,
		puntos = nil,
		invisible = datos.invisible == true,
		destello = datos.destello == true,
		navegando = datos.navegando == true,
		montado = datos.montado == true,
		rapido = datos.rapido == true,
		clan = if typeof(datos.clan) == "string" then datos.clan else nil,
		admin = datos.admin == true,
		espectador = datos.espectador == true,
		partes = {
			cuerpo = nuevoLabel(),
			cabeza = nuevoLabel(),
			casco = nuevoLabel(),
			arma = nuevoLabel(),
			escudo = nuevoLabel(),
			nombre = nombre,
		},
	}
	personajes[id] = pj
	ponerNombre(pj)
	nombre.TextColor3 = colorNombre(pj)
	nombre.Visible = not datos.sinNombre
	vestir(pj)
	if datos.destello then
		-- aparece de a poco
		local p = pj.partes :: any
		local partes = { p.cuerpo, p.cabeza, p.casco, p.arma, p.escudo }
		for _, label in partes do
			label.ImageTransparency = 1
		end
		fundir(partes, TRANSP_DESTELLO)
	end
	ubicar(pj, os.clock())
	if datos.fx then
		Personajes.fx(id, datos.fx, -1)
	end
	return pj
end

-- Los del destello que se están desvaneciendo: ya no existen para el juego, pero sus dibujos siguen hasta que termina
-- el fundido y hay que reubicarlos si el lienzo cambia de origen
local yendose: { [Personaje]: boolean } = {}

local function destruirPartes(pj: Personaje)
	yendose[pj] = nil
	for _, parte in pj.partes :: any do
		Grh.detener(parte)
		parte:Destroy()
	end
end

function Personajes.quitar(id: number, sinFundido: boolean?)
	local pj = personajes[id]
	if not pj then
		return
	end
	personajes[id] = nil
	enMovimiento[pj] = nil
	if (pj :: any).destello and not sinFundido then
		-- Fase 21 (docs/40 §5): el destello se va de a poco
		local p = pj.partes :: any
		p.nombre.Visible = false
		local partes = { p.cuerpo, p.cabeza, p.casco, p.arma, p.escudo }
		for _, parte in partes do
			Grh.detener(parte)
		end
		yendose[pj] = true
		fundir(partes, 1, function()
			if yendose[pj] then
				destruirPartes(pj)
			end
		end)
	else
		for _, parte in pj.partes :: any do
			Grh.detener(parte)
			parte:Destroy()
		end
	end
	if pj.fx then
		Grh.detener(pj.fx)
		pj.fx:Destroy()
		pj.fx = nil -- (el que se desvanece se sigue reubicando)
	end
	if pj.dialogo then
		pj.dialogo:Destroy()
		pj.dialogo = nil
	end
	if pj.puntos then
		pj.puntos:Destroy()
		pj.puntos = nil
	end
end

function Personajes.de(id: number): Personaje?
	return personajes[id]
end

function Personajes.todos(): { [number]: Personaje }
	return personajes
end

-- Fase 18 (docs/37 §5.2): el color del día
function Personajes.setLuz(c: Color3)
	if c == luz then
		return
	end
	luz = c
	for _, pj in personajes do
		tenir(pj)
	end
end

-- Hay algún personaje parado (o llegando) en ese tile
-- Fase 23 (docs/42 §2.3, D23-05 A): un espectador no ocupa lugar, y si el que camina (excepto) es espectador, pasa
-- por donde hay otros.
function Personajes.ocupado(x: number, y: number, excepto: number?): boolean
	local yo = if excepto then personajes[excepto] else nil
	if yo and yo.espectador then
		return false
	end
	for id, pj in personajes do
		if id ~= excepto and not pj.espectador and pj.x == x and pj.y == y then
			return true
		end
	end
	return false
end

-- ¿Hay alguien en ese tile que no deja pasar a `excepto`? Como `ocupado`, salvo que el fantasma de otro jugador no
-- frena al vivo: se corre a la casilla de donde viene (Fase 34, docs/54 §2; la misma regla que el servidor)
function Personajes.bloquea(x: number, y: number, excepto: number): boolean
	local yo = personajes[excepto]
	if yo and yo.espectador then
		return false
	end
	for id, pj in personajes do
		if id ~= excepto and not pj.espectador and pj.x == x and pj.y == y then
			if not yo or not Fantasma.seCorre(yo, pj) then
				return true
			end
		end
	end
	return false
end

-- Cada paso de un personaje vivo (id, x, y del tile de antes): los pasos que suenan (docs/29 §3.2; lo pone Main)
Personajes.alCaminar = nil :: ((number, number, number) -> ())?

-- Empieza un paso: la posición lógica pasa ya al destino (como MoveCharbyHead).
-- t0 opcional: para encadenar pasos sin saltos, el siguiente arranca justo cuando termina el anterior.
function Personajes.caminar(id: number, x: number, y: number, heading: number, t0: number?)
	local pj = personajes[id]
	if not pj then
		return
	end
	local seguia = pj.caminando
	local f = Personajes.alCaminar
	if f and not pj.muerto and not pj.navegando then
		f(id, pj.x, pj.y) -- en la posición previa al paso (cli/Red/Protocol.bas:2796-2809)
	end
	pj.desdeX, pj.desdeY = pj.x, pj.y
	pj.x, pj.y = x, y
	local cambioHeading = pj.heading ~= heading
	pj.heading = heading
	pj.caminando = true
	local ahora = os.clock()
	pj.t0 = t0 or ahora
	enMovimiento[pj] = true
	-- Si ya venía caminando en la misma dirección, la animación sigue sin reiniciarse
	if not seguia or cambioHeading then
		vestir(pj)
	end
	ubicar(pj, ahora)
end

-- Salto instantáneo (corrección del servidor o teletransporte)
function Personajes.teletransportar(id: number, x: number, y: number, heading: number)
	local pj = personajes[id]
	if not pj then
		return
	end
	pj.x, pj.y, pj.desdeX, pj.desdeY = x, y, x, y
	pj.heading = heading
	pj.caminando = false
	enMovimiento[pj] = nil
	vestir(pj)
	ubicar(pj, os.clock())
end

function Personajes.girar(id: number, heading: number)
	local pj = personajes[id]
	if not pj or pj.heading == heading then
		return
	end
	pj.heading = heading
	vestir(pj)
	ubicar(pj, os.clock())
end

-- Progreso del paso actual (1 = terminado) y posición visual en tiles, para la cámara
function Personajes.posicionVisual(id: number): (number, number)
	local pj = personajes[id]
	if not pj then
		return 0, 0
	end
	local dx, dy = desplazamiento(pj, os.clock())
	return pj.x + dx / TILE_PX, pj.y + dy / TILE_PX
end

-- Hitbox del click (DF11-02 C, docs/20 §3.2): el personaje dibujado bajo un punto del mapa. (u, v) en tiles
-- continuos: el tile (x, y) va de u = x a x + 1 y de v = y a y + 1. La caja es 1 tile de ancho por 2 de alto sobre
-- los pies, en la posición visual (con la caminata), más ¼ de tile por lado. Si hay varios, gana el que se dibuja
-- adelante (pies más abajo) y, a igual altura, el más cercano en horizontal. Devuelve el id y su tile lógico.
local MARGEN_CLICK = 0.25
-- excepto: uno que no cuenta (uno mismo, al tirar con el arco: su dibujo tapa al que tiene pegado arriba; Fase 34)
function Personajes.bajoElMouse(u: number, v: number, excepto: number?): (number?, number?, number?)
	local ahora = os.clock()
	local mejor: Personaje? = nil
	local mejorV, mejorDx = -math.huge, math.huge
	for id, pj in personajes do
		if id == excepto then
			continue
		end
		local dx, dy = desplazamiento(pj, ahora)
		local vx, vy = pj.x + dx / TILE_PX, pj.y + dy / TILE_PX
		if u >= vx - MARGEN_CLICK and u < vx + 1 + MARGEN_CLICK and v >= vy - 1 - MARGEN_CLICK and v < vy + 1 + MARGEN_CLICK then
			local ddx = math.abs(u - (vx + 0.5))
			if vy > mejorV or (vy == mejorV and ddx < mejorDx) then
				mejor, mejorV, mejorDx = pj, vy, ddx
			end
		end
	end
	if mejor then
		return mejor.id, mejor.x, mejor.y
	end
	return nil, nil, nil
end

function Personajes.finDelPaso(id: number): number
	local pj = personajes[id]
	return if pj then pj.t0 + segPaso(pj) else 0
end

function Personajes.pasoTerminado(id: number): boolean
	local pj = personajes[id]
	return not pj or not pj.caminando or os.clock() - pj.t0 >= segPaso(pj)
end

-- Animación de ataque: el arma arranca en el frame 1 y se corta pasado el frame 4 (TileEngine.bas:1261-1270)
function Personajes.atacar(id: number)
	local pj = personajes[id]
	if not pj or pj.muerto then
		return
	end
	local _, _, _, gArma = grhDe(pj)
	if gArma == 0 then
		return
	end
	local duracion = 4 * Grh.msPorFrame(gArma) / VEL_CAMINAR / 1000
	pj.atacandoHasta = os.clock() + duracion
	Grh.animar(pj.partes.arma, gArma, -1, nil, os.clock(), VEL_CAMINAR)
	task.delay(duracion, function()
		if personajes[id] == pj and os.clock() >= pj.atacandoHasta then
			vestir(pj)
		end
	end)
end

-- Oculto o invisible (docs/27 §5): solo le llega al dueño
function Personajes.setInvisible(id: number, si: boolean)
	local pj = personajes[id]
	if pj then
		pj.invisible = si
		vestir(pj)
	end
end

-- ─── Proyectiles (Fase 14a, docs/27 §2) ──────────────────────────────────────
-- Engine_Projectile_Create (cliente mDx8_Projectile.bas): la flecha (el ícono de la munición) o la Cuchilla viaja
-- del que dispara al blanco a 0,8 px/ms (~25 tiles/s), girada hacia él. El daño ya se aplicó en el servidor: el
-- número espera a que llegue (Personajes.esperaProyectil).
type Proyectil = { label: ImageLabel, desde: number, hasta: number, t0: number, dur: number, ox: number, oy: number }
local proyectiles: { Proyectil } = {}
local VEL_PROYECTIL = 0.8 * 1000 -- px por segundo
local Z_PROYECTIL = 9 + 128 * 128 * 16 * 2

local function centroPx(pj: Personaje, ahora: number): (number, number)
	local bx, by = Mundo.pxDeTile(pj.x, pj.y)
	local dx, dy = desplazamiento(pj, ahora)
	return bx + dx + TILE_PX / 2, by + dy - TILE_PX / 2
end

function Personajes.proyectil(desde: number, hasta: number, grh: number)
	local a, b = personajes[desde], personajes[hasta]
	if not a or not b or not Grh.existe(grh) then
		return
	end
	local ahora = os.clock()
	local ax, ay = centroPx(a, ahora)
	local bx, by = centroPx(b, ahora)
	local dist = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
	local label = nuevoLabel()
	Grh.aplicar(label, grh)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = Z_PROYECTIL
	label.Rotation = math.deg(math.atan2(by - ay, bx - ax)) + 45 -- el ícono apunta al noreste
	label.Position = UDim2.fromOffset(ax, ay)
	table.insert(proyectiles, { label = label, desde = desde, hasta = hasta, t0 = ahora, dur = dist / VEL_PROYECTIL, ox = ax, oy = ay })
end

-- Cuánto falta (s) para que llegue un proyectil a ese personaje (0 si no hay ninguno en camino)
function Personajes.esperaProyectil(id: number): number
	local ahora = os.clock()
	local espera = 0
	for _, p in proyectiles do
		if p.hasta == id then
			espera = math.max(espera, p.t0 + p.dur - ahora)
		end
	end
	return espera
end

local function moverProyectiles(ahora: number)
	for i = #proyectiles, 1, -1 do
		local p = proyectiles[i]
		local b = personajes[p.hasta]
		local t = if p.dur > 0 then (ahora - p.t0) / p.dur else 1
		if t >= 1 or not b then
			p.label:Destroy()
			table.remove(proyectiles, i)
		else
			local bx, by = centroPx(b, ahora)
			p.label.Position = UDim2.fromOffset(p.ox + (bx - p.ox) * t, p.oy + (by - p.oy) * t)
			p.label.Rotation = math.deg(math.atan2(by - p.oy, bx - p.ox)) + 45
		end
	end
end

-- Cambio de apariencia o estado (muerte, resurrección)
function Personajes.cambiar(id: number, datos: any)
	local pj = personajes[id]
	if not pj then
		return
	end
	if datos.apariencia then
		pj.apariencia = datos.apariencia
	end
	if datos.muerto ~= nil then
		pj.muerto = datos.muerto
	end
	if datos.estado ~= nil then
		pj.estado = datos.estado
	end
	if datos.atacable ~= nil then
		pj.atacable = datos.atacable == true
	end
	if datos.navegando ~= nil then
		pj.navegando = datos.navegando == true
	end
	if datos.montado ~= nil then
		pj.montado = datos.montado == true
	end
	if datos.rapido ~= nil then
		pj.rapido = datos.rapido == true
	end
	if datos.espectador ~= nil then
		pj.espectador = datos.espectador == true
	end
	if datos.sinNombre ~= nil then -- mimetizado: no se le ve el nombre (correcciones de la 14b)
		pj.partes.nombre.Visible = not datos.sinNombre
	end
	-- Fase 15b (docs/28 §3.1): el clan en una segunda línea, del mismo color (TileEngine.bas:1711-1715); false = sin clan
	if datos.clan ~= nil or datos.admin ~= nil then
		if datos.clan ~= nil then
			pj.clan = if typeof(datos.clan) == "string" then datos.clan else nil
		end
		if datos.admin ~= nil then
			pj.admin = datos.admin == true
		end
		ponerNombre(pj)
	end
	pj.partes.nombre.TextColor3 = colorNombre(pj)
	vestir(pj)
	ubicar(pj, os.clock())
end

-- FX sobre el personaje (sangre, hechizos, meditar). Un solo FX a la vez, como SetCharacterFx.
-- vueltas: se reproduce vueltas+1 veces (loops de AO); -1 = infinito (queda como FX persistente).
-- fxId 0 = apagar el FX persistente (dejar de meditar).
local function ponerFx(pj: Personaje, fxId: number, vueltas: number)
	if pj.fx then
		Grh.detener(pj.fx)
		pj.fx:Destroy()
		pj.fx = nil
	end
	local f = Indices.fx[fxId]
	if not f or not Grh.existe(f.grh) then
		return
	end
	local label = nuevoLabel()
	pj.fx, pj.fxId = label, fxId
	Grh.aplicar(label, f.grh)
	ubicar(pj, os.clock())
	Grh.animar(label, f.grh, vueltas, function()
		if pj.fx == label then
			pj.fx = nil
			-- Terminó un FX temporal: vuelve el persistente (el de meditar) si sigue activo
			if pj.fxPersistente and personajes[pj.id] == pj then
				ponerFx(pj, pj.fxPersistente, -1)
			end
		end
		label:Destroy()
	end)
end

function Personajes.fx(id: number, fxId: number, vueltas: number)
	local pj = personajes[id]
	if not pj then
		return
	end
	if fxId == 0 then
		-- Apagar el persistente. Si en este momento se ve un FX temporal, se deja terminar solo.
		local mostrandoPersistente = pj.fx ~= nil and pj.fxPersistente ~= nil and pj.fxId == pj.fxPersistente
		pj.fxPersistente = nil
		if mostrandoPersistente then
			ponerFx(pj, 0, 0)
		end
		return
	end
	if vueltas < 0 then
		pj.fxPersistente = fxId
	end
	ponerFx(pj, fxId, vueltas)
end

-- Diálogo sobre la cabeza (palabras mágicas): uno por personaje, 18 caracteres por línea cortando por
-- palabra, 5000 ms + 100 ms por carácter, entra subiendo 12 px (clsDialogs.cls, docs/10 §6.4)
local MAX_LINEA = 18
local function partirEnLineas(texto: string): { string }
	local lineas, actual = {}, ""
	for palabra in string.gmatch(texto, "%S+") do
		if actual == "" then
			actual = palabra
		elseif #actual + 1 + #palabra <= MAX_LINEA then
			actual ..= " " .. palabra
		else
			table.insert(lineas, actual)
			actual = palabra
		end
	end
	if actual ~= "" then
		table.insert(lineas, actual)
	end
	return lineas
end

local Z_DIALOGOS = 10 + 128 * 128 * 16 * 2 - 1
local function nuevoDialogo(texto: string, color: Color3): TextLabel
	local lineas = partirEnLineas(texto)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(180, 14 * #lineas)
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 14
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.TextYAlignment = Enum.TextYAlignment.Bottom
	l.Text = table.concat(lineas, "\n")
	l.ZIndex = Z_DIALOGOS
	l.Parent = Mundo.lienzoGui()
	return l
end

-- Altura del globo (correcciones de la 14b): la del cliente clásico, UpdateDialogPos (clsDialogs.cls:286-306) con la
-- cabeza del cuerpo y OFFSET_HEAD (TileEngine.bas:1457): la primera línea arranca en Y + HeadOffset.Y − 34 y cada
-- línea de más sube 3 px. Antes el globo quedaba unos 30 px más arriba.
local function yDialogo(by: number, hoy: number, l: TextLabel): number
	local lineas = math.max(1, math.floor(l.Size.Y.Offset / 14 + 0.5))
	return by + hoy + OFFSET_HEAD + 14 - (lineas - 1) * 3 - l.Size.Y.Offset
end

-- Fase 14b (docs/27 §12.9): las palabras mágicas de un invisible, sobre su tile (el personaje no llega)
type DialogoTile = { label: TextLabel, x: number, y: number, t0: number, hasta: number }
local dialogosTile: { DialogoTile } = {}
function Personajes.dialogoEnTile(x: number, y: number, texto: string, color: Color3)
	for i = #dialogosTile, 1, -1 do -- uno por tile, como uno por personaje
		local t = dialogosTile[i]
		if t.x == x and t.y == y then
			t.label:Destroy()
			table.remove(dialogosTile, i)
		end
	end
	local ahora = os.clock()
	table.insert(dialogosTile, { label = nuevoDialogo(texto, color), x = x, y = y, t0 = ahora, hasta = ahora + (5000 + 100 * #texto) / 1000 })
end

-- "Cartelear" (correcciones de la 14b): le saca el globo a ese personaje
function Personajes.borrarDialogo(id: number)
	local pj = personajes[id]
	if pj and pj.dialogo then
		pj.dialogo:Destroy()
		pj.dialogo = nil
	end
end

function Personajes.dialogo(id: number, texto: string, color: Color3)
	local pj = personajes[id]
	if not pj then
		return
	end
	if pj.dialogo then
		pj.dialogo:Destroy()
	end
	local lineas = partirEnLineas(texto)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(180, 14 * #lineas)
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 14
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.TextYAlignment = Enum.TextYAlignment.Bottom
	l.Text = table.concat(lineas, "\n")
	l.ZIndex = Z_DIALOGOS
	l.Parent = Mundo.lienzoGui()
	pj.dialogo = l
	pj.dialogoT0 = os.clock()
	pj.dialogoHasta = os.clock() + (5000 + 100 * #texto) / 1000
end

-- El color con que se escribe su nombre en la consola (el mismo del nombre)
function Personajes.colorDeEstado(estado: string): Color3
	if estado == "muerto" then
		return Alineacion.ColorMuerto
	end
	if estado == "atacable" then -- Fase 19 (docs/38 §5)
		return CfgDueno.ColorAtacable
	end
	return Alineacion.Colores[estado] or Alineacion.Colores.ciudadano
end

-- Puntitos de "escribiendo" sobre la cabeza (cliente TileEngine.bas:1498-1510)
function Personajes.escribiendo(id: number, si: boolean)
	local pj = personajes[id]
	if not pj then
		return
	end
	if not si then
		if pj.puntos then
			pj.puntos:Destroy()
			pj.puntos = nil
		end
		return
	end
	if pj.puntos then
		return
	end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(40, 14)
	l.Font = Enum.Font.SourceSansBold
	l.TextSize = 18
	l.TextColor3 = Color3.fromRGB(220, 220, 255)
	l.TextStrokeTransparency = 0.4
	l.Text = "..."
	l.ZIndex = Z_DIALOGOS
	l.Parent = Mundo.lienzoGui()
	pj.puntos = l
end

-- FX en el piso, sin personaje (PrepareMessageFXtoMap: el hechizo que mata a un NPC, docs/16 §6.1)
type FxPiso = { label: ImageLabel, x: number, y: number, fx: number }
local fxPiso: { [FxPiso]: true } = {}

local function ubicarFxPiso(f: FxPiso)
	local d = Indices.fx[f.fx]
	local bx, by = Mundo.pxDeTile(f.x, f.y)
	Grh.ubicar(f.label, d.grh, bx + d.offsetX, by + d.offsetY)
	f.label.ZIndex = Mundo.z(f.x, f.y, Mundo.SUB.fx)
end

function Personajes.fxEnTile(x: number, y: number, fxId: number, vueltas: number)
	local d = Indices.fx[fxId]
	if not d or not Grh.existe(d.grh) then
		return
	end
	local f: FxPiso = { label = nuevoLabel(), x = x, y = y, fx = fxId }
	fxPiso[f] = true
	Grh.aplicar(f.label, d.grh)
	ubicarFxPiso(f)
	Grh.animar(f.label, d.grh, math.max(vueltas, 0), function()
		fxPiso[f] = nil
		f.label:Destroy()
	end)
end

-- Char_CleanAll (cliente General.bas:445-448): al cambiar de mapa se borran todos (y los FX del piso)
-- Los dibujos de las barras de parálisis se van con el mapa; los datos quedan (la lista del mapa nuevo puede haber
-- llegado antes) y se vuelven a dibujar solos. Se define más abajo, con las barras.
Personajes.soltarBarras = function() end

function Personajes.limpiar()
	for id in personajes do
		Personajes.quitar(id, true) -- al cambiar de mapa, sin fundido
	end
	for pj in yendose do
		destruirPartes(pj)
	end
	for f in fxPiso do
		Grh.detener(f.label)
		f.label:Destroy()
	end
	table.clear(fxPiso)
	for _, t in dialogosTile do
		t.label:Destroy()
	end
	table.clear(dialogosTile)
	Personajes.soltarBarras()
end

-- Número flotante de daño: sube 20 px con ease-out cúbico durante 1 s (Damage_Create, docs/10 §5).
-- Si el personaje desaparece (un NPC que muere) el número termina en el último lugar donde estaba.
type Numero = { label: TextLabel, id: number, t0: number, px: number?, py: number? }
local numeros: { Numero } = {}
local Z_NUMEROS = 10 + 128 * 128 * 16 * 2

-- espera (s): Fase 14a, el número de una flecha sale cuando llega (docs/27 §2.2); mientras tanto sigue al personaje
-- sin verse, así aunque la criatura muera y desaparezca antes el número queda en su lugar
function Personajes.numero(id: number, valor: number, color: Color3, tipo: string?, espera: number?)
	local pj = personajes[id]
	if not pj or (valor == 0 and tipo ~= "curar" and tipo ~= "trabajo") then
		return -- un daño 0 no se dibuja (Damage_Draw, docs/14 §3.2)
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(80, 16)
	label.Font = Enum.Font.SourceSansBold
	label.TextSize = 16
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = if valor < 0 then "Fallo" elseif tipo == "curar" or tipo == "trabajo" then `+{valor}` else `-{valor}`
	label.ZIndex = Z_NUMEROS
	label.Visible = not espera or espera <= 0
	label.Parent = Mundo.lienzoGui()
	table.insert(numeros, { label = label, id = id, t0 = os.clock() + math.max(0, espera or 0) })
end

-- ─── La barra de parálisis (Fase 28, docs/48 §5) ─────────────────────────────
-- Con 87 de Supervivencia el servidor manda lo que les queda a los paralizados e inmovilizados del mapa (jugadores y
-- criaturas). Debajo de cada uno va una barra que se vacía, con los segundos al lado. Los datos se guardan por id,
-- exista o no el dibujo del personaje (la lista puede llegar antes que él al cambiar de mapa).
type Barra = { hasta: number, total: number, inm: boolean, marco: Frame?, relleno: Frame?, texto: TextLabel? }
local barras: { [number]: Barra } = {}
local BARRA_ANCHO, BARRA_ALTO = CfgSupervivencia.BarraAncho, 5
local COLOR_PARALISIS = Color3.fromRGB(120, 205, 255)
local COLOR_INMOVIL = Color3.fromRGB(255, 190, 80)

local function sacarBarra(id: number)
	local b = barras[id]
	if b then
		if b.marco then
			b.marco:Destroy()
		end
		barras[id] = nil
	end
end

-- lista: { { id, segundos, inmovilizado } }, todos los del mapa; el que no viene, se soltó
function Personajes.tiemposParalisis(lista: any)
	if typeof(lista) ~= "table" then
		return
	end
	local ahora = os.clock()
	local estan: { [number]: boolean } = {}
	for _, x in lista do
		local id, seg, inm = x[1], x[2], x[3] == true
		if typeof(id) == "number" and typeof(seg) == "number" and seg > 0 then
			estan[id] = true
			local hasta = ahora + seg
			local b = barras[id]
			if not b then
				barras[id] = { hasta = hasta, total = seg, inm = inm }
			elseif b.inm ~= inm or math.abs(b.hasta - hasta) > CfgSupervivencia.ParalisisTolerancia then
				-- renovada (queda más que antes): la barra vuelve a llena; acortada: baja de golpe
				b.total = if hasta > b.hasta or b.inm ~= inm then seg else b.total
				b.hasta = hasta
				b.inm = inm
			end
		end
	end
	for id in barras do
		if not estan[id] then
			sacarBarra(id)
		end
	end
end

-- ─── La barra de vida (Fase 28, docs/48 §5.2) ────────────────────────────────
-- Con 100 de Supervivencia el servidor manda la vida de las criaturas y de los demás jugadores del mapa, en pasos de
-- la barra (de 1 a BarraAncho). Va debajo del nombre; la de parálisis, si la tiene, debajo de esta.
type Vida = { pasos: number, marco: Frame?, relleno: Frame?, hecho: number?, x: number?, y: number?, z: number? }
local vidas: { [number]: Vida } = {}
local VIDA_ALTO = 4
local COLOR_VIDA = Color3.fromRGB(215, 45, 45)

local function sacarVida(id: number)
	local v = vidas[id]
	if v then
		if v.marco then
			v.marco:Destroy()
		end
		vidas[id] = nil
	end
end

-- lista: { { id, pasos } } con los que cambiaron (-1 = ya no está); todo = true: es la lista entera, lo anterior se va
function Personajes.vidas(lista: any, todo: boolean?)
	if typeof(lista) ~= "table" then
		return
	end
	if todo then
		for id in vidas do
			sacarVida(id)
		end
	end
	for _, x in lista do
		local id, pasos = x[1], x[2]
		if typeof(id) == "number" and typeof(pasos) == "number" then
			if pasos <= 0 then
				sacarVida(id)
			else
				local v = vidas[id]
				if v then
					v.pasos = pasos
				else
					vidas[id] = { pasos = pasos }
				end
			end
		end
	end
end

-- Dónde empieza lo que va debajo del nombre (uno, dos o tres renglones); sin nombre a la vista, debajo de los pies
local function yBajoNombre(pj: Personaje, ahora: number): (number, number)
	local n = pj.partes.nombre
	local renglones = if not n.Visible or pj.nombre == "" then 0 else 1 + (if pj.clan then 1 else 0) + (if pj.admin then 1 else 0)
	local bx, by = Mundo.pxDeTile(pj.x, pj.y)
	local dx, dy = desplazamiento(pj, ahora)
	return bx + dx + 16 - BARRA_ANCHO / 2, by + dy + 34 + renglones * 14
end

local function dibujarVidas(ahora: number)
	for id, v in vidas do
		local pj = personajes[id]
		if not pj or pj.muerto then
			if v.marco then
				v.marco.Visible = false
			end
		else
			local marco = v.marco
			if not marco then
				local m = Instance.new("Frame")
				m.Name = "BarraVida"
				m.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
				m.BorderColor3 = Color3.new(0, 0, 0)
				m.BorderSizePixel = 1
				m.Size = UDim2.fromOffset(BARRA_ANCHO, VIDA_ALTO)
				local r = Instance.new("Frame")
				r.Name = "Relleno"
				r.BackgroundColor3 = COLOR_VIDA
				r.BorderSizePixel = 0
				r.Parent = m
				m.Parent = Mundo.lienzoGui()
				v.marco, v.relleno = m, r
				marco = m
			end
			-- (hay una por cada criatura del mapa: solo se toca lo que cambió)
			local relleno = v.relleno :: Frame
			if v.hecho ~= v.pasos then
				v.hecho = v.pasos
				relleno.Size = UDim2.new(math.clamp(v.pasos / BARRA_ANCHO, 0, 1), 0, 1, 0)
			end
			local x, y = yBajoNombre(pj, ahora)
			if v.x ~= x or v.y ~= y then
				v.x, v.y = x, y
				marco.Position = UDim2.fromOffset(x, y)
			end
			local z = Mundo.z(pj.x, pj.y, Mundo.SUB.nombre)
			if v.z ~= z then
				v.z = z
				marco.ZIndex = z
				relleno.ZIndex = z
			end
			marco.Visible = true
		end
	end
end

Personajes.soltarBarras = function()
	for _, b in barras do
		if b.marco then
			b.marco:Destroy()
			b.marco, b.relleno, b.texto = nil, nil, nil
		end
	end
	for _, v in vidas do
		if v.marco then
			v.marco:Destroy()
			v.marco, v.relleno, v.hecho, v.x, v.y, v.z = nil, nil, nil, nil, nil, nil
		end
	end
end

local function dibujarBarras(ahora: number)
	for id, b in barras do
		local pj = personajes[id]
		local queda = b.hasta - ahora
		if queda <= 0 then
			sacarBarra(id)
		elseif not pj or pj.muerto then
			if b.marco then
				b.marco.Visible = false
			end
		else
			local marco = b.marco
			if not marco then
				local m = Instance.new("Frame")
				m.Name = "BarraParalisis"
				m.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
				m.BorderColor3 = Color3.new(0, 0, 0)
				m.BorderSizePixel = 1
				m.Size = UDim2.fromOffset(BARRA_ANCHO, BARRA_ALTO)
				local r = Instance.new("Frame")
				r.Name = "Relleno"
				r.BorderSizePixel = 0
				r.Parent = m
				local t = Instance.new("TextLabel")
				t.Name = "Segundos"
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.SourceSansBold
				t.TextSize = 13
				t.TextXAlignment = Enum.TextXAlignment.Left
				t.TextStrokeTransparency = 0.3
				t.Position = UDim2.fromOffset(BARRA_ANCHO + 4, -5)
				t.Size = UDim2.fromOffset(40, 14)
				t.Parent = m
				m.Parent = Mundo.lienzoGui()
				b.marco, b.relleno, b.texto = m, r, t
				marco = m
			end
			local relleno, texto = b.relleno :: Frame, b.texto :: TextLabel
			local color = if b.inm then COLOR_INMOVIL else COLOR_PARALISIS
			relleno.BackgroundColor3 = color
			relleno.Size = UDim2.new(math.clamp(queda / b.total, 0, 1), 0, 1, 0)
			texto.TextColor3 = color
			texto.Text = tostring(math.ceil(queda))
			-- debajo del nombre y, si se le ve la vida, debajo de esa barra
			local x, y = yBajoNombre(pj, ahora)
			marco.Position = UDim2.fromOffset(x, y + (if vidas[id] then VIDA_ALTO + 4 else 0))
			marco.ZIndex = Mundo.z(pj.x, pj.y, Mundo.SUB.nombre)
			relleno.ZIndex = marco.ZIndex
			texto.ZIndex = marco.ZIndex
			marco.Visible = true
		end
	end
end

RunService.RenderStepped:Connect(function()
	local ahora = os.clock()
	moverProyectiles(ahora)
	dibujarVidas(ahora)
	dibujarBarras(ahora)
	for i = #numeros, 1, -1 do
		local n = numeros[i]
		local t = (ahora - n.t0) / 1
		local pj = personajes[n.id]
		if pj then
			local dx, dy = desplazamiento(pj, ahora)
			n.px, n.py = pj.x + dx / TILE_PX, pj.y + dy / TILE_PX -- en tiles: sobrevive a un cambio de origen
		end
		if t >= 1 or not n.px then
			n.label:Destroy()
			table.remove(numeros, i)
		elseif t < 0 then
			n.label.Visible = false
		else
			n.label.Visible = true
			local bx, by = Mundo.pxDeTile(n.px :: number, n.py :: number)
			local subida = 20 * (1 - (1 - t) ^ 3)
			n.label.Position = UDim2.fromOffset(bx + 16 - 40, by - 48 - subida)
			n.label.TextTransparency = math.max(0, (t - 0.6) / 0.4)
		end
	end
	-- Diálogos: siguen al personaje; entran 12 px más abajo y suben 1 px cada 12 ms
	for _, pj in personajes do
		local d = pj.dialogo
		if d then
			if ahora >= pj.dialogoHasta then
				d:Destroy()
				pj.dialogo = nil
			else
				local bx, by = Mundo.pxDeTile(pj.x, pj.y)
				local dx, dy = desplazamiento(pj, ahora)
				local entrada = math.max(0, 12 - (ahora - pj.dialogoT0) * 1000 / 12)
				local cuerpo = Indices.cuerpos[pj.apariencia.cuerpo]
				d.Position = UDim2.fromOffset(bx + dx + 16 - 90, yDialogo(by + dy, cuerpo and cuerpo.headOffset[2] or 0, d) + entrada)
			end
		end
		local p = pj.puntos
		if p then
			local bx, by = Mundo.pxDeTile(pj.x, pj.y)
			local dx, dy = desplazamiento(pj, ahora)
			p.Position = UDim2.fromOffset(bx + dx + 16 - 20, by + dy + OFFSET_HEAD - 34)
			p.Visible = pj.dialogo == nil
		end
	end
	for i = #dialogosTile, 1, -1 do
		local t = dialogosTile[i]
		if ahora >= t.hasta then
			t.label:Destroy()
			table.remove(dialogosTile, i)
		else
			local bx, by = Mundo.pxDeTile(t.x, t.y)
			local entrada = math.max(0, 12 - (ahora - t.t0) * 1000 / 12)
			t.label.Position = UDim2.fromOffset(bx + 16 - 90, yDialogo(by, -4, t.label) + entrada)
		end
	end
end)

-- ─── Actualización por frame ─────────────────────────────────────────────────
-- Personajes.alTerminarPaso(id) lo puede usar el controlador para encadenar pasos
Personajes.alTerminarPaso = nil :: ((number) -> ())?

RunService:BindToRenderStep("AO_Personajes", Enum.RenderPriority.Character.Value, function()
	local ahora = os.clock()
	for pj in enMovimiento do
		if ahora - pj.t0 >= segPaso(pj) then
			local cb = Personajes.alTerminarPaso
			if cb then
				cb(pj.id) -- puede empezar otro paso y re-registrarlo
			end
			if ahora - pj.t0 >= segPaso(pj) then -- no arrancó otro paso: queda quieto
				pj.caminando = false
				enMovimiento[pj] = nil
				vestir(pj)
			end
		end
		ubicar(pj, ahora)
	end
end)

-- Cuando el lienzo del mapa cambia de origen, todos se reubican (personajes y FX en el piso)
Mundo.alRedibujar(function()
	local ahora = os.clock()
	for _, pj in personajes do
		ubicar(pj, ahora)
	end
	for pj in yendose do
		ubicar(pj, ahora)
	end
	for f in fxPiso do
		ubicarFxPiso(f)
	end
end)

return Personajes
