--!strict
--[[
	Los 20 skills (NUMSKILLS, Declares.bas:503) en el orden de eSkill (Declares.bas:583-607). docs/21 §7.

	clave: el nombre que usan el código y el guardado (combatiente.skills[clave]).
	nombre: SkillsNames (General.bas:498-517), el de los mensajes "Has mejorado tu skill X…".
	titulo / ayuda: los textos de la ventana de skills (frmSkills3, spanish.json "HABILIDADES").
]]

export type Skill = { clave: string, nombre: string, titulo: string, ayuda: string }

local Skills = {}

Skills.Lista = {
	{ clave = "Magia", nombre = "Magia", titulo = "Magia", ayuda = "- Representa la habilidad de un personaje de las areas magicas.\n- Indica la variedad de hechizos que es capaz de dominar el personaje." },
	{ clave = "Robar", nombre = "Robar", titulo = "Robar", ayuda = "- Habilidades de hurto. Nunca por medio de la violencia.\n- Indica la probabilidad de exito del personaje al intentar apoderarse del oro de otros, en caso de ser Ladron, tambien podra apoderarse de items." },
	{ clave = "Tacticas", nombre = "Evasion en combate", titulo = "Evasion en Combate", ayuda = "- Representa la habilidad general para moverse en combate entre golpes enemigos sin morir o tropezar en el intento.\n- Indica la posibilidad de evadir un golpe fisico del personaje." },
	{ clave = "Armas", nombre = "Combate con armas", titulo = "Combate con Armas", ayuda = "- Representa la habilidad del personaje para manejar armas de combate cuerpo a cuerpo.\n- Indica la probabilidad de impactar al oponente con armas cuerpo a cuerpo." },
	{ clave = "Meditar", nombre = "Meditar", titulo = "Meditar", ayuda = "- Representa la capacidad del personaje de concentrarse para abstrarse dentro de su mente, y asi revitalizar su fuerza espiritual.\n- Indica la velocidad a la que el personaje recupera mana (Solo para clases magicas)." },
	{ clave = "Apunalar", nombre = "Apunalar", titulo = "Apunalar", ayuda = "- Representa la destreza para inflingir lesion grave con armas cortas.\n- Indica la posibilidad de apunalar al enemigo en un ataque. El Asesino es la unica clase que no necesita 10 skills para comenzar a entrenar esta habilidad." },
	{ clave = "Ocultarse", nombre = "Ocultarse", titulo = "Ocultarse", ayuda = "- La habilidad propia de un personaje para mimetizarse con el medio y evitar que se perciba su presencia.\n- Indica la facilidad con la que uno puede desaparecer de la vista de los demas y por cuanto tiempo." },
	{ clave = "Supervivencia", nombre = "Supervivencia", titulo = "Supervivencia", ayuda = "- Es el conjunto de habilidades necesarias para sobrevivir fuera de una ciudad en base a lo que la naturaleza ofrece.\n- Permite conocer la salud de las criaturas guiandose exclusivamente por su aspecto, asi como encender fogatas junto a las que descansar." },
	{ clave = "Talar", nombre = "Talar", titulo = "Talar", ayuda = "- Es la habilidad en el uso del hacha para evitar desperdiciar madera y maximizar la efectividad de cada golpe dado.\n- Indica la probabilidad de obtener madera por golpe." },
	{ clave = "Comerciar", nombre = "Comercio", titulo = "Comercio", ayuda = "- Es la habilidad para regatear los precios exigidos en la compra y evitar ser regateado al vender.\n- Indica que tan caro se compra en el comercio con NPCs." },
	{ clave = "Defensa", nombre = "Defensa con escudos", titulo = "Defensa con Escudos", ayuda = "- Es la habilidad de interponer correctamente el escudo ante cada embate enemigo para evitar ser impactado sin perder el equilibrio y poder responder rapidamente con la otra mano.\n- Indica las probabilidades de bloquear un impacto con el escudo." },
	{ clave = "Pesca", nombre = "Pesca", titulo = "Pesca", ayuda = "- Es el conjunto de conocimientos basicos para poder armar un cebo, poner la carnada en el anzuelo y saber donde buscar peces.\n- Indica la probabilidad de tener exito en cada intento de pescar." },
	{ clave = "Mineria", nombre = "Mineria", titulo = "Mineria", ayuda = "- Es el conjunto de conocimientos sobre los distintos minerales, el donde se obtienen, como deben ser extraidos y trabajados.\n- Indica la probabilidad de tener exito en cada intento de minar y la capacidad, o no, de convertir estos minerales en lingotes." },
	{ clave = "Carpinteria", nombre = "Carpinteria", titulo = "Carpinteria", ayuda = "- Es el conjunto de conocimientos para saber serruchar, lijar, encolar y clavar madera con un buen nivel de terminacion.\n- Indica la habilidad en el manejo de estas herramientas, el que tan bueno se es en el oficio de carpintero." },
	-- El título "Mineria" de Herreria es un error del spanish.json original; en la ventana se ve la imagen, que dice "Herrería"
	{ clave = "Herreria", nombre = "Herreria", titulo = "Herreria", ayuda = "- Es el conjunto de conocimientos para saber procesar cada tipo de mineral para fundirlo, forjarlo y crear aleaciones.\n- Indica la habilidad en el manejo de estas tecnicas, el que tan bueno se es en el oficio de herrero." },
	-- Fase 31 (docs/51, D31-10 a D31-14; pedido del autor): para qué sirve y cómo se entrena (Shared.Jugador.Liderazgo).
	-- Cuatro renglones de menos de 513 px en Arial 13: con el título son los cinco que entran en el cuadro de la ventana.
	{ clave = "Liderazgo", nombre = "Liderazgo", titulo = "Liderazgo", ayuda = "- El grupo que lideras admite mas miembros: 6 con 50 puntos, 7 con 75 y 8 con 100.\n- Ese grupo gana 1% mas de experiencia cada 10 puntos y cobra desde mas lejos.\n- Tu clan admite 20 miembros mas uno cada 5 puntos. Fundarlo pide 90 puntos.\n- Se entrena liderando: sube cuando tu grupo mata una criatura hostil." },
	{ clave = "Domar", nombre = "Domar animales", titulo = "Domar Animales", ayuda = "- Es la habilidad en el trato con animales para que estos te sigan y ayuden en combate.\n- Indica la posibilidad de lograr domar a una criatura y que clases de criaturas se puede domar." },
	{ clave = "Proyectiles", nombre = "Combate a distancia", titulo = "Combate a Distancia", ayuda = "- Es el manejo de las armas de largo alcance.\n- Indica la probabilidad de exito para impactar a un enemigo con este tipo de armas." },
	{ clave = "Wrestling", nombre = "Combate sin armas", titulo = "Combate Cuerpo a Cuerpo", ayuda = "- Es la habilidad del personaje para entrar en combate sin arma alguna salvo sus propias manos.\n- Indica la probabilidad de exito para impactar a un enemigo estando desarmado. El Bandido y Ladron tienen habilidades extras asociadas a esta habilidad." },
	{ clave = "Navegacion", nombre = "Navegacion", titulo = "Navegacion", ayuda = "- Es la habilidad para controlar barcos en el mar sin naufragar.\n- Indica que clase de barcos se pueden utilizar." },
} :: { Skill }

