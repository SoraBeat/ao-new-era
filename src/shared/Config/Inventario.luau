--!strict
--[[
	Inventario del slice (docs/17-spec-hud-slice.md §6 y §7; DF9-04 A, DF9-05 B, DF9-06 C, DF9-07 C).
	Los datos de cada objeto (nombre, Grh, tipo, ataque/defensa) están en Shared.Generado.ObjetosInventario.
]]

local Inventario = {}

Inventario.Slots = 35 -- MAX_INVENTORY_SLOTS: se dibujan todos
Inventario.SlotsUsables = 25 -- MAX_NORMAL_INVENTORY_SLOTS: sin mochila ni alforja

-- Contenido del personaje de prueba por clase: { objeto, cantidad, equipado? }. La roja va primero (DF9-05 B, §6.3).
-- Las 12 clases están en Config.Clases (docs/27 §1.5).
local Clases = require(script.Parent.Clases)
Inventario.Preset = {} :: { [string]: { { any } } }
for nombre, d in Clases.datos do
	Inventario.Preset[nombre] = d.prueba.equipo
end

-- Kit rápido de clase (panel de Admin, docs/28 §10): los objetos 5001-5012 ("Kit de <Clase>", Generado) dan el
-- Preset de su clase más esto: Manzana Roja y Botella de Agua (sin hambre ni sed todavía, no hacen nada)
Inventario.KitBase = 5000
Inventario.KitExtra = { { 1, 20 }, { 43, 20 } }

-- Tirar oro (docs/22 §7.2): el cliente manda Tirar con este slot (FLAGORO = MAX_INVENTORY_SLOTS + 1)
Inventario.SlotOro = 36

-- Mochilas (Fase 16b, docs/32 §6.2, DP16-11 B)
Inventario.MsgMochilaVaciar = "Primero vacia los slots de la mochila."
Inventario.MsgMochilaSlot = "La mochila equipada tiene que estar en los primeros 25 slots."
Inventario.MsgMochilaEquipada = "Primero desequipa la mochila."

-- Objetos personales (Fase 21, docs/40 §9, D21-35 A): la Gema de Fundación. No se caen al morir, no se tiran, no se
-- roban ni se venden; si no entran en el inventario quedan anotados en el personaje y se entregan cuando haya lugar
Inventario.MsgPersonal = "Ese objeto es personal: no se puede tirar."
Inventario.MsgPendienteEntregado = "Recibiste %d %s que tenias pendiente."
Inventario.MsgPendienteSinLugar = "No tenias lugar para %s: se te entrega cuando lo haya."

Inventario.MaxObjs = 10000 -- MAX_INVENTORY_OBJS (Declares.bas:693): tope de una pila, en el inventario y en el piso

-- Reposición de los personajes de prueba, antes junto al altar y desde la Fase 13 junto al sacerdote (DF9-05 B,
-- rehecha en DF11-08 C: sin pisar y solo lo gastado o perdido al morir).
-- Los mensajes son nuevos (no están en el original).
-- (La distancia es la del sacerdote al caminar, < 5: Config.Ciudad.SacerdoteCaminar, DF13-06 A)
Inventario.MsgRepuesto = "Tus pociones fueron repuestas."
Inventario.MsgEquipoRepuesto = "Tu equipo fue repuesto."

-- Tirar, agarrar y equipar: límite propio contra clientes truchos (docs/20 §5.2), el IntervaloTirar de AO20
-- menos la gracia de DF7-05. En silencio.
Inventario.IntervaloAccionPiso = 400

-- Cliente (Declares.bas:120-121): U 450 ms, doble click 125 ms; en celular el botón Usar y el doble toque
-- van a 125 ms (DF9-06 C)
Inventario.ClienteU = 450
Inventario.ClienteDobleClick = 125

-- Servidor: tope de usos contra clientes truchos (DF9-07 C): como mucho N usos en cualquier lapso de MS
Inventario.TopeUsos = 8
Inventario.TopeUsosMs = 950

return Inventario
