--!strict
--[[
	Pretorianos — el clan del Fuerte Pretoriano como criaturas comunes (Fase 17a, docs/35 §3.3).

	SpawnClan (clsClanPretoriano.cls:176-284): 9 miembros alrededor de una posición: el Rey en el centro, 2 sanadores a
	los costados, 3 espadachines abajo, un tirador, un mago y un ladrón arriba. Cada uno sale al azar entre los NPC de
	su rol en Pretorianos.dat (la versión "alta" y la "baja"). Cuando muere el último, el clan reaparece entero en la
	otra posición (MuerePretoriano, :2918-2966). Server.ini [CLAN-PRETORIANO]: Mapa=163.
]]

local Pretorianos = {}

Pretorianos.Mapa = 163
-- InitializePretoriansVars (:314-329): se alterna entre las dos
Pretorianos.Posiciones = { { 35, 25 }, { 67, 25 } }

-- Pretorianos.dat: los NPC de cada rol (Alto/Bajo)
Pretorianos.Roles = {
	rey = { 900, 901 },
	sanador = { 902, 903, 904, 905 },
	mago = { 906, 907, 908, 909 },
	tirador = { 910, 911, 912, 913 },
	espadachin = { 914, 915, 916, 917, 918, 919, 920, 921 },
	ladron = { 922, 923 },
} :: { [string]: { number } }

-- SpawnClan: el rol y el corrimiento de cada miembro desde el centro, en orden (nPos se va moviendo)
Pretorianos.Formacion = {
	{ "rey", 0, 0 },
	{ "sanador", 3, 0 },
	{ "sanador", -3, 0 },
	{ "espadachin", -3, 3 },
	{ "espadachin", 0, 3 },
	{ "espadachin", 3, 3 },
	{ "tirador", 2, -3 },
	{ "mago", -2, -3 },
	{ "ladron", -2, -3 },
} :: { { any } }

function Pretorianos.todos(): { number }
	local t = {}
	for _, ids in Pretorianos.Roles do
		for _, id in ids do
			table.insert(t, id)
		end
	end
	return t
end

return Pretorianos
