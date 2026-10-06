--!strict
--[[
	Teclas configurables (DF11-03 C, DF11-04 A; docs/20 §4). Las acciones del slice y los dos juegos de fábrica
	del cliente original (doc 10 §1.2): "flechas" = LoadDefaults (clsCustomKeys.cls:378-411) y "wasd" =
	BindAlternativeKeys.bin. Por defecto WASD, y las flechas caminan siempre salvo que se asignen a otra acción.

	Las teclas se guardan por nombre (el Name de Enum.KeyCode), salvo Control, Shift y Alt, que valen por
	cualquiera de los dos lados como en el original.
]]

local Teclas = {}

export type Mapa = { [string]: string }

-- En el orden del menú. "diagnostico" es nuestro (Fase 10).
Teclas.Acciones = {
	{ id = "arriba", nombre = "Caminar al norte" },
	{ id = "abajo", nombre = "Caminar al sur" },
	{ id = "izquierda", nombre = "Caminar al oeste" },
	{ id = "derecha", nombre = "Caminar al este" },
	{ id = "atacar", nombre = "Atacar" },
	{ id = "usar", nombre = "Usar objeto" },
	{ id = "agarrar", nombre = "Agarrar objeto" },
	{ id = "tirar", nombre = "Tirar objeto" },
	{ id = "equipar", nombre = "Equipar objeto" },
	{ id = "seguro", nombre = "Seguro" },
	{ id = "meditar", nombre = "Meditar" },
	-- Fase 14a (docs/27 §5 y §6): mKeyHide (O) y mKeySteal (R) del cliente original
	{ id = "ocultar", nombre = "Ocultarse" },
	{ id = "robar", nombre = "Robar" },
	-- Fase 16c (docs/33 §1.3, DM16-11 A): mKeyTamAnimal (D); en WASD la D camina, así que B
	{ id = "domar", nombre = "Domar animales" },
	-- Fase 16a (docs/31 §2.2, DR16-12 A): el macro de trabajo del cliente original (F8)
	{ id = "trabajar", nombre = "Trabajar seguido" },
	-- Fase 21 (docs/40 §8): nuestro (el original no tiene tecla para navegar). La Z está libre en los dos juegos.
	{ id = "navegar", nombre = "Navegar" },
	-- Fase 22 (docs/41 §1): los diez atajos de la barra de PC. Los números estaban libres en los dos juegos.
	{ id = "atajo1", nombre = "Atajo 1" },
	{ id = "atajo2", nombre = "Atajo 2" },
	{ id = "atajo3", nombre = "Atajo 3" },
	{ id = "atajo4", nombre = "Atajo 4" },
	{ id = "atajo5", nombre = "Atajo 5" },
	{ id = "atajo6", nombre = "Atajo 6" },
	{ id = "atajo7", nombre = "Atajo 7" },
	{ id = "atajo8", nombre = "Atajo 8" },
	{ id = "atajo9", nombre = "Atajo 9" },
	{ id = "atajo10", nombre = "Atajo 10" },
	{ id = "opciones", nombre = "Opciones" },
	-- Fase 26 (docs/46 §10): la Guía del juego, también jugando. F1 estaba libre en los dos juegos.
	{ id = "guia", nombre = "Guía del juego" },
	-- Paquete P2 (docs/29 §5): mKeyToggleMusic (M) y mKeyToggleSound (S del original; N, porque S camina en WASD)
	{ id = "musica", nombre = "Música (prender/apagar)" },
	{ id = "sonidos", nombre = "Sonidos (prender/apagar)" },
	{ id = "diagnostico", nombre = "Diagnóstico" },
}

Teclas.Juegos = {
	flechas = {
		arriba = "Up", abajo = "Down", izquierda = "Left", derecha = "Right",
		atacar = "Control", usar = "U", agarrar = "A", tirar = "T", equipar = "E", seguro = "C",
		meditar = "F6", opciones = "F5", diagnostico = "F3", ocultar = "O", robar = "R", musica = "M", sonidos = "N",
		trabajar = "F8", domar = "D", navegar = "Z", guia = "F1",
	} :: Mapa,
	wasd = {
		arriba = "W", abajo = "S", izquierda = "A", derecha = "D",
		atacar = "Control", usar = "U", agarrar = "Q", tirar = "T", equipar = "E", seguro = "C",
		meditar = "F6", opciones = "F5", diagnostico = "F3", ocultar = "O", robar = "R", musica = "M", sonidos = "N",
		trabajar = "F8", domar = "B", navegar = "Z", guia = "F1",
	} :: Mapa,
}
Teclas.PorDefecto = "wasd"
-- Fase 22 (docs/41 §1): los atajos, con la fila de números en los dos juegos
Teclas.Atajos = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero" }
for _, juego in Teclas.Juegos do
	for i, tecla in Teclas.Atajos do
		(juego :: any)[`atajo{i}`] = tecla
	end
end

-- Las flechas caminan siempre, salvo que el jugador las asigne a otra acción (DF11-03 C)
Teclas.FlechasExtra = { Up = "arriba", Down = "abajo", Left = "izquierda", Right = "derecha" }

