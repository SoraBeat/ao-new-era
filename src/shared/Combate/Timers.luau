--!strict
--[[
	Timers — intervalos de golpe y hechizo.

	Servidor: los gates de modNuevoTimer.bas (candado clásico literal, D-04 A; spec 14 §2.1, spec 15 §4)
	con dos agregados decididos en la Fase 7:
	  - DF7-05: tolerancia por latencia (`gracia`) restada en las comparaciones de tiempo.
	  - DF7-16: tope anti-ráfaga: 1000 - gracia ms entre dos acciones cualesquiera, antes de los gates.
	Cliente: los timers del cliente clásico (MainTimer.cls:192-218, frmMain.frm), literales (DF7-04 A), con los mismos
	números que el servidor (como el WriteIntervals de AO20; DF11-01 B).

	Todo en ms. Módulo puro: se puede probar con el CLI de Luau (usarConfig).
]]

local ReplicatedStorage = game and game:GetService("ReplicatedStorage")

export type Config = {
	atacar: number,
	hechizo: number,
	magiaGolpe: number,
	golpeMagia: number,
	flechas: number, -- Fase 14a: IntervaloFlechasCazadores (docs/27 §2.1)
	gracia: number,
	antiRafaga: boolean,
	-- Fase 9: pociones (docs/17 §7)
	usar: number,
	golpeUsar: number,
	topeUsos: number,
	topeUsosMs: number,
}

local cfg: Config
if ReplicatedStorage then
	local C = require(ReplicatedStorage.Shared.Config.Combate) :: any
	cfg = {
		atacar = C.IntervaloUserPuedeAtacar,
		hechizo = C.IntervaloLanzaHechizo,
		magiaGolpe = C.IntervaloMagiaGolpe,
		golpeMagia = C.IntervaloGolpeMagia,
		flechas = C.IntervaloFlechasCazadores,
		gracia = C.GraciaLatencia,
		antiRafaga = C.AntiRafaga,
		usar = C.IntervaloUserPuedeUsar,
		golpeUsar = C.IntervaloGolpeUsar,
		topeUsos = 0,
		topeUsosMs = 0,
	}
	local I = require(ReplicatedStorage.Shared.Config.Inventario) :: any
	cfg.topeUsos, cfg.topeUsosMs = I.TopeUsos, I.TopeUsosMs
end

local Timers = {}

-- Intervalos del cliente (cliente/Declares.bas:112-124): los mismos que el servidor (DF11-01 B). En el clásico
-- son 1500 / 1400 / 1000.
local CLIENTE = { Attack = 1500, CastSpell = 1400, CastAttack = 1000, Arrows = 1400 }
local function clienteDesdeConfig()
	if cfg then
		CLIENTE = { Attack = cfg.atacar, CastSpell = cfg.hechizo, CastAttack = cfg.golpeMagia, Arrows = cfg.flechas or 1400 }
	end
end
clienteDesdeConfig()

function Timers.usarConfig(c: Config)
	cfg = c
	clienteDesdeConfig()
end

-- Todos al mismo valor muy negativo: el primer golpe y el primer hechizo pasan y el candado arranca
-- como en el original (spec 14 §2.1)
local T0 = -1e9

-- ─── Servidor ────────────────────────────────────────────────────────────────
export type Servidor = {
	puedeAtacar: number,
	golpeUsar: number,
	lanzarSpell: number,
	magiaGolpe: number,
	golpeMagia: number,
	usarArco: number,
	ultimaAccion: number,
	usar: number,
	usos: { number }, -- últimos usos aceptados (tope DF9-07 C)
}

function Timers.nuevoServidor(): Servidor
	return {
		puedeAtacar = T0,
		golpeUsar = T0,
		lanzarSpell = T0,
		magiaGolpe = T0,
		golpeMagia = T0,
		usarArco = T0,
		ultimaAccion = T0,
		usar = T0,
		usos = {},
	}
end

-- modNuevoTimer.bas:96-122
local function permiteAtacar(t: Servidor, now: number): boolean
	if now - t.puedeAtacar >= cfg.atacar - cfg.gracia then
		t.puedeAtacar = now
		t.golpeUsar = now
		return true
	end
	return false
