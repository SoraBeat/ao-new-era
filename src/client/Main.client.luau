--!strict
-- Punto de entrada del cliente: arranca los módulos en orden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Version = require(ReplicatedStorage.Shared.Version)
local Clases = require(ReplicatedStorage.Shared.Config.Clases)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local CFG = require(ReplicatedStorage.Shared.Config.Combate)
local Magia = require(ReplicatedStorage.Shared.Config.Magia)
local Teclas = require(ReplicatedStorage.Shared.Config.Teclas)
local Camara = require(script.Parent.Render.Camara)
local Mundo = require(script.Parent.Render.Mundo)
local Texturas = require(script.Parent.Render.Texturas)
local MapaMundo = require(script.Parent.UI.MapaMundo)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Personajes = require(script.Parent.Render.Personajes)
local Controlador = require(script.Parent.Jugador.Controlador)
local Mando = require(script.Parent.Jugador.Mando)
local Consola = require(script.Parent.UI.Consola)
local Hechizos = require(script.Parent.UI.Hechizos)
local Atajos = require(script.Parent.UI.Atajos)
local Inventario = require(script.Parent.UI.Inventario)
local Hud = require(script.Parent.UI.Hud)
local PanelCuenta = require(script.Parent.UI.PanelCuenta)
local Skills = require(script.Parent.UI.Skills)
local Dialogo = require(script.Parent.UI.Dialogo)
local Inicio = require(script.Parent.UI.Inicio)
local Admin = require(script.Parent.UI.Admin)
local Reglas = require(script.Parent.UI.Reglas)
local Denuncia = require(script.Parent.UI.Denuncia)
local Estadisticas = require(script.Parent.UI.Estadisticas)
local Guia = require(script.Parent.UI.Guia)
local ConfigProgresion = require(ReplicatedStorage.Shared.Config.Progresion)
local ConfigTutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local ConfigNpcs = require(ReplicatedStorage.Shared.Config.Npcs)
local DatosNpcs = require(ReplicatedStorage.Shared.Generado.Npcs) :: any
local Tienda = require(script.Parent.UI.Tienda)
local Aliados = require(script.Parent.UI.Aliados)
local Chat = require(script.Parent.UI.Chat)
local Alineacion = require(script.Parent.UI.Alineacion)
local Party = require(script.Parent.UI.Party)
local Inspeccion = require(script.Parent.UI.Inspeccion)
local Voz = require(script.Parent.Jugador.Voz)
local Clanes = require(script.Parent.UI.Clanes)
local Retos = require(script.Parent.UI.Retos)
local Cantidad = require(script.Parent.UI.Cantidad)
local ConfigTeclas = require(script.Parent.UI.ConfigTeclas)
local ChatCfg = require(ReplicatedStorage.Shared.Config.Chat)
local ConfigInv = require(ReplicatedStorage.Shared.Config.Inventario)
local ConfigComercio = require(ReplicatedStorage.Shared.Config.Comercio)
local Comercio = require(script.Parent.UI.Comercio)
local Banco = require(script.Parent.UI.Banco)
local Intercambio = require(script.Parent.UI.Intercambio)
local Mercado = require(script.Parent.UI.Mercado)
local Tutorial = require(script.Parent.UI.Tutorial)
local ObjetosInventario = require(ReplicatedStorage.Shared.Generado.ObjetosInventario) :: any
local Produccion = require(script.Parent.UI.Produccion)
local Mascotas = require(script.Parent.UI.Mascotas)
local Faccion = require(script.Parent.UI.Faccion)
local Entrenador = require(script.Parent.UI.Entrenador)
local Barco = require(script.Parent.UI.Barco)
local Quests = require(script.Parent.UI.Quests)
local Casas = require(script.Parent.UI.Casas)
local HudComun = require(script.Parent.UI.HudComun)
local Sonido = require(script.Parent.Audio.Sonido)
local Musica = require(script.Parent.Audio.Musica)
local Opciones = require(script.Parent.UI.Opciones)
local HudEditor = require(script.Parent.UI.HudEditor)
local Clima = require(script.Parent.Render.Clima)

print(`[{Version.nombre}] cliente OK — fase {Version.fase}`)

Mapas.limiteCache = 3 -- el cliente guarda los últimos 3 mapas decodificados (docs/35 §1.2)
Camara.iniciar()
Mundo.iniciar() -- antes de escuchar eventos: los personajes se dibujan sobre el lienzo (el mapa llega al unirse)
Inventario.iniciar() -- escucha Inventario / InventarioSlot antes de unirse

local miId = 0

