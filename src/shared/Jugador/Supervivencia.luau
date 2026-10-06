--!strict
--[[
	Supervivencia — las cuentas puras de la fogata (Fase 19, docs/38 §2 y §3). Las mismas de
	herramientas/fase19_ref.py, verificadas contra muestras/fase19_vectores.json.

	Hacer ramitas: TratarDeHacerFogata (Trabajo.bas:1724-1817). Prender: AccionParaRamita (Acciones.bas:354-441).
	Descansar: HandleRest (Protocol.bas:6470-6515).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cfg = require(ReplicatedStorage.Shared.Config.Supervivencia)

local Supervivencia = {}

local M = Cfg.Msg

-- 1 de cada `suerte` (Trabajo.bas:1777-1786)
function Supervivencia.suerteRamitas(skill: number): number
	return if skill < 6 then 3 elseif skill <= 34 then 2 else 1
end

-- Acciones.bas:397-408
function Supervivencia.suertePrender(skill: number): number
	return if skill < 6 then 3 elseif skill <= 10 then 2 else 1
end

-- Una cada tres maderas; el resto se pierde
function Supervivencia.ramitas(maderas: number): number
	return maderas // Cfg.MaderasPorFogata
end

-- Por qué no se pueden hacer las ramitas (nil = se intenta), en el orden del original (Trabajo.bas:1742-1771).
-- ocupado: hay un personaje o una criatura parado sobre la leña (LegalPos, :1742; el original sale sin avisar)
function Supervivencia.motivoRamitas(obj: number, cantidad: number, dist: number, dagaEquipada: boolean, ocupado: boolean): string?
	if not dagaEquipada then
		return M.equipar
	end
	if ocupado then
		return M.ocupado
	end
	if obj ~= Cfg.Madera then
		return M.sinMadera
	end
	if dist > Cfg.Distancia then
		return M.lejosHacer
	end
	if cantidad < Cfg.MaderasPorFogata then
		return M.pocas
	end
	return nil
end

-- Antes de tirar la suerte (Acciones.bas:381-391). ciudad: el mapa tiene Zona = CIUDAD; el original lo mira después
-- de la suerte (:413) y el aviso solo sale si la tirada fue buena. Acá va antes (docs/38 §7).
function Supervivencia.motivoPrender(dist: number, mapaSeguro: boolean, tileSeguro: boolean, ciudad: boolean): string?
	if dist > Cfg.Distancia then
		return M.lejosPrender
	end
	if tileSeguro or mapaSeguro then
		return M.zonaSegura
	end
	if ciudad then
		return M.ciudad
	end
	return nil
end

-- HayOBJarea: la fogata (fx, fy) entra en la pantalla del que está en (x, y)
function Supervivencia.aLaVista(x: number, y: number, fx: number, fy: number): boolean
	return math.abs(fx - x) <= Cfg.VistaX and math.abs(fy - y) <= Cfg.VistaY
end

-- ─── Comer de los árboles y beber del agua (Fase 28, docs/48 §1.1) ────────────
-- Por qué no puede (nil = puede) y la marca de ese aviso, para no repetirlo seguido. tipo: "comer" | "beber"; valor:
-- el hambre o la sed que tiene, de 0 a max.
-- Al que no tiene el skill se le avisa antes de mirar la distancia: si no, cualquier doble click sobre un árbol lejano
-- le diría "Estas demasiado lejos." a quien igual no puede.
function Supervivencia.motivoForraje(tipo: string, skill: number, dist: number, muerto: boolean, valor: number, max: number): (string?, number)
	local comer = tipo == "comer"
	local base = Cfg.MarcaForraje + (if comer then 0 else 4)
	if muerto then
		return M.muerto, base + 3
	end
	if skill < Cfg.SkillForraje then
		return string.format(if comer then M.sinSkillComer else M.sinSkillBeber, Cfg.SkillForraje), base
	end
	if dist > Cfg.Distancia then
		return M.lejosPrender, base + 2
	end
	if valor >= max then
		return if comer then M.sinHambre else M.sinSed, base + 1
	end
	return nil, 0
end

export type Rect = { x0: number, y0: number, x1: number, y1: number }

-- Los tiles que tapa un dibujo de la capa 3 anclado en (ax, ay), de ancho w y alto h en pixeles: centrado en el tile y
-- apoyado en su borde de abajo (Draw_Grh con Center, TileEngine.bas)
function Supervivencia.rectDibujo(ax: number, ay: number, w: number, h: number): Rect
	local izq = ax * 32 - (w - 32) // 2 -- la misma cuenta que el cliente (Render/Grh.ubicar)
	local arriba = (ay + 1) * 32 - h
	return { x0 = math.floor(izq / 32), y0 = math.floor(arriba / 32), x1 = math.floor((izq + w - 1) / 32), y1 = ay }
end

-- Une los rectángulos del mismo ancho que se tocan por arriba o por abajo (la fuente de Gotland son ocho tiras)
function Supervivencia.unirRects(rects: { Rect }): { Rect }
	local r = table.clone(rects)
	local cambio = true
	while cambio do
		cambio = false
		for i = 1, #r do
			for j = i + 1, #r do
				local a, b = r[i], r[j]
				if a.x0 == b.x0 and a.x1 == b.x1 and a.y0 <= b.y1 + 1 and b.y0 <= a.y1 + 1 then
					r[i] = { x0 = a.x0, x1 = a.x1, y0 = math.min(a.y0, b.y0), y1 = math.max(a.y1, b.y1) }
					table.remove(r, j)
					cambio = true
					break
				end
			end
			if cambio then
				break
			end
		end
	end
	return r
end

function Supervivencia.enRect(r: Rect, x: number, y: number): boolean
	return x >= r.x0 and x <= r.x1 and y >= r.y0 and y <= r.y1
end

-- De (x, y) al rectángulo, sumando los dos ejes (0 = adentro)
function Supervivencia.distRect(r: Rect, x: number, y: number): number
	return math.max(r.x0 - x, 0, x - r.x1) + math.max(r.y0 - y, 0, y - r.y1)
end

-- La vida, en los pasos de la barra (Fase 28, docs/48 §5.2): 0 solo si está muerto; con vida, de 1 a pasos
function Supervivencia.pasosVida(hp: number, max: number, pasos: number): number
	if hp <= 0 or max <= 0 then
		return 0
	end
	return math.clamp(math.ceil(hp / max * pasos), 1, pasos)
end

return Supervivencia
