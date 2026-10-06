--!strict
--[[
	LimpiezaService — limpieza del mundo (DF11-09 A, docs/20 §5.5): mLimpieza.bas y mMainLoop.bas:350-383.

	- Cada objeto que se pone en el piso (MundoService.ponerObjeto: tirar, apilar, cada slot del drop al morir) se
	  anota, salvo en tiles bloqueados. Agarrarlo no borra la entrada. Los objetos del mapa no pasan por acá.
	- Cuando las entradas llegan exactamente a 1500, arranca una cuenta de 16 s (tickLimpieza = 16). Salen los
	  avisos de 15 y 10 segundos; el de 5..1 está escrito `Case 5 To 1` (mMainLoop.bas:377) y en VB6 ese rango
	  nunca se cumple, así que no sale. A los 16 s se borra lo que haya en cada tile anotado.
	- Fase 23 (docs/42 §6.2, D23-30 A): un administrador puede pedir la misma cuenta (`pedir`, el /LIMPIARMUNDO del
	  original) o limpiar en el acto un solo mapa (`limpiarMapa`, nuestro). En los dos casos queda lo que está bajo
	  techo y lo que vino con el mapa.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Grilla = require(ReplicatedStorage.Shared.Mundo.Grilla)
local Mapas = require(ReplicatedStorage.Shared.Mundo.Mapas)
local Remotes = require(ReplicatedStorage.Shared.Red.Remotes)
local MundoService = require(ServerScriptService.Server.Mundo.MundoService)

local LimpiezaService = {}

local MAXITEMS = 1500 -- mLimpieza.bas:4
local TICK_INICIAL = 16 -- mLimpieza.bas:18

local lista: { { number } } = {}
local tickLimpieza = 0
local evConsola: RemoteEvent

local AVISOS: { [number]: string } = { -- mMainLoop.bas:356-375
	[300] = "Servidor> Limpieza del mundo en 5 Minuto. Atentos!!",
	[240] = "Servidor> Limpieza del mundo en 4 Minutos. Atentos!!",
	[180] = "Servidor> Limpieza del mundo en 3 Minutos. Atentos!!",
	[120] = "Servidor> Limpieza del mundo en 2 Minutos. Atentos!!",
	[60] = "Servidor> Limpieza del mundo en 1 Minuto. Atentos!!",
	[15] = "Servidor> Limpieza del mundo en 15 segundos. Atentos!!",
	[10] = "Servidor> Limpieza del mundo en 10 segundos. Atentos!!",
}

local function aTodos(texto: string)
	evConsola:FireAllClients(texto, "servidor")
end

-- AgregarObjetoLimpieza (mLimpieza.bas:8-19). Fase 13: cada entrada con su mapa.
local function anotar(n: number, x: number, y: number)
	local mapa = MundoService.mapa(n)
	if mapa and Grilla.estaBloqueado(mapa, x, y) then
		return -- InvUsuario.bas:708: el Or de casas/bajo techo es siempre verdadero; solo cuenta el bloqueo
	end
	table.insert(lista, { n, x, y })
	if #lista == MAXITEMS then
		tickLimpieza = TICK_INICIAL
	end
end

-- Borra lo que haya en un tile anotado: ni bajo techo ni en una casa ni en un tile bloqueado. Devuelve si borró algo.
local function borrarEn(n: number, x: number, y: number): boolean
	local mapa = MundoService.mapa(n)
	if mapa and not Grilla.estaBloqueado(mapa, x, y) and not Mapas.bajoTecho(mapa, x, y) then
		local o = MundoService.objetoEn(n, x, y)
		if o then
			MundoService.quitarObjeto(n, x, y, o.cantidad)
			return true
		end
	end
	return false
end

-- BorrarObjetosLimpieza (mLimpieza.bas:23-45)
local function borrar()
	local l = lista
	lista = {}
	for _, p in l do
		borrarEn(p[1], p[2], p[3])
	end
end

-- PasarSegundo (mMainLoop.bas:343-383), la parte de la limpieza
local function pasarSegundo()
	if tickLimpieza <= 0 then
		return
	end
	tickLimpieza -= 1
	local aviso = AVISOS[tickLimpieza]
	if aviso then
		aTodos(aviso)
	elseif tickLimpieza == 0 then
		borrar()
		aTodos("Servidor> Limpieza del mundo finalizada.")
	end
end

-- Fase 29 (docs/49 §9): el botín que un bot levanta enseguida no cuenta para la limpieza del mundo (si no, veinte
-- bots farmeando la dispararían cada pocos minutos)
function LimpiezaService.olvidar(n: number, x: number, y: number)
	for i = #lista, 1, -1 do
		local p = lista[i]
		if p[1] == n and p[2] == x and p[3] == y then
			table.remove(lista, i)
			return
		end
	end
end

function LimpiezaService.iniciar()
	evConsola = Remotes.evento("Consola")
	MundoService.alCrearObjeto(function(n: number, x: number, y: number)
		anotar(n, x, y)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pasarSegundo()
		end
	end)
end

-- Fase 23: arranca la cuenta de 16 s a pedido (el /LIMPIARMUNDO de los GM, Protocol.bas:23836). false si ya corría.
function LimpiezaService.pedir(): boolean
	if tickLimpieza > 0 then
		return false
	end
	tickLimpieza = TICK_INICIAL
	return true
end

-- Fase 23: limpia ya lo tirado en un mapa, sin cuenta ni aviso. Devuelve cuántos casilleros vació.
function LimpiezaService.limpiarMapa(n: number): number
	local quedan: { { number } } = {}
	local delMapa: { { number } } = {}
	for _, p in lista do
		table.insert(if p[1] == n then delMapa else quedan, p)
	end
	lista = quedan
	local k = 0
	for _, p in delMapa do
		if borrarEn(p[1], p[2], p[3]) then
			k += 1
		end
	end
	return k
end

-- Para las pruebas desde Studio
LimpiezaService._interno = {
	cantidad = function(): number
		return #lista
	end,
	forzar = function()
		tickLimpieza = TICK_INICIAL -- como el /LIMPIAR de los GM (Protocol.bas:23836)
	end,
}

return LimpiezaService
