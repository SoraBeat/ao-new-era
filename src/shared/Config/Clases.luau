--!strict
--[[
	Las 12 clases (docs/27 §1, Fase 14a): todo lo que cambia de una clase a otra, en un solo lugar. Las demás
	configuraciones (Combate.mod, Progresion, Cuenta, Skills, Magia, Inventario) leen de acá.

	Fuentes (herramientas/fase14_ref.py clases):
	  - mod y modVida: Balance.dat (FileIO.bas:812-858)
	  - golpe { hasta el 35, desde el 36 }, manaPorInt y energia: CheckUserLevel (Modulo_UsUaRiOs.bas:774-835,
	    Declares.bas:632-640). El maná por nivel se redondea (AumentoMANA es Integer).
	  - manaInicial / manaInicialPorInt: SetAttributesToNewUser (TCP.bas:523-538); el Mago, 3 × Inteligencia
	  - iniciales: TCP.bas:540-552; el Druida, con Invocar Mascota (46) desde la Fase 16c (DM16-09 A, docs/33 §4)
	  - inhabilitadas: frmSkills3.ValidarSkills (cliente, frmSkills3.frm:1613-1651); el servidor también las valida
	    (DC14-05 A)
	  - kit: DC14-03 A (docs/27 §1.3); prueba: DC14-14 A (docs/27 §1.5)
]]

export type Clase = {
	mod: { [string]: number },
	modVida: number,
	golpe: { number },
	manaPorInt: number,
	energia: number,
	manaInicial: number,
	manaInicialPorInt: number?,
	iniciales: { number },
	inhabilitadas: { [string]: boolean },
	magica: boolean,
	kit: { arma: number, municion: { number }?, ropa: string, casco: boolean, escudo: boolean },
	prueba: {
		vida: number,
		energia: number,
		mana: number,
		golpe: number,
		skills: { [string]: number },
		equipo: { { any } },
	},
}

local Clases = {}

-- eClass 1..12 (Declares.bas:175-190): el orden del combo del formulario
Clases.Orden = { "Mago", "Clerigo", "Guerrero", "Asesino", "Ladron", "Bardo", "Druida", "Bandido", "Paladin", "Cazador", "Trabajador", "Pirata" }

local SIN_MAGIA = { Magia = true, Meditar = true }
local POC_MAGICA = { { 857, 400 }, { 856, 400 } } -- docs/24 DA-06 A: el doble del original
local POC_FISICA = { { 857, 400 }, { 855, 200 }, { 858, 100 } }
local POC_PRUEBA_MAGICA = { { 38, 1000 }, { 37, 1000 }, { 166, 100 } }
local POC_PRUEBA_FISICA = { { 38, 1000 }, { 166, 100 } }

local function juntar(a: { any }, b: { any }): { any }
	local t = table.clone(a)
	for _, x in b do
		table.insert(t, x)
	end
	return t
end

