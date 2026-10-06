--!strict
--[[
	Cuenta, creación de personajes y modo prueba (docs/21 §2-§5 y §9-§10).
]]

local Cuenta = {}

Cuenta.MaxPersonajes = 10 -- MAX_CHARACTERS (Cuentas.bas:811-815, DF12-01 A)

-- Dados (Server.ini.produccion MinDados / MaxDados, DF12-06 A): RandomNumber(Min, Max) por atributo
Cuenta.DadoMin = 16
Cuenta.DadoMax = 18

Cuenta.Razas = { "Humano", "Elfo", "Drow", "Gnomo", "Enano" } -- eRaza 1..5 (los nombres de ListaRazas)
Cuenta.NombreRaza = { Humano = "Humano", Elfo = "Elfo", Drow = "Elfo Oscuro", Gnomo = "Gnomo", Enano = "Enano" } -- el combo del formulario
Cuenta.Generos = { "Hombre", "Mujer" }
-- Las 12 (DF12-03 A las mostraba y habilitaba dos; la Fase 14 habilita todas, DC14-02 A). Lo de cada clase: Config.Clases
local Clases = require(script.Parent.Clases)
Cuenta.Clases = Clases.Orden
Cuenta.ClasesHabilitadas = {} :: { [string]: boolean }
for _, c in Clases.Orden do
	Cuenta.ClasesHabilitadas[c] = true
end
Cuenta.NombreClase = { Clerigo = "Clérigo", Ladron = "Ladrón", Paladin = "Paladín" } :: { [string]: string }

-- Cabezas seleccionables (Declares.bas:2332-2371): [raza][genero] = { primera, última }
Cuenta.Cabezas = {
	Humano = { Hombre = { 1, 40 }, Mujer = { 70, 89 } },
	Elfo = { Hombre = { 101, 122 }, Mujer = { 170, 188 } },
	Drow = { Hombre = { 201, 221 }, Mujer = { 270, 288 } },
	Enano = { Hombre = { 301, 319 }, Mujer = { 370, 384 } },
	Gnomo = { Hombre = { 401, 416 }, Mujer = { 470, 484 } },
} :: { [string]: { [string]: { number } } }

function Cuenta.cabezaValida(raza: string, genero: string, cabeza: number): boolean
	local r = Cuenta.Cabezas[raza]
	local g = r and r[genero]
	return g ~= nil and cabeza >= g[1] and cabeza <= g[2] and cabeza == math.floor(cabeza)
end

-- Ropa newbie por raza (AddItemsToNewUser, TCP.bas:591-604): su NumRopaje es el cuerpo inicial (DarCuerpo)
Cuenta.RopaNewbie = { Humano = 463, Elfo = 464, Drow = 465, Enano = 466, Gnomo = 466 } :: { [string]: number }
-- DF12-11 A (transitorio hasta la Fase 13): lo que se recibe una vez, equipado, al dejar de ser newbie
Cuenta.RopaComun = { Humano = 31, Elfo = 32, Drow = 35, Enano = 240, Gnomo = 240 } :: { [string]: number }
Cuenta.DagaComun = 15
Cuenta.DagaNewbie = 460

-- Inventario inicial (AddItemsToNewUser, TCP.bas:566-681; con comida y agua desde la Fase 16a, DR16-05 A): las pociones de
-- Clases.pociones y después el equipo, equipado (docs/27 §1.3, DC14-03 A).
-- docs/24 DA-06 A: equipo newbie del obj.dat que el original no da, equipado desde el principio. La armadura de cuero
-- reemplaza la ropa newbie (1046 para las razas altas, 1047 para enanos y gnomos). Mago, Bardo y Druida no la pueden
-- usar: llevan la Túnica (Newbie).
Cuenta.ArmaduraNewbie = { Humano = 1046, Elfo = 1046, Drow = 1046, Enano = 1047, Gnomo = 1047 } :: { [string]: number }
Cuenta.TunicaNewbie = { Humano = 1044, Elfo = 1044, Drow = 1044, Enano = 1045, Gnomo = 1045 } :: { [string]: number }
Cuenta.CascoNewbie = 1051 -- Casco Simple (Newbie)
-- docs/24 DA-12 A: una sola vez, al dejar de ser newbie
Cuenta.RecompensaNewbie = 20000
Cuenta.MsgRecompensaNewbie = "¡Dejaste de ser newbie! Recibiste 20000 monedas de oro."
Cuenta.EscudoNewbie = 1048 -- Escudo (Newbie)

-- DC14-16 A: el Cazador, al dejar de ser newbie, recibe un Arco Simple y 150 Flechas en lugar de la Daga
Cuenta.ArcoComun = 478
Cuenta.FlechasComunes = { 480, 150 }

-- Fase 30 (docs/50 §1, pedido del autor): la Flecha de Rama, la flecha que no se gasta de las clases sin magia
-- (Guerrero, Cazador, Ladrón, Trabajador y Pirata), para que puedan pegar de lejos sin comprar flechas. Pega menos
-- que la común (0-1 contra 1-3). Es personal: no se tira, no se vende ni se pasa, y no se cae al morir. Todo personaje
-- sin magia tiene una: se la dan al entrar al juego si no la tiene (los nuevos y los que ya existían). La primera
-- vez, el principiante que no tiene arco recibe además un Arco (Newbie); y al dejar de ser principiante, los que no
-- son Cazadores (que ya lo recibían) reciben un Arco Simple con lo demás del nivel 13.
Cuenta.FlechaRama = 5200
Cuenta.ArcoNewbie = 859
Cuenta.MsgFlechaRama = "Recibiste una Flecha de Rama: no se gasta nunca. Equipala junto con un arco para pegar de lejos."
Cuenta.MsgFlechaRamaBaul = "La Flecha de Rama no se guarda en el baul de una casa."

