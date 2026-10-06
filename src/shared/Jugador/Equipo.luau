--!strict
--[[
	Equipo (Fase 32, docs/52 §4, pedido del autor): quién puede usar cada objeto, dicho en una frase, para las
	ventanas donde se elige qué fabricar o qué comprar (herrería, carpintería y comercio).

	La frase es la misma que usa la guía (herramientas/guia_ref.py) y la wiki: hasta ListaHasta clases se nombran; con
	más, se dicen las que no ("Todas menos Mago y Druida"). Verificado contra herramientas/fase32_ref.py.

	Fase 39 (docs/59 §4, pedido del autor): además, el skill mínimo que pide cada arma, armadura, casco y escudo para
	equiparse (`skill` y `minSkill` del objeto, que salen de herramientas/fase39_ref.py). Lo miran el servidor (al
	equipar), el inventario (la X roja) y las mismas ventanas ("Pide 55 de Evasion en combate").
]]

local Clases = require(script.Parent.Parent.Config.Clases)
local Cuenta = require(script.Parent.Parent.Config.Cuenta)
local Skills = require(script.Parent.Parent.Config.Skills)

local Equipo = {}

Equipo.ListaHasta = 6

-- Lo que se equipa: en eso tiene sentido decir qué clases lo usan
local SE_EQUIPA = { arma = true, armadura = true, casco = true, escudo = true, anillo = true, instrumento = true, municion = true }

local function nombreClase(c: string): string
	return Cuenta.NombreClase[c] or c
end

-- "A", "A y B", "A, B y C" ("e" delante de i / hi)
local function enumerar(items: { string }): string
	local n = #items
	if n == 0 then
		return ""
	elseif n == 1 then
		return items[1]
	end
	local ultimo = items[n]
	local inicio = string.lower(string.sub(ultimo, 1, 2))
	local nexo = if string.sub(inicio, 1, 1) == "i" or inicio == "hi" then " e " else " y "
	return table.concat(items, ", ", 1, n - 1) .. nexo .. ultimo
end

function Equipo.llevaClases(o: any): boolean
	return o ~= nil and SE_EQUIPA[o.tipo] == true
end

-- ¿Esa clase puede usar el objeto? (solo la clase: el género y la raza de la ropa los mira Inventario)
function Equipo.laUsa(o: any, clase: string): boolean
	return not (o.clasesProhibidas and o.clasesProhibidas[clase])
end

-- "Todas las clases", "Guerrero, Bandido y Paladín" o "Todas menos Mago y Druida"
function Equipo.quienes(o: any): string
	local si, no = {}, {}
	for _, c in Clases.Orden do
		table.insert(if Equipo.laUsa(o, c) then si else no, nombreClase(c))
	end
	if #no == 0 then
		return "Todas las clases"
	elseif #si == 0 then
		return "Ninguna clase"
	elseif #si <= Equipo.ListaHasta then
		return enumerar(si)
	end
	return "Todas menos " .. enumerar(no)
end

-- El golpe o la defensa en una frase corta ("Golpe 6-17", "Defensa 35-40"); "" si el objeto no es equipo de pelea
function Equipo.dato(o: any): string
	if o.tipo == "arma" and not o.herramienta then
		return `Golpe {o.minHit or 0}-{o.maxHit or 0}`
	elseif o.tipo == "armadura" or o.tipo == "casco" or o.tipo == "escudo" then
		return `Defensa {o.minDef or 0}-{o.maxDef or 0}`
	end
	return ""
end

-- ─── El skill mínimo para equipar (Fase 39, docs/59 §4) ──────────────────────
-- Lo que pide skill: las armas (no las herramientas), las armaduras, los cascos y los escudos
local PIDE_SKILL = { arma = true, armadura = true, casco = true, escudo = true }
Equipo.MsgSkill = "Necesitas %d puntos en %s para poder equipar este objeto." -- (el texto del original, InvUsuario.bas:1246)

-- El skill que pide el objeto para equiparse: (clave, mínimo), o (nil, 0) si no pide nada
function Equipo.pide(o: any): (string?, number)
	if o and PIDE_SKILL[o.tipo] and typeof(o.skill) == "string" and typeof(o.minSkill) == "number" and o.minSkill > 0 then
		return o.skill, o.minSkill
	end
	return nil, 0
end

-- El nombre de un skill como lo dicen los mensajes del juego ("Evasion en combate")
function Equipo.nombreSkill(clave: string): string
	local i = Skills.Indice[clave]
	return if i then Skills.Lista[i].nombre else clave
end

-- Con esos skills (los del personaje, por clave), ¿le falta para equiparlo? Devuelve (clave, mínimo) de lo que le
-- falta, o (nil, 0) si puede.
function Equipo.leFalta(o: any, skills: { [string]: number }?): (string?, number)
	local clave, minimo = Equipo.pide(o)
	if clave and ((skills and skills[clave]) or 0) < minimo then
		return clave, minimo
	end
	return nil, 0
end

-- "Pide 55 de Evasion en combate", o "" si no pide nada
function Equipo.frasePide(o: any): string
	local clave, minimo = Equipo.pide(o)
	return if clave then `Pide {minimo} de {Equipo.nombreSkill(clave)}` else ""
end

-- La ficha entera para una ventana: { dato, "Lo usan: ...", "Pide ..." } (cada una puede venir vacía)
function Equipo.ficha(o: any): (string, string, string)
	if not o then
		return "", "", ""
	end
	return Equipo.dato(o), if Equipo.llevaClases(o) then "Lo usan: " .. Equipo.quienes(o) else "", Equipo.frasePide(o)
end

return Equipo
