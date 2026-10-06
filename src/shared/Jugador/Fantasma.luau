--!strict
--[[
	Fantasma — el vivo que camina hacia el fantasma de otro jugador lo corre (Fase 34, docs/54 §2; pedido del autor:
	"al pasar arriba de un fantasma lo tiene que mover a la posición de donde viene el jugador").

	Es lo del original (MoveUserChar con CasperIndex, Modulo_UsUaRiOs.bas): el muerto no bloquea al vivo; cambian de
	lugar. El fantasma queda en la casilla que deja el vivo, mirando para el lado contrario, como si hubiera dado ese
	paso. Ya pasaba con las criaturas (NpcService.moverNpc, DF8-07 A); faltaba entre jugadores.

	La regla está acá para que el servidor (MovimientoService.paso) y el cliente (la predicción del paso, en
	Controlador) decidan lo mismo.
]]

local Fantasma = {}

-- El rumbo contrario (1 norte, 2 este, 3 sur, 4 oeste)
Fantasma.INVERSO = { [1] = 3, [2] = 4, [3] = 1, [4] = 2 } :: { [number]: number }

export type Quien = { muerto: boolean?, espectador: boolean?, npc: boolean? }

-- ¿`otro`, que está parado en la casilla a la que va `yo`, se corre para dejarlo pasar?
-- Solo el fantasma de un jugador, y solo ante un vivo: un muerto no corre a otro muerto, y una criatura no se corre.
function Fantasma.seCorre(yo: Quien, otro: Quien): boolean
	if yo.muerto or yo.espectador then
		return false
	end
	return otro.muerto == true and not otro.npc and not otro.espectador
end

return Fantasma
