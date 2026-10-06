--!strict
--[[
	Admin — los números y las reglas de la administración (Fase 23, docs/42). Verificado contra
	herramientas/fase23_ref.py (muestras/fase23_vectores.json).

	Rangos (D23-01 A): 0 jugador, 1 ayudante (la lista de server/Admin/Admins.luau), 2 dueño. Un ayudante no sanciona ni
	mueve a otro ayudante ni al dueño; el dueño sí puede sobre un ayudante.
]]

local Admin = {}

-- ─── Cárcel y silencio (docs/42 §5; Admin.bas:263-275, Ciudades.Dat:51-59) ───
Admin.Carcel = { mapa = 66, x = 75, y = 47 } -- la celda
Admin.Libertad = { mapa = 66, x = 75, y = 65 } -- donde queda al cumplir
-- La celda: un recinto cerrado (su única puerta pide llave, y en el port esas no se abren). El rectángulo que la
-- contiene, con el pasillo de la puerta; sirve para saber si el preso está adentro.
Admin.CeldaArea = { x1 = 47, y1 = 40, x2 = 80, y2 = 61 }
Admin.PenaMinMin = 1
Admin.PenaMaxMin = 60
Admin.SilencioMaxMin = 60

-- ─── Modo espectador (docs/42 §2.3) ──────────────────────────────────────────
Admin.EspectadorSinPeleaSeg = 10 -- para entrar: sin pegar, lanzar ni recibir daño en estos segundos

-- ─── Invocar y limpiar (docs/42 §6) ──────────────────────────────────────────
Admin.InvocarPorVez = 10
Admin.InvocarVivas = 40
Admin.InvocarSeg = 30 * 60
Admin.LimpiezaSeg = 16

-- Qué se puede invocar: lo que se puede atacar y no es de una ciudad (ni guardias, ni vendedores, ni sacerdotes).
-- `d`: una fila de shared/Generado/Npcs (tipo 0 común, 6 dragón, 10 pretoriano).
function Admin.invocable(d: any): boolean
	return typeof(d) == "table" and d.atacable == true and d.comercia ~= true and (d.tipo == 0 or d.tipo == 6 or d.tipo == 10)
end

-- ─── El panel ────────────────────────────────────────────────────────────────
Admin.AccionesPorSeg = 4 -- por administrador (fichas: se recargan de a 4 por segundo, hasta 4)
Admin.RegistroDias = 7
Admin.RegistroMaxDia = 100 -- anotaciones que se leen de un día, como mucho (cada una es una lectura, y Roblox da pocas por minuto)
Admin.SancionesGuardadas = 20 -- las últimas, en los datos de la cuenta
Admin.IntercambiosMax = 100 -- intercambios que se leen por pedido, como mucho

-- Lo que ve el sancionado: una lista fija (Roblox no deja enlaces, nombres ni datos personales en el motivo de un
-- ban, y un texto libre de un administrador habría que filtrarlo). El orden es el del comando: /CARCEL nick min 4
Admin.Motivos = {
	{ clave = "insultos", texto = "Insultos o acoso a otros jugadores" },
	{ clave = "trampas", texto = "Trampas o programas no permitidos" },
	{ clave = "error", texto = "Aprovechar un error del juego" },
	{ clave = "spam", texto = "Spam o publicidad" },
	{ clave = "nombre", texto = "Nombre de personaje o de clan inapropiado" },
	{ clave = "otro", texto = "No respetar las reglas del juego" },
}
Admin.MotivoPorDefecto = "otro"

-- Segundos; -1 = para siempre (así lo pide Players:BanAsync)
Admin.BanDuraciones = {
	{ texto = "1 día", seg = 86400 },
	{ texto = "3 días", seg = 259200 },
	{ texto = "7 días", seg = 604800 },
	{ texto = "30 días", seg = 2592000 },
	{ texto = "Para siempre", seg = -1 },
}
Admin.Apelar = "Para apelar, buscá los enlaces en la página del juego."
Admin.BanTextoMax = 400 -- DisplayReason
Admin.BanNotaMax = 1000 -- PrivateReason
Admin.NotaMax = 200 -- la nota del panel

