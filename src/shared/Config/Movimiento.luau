--!strict
--[[
	Parámetros de movimiento (decisión D-02, docs/12-decisiones-pendientes.md).
]]
return {
	-- Duración de un paso: fin del scroll del cliente clásico, 32 px a 0,144 px/ms (docs/10 §3)
	MS_POR_PASO = 222,
	-- Anti-speedhack del servidor: el clásico medía 30 pasos en ≥ 5800 ms (≈ 193 ms/paso).
	-- Acá: un balde de fichas que se rellena a 1 cada 193 ms, con margen de 3 para el jitter de red.
	MS_POR_FICHA = 193,
	FICHAS_MAX = 3,
	-- Giro en el lugar (cuando el paso no sale): como mucho uno cada 300 ms (INT_CHANGE_HEADING, cliente
	-- Declares.bas:123, mPooMap.bas:141-145). El servidor descarta giros más seguidos que 300 - 50 ms
	-- (DF10-05 B, docs/18 §7).
	MS_GIRO = 300,
	MS_GIRO_SERVIDOR = 250,
}