end

-- modNuevoTimer.bas:69-94
local function permiteLanzarSpell(t: Servidor, now: number): boolean
	if now - t.lanzarSpell >= cfg.hechizo - cfg.gracia then
		t.lanzarSpell = now
		return true
	end
	return false
end

-- modNuevoTimer.bas:150-185 (hechizo -> golpe, un uso por hechizo)
local function permiteMagiaGolpe(t: Servidor, now: number): boolean
	if t.magiaGolpe > t.lanzarSpell then
		return false
	end
	if now - t.lanzarSpell >= cfg.magiaGolpe - cfg.gracia then
		t.magiaGolpe = now
		t.puedeAtacar = now
		t.golpeUsar = now
		return true
	end
	return false
end

-- modNuevoTimer.bas:187-217 (golpe -> hechizo, un uso por golpe)
local function permiteGolpeMagia(t: Servidor, now: number): boolean
	if t.golpeMagia > t.puedeAtacar then
		return false
	end
	if now - t.puedeAtacar >= cfg.golpeMagia - cfg.gracia then
		t.golpeMagia = now
		t.lanzarSpell = now
		return true
	end
	return false
end

local function rafaga(t: Servidor, now: number): boolean
	return cfg.antiRafaga and now - t.ultimaAccion < cfg.magiaGolpe - cfg.gracia
end

-- IntervaloPermiteUsarArcos (modNuevoTimer.bas:285-310). Fase 14a (docs/27 §2.1): disparar lo actualiza; golpear y
-- lanzar solo lo consultan (SistemaCombate.bas:1167, Protocol.bas:3467).
local function arcoListo(t: Servidor, now: number): boolean
	return now - t.usarArco >= (cfg.flechas or 0) - cfg.gracia
end

-- Golpe: MagiaGolpe y, si no, Atacar (SistemaCombate.bas:1170-1178). Devuelve el gate que pasó o nil.
function Timers.golpe(t: Servidor, now: number): string?
	if rafaga(t, now) or not arcoListo(t, now) then
		return nil
	end
	local g = if permiteMagiaGolpe(t, now) then "MagiaGolpe" elseif permiteAtacar(t, now) then "Atacar" else nil
	if g then
		t.ultimaAccion = now
	end
	return g
end

-- Hechizo: GolpeMagia y, si no, LanzarSpell (Protocol.bas:3470-3477)
function Timers.hechizo(t: Servidor, now: number): string?
	if rafaga(t, now) or not arcoListo(t, now) then
		return nil
	end
	local g = if permiteGolpeMagia(t, now) then "GolpeMagia" elseif permiteLanzarSpell(t, now) then "LanzarSpell" else nil
	if g then
		t.ultimaAccion = now
	end
	return g
end

-- Disparar (HandleWorkLeftClick con Proyectiles, Protocol.bas:3434-3447): consulta Atacar y LanzarSpell sin
-- actualizarlos y actualiza el del arco. Con el tope anti-ráfaga de DF7-16, como el golpe y el hechizo.
function Timers.disparo(t: Servidor, now: number): boolean
	if rafaga(t, now) then
		return false
	end
	if now - t.puedeAtacar < cfg.atacar - cfg.gracia or now - t.lanzarSpell < cfg.hechizo - cfg.gracia then
		return false
	end
	if not arcoListo(t, now) then
		return false
	end
	t.usarArco = now
	t.ultimaAccion = now
	return true
end

-- Usar un objeto (docs/17 §7.1): IntervaloPermiteUsar (modNuevoTimer.bas:257), con la tolerancia de DF7-05 y
-- el tope de DF9-07 C. Actualiza el timer. No mira ni toca el tope anti-ráfaga de DF7-16.
function Timers.usar(t: Servidor, now: number): boolean
	if now - t.usar < cfg.usar - cfg.gracia then
		return false
	end
	local n = cfg.topeUsos
	if n > 0 then
		local u = t.usos
		if #u >= n and now - u[#u - n + 1] < cfg.topeUsosMs then
			return false
		end
		table.insert(u, now)
		if #u > n then
			table.remove(u, 1)
		end
	end
	t.usar = now
	return true