-- Sonido y música (paquete P2, docs/29): los efectos con distancia y paneo desde el jugador, el click de todos los
-- botones, los pasos de los que se mueven y las opciones guardadas (llegan antes del menú)
Sonido.iniciar()
Tienda.iniciar() -- la tienda (Fase 23, docs/42 §8): se abre también desde el panel de personajes, antes de entrar
Aliados.iniciar() -- los puntos de la party y del clan (Fase 24, docs/43 §4): la primera lista puede llegar antes del HUD
Sonido.setPosicion(function(): (number?, number?)
	if miId ~= 0 and Personajes.de(miId) then
		return Personajes.posicionVisual(miId)
	end
	return nil, nil
end)
Sonido.engancharClicks(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
Personajes.alCaminar = Sonido.paso
Remotes.evento("Sonido").OnClientEvent:Connect(function(n: any, x: number?, y: number?)
	Sonido.tocar(n, x, y)
end)
Opciones.alCambiarNoche = Clima.setVerNoche -- antes de escuchar Audio: lo guardado trae "Ver la noche"
-- Fase 33 (docs/53 §5): la transparencia del minimapa y de los botones del celular, y las barras para cambiarla
Opciones.esTactil = Hud.interfazTactil -- (la que se armó: enchufar un teclado a mitad de la partida no la cambia)
Opciones.alCambiarTactil = Hud.setTransparencia
Opciones.alCambiarPuntero = Mando.setVelocidad -- Fase 34 (docs/54 §4): la velocidad del puntero del mando
-- Fase 38 (docs/58): acomodar la interfaz del celular. Lo guardado llega al entrar (antes de que exista el HUD)
Opciones.alAcomodar = HudEditor.abrir
HudEditor.aviso = function(texto: string)
	Consola.agregar(texto, "info")
end
Remotes.evento("HudGuardado").OnClientEvent:Connect(function(g: any)
	Hud.setInterfazGuardada(g)
end)
Remotes.evento("Audio").OnClientEvent:Connect(function(a: any)
	Opciones.recibir(a)
end)
Opciones.aviso = function(texto: string)
	Consola.agregar(texto, "info")
end
Controlador.alAudio = Opciones.alternar

Mando.preparar() -- el gamepad: el modo mando y el puntero, ya desde las pantallas de entrada (docs/37 §7.3)

-- Fase 18 (docs/37): la lluvia, el color del día y la fogata, según dónde está el jugador
Clima.iniciar(function(): (number?, number?)
	if miId ~= 0 and Personajes.de(miId) then
		return Personajes.posicionVisual(miId)
	end
	return nil, nil
end)

-- Fase 17a (docs/35 §5): dónde está el personaje, para la marca del mapa del mundo
MapaMundo.posicion = function(): (number?, number?, number?)
	local m = Mundo.mapa()
	if not m then
		return nil, nil, nil
	end
	if miId ~= 0 and Personajes.de(miId) then
		local x, y = Personajes.posicionVisual(miId)
		return m.numero, x, y
	end
	return m.numero, nil, nil
end

-- Eventos (se conectan ANTES de unirse para no perder ninguno)
Remotes.evento("PersonajeAparecio").OnClientEvent:Connect(function(id: number, datos: any)
	Personajes.crear(id, datos)
end)
Remotes.evento("PersonajeMovio").OnClientEvent:Connect(function(id: number, x: number, y: number, heading: number)
	Personajes.caminar(id, x, y, heading)
end)
Remotes.evento("PersonajeGiro").OnClientEvent:Connect(function(id: number, heading: number)
	Personajes.girar(id, heading)
end)
Remotes.evento("PersonajeSeFue").OnClientEvent:Connect(function(id: number)
	Personajes.quitar(id)
	Sonido.olvidar(id)
end)
Remotes.evento("PersonajeCambio").OnClientEvent:Connect(function(id: number, datos: any)
	Personajes.cambiar(id, datos)
	if id == miId and datos.navegando ~= nil then
		Sonido.navegando(datos.navegando == true) -- el mar, mientras navega (docs/34 §1.3)
	end
end)
Remotes.evento("Golpe").OnClientEvent:Connect(function(id: number)
	Personajes.atacar(id)
end)
Remotes.evento("Danio").OnClientEvent:Connect(function(id: number, valor: number, tipo: string?)
	local color = if valor < 0 then CFG.ColorFallo
		elseif tipo == "curar" then Magia.ColorCurar
		elseif tipo == "trabajo" then Magia.ColorTrabajo
		elseif tipo == "punal" then CFG.ColorPunal -- apuñalar y crítico (DAMAGE_PUNAL, docs/27 §3)
		else CFG.ColorDanio
	-- Fase 14a (docs/27 §2.2): si le viene una flecha, el número sale cuando llega
	Personajes.numero(id, valor, color, tipo, Personajes.esperaProyectil(id))
end)
Remotes.evento("Proyectil").OnClientEvent:Connect(function(desde: number, hasta: number, grh: number)
	Personajes.proyectil(desde, hasta, grh)
end)
Remotes.evento("Oculto").OnClientEvent:Connect(function(id: number, si: boolean)
	Personajes.setInvisible(id, si)
end)
Remotes.evento("PalabrasMagicas").OnClientEvent:Connect(function(id: number, hechizo: number)
	local h = Magia.Hechizos[hechizo]
	if h and h.palabras ~= "" then -- Invisibilidad no tiene palabras: sin globo vacío (docs/27 §12.9)
		Personajes.dialogo(id, h.palabras, Magia.ColorPalabras)
	end
	if id == miId then
		Tutorial.evento("lanzar") -- el paso "lanzá un hechizo" del tutorial (Fase 25, docs/44 §12)
	end
end)
-- Fase 14b (docs/27 §12.9): las palabras de un invisible, sobre su tile
Remotes.evento("PalabrasTile").OnClientEvent:Connect(function(x: number, y: number, hechizo: number)
	local h = Magia.Hechizos[hechizo]
	if h and h.palabras ~= "" then
		Personajes.dialogoEnTile(x, y, h.palabras, Magia.ColorPalabras)
	end
end)
Remotes.evento("BorrarDialogo").OnClientEvent:Connect(function(id: number)
	Personajes.borrarDialogo(id)
end)
Remotes.evento("Aturdido").OnClientEvent:Connect(function(si: boolean)
	Controlador.setAturdido(si)
end)
Remotes.evento("Invisibilidad").OnClientEvent:Connect(function(ticks: number)
	Hud.invisibilidad(ticks)
end)
Remotes.evento("MeditarToggle").OnClientEvent:Connect(function(meditando: boolean)
	Controlador.setMeditando(meditando)
end)
Remotes.evento("Paralisis").OnClientEvent:Connect(function(ticks: number, inmovilizado: boolean?)
	Controlador.setParalisis(ticks, inmovilizado == true)
	Hud.paralisis(ticks)
end)
-- Fase 28 (docs/48 §5): con 87 de Supervivencia, la barra con lo que les queda a los paralizados e inmovilizados
Remotes.evento("TiemposParalisis").OnClientEvent:Connect(function(lista: any)
	Personajes.tiemposParalisis(lista)
end)
-- Fase 28 (docs/48 §5.2): con 100 de Supervivencia, la barra de vida de las criaturas y de los demás jugadores
Remotes.evento("Vidas").OnClientEvent:Connect(function(lista: any, todo: any)
	Personajes.vidas(lista, todo == true)
end)
Remotes.evento("Fx").OnClientEvent:Connect(function(id: number, fx: number, vueltas: number)
	Personajes.fx(id, fx, vueltas)
end)
Remotes.evento("FxMapa").OnClientEvent:Connect(function(x: number, y: number, fx: number, vueltas: number)
	Personajes.fxEnTile(x, y, fx, vueltas)
end)
Remotes.evento("Consola").OnClientEvent:Connect(function(texto: string, tipo: string)
	Consola.agregar(texto, tipo)
	if texto == ConfigNpcs.MsgMatar then
		Tutorial.evento("matar") -- el paso "matá a una criatura" del tutorial (Fase 25, docs/44 §12)
	end
end)
-- Fase 11: objetos del piso y teclas guardadas (docs/20 §5 y §4.5)
Remotes.evento("ObjetoPiso").OnClientEvent:Connect(function(x: number, y: number, grh: number)
	Mundo.objetoPiso(x, y, grh)
end)
Remotes.evento("Teclas").OnClientEvent:Connect(function(t: any, fallo: boolean?, consola: number?)
	if typeof(consola) == "number" then
		Hud.setConsola(consola) -- el tamaño de la consola del celular (docs/23 DN-09)
	end
	if fallo then
		Consola.agregar("No se pudo cargar tu configuración de teclas.", "info")
	elseif Teclas.validar(t) then
		Controlador.setTeclas(t)
		Atajos.refrescar() -- la tecla que muestra cada casillero
	end
end)
-- Fase 12: skills (la ventana de la estrella) y aviso de subida de nivel
Remotes.evento("Skills").OnClientEvent:Connect(function(d: any)
	Skills.actualizar(d)
	-- Fase 39 (docs/59 §4): con los skills, el inventario marca con la X lo que todavía no se puede equipar
	if typeof(d) == "table" then
		Inventario.setSkills(d.valores, d.sinRequisito == true)
	end
end)
Remotes.evento("SubioNivel").OnClientEvent:Connect(function(_puntos: number)
	-- La estrella se prende con los skillpoints libres que llegan en las estadísticas (LightSkillStar)
end)
-- Fase 13a (docs/22): cambio de mapa, puertas, carteles, lo que dicen los NPCs y el viaje a hogar
local hudListo = false
local function entrarAlMapa(e: any)
	Personajes.limpiar()
	Mundo.cargar(e.mapa)
	Mundo.puertasIniciales(e.puertas or {})
	Mundo.pisoInicial(e.piso or {})
	for id, datos in e.personajes do
		Personajes.crear(tonumber(id) :: number, datos)
	end
	local yo = Personajes.de(miId)
	Sonido.navegando(yo ~= nil and yo.navegando)
	if hudListo then
		Hud.cambiarMapa(e.mapa, Mundo.mapa().nombre)
	end
	Musica.deMapa(Mundo.mapa()) -- la del mapa; si es la misma, sigue (docs/29 §4)
	-- Fase 17a (docs/35 §1.2): las hojas de terreno del mapa y, de fondo, las de los vecinos y su música
	Texturas.entrar(Mundo.mapa())
	local musicas = {}
	for _, v in Texturas.vecinos(Mundo.mapa()) do
		local meta = Mapas.meta(v)
		if meta then
			table.insert(musicas, meta.musica)
		end
	end
	Musica.precargarVecinas(musicas)
end
Remotes.evento("CambiarMapa").OnClientEvent:Connect(function(e: any)
	Controlador.setCorreccion(e.idCorreccion)
	entrarAlMapa(e)
end)
Remotes.evento("Puerta").OnClientEvent:Connect(function(x: number, y: number, cerrada: boolean)
	Mundo.puerta(x, y, cerrada)
end)
Remotes.evento("MostrarCartel").OnClientEvent:Connect(function(texto: string, grh: number)
	Hud.cartel(texto, grh)
end)
Remotes.evento("Habla").OnClientEvent:Connect(function(id: number, texto: string)
	Personajes.dialogo(id, texto, Color3.new(1, 1, 1))
end)
-- P7 (docs/34 §4.2): al bajarse de la montura, la espera para volver a montar
Remotes.evento("Montura").OnClientEvent:Connect(function(_montado: boolean, espera: number)
	HudComun.setMontura(espera)
end)
Remotes.evento("Viaje").OnClientEvent:Connect(function(seg: number)
	Controlador.setViaje(seg)
	Hud.viaje(seg)
end)
-- docs/23: el chat (globo sobre la cabeza + eco en la consola), los puntitos de "escribiendo" y la ventana de bando
-- Hablar, gritar y susurrar llegan por TextChatService ya filtrados para este jugador (docs/23 DN-05 A)
local AVISOS_CHAT: { [Enum.TextChatMessageStatus]: string } = {
	[Enum.TextChatMessageStatus.Floodchecked] = ChatCfg.MsgSpam,
	[Enum.TextChatMessageStatus.InvalidPrivacySettings] = ChatCfg.MsgSinChat,
}
TextChatService.MessageReceived:Connect(function(m: TextChatMessage)
	local fuente = m.TextSource
	if not fuente then
		return
	end
	local jugador = Players:GetPlayerByUserId(fuente.UserId)
	if m.Status ~= Enum.TextChatMessageStatus.Success then
		if jugador == Players.LocalPlayer and m.Status ~= Enum.TextChatMessageStatus.Sending then
			Consola.agregar(AVISOS_CHAT[m.Status] or ChatCfg.MsgNoEnviado, "info")
		end
		return
	end
	local id = jugador and jugador:GetAttribute("AOId")
	if typeof(id) ~= "number" or m.Text == "" then
		return
	end
	local tipo = if ChatCfg.Colores[m.Metadata] then m.Metadata else "hablar"
	local canal = m.TextChannel
	if tipo == "party" then
		-- /PMSG (BroadCastParty, clsParty.cls:175-189): " [Nombre] texto" en la consola, sin globo (docs/28 §2.3)
		local nombreP = tostring((jugador :: Player):GetAttribute("AONombre") or "")
		-- Fase 23 (docs/42 §3.3, D23-10 A): el de un grupo que no es el mío le llega a un administrador que escucha
		local mio = canal ~= nil and Players.LocalPlayer:GetAttribute("AOParty") == canal.Name
		Consola.agregar(`{if mio then "" else " [grupo]"} [{nombreP}] {m.Text}`, "party")
		return
	end
	if tipo == "clan" then
		-- /CMSG por el canal del clan (Fase 23, docs/42 §3.4): "Nombre> texto" en la consola (PrepareMessageGuildChat,
		-- Protocol.bas:7428) y, para los del clan que lo ven, el globo amarillo sobre la cabeza (SendToUserGuildArea)
		local nombreC = tostring((jugador :: Player):GetAttribute("AONombre") or "")
		local mio = canal ~= nil and Players.LocalPlayer:GetAttribute("AOClan") == canal.Name
		Consola.agregar(`{if mio or not canal then "" else `[clan {string.sub(canal.Name, 6)}] `}{nombreC}> {m.Text}`, "guildMsg")
		if mio and Personajes.de(id) then
			Personajes.dialogo(id, `< {m.Text} >`, Color3.fromRGB(255, 255, 0))
		end
		return
	end
	local color = ChatCfg.Colores[tipo]
	local p = Personajes.de(id)
	local nombre = if p then p.nombre else tostring((jugador :: Player):GetAttribute("AONombre") or "")
	-- Fase 23 (docs/42 §3.3, D23-09 A): lo que un administrador oye de lejos con "Escuchar todo". El servidor le avisó
	-- de qué mapa viene; va a la consola con el mapa adelante, sin globo.
	local lejos = if tipo == "susurro" then nil else Admin.oido(fuente.UserId)
	if lejos then
		local donde = if lejos.nombre ~= "" then lejos.nombre else `mapa {lejos.mapa}`
		Consola.agregarChat(`[{donde}] {nombre}`, Personajes.colorDeEstado(if tipo == "muerto" then "muerto" else "neutral"), m.Text, color)
		return
	end
	local estadoNombre = if tipo == "muerto" then "muerto"
		elseif p and p.atacable then "atacable" -- Fase 19 (docs/38 §5)
		elseif p then p.estado or "neutral"
		else "neutral"
	Personajes.escribiendo(id, false)
	if tipo == "susurro" and m.TextChannel then
		Intercambio.chat(m.TextChannel.Name, nombre, m.Text) -- el chat de la ventana de intercambio (docs/41 §5.2)
	end
	Personajes.dialogo(id, m.Text, color) -- el susurro también, en azul (solo lo reciben los dos)
	Consola.agregarChat(nombre, Personajes.colorDeEstado(estadoNombre), m.Text, if tipo == "susurro" then ChatCfg.ColorSusurroConsola else color)
end)
Remotes.evento("Escribiendo").OnClientEvent:Connect(function(id: number, si: boolean)
	Personajes.escribiendo(id, si)
end)
-- Fase 29 (docs/49 §8): un mensaje que llega por el servidor y no por TextChatService. Se dibuja igual que los demás.
Remotes.evento("Dicho").OnClientEvent:Connect(function(id: any, texto: any, tipoDicho: any, nombreLejos: any, mapaLejos: any)
	if typeof(id) ~= "number" or typeof(texto) ~= "string" or texto == "" then
		return
	end
	local tipo = if tipoDicho == "gritar" or tipoDicho == "muerto" then tipoDicho else "hablar"
	local color = ChatCfg.Colores[tipo]
	if typeof(nombreLejos) == "string" then
		Consola.agregarChat(`[mapa {tostring(mapaLejos)}] {nombreLejos}`, Personajes.colorDeEstado(if tipo == "muerto" then "muerto" else "neutral"), texto, color)
		return
	end
	local p = Personajes.de(id)
	if not p then
		return
	end
	local estadoNombre = if tipo == "muerto" then "muerto" elseif p.atacable then "atacable" else p.estado or "neutral"
	Personajes.escribiendo(id, false)
	Personajes.dialogo(id, texto, color)
	Consola.agregarChat(p.nombre, Personajes.colorDeEstado(estadoNombre), texto, color)
end)
Remotes.evento("AbrirAlineacion").OnClientEvent:Connect(function()
	HudComun.setCaminoPendiente(true)
	-- Fase 26 (docs/46 §3.3): el servidor la pide en un momento de calma y la vuelve a pedir cada tanto mientras siga
	-- pendiente; si ya está abierta no se rearma (se perdería la confirmación a medio hacer)
	if not Alineacion.abierta() then
		Alineacion.abrir()
	end
end)
-- Con la ventana obligatoria abierta no se juega: ni teclas ni pasos (el servidor tampoco los acepta). Tampoco
-- mientras se acomoda la interfaz del celular (Fase 38): un toque fuera del velo no es un toque en el mapa.
Controlador.bloqueado = function(): boolean
	return Alineacion.abierta() or HudEditor.abierto()
end
-- Fase 15a (docs/28 §2.3): la ventana "Grupo"
Remotes.evento("Party").OnClientEvent:Connect(function(tipo: string, d: any)
	Party.evento(tipo, d)
end)
-- Fase 15b (docs/28 §3): los clanes
Remotes.evento("ClanEvento").OnClientEvent:Connect(function(tipo: string, d: any)
	if tipo == "globo" and typeof(d) == "table" then
		Personajes.dialogo(d.id, d.texto, Color3.fromRGB(255, 255, 0)) -- el /CMSG sobre la cabeza, en amarillo
	else
		Clanes.evento(tipo, d)
	end
end)
-- Fase 15c (docs/28 §14): los retos
Remotes.evento("RetoEvento").OnClientEvent:Connect(function(tipo: string, d: any)
	Retos.evento(tipo, d)
end)
Retos.aviso = function(texto: string)
	Consola.agregar(texto, "info")
end
Party.alIntercambiar = Intercambio.pedir -- "Intercambiar" en el menú sobre otro jugador (Fase 22, docs/41 §5)
-- Fase 23 (docs/42): las reglas del juego y las denuncias
Party.alDenunciar = Denuncia.abrir
Chat.alDenunciar = Denuncia.abrir
Chat.alReglas = function()
	Reglas.abrir()
end
Opciones.alReglas = function()
	Reglas.abrir()
end
-- Fase 23 (docs/42 §8.4): la tienda (/TIENDA; los botones la abren solos)
Chat.alTienda = function()
	Tienda.abrir()
end
-- Fase 28 (docs/48 §2): el botón derecho sobre una criatura ofrece "Inspeccionar". Los dos botones (el de los
-- jugadores y el de las criaturas) no conviven: mostrar uno saca el otro.
Controlador.alClickearJugador = function(id: number, nombre: string, pos: Vector2)
	Inspeccion.alClickearMapa()
	Party.alClickearJugador(id, nombre, pos)
end
Controlador.alClickearNpc = function(id: number, numero: number, pos: Vector2)
	Party.alClickearMapa()
	Inspeccion.alClickearNpc(id, numero, pos)
end
Controlador.alClickearMapa = function()
	Party.alClickearMapa()
	Inspeccion.alClickearMapa()
end
Chat.aviso = function(texto: string)
	Consola.agregar(texto, "info")
end
Chat.bloqueada = function(): boolean
	return Controlador.capturando == true or Cantidad.abierto() or Skills.abierta() or ConfigTeclas.abierta() or Alineacion.abierta()
end

-- Fase 13b (docs/22 §5-§9): comercio, banco, tirar oro y los hechizos que se aprenden con pergaminos
Comercio.iniciar()
Banco.iniciar()
Intercambio.iniciar() -- el intercambio entre jugadores (Fase 22, docs/41 §5)
Mercado.iniciar() -- el Subastador: el mercado entre jugadores (Fase 25, docs/44 §10)
Produccion.iniciar() -- herrería y carpintería (Fase 16b, docs/32 §7)
Produccion.alConstruir = function()
	Controlador.cortarMacro() -- empezar a construir apaga el F8 de talar o fundir
end
Mascotas.iniciar() -- la ventana de las mascotas (Fase 16c, docs/33 §6)
Faccion.iniciar() -- la ventana de la Armada Real y la Legión Oscura (P8, docs/36 §10)
Entrenador.iniciar() -- la ventana del entrenador (Fase 20, docs/39 §4)
Barco.iniciar() -- los viajes en barco con el pirata (Fase 39, docs/59 §5)
Quests.iniciar() -- las ventanas de las quests (Fase 20, docs/39 §2.6)
Casas.iniciar() -- la ventana de propiedades (Fase 20, docs/39 §3.4)
Admin.iniciar() -- /ADMIN (docs/25)
Remotes.evento("HechizoSlot").OnClientEvent:Connect(function(slot: number, id: number)
	Hechizos.actualizar(slot, id)
end)

local ultimasEstadisticas: any = nil
local function oroActual(): number
	return if ultimasEstadisticas then ultimasEstadisticas.oro or 0 else 0
end
Comercio.oro = oroActual
Banco.oro = oroActual
Intercambio.oro = oroActual
Mercado.oro = oroActual
Comercio.aviso = function(texto: string)
	Consola.agregar(texto, "info")
end
HudComun.tocarOro = function()
	local oro = oroActual()
	if oro <= 0 or Comercio.abierta() or Banco.abierta() or Intercambio.abierta() or Mercado.abierta() then
		return
	end
	if ultimasEstadisticas and (ultimasEstadisticas.elv or 1) < ConfigComercio.NivelTirarOro then
		Consola.agregar(ConfigComercio.MsgNivelTirarOro, "info") -- docs/24 DA-13 A
		return
	end
	-- Fase 24 (docs/43 §13): sin tope; desde ConfirmarTirarOro pregunta antes de tirar
	Cantidad.abrir(oro, function(n: number)
		n = math.min(math.floor(n), oroActual())
		if n < 1 then
			return
		end
		if n < ConfigComercio.ConfirmarTirarOro then
			Remotes.evento("Tirar"):FireServer(ConfigInv.SlotOro, n)
			return
		end
		task.spawn(function()
			local texto = string.format("%d", n):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
			if Dialogo.confirmar(string.format(ConfigComercio.MsgConfirmarTirarOro, texto), "Tirar oro") then
				Remotes.evento("Tirar"):FireServer(ConfigInv.SlotOro, math.min(n, oroActual()))
			end
		end)
	end, oro)
end
Remotes.evento("Estadisticas").OnClientEvent:Connect(function(s: any)
	ultimasEstadisticas = s
	Intercambio.refrescarOro()
	Chat.setMuerto(s.muerto == true)
	Hud.estadisticas(s)
	Controlador.setEstadisticas(s)
	Inventario.setUsables(s.slots) -- Fase 16b: la mochila
end)

-- Panel de cuenta (Fase 12, docs/21 §2): los eventos de arriba ya escuchan mientras se elige. En Studio, el atributo
-- "ClasePrueba" del Workspace entra directo con un personaje de prueba (las pruebas automáticas de fases anteriores).
local function pedidoDePrueba(): any
	if RunService:IsStudio() then
		local c = workspace:GetAttribute("ClasePrueba")
		if typeof(c) == "string" and Clases.datos[c] then
			return { prueba = c }
		end
	end
	return nil
end

-- Pantalla de carga (docs/26, ReplicatedFirst/Carga): esperamos a que precargue todas las texturas. Si en 120 s no
-- terminó (no debería: ofrece "Entrar igual" a los 25), seguimos igual.
do
	local ReplicatedFirst = game:GetService("ReplicatedFirst")
	local t0 = os.clock()
	while not ReplicatedFirst:GetAttribute("Precargado") and os.clock() - t0 < 120 do
		task.wait(0.1)
	end
end

-- Fase 20 (docs/39 §7): el que llega viajando (a la sala de un clan contra clan, o de vuelta) entra con el mismo
-- personaje, sin pasar por la pantalla de inicio ni por la lista. Lo que viene con el viaje es solo una pista: que el
-- personaje sea de esta cuenta lo mira el servidor. Vale una vez: si no entra, sigue el panel de siempre.
local pedidoDeViaje: any = nil
local llegaAPruebas = false -- Fase 37 (docs/57 §7): ya tocó "Jugar" en el servidor del que viene
do
	local ok, d = pcall(function()
		return game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	end)
	if ok and typeof(d) == "table" and (d.ao == "cvc" or d.ao == "volver") then
		if typeof(d.prueba) == "string" and Clases.datos[d.prueba] then
			pedidoDeViaje = { prueba = d.prueba }
		elseif typeof(d.pj) == "number" or typeof(d.pj) == "string" then
			pedidoDeViaje = { id = d.pj }
		end
	elseif ok and typeof(d) == "table" and d.ao == "pruebas" then
		llegaAPruebas = true
	end
end
-- El que llega viajando se saltea la pantalla de inicio solo si la puerta lo deja entrar acá (antes de la apertura,
-- el que vuelve de una sala cae en un servidor normal, que está cerrado: ahí va la pantalla de inicio, que lo lleva
-- al mundo de pruebas)
if (pedidoDeViaje or llegaAPruebas) and not Inicio.pasa(8) then
	pedidoDeViaje, llegaAPruebas = nil, false
end

-- Pantalla de inicio (docs/24 DA-07 A): antes del panel de personajes (no en las pruebas automáticas de Studio)
if not pedidoDePrueba() and not pedidoDeViaje and not llegaAPruebas then
	Inicio.mostrar()
end

-- El tutorial (Fase 25, docs/44 §12; el de la Fase 22, docs/41 §6, era solo carteles). Se abre solo la primera vez
-- que la cuenta entra con un personaje recién creado (lo decide el servidor) y, cuando se quiera, desde Opciones.
local function abrirTutorial()
	Tutorial.abrir({
		tactil = Hud.esTactil(),
		magia = function(): boolean
			return ultimasEstadisticas ~= nil and (ultimasEstadisticas.maxMana or 0) > 0
		end,
		arco = function(): boolean
			for _, d in Inventario.slots() do
				local o = ObjetosInventario[d.obj]
				if d.equipado and o and o.tipo == "arma" and o.proyectil then
					return true
				end
			end
			return false
		end,
		teclas = Controlador.teclas,
		posicion = Controlador.posicion,
		parte = Hud.parte,
		rectVista = Hud.rectVista,
		puedeViajar = function(): boolean
			local s, m = ultimasEstadisticas, Mundo.mapa()
			return s ~= nil and m ~= nil
				and ConfigTutorial.puedeViajar(s.elv or 1, ConfigProgresion.LimiteNewbie, m.numero, s.muerto == true, false)
		end,
		comercioAbierto = Comercio.abierta,
		experiencia = function(): number
			local s = ultimasEstadisticas
			return if s then (s.elv or 1) * 1e10 + (s.exp or 0) else 0
		end,
		nombreNpc = function(numero: number): string?
			local d = DatosNpcs[numero]
			return if d then d.nombre else nil
		end,
		viajar = function()
			Remotes.evento("TutorialAccion"):FireServer("viajar")
		end,
		premio = function(volver: boolean)
			Remotes.evento("TutorialAccion"):FireServer("premio", volver)
		end,
	})
end
-- Usar o equipar un objeto (y, si es una poción, tomarla): dos de los objetivos del tutorial
Inventario.alPedirUso = function(slot: number)
	if not Tutorial.abierto() then
		return
	end
	local d = Inventario.slots()[slot]
	local o = if d then ObjetosInventario[d.obj] else nil
	Tutorial.evento("usar")
	if o and o.tipo == "pocion" then
		Tutorial.evento("pocion")
	end
end

-- Fase 25 (docs/44 §7): el botón del HUD y /CAMINO vuelven a abrir la ventana del camino si sigue pendiente. Fase 26
-- (docs/46 §3.3): la ventana es obligatoria y no se cierra sola; quedan por si algo la sacó de pantalla.
local MSG_CAMINO_ELEGIDO = "Ya elegiste tu camino. Para cambiarlo: jura ante el Rey (Banderbill) o el Demonio (Arkhein), o /ABANDONAR en Ullathorpe."
local MSG_CAMINO_NEWBIE = "Vas a elegir tu camino al llegar al nivel 13."
HudComun.alCamino = function()
	Alineacion.abrir()
end
Alineacion.alElegir = function()
	HudComun.setCaminoPendiente(false)
end
-- Fase 25 (docs/44 §11): la guía del juego (/GUIA y el botón de Opciones; en el menú de inicio la abre Inicio)
Chat.alGuia = function()
	Guia.abrir()
end
Opciones.alGuia = function()
	Guia.abrir()
end
-- Fase 26 (docs/46 §10): también jugando, con F1 y con el botón "Guía" (PC) o el Menú (celular)
Controlador.alGuia = function()
	Guia.abrir()
end
Opciones.alSalir = function()
	Remotes.evento("Comando"):FireServer("SALIR", nil) -- "Cambiar de personaje" es /SALIR (Fase 25, docs/44 §9)
end
Chat.alCamino = function()
	if HudComun.caminoPendiente() then
		Alineacion.abrir()
	elseif ultimasEstadisticas and (ultimasEstadisticas.elv or 1) <= ConfigProgresion.LimiteNewbie then
		Consola.agregar(MSG_CAMINO_NEWBIE, "info")
	else
		Consola.agregar(MSG_CAMINO_ELEGIDO, "info")
	end
end

-- ─── La sesión (Fase 25, docs/44 §9) ─────────────────────────────────────────
-- Entrar con un personaje, jugar y, con /SALIR, volver a la pantalla de personajes para entrar con el mismo o con
-- otro, sin salir del juego. Lo que se arma una sola vez (el HUD, el teclado, el mando, la voz) queda armado; lo que
-- es de cada personaje se pone al entrar y se limpia al salir.
local salio = Instance.new("BindableEvent")
local enMundo = false
Remotes.evento("Salio").OnClientEvent:Connect(function()
	if enMundo then
		salio:Fire()
	end
end)
Remotes.evento("Salida").OnClientEvent:Connect(function(seg: number)
	HudComun.setSalida(if typeof(seg) == "number" then seg else 0)
end)

-- Todo lo que puede haber quedado abierto del personaje anterior
local function cerrarTodo()
	for _, cerrar in {
		Comercio.cerrar, Banco.cerrar, Intercambio.cerrar, Mercado.cerrar, Produccion.cerrar, Faccion.cerrar, Entrenador.cerrar, Barco.cerrar, Quests.cerrar,
		Casas.cerrar, Admin.cerrar, Tienda.cerrar, Opciones.cerrar, Alineacion.cerrar, Cantidad.cerrar, Skills.cerrar,
		Tutorial.cerrar, MapaMundo.cerrar, Estadisticas.cerrar, Reglas.cerrar, Guia.cerrar, Denuncia.cerrar, Clanes.cerrarTodo,
		Inspeccion.cerrar,
		Party.reiniciar, Retos.reiniciar, Mascotas.limpiar, Consola.limpiar, HudComun.cerrarCartel,
		Intercambio.olvidarPedido, Admin.alSalir,
		function()
			ConfigTeclas.cerrar(Controlador)
		end,
		function()
			HudComun.setMontura(0)
		end,
	} :: { any } do
		local ok, err = pcall(cerrar)
		if not ok then
			warn(`[Cliente] al volver a la pantalla de personajes: {err}`)
		end
	end
end

local montado = false
local primeraVez = true
local salioEn = -math.huge -- cuándo volvió a la pantalla de personajes (el servidor pide un respiro antes de entrar de nuevo)
local RESPIRO_TRAS_SALIR = 3.3
while true do
	local estado: any = nil
	while not estado do
		-- (el atajo de las pruebas de Studio y el del que llega viajando valen solo la primera vez)
		local pedido = (if primeraVez then pedidoDePrueba() or pedidoDeViaje else nil) or PanelCuenta.elegir()
		pedidoDeViaje = nil
		local falta = RESPIRO_TRAS_SALIR - (os.clock() - salioEn)
		if falta > 0 then
			task.wait(falta) -- (eligió muy rápido: se espera acá, sin el cartel de "Espera un momento")
		end
		local r = Remotes.funcion("Unirse"):InvokeServer(pedido)
		if r and r.error then
			Dialogo.aviso(r.error)
			if primeraVez and pedidoDePrueba() then
				task.wait(1)
			end
		else
			estado = r
		end
	end
	primeraVez = false
	miId = estado.miId
	enMundo = true
	entrarAlMapa(estado)
	local yo = estado.personajes[tostring(miId)]
	local clase = estado.clase or (yo and yo.clase) or ""
	Tienda.personaje = { clase = clase, raza = estado.raza or "" } -- la lista del Kit de tu clase (docs/42 §11)
	local ctx = {
		nombre = yo and yo.nombre or "",
		clase = clase,
		raza = estado.raza,
		genero = estado.genero,
		mapa = estado.mapa,
		mapaNombre = Mundo.mapa().nombre,
		posicion = Controlador.posicion,
		lanzar = Controlador.lanzar,
		seguro = Controlador.seguro,
		abrirSkills = Skills.alternar,
	}
	if not montado then
		Controlador.iniciar(miId)
		Mando.iniciar(miId) -- el gamepad (Fase 18, docs/37 §7)
		Voz.iniciar(miId) -- chat de voz por cercanía (docs/28 §11)
		Tienda.apariencia = function(): any? -- la vista previa de una skin sobre el personaje (docs/42 §9.1)
			local pj = Personajes.de(miId)
			return if pj and not pj.muerto and not pj.navegando then pj.apariencia else nil
		end
		Hechizos.iniciar(estado.hechizos or {})
		Atajos.iniciar(estado.atajos) -- los atajos guardados del personaje (Fase 22, docs/41 §1)
		Hud.iniciar(ctx, Controlador)
		Opciones.alTutorial = abrirTutorial
		montado = true
	else
		Controlador.reiniciar()
		Hechizos.reiniciar(estado.hechizos or {})
		Atajos.iniciar(estado.atajos)
		Atajos.refrescar()
		Hud.setPersonaje(ctx)
		Hud.mostrar(true)
	end
	Controlador.capturando = false
	if ultimasEstadisticas then
		Hud.estadisticas(ultimasEstadisticas) -- llegaron antes de armar el HUD
	end
	hudListo = true
	Hud.cambiarMapa(estado.mapa, Mundo.mapa().nombre)
	-- 13 o más y todavía no eligió bando (docs/23 DN-02 A). Fase 26 (docs/46 §3.3): la ventana la pide el servidor
	-- (AbrirAlineacion) cuando hay calma, en un segundo o dos si entró en una ciudad
	HudComun.setCaminoPendiente(estado.elegirAlineacion == true)
	if estado.tutorial then
		-- Los pasos dependen del maná y de si tiene un arco puesto: se espera a que lleguen las estadísticas y el
		-- inventario (un momento después de entrar), con un tope por si algo no llega
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 3 and (ultimasEstadisticas == nil or next(Inventario.slots()) == nil) do
				task.wait(0.1)
			end
			if enMundo then
				abrirTutorial()
			end
		end)
	end

	salio.Event:Wait()

	-- /SALIR: de vuelta a la pantalla de personajes
	salioEn = os.clock()
	enMundo = false
	Controlador.capturando = true -- el teclado, los clicks y el mando no le llegan al juego mientras está el panel
	cerrarTodo()
	Controlador.reiniciar()
	Hud.mostrar(false)
	Personajes.limpiar()
	Personajes.tiemposParalisis({}) -- Fase 28: las barras de parálisis son de ese personaje; el que entra después empieza sin ninguna
	Personajes.vidas({}, true) -- y las de vida
	HudComun.setSalida(0)
	HudComun.setCaminoPendiente(false)
	HudComun.setMuerto(false)
	Hud.viaje(0)
	Hud.paralisis(0)
	Hud.invisibilidad(0)
	Sonido.navegando(false)
	Musica.creacion(false) -- el himno del menú
	ultimasEstadisticas = nil
	Tienda.personaje = nil
end
