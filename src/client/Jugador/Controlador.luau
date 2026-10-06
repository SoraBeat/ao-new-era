--!strict
--[[
	Controlador — input del personaje propio (docs/10-cliente-controles-e-interfaz.md, docs/15 §2, §5, §7).

	- Flechas o WASD, sin diagonales. Si hay varias apretadas, gana la ÚLTIMA que se apretó.
	- Manteniendo la tecla, el siguiente paso sale apenas termina el anterior (222 ms por tile).
	- Predicción: el personaje camina al toque y avisa al servidor. Si el servidor rechaza el paso,
	  llega PosCorregida y el personaje salta de golpe a la posición real, como en AO.
	- Si el tile de enfrente no se puede pisar, el personaje solo gira.
	- Ctrl ataca y C alterna el seguro. Se disparan al SOLTAR la tecla, no se repiten manteniéndola, y un
	  golpe antes de tiempo se pierde: no hay cola (docs/10 §2 y §4).
	- Fase 7: timers del cliente clásico para golpe y hechizo (DF7-04 A), cursor armado con "Lanzar" y
	  click sobre el mapa, F6 para meditar, y movimiento con meditación (DF7-06 B) y parálisis (DF7-07 A).
	- Fase 11 (docs/20): las teclas salen de la configuración del jugador (Shared.Config.Teclas; DF11-03 C: WASD de
	  fábrica y las flechas caminan siempre salvo que se asignen a otra acción). Todas las acciones salvo caminar se
	  disparan al soltar. Agarrar, tirar (con el diálogo de cantidad) y equipar. El click apunta sobre el dibujo
	  de los personajes (DF11-02 C).
	- Fase 13a (docs/22): doble click o doble toque sobre un tile = Accion (puertas, carteles, sacerdote); el cartel
	  se cierra al caminar o hacer click; viajando con /HOGAR no se camina; las salidas a mapas que todavía no están
	  avisan (DF13-04 A).
	- Fase 18 (docs/37 §7): el mando. El rumbo del stick entra junto al del D-pad táctil (setDireccionMando). El click
	  sobre el mapa está partido en dos: clickEnMapa pasa de la pantalla al tile y accionEnTile hace lo que toca sobre
	  ese tile. alCambiarCursor avisa cuando se arma y se desarma el cursor, y Controlador.desarmar lo cancela.
	- Fase 34 (docs/54): el mando pasó a tener un puntero libre, un mouse: llama a clickEnPantalla (clickEnMapa),
	  menuEnPantalla (el botón derecho), interactuarEn y dispararEn con el punto de la pantalla. Un jugador vivo pasa
	  por encima del fantasma de otro (el servidor lo corre a la casilla de la que viene). El click de talar o minar
	  vale sobre todo el dibujo del árbol o del yacimiento (Mundo.recursoBajo).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local Magia = require(ReplicatedStorage.Shared.Config.Magia)
local Teclas = require(ReplicatedStorage.Shared.Config.Teclas)
local MovConfig = require(ReplicatedStorage.Shared.Config.Movimiento)
local Timers = require(ReplicatedStorage.Shared.Combate.Timers)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local Mundo = require(script.Parent.Parent.Render.Mundo)
local Personajes = require(script.Parent.Parent.Render.Personajes)
local Consola = require(script.Parent.Parent.UI.Consola)
local Inventario = require(script.Parent.Parent.UI.Inventario)
local Diagnostico = require(script.Parent.Parent.UI.Diagnostico)
local Cantidad = require(script.Parent.Parent.UI.Cantidad)
local HudComun = require(script.Parent.Parent.UI.HudComun)
local Chat = require(script.Parent.Parent.UI.Chat)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Ciudad = require(ReplicatedStorage.Shared.Config.Ciudad)
local Transporte = require(ReplicatedStorage.Shared.Config.Transporte)
local Hab = require(ReplicatedStorage.Shared.Config.Habilidades)

local Controlador = {}

local DIRECCION: { [string]: number } = {
	arriba = Grilla.NORTE,
	derecha = Grilla.ESTE,
	abajo = Grilla.SUR,
	izquierda = Grilla.OESTE,
}

-- Configuración de teclas: acción → tecla y tecla → acción (con las flechas extra de DF11-03 C)
local mapaTeclas: Teclas.Mapa = Teclas.copia(Teclas.Juegos[Teclas.PorDefecto])
local accionDe: { [string]: string } = {}
local function reconstruir()
	accionDe = {}
	for tecla, accion in Teclas.FlechasExtra do
		accionDe[tecla] = accion
	end
	for accion, tecla in mapaTeclas do
		accionDe[tecla] = accion
	end
end
reconstruir()

-- Lo pone la barra de atajos (Fase 22): cambiaron las teclas
Controlador.alCambiarTeclas = nil :: (() -> ())?

function Controlador.setTeclas(t: Teclas.Mapa)
	mapaTeclas = Teclas.copia(t)
	reconstruir()
	if Controlador.alCambiarTeclas then
		Controlador.alCambiarTeclas()
	end
end

function Controlador.teclas(): Teclas.Mapa
	return Teclas.copia(mapaTeclas)
end

-- La ventana de teclas la toma mientras espera una tecla: el juego no reacciona
Controlador.capturando = false
-- Fase 26 (docs/46 §3.3): con la ventana obligatoria del camino abierta no se juega (lo pone Main)
Controlador.bloqueado = nil :: (() -> boolean)?
local function bloqueado(): boolean
	local f = Controlador.bloqueado
	return f ~= nil and f()
end
-- Lo pone el HUD: abre la ventana de opciones
Controlador.alOpciones = nil :: (() -> ())?
Controlador.alGuia = nil :: (() -> ())? -- la Guía del juego (Fase 26, docs/46 §10): la tecla y los botones del HUD
-- Lo pone Main: las teclas de música y sonidos (docs/29 §5)
Controlador.alAudio = nil :: ((string) -> ())?

-- La mira del cursor armado (vbCrosshair del original, Protocol.bas:1243). docs/28 §11: una imagen nuestra, porque el
-- cursor de sistema "Cross" no se veía
local CURSOR_CRUZ = (require(game:GetService("ReplicatedStorage").Shared.Generado.UiAssets) :: any).cursorCruz or "rbxasset://SystemCursors/Cross"

local miId = 0
local idCorreccion = 0
local apretadas: { string } = {} -- teclas de caminar, en orden de pulsación; la última gana
local caminar: RemoteEvent
local girar: RemoteEvent
local atacar: RemoteEvent
local seguro: RemoteEvent
local lanzar: RemoteEvent
local mirar: RemoteEvent
local meditar: RemoteEvent
local tirar: RemoteEvent
local agarrar: RemoteEvent
local equipar: RemoteEvent
local accion: RemoteEvent

local timers = Timers.nuevoCliente()
local muerto = false
local meditando = false
local descansando = false -- Fase 19 (docs/38 §3): junto a una fogata; no se ataca hasta levantarse
local paralizado = false
local inmovilizado = false -- Fase 14b (docs/27 §12.5): paralizado que puede girar
local aturdido = false -- Fase 14b (docs/27 §12.6): el paso lo elige el servidor
local esperandoPaso = false
local ultimoPasoAturdido = -1e9
local mana, maxMana = 0, 0
local cursorSlot: number? = nil -- hechizo armado ("Lanzar" apretado, esperando el click)
-- Fase 14a (docs/27 §2 y §6): el cursor del arco ("Proyectiles", lo pide el servidor al usar el arco) o el de robar
local cursorSkill: string? = nil
local disparar: RemoteEvent
local robar: RemoteEvent
local domar: RemoteEvent -- Fase 16c (docs/33 §1.3)
local ocultarse: RemoteEvent
local timersTrabajo = Timers.nuevoClienteUso()
local viajando = false
local ultimoAvisoViaje = -1e9
local ultimoAvisoSalida = -1e9
local ultimoAvisoMontura = -1e9
local ultimoClick = { x = 0, y = 0, t = -1e9 }
-- Fase 16a (docs/31 §2.2, DR16-12 A): el último click de trabajo y el macro que lo repite cada 900 ms. Desde el
-- 2026-10-04 (docs/31 §2.2, "Cambió") se prende solo con el click de trabajo; F8 lo para y lo retoma.
local trabajar: RemoteEvent
local ultimoTrabajo: { skill: string, x: number, y: number }? = nil
local macroActivo = false
local macroSerie = 0 -- cada encendido es una serie: la anterior deja de repetir aunque esté en medio de su espera
local macroAvisado = false -- ya se le dijo que sigue trabajando (y entonces se le dice cuando para)
local MACRO_MS = 900 -- INT_MACRO_TRABAJO (cli/Declares.bas:114)
local MSG_SIGUE = "Sigues trabajando hasta que camines o hagas click en otro lado."
local MSG_PARA = "Dejas de trabajar."
local OFICIOS = { Talar = true, Pesca = true, Mineria = true, FundirMetal = true, Herreria = true } -- 16b: fragua y yunque
local colaActiva = false -- Fase 16b (docs/32 §2.2): el servidor está construyendo (la cola)
-- Aviso del cursor (cli/Lenguajes/spanish.json:276-306)
local AVISO_CURSOR = {
	Talar = "Haz click sobre el arbol...",
	Pesca = "Haz click sobre el sitio donde quieres pescar...",
	Mineria = "Haz click sobre el yacimiento...",
	FundirMetal = "Haz click sobre la fragua...",
	Herreria = "Haz click sobre el yunque...", -- nuestro: el original arma la cruz sin aviso
	Domar = "Haz click sobre la criatura...", -- nuestro (Fase 16c, docs/33 §1.3): el original no avisa
}

-- ─── Estado que manda el servidor ────────────────────────────────────────────
-- El HUD táctil muestra el botón "Seguir" (estado: "nada" | "listo" | "activo")
Controlador.alCambiarMacro = nil :: ((string) -> ())?
local function avisarMacro()
	local f = Controlador.alCambiarMacro
	if f then
		f(if macroActivo or colaActiva then "activo" elseif ultimoTrabajo then "listo" else "nada")
	end
end

-- Se apaga al caminar, atacar, usar otro objeto, hacer otro click o morir (frmMain.frm:2112-2146). olvidar: además
-- se pierde el último click de trabajo (caminar)
function Controlador.cortarMacro(olvidar: boolean?)
	local avisar = macroActivo and macroAvisado
	macroActivo = false
	macroSerie += 1
	macroAvisado = false
	if avisar then
		Consola.agregar(MSG_PARA, "info")
	end
	if olvidar then
		ultimoTrabajo = nil
	end
	avisarMacro()
end

function Controlador.setEstadisticas(s: any)
	if s.muerto and not muerto then
		Controlador.cortarMacro(true)
	end
	muerto = s.muerto
	mana, maxMana = s.mana, s.maxMana
	meditando = s.meditando == true
	descansando = s.descansando == true
	paralizado = s.paralizado == true
end

function Controlador.setMuerto(m: boolean)
	muerto = m
end

function Controlador.setMeditando(m: boolean)
	meditando = m
end

function Controlador.setParalisis(ticks: number, inmov: boolean?)
	paralizado = ticks > 0
	inmovilizado = paralizado and inmov == true
end

function Controlador.setAturdido(si: boolean)
	aturdido = si
	esperandoPaso = false
end

-- Fase 13a: viaje con /HOGAR (segundos; 0 = terminó) y la corrección que manda el servidor al cambiar de mapa
function Controlador.setViaje(seg: number)
	viajando = seg > 0
end

function Controlador.setCorreccion(idc: number)
	idCorreccion = idc
end

local function ahoraMs(): number
	return os.clock() * 1000
end

-- ─── Movimiento ──────────────────────────────────────────────────────────────
local function quitarTecla(k: string)
	local i = table.find(apretadas, k)
	if i then
		table.remove(apretadas, i)
	end
end

-- D-pad táctil (docs/17 §3): mientras se mantiene apretado manda sobre el teclado
local direccionTactil: number? = nil
function Controlador.setDireccionTactil(h: number?)
	direccionTactil = h
end

-- El stick o la cruceta del mando (Fase 18, docs/37 §7.2): igual que el D-pad táctil
local direccionMando: number? = nil
function Controlador.setDireccionMando(h: number?)
	direccionMando = h
end

local function direccionActual(): number?
	if direccionTactil then
		return direccionTactil
	end
	if direccionMando then
		return direccionMando
	end
	local k = apretadas[#apretadas]
	local accion = k and accionDe[k]
	return accion and DIRECCION[accion] or nil
end

-- Chequeo local (el servidor tiene la última palabra). P7 (docs/34 §1.3): navegando solo se pisa agua; a pie, solo
-- tierra (Map_LegalPos, cli/Areas/mPooMap.bas:254-258)
local function sePuedePisar(x: number, y: number): boolean
	local mapa = Mundo.mapa()
	local yo = Personajes.de(miId)
	local navego = yo ~= nil and yo.navegando
	-- Montado no se entra bajo techo (cli/Areas/mPooMap.bas:260-272; docs/34 §4.2)
	if yo and yo.montado and Mapas.bajoTecho(mapa, x, y) then
		if os.clock() - ultimoAvisoMontura > 2 then
			ultimoAvisoMontura = os.clock()
			Consola.agregar(Transporte.MsgMontura.Caminar, "info")
		end
		return false
	end
	return Grilla.dentroDelAreaJugable(x, y)
		and not Grilla.estaBloqueado(mapa, x, y)
		and Grilla.esAgua(mapa, x, y) == navego
		and not Personajes.bloquea(x, y, miId) -- (el fantasma de otro jugador no frena: Fase 34)
end

-- Descartes del cliente: acciones apretadas antes de tiempo (para el panel de diagnóstico, DF10-02 B)
Controlador.descartes = { golpes = 0, clicks = 0 }

-- Giro en el lugar con el límite de 300 ms del cliente original (MainTimer ChangeHeading, DF10-05 B)
local ultimoGiro = -1e9
local function girarLimitado(h: number)
	local ahora = os.clock() * 1000
	if ahora - ultimoGiro >= MovConfig.MS_GIRO then
		ultimoGiro = ahora
		Personajes.girar(miId, h)
		girar:FireServer(h)
	end
end

local function intentarPaso(t0: number?)
	local h = direccionActual()
	local pj = Personajes.de(miId)
	if not h or not pj or bloqueado() then
		return
	end
	local d = Grilla.DELTA[h]
	local nx, ny = pj.x + d[1], pj.y + d[2]
	local libre = sePuedePisar(nx, ny)
	HudComun.cerrarCartel() -- caminar cierra el cartel (cliente mPooMap.bas:114)

	if viajando then
		if os.clock() - ultimoAvisoViaje > 2 then
			ultimoAvisoViaje = os.clock()
			Consola.agregar(Ciudad.MsgViajando, "info")
		end
		return
	end
	if not libre then
		local cerrada = Mapas.salidaCerrada(Mundo.mapa(), nx, ny)
		if cerrada and os.clock() - ultimoAvisoSalida > Ciudad.SegAvisoSalida then
			ultimoAvisoSalida = os.clock()
			Consola.agregar(if cerrada == "borde" then Ciudad.MsgSalidaBorde else Ciudad.MsgSalidaInterior, "info")
		end
	end

	if not muerto and (meditando or paralizado) then
		-- Meditando: el primer toque no camina; corta la meditación en el servidor (DF7-06 B).
		-- Paralizado: no camina; sólo gira hacia un tile no transitable (DF7-07 A).
		if meditando then
			meditando = false
			meditar:FireServer(false)
		end
		-- (un fantasma no frena el paso, pero para girar cuenta como ocupado, igual que en el servidor)
		local puedeGirar = not paralizado or inmovilizado or not libre or Personajes.ocupado(nx, ny, miId)
		if pj.heading ~= h and puedeGirar then
			girarLimitado(h)
		end
		return
	end

	if aturdido and not muerto then
		-- Aturdido (docs/27 §12.6): no predice; manda el paso y el servidor lo devuelve para cualquier lado. Uno por
		-- vez y no más seguido que las fichas del servidor.
		local ahora = os.clock() * 1000
		if esperandoPaso and ahora - ultimoPasoAturdido < 1000 then
			return
		end
		if ahora - ultimoPasoAturdido < MovConfig.MS_POR_FICHA then
			return
		end
		esperandoPaso = true
		ultimoPasoAturdido = ahora
		caminar:FireServer(h, idCorreccion)
		return
	end

	if libre then
		if macroActivo or ultimoTrabajo then
			Controlador.cortarMacro(true)
		end
		Personajes.caminar(miId, nx, ny, h, t0)
		caminar:FireServer(h, idCorreccion)
	elseif pj.heading ~= h then
		girarLimitado(h)
	end
end

-- Posición visual del personaje propio (en tiles), para la cámara y el HUD
function Controlador.posicion(): (number, number)
	return Personajes.posicionVisual(miId)
end

-- ─── Hechizos: "Lanzar" arma el cursor; el click sobre el mapa lanza ─────────
-- Lo pone el mando (Fase 18): el cursor se armó (true) o se desarmó (false)
Controlador.alCambiarCursor = nil :: ((boolean) -> ())?
local function avisarCursor(armado: boolean)
	local f = Controlador.alCambiarCursor
	if f then
		f(armado)
	end
end

local function desarmar()
	local estaba = cursorSlot ~= nil or cursorSkill ~= nil
	cursorSlot = nil
	cursorSkill = nil
	UserInputService.MouseIcon = ""
	if estaba then
		avisarCursor(false)
	end
end
Controlador.desarmar = desarmar

-- Lo llama la lista de hechizos (botón "Lanzar", frmMain.frm:2437-2451). callado: lo usan los atajos (Fase 22,
-- docs/41 §1.3), que arman la mira con una tecla: sin el aviso en cada apretada
function Controlador.lanzar(slot: number, callado: boolean?)
	if muerto then
		if not callado then
			Consola.agregar("Estas Muerto!!!", "info")
		end
		return
	end
	cursorSlot = slot
	cursorSkill = nil
	UserInputService.MouseIcon = CURSOR_CRUZ
	if not callado then
		Consola.agregar("Haz click sobre el objetivo...", "objetivo")
	end
	avisarCursor(true)
end

function Controlador.estaMuerto(): boolean
	return muerto
end

-- Lo pone el HUD de PC (Fase 22): la tecla de un atajo, al apretarla
Controlador.alAtajo = nil :: ((number) -> ())?

-- WorkRequestTarget (cliente Protocol.bas:1239-1294): el servidor lo pide al usar el arco; robar lo arma la tecla R
function Controlador.pedirObjetivo(skill: string)
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	cursorSkill = skill
	cursorSlot = nil
	UserInputService.MouseIcon = CURSOR_CRUZ
	-- MENSAJE_TRABAJO_PROYECTILES / _ROBAR; los oficios, el suyo (Fase 16a)
	Consola.agregar(AVISO_CURSOR[skill] or "Haz click sobre la victima...", "objetivo")
	avisarCursor(true)
end

-- La cola de construcción (Fase 16b): el servidor avisa cuando empieza y cuando termina
function Controlador.setCola(activa: boolean)
	colaActiva = activa
	avisarMacro()
end

-- Prende la repetición del último click de trabajo. yaMando: el click acaba de mandar el primer intento, así que
-- espera un intervalo antes de repetir. El aviso sale con la primera repetición: si el servidor contesta antes que
-- ahí no se puede trabajar (y la corta), no se dice nada de más.
local function prenderMacro(yaMando: boolean)
	macroActivo = true
	macroSerie += 1
	macroAvisado = false
	local serie = macroSerie
	avisarMacro()
	task.spawn(function()
		if yaMando then
			task.wait(MACRO_MS / 1000)
		end
		while macroActivo and macroSerie == serie do
			local t = ultimoTrabajo
			if not t or muerto then
				Controlador.cortarMacro()
				break
			end
			if not macroAvisado then
				macroAvisado = true
				Consola.agregar(MSG_SIGUE, "info")
			end
			trabajar:FireServer(t.skill, t.x, t.y)
			task.wait(MACRO_MS / 1000)
		end
	end)
end

-- F8 (frmMain.frm:2112-2146): para o retoma el macro que repite el último click de trabajo. Con una cola de
-- construcción en curso, la para (Fase 16b)
function Controlador.alternarMacro()
	if colaActiva then
		Remotes.evento("PararTrabajo"):FireServer()
		return
	end
	if macroActivo then
		Controlador.cortarMacro()
		return
	end
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	if not ultimoTrabajo then
		Consola.agregar("Primero usa la herramienta y haz click donde quieres trabajar.", "info")
		return
	end
	prenderMacro(false)
end

-- Ocultarse (frmMain.frm:1723-1732): sin timer en el cliente; el servidor pone el límite (DC14-10 A)
function Controlador.ocultarse()
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	ocultarse:FireServer()
end

-- Robar (frmMain.frm:1712-1721): arma el cursor
function Controlador.robar()
	Controlador.pedirObjetivo("Robar")
end

-- Domar (frmMain.frm:1701-1710; Fase 16c, docs/33 §1.3): la tecla arma el cursor; no entra en el macro F8
function Controlador.domar()
	Controlador.pedirObjetivo("Domar")
end

-- Navegar (Fase 21, docs/40 §8; nuestro): sube al mejor barco del inventario o baja. El servidor elige el barco.
local ultimoNavegar = 0
function Controlador.navegar()
	local ahora = os.clock()
	if ahora - ultimoNavegar < 0.45 then
		return
	end
	ultimoNavegar = ahora
	Remotes.evento("Navegar"):FireServer()
end

-- Punto del mundo bajo un punto de la pantalla, en tiles continuos (el lienzo del mapa está en el plano y = 0):
-- el tile (x, y) va de x a x + 1
local function puntoEnPantalla(pos: Vector2): (number?, number?)
	local camara = workspace.CurrentCamera
	if not camara then
		return nil, nil
	end
	local rayo = camara:ScreenPointToRay(pos.X, pos.Y)
	if math.abs(rayo.Direction.Y) < 1e-6 then
		return nil, nil
	end
	local p = rayo.Origin + rayo.Direction * (-rayo.Origin.Y / rayo.Direction.Y)
	return p.X / Grilla.TILE_STUDS + 1, p.Z / Grilla.TILE_STUDS + 1
end

-- El HUD dice si un punto de la pantalla cae sobre la vista del juego (en PC, el hueco de MainViewPic)
Controlador.filtroClick = nil :: ((Vector2) -> boolean)?
-- La misma pregunta sin efectos (en el celular, filtroClick además cierra el panel abierto y se queda con el toque)
Controlador.filtroVista = nil :: ((Vector2) -> boolean)?
-- La ventana "Grupo" (docs/28 §10): se clickeó a otro jugador / a otra cosa del mapa
Controlador.alClickearJugador = nil :: ((number, string, Vector2) -> ())?
Controlador.alClickearMapa = nil :: (() -> ())?
-- Fase 28 (docs/48 §2): se hizo click derecho sobre una criatura que se puede inspeccionar (id, su número, dónde)
Controlador.alClickearNpc = nil :: ((number, number, Vector2) -> ())?

-- Lo que hace un click sobre un tile (frmMain.frm:2522-2632). (x, y): el tile al que se apunta; exacto e id: si el
-- click cayó sobre el dibujo de un personaje (DF11-02 C); (tx, ty): el tile clickeado sin ese ajuste (los oficios).
-- Lo llama clickEnMapa (mouse, dedo y el puntero del mando)
local function accionEnTile(x: number, y: number, exacto: any, id: number?, tx: number, ty: number)
	local pj = Personajes.de(miId)
	if not pj or not Grilla.dentroDelMapa(x, y) then
		return
	end
	-- La vista es más ancha que el rango del original (D-40 C): fuera del rango el click no existe
	if math.abs(x - pj.x) > Magia.RangoVisionX or math.abs(y - pj.y) > Magia.RangoVisionY then
		return
	end
	HudComun.cerrarCartel() -- un click en la vista cierra el cartel (cliente frmMain.frm:2522)
	if macroActivo then
		Controlador.cortarMacro() -- otro click apaga el macro (frmMain.frm:2551-2552)
	end
	-- Cursor del arco o de robar (frmMain.frm:2552-2632): antes de tiempo se desarma
	if cursorSkill then
		local skill = cursorSkill
		if skill == "Proyectiles" then
			if not Timers.clickFlecha(timers, ahoraMs()) then
				Controlador.descartes.clicks += 1
				desarmar()
				Consola.agregar("No puedes lanzar proyectiles tan rapido.", "talk")
				return
			end
			desarmar()
			disparar:FireServer(x, y, exacto, id) -- docs/28 §11: el id del apuntado, por si se movió
		elseif OFICIOS[skill] then
			-- Talar, pescar, minar (Fase 16a): el tile clickeado, sin el ajuste al personaje; INT_WORK 700
			desarmar()
			if not Timers.clienteUsar(timersTrabajo, "Work", 700, ahoraMs()) then
				return
			end
			trabajar:FireServer(skill, tx, ty)
			if skill ~= "Herreria" then -- el yunque abre la ventana: no se repite
				-- y sigue solo (pedido del autor, 2026-10-04): no hace falta apretar F8 después del primer click
				ultimoTrabajo = { skill = skill, x = tx, y = ty }
				prenderMacro(true)
			end
		else
			-- Robar: MainTimer.Check(Work), INT_WORK 700 (frmMain.frm:2620-2625)
			if not Timers.clienteUsar(timersTrabajo, "Work", 700, ahoraMs()) then
				desarmar()
				return
			end
			desarmar()
			if skill == "Domar" then
				domar:FireServer(x, y, exacto, id)
			else
				robar:FireServer(x, y, exacto)
			end
		end
		return
	end
	local slot = cursorSlot
	if slot == nil then
		mirar:FireServer(x, y, exacto) -- LeftClick → LookatTile (DF7-08 A)
		if Controlador.alClickearMapa then
			(Controlador.alClickearMapa :: () -> ())() -- cierra el "Invitar al grupo" (docs/28 §11)
		end
		-- Doble click en el mismo tile → Accion (DoubleClick, Protocol.bas:3081-3105)
		local ahora = os.clock()
		if ultimoClick.x == x and ultimoClick.y == y and ahora - ultimoClick.t <= Ciudad.DobleClickSeg then
			accion:FireServer(x, y)
			ultimoClick.t = -1e9
		else
			ultimoClick.x, ultimoClick.y, ultimoClick.t = x, y, ahora
		end
		return
	end
	-- Timers del cliente clásico (frmMain.frm:2586-2616): antes de tiempo se desarma y no se encola
	if not Timers.clickHechizo(timers, ahoraMs()) then
		Controlador.descartes.clicks += 1
		desarmar()
		Consola.agregar("No puedes lanzar hechizos tan rapido.", "talk")
		return
	end
	desarmar()
	lanzar:FireServer(slot, x, y, exacto, id)
end

-- El mando, botón A sin el puntero a la vista: mirar y, enseguida, la acción sobre el tile de enfrente (va con
-- "tile": el servidor toma solo a quien está parado ahí, sin la regla del mouse)
function Controlador.interactuar(x: number, y: number)
	local pj = Personajes.de(miId)
	if not pj or not Grilla.dentroDelMapa(x, y) then
		return
	end
	if math.abs(x - pj.x) > Magia.RangoVisionX or math.abs(y - pj.y) > Magia.RangoVisionY then
		return
	end
	HudComun.cerrarCartel()
	if macroActivo then
		Controlador.cortarMacro()
	end
	mirar:FireServer(x, y, "tile")
	accion:FireServer(x, y)
end

local function clickEnMapa(pos: Vector2)
	local filtro = Controlador.filtroClick
	if filtro and not filtro(pos) then
		return
	end
	local u, v = puntoEnPantalla(pos)
	if not u or not v or not Personajes.de(miId) then
		return
	end
	-- Sobre el dibujo de un personaje: se manda su tile (DF11-02 C); si no, el tile clickeado. Con el arco uno mismo
	-- no cuenta (Fase 34): no se puede tirar a uno mismo, y su dibujo tapa al que tiene pegado arriba
	local id, px, py = Personajes.bajoElMouse(u, v, if cursorSkill == "Proyectiles" then miId else nil)
	local x, y = math.floor(u), math.floor(v)
	local exacto = id ~= nil and px ~= nil and py ~= nil
	if exacto then
		x, y = px :: number, py :: number
	end
	-- Talar y minar (Fase 34, docs/54 §3): vale el click sobre todo el dibujo del árbol o del yacimiento
	local tx, ty = math.floor(u), math.floor(v)
	if cursorSkill then
		local yo = Personajes.de(miId) :: any
		local rx, ry = Mundo.recursoBajo(u, v, cursorSkill, yo.x, yo.y, Hab.DistanciaOficio)
		if rx and ry then
			tx, ty = rx, ry
		end
	end
	accionEnTile(x, y, exacto, id, tx, ty)
end

-- ─── El puntero del mando (Fase 34, docs/54 §4): un mouse que se mueve con el stick ──────────
-- El click izquierdo en un punto de la pantalla (con el cursor armado: lanza, dispara, trabaja)
Controlador.clickEnPantalla = clickEnMapa

-- Dónde cae en la pantalla un punto del mapa (en casillas continuas: el centro del tile (x, y) es x + 0,5), en las
-- mismas coordenadas que los clicks. nil si queda detrás de la cámara.
function Controlador.pantallaDe(u: number, v: number): Vector2?
	local camara = workspace.CurrentCamera
	if not camara then
		return nil
	end
	local p, adelante = camara:WorldToScreenPoint(Vector3.new((u - 1) * Grilla.TILE_STUDS, 0, (v - 1) * Grilla.TILE_STUDS))
	return if adelante then Vector2.new(p.X, p.Y) else nil
end

-- ¿El punto cae sobre la vista del juego? Solo pregunta: no cierra nada
function Controlador.enLaVista(pos: Vector2): boolean
	local filtro = Controlador.filtroVista
	return filtro == nil or filtro(pos)
end

-- El tile (y el personaje, si hay uno dibujado ahí) bajo un punto de la pantalla, si está en la vista y en el rango.
-- sinMi: uno mismo no cuenta (el tiro del arco)
local function bajoElPunto(pos: Vector2, sinMi: boolean?): (number?, number?, boolean, number?)
	if not Controlador.enLaVista(pos) then
		return nil, nil, false, nil
	end
	local u, v = puntoEnPantalla(pos)
	local pj = Personajes.de(miId)
	if not u or not v or not pj then
		return nil, nil, false, nil
	end
	local id, px, py = Personajes.bajoElMouse(u, v, if sinMi then miId else nil)
	local x, y = math.floor(u), math.floor(v)
	local exacto = id ~= nil and px ~= nil and py ~= nil
	if exacto then
		x, y = px :: number, py :: number
	end
	if not Grilla.dentroDelMapa(x, y) or math.abs(x - pj.x) > Magia.RangoVisionX or math.abs(y - pj.y) > Magia.RangoVisionY then
		return nil, nil, false, nil
	end
	return x, y, exacto, id
end

-- A sin nada armado: mirar y, enseguida, la acción (el click y el doble click del mouse de una vez)
function Controlador.interactuarEn(pos: Vector2)
	local x, y, exacto = bajoElPunto(pos)
	if not x or not y then
		return
	end
	HudComun.cerrarCartel()
	if macroActivo then
		Controlador.cortarMacro()
	end
	mirar:FireServer(x, y, exacto)
	if Controlador.alClickearMapa then
		(Controlador.alClickearMapa :: () -> ())()
	end
	accion:FireServer(x, y)
end

-- RT con el arco o las Cuchillas: el tiro sale hacia donde está el puntero, sin pasar por "usar el arco" y hacer
-- click (el servidor no pide ese paso: valida el arma, las flechas y los tiempos al recibir el disparo). Devuelve si
-- lo mandó. Antes de tiempo no dice nada: con el gatillo se aprieta seguido.
function Controlador.dispararEn(pos: Vector2): boolean
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return false
	end
	local x, y, exacto, id = bajoElPunto(pos, true)
	if not x or not y then
		return false
	end
	HudComun.cerrarCartel()
	if macroActivo then
		Controlador.cortarMacro()
	end
	if not Timers.clickFlecha(timers, ahoraMs()) then
		Controlador.descartes.clicks += 1
		return false
	end
	if cursorSlot ~= nil or cursorSkill ~= nil then
		desarmar() -- había otra cosa armada (un hechizo): el tiro la reemplaza
	end
	disparar:FireServer(x, y, exacto, id)
	return true
end

-- Y del mando (Fase 35, docs/56 §3): lanza ese hechizo adonde está el puntero, sin armar el cursor y esperar el
-- click. Como el tiro del arco: el servidor valida todo al recibirlo, y antes de tiempo no dice nada. Devuelve si
-- lo mandó.
local function lanzarYa(slot: number, x: number, y: number, exacto: boolean, id: number?): boolean
	HudComun.cerrarCartel()
	if macroActivo then
		Controlador.cortarMacro()
	end
	if not Timers.clickHechizo(timers, ahoraMs()) then
		Controlador.descartes.clicks += 1
		return false
	end
	if cursorSlot ~= nil or cursorSkill ~= nil then
		desarmar() -- había otra cosa armada: el hechizo la reemplaza
	end
	lanzar:FireServer(slot, x, y, exacto, id)
	return true
end

function Controlador.lanzarEn(slot: number, pos: Vector2): boolean
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return false
	end
	local x, y, exacto, id = bajoElPunto(pos)
	if not x or not y then
		return false
	end
	return lanzarYa(slot, x, y, exacto, id)
end

-- L3 del mando (Fase 35, docs/56 §3): lanza ese hechizo sobre uno mismo, sin pasar por el puntero (curarse, sacarse
-- la parálisis). Es el click sobre el propio personaje: va con su tile y su id.
function Controlador.lanzarSobreMi(slot: number): boolean
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return false
	end
	local pj = Personajes.de(miId)
	if not pj then
		return false
	end
	return lanzarYa(slot, pj.x, pj.y, true, miId)
end

-- ─── Acciones (teclas y botones táctiles) ────────────────────────────────────
-- Ctrl (frmMain.frm:1868-1885): timers del cliente clásico; el servidor valida con los suyos
function Controlador.golpe()
	if macroActivo then
		Controlador.cortarMacro()
	end
	if Timers.ctrl(timers, ahoraMs(), meditando or descansando) then
		Personajes.atacar(miId)
		atacar:FireServer()
	elseif not meditando and not descansando then
		Controlador.descartes.golpes += 1
	end
end

function Controlador.seguro()
	seguro:FireServer()
end

-- Agarrar (frmMain.frm:2394-2404)
function Controlador.agarrar()
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	agarrar:FireServer()
end

-- Tirar (frmMain.frm:2372-2392): con 1 se tira directo; con más, el diálogo de cantidad (DF11-05 A)
function Controlador.tirar()
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	local slot, d = Inventario.seleccionado()
	if slot == 0 or not d then
		return
	end
	if d.cant == 1 then
		tirar:FireServer(slot, 1)
	elseif d.cant > 1 then
		Cantidad.abrir(d.cant, function(n: number)
			tirar:FireServer(slot, n)
		end)
	end
end

-- Equipar (frmMain.frm:2418-2435)
function Controlador.equipar()
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	local slot = Inventario.seleccionado()
	if slot > 0 then
		equipar:FireServer(slot)
		Inventario.avisarUso(slot)
	end
end

-- F6 (frmMain.frm:1817-1829): con el maná lleno no manda nada (el Guerrero, 0/0, tampoco)
function Controlador.meditar()
	if mana == maxMana then
		return
	end
	if muerto then
		Consola.agregar("Estas Muerto!!!", "info")
		return
	end
	meditar:FireServer()
end

-- Espera que falta (ms) para golpear y lanzar según los timers del cliente, con el intervalo que la gobierna
function Controlador.enfriamientos(): (number, number, number, number)
	local ahora = ahoraMs()
	local g, gt = Timers.restanteCtrl(timers, ahora)
	local h, ht = Timers.restanteHechizo(timers, ahora)
	return g, gt, h, ht
end

function Controlador.cursorArmado(): boolean
	return cursorSlot ~= nil or cursorSkill ~= nil
end

-- Botón derecho (o mantener apretado en el celular) sobre otro jugador: "Invitar al grupo" (docs/28 §11; antes era
-- el click izquierdo, que se mezclaba con apuntar)
local function menuEnMapa(pos: Vector2)
	local filtro = Controlador.filtroClick
	if filtro and not filtro(pos) then
		return
	end
	local u, v = puntoEnPantalla(pos)
	if not u or not v then
		return
	end
	local id = Personajes.bajoElMouse(u, v)
	local otro = if id and id ~= miId then Personajes.de(id) else nil
	-- (a la silueta del destello no se la puede invitar: Fase 21, docs/40 §5)
	if otro and not otro.npc and not otro.destello then
		local f = Controlador.alClickearJugador
		if f then
			f(otro.id, otro.nombre, pos)
		end
	elseif otro and otro.npc and otro.numero and Controlador.alClickearNpc then
		-- Fase 28 (docs/48 §2): sobre una criatura, "Inspeccionar"
		(Controlador.alClickearNpc :: any)(otro.id, otro.numero, pos)
	elseif Controlador.alClickearMapa then
		(Controlador.alClickearMapa :: () -> ())()
	end
end
Controlador.menuEnPantalla = menuEnMapa -- el botón derecho del puntero del mando (LT + A)
local MANTENER_S = 0.5
local toques: { [InputObject]: { t: number, pos: Vector3 } } = {}

-- ─── Arranque ────────────────────────────────────────────────────────────────
-- Otro personaje en la misma sesión (Fase 25, docs/44 §9: se volvió a la pantalla de personajes y se entró de
-- nuevo): el estado del anterior no vale. `iniciar` se llama una sola vez (conecta el teclado y los eventos).
function Controlador.reiniciar()
	desarmar()
	table.clear(apretadas)
	direccionTactil, direccionMando = nil, nil
	timers = Timers.nuevoCliente()
	timersTrabajo = Timers.nuevoClienteUso()
	muerto, meditando, descansando = false, false, false
	paralizado, inmovilizado, aturdido, esperandoPaso = false, false, false, false
	mana, maxMana = 0, 0
	viajando = false
	idCorreccion = 0
	ultimoClick = { x = 0, y = 0, t = -1e9 }
	ultimoTrabajo, macroActivo, colaActiva = nil, false, false
	macroSerie += 1
	macroAvisado = false
	avisarMacro()
end

function Controlador.iniciar(id: number)
	miId = id
	caminar = Remotes.evento("Caminar")
	girar = Remotes.evento("Girar")
	atacar = Remotes.evento("Atacar")
	seguro = Remotes.evento("Seguro")
	lanzar = Remotes.evento("Lanzar")
	mirar = Remotes.evento("Mirar")
	meditar = Remotes.evento("Meditar")
	tirar = Remotes.evento("Tirar")
	agarrar = Remotes.evento("Agarrar")
	equipar = Remotes.evento("Equipar")
	accion = Remotes.evento("Accion")
	disparar = Remotes.evento("Disparar")
	robar = Remotes.evento("Robar")
	domar = Remotes.evento("Domar")
	ocultarse = Remotes.evento("Ocultarse")
	trabajar = Remotes.evento("Trabajar")
	Remotes.evento("Produccion").OnClientEvent:Connect(function(accion: string, a: any)
		if accion == "apagarMacro" then
			-- el servidor no puede fundir más (Fase 16b), o ahí no se puede trabajar (a == true: y se olvida ese click)
			Controlador.cortarMacro(a == true)
		elseif accion == "cola" then
			Controlador.setCola(a == true)
		end
	end)
	Remotes.evento("PedirObjetivo").OnClientEvent:Connect(function(skill: string)
		Controlador.pedirObjetivo(skill)
	end)
	Inventario.alEquipar(Controlador.equipar) -- doble click sobre equipo (picInv_DblClick)
	Inventario.alEquiparSlot(function(slot: number) -- los atajos (Fase 22)
		if not muerto then
			equipar:FireServer(slot)
			Inventario.avisarUso(slot)
		end
	end)
	Inventario.alUsar = function()
		if macroActivo then
			Controlador.cortarMacro() -- usar un objeto apaga el macro de trabajo
		end
	end

	UserInputService.InputBegan:Connect(function(input, procesado)
		if input.UserInputType == Enum.UserInputType.Touch and not procesado then
			toques[input] = { t = os.clock(), pos = input.Position }
		end
		if Controlador.capturando or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if bloqueado() then
			return
		end
		-- Con la caja del chat abierta, las flechas siguen caminando (como el original); lo demás escribe (docs/23)
		if procesado and not (Chat.abierta() and Teclas.FlechasExtra[input.KeyCode.Name]) then
			return
		end
		local k = Teclas.desdeKeyCode(input.KeyCode)
		local accion = k and accionDe[k]
		if k and accion and DIRECCION[accion] then
			quitarTecla(k)
			table.insert(apretadas, k)
		end
		-- Fase 22 (docs/41 §1.3): los atajos actúan al apretar la tecla (lo demás, al soltarla), para que la poción
		-- salga en el momento. Roblox avisa una sola vez por apretada: dejarla apretada no repite.
		local n = accion and tonumber(string.match(accion, "^atajo(%d+)$"))
		if n and not procesado and Controlador.alAtajo then
			Controlador.alAtajo(n)
		end
	end)
	UserInputService.InputEnded:Connect(function(input, procesado)
		local k = if input.UserInputType == Enum.UserInputType.Keyboard then Teclas.desdeKeyCode(input.KeyCode) else nil
		if k then
			quitarTecla(k)
		end
		local t = toques[input]
		toques[input] = nil
		if procesado or Controlador.capturando or bloqueado() then
			return
		end
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.Touch then
			if t and os.clock() - t.t >= MANTENER_S and (input.Position - t.pos).Magnitude < 12 then
				menuEnMapa(Vector2.new(input.Position.X, input.Position.Y)) -- mantener apretado
				return
			end
		end
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			clickEnMapa(Vector2.new(input.Position.X, input.Position.Y))
			return
		end
		if tipo == Enum.UserInputType.MouseButton2 then
			menuEnMapa(Vector2.new(input.Position.X, input.Position.Y))
			return
		end
		local accion = k and accionDe[k]
		if accion == "atacar" then
			Controlador.golpe()
		elseif accion == "seguro" then
			Controlador.seguro()
		elseif accion == "meditar" then
			Controlador.meditar()
		elseif accion == "usar" then
			Inventario.usar("U") -- frmMain.frm:1737-1744: al soltar, 450 ms
		elseif accion == "agarrar" then
			Controlador.agarrar()
		elseif accion == "tirar" then
			Controlador.tirar()
		elseif accion == "equipar" then
			Controlador.equipar()
		elseif accion == "opciones" then
			if Controlador.alOpciones then
				Controlador.alOpciones()
			end
		elseif accion == "guia" then -- Fase 26 (docs/46 §10)
			if Controlador.alGuia then
				Controlador.alGuia()
			end
		elseif accion == "musica" or accion == "sonidos" then
			if Controlador.alAudio then
				Controlador.alAudio(accion)
			end
		elseif accion == "ocultar" then
			Controlador.ocultarse()
		elseif accion == "robar" then
			Controlador.robar()
		elseif accion == "domar" then
			Controlador.domar()
		elseif accion == "navegar" then
			Controlador.navegar()
		elseif accion == "trabajar" then
			Controlador.alternarMacro()
		elseif accion == "diagnostico" then
			Diagnostico.alternar() -- panel del playtest (DF10-02 B)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(apretadas)
	end)

	Remotes.evento("PosCorregida").OnClientEvent:Connect(function(x: number, y: number, heading: number, idc: number, animado: boolean?)
		idCorreccion = idc
		esperandoPaso = false
		if animado then
			-- Un NPC empujó a nuestro fantasma (ForceCharMove, DF8-07 A): se desliza como un paso normal
			Personajes.caminar(miId, x, y, heading)
		else
			Personajes.teletransportar(miId, x, y, heading)
		end
	end)

	-- Encadenar pasos: el siguiente arranca exactamente cuando termina el anterior
	Personajes.alTerminarPaso = function(pid)
		if pid == miId then
			intentarPaso(Personajes.finDelPaso(miId))
		end
	end

	RunService:BindToRenderStep("AO_Controlador", Enum.RenderPriority.Input.Value + 1, function()
		if Personajes.pasoTerminado(miId) then
			intentarPaso()
		end
	end)
	RunService:BindToRenderStep("AO_Camara", Enum.RenderPriority.Character.Value + 1, function()
		local vx, vy = Personajes.posicionVisual(miId)
		Mundo.centrarEn(vx, vy)
	end)
end

return Controlador