Skills.Indice = {} :: { [string]: number }
for i, s in Skills.Lista do
	Skills.Indice[s.clave] = i
end

Skills.Max = 100 -- MAXSKILLPOINTS
Skills.PuntosIniciales = 10 -- AsignedSkills >= 10 para entrenar (Modulo_UsUaRiOs.bas:1567)
Skills.ExigirAsignados = false -- docs/24 DA-03 A: los skills entrenan desde 0 (true = como el original)
-- Fase 26 (docs/46 §8, pedido del autor): cada acción que entrena un skill lo sube un punto, salga bien o mal,
-- hasta el tope del nivel. Con false vuelve el contador del original (50 por acierto y 20 por fallo contra lo que
-- pide cada punto: 4 acciones el primero, unas 500 el último).
Skills.PuntoPorAccion = true
Skills.ExpAcierto = 50 -- EXP_ACIERTO_SKILL (Declares.bas:788-792)
Skills.ExpFallo = 20 -- EXP_FALLO_SKILL
Skills.ExpPorSubir = 50 -- experiencia de personaje por cada punto que sube (:1602)
Skills.MarcaAviso = 7 -- UltimoMensaje del aviso de los 10 puntos (:1568-1570)

-- "* Habilidad inhabilitada para tu clase." (AYUDA_NO_USAR_HABILIDAD, frmSkills3.ValidarSkills)
Skills.AvisoInhabilitada = "* Habilidad inhabilitada para tu clase."
-- Por clase (frmSkills3.ValidarSkills; docs/27 §1.4): la ventana y también el servidor (DC14-05 A)
local Clases = require(script.Parent.Clases)
Skills.Inhabilitadas = {} :: { [string]: { [string]: boolean } }
for nombre, d in Clases.datos do
	Skills.Inhabilitadas[nombre] = d.inhabilitadas
end

-- Skills que se pueden asignar pero todavía no tienen efecto (aviso nuestro). DF12-12 B lo usaba para Apuñalar, que
-- llega en la Fase 14a.
Skills.SinEfecto = {} :: { [string]: string }

-- Skills vacíos (todos en 0), con la clave de cada uno
function Skills.vacios(): { [string]: number }
	local t = {}
	for _, s in Skills.Lista do
		t[s.clave] = 0
	end
	return t
end

return Skills