end

-- IntervaloPermiteGolpeUsar(Actualizar:=False) (modNuevoTimer.bas:124-148): pasaron 1200 ms desde el último golpe
function Timers.golpeUsarListo(t: Servidor, now: number): boolean
	return now - t.golpeUsar >= cfg.golpeUsar - cfg.gracia
end

-- ─── Cliente clásico ─────────────────────────────────────────────────────────
-- Intervalos del cliente: CLIENTE, arriba (salen de la misma configuración que el servidor).

export type Cliente = { Attack: number, CastSpell: number, CastAttack: number, Arrows: number }

function Timers.nuevoCliente(): Cliente
	return { Attack = T0, CastSpell = T0, CastAttack = T0, Arrows = T0 }
end

-- MainTimer.Check: pasa si venció; si restart, reinicia acoplado
local function check(c: Cliente, nombre: string, now: number, restart: boolean): boolean
	local ct = c :: any
	if now - ct[nombre] >= CLIENTE[nombre] then
		if restart then
			ct[nombre] = now
			if nombre == "Attack" or nombre == "CastSpell" then
				c.CastAttack = now
			elseif nombre == "CastAttack" then
				c.Attack = now
				c.CastSpell = now
			end
		end
		return true
	end
	return false
end

-- Ctrl (frmMain.frm:1868-1885). true = manda Atacar.
function Timers.ctrl(c: Cliente, now: number, meditando: boolean?): boolean
	if not check(c, "CastSpell", now, false) then
		return check(c, "CastAttack", now, true)
	end
	local ok = check(c, "Attack", now, true) -- VB6 no corta el Or: reinicia aunque medite
	return ok and not meditando
end

-- Click con el cursor armado (frmMain.frm:2586-2616). true = manda Lanzar; false = desarma el cursor. Antes, como
-- cualquier click con un skill armado, espera el timer de las flechas (frmMain.frm:2552).
function Timers.clickHechizo(c: Cliente, now: number): boolean
	if not check(c, "Arrows", now, false) then
		return false
	end
	if not check(c, "Attack", now, false) then
		return check(c, "CastAttack", now, true)
	end
	return check(c, "CastSpell", now, true)
end

-- Click con el cursor del arco (frmMain.frm:2552-2582): Check(Arrows, False) y después Check(Arrows). true = dispara.
function Timers.clickFlecha(c: Cliente, now: number): boolean
	return check(c, "Arrows", now, true)
end

-- Timers de uso del cliente (UseItemWithU 450, UseItemWithDblClick 125): sueltos, sin acople
export type ClienteUso = { [string]: number }
function Timers.nuevoClienteUso(): ClienteUso
	return {}
end
function Timers.clienteUsar(c: ClienteUso, via: string, intervalo: number, now: number): boolean
	if now - (c[via] or T0) >= intervalo then
		c[via] = now
		return true
	end
	return false
end

-- Tiempo que falta (ms) para que el cliente deje golpear / lanzar, y el intervalo que lo gobierna. Para el
-- indicador de espera de los botones táctiles (DF9-08 B).
local function restante(c: Cliente, nombre: string, now: number): (number, number)
	local r = CLIENTE[nombre] - (now - (c :: any)[nombre])
	return math.max(0, r), CLIENTE[nombre]
end
function Timers.restanteCtrl(c: Cliente, now: number): (number, number)
	if not check(c, "CastSpell", now, false) then
		return restante(c, "CastAttack", now)
	end
	return restante(c, "Attack", now)
end
function Timers.restanteHechizo(c: Cliente, now: number): (number, number)
	if not check(c, "Attack", now, false) then
		return restante(c, "CastAttack", now)
	end
	return restante(c, "CastSpell", now)
end

-- Para la UI: ¿se podría golpear / lanzar ahora? (sin reiniciar nada)
function Timers.listoCtrl(c: Cliente, now: number): boolean
	if not check(c, "CastSpell", now, false) then
		return check(c, "CastAttack", now, false)
	end
	return check(c, "Attack", now, false)
end

return Timers