Clases.datos = {
	Mago = {
		mod = { Evasion = 0.4, AtaqueArmas = 0.5, AtaqueProyectiles = 0.5, AtaqueWrestling = 0.3, DanoArmas = 0.5, DanoProyectiles = 0.5, DanoWrestling = 0.4, Escudo = 0.6 },
		modVida = 7.5, golpe = { 1, 1 }, manaPorInt = 2.8, energia = 14,
		manaInicial = 0, manaInicialPorInt = 3, iniciales = { 2 }, magica = true,
		inhabilitadas = { Defensa = true, Proyectiles = true },
		kit = { arma = 862, ropa = "tunica", casco = false, escudo = false }, -- Bastón de Mago (Newbie)
		prueba = {
			vida = 187, energia = 376, mana = 1254, golpe = 25,
			skills = { Armas = 63, Tacticas = 63, Magia = 63, Meditar = 63 },
			-- Bastón Nudoso, Túnica Roja, Sombrero de Mago
			equipo = juntar(POC_PRUEBA_MAGICA, { { 659, 1, true }, { 239, 1, true }, { 662, 1, true } }),
		},
	},
	Clerigo = {
		mod = { Evasion = 0.8, AtaqueArmas = 0.85, AtaqueProyectiles = 0.7, AtaqueWrestling = 0.4, DanoArmas = 0.8, DanoProyectiles = 0.7, DanoWrestling = 0.4, Escudo = 0.85 },
		modVida = 8.5, golpe = { 2, 2 }, manaPorInt = 2, energia = 15,
		manaInicial = 50, iniciales = { 2 }, magica = true, inhabilitadas = {},
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 211, energia = 400, mana = 914, golpe = 49,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Magia = 63, Meditar = 63 },
			-- Mazo del Juicio, Armadura de Campeón, Casco de Hierro Completo, Escudo de Hierro
			equipo = juntar(POC_PRUEBA_MAGICA, { { 990, 1, true }, { 903, 1, true }, { 131, 1, true }, { 128, 1, true } }),
		},
	},
	Guerrero = {
		mod = { Evasion = 1, AtaqueArmas = 1, AtaqueProyectiles = 0.8, AtaqueWrestling = 0.6, DanoArmas = 1.1, DanoProyectiles = 0.9, DanoWrestling = 0.4, Escudo = 1 },
		modVida = 10, golpe = { 3, 2 }, manaPorInt = 0, energia = 15,
		manaInicial = 0, iniciales = {}, magica = false, inhabilitadas = SIN_MAGIA,
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 247, energia = 400, mana = 0, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63 },
			-- Hacha Larga de Guerra, Placas Completa, Casco de Hierro Completo, Escudo de Hierro
			equipo = juntar(POC_PRUEBA_FISICA, { { 126, 1, true }, { 195, 1, true }, { 131, 1, true }, { 128, 1, true } }),
		},
	},
	Asesino = {
		mod = { Evasion = 1.1, AtaqueArmas = 0.9, AtaqueProyectiles = 0.75, AtaqueWrestling = 0.4, DanoArmas = 0.9, DanoProyectiles = 0.8, DanoWrestling = 0.4, Escudo = 0.8 },
		modVida = 8.5, golpe = { 3, 1 }, manaPorInt = 1, energia = 15,
		manaInicial = 50, iniciales = { 2 }, magica = true, inhabilitadas = {},
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 211, energia = 400, mana = 482, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Magia = 63, Meditar = 63, Apunalar = 63, Ocultarse = 63 },
			-- Daga +3, Cota de Mallas, Casco de Hierro Completo, Escudo de Tortuga (hasta la Fase 32 no podía usar el de Hierro)
			equipo = juntar(POC_PRUEBA_MAGICA, { { 366, 1, true }, { 359, 1, true }, { 131, 1, true }, { 404, 1, true } }),
		},
	},
	Ladron = {
		mod = { Evasion = 1.1, AtaqueArmas = 0.8, AtaqueProyectiles = 0.85, AtaqueWrestling = 0.8, DanoArmas = 0.75, DanoProyectiles = 0.85, DanoWrestling = 1.05, Escudo = 0.7 },
		modVida = 10, golpe = { 2, 2 }, manaPorInt = 0, energia = 18,
		manaInicial = 0, iniciales = {}, magica = false, inhabilitadas = SIN_MAGIA,
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = false },
		prueba = {
			vida = 247, energia = 472, mana = 0, golpe = 49,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Robar = 63, Ocultarse = 63, Wrestling = 63, Apunalar = 63 },
			-- Daga +2, Armadura de Cazador, Guantes de Hurto
			equipo = juntar(POC_PRUEBA_FISICA, { { 365, 1, true }, { 360, 1, true }, { 873, 1, true } }),
		},
	},
	Bardo = {
		mod = { Evasion = 1.075, AtaqueArmas = 0.7, AtaqueProyectiles = 0.7, AtaqueWrestling = 0.4, DanoArmas = 0.75, DanoProyectiles = 0.7, DanoWrestling = 0.4, Escudo = 0.8 },
		modVida = 8.5, golpe = { 2, 2 }, manaPorInt = 2, energia = 15,
		manaInicial = 50, iniciales = { 2 }, magica = true, inhabilitadas = {},
		kit = { arma = 460, ropa = "tunica", casco = true, escudo = true },
		prueba = {
			vida = 211, energia = 400, mana = 914, golpe = 49,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Magia = 63, Meditar = 63, Apunalar = 63 },
			-- Daga +2, Túnica Azul, Laúd Élfico
			equipo = juntar(POC_PRUEBA_MAGICA, { { 365, 1, true }, { 238, 1, true }, { 1049, 1, true } }),
		},
	},
	Druida = {
		mod = { Evasion = 0.75, AtaqueArmas = 0.65, AtaqueProyectiles = 0.75, AtaqueWrestling = 0.4, DanoArmas = 0.7, DanoProyectiles = 0.75, DanoWrestling = 0.4, Escudo = 0.75 },
		modVida = 8.5, golpe = { 2, 2 }, manaPorInt = 2, energia = 15,
		manaInicial = 50, iniciales = { 2, 46 }, magica = true,
		inhabilitadas = { Defensa = true, Proyectiles = true },
		kit = { arma = 460, ropa = "tunica", casco = false, escudo = false },
		prueba = {
			vida = 211, energia = 400, mana = 914, golpe = 49,
			skills = { Armas = 63, Tacticas = 63, Magia = 63, Meditar = 63 },
			-- Daga +2, Túnica Azul, Flauta Élfica
			equipo = juntar(POC_PRUEBA_MAGICA, { { 365, 1, true }, { 238, 1, true }, { 1050, 1, true } }),
		},
	},
	Bandido = {
		mod = { Evasion = 0.7, AtaqueArmas = 0.85, AtaqueProyectiles = 0.8, AtaqueWrestling = 0.95, DanoArmas = 0.85, DanoProyectiles = 0.7, DanoWrestling = 1.05, Escudo = 2 },
		modVida = 9.5, golpe = { 3, 1 }, manaPorInt = 2 / 3, energia = 18,
		manaInicial = 50, iniciales = { 2 }, magica = true, inhabilitadas = {},
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 235, energia = 472, mana = 338, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Magia = 63, Meditar = 63, Wrestling = 63, Ocultarse = 63 },
			-- Espada Vikinga, Cota de Mallas, Casco de Hierro Completo, Escudo de Hierro, Guantes de Hurto
			equipo = juntar(POC_PRUEBA_MAGICA, { { 123, 1, true }, { 359, 1, true }, { 131, 1, true }, { 128, 1, true }, { 873, 1, true } }),
		},
	},
	Paladin = {
		mod = { Evasion = 0.9, AtaqueArmas = 0.95, AtaqueProyectiles = 0.75, AtaqueWrestling = 0.4, DanoArmas = 0.925, DanoProyectiles = 0.8, DanoWrestling = 0.4, Escudo = 1 },
		modVida = 9.5, golpe = { 3, 1 }, manaPorInt = 1, energia = 15,
		manaInicial = 50, iniciales = { 2 }, magica = true, inhabilitadas = {},
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 235, energia = 400, mana = 482, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Magia = 63, Meditar = 63 },
			-- Espada Larga, Cota de Mallas, Casco de Hierro Completo, Escudo de Hierro
			equipo = juntar(POC_PRUEBA_MAGICA, { { 2, 1, true }, { 359, 1, true }, { 131, 1, true }, { 128, 1, true } }),
		},
	},
	Cazador = {
		mod = { Evasion = 0.9, AtaqueArmas = 0.8, AtaqueProyectiles = 1, AtaqueWrestling = 0.5, DanoArmas = 0.9, DanoProyectiles = 1.1, DanoWrestling = 0.4, Escudo = 0.8 },
		modVida = 9.5, golpe = { 3, 2 }, manaPorInt = 0, energia = 15,
		manaInicial = 0, iniciales = {}, magica = false, inhabilitadas = SIN_MAGIA,
		-- Arco (Newbie) + 300 Flechas (Newbie) como munición (el doble del original, DA-06)
		kit = { arma = 859, municion = { 860, 300 }, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 235, energia = 400, mana = 0, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63, Proyectiles = 63, Ocultarse = 63 },
			-- Arco Compuesto, 500 Flechas, Armadura de Cazador, Casco de Hierro Completo
			equipo = juntar(POC_PRUEBA_FISICA, { { 479, 1, true }, { 480, 500, true }, { 360, 1, true }, { 131, 1, true } }),
		},
	},
	Trabajador = {
		mod = { Evasion = 0.8, AtaqueArmas = 0.8, AtaqueProyectiles = 0.7, AtaqueWrestling = 0.5, DanoArmas = 0.8, DanoProyectiles = 0.7, DanoWrestling = 0.4, Escudo = 0.7 },
		modVida = 9.5, golpe = { 2, 2 }, manaPorInt = 0, energia = 40,
		manaInicial = 0, iniciales = {}, magica = false, inhabilitadas = SIN_MAGIA,
		-- En el original, una herramienta al azar (561-565): desde la Fase 16a, una de 561-563 (Config.Cuenta, DR16-16 A)
		kit = { arma = 460, ropa = "cuero", casco = true, escudo = true },
		prueba = {
			vida = 235, energia = 999, mana = 0, golpe = 49,
			skills = { Armas = 63, Tacticas = 63, Defensa = 63 },
			-- Espada Corta, Cota de Mallas, Casco de Hierro Completo, Escudo de Tortuga
			equipo = juntar(POC_PRUEBA_FISICA, { { 164, 1, true }, { 359, 1, true }, { 131, 1, true }, { 404, 1, true } }),
		},
	},
	Pirata = {
		mod = { Evasion = 1.25, AtaqueArmas = 0.9, AtaqueProyectiles = 0.9, AtaqueWrestling = 0.5, DanoArmas = 0.95, DanoProyectiles = 0.8, DanoWrestling = 0.4, Escudo = 0.6 },
		modVida = 9.5, golpe = { 3, 3 }, manaPorInt = 0, energia = 15,
		manaInicial = 0, iniciales = {}, magica = false,
		-- Fase 32 (docs/52 §2, D32-06): el Pirata ya puede entrenar Defensa con escudos (en el original la tenía
		-- inhabilitada, frmSkills3.ValidarSkills, aunque usaba el Escudo de Tortuga). El Mago y el Druida siguen sin ella.
		inhabilitadas = SIN_MAGIA,
		kit = { arma = 460, ropa = "cuero", casco = false, escudo = false },
		prueba = {
			vida = 235, energia = 400, mana = 0, golpe = 73,
			skills = { Armas = 63, Tacticas = 63, Proyectiles = 63 },
			-- 200 Cuchillas, Cota de Mallas
			equipo = juntar(POC_PRUEBA_FISICA, { { 1009, 200, true }, { 359, 1, true } }),
		},
	},
} :: { [string]: Clase }

-- ¿Es una clase sin magia? (Guerrero, Cazador, Ladrón, Trabajador y Pirata: las de la Flecha de Rama, docs/50 §1)
function Clases.sinMagia(clase: string): boolean
	local d = Clases.datos[clase]
	return d ~= nil and not d.magica
end

-- Pociones del kit (docs/24 DA-06 A): azules a las clases con maná (docs/21 §4.2), amarillas y verdes al resto
function Clases.pociones(clase: string): { { number } }
	local d = Clases.datos[clase]
	return if d and d.magica then POC_MAGICA else POC_FISICA
end

-- Maná al crear (SetAttributesToNewUser)
function Clases.manaInicial(clase: string, inteligencia: number): number
	local d = Clases.datos[clase]
	if not d then
		return 0
	end
	return if d.manaInicialPorInt then d.manaInicialPorInt * inteligencia else d.manaInicial
end

return Clases
