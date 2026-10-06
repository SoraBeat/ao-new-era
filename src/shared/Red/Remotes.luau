--!strict
--[[
	Remotes — canales de red entre cliente y servidor. El servidor los crea; el cliente los espera.

	Cliente → servidor
		Cuenta          (RemoteFunction) () → { personajes = { resumen }, probador, max } | { error }   (Fase 12)
		TirarDados      (RemoteFunction) () → { Fuerza, Agilidad, Inteligencia, Carisma, Constitucion }
		CrearPersonaje  (RemoteFunction) ({ nombre, raza, genero, clase, cabeza }) → { ok, personajes? , error? }
		BorrarPersonaje (RemoteFunction) (id, nombreEscrito) → { ok, personajes?, error? }
		Unirse      (RemoteFunction)  ({ id } | { prueba = clase }) → { miId, mapa, personajes = { [id] = datos },
		                                piso = { ["i"] = grh }, hechizos = { id… } } | { error }
		AsignarSkills ({ [clave] = puntos })   -- la ventana de skills (Fase 12)
		Caminar     (heading, idCorreccion)
		Girar       (heading)
		Atacar      ()                       -- golpe al tile de enfrente
		Seguro      ()                       -- activa / desactiva el seguro
		Lanzar      (slot, x, y, exacto?)    -- hechizo del slot sobre el tile clickeado (DF7-03 B); exacto = el cliente
		                                     -- apuntó sobre el dibujo de un personaje (DF11-02 C)
		Mirar       (x, y, exacto?)          -- click simple sobre el mapa: LookatTile (DF7-08)
		Meditar     (quiere?)                -- nil = toggle (F6); false = dejar de meditar (flecha, DF7-06 B)
		Usar        (slot)                   -- usar el objeto del slot (U, doble click, botón Usar; docs/17 §7)
		Tirar       (slot, cantidad)         -- al tile propio (docs/20 §5.2)
		Agarrar     ()                       -- del tile propio (§5.3)
		Equipar     (slot)                   -- equipa o desequipa (§6.2)
		GuardarTeclas ({ accion = "Tecla" }) -- configuración de teclas (DF11-04 A)
		ElegirAlineacion ("ciudadano" | "neutral" | "criminal")   -- la ventana de bando, la primera vez (docs/23)
		Comando     ("NOMBRE")               -- /COMANDO escrito en el chat (docs/23 DN-07)
		Escribiendo (si)                     -- los puntitos sobre la cabeza
		GuardarConsola (n)                   -- tamaño de la consola del celular (índice de Chat.TamanosConsola)
		Susurrar    (RemoteFunction) (nick) → nombreCanal | (nil, aviso)   -- abre el canal privado del susurro
		RenombrarPersonaje (RemoteFunction) (id, nombre) → { ok, personajes?, error? }   -- nombre que no pasa el filtro
		Comprar(slot, cant), Vender(slotInv, cant), CerrarComercio()          -- tienda (Fase 13b, ComercioService)
		Depositar(slotInv, cant), Retirar(slotBanco, cant), DepositarOro(cant), RetirarOro(cant), CerrarBanco()
		Tirar(36, cant)                      -- tirar oro (Config.Inventario.SlotOro)
		Admin(accion, a, b, c)               -- el panel de Admin, solo con personaje de prueba (docs/25)
		Disparar    (x, y, exacto?)          -- arco o Cuchillas sobre el tile clickeado (Fase 14a, docs/27 §2)
		Ocultarse   ()                       -- tecla O (docs/27 §5)
		Robar       (x, y, exacto?)          -- sobre el tile clickeado, con el cursor de robar (docs/27 §6)
		Trabajar    (skill, x, y)            -- talar, pescar o minar en el tile clickeado (Fase 16a, docs/31 §2); FundirMetal y Herreria (16b)
		Construir(oficio, obj, total, porCiclo), Mejorar(origen, total), PararTrabajo()   -- la cola de producción (Fase 16b, docs/32)
		Domar       (x, y, exacto?, id?)     -- con el cursor de domar sobre la criatura (Fase 16c, docs/33 §1.3)
		OrdenMascota(slot, accion)           -- "quieto" | "acompanar" | "liberar" desde la ventana Mascotas (docs/33 §6)
		(hablar y gritar van por TextChatService, canal CanalesAO.AO, con el tipo en Metadata)
	Servidor → cliente
		PersonajeAparecio (id, datos)
		PersonajeMovio    (id, x, y, heading)
		PersonajeGiro     (id, heading)
		PersonajeSeFue    (id)
		PosCorregida      (x, y, heading, idCorreccion, animado?)   -- solo al dueño; animado = empujón de un NPC (DF8-07)
		Estadisticas      ({ hp, maxHp, sta, maxSta, mana, maxMana, seguro, muerto, …, exp, oro, elv, elu, fuerza, agilidad })   -- solo al dueño
		Consola           (texto, tipo)
		Golpe             (id)                  -- animación de ataque del arma
		Danio             (id, valor, tipo?)    -- número flotante; valor < 0 = "Fallo"; tipo "curar" | "trabajo"
		Fx                (id, fx, vueltas)     -- fx 0 = apagar el FX persistente; vueltas -1 = infinito
		PersonajeCambio   (id, { apariencia, muerto })
		PalabrasMagicas   (id, hechizo)         -- diálogo sobre la cabeza del que lanza
		MeditarToggle     (meditando)           -- solo al dueño
		Paralisis         (ticks, inmovilizado?)   -- solo al dueño; 0 = libre; inmovilizado = puede girar (Fase 14b)
		FxMapa            (x, y, fx, vueltas)   -- FX en el piso (un hechizo que mata a un NPC)
		Inventario        ({ ["slot"] = { obj, cant, equipado } })   -- solo al dueño: todo el inventario
		InventarioSlot    (slot, { obj, cant, equipado }?)          -- solo al dueño: un slot (nil = vacío)
		Diagnostico       ({ golpe, hechizo, usar, golpeUsar, pasos, piso })   -- solo al dueño: rechazos del servidor (DF10-02 B)
		ObjetoPiso        (x, y, grh)           -- a todos: objeto del piso creado o borrado (grh 0)
		Teclas            ({ accion = "Tecla" }?)   -- solo al dueño, al entrar: la configuración guardada (DF11-04 A)
		Skills            ({ valores, libres, asignados, clase })   -- solo al dueño: al entrar y al cambiar (Fase 12)
		SubioNivel        (puntos)              -- solo al dueño: prende la estrella de skills (WriteLevelUp)
		AbrirAlineacion   ()                    -- solo al dueño: mostrar la ventana de bando (docs/23)
		Escribiendo       (id, si)              -- a los del área: puntitos sobre la cabeza
		Comercio          ("abrir", {…} | "slot", i, item? | "skill", n | "cerrar")   -- solo al dueño (Fase 13b)
		Banco             ("abrir", {…} | "slot", i, item? | "oro", n | "cerrar")     -- solo al dueño
		HechizoSlot       (slot, hechizo)       -- solo al dueño: aprendió un hechizo con un pergamino (0 = vacío)
		AdminPanel        ({ mod = { rango, jugadores, … }, pruebas = { objetos, skills, … }? })   -- abre el panel de
		                                        -- administración (Fase 23, docs/42); pruebas, solo con personaje de prueba
		PedirObjetivo     (skill)               -- solo al dueño: armar el cursor ("Proyectiles" | "Robar"; Fase 14a; "Talar" | "Pesca" | "Mineria", 16a)
		Proyectil         (desde, hasta, grh)   -- a los del área: la flecha o la cuchilla que viaja (docs/27 §2)
		Oculto            (id, si)              -- al dueño: se ve translúcido (docs/27 §5); a los demás el personaje
		                                        -- desaparece con PersonajeSeFue y vuelve con PersonajeAparecio
		Aturdido          (si)                  -- solo al dueño: camina al azar (docs/27 §12.6)
		Invisibilidad     (ticks)               -- solo al dueño: lo que le queda al hechizo (0 = terminó; §12.9)
		PalabrasTile      (x, y, hechizo)       -- a los que no ven al que lanza (invisible): el diálogo sobre su tile
		BorrarDialogo     (id)                  -- a los del área: "cartelear", le saca el globo a ese personaje
		Mascotas          ({ { slot, nombre, hp, maxHp, invocada, restante, esperando, quieta } })   -- solo al dueño (Fase 16c)
		Estadisticas.dopas: ticks que le quedan al efecto de pociones y hechizos de atributos (0 = ninguno)

		Party             ("estado" | "abrir", { lider, miembros = { { nombre, exp } }, total }?)   -- solo al dueño: la
		                                        -- ventana "Grupo" (nil = ya no está en party; docs/28 §2.3)

	Cliente → servidor (Fase 14b, correcciones)
		Cartelear         ()                    -- habló solo con espacios: borrar su globo

	Cliente → servidor (correcciones de la 15a, docs/28 §10)
		MoverHechizo      (arriba, slot)        -- las flechas de la lista: intercambia con el de arriba o abajo
		MoverItem         (desde, hasta)        -- arrastrar con el botón derecho: intercambia los dos slots
		MoverBanco        (desde, hasta)        -- Fase 31: el botón "Mover" del banco o del baúl abierto; intercambia
		                                        -- los dos lugares enteros (el servidor contesta con dos Banco("slot"))
		PartyAccion       ("invitar", id) | ("responder", acepta) | ("porcentajes", { [nombre] = % } | nil)
	Servidor → cliente: Party también manda ("invitacion", { lider, segundos }) al invitado

	Clanes (Fase 15b, docs/28 §3)
		Clan (función)    (accion, a, b) → datos o { ok } / { error }: panel, detalles, fundar, puedeFundar, solicitar,
		                  ficha, aceptar, rechazar, echar, salir, cerrar, noticias, codex, textos
		ClanEvento        S→C ("abrir" | "fundar" | "refrescar" | "noticias", d | "aviso", texto | "globo", { id, texto })
		PersonajeCambio.clan: el nombre del clan bajo el nombre (false = sin clan)

	Retos (Fase 15c, docs/28 §4 y §14)
		Reto (función)    (accion, datos) → { ok, mensaje } / { error } / { lista }: invitar ({ modo, oponentes, aliados,
		                  oro }), aceptar (invitador?), rechazar, jugadores (los nombres para elegir)
		RetoEvento        S→C ("abrir" | "invitacion", { de, texto, segundos } | "cerrarInvitacion" | "empieza", { arena }
		                  | "cuenta", n | "termina")

	Sonido y música (paquete P2, docs/29)
		Sonido            S→C (n, x?, y?): el WAV n del original en el tile (x, y) del mapa del jugador; sin x,y = plano
		Audio             S→C ({ musica, volMusica, sonidos, volSonidos }?): las opciones guardadas, al entrar al juego
		GuardarAudio      C→S (lo mismo): el servidor valida y lo guarda con las preferencias

	Los NPCs (Fase 8) usan los mismos eventos de personajes: ids negativos, datos con npc = true.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTOS = {
	"Caminar", "Girar", "PersonajeAparecio", "PersonajeMovio", "PersonajeGiro", "PersonajeSeFue", "PosCorregida",
	-- Combate (Fase 6)
	"Atacar", "Seguro", "Estadisticas", "Consola", "Golpe", "Danio", "Fx", "PersonajeCambio",
	-- Magia (Fase 7)
	"Lanzar", "Mirar", "Meditar", "PalabrasMagicas", "MeditarToggle", "Paralisis",
	-- NPCs (Fase 8)
	"FxMapa",
	-- HUD e inventario (Fase 9)
	"Usar", "Inventario", "InventarioSlot",
	-- Playtest (Fase 10)
	"Diagnostico",
	-- Ajustes del playtest (Fase 11)
	"Tirar", "Agarrar", "Equipar", "ObjetoPiso", "Teclas", "GuardarTeclas",
	-- Personaje persistente (Fase 12)
	"AsignarSkills", "Skills", "SubioNivel",
	-- Ciudad (Fase 13a, docs/22 §12.1)
	"CambiarMapa", "Puerta", "Accion", "MostrarCartel", "Habla", "Hogar", "Viaje",
	-- Alineación y chat (docs/23)
	"AbrirAlineacion", "ElegirAlineacion", "Comando", "Escribiendo", "GuardarConsola",
	-- Fase 25 (docs/44 §9): /SALIR. Salida S→C (segundos que faltan; 0 = cancelada); Salio S→C: ya está fuera del
	-- mundo, el cliente vuelve a la pantalla de personajes
	"Salida", "Salio",
	-- Fase 25 (docs/44 §12): el tutorial. TutorialAccion C→S ("viajar" al Dungeon Newbie, o "premio" al terminarlo, con si además
	-- quiere que lo traigan de vuelta a Ullathorpe)
	"TutorialAccion",
	-- Fase 25 (docs/44 §10): el Subastador. Mercado S→C (tipo, datos); MercadoAccion C→S (accion, a, b, c, d)
	"Mercado", "MercadoAccion",
	-- Economía (Fase 13b, docs/22 §12.1)
	"Comercio", "Comprar", "Vender", "CerrarComercio", "Banco", "Depositar", "Retirar", "DepositarOro", "RetirarOro",
	"CerrarBanco", "HechizoSlot",
	-- Fase 31 (pedido del autor): MoverBanco C→S (desde, hasta): ordenar el banco o el baúl de la casa
	"MoverBanco",
	-- Fase 22 (docs/41 §5): el intercambio entre jugadores
	"Intercambio", "IntercambioAccion",
	-- Panel de Admin (docs/25)
	"Admin", "AdminPanel",
	-- Administración (Fase 23, docs/42): Mod C→S (accion, a, b, c, d), solo administradores; ModDatos S→C (tipo,
	-- datos): "lista" | "detalle" | "registro" | …
	"Mod", "ModDatos",
	-- Denunciar C→S (nick, motivo): la denuncia de un jugador, con el motivo de la lista (docs/42 §3.3)
	"Denunciar",
	-- Fase 23 (docs/42 §8): la tienda. TiendaAccion(accion, …) del cliente; TiendaDatos(datos) cuando cambia algo
	"TiendaAccion", "TiendaDatos",
	-- Clases, armas y habilidades (Fase 14a, docs/27)
	"PedirObjetivo", "Disparar", "Proyectil", "Ocultarse", "Robar", "Oculto",
	-- Hechizos (Fase 14b, docs/27 §12)
	"Aturdido", "Invisibilidad", "PalabrasTile",
	-- Correcciones de la 14b: cartelear
	"Cartelear", "BorrarDialogo",
	-- Party (Fase 15a, docs/28 §2)
	"Party",
	-- Correcciones de la 15a (docs/28 §10): mover hechizos, arrastrar ítems, acciones de la party
	"MoverHechizo", "MoverItem", "PartyAccion",
	-- Clanes (Fase 15b, docs/28 §3)
	"ClanEvento",
	-- Retos (Fase 15c, docs/28 §14)
	"RetoEvento",
	-- Sonido y música (paquete P2, docs/29)
	"Sonido", "Audio", "GuardarAudio",
	-- Fase 38 (docs/58): cómo acomodó el jugador la interfaz del celular. HudGuardado S→C (lo guardado, al entrar al
	-- juego, si hay algo); GuardarHud C→S (la del teléfono y la de la tableta, o false = de fábrica): el servidor la valida
	-- (Config/Disposicion) y la guarda con las preferencias de la cuenta
	"HudGuardado", "GuardarHud",
	-- Fase 39 (docs/59 §5): los viajes en barco con el pirata. Barco S→C ("abrir", { origen, destinos = { { id,
	-- nombre, precio } }, oro }); BarcoViajar C→S (el id del puerto de destino)
	"Barco", "BarcoViajar",
	-- Supervivencia y recolección (Fase 16a, docs/31)
	"Trabajar",
	-- Producción (Fase 16b, docs/32)
	"Produccion", "Construir", "Mejorar", "PararTrabajo",
	-- Domar y mascotas (Fase 16c, docs/33)
	"Domar", "Mascotas", "OrdenMascota",
	"Navegar", -- Fase 21 (docs/40 §8): la tecla de subir o bajar del barco
	-- Atajos (Fase 22, docs/41 §1): GuardarAtajos C→S (la lista de diez: false o { t = "h" | "o", id })
	"GuardarAtajos",
	-- Navegación y monturas (P7, docs/34): Montura(montado, segundosDeEspera), solo al dueño
	"Montura",
	-- Facciones (P8, docs/36 §10): Faccion S→C ("abrir" | "estado", datos de la ventana); FaccionAccion C→S
	-- ("enlistar" | "recompensa" | "retirar" | "estado") con el Rey o el Demonio de la ventana
	"Faccion", "FaccionAccion",
	-- Entrenador (Fase 20, docs/39 §4): Entrenador S→C ("lista", { nombres }); Entrenar C→S (posición en la lista)
	"Entrenador", "Entrenar",
	-- Quests (Fase 20, docs/39 §2): QuestEvento S→C ("oferta", { id, nombre, texto } | "lista" | "refrescar", { { id,
	-- nombre, texto } }); QuestAccion C→S ("aceptar" | "rechazar" | "lista" | "abandonar", id)
	"QuestEvento", "QuestAccion",
	-- Casas (Fase 20, docs/39 §3): CasaEvento S→C ("abrir" | "refrescar", { ciudad, vendedor, precio, casas, tengo });
	-- CasaAccion C→S ("alquilar" | "renovar" | "dejar", idDeLaCasa | "cerrar")
	"CasaEvento", "CasaAccion",
	-- Aliados (Fase 24, docs/43 §4) S→C ({ { nombre, mapa, x, y, tipo } }): los de la party (tipo 1) y los del clan
	-- (tipo 2) conectados en este servidor, para los puntos del minimapa y del mapa del mundo. Una vez por segundo,
	-- solo si cambió
	"Aliados",
	-- Tiempos de parálisis (Fase 28, docs/48 §5) S→C ({ { id, segundos, inmovilizado } }): lo que les queda a los
	-- paralizados e inmovilizados del mapa, jugadores y criaturas. Solo al que tiene 87 de Supervivencia, y solo
	-- cuando cambia; el cliente dibuja la barra y la va bajando solo
	"TiemposParalisis",
	-- Vidas (Fase 28, docs/48 §5.2) S→C ({ { id, pasos } }, todo): la vida de las criaturas y de los demás jugadores del
	-- mapa, en pasos de la barra (-1 = ya no está). Solo al que tiene 100 de Supervivencia y solo lo que cambió; con
	-- todo = true es la lista entera (cambió de mapa) y lo anterior se descarta
	"Vidas",
	-- Dicho (Fase 29, docs/49 §8) S→C (id, texto, tipo, nombre?, mapa?): lo que dice un personaje que no escribe por
	-- TextChatService. Se dibuja como cualquier mensaje: el globo y la línea "Nombre> texto". Con nombre y mapa, es
	-- lo que oye de lejos un administrador con "Escuchar todo": solo la línea, con el mapa adelante
	"Dicho",
	-- AperturaAviso (Fase 36, docs/57) S→C (que?): la puerta cambió para ese jugador (abrió, o el dueño lo dejó pasar):
	-- que vuelva a preguntar con la función Apertura. Con "fallo": el viaje al mundo de pruebas no salió
	"AperturaAviso",
}
-- PedirEstadisticas (Fase 22, docs/41 §3): () → la ficha del personaje para la ventana de Estadísticas
-- CambiarPersonaje (Fase 24, docs/43 §18): (id, "nombre" | "cara", nombre nuevo | cabeza) → { ok, personajes,
-- bandeja } | { error, sinCambio? }. Gasta un Cambio de nombre o de cara de la cuenta; solo fuera del mundo
-- Apertura (Fase 36, docs/57): () → { pasa, pruebas, cuando?, ahora }. Antes de la apertura, al que no pasa lo anota
-- entre los que esperan en la puerta (los ve el dueño en su pestaña). pruebas: tiene llave y "Jugar" lo lleva al mundo
-- de pruebas.
-- AperturaPruebas (Fase 37, docs/57 §7): () → { ok } | { error }: el que tiene llave viaja al mundo de pruebas
local FUNCIONES = { "Unirse", "Cuenta", "TirarDados", "CrearPersonaje", "BorrarPersonaje", "RenombrarPersonaje", "CambiarPersonaje", "Susurrar", "Clan", "Reto", "PedirEstadisticas", "Tienda", "Apertura", "AperturaPruebas" }

local Remotes = {}

local carpeta: Folder
if RunService:IsServer() then
	carpeta = Instance.new("Folder")
	carpeta.Name = "Remotes"
	for _, nombre in EVENTOS do
		local r = Instance.new("RemoteEvent")
		r.Name = nombre
		r.Parent = carpeta
	end
	for _, nombre in FUNCIONES do
		local r = Instance.new("RemoteFunction")
		r.Name = nombre
		r.Parent = carpeta
	end
	carpeta.Parent = ReplicatedStorage
else
	carpeta = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.evento(nombre: string): RemoteEvent
	return carpeta:WaitForChild(nombre) :: RemoteEvent
end

function Remotes.funcion(nombre: string): RemoteFunction
	return carpeta:WaitForChild(nombre) :: RemoteFunction
end

return Remotes