-- Roblox las usa: menú, consola de desarrollador, pantalla completa. Enter abre el chat (docs/23 DN-06 A).
Teclas.Reservadas = { Escape = true, F9 = true, F11 = true, Return = true, KeypadEnter = true }

-- Nombres que se pueden asignar (lista blanca, también la usa el servidor para validar)
local VALIDAS: { [string]: boolean } = {}
for c = string.byte("A"), string.byte("Z") do
	VALIDAS[string.char(c)] = true
end
for _, n in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" } do
	VALIDAS[n] = true
	VALIDAS["Keypad" .. n] = true
end
for i = 1, 12 do
	VALIDAS["F" .. i] = true
end
for _, n in {
	"Up", "Down", "Left", "Right", "Space", "Backspace", "Tab", "Insert", "Delete", "Home", "End",
	"PageUp", "PageDown", "Control", "Shift", "Alt", "Comma", "Period", "Minus", "Equals", "Semicolon", "Quote",
	"LeftBracket", "RightBracket", "BackSlash", "Slash", "Backquote", "KeypadMultiply", "KeypadPlus", "KeypadMinus",
	"KeypadDivide", "KeypadPeriod", "CapsLock", "Pause",
} do
	VALIDAS[n] = true
end
for n in Teclas.Reservadas do
	VALIDAS[n] = nil
end

local MOSTRAR: { [string]: string } = {
	Up = "Flecha arriba", Down = "Flecha abajo", Left = "Flecha izquierda", Right = "Flecha derecha",
	Space = "Espacio", Return = "Enter", Backspace = "Retroceso", Delete = "Suprimir", Insert = "Insertar",
	Home = "Inicio", End = "Fin", PageUp = "Re Pág", PageDown = "Av Pág", Tab = "Tab", CapsLock = "Bloq Mayús",
	Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
	KeypadMultiply = "NumPad *", KeypadPlus = "NumPad +", KeypadMinus = "NumPad -", KeypadDivide = "NumPad /",
	KeypadPeriod = "NumPad .", KeypadEnter = "NumPad Enter", Comma = ",", Period = ".", Minus = "-", Equals = "=",
	Semicolon = ";", Quote = "'", LeftBracket = "[", RightBracket = "]", BackSlash = "\\", Slash = "/", Backquote = "`",
}

function Teclas.valida(nombre: any): boolean
	return typeof(nombre) == "string" and VALIDAS[nombre] == true
end

-- Nombre para mostrar en el menú
function Teclas.mostrar(nombre: string?): string
	if not nombre then
		return ""
	end
	local m = MOSTRAR[nombre]
	if m then
		return m
	end
	local n = string.match(nombre, "^Keypad(%a+)$")
	if n and MOSTRAR[n] then
		return "NumPad " .. MOSTRAR[n]
	end
	return nombre
end

-- Nombre con el que se guarda una tecla apretada (nil si no se puede asignar)
function Teclas.desdeKeyCode(kc: EnumItem): string?
	local n = kc.Name
	if n == "LeftControl" or n == "RightControl" then
		n = "Control"
	elseif n == "LeftShift" or n == "RightShift" then
		n = "Shift"
	elseif n == "LeftAlt" or n == "RightAlt" then
		n = "Alt"
	end
	return if VALIDAS[n] then n else nil
end

-- Una configuración completa y válida: todas las acciones, teclas de la lista blanca y sin repetir
function Teclas.validar(t: any): boolean
	if typeof(t) ~= "table" then
		return false
	end
	local usadas: { [string]: boolean } = {}
	local n = 0
	for k, v in t do
		n += 1
		if typeof(k) ~= "string" or not Teclas.valida(v) or usadas[v] then
			return false
		end
		usadas[v] = true
	end
	for _, a in Teclas.Acciones do
		if t[a.id] == nil then
			return false
		end
	end
	return n == #Teclas.Acciones
end

-- Una configuración guardada antes de que existieran algunas acciones (Fase 14a: ocultar y robar): les da la
-- tecla de fábrica si está libre, o la primera letra libre. Devuelve una copia; lo que no sea tabla, nil.
function Teclas.completar(t: any): Mapa?
	if typeof(t) ~= "table" then
		return nil
	end
	local c: Mapa = {}
	local usadas: { [string]: boolean } = {}
	for k, v in t do
		if typeof(k) == "string" and typeof(v) == "string" then
			c[k] = v
			usadas[v] = true
		end
	end
	local fabrica = Teclas.Juegos[Teclas.PorDefecto]
	for _, a in Teclas.Acciones do
		if c[a.id] == nil then
			local tecla = fabrica[a.id]
			if usadas[tecla] then
				tecla = nil
				for b = string.byte("A"), string.byte("Z") do
					local l = string.char(b)
					if not usadas[l] then
						tecla = l
						break
					end
				end
			end
			if tecla then
				c[a.id] = tecla
				usadas[tecla] = true
			end
		end
	end
	return c
end

function Teclas.copia(t: Mapa): Mapa
	local c: Mapa = {}
	for k, v in t do
		c[k] = v
	end
	return c
end

return Teclas
