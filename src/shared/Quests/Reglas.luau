--!strict
--[[
	Reglas — las cuentas de las quests, sin estado propio (Fase 20, docs/39 §2). Son las de herramientas/fase20_ref.py
	(motivo_pedir, aceptar, contar_muerte, falta, premio_de, texto_quest): el servidor las usa sobre los datos del
	personaje y las pruebas las comparan con muestras/fase20_vectores.json.

	El estado de un personaje (se guarda tal cual en su perfil):
	  { activas = { { id = número, matados = { n por cada criatura pedida } } }, hechas = { ["id"] = cuándo la entregó } }
	Las claves de `hechas` son texto: una tabla con claves numéricas salteadas no se puede guardar en un DataStore.
]]

local Cfg = require(script.Parent.Parent.Config.Quests)

local Reglas = {}

export type Quest = {
	id: number, nombre: string, desc: string, nivel: number,
	matar: { { number } }, traer: { { number } }, premios: { { number } },
	exp: number, oro: number, expRepetir: number, oroRepetir: number,
}
export type Activa = { id: number, matados: { number } }
export type Estado = { activas: { Activa }, hechas: { [string]: number } }

function Reglas.nuevo(): Estado
	return { activas = {}, hechas = {} }
end

function Reglas.activa(est: Estado, id: number): Activa?
	for _, a in est.activas do
		if a.id == id then
			return a
		end
	end
	return nil
end

-- Segundos que faltan para poder repetirla (0 si ya se puede o si nunca la hizo)
function Reglas.faltaRepetir(est: Estado, id: number, ahora: number): number
	local t = est.hechas[tostring(id)]
	if not t then
		return 0
	end
	return math.max(0, t + Cfg.RepetirSeg - ahora)
end

-- HandleQuest (modQuests.bas:320-388), con el muerto (D20-11 A) y la repetición (D20-10). q: la quest del NPC (nil si
-- no da ninguna). Devuelve el motivo, o "entregar" / "ofrecer".
function Reglas.motivoPedir(est: Estado, q: Quest?, nivel: number, dist: number, muerto: boolean, ahora: number): string
	if muerto then
		return "muerto"
	end
	if dist > Cfg.Dist then
		return "lejos"
	end
	if not q then
		return "sinMision"
	end
	if Reglas.activa(est, q.id) then
		-- Fase 24 (docs/43 §1.4, D24-24 A): la que ya está aceptada se entrega con cualquier nivel (la 7 y la 10
		-- subieron el suyo). Hasta la Fase 23, como el original, pedía el nivel también acá.
		return "entregar"
	end
	if Reglas.faltaRepetir(est, q.id, ahora) > 0 then
		return "espera"
	end
	if nivel < q.nivel then
		return "nivel"
	end
	if #est.activas >= Cfg.Max then
		return "demasiadas"
	end
	return "ofrecer"
end

-- Lo que da entregarla ahora: todo la primera vez; al repetirla, la experiencia y el oro de repetir, sin objetos
function Reglas.premioDe(est: Estado, q: Quest): { exp: number, oro: number, premios: { { number } } }
	if est.hechas[tostring(q.id)] then
		return { exp = q.expRepetir, oro = q.oroRepetir, premios = {} }
	end
	return { exp = q.exp, oro = q.oro, premios = q.premios }
end