-- ─── Anuncio y denuncias (docs/42 §3.3 y §6.3) ───────────────────────────────
Admin.AnuncioCadaSeg = 10
Admin.AnuncioMax = 200
Admin.DenunciaCadaSeg = 60

-- ─── Las reglas del juego (docs/42 §5.6; el texto lo aprueba el autor). Van también en la descripción del juego. ───
Admin.Reglas = {
	"Respetá a los demás: nada de insultos, acoso ni discriminación.",
	"No uses trampas, programas ni errores del juego para sacar ventaja. Si encontrás un error, avisá con /REPORTE.",
	"No hagas spam ni publicidad.",
	"Los nombres de personajes y de clanes tienen que ser apropiados.",
	"No te hagas pasar por un administrador. Los administradores de verdad llevan la marca dorada.",
	"Las compras con Robux son de tu cuenta y no se pasan a otros jugadores. El oro es la excepción: una vez retirado es oro común.",
	"Para moderar, los administradores pueden leer el chat común, el de clan y el de grupo. Los susurros, no: si recibís uno fuera de lugar, usá /DENUNCIAR.",
	"Las sanciones van del silencio y la cárcel al ban, según la falta. Para apelar una, buscá los enlaces en la página del juego.",
}

Admin.MarcaTexto = "Administrador"
Admin.MarcaColor = Color3.fromRGB(255, 204, 64)

