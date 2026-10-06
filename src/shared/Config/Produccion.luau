--!strict
--[[
	Producción (Fase 16b, docs/32-spec-produccion.md): fundir, herrería, carpintería, mejorar y fundir armas.
	Referencia: herramientas/fase16b_ref.py. Las recetas están en Shared.Generado.Recetas.
]]

local Produccion = {}

-- Intervalo de trabajo (IntervaloTrabajo, Server.ini:134): el mismo de talar, pescar, minar y robar
Produccion.IntervaloTrabajo = 850

-- Divisores de skill por clase (Trabajo.bas:1409-1464): 1 el Trabajador; el resto, 3 / 4 / 3
function Produccion.modFundicion(clase: string): number
	return if clase == "Trabajador" then 1 else 3
end
function Produccion.modHerreria(clase: string): number
	return if clase == "Trabajador" then 1 else 4
end
function Produccion.modCarpinteria(clase: string): number
	return if clase == "Trabajador" then 1 else 3
end

-- Energía por ciclo de construir o mejorar (Trabajo.bas:32-34)
Produccion.MaderaElfica = 1006 -- LenaElfica (Declares.bas:434; P8, docs/36 §9)
Produccion.StaTrabajador = 2
Produccion.StaResto = 6

-- Las herramientas de cada oficio (equipadas como arma)
Produccion.Herramientas = {
	Herreria = { [389] = true, [565] = true },
	Carpinteria = { [198] = true, [564] = true },
} :: { [string]: { [number]: boolean } }

-- Sonidos (SND_TRABAJO_HERRERO / _CARPINTERO, Declares.bas:681-683)
Produccion.Sonido = { Herreria = 41, Carpinteria = 42 } :: { [string]: number }

-- Mensajes del original (Trabajo.bas, Protocol.bas) y los nuestros (marcados)
Produccion.Msg = {
	NoFragua = "Ahi no hay ninguna fragua.",
	NoYunque = "Ahi no hay ningUn yunque.",
	SinConocimientos = "No tienes conocimientos de mineria suficientes para trabajar este mineral.",
	SinMinerales = "No tienes mas minerales.",
	PocosMinerales = "No tienes suficientes minerales para hacer un lingote.",
	SinHerreria = "No tienes los conocimientos suficientes en herreria para fundir este objeto.",
	FundirArma = "Has obtenido el %d%% de los lingotes utilizados para la construccion del objeto!",
	HerramientasNo = "Las herramientas no se pueden fundir.",
	DesequipaArma = "Primero desequipa el arma.", -- nuestro (DP16-09 A)
	SinMateriales = "No tienes suficientes materiales.",
	SinMadera = "No tienes suficiente madera.",
	SinMaderaElfica = "No tienes suficiente madera elfica.", -- Trabajo.bas:495 (P8, docs/36 §9)
	SinEnergia = "No tienes suficiente energia.",
	SinLugar = "No puedes cargar mas objetos.",
	Martillo = "Debes equiparte el martillo de herrero.",
	Serrucho = "Debes tener equipado el serrucho para trabajar.",
	YunqueLejos = "Tienes que estar cerca del yunque.", -- nuestro (DP16-04 A)
	SinSkill = "No tienes suficientes skills.",
	Terminado = "Has terminado de trabajar!",
	Cancelado = "Dejaste de trabajar.", -- nuestro (la cola, DP16-05 A)
}

-- Lo construido, por tipo (Trabajo.bas:790-804; carpintería, :970)
Produccion.Construido = {
	arma = { "Has construido el arma!", "Has construido %d armas!" },
	escudo = { "Has construido el escudo!", "Has construido %d escudos!" },
	casco = { "Has construido el casco!", "Has construido %d cascos!" },
	armadura = { "Has construido la armadura!", "Has construido %d armaduras" },
	municion = { "Has construido la flecha!", "Has construido %d flechas!" }, -- nuestro (Fase 34): salen todas juntas
	otro = { "Has construido 1 objeto!", "Has construido %d objetos!" },
} :: { [string]: { string } }

-- Lo mejorado (Trabajo.bas:1330-1376)
Produccion.Mejorado = {
	arma = "Has mejorado el arma!",
	escudo = "Has mejorado el escudo!",
	casco = "Has mejorado el casco!",
	armadura = "Has mejorado la armadura!",
	municion = "Has mejorado la flecha!",
} :: { [string]: string }
Produccion.MejoradoVarias = "Has mejorado %d flechas!" -- nuestro (Fase 34): las flechas se mejoran todas juntas

-- Fase 34 (docs/54 §7; pedido del autor: "que las flechas no se fabriquen de 1 en 1"): lo de estos tipos se
-- construye (o se mejora) todo junto, en un solo ciclo de trabajo: el total pedido, o lo que alcance con la madera.
-- Lo demás sigue de a "por ciclo" cada IntervaloTrabajo.
Produccion.DeUna = { municion = true } :: { [string]: boolean }
function Produccion.deUna(tipo: string?): boolean
	return tipo ~= nil and Produccion.DeUna[tipo] == true
end

-- Cuántos salen en un ciclo. pedido: lo que falta del total; porCiclo: lo que hace el trabajador de una vez;
-- alcanza: para cuántos dan los materiales. deUna: todo junto.
function Produccion.enUnCiclo(deUna: boolean, pedido: number, porCiclo: number, alcanza: number): number
	local n = if deUna then pedido else math.min(porCiclo, pedido)
	return math.max(0, math.min(n, alcanza))
end

-- Tope del total pedido en la ventana (MAX_INVENTORY_OBJS)
Produccion.MaxTotal = 10000

return Produccion