-- Al aceptar se vuelve a mirar todo (el original solo mira la distancia). true si la aceptó.
function Reglas.aceptar(est: Estado, q: Quest?, nivel: number, dist: number, muerto: boolean, ahora: number): boolean
	if not q or Reglas.motivoPedir(est, q, nivel, dist, muerto, ahora) ~= "ofrecer" then
		return false
	end
	table.insert(est.activas, { id = q.id, matados = table.create(#q.matar, 0) })
	return true
end

-- MuereNpc (MODULO_NPCs.bas:263-291): suma 1 en cada quest activa que pida esa criatura, sin pasar de lo pedido.
-- Devuelve los avisos: { quest, criatura, llevan, piden, completa (ya mató todo lo de esa quest) }
function Reglas.contarMuerte(est: Estado, quests: { [number]: Quest }, npc: number): { { quest: Quest, npc: number, llevan: number, piden: number, completa: boolean } }
	local avisos = {}
	for _, a in est.activas do
		local q = quests[a.id]
		if q then
			for i, par in q.matar do
				if par[1] == npc and (a.matados[i] or 0) < par[2] then
					a.matados[i] = (a.matados[i] or 0) + 1
					local completa = true
					for j, otro in q.matar do
						if (a.matados[j] or 0) < otro[2] then
							completa = false
						end
					end
					table.insert(avisos, { quest = q, npc = npc, llevan = a.matados[i], piden = par[2], completa = completa })
				end
			end
		end
	end
	return avisos
end

-- Lo que falta para entregar (FinishQuest, modQuests.bas:122-149): "faltanObjetos", "faltanCriaturas" o nil.
-- tiene(objeto) → cuántos hay en todo el inventario
function Reglas.falta(est: Estado, q: Quest, tiene: (number) -> number): string?
	for _, par in q.traer do
		if tiene(par[1]) < par[2] then
			return "faltanObjetos"
		end
	end
	local a = Reglas.activa(est, q.id)
	for i, par in q.matar do
		if not a or (a.matados[i] or 0) < par[2] then
			return "faltanCriaturas"
		end
	end
	return nil
end

-- Deja la quest como hecha a la hora `ahora` (el servidor ya miró que se puede y entregó el premio)
function Reglas.cerrar(est: Estado, q: Quest, ahora: number)
	for i = #est.activas, 1, -1 do
		if est.activas[i].id == q.id then
			table.remove(est.activas, i)
		end
	end
	est.hechas[tostring(q.id)] = ahora
end

function Reglas.abandonar(est: Estado, id: number): boolean
	for i = #est.activas, 1, -1 do
		if est.activas[i].id == id then
			table.remove(est.activas, i)
			return true
		end
	end
	return false
end

-- "12 dias", "1 dia", "5 horas", "menos de una hora" (fase20_ref.falta_texto)
function Reglas.faltaTexto(seg: number): string
	if seg >= 86400 then
		local d = seg // 86400
		return `{d} dia{if d == 1 then "" else "s"}`
	end
	if seg >= 3600 then
		local h = seg // 3600
		return `{h} hora{if h == 1 then "" else "s"}`
	end
	return "menos de una hora"
end

-- El texto de la ventana (cli/Red/Protocol.bas:11341-11375). Con `est`, la quest ya aceptada: lo que lleva matado y,
-- nuestro, lo que tiene de cada objeto (D20-09 A). El premio es el que toca: el de la primera vez o el de repetir.
function Reglas.texto(q: Quest, nombreNpc: (number) -> string, nombreObj: (number) -> string, est: Estado, aceptada: boolean, tiene: ((number) -> number)?): string
	local L = { `Mision: {q.nombre}`, `Detalles: {q.desc}`, `Nivel requerido: {q.nivel}`, "", "OBJETIVOS" }
	local a = if aceptada then Reglas.activa(est, q.id) else nil
	for i, par in q.matar do
		table.insert(L, `*) Matar {par[2]} {nombreNpc(par[1])}.{if a then ` (Has matado {a.matados[i] or 0})` else ""}`)
	end
	for _, par in q.traer do
		local t = if a and tiene then ` (Tienes {math.min(par[2], tiene(par[1]))})` else ""
		table.insert(L, `*) Conseguir {par[2]} {nombreObj(par[1])}.{t}`)
	end
	local pr = Reglas.premioDe(est, q)
	table.insert(L, "")
	table.insert(L, "RECOMPENSAS")
	table.insert(L, `*) Oro: {pr.oro} monedas de oro.`)
	table.insert(L, `*) Experiencia: {pr.exp} puntos de experiencia.`)
	for _, par in pr.premios do
		table.insert(L, `*) {par[2]} {nombreObj(par[1])}`)
	end
	return table.concat(L, "\n")
end

return Reglas