Admin.Msg = {
	NoPuede = "No podes hacer eso sobre ese jugador.",
	NoEsta = "Ese jugador ya no esta en este servidor.",
	EsBot = "Es un bot: se lo pausa o se lo borra desde la pestaña Bots.", -- Fase 29 (docs/49 §12)
	Espera = "Demasiadas acciones seguidas: espera un momento.",
	SoloStudio = "Eso anda solo dentro de Studio.",
	EspectadorSi = "Modo espectador: nadie te ve ni te toca, salvo los otros administradores. Solo podes mirar y usar el panel.",
	EspectadorNo = "Saliste del modo espectador: estas a la vista.",
	EspectadorVuelve = "Saliste del modo espectador: volviste a donde entraste.",
	EspMuerto = "No podes entrar al modo espectador estando muerto.",
	EspTransporte = "Baja de la montura o del barco antes de entrar al modo espectador.",
	EspReto = "No podes entrar al modo espectador en un reto.",
	EspGrupo = "Sali del grupo antes de entrar al modo espectador.",
	EspPelea = "No podes entrar al modo espectador recien salido de una pelea: espera unos segundos.",
	EspComercio = "Cerra la ventana de comercio antes de entrar al modo espectador.",
	EspMascotas = "Guarda o libera tus mascotas antes de entrar al modo espectador.",
	EspViaje = "No podes entrar al modo espectador mientras viajas.",
	EspOculto = "No podes entrar al modo espectador estando oculto, invisible o mimetizado.",
	EspParalizado = "No podes entrar al modo espectador estando paralizado.",
	EspPreso = "No podes entrar al modo espectador estando preso.",
	SinLugar = "No hay un lugar libre cerca.",
	Traido = "Un administrador te llevo ante el.",
	Devuelto = "Un administrador te devolvio a donde estabas.",
	Revivido = "Un administrador te devolvio la vida.",
	TraerInvisible = "Para traer a alguien tenes que estar a la vista: sali del modo espectador.",
	EnReto = "Esta en un reto: no se lo puede mover hasta que termine.",
	Viajando = "Esta viajando a otro servidor.",
	Preso = "Esta preso: primero hay que liberarlo.",
	NoTraido = "A ese jugador no lo trajo nadie: no hay donde devolverlo.",
	NoMuerto = "Ese jugador no esta muerto.",
	Vos = "No podes hacer eso sobre vos mismo.",
	TeEncarcelaron = "Un administrador te encarcelo por %d min. Motivo: %s.",
	SeguisPreso = "Seguis preso: te faltan %d min.",
	Liberado = "Has sido liberado.", -- el del original
	NoPreso = "Ese jugador no esta preso.",
	YaPreso = "Ese jugador ya esta preso.",
	Echado = "Un administrador te desconecto del juego. Motivo: %s.",
	CuentaPresa = "Tu cuenta tiene un personaje preso (%s). Hasta que cumpla, solo podes entrar con el: le faltan %d min.",
	BorrarPreso = "No podes borrar a un personaje preso.",
	BanSinNombre = "No hay ningun personaje con ese nombre.",
	BanFallo = "No se pudo completar el ban: Roblox no contesto. Proba de nuevo.",
	BanDuracion = "Elegi una duracion de la lista.",
	Silenciado = "Estas silenciado: no podes hablar por %d min.",
	TeSilenciaron = "Un administrador te silencio por %d min. Motivo: %s.",
	YaPodesHablar = "Ya podes volver a hablar.",
	NoSilenciado = "Ese jugador no esta silenciado.",
	MinutosMal = "Los minutos van de 1 a 60.",
	EscuchaSi = "Escuchar todo: te llega lo que se habla en todo el servidor, y el chat de los clanes y de los grupos.",
	EscuchaNo = "Escuchar todo: apagado.",
	AnuncioEspera = "Un anuncio cada 10 segundos.",
	AnuncioVacio = "Escribi el anuncio.",
	AnuncioFiltro = "El anuncio no paso el filtro de Roblox, o no se pudo filtrar. No se mando.",
	DenunciaEspera = "Podes hacer una denuncia por minuto.",
	DenunciaHecha = "Tu denuncia quedo registrada. Gracias por avisar.",
	DenunciaVos = "No podes denunciarte a vos mismo.",
	NoNick = "No hay nadie conectado con ese nombre en este servidor.",
	InvNoExiste = "Esa criatura no existe o no se puede invocar.",
	InvPremio = "El tilde 'con premio' lo tiene solo el dueño del juego.",
	InvArena = "No se puede invocar en las arenas de los retos.",
	InvCasa = "No se puede invocar dentro de una casa.",
	InvTope = "Ya hay %d criaturas invocadas vivas en el servidor: quita algunas antes de invocar mas.",
	InvSinLugar = "No hay lugar cerca para esa criatura.",
	InvNinguna = "No hay criaturas invocadas.",
	LimpiezaYa = "La limpieza del mundo ya esta en marcha.",
	LimpiezaPedida = "Limpieza del mundo en %d segundos.",
	MarcaSi = "Marca de administrador: a la vista.",
	MarcaNo = "Marca de administrador: oculta.",
	-- Fase 24 (docs/43 §21 y §22): lo del dueño
	SoloDueno = "Eso lo hace solo el dueño del juego.",
	ObjNoExiste = "Ese objeto no existe o no se puede crear en el piso.",
	ObjSinLugar = "No hay lugar en el piso cerca tuyo.",
	AdmYa = "Esa cuenta ya es administradora.",
	AdmNumero = "Escribi el numero de cuenta, o elegi a un jugador conectado.",
	AdmNoExiste = "No se encontro ninguna cuenta de Roblox con ese numero. Revisalo y proba de nuevo.",
	AdmTope = "Ya hay %d administradores agregados: saca alguno antes de sumar otro.",
	AdmFijo = "Esa cuenta esta en la lista fija del juego (Admins.luau): no se saca desde el panel.",
	AdmNoEs = "Esa cuenta no esta entre los administradores agregados.",
	AdmDueno = "El dueño no se saca.",
	AdmGuardado = "No se pudo guardar la lista de administradores. Proba de nuevo en un momento.",
	AdmYaNo = "Ya no sos administrador.",
	AdmAhora = "Ahora sos administrador: con /ADMIN abris el panel.",
	AdmSinPrueba = "Ya no tenes permiso para usar un personaje de prueba.",
}

