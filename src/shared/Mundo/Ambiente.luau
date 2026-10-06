--!strict
--[[
	Ambiente — las cuentas de la Fase 18 (docs/37): la lluvia y el día por el reloj, quién se moja, y los golpes del
	frío y de la lava. Sin estado: las usan el servidor (AmbienteService) y el cliente (Render/Clima).

	Son las mismas de herramientas/fase18_ref.py; se verifican contra docs/muestras/fase18_vectores.json. Desde la Fase 21
	(docs/40 §6) la lluvia es la de herramientas/fase21_ref.py (el inicio sorteado y la gracia del servidor), y sus
	vectores, los de docs/muestras/fase21_vectores.json; los de lluvia de la Fase 18 quedaron como historia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Ambiente)
local Formulas = require(ReplicatedStorage.Shared.Combate.Formulas)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Generado = require(ReplicatedStorage.Shared.Generado.Ambiente)

local Ambiente = {}

-- ─── Lluvia por el reloj (DA18-02 A) ─────────────────────────────────────────
-- a * b módulo 2^32 sin pasar de 2^53 (a < 2^32, b < 2^27)
local function mul32(a: number, b: number): number
	local bajo, alto = a % 65536, math.floor(a / 65536)
	return (bajo * b + ((alto * b) % 65536) * 65536) % 4294967296
end

-- Un entero → 32 bits bien revueltos (igual que fase18_ref.mezcla)
function Ambiente.mezcla(n: number): number
	local x = n % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45D9F3B)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45D9F3B)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end

-- Minutos que llueve en el ciclo: en cada minuto menos el último, ProbCorte % de cortarse (tLluviaEvent)
function Ambiente.duracionLluvia(ciclo: number): number
	for k = 1, Cfg.MaxLluviaMin - 1 do
		if Ambiente.mezcla(ciclo * 8 + k) % 100 < Cfg.ProbCorte then
			return k
		end
	end
	return Cfg.MaxLluviaMin
end

-- Fase 21 (docs/40 §6.2; fase21_ref.inicio_lluvia): el minuto del ciclo en el que empieza a llover, sorteado con el
-- número de ciclo (igual en todos los servidores): de InicioMin a SecoMin. Hasta la Fase 20 era siempre SecoMin.
function Ambiente.inicioLluvia(ciclo: number): number
	return Cfg.InicioMin + Ambiente.mezcla(ciclo * 8 + 7) % (Cfg.SecoMin - Cfg.InicioMin + 1)
end

-- (llueve, segundos hasta el próximo cambio, cuándo empezó esta lluvia) a la hora t (os.time()). El tercero, en
-- segundos de os.time(), solo si llueve.
function Ambiente.lluvia(t: number): (boolean, number, number?)
	local cicloMin = Cfg.SecoMin + Cfg.MaxLluviaMin
	local m = math.floor(t / 60)
	local ciclo, en = math.floor(m / cicloMin), m % cicloMin
	local ini, d = Ambiente.inicioLluvia(ciclo), Ambiente.duracionLluvia(ciclo)
	local seg = t % 60
	if en < ini then
		return false, (ini - en) * 60 - seg, nil
	elseif en < ini + d then
		return true, (ini + d - en) * 60 - seg, (ciclo * cicloMin + ini) * 60
	end
	return false, (cicloMin - en + Ambiente.inicioLluvia(ciclo + 1)) * 60 - seg, nil
end

-- Lo que ve un servidor que abrió en `abrio` (D21-23 A): la lluvia que empezó antes de que pase la gracia se saltea
-- entera
function Ambiente.lluviaServidor(t: number, abrio: number): boolean
	local llueve, _, empezo = Ambiente.lluvia(t)
	return llueve and empezo ~= nil and empezo >= abrio + Cfg.GraciaServidorSeg
end

-- Dónde llueve (DA18-04 A): la lista del cliente original (INIT/FK.ind)
function Ambiente.llueveEn(mapa: number): boolean
	return Generado.llueve[mapa] == true