-- Fase 16a (docs/31): comida y bebida del personaje nuevo (DR16-05 A, TCP.bas:656-664) y la herramienta del
-- Trabajador (DR16-16 A): una newbie al azar al crear y, al pasar a 13, la común equivalente en lugar de la Daga
Cuenta.ComidaInicial = { { 467, 100 }, { 468, 100 } }
-- Fase 16b (DP16-12 A): las cinco del original (TCP.bas:627-629): hacha, piquete, caña, serrucho y martillo
Cuenta.HerramientasTrabajador = { 561, 562, 563, 564, 565 }
Cuenta.HerramientaComun = { [561] = 127, [562] = 187, [563] = 138, [564] = 198, [565] = 389 } :: { [number]: number }

-- SetAttributesToNewUser (TCP.bas:483-564): el maná al crear es Clases.manaInicial (el Mago, 3 × Inteligencia)

-- Dónde aparece un personaje nuevo (DF13-05 A; antes DF12-10, junto al altar del 39): en el hogar de Ullathorpe
-- (Dat/Ciudades.Dat). También los de prueba y los guardados en un mapa que no está en el port.
Cuenta.Inicio = { mapa = 1, x = 58, y = 45 }
Cuenta.HogarPorDefecto = "Ullathorpe" -- DF13-05 A; se cambia con un gobernador (DW17-04 A)

-- "Personaje de prueba" (DF12-09 A) y, con él, /ADMIN: solo los administradores (el dueño del juego y la lista de
-- server/Admin/Admins.luau). En Studio lo ven todos. Hasta el 2026-10-02 lo veía cualquiera (PruebaParaTodos).
Cuenta.PrefijoPrueba = "[Prueba] "

-- Nombres (docs/21 §3.2)
Cuenta.LargoNombre = 15
Cuenta.MsgNombreInvalido = "Nombre invalido."
Cuenta.MsgNombreEnUso = "Ya existe el personaje."
Cuenta.MsgSinDados = "Debe tirar los dados antes de poder crear un personaje."
Cuenta.MsgCabezaInvalida = "Cabeza invalida, elija una cabeza seleccionable."
Cuenta.MsgCuentaLlena = "No puedes crear mas de 10 personajes."
Cuenta.MsgNombreLargo = "El nombre del personaje debe tener menos de 30 letras."
Cuenta.MsgEspaciosFinal = "Nombre invalido, se han removido los espacios al final del nombre"
Cuenta.MsgNoSeleccionado = "No has seleccionado un personaje."
Cuenta.MsgConfirmarBorrar = "Estas seguro que quieres borrar el personaje de tu cuenta? Esta accion no puede revertise"
Cuenta.MsgTituloBorrar = "ALERTA - BORRAR PERSONAJE"
-- Nuestros
Cuenta.MsgEscribirNombre = "Escribi el nombre del personaje para confirmar."
Cuenta.MsgNombreNoCoincide = "El nombre no coincide."
Cuenta.MsgErrorGuardado = "No se pudo guardar. Proba de nuevo en un momento."
Cuenta.MsgOtroLugar = "Entraste desde otro lugar."
Cuenta.MsgNoCargo = "No se pudo cargar tu cuenta. Proba de nuevo en un momento."
Cuenta.MsgEspera = "Espera un momento."
-- DN-08 A (docs/23): un nombre de antes que no pasa el filtro de Roblox
Cuenta.MsgRenombrar = "El nombre de este personaje no esta permitido. Elegi uno nuevo."
Cuenta.MsgTituloRenombrar = "NOMBRE NO PERMITIDO"
Cuenta.MsgEscribirNuevoNombre = "Escribi el nuevo nombre."

-- Límites contra spam (nuestros, docs/21 §3.2): segundos entre pedidos
Cuenta.IntervaloDados = 0.3
Cuenta.IntervaloCrear = 2
Cuenta.IntervaloBorrar = 2

-- Guardado (docs/21 §9)
Cuenta.VersionPerfil = 1
Cuenta.SegundosAlSalir = 10 -- IntervaloCerrarConexion: en mapa inseguro el personaje queda 10 s al salir

-- Normaliza un nombre (§3.2): recorta los bordes, junta los espacios dobles; 1..15 letras ASCII o espacios, con al
-- menos una letra. Devuelve (nombre, clave en minúsculas) o nil. Lo usan el cliente (aviso) y el servidor (regla).
function Cuenta.normalizarNombre(n: any): (string?, string?)
	if typeof(n) ~= "string" or #n > 64 then
		return nil, nil -- (el tope antes de partirlo: un texto enorme mandado a propósito costaba medio segundo)
	end
	local partes = {}
	for p in string.gmatch(n, "[^ ]+") do
		table.insert(partes, p)
	end
	local s = table.concat(partes, " ")
	if #s < 1 or #s > Cuenta.LargoNombre then
		return nil, nil
	end
	if not string.match(s, "^[A-Za-z ]+$") or not string.match(s, "%a") then
		return nil, nil
	end
	return s, string.lower(s)
end

return Cuenta