-- ─── Lo del dueño (Fase 24, docs/43 §21 y §22) ───────────────────────────────
Admin.CrearOroMax = 10000000 -- monedas de oro por vez
Admin.AdminsMax = 20 -- administradores agregados desde el panel
Admin.AdminsRefrescoSeg = 120 -- cada cuánto relee la lista cada servidor (además del aviso entre servidores)
-- Si un servidor pasa este tiempo sin poder leer la lista guardada, los agregados quedan sin permisos en ese servidor
-- hasta que la lea (que uno al que se le sacó el permiso no lo conserve mientras dure una falla de los datos)
Admin.AdminsVenceSeg = 600

-- Qué se puede crear en el piso: lo que existe en el inventario, tiene dibujo de piso, se puede levantar (los muebles
-- y las flores no: quedarían ocupando el casillero) y no es personal (la gema, lo de la tienda y los premios no
-- llegan nunca al piso) ni de principiante. `o`: una fila de Generado/ObjetosInventario.
function Admin.creable(o: any, tienePiso: boolean): boolean
	return typeof(o) == "table" and tienePiso and o.personal ~= true and o.newbie ~= true and o.agarrable ~= false
end

function Admin.motivo(clave: any): string?
	for _, m in Admin.Motivos do
		if m.clave == clave then
			return m.texto
		end
	end
	return nil
end

-- El motivo del comando: el número de la lista (1 a 6) o nada (vale el último)
function Admin.motivoDeNumero(n: any): string
	local i = tonumber(n)
	local m = if i then Admin.Motivos[math.floor(i)] else nil
	return if m then m.clave else Admin.MotivoPorDefecto
end

function Admin.penaValida(minutos: any): boolean
	return typeof(minutos) == "number" and minutos == minutos and minutos % 1 == 0 and minutos >= Admin.PenaMinMin and minutos <= Admin.PenaMaxMin
end

-- El contador de la cárcel o del silencio: baja solo con el jugador en el mundo. Devuelve (restante, quedó libre).
function Admin.penaTick(seg: number, dt: number, conectado: boolean): (number, boolean)
	if seg <= 0 then
		return 0, false
	end
	if not conectado then
		return seg, false
	end
	local r = math.max(0, seg - dt)
	return r, r == 0
end

function Admin.puedeActuarSobre(actor: number, objetivo: number): boolean
	return actor >= 1 and actor > objetivo
end

-- Lo que ve el baneado en el cartel de Roblox: el motivo y cómo apelar (ya no puede abrir la ventana Reglas)
function Admin.textoBan(clave: any): string
	return `{Admin.motivo(clave) or Admin.motivo(Admin.MotivoPorDefecto)}. {Admin.Apelar}`
end

-- ─── El registro (docs/42 §7.1) ──────────────────────────────────────────────
-- Una anotación: { t, accion, a = { u, n }, o = { u, n }?, mapa?, motivo?, min?, nota?, extra? }
Admin.Acciones = {
	ir = "Fue a",
	traer = "Trajo a",
	devolver = "Devolvió a",
	revivir = "Revivió a",
	ficha = "Vio la ficha de",
	silenciar = "Silenció a",
	desilenciar = "Le sacó el silencio a",
	carcel = "Encarceló a",
	liberar = "Liberó a",
	echar = "Echó a",
	banear = "Baneó a",
	desbanear = "Le levantó el ban a",
	espectador = "Modo espectador",
	escuchar = "Escuchar todo",
	anuncio = "Anuncio a todos",
	invocar = "Invocó",
	quitarInvocadas = "Quitó las criaturas invocadas",
	limpiar = "Limpió el mundo",
	limpiarMapa = "Limpió el mapa",
	denuncia = "Denunció a",
	cambioNombre = "Cambió de nombre", -- Fase 24 (docs/43 §18): con el Cambio de nombre de la tienda
	crearObjeto = "Creó en el piso", -- Fase 24 (docs/43 §21)
	adminAgregar = "Hizo administrador a", -- Fase 24 (docs/43 §22)
	adminQuitar = "Le sacó la administración a",
	probadorAgregar = "Dejó pasar por la puerta a", -- Fase 36 (docs/57): los testers de antes de la apertura
	probadorQuitar = "Le cerró la puerta a",
	botCrear = "Creó bots", -- Fase 29 (docs/49 §3)
	botBorrar = "Borró un bot",
	botPausar = "Pausó un bot",
	botSeguir = "Reanudó un bot",
	botsApagar = "Apagó los bots",
	botsPrender = "Activó los bots",
	prueba = "Prueba del registro",
} :: { [string]: string }

