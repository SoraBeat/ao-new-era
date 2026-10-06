--!strict
--[[
	Presets de personaje del vertical slice (docs/11-mvp-vertical-slice.md §3.3 y §3.6).
	Apariencia = índices de Personajes.ind (cuerpo), Cabezas.ind, Cascos.ind, Armas.dat y Escudos.dat.
]]

export type Apariencia = { cuerpo: number, cabeza: number, casco: number, arma: number, escudo: number }

local Personajes = {}

Personajes.clases = {
	Guerrero = {
		apariencia = { cuerpo = 45, cabeza = 1, casco = 6, arma = 3, escudo = 4 } :: Apariencia,
		-- Equipo (objetos.json): Hacha Larga de Guerra, Placas Completa, Casco de Hierro Completo, Escudo de Hierro
		equipo = { arma = 126, armadura = 195, casco = 131, escudo = 128 },
	},
	Clerigo = {
		apariencia = { cuerpo = 317, cabeza = 5, casco = 6, arma = 32, escudo = 4 } :: Apariencia,
		-- Mazo del Juicio, Armadura de Campeón, Casco de Hierro Completo, Escudo de Hierro
		equipo = { arma = 990, armadura = 903, casco = 131, escudo = 128 },
	},
}

-- Cuerpo desnudo (DarCuerpoDesnudo, General.bas:45-110) por género y raza (Fase 12; en la Fase 11 era siempre 21)
Personajes.cuerpoDesnudo = 21
Personajes.desnudo = {
	Hombre = { Humano = 21, Drow = 32, Elfo = 210, Gnomo = 222, Enano = 53 },
	Mujer = { Humano = 39, Drow = 40, Elfo = 259, Gnomo = 260, Enano = 60 },
} :: { [string]: { [string]: number } }

function Personajes.cuerpoDesnudoDe(raza: string?, genero: string?): number
	local g = Personajes.desnudo[genero or "Hombre"]
	return g and g[raza or "Humano"] or Personajes.cuerpoDesnudo
end

-- Muerto (iCuerpoMuerto / iCabezaMuerto, Declares.bas:560-562): sin casco, arma ni escudo
Personajes.muerto = { cuerpo = 8, cabeza = 500, casco = 0, arma = 0, escudo = 0 } :: Apariencia

-- (Dónde aparece cada uno: Config.Cuenta.Inicio y el mapa guardado, Fase 13)

return Personajes
