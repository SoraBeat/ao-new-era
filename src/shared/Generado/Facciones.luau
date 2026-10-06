--!strict
-- GENERADO por herramientas/fase17b_ref.py exportar (ModFacciones.bas, Balance.dat y ArmadurasFaccionarias.dat)
-- — no editar a mano. P8 (docs/36 §3): rangos[bando][k + 1] = el rango k: bajas (criminales o ciudadanos matados
-- en total, las del original a un tercio, DF17-03 B), nivel, exp (×10, DF17-05 A) y cuántas armaduras de defensa
-- baja, media y alta. armaduras[clase][bando].alto / .bajo: los tres objetos (baja, media, alta).

local M = {}

M.divisorBajas = 3
M.expMulti = 7

M.rangos = {
	armada = {
		{ titulo = "Aprendiz", bajas = 10, nivel = 25, exp = 35000, armaduras = { 10, 2, 1 } },
		{ titulo = "Escudero", bajas = 23, nivel = 25, exp = 52500, armaduras = { 7, 4, 3 } },
		{ titulo = "Soldado", bajas = 43, nivel = 25, exp = 70000, armaduras = { 5, 6, 4 } },
		{ titulo = "Sargento", bajas = 70, nivel = 25, exp = 140000, armaduras = { 4, 8, 5 } },
		{ titulo = "Teniente", bajas = 107, nivel = 25, exp = 175000, armaduras = { 3, 10, 7 } },
		{ titulo = "Comandante", bajas = 153, nivel = 25, exp = 210000, armaduras = { 3, 6, 8 } },
		{ titulo = "Capitan", bajas = 213, nivel = 27, exp = 280000, armaduras = { 2, 5, 9 } },
		{ titulo = "Senescal", bajas = 290, nivel = 25, exp = 350000, armaduras = { 2, 4, 11 } },
		{ titulo = "Mariscal", bajas = 387, nivel = 25, exp = 420000, armaduras = { 2, 4, 12 } },
		{ titulo = "Condestable", bajas = 667, nivel = 30, exp = 490000, armaduras = { 2, 3, 14 } },
		{ titulo = "Ejecutor Imperial", bajas = 833, nivel = 31, exp = 560000, armaduras = { 2, 3, 15 } },
		{ titulo = "Protector del Reino", bajas = 1000, nivel = 33, exp = 700000, armaduras = { 2, 3, 16 } },
		{ titulo = "Avatar de la Justicia", bajas = 1167, nivel = 35, exp = 1050000, armaduras = { 1, 3, 18 } },
		{ titulo = "Guardian del Bien", bajas = 1333, nivel = 36, exp = 1540000, armaduras = { 1, 3, 19 } },
		{ titulo = "Campeon de la Luz", bajas = 1667, nivel = 37, exp = 2380000, armaduras = { 1, 3, 20 } },
	},
	caos = {
		{ titulo = "Acolito", bajas = 23, nivel = 25, exp = 35000, armaduras = { 10, 2, 1 } },
		{ titulo = "Alma Corrupta", bajas = 53, nivel = 25, exp = 52500, armaduras = { 7, 4, 3 } },
		{ titulo = "Paria", bajas = 100, nivel = 25, exp = 70000, armaduras = { 5, 6, 4 } },
		{ titulo = "Condenado", bajas = 163, nivel = 25, exp = 140000, armaduras = { 4, 8, 5 } },
		{ titulo = "Esbirro", bajas = 247, nivel = 25, exp = 175000, armaduras = { 3, 10, 7 } },
		{ titulo = "Sanguinario", bajas = 367, nivel = 25, exp = 210000, armaduras = { 3, 6, 8 } },
		{ titulo = "Corruptor", bajas = 500, nivel = 27, exp = 280000, armaduras = { 2, 5, 9 } },
		{ titulo = "Heraldo Impio", bajas = 670, nivel = 25, exp = 350000, armaduras = { 2, 4, 11 } },
		{ titulo = "Caballero de la Oscuridad", bajas = 900, nivel = 25, exp = 420000, armaduras = { 2, 4, 12 } },
		{ titulo = "Senor del Miedo", bajas = 1533, nivel = 30, exp = 490000, armaduras = { 2, 3, 14 } },
		{ titulo = "Ejecutor Infernal", bajas = 1933, nivel = 31, exp = 560000, armaduras = { 2, 3, 15 } },
		{ titulo = "Protector del Averno", bajas = 2330, nivel = 33, exp = 700000, armaduras = { 2, 3, 16 } },
		{ titulo = "Avatar de la Destruccion", bajas = 2700, nivel = 35, exp = 1050000, armaduras = { 1, 3, 18 } },
		{ titulo = "Guardian del Mal", bajas = 3100, nivel = 36, exp = 1540000, armaduras = { 1, 3, 19 } },
		{ titulo = "Campeon de la Oscuridad", bajas = 3833, nivel = 37, exp = 2380000, armaduras = { 1, 3, 20 } },
	},
}

M.tope = { armada = 3333, caos = 7667 }

M.armaduras = {
	Mago = { armada = { alto = { 675, 517, 679 }, bajo = { 676, 549, 682 } }, caos = { alto = { 677, 518, 634 }, bajo = { 678, 558, 686 } } },
	Clerigo = { armada = { alto = { 675, 372, 680 }, bajo = { 676, 1039, 1040 } }, caos = { alto = { 677, 523, 684 }, bajo = { 678, 1041, 1042 } } },
	Guerrero = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Asesino = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Ladron = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Bardo = { armada = { alto = { 675, 372, 680 }, bajo = { 676, 1039, 1040 } }, caos = { alto = { 677, 523, 684 }, bajo = { 678, 1041, 1042 } } },
	Druida = { armada = { alto = { 675, 372, 680 }, bajo = { 676, 1039, 1040 } }, caos = { alto = { 677, 523, 684 }, bajo = { 678, 1041, 1042 } } },
	Bandido = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Paladin = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Cazador = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Trabajador = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
	Pirata = { armada = { alto = { 675, 521, 629 }, bajo = { 676, 492, 681 } }, caos = { alto = { 677, 369, 683 }, bajo = { 678, 379, 685 } } },
}

return M