-- "7 días", "para siempre"… o nil si no es una duración de la lista
function Admin.duracionTexto(seg: any): string?
	for _, d in Admin.BanDuraciones do
		if d.seg == seg then
			return string.lower(d.texto)
		end
	end
	return nil
end

local function duracion(e: any): string
	local t = Admin.duracionTexto(e.seg)
	if t then
		return ` ({t})`
	end
	return if typeof(e.min) == "number" then ` ({e.min} min)` else ""
end

-- Una línea para la pestaña Registro y para las sanciones anteriores (sin la hora, que la pone el que la muestra)
function Admin.describir(e: any): string
	local verbo = Admin.Acciones[e.accion] or tostring(e.accion)
	local quien = if typeof(e.a) == "table" then tostring(e.a.n) else "?"
	local s = `{quien}: {verbo}`
	if typeof(e.o) == "table" then
		s ..= ` {e.o.n}`
	end
	s ..= duracion(e)
	if typeof(e.extra) == "string" and e.extra ~= "" then
		s ..= ` · {e.extra}`
	end
	local m = Admin.motivo(e.motivo)
	if m then
		s ..= ` · {m}`
	end
	if typeof(e.nota) == "string" and e.nota ~= "" then
		s ..= ` · nota: {e.nota}`
	end
	return s
end

local function miles(n: number): string
	local t = tostring(math.floor(n))
	local r = string.gsub(string.reverse(t), "(%d%d%d)", "%1.")
	r = string.reverse(r)
	return (string.gsub(r, "^%.", ""))
end

local function loQueDio(p: any): string
	local t = {}
	for _, o in if typeof(p.da) == "table" then p.da else {} do
		if typeof(o) == "table" then
			table.insert(t, `{tostring(o.cant)} {tostring(o.nombre)}`)
		end
	end
	if typeof(p.oro) == "number" and p.oro > 0 then
		table.insert(t, `{miles(p.oro)} monedas de oro`)
	end
	return if #t > 0 then table.concat(t, ", ") else "nada"
end

-- Un intercambio del registro de la Fase 22 (IntercambioService): { cuando, a = { usuario, nombre, da, oro }, b }
function Admin.describirIntercambio(e: any): string
	return `{tostring(e.a.nombre)} le dio a {tostring(e.b.nombre)}: {loQueDio(e.a)}. Recibió: {loQueDio(e.b)}.`
end

-- Una sanción anterior, en los datos de la cuenta: { t, accion, motivo?, min?, seg?, por }
function Admin.describirSancion(s: any): string
	local nombres = { silenciar = "Silencio", carcel = "Cárcel", echar = "Echado", banear = "Ban" }
	local t = `{nombres[s.accion] or tostring(s.accion)}{duracion(s)}`
	local m = Admin.motivo(s.motivo)
	if m then
		t ..= ` · {m}`
	end
	if typeof(s.por) == "string" then
		t ..= ` · por {s.por}`
	end
	return t
end

return Admin
