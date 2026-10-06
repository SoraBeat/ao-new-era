--!strict
--[[
	Constantes de la subida de nivel y de los skills (docs/21 §6 y §7). Las tablas largas (ELU, LevelSkill, costo de
	cada punto de skill) están en Shared.Generado.Progresion (herramientas/fase12_ref.py exportar).
]]

local Progresion = {}

Progresion.NivelMaximo = 55 -- STAT_MAXELV (Server.ini:17, DF12-07 A); en la práctica el 54
Progresion.MaxExp = 999999999 -- MAXEXP (Declares.bas:418)
Progresion.LimiteNewbie = 12 -- LimiteNewbie (Declares.bas:235)

-- Topes (Declares.bas:519-526)
Progresion.MaxHp = 999
Progresion.MaxSta = 999
Progresion.MaxMana = 9999
Progresion.MaxHitMenos36 = 99
Progresion.MaxHitDesde36 = 999
Progresion.MaxAtributo = 40 -- MAXATRIBUTOS

-- Balance.dat (el ModVida de cada clase está en Config.Clases, docs/27 §1)
Progresion.DistribucionEntera = { 10, 20, 40, 20, 10 } -- E1..E5
Progresion.DistribucionSemientera = { 10, 40, 40, 10 } -- S1..S4
Progresion.ModRaza = {
	Humano = { Fuerza = 1, Agilidad = 1, Inteligencia = 0, Carisma = 0, Constitucion = 2 },
	Elfo = { Fuerza = -1, Agilidad = 3, Inteligencia = 2, Carisma = 2, Constitucion = 1 },
	Drow = { Fuerza = 2, Agilidad = 3, Inteligencia = 2, Carisma = -3, Constitucion = 0 },
	Gnomo = { Fuerza = -2, Agilidad = 3, Inteligencia = 4, Carisma = 1, Constitucion = 0 },
	Enano = { Fuerza = 3, Agilidad = 0, Inteligencia = -2, Carisma = -2, Constitucion = 3 },
} :: { [string]: { [string]: number } }
Progresion.Atributos = { "Fuerza", "Agilidad", "Inteligencia", "Carisma", "Constitucion" }

-- Por nivel (CheckUserLevel, Modulo_UsUaRiOs.bas:774-835): golpe, maná y energía de cada clase en Config.Clases

-- Guardar al subir de nivel (docs/21 §9.2) y el mensaje de la experiencia por matar a un jugador (cliente Protocol.bas)
Progresion.MsgExpPvp = "Has ganado %d puntos de experiencia."

-- ─── Premios por nivel (Fase 24, docs/43 §5; pedido del autor) ──────────────────────────────────────────────────
-- Al llegar a cada uno de estos niveles, una sola vez por personaje: oro, pociones "de premio" (las copias personales
-- PremioBase + 38 y PremioBase + 37 de Generado/ObjetosInventario: no se caen al morir ni se comercian) y Pociones de
-- Experiencia. La referencia: herramientas/fase24_ref.py (PREMIOS_NIVEL, premio_nivel, premios_pendientes).
Progresion.PremioBase = 20000
Progresion.PocionRoja, Progresion.PocionAzul, Progresion.PocionExp = 38, 37, 5100
Progresion.NivelesPremio = { 18, 25, 32, 40 }
-- [nivel] = { oro, pociones rojas, pociones azules (solo las clases con maná), pociones de experiencia }
Progresion.PremiosNivel = {
	[18] = { 20000, 150, 150, 1 },
	[25] = { 60000, 300, 300, 1 },
	[32] = { 150000, 500, 500, 2 },
	[40] = { 400000, 1000, 1000, 3 },
} :: { [number]: { number } }
Progresion.MsgPremio = "Llegaste al nivel %d! Tu premio: %s."
Progresion.MsgPremioOro = "%s monedas de oro"
Progresion.MsgPremioSinLugar = "Lo que no entro en tu inventario queda guardado: se te entrega cuando tengas lugar."

-- Fase 27 (docs/47 §4; pedido del autor; herramientas/fase27_ref.py extra_nivel): el premio extra del nivel 18, una
-- sola vez por personaje (y también para los que ya habían pasado ese nivel). Las clases mágicas aprenden
-- Petrificación (va derecho a la lista de hechizos: no hay pergamino). Las demás reciben pociones "de premio": con
-- las 150 rojas del premio de siempre llegan a 1.000 rojas, más 100 verdes y 100 amarillas.
Progresion.ExtraNivel = { nivel = 18, hechizo = 68, objetos = { { 20038, 850 }, { 20039, 100 }, { 20036, 100 } } }
Progresion.MsgExtraHechizo = "Premio del nivel %d para tu clase: el hechizo %s. Ya esta en tu lista de hechizos."
Progresion.MsgExtraObjetos = "Premio del nivel %d para tu clase: %s."

-- { oro, objetos = { { objeto, cantidad } } } del nivel, o nil si ese nivel no tiene premio
function Progresion.premioNivel(nivel: number, conMana: boolean): { oro: number, objetos: { { number } } }?
	local p = Progresion.PremiosNivel[nivel]
	if not p then
		return nil
	end
	local objetos = { { Progresion.PremioBase + Progresion.PocionRoja, p[2] } }
	if conMana then
		table.insert(objetos, { Progresion.PremioBase + Progresion.PocionAzul, p[3] })
	end
	table.insert(objetos, { Progresion.PocionExp, p[4] })
	return { oro = p[1], objetos = objetos }
end

-- Los niveles de premio que le tocan a un personaje de ese nivel y todavía no recibió, de menor a mayor
function Progresion.premiosPendientes(nivel: number, recibidos: { number }): { number }
	local out = {}
	for _, n in Progresion.NivelesPremio do
		if n <= nivel and not table.find(recibidos, n) then
			table.insert(out, n)
		end
	end
	return out
end

return Progresion