end

-- Intemperie (General.bas:812-837): en un mapa donde llueve, fuera de techo, casa y zona segura, y no en una arena
function Ambiente.intemperie(llueveEnMapa: boolean, trigger: number, enArena: boolean?): boolean
	local T = Mapas.TRIGGER
	return llueveEnMapa and trigger ~= T.BAJOTECHO and trigger ~= T.CASA and trigger ~= T.ZONASEGURA and not enArena
end

-- EfectoLluvia (General.bas:839-864): la energía después de un segundo a la intemperie
function Ambiente.efectoLluvia(sta: number, maxSta: number): number
	return math.max(0, sta - Formulas.porcentaje(maxSta, Cfg.LluviaPorcSta))
end

-- ─── Frío y lava ─────────────────────────────────────────────────────────────
-- EfectoFrio en la nieve y EfectoLava: (vida nueva, murió). Muere con menos de 1
function Ambiente.golpeVida(hp: number, maxHp: number, porc: number): (number, boolean)
	hp -= Formulas.porcentaje(maxHp, porc)
	if hp < 1 then
		return 0, true
	end
	return hp, false
end

-- HayLava (General.bas:175-196): el Grh de la capa 1
function Ambiente.hayLava(grhCapa1: number): boolean
	return grhCapa1 >= Cfg.LavaMin and grhCapa1 <= Cfg.LavaMax
end

-- ¿Le corre el frío que saca vida? (DA18-07 B). segDesdeRevivir: nil si no resucitó
function Ambiente.frioNieve(mapa: number, desnudo: boolean, muerto: boolean?, dios: boolean?, segDesdeRevivir: number?): boolean
	if muerto or dios or not desnudo or not Cfg.MapasFrio[mapa] then
		return false
	end
	return segDesdeRevivir == nil or segDesdeRevivir >= Cfg.GraciaRevivirSeg
end

-- ─── El día (DA18-09 A, DA18-10 A) ───────────────────────────────────────────
-- (índice de la fase, nombre, segundos desde que empezó). Con otro largo de día, todo a escala
function Ambiente.fase(t: number, diaMin: number?): (number, string, number)
	local largo = diaMin or Cfg.DiaMin
	local k = largo / Cfg.DiaMin
	local seg = t % (largo * 60)
	local i = 1
	for j, f in Cfg.Fases do
		if seg >= f[2] * 60 * k then
			i = j
		end
	end
	return i, Cfg.Fases[i][1], seg - Cfg.Fases[i][2] * 60 * k
end

-- El color (r, g, b de 0 a 255) que multiplica el mapa a la hora t: el de la fase, llegando en TransicionSeg desde el
-- de la fase anterior
function Ambiente.luzRGB(t: number, diaMin: number?): (number, number, number)
	local i, nombre, desde = Ambiente.fase(t, diaMin)
	local c1 = Cfg.Color[nombre]
	if desde >= Cfg.TransicionSeg then
		return math.round(c1.R * 255), math.round(c1.G * 255), math.round(c1.B * 255)
	end
	local anterior = Cfg.Fases[if i == 1 then #Cfg.Fases else i - 1][1]
	local c0 = Cfg.Color[anterior]
	local a = desde / Cfg.TransicionSeg
	local function mezclar(v0: number, v1: number): number
		local x0, x1 = math.round(v0 * 255), math.round(v1 * 255)
		return math.floor(x0 + (x1 - x0) * a + 0.5)
	end
	return mezclar(c0.R, c1.R), mezclar(c0.G, c1.G), mezclar(c0.B, c1.B)
end

function Ambiente.luz(t: number, diaMin: number?): Color3
	return Color3.fromRGB(Ambiente.luzRGB(t, diaMin))
end

-- En todo lo que no es dungeon (la misma regla de la lluvia del servidor)
function Ambiente.hayNoche(zona: string): boolean
	return string.upper(zona) ~= "DUNGEON"
end

return Ambiente
