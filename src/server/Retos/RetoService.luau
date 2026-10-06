--!strict
--[[
	RetoService — los retos (Fase 15c, docs/28 §4 y §14; Retos.bas, notas en clanes-retos.md §3).

	- Invitar: la ventana de retos (FrmRetos) o /RETOS. 1v1, 2v2 o 3v3 con los nombres de los oponentes y aliados y el
	  oro (0 a 100.000.000). Todos tienen que estar en este servidor (DS15-25 A), vivos, en una ciudad, sin otro reto
	  ni comercio, y con el oro en la billetera. Nuestros (docs/28 §4.2): sin newbies; con apuesta, todos nivel 18+; el
	  premio no puede pasar el tope de la billetera; prueba con prueba.
	- Aceptar: una ventana con Aceptar / Rechazar (o /ACEPTAR <invitador>). La invitación vence a los 60 s
	  (DS15-26 A). Si todos aceptaron y no hay arena libre, se avisa y se reintenta hasta que venza.
	- Empezar: revalida todo, cobra la apuesta y lleva a cada equipo a su esquina de una arena libre del mapa 272,
	  con todo lleno y una cuenta de 10 s en la que el servidor no los deja moverse ni pegar.
	- Rondas: cuando un equipo se queda sin vivos (con o sin atacante: el veneno también cuenta, DS15-26 A), el otro
	  gana la ronda; al mejor de 3. Entre rondas se revive, se llena todo y se cambian de esquina.
	- Final: cada ganador cobra el doble de la apuesta; todos vuelven a donde estaban. Anuncio a todo el servidor.
	- Desconectarse pierde el reto (TCP.bas:873-874): sale de la arena, pierde lo apostado; si su equipo se queda
	  sin nadie, gana el otro.
	- Lo apostado y la posición de antes quedan en `retoGuardado`: si el servidor se cae o se cierra, el perfil se
	  guarda con el oro devuelto y en el lugar de antes (CuentaService.volcar).
	En la arena (CombateService): se pueden atacar los del reto sin mirar bando, seguro ni zona (DS15-26 A), también
	al compañero (DS15-28 A); no hay criminal, "en pelea", contadores, multa, exp (DS15-27 A) ni drop. No se puede
	resucitar, ir al hogar, tomar la poción negra ni robar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cfg = require(ReplicatedStorage.Shared.Config.Retos)
local ConfigComercio = require(ReplicatedStorage.Shared.Config.Comercio)
local Alineacion = require(ReplicatedStorage.Shared.Config.Alineacion)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local JugadorService = require(ServerScriptService.Server.Jugadores.JugadorService)
local CombateService = require(ServerScriptService.Server.Combate.CombateService)
local MundoService = require(ServerScriptService.Server.Mundo.MundoService)
local InventarioService = require(ServerScriptService.Server.Inventario.InventarioService)
local PoliticaService = require(ServerScriptService.Server.Comercio.PoliticaService)
local ChatService = require(ServerScriptService.Server.Chat.ChatService)

type PJ = JugadorService.PJ

export type Reto = {
	id: number,
	equipos: { { PJ } }, -- [1] el que invita y sus aliados, [2] los oponentes
	nombres: { string }, -- los nombres de cada equipo al empezar (para los mensajes)
	oro: number,
	arena: number,
	fase: string, -- "cuenta" | "pelea" | "fin"
	cuenta: number,
	rondas: { number },
	tRonda: number, -- Fase 20 (docs/39 §6): los segundos que le quedan a la ronda
	empates: number, -- las rondas seguidas que terminaron por tiempo sin ventaja
	lado: number, -- 1: el equipo 1 en la esquina a; 2: cambiados
	-- Fase 19 (docs/38 §6): cuántos por lado al empezar y, si es un clan contra clan, { nombres, alTerminar(ganador) }
	tam: number,
	cvc: any?,
}

type Invitacion = { de: PJ, equipos: { { PJ } }, oro: number, aceptaron: { [PJ]: boolean }, vence: number, avisoArena: number }

local RetoService = {}
-- Fase 29 (docs/49 §11): retaron a `p` (lo usa BotService: un bot lo rechaza)
RetoService.alInvitar = nil :: ((p: any, de: any, reto: { modo: number, oro: number }) -> ())?
-- Fase 29 (docs/49 §19.2, D29-68): terminó un reto (lo usa BotService: alguno lo comenta)
RetoService.alTerminar = nil :: (() -> ())?

local T = CombateService.T
local consola = CombateService.consola
local estado = CombateService.estado
local M = Cfg.Msg
local MC = Cfg.MsgCvc

local evReto: RemoteEvent
local invitaciones: { [PJ]: Invitacion } = {} -- por el que invita
local arenas: { [number]: Reto } = {}
local contador = 0

-- ─── Ayudas ──────────────────────────────────────────────────────────────────
local function retoDe(pj: PJ): Reto?
	return (pj :: any).reto
end

local function todos(eq: { { PJ } }): { PJ }
	local r = {}
	for _, e in eq do
		for _, p in e do
			table.insert(r, p)
		end
	end
	return r
end

local function nombresDe(e: { PJ }): string
	local r = {}
	for _, p in e do
		table.insert(r, p.nombre)
	end
	return table.concat(r, ", ")
end

local function aTodos(lista: { PJ }, texto: string, tipo: string?)
	for _, p in lista do
		consola(p, texto, tipo or T.info)
	end
end

local function porNombre(n: any): PJ?
	if typeof(n) ~= "string" then
		return nil
	end
	local q = string.lower((string.match(n, "^%s*(.-)%s*$") or ""))
	for _, p in JugadorService.todos() do
		if not p.desconectado and not p.espectador and string.lower(p.nombre) == q then -- (Fase 23: ni al espectador)
			return p
		end
	end
	return nil
end

local function conectado(p: PJ): boolean
	if (p :: any).titere or (p :: any).bot then -- Studio: el títere de JugadorService.crearTitere. Fase 29: un bot
		return not p.desconectado
	end
	return not p.desconectado and p.jugador.Parent == Players and JugadorService.de(p.jugador) == p
end

-- Desde dónde se puede retar (pedido del autor, docs/28 §15): cualquier mapa seguro (todas las ciudades del
-- original menos la Abandonada tienen Pk=1), cualquier mapa con Zona=CIUDAD (la Abandonada) y cualquier tile con el
-- trigger ZONASEGURA de un mapa inseguro. En un lugar inseguro, además, no tiene que haber peleado hace poco: así
-- nadie se escapa de una pelea metiéndose en un reto.
local function lugarParaRetar(p: PJ): boolean
	local mapa = MundoService.mapa(p.mapa)
	if not mapa then
		return false
	end
	if mapa.zonaSegura or MundoService.trigger(p.mapa, p.x, p.y) == Mapas.TRIGGER.ZONASEGURA then
		return true
	end
	return mapa.zona == "CIUDAD" and os.clock() - p.ultimaPelea >= Alineacion.SegFueraDePelea
end
RetoService.lugarParaRetar = lugarParaRetar

-- ─── Validaciones (ValidateFight + ValidateFight_Users, Retos.bas:375-488) ───
-- Por qué `p` no puede entrar a una pelea de arena (nil = puede). prueba: si se pasa, tiene que coincidir
local function motivoJugador(p: PJ, oro: number, prueba: boolean?): string?
	if not conectado(p) then
		return string.format(M.Offline, p.nombre)
	end
	if prueba ~= nil and p.prueba ~= prueba then
		return M.Prueba
	end
	if p.muerto then
		return string.format(M.Muerto, p.nombre)
	end
	if p.preso or p.espectador then -- Fase 23 (docs/42 §5.2 y §2.3): ni retos ni clan contra clan
		return string.format(M.NoDisponible, p.nombre)
	end
	if JugadorService.estadoDe(p) == "newbie" then
		return string.format(M.Newbie, p.nombre)
	end
	if not lugarParaRetar(p) then
		return string.format(M.NoSegura, p.nombre)
	end
	if p.navegando then -- DT16-09 A (docs/34 §5): no se invita ni se acepta un reto navegando
		return string.format(M.Navegando, p.nombre)
	end
	if retoDe(p) then
		return string.format(M.EnEvento, p.nombre)
	end
	if JugadorService.viajando(p) then -- Fase 20 (docs/39 §7): pidió viajar a la sala de un clan contra clan
		return string.format(M.NoDisponible, p.nombre)
	end
	local comerciando = InventarioService.comerciando
	if comerciando and comerciando(p) then
		return string.format(M.NoDisponible, p.nombre)
	end
	local e = estado(p)
	if e.oro < oro then
		return string.format(M.SinOro, p.nombre)
	end
	if oro > 0 and e.combatiente.elv < Cfg.NivelApuesta then
		return string.format(M.NivelApuesta, p.nombre)
	end
	-- Fase 26 (docs/46 §9): desde que el oro se vende, apostarlo lo mira la norma de Roblox sobre pasar a otro jugador
	-- lo comprado. No espera: la consulta se hizo al entrar (nil = todavía no se sabe: tampoco)
	if oro > 0 and not prueba then
		local puede = PoliticaService.sabida(p)
		if puede ~= true then
			return string.format(if puede == false then M.ApuestaNoPermitida else M.ApuestaSinSaber, p.nombre)
		end
	end
	if e.oro + oro > ConfigComercio.MaxOro then
		return string.format(M.TopeOro, p.nombre)
	end
	return nil
end
-- Lo pone CvcService: el motivo por el que en este servidor no se arman retos comunes (nil = se puede)
RetoService.sinRetos = nil :: (() -> string?)?
RetoService.motivoJugador = motivoJugador -- Fase 19: el clan contra clan mira a cada anotado con las mismas reglas

local function validar(lista: { PJ }, oro: number): string?
	if oro < 0 or oro > Cfg.OroMax or oro ~= math.floor(oro) then
		return M.OroRango
	end
	if oro > 0 and not Cfg.Apuestas then
		return M.SinApuestas
	end
	local prueba = lista[1] and lista[1].prueba
	for _, p in lista do
		local motivo = motivoJugador(p, oro, prueba)
		if motivo then
			return motivo
		end
	end
	return nil
end

-- ─── Invitar y aceptar (SendFight, AcceptFight: Retos.bas:1053-1093) ─────────
local function quitarInvitaciones(p: PJ, motivo: string?)
	for de, inv in invitaciones do
		local esta = de == p
		for _, x in todos(inv.equipos) do
			if x == p then
				esta = true
			end
		end
		if esta then
			invitaciones[de] = nil
			if motivo then
				aTodos(todos(inv.equipos), motivo)
			end
			for _, x in todos(inv.equipos) do
				JugadorService.enviar(x, evReto, "cerrarInvitacion")
			end
		end
	end
end

local function invitar(pj: PJ, datos: any): any
	if typeof(datos) ~= "table" then
		return { error = M.Cantidad }
	end
	-- Fase 20 (docs/39 §7): en la sala de un clan contra clan las arenas son para esa pelea
	local cerrado = RetoService.sinRetos and RetoService.sinRetos()
	if cerrado then
		return { error = cerrado }
	end
	local modo = datos.modo
	if modo ~= 1 and modo ~= 2 and modo ~= 3 then
		return { error = M.Cantidad }
	end
	local oro = tonumber(datos.oro) or 0
	local eq1, eq2 = { pj }, {}
	local vistos: { [PJ]: boolean } = { [pj] = true }
	local function sumar(lista: any, n: number, destino: { PJ }): string?
		for i = 1, n do
			local nombre = typeof(lista) == "table" and lista[i] or nil
			local p = porNombre(nombre)
			if not p then
				return if typeof(nombre) == "string" and nombre ~= "" then string.format(M.Offline, nombre) else M.Cantidad
			end
			if vistos[p] then
				return M.Cantidad
			end
			vistos[p] = true
			table.insert(destino, p)
		end
		return nil
	end
	local err = sumar(datos.oponentes, modo, eq2) or sumar(datos.aliados, modo - 1, eq1)
	if err then
		return { error = err }
	end
	local lista = todos({ eq1, eq2 })
	err = validar(lista, oro)
	if err then
		return { error = err }
	end
	quitarInvitaciones(pj, nil) -- "si vuelves a mandar, la anterior solicitud se cancela"
	local inv: Invitacion = { de = pj, equipos = { eq1, eq2 }, oro = oro, aceptaron = { [pj] = true }, vence = os.clock() + Cfg.VenceInvitacion, avisoArena = 0 }
	invitaciones[pj] = inv
	local texto = `{nombresDe(eq2)} vs {nombresDe(eq1)}.{if oro > 0 then ` Oro requerido: {oro}.` else ""}`
	for _, p in lista do
		if p ~= pj then
			consola(p, `{texto} Para aceptar tipea /ACEPTAR {pj.nombre}`, T.info)
			JugadorService.enviar(p, evReto, "invitacion", { de = pj.nombre, texto = texto, segundos = Cfg.VenceInvitacion })
			local f = RetoService.alInvitar
			if f then
				task.spawn(f, p, pj, { modo = modo, oro = oro })
			end
		end
	end
	return { ok = true, mensaje = M.Esperando }
end

local comenzar: (Invitacion) -> ()
local depuracion: () -> ()

local function aceptar(pj: PJ, de: any): any
	for invitador, inv in invitaciones do
		if (de == nil or (typeof(de) == "string" and string.lower(de) == string.lower(invitador.nombre))) and not inv.aceptaron[pj] then
			for _, p in todos(inv.equipos) do
				if p == pj then
					inv.aceptaron[pj] = true
					consola(pj, M.Aceptaste, T.info)
					local faltan = false
					for _, x in todos(inv.equipos) do
						if not inv.aceptaron[x] then
							faltan = true
						end
					end
					if not faltan then
						comenzar(inv)
					end
					return { ok = true }
				end
			end
		end
	end
	return { error = "No tienes invitaciones a retos." }
end

local function rechazar(pj: PJ): any
	for invitador, inv in invitaciones do
		for _, p in todos(inv.equipos) do
			if p == pj and invitador ~= pj then
				invitaciones[invitador] = nil
				aTodos(todos(inv.equipos), `{pj.nombre} rechazo el reto.`)
				for _, x in todos(inv.equipos) do
					JugadorService.enviar(x, evReto, "cerrarInvitacion")
				end
				return { ok = true }
			end
		end
	end
	return { ok = true }
end

-- ─── En la arena ─────────────────────────────────────────────────────────────
local function enZona(a: number, x: number, y: number): boolean
	local z = Cfg.Arenas[a].zona
	return x >= z[1] and x <= z[2] and y >= z[3] and y <= z[4]
end

-- El tile libre de la zona de pelea más cercano a la esquina
local function lugarEn(a: number, esquina: { number }): (number?, number?)
	local m = Cfg.Mapa
	for r = 0, 10 do
		for dy = -r, r do
			for dx = -r, r do
				local x, y = esquina[1] + dx, esquina[2] + dy
				if math.max(math.abs(dx), math.abs(dy)) == r and enZona(a, x, y) and MundoService.esLegal(m, x, y) then
					return x, y
				end
			end
		end
	end
	return nil, nil
end

local function llenar(p: PJ)
	if p.muerto then
		CombateService.revivir(p, true)
	end
	local e = estado(p)
	e.hp, e.mana, e.sta = e.maxHp, e.maxMana, e.maxSta
	e.envenenado = false
	if e.paralizado then
		CombateService.quitarParalisis(p)
	end
	CombateService.enviarEstadisticas(p)
end

local function avisarCuenta(reto: Reto)
	for _, p in todos(reto.equipos) do
		JugadorService.enviar(p, evReto, "cuenta", reto.cuenta)
		consola(p, if reto.cuenta > 0 then `Cuenta -> {reto.cuenta}` else "Cuenta -> YA!", T.info)
	end
end

-- Pone a cada equipo en su esquina (cambian de lado en cada ronda, FinishFight ChangeTeam) con todo lleno y la cuenta
local function colocar(reto: Reto)
	local A = Cfg.Arenas[reto.arena]
	for i, eq in reto.equipos do
		local esquina = if (i == 1) == (reto.lado == 1) then A.a else A.b
		for _, p in eq do
			llenar(p)
			local x, y = lugarEn(reto.arena, esquina)
			if x and y then
				JugadorService.trasladar(p, Cfg.Mapa, x, y)
			end
		end
	end
	reto.fase = "cuenta"
	reto.cuenta = Cfg.Cuenta
	avisarCuenta(reto)
end

-- Arranca la pelea entre dos equipos ya validados: cobra la apuesta y los lleva a la primera arena libre de `orden`.
-- cvc: si es un clan contra clan (Fase 19, docs/38 §6), { nombres = { clan 1, clan 2 }, alTerminar = f(ganador) }.
-- Devuelve nil si no hay arena.
local function empezar(equipos: { { PJ } }, oro: number, orden: { number }, cvc: any?): Reto?
	local libre: number? = nil
	for _, i in orden do
		if Cfg.Arenas[i] and not arenas[i] then
			libre = i
			break
		end
	end
	if not libre then
		return nil
	end
	local lista = todos(equipos)
	for _, p in lista do
		quitarInvitaciones(p, nil)
	end
	contador += 1
	local reto: Reto = {
		id = contador,
		equipos = equipos,
		nombres = if cvc then cvc.nombres else { nombresDe(equipos[1]), nombresDe(equipos[2]) },
		oro = oro,
		arena = libre,
		fase = "cuenta",
		cuenta = Cfg.Cuenta,
		rondas = { 0, 0 },
		tRonda = 0,
		empates = 0,
		lado = 1,
		tam = #equipos[1],
		cvc = cvc,
	}
	arenas[libre] = reto
	for _, p in lista do
		local e = estado(p)
		e.oro -= oro -- Retos.bas:162-163
		local q = p :: any
		q.reto = reto
		-- Lo apostado y dónde estaba: si el servidor se cae, se guarda como antes del reto (CuentaService.volcar)
		q.retoGuardado = { oro = oro, pos = { mapa = p.mapa, x = p.x, y = p.y, h = p.heading } }
		CombateService.enviarEstadisticas(p)
		JugadorService.enviar(p, evReto, "empieza", { arena = libre })
	end
	-- Fase 31 (docs/51, D31-20): los que quedaron en equipos distintos pasan a ser rivales y dejan de verse invisibles,
	-- aunque sean del mismo clan o del mismo grupo (RetoService.rivales). Con todos ya anotados en el reto.
	for _, p in lista do
		JugadorService.reverInvisibles(p)
	end
	print(`[Retos] {reto.nombres[2]} vs {reto.nombres[1]} por {oro} en la arena {libre}{if cvc then " (clan contra clan)" else ""}`)
	colocar(reto)
	return reto
end
RetoService.empezar = empezar
-- Fase 23 (docs/42 §2.3): el que entra al modo espectador suelta las invitaciones a retos en las que figura
function RetoService.soltar(pj: PJ)
	quitarInvitaciones(pj, `{pj.nombre} ya no esta disponible para el reto.`)
end

comenzar = function(inv: Invitacion)
	local lista = todos(inv.equipos)
	local err = validar(lista, inv.oro)
	if err then
		invitaciones[inv.de] = nil
		aTodos(lista, err)
		for _, x in lista do
			JugadorService.enviar(x, evReto, "cerrarInvitacion")
		end
		return
	end
	-- Fase 19: los retos comunes empiezan por las arenas chicas (las grandes, para el clan contra clan)
	if not empezar(inv.equipos, inv.oro, Cfg.OrdenArenas, nil) then
		-- DS15-26 A: se avisa (el original callaba) y se reintenta hasta que venza la invitación
		if os.clock() - inv.avisoArena > 15 then
			inv.avisoArena = os.clock()
			aTodos(lista, M.SinArena)
		end
	end
end

-- Vuelve a donde estaba antes del reto (FindLegalPos, Retos.bas:1095-1122)
local function devolver(p: PJ)
	local q = p :: any
	local g = q.retoGuardado
	q.reto = nil
	q.retoGuardado = nil
	JugadorService.reverInvisibles(p) -- Fase 31 (D31-20): ya no es rival de nadie; vuelve a ver a los de su clan y su grupo
	if not g then
		return
	end
	local pos = g.pos
	if MundoService.cargado(pos.mapa) then
		local x, y = MundoService.tileLibreCerca(pos.mapa, pos.x, pos.y, 10)
		if x and y then
			JugadorService.trasladar(p, pos.mapa, x, y)
		end
	end
	JugadorService.enviar(p, evReto, "termina")
end

-- Fin del reto (RewardUsers + FinishFight, Retos.bas:148-190, :996-1049)
local function terminar(reto: Reto, ganador: number)
	reto.fase = "fin"
	arenas[reto.arena] = nil
	local perdedor = if ganador == 1 then 2 else 1
	local cvc = reto.cvc
	for _, p in reto.equipos[ganador] do
		local e = estado(p)
		e.oro = math.min(ConfigComercio.MaxOro, e.oro + reto.oro * 2)
		consola(p, if cvc then MC.Gano
			elseif reto.rondas[ganador] > 0 then `Has ganado el reto con {reto.rondas[ganador]} rounds a tu favor.`
			else "Has ganado el reto.", T.info)
	end
	for _, p in reto.equipos[perdedor] do
		consola(p, if cvc then MC.Perdio else "Has perdido el reto.", T.info)
	end
	-- Fase 22 (docs/41 §3): retos ganados y perdidos (el clan contra clan se lleva por clan, no acá)
	if not cvc then
		for _, p in reto.equipos[ganador] do
			JugadorService.sumarStat(p, "retosG")
		end
		for _, p in reto.equipos[perdedor] do
			JugadorService.sumarStat(p, "retosP")
		end
	end
	for _, p in todos(reto.equipos) do
		llenar(p)
		devolver(p)
		CombateService.enviarEstadisticas(p)
	end
	-- A todo el servidor (Retos.bas:1040)
	-- El del clan contra clan es el texto del original (Mod_ClanvsClan.bas:353-413)
	local texto = if cvc then string.format(MC.Vencio, reto.nombres[ganador], reto.nombres[perdedor], reto.tam, reto.tam)
		else `Retos: {reto.nombres[2]} vs {reto.nombres[1]}. Ganador {reto.nombres[ganador]}.{if reto.oro > 0 then ` Apuesta por {reto.oro} Monedas de Oro` else ""}`
	for _, p in JugadorService.todos() do
		if not p.desconectado then
			consola(p, texto, T.servidor)
		end
	end
	print(`[Retos] {texto}`)
	if cvc and cvc.alTerminar then
		task.spawn(cvc.alTerminar, ganador) -- guarda el resultado en los clanes: cede
	end
	local f = RetoService.alTerminar
	if f then
		task.spawn(f)
	end
end

-- La ronda que sigue: a los 2 s, cambian de esquina y arranca la cuenta
local function otraRonda(reto: Reto)
	reto.fase = "entreRondas"
	for _, p in todos(reto.equipos) do
		JugadorService.enviar(p, evReto, "tiempo", 0) -- saca el reloj de la ronda
	end
	task.delay(2, function()
		if reto.fase == "entreRondas" then
			reto.lado = if reto.lado == 1 then 2 else 1
			colocar(reto)
		end
	end)
end

-- Fase 20 (docs/39 §6): dos rondas seguidas sin ventaja. Nadie gana: cada uno de los que siguen ahí recupera lo que
-- apostó (lo de uno que se desconectó ya se había perdido, y no vuelve)
local function terminarSinGanador(reto: Reto)
	reto.fase = "fin"
	arenas[reto.arena] = nil
	local cvc = reto.cvc
	for _, p in todos(reto.equipos) do
		local e = estado(p)
		e.oro = math.min(ConfigComercio.MaxOro, e.oro + reto.oro)
		consola(p, Cfg.MsgTiempo.SinGanador, T.info)
		llenar(p)
		devolver(p)
		CombateService.enviarEstadisticas(p)
	end
	local texto = string.format(if cvc then Cfg.MsgTiempo.AnuncioCvc else Cfg.MsgTiempo.Anuncio, reto.nombres[2], reto.nombres[1])
	for _, p in JugadorService.todos() do
		if not p.desconectado then
			consola(p, texto, T.servidor)
		end
	end
	print(`[Retos] {texto}`)
	if cvc and cvc.alTerminar then
		task.spawn(cvc.alTerminar, 0) -- 0: sin ganador; los clanes quedan libres y no se anota nada
	end
end

-- Fase 20 (docs/39 §6, D20-32 A): se acabó el tiempo de la ronda. Gana el equipo con más vivos; después, el que conserva
-- más vida; con empate la ronda se juega de nuevo, y con dos seguidos el reto termina sin ganador.
local function finPorTiempo(reto: Reto)
	if reto.fase ~= "pelea" then
		return
	end
	local equipos: { { Cfg.Peleador } } = {}
	for i, eq in reto.equipos do
		equipos[i] = {}
		for _, p in eq do
			local e = estado(p)
			table.insert(equipos[i], { vivo = not p.muerto, hp = e.hp, maxHp = e.maxHp })
		end
	end
	local ganador = Cfg.ganadorPorTiempo(equipos)
	local que = Cfg.finPorTiempo(reto.rondas, reto.empates, ganador)
	if que == "empate" then
		terminarSinGanador(reto)
		return
	end
	if que == "repetir" then
		reto.empates += 1
		aTodos(todos(reto.equipos), Cfg.MsgTiempo.Repite)
		otraRonda(reto)
		return
	end
	reto.empates = 0
	reto.rondas[ganador] += 1
	aTodos(todos(reto.equipos), string.format(Cfg.MsgTiempo.Gana, reto.nombres[ganador]))
	if que == "fin" then
		terminar(reto, ganador)
	else
		otraRonda(reto)
	end
end

-- Un equipo se quedó sin vivos (UserDieFight, Retos.bas:870-955)
local function revisarRonda(reto: Reto)
	if reto.fase ~= "pelea" then
		return
	end
	for i, eq in reto.equipos do
		local vivos = 0
		for _, p in eq do
			if not p.muerto then
				vivos += 1
			end
		end
		if vivos == 0 then
			local otro = if i == 1 then 2 else 1
			reto.rondas[otro] += 1
			reto.empates = 0
			for _, p in reto.equipos[otro] do
				consola(p, `Has ganado el round. Rounds ganados: {reto.rondas[otro]}.`, T.info)
			end
			if reto.rondas[otro] >= Cfg.RondasParaGanar then
				terminar(reto, otro)
			else
				otraRonda(reto)
			end
			return
		end
	end
end

-- Muerte (con o sin atacante: DS15-26 A arregla el veneno)
local function alMorir(pj: PJ)
	local reto = retoDe(pj)
	if reto then
		task.defer(revisarRonda, reto)
	end
end

-- Se desconecta: pierde lo apostado y sale de la arena (corre antes del guardado final). Si el que sale no se
-- desconectó es que se cierra el servidor: queda `retoGuardado` y CuentaService.volcar le devuelve lo apostado.
local function alSalir(pj: PJ)
	quitarInvitaciones(pj, `{pj.nombre} se desconecto: el reto se cancela.`)
	local reto = retoDe(pj)
	if not reto or reto.fase == "fin" or not pj.desconectado then
		return
	end
	local q = pj :: any
	if q.retoGuardado then
		q.retoGuardado.oro = 0 -- lo apostado se pierde; CuentaService.volcar lo guarda vivo, lleno y donde estaba
	end
	q.reto = nil
	local equipo = 1
	for i, eq in reto.equipos do
		local idx = table.find(eq, pj)
		if idx then
			table.remove(eq, idx)
			equipo = i
		end
	end
	aTodos(todos(reto.equipos), `{pj.nombre} se desconecto y queda descalificado.`)
	if #reto.equipos[equipo] == 0 then
		terminar(reto, if equipo == 1 then 2 else 1)
	else
		revisarRonda(reto)
	end
end

-- La cuenta regresiva y el vencimiento de las invitaciones (PasarSegundo, mMainLoop.bas:411-425)
local function cadaSegundo()
	while true do
		task.wait(1)
		for _, reto in arenas do
			if reto.fase == "cuenta" then
				reto.cuenta -= 1
				avisarCuenta(reto)
				if reto.cuenta <= 0 then
					reto.fase = "pelea"
					reto.tRonda = Cfg.RondaSeg -- Fase 20 (docs/39 §6): el reloj de la ronda, desde el "YA!"
					for _, p in todos(reto.equipos) do
						JugadorService.enviar(p, evReto, "tiempo", reto.tRonda)
					end
				end
			elseif reto.fase == "pelea" then
				reto.tRonda -= 1
				local aviso = Cfg.RondaAvisos[reto.tRonda]
				if aviso then
					aTodos(todos(reto.equipos), aviso)
				end
				if reto.tRonda <= 0 then
					local ok, err = pcall(finPorTiempo, reto)
					if not ok then
						warn(`[Retos] fin por tiempo: {err}`)
					end
				end
			end
		end
		for de, inv in invitaciones do
			if os.clock() > inv.vence then
				invitaciones[de] = nil
				aTodos(todos(inv.equipos), M.Vencio)
				for _, x in todos(inv.equipos) do
					JugadorService.enviar(x, evReto, "cerrarInvitacion")
				end
			else
				local listos = true
				for _, x in todos(inv.equipos) do
					if not inv.aceptaron[x] then
						listos = false
					end
				end
				if listos then
					comenzar(inv) -- todos aceptaron pero no había arena: reintenta
				end
			end
		end
	end
end

-- ─── Reglas de la arena para los demás servicios ─────────────────────────────
function RetoService.mismoReto(a: PJ, v: PJ): boolean
	local r = retoDe(a)
	return r ~= nil and r == retoDe(v)
end

-- Fase 31 (docs/51, D31-20): ¿están peleando como rivales? En el mismo reto (el clan contra clan es un reto) y en
-- equipos distintos. Lo usa JugadorService.esAliado: dos rivales no se ven invisibles aunque compartan clan o grupo.
-- Es la cuenta de MagiaService.mismoEquipo dada vuelta, salvo que con uno adentro del reto y el otro afuera no son
-- rivales (el de afuera no está en la arena).
function RetoService.rivales(a: PJ, b: PJ): boolean
	local r = retoDe(a)
	if r == nil or r ~= retoDe(b) then
		return false
	end
	for _, equipo in r.equipos do
		if table.find(equipo, a) then
			return table.find(equipo, b) == nil
		end
	end
	return false
end

function RetoService.enReto(pj: PJ): boolean
	return retoDe(pj) ~= nil
end

function RetoService.quieto(pj: PJ): boolean
	local r = retoDe(pj)
	return r ~= nil and r.fase ~= "pelea"
end

-- ─── Studio: probar solo con títeres ─────────────────────────────────────────
-- ServerStorage.DepuracionRetos:Invoke(accion, ...):
--   titere(clase, nombre, limpio)    → crea un personaje de prueba sin jugador al lado del primer jugador (limpio =
--                                      true: con ese nombre a secas, sin la marca de prueba, para filmar)
--   como(nombre, accion, datos)      → invitar / aceptar / rechazar en nombre del títere
--   matar(nombre) · salir(nombre)    → muere · se desconecta
--   oro(nombre, n) · nivel(nombre, n) · probar(a, b) · veneno(nombre) · pos(nombre)
--   estado()                         → las arenas y las invitaciones
--   tiempo(n)                        → Fase 20: deja n segundos de ronda en todas las peleas
--   vida(nombre, n)                  → le pone esa vida
function depuracion()
	local f = Instance.new("BindableFunction")
	f.Name = "DepuracionRetos"
	f.Parent = game:GetService("ServerStorage")
	f.OnInvoke = function(accion: string, a: any, b: any, c: any): any
		local p = porNombre(a)
		if accion == "tiempo" then
			local n = 0
			for _, reto in arenas do
				if reto.fase == "pelea" then
					reto.tRonda = tonumber(a) or 2
					n += 1
				end
			end
			return n
		elseif accion == "vida" and p then
			estado(p).hp = math.clamp(tonumber(b) or 1, 1, estado(p).maxHp)
			CombateService.enviarEstadisticas(p)
			return estado(p).hp
		elseif accion == "titere" then
			local yo: PJ? = nil
			for _, x in JugadorService.todos() do
				if not (x :: any).titere and not (x :: any).bot and not x.desconectado then
					yo = x
				end
			end
			if not yo then
				return "no hay jugador"
			end
			local q = JugadorService.crearTitere(a or "Guerrero", b or "Titere", yo.mapa, yo.x + 1, yo.y, c == true)
			return if q then q.nombre else "no se pudo"
		elseif not p then
			if accion == "estado" then
				local r = {}
				for i, reto in arenas do
					table.insert(r, `arena {i}: {reto.nombres[1]} vs {reto.nombres[2]} fase {reto.fase} cuenta {reto.cuenta} rondas {reto.rondas[1]}-{reto.rondas[2]} lado {reto.lado} tiempo {reto.tRonda} empates {reto.empates}`)
				end
				for de, inv in invitaciones do
					local n = 0
					for _ in inv.aceptaron do
						n += 1
					end
					table.insert(r, `invitación de {de.nombre}: {n}/{#todos(inv.equipos)} aceptaron, oro {inv.oro}`)
				end
				return table.concat(r, "\n")
			end
			return "no existe " .. tostring(a)
		elseif accion == "como" then
			if b == "invitar" then
				return invitar(p, c)
			elseif b == "aceptar" then
				return aceptar(p, c)
			elseif b == "rechazar" then
				return rechazar(p)
			end
		elseif accion == "matar" then
			CombateService.morir(p, nil, true)
			return "ok"
		elseif accion == "salir" then
			JugadorService.quitarTitere(p)
			return "ok"
		elseif accion == "oro" then
			estado(p).oro = b
			CombateService.enviarEstadisticas(p)
			return "ok"
		elseif accion == "nivel" then
			estado(p).combatiente.elv = b
			return "ok"
		elseif accion == "probar" then -- (a, b): qué dicen las reglas de combate entre los dos
			local v = porNombre(b)
			if not v then
				return "no existe " .. tostring(b)
			end
			return `atacar={CombateService.puedeAtacar(p, v)} ayudar={CombateService.puedeAyudar(p, v)} quieto={RetoService.quieto(p)}`
		elseif accion == "veneno" then -- muere envenenado: sin atacante
			estado(p).hp = 1
			CombateService.envenenar(p)
			return "ok"
		elseif accion == "pos" then
			return `{p.mapa} {p.x} {p.y} muerto={p.muerto} hp={estado(p).hp} oro={estado(p).oro}`
		end
		return "?"
	end
end

-- ─── Arranque ────────────────────────────────────────────────────────────────
function RetoService.iniciar()
	evReto = Remotes.evento("RetoEvento")
	Remotes.funcion("Reto").OnServerInvoke = function(jugador: Player, accion: any, datos: any)
		local pj = JugadorService.de(jugador)
		if not pj or not pj.combate then
			return nil
		end
		if pj.espectador and accion ~= "jugadores" then
			return { error = JugadorService.MsgEspectador } -- Fase 23 (docs/42 §2.3): el espectador solo mira
		end
		if pj.preso and accion ~= "jugadores" then
			return { error = JugadorService.MsgPreso } -- (docs/42 §5.2, D23-20 A)
		end
		local ok, r = pcall(function(): any
			if accion == "invitar" then
				return invitar(pj, datos)
			elseif accion == "aceptar" then
				return aceptar(pj, datos)
			elseif accion == "rechazar" then
				return rechazar(pj)
			elseif accion == "jugadores" then -- para elegir oponentes y aliados en la ventana
				local r = {}
				for _, p in JugadorService.todos() do
					if p ~= pj and not p.desconectado and not p.espectador and p.prueba == pj.prueba then
						table.insert(r, p.nombre)
					end
				end
				table.sort(r)
				return { lista = r }
			end
			return nil
		end)
		if not ok then
			warn(`[Retos] {accion}: {r}`)
			return { error = "Error en el reto." }
		end
		return r
	end
	ChatService.registrarComando("RETOS", function(pj)
		JugadorService.enviar(pj, evReto, "abrir")
	end)
	ChatService.registrarComando("ACEPTAR", function(pj, arg)
		local r = aceptar(pj, arg)
		if r.error then
			consola(pj, r.error, T.info)
		end
	end)
	CombateService.registrarAlMorir(alMorir)
	JugadorService.alSalir(alSalir, true)
	CombateService.muerteEnArena = RetoService.mismoReto
	CombateService.mismoReto = RetoService.mismoReto
	CombateService.enReto = RetoService.enReto
	CombateService.retoQuieto = RetoService.quieto
	JugadorService.rivales = RetoService.rivales -- Fase 31 (docs/51, D31-20)
	task.spawn(cadaSegundo)
	if game:GetService("RunService"):IsStudio() then
		depuracion()
	end
end

RetoService._interno = { invitar = invitar, aceptar = aceptar, rechazar = rechazar, arenas = arenas, invitaciones = invitaciones, terminar = terminar }

return RetoService
