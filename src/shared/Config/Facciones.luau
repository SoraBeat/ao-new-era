--!strict
--[[
	Facciones — la Armada Real y la Legión Oscura (paquete P8, docs/36-spec-facciones.md).

	Enlistarse (EnlistarArmadaReal y EnlistarCaos, ModFacciones.bas:217-316, :642-745), los 15 rangos y sus recompensas
	(RecompensaArmadaReal :318-488, RecompensaCaos :747-896), irse (HandleLeaveFaction, Protocol.bas:8358-8462) y las
	reglas de los objetos, los guardias, los anillos y los barcos. Los números vienen de Generado/Facciones.luau
	(herramientas/fase17b_ref.py, verificados contra el código y los .dat del original); los textos, del original, sin
	tildes. "Nuestro" marca lo que el original no tiene.

	Un miembro de la Armada es siempre un ciudadano y uno de la Legión siempre un criminal (docs/36 §4): dejar de serlo
	expulsa. Un personaje es de una sola facción en toda su vida.
]]

local Datos = require(script.Parent.Parent.Generado.Facciones)

local Facciones = {}

export type Bando = string -- "armada" | "caos"

Facciones.Armada, Facciones.Caos = "armada", "caos"
Facciones.Bandos = { "armada", "caos" }
Facciones.NivelIngreso = 25
Facciones.MaxIngresos = 5 -- Reenlistadas > 4: no entra más (5 ingresos en total)
Facciones.DistNoble = 4 -- Distancia (Manhattan) al Rey o al Demonio para los tres comandos (Protocol.bas:7006)
Facciones.TipoNoble = 5 -- eNPCType.Noble
-- El Rey (NPC 72, flags.Faccion = 0) y el Demonio (NPC 98)
Facciones.Nobles = { [72] = "armada", [98] = "caos" } :: { [number]: Bando }
Facciones.Estado = { armada = "ciudadano", caos = "criminal" } :: { [string]: string }
-- " <Ejercito Real> <Titulo>" en el click sobre un jugador (GameLogic.bas:1258-1262)
Facciones.Nombre = { armada = "Ejercito Real", caos = "Legion Oscura" } :: { [string]: string }
Facciones.NombreVentana = { armada = "Armada Real", caos = "Legión Oscura" } :: { [string]: string }
Facciones.Enemigos = { armada = "Criminales", caos = "Ciudadanos" } :: { [string]: string }

-- ─── Objetos (docs/36 §5) ────────────────────────────────────────────────────
-- Los de la Armada solo se venden a un NPC llamado "SR" y los de la Legión a un "SC" (Comercio.bas:135-150)
Facciones.Sastre = { armada = "SR", caos = "SC" } :: { [string]: string }
Facciones.Cuerno = { armada = 874, caos = 875 } :: { [string]: number }
Facciones.SegCuerno = 10 -- nuestro (DF17-14 A): el original no tiene espera

-- ─── Combate (docs/36 §6) ────────────────────────────────────────────────────
Facciones.MinutosEntreBajas = 5 -- DF17-21 (elegido por el autor): la misma víctima vuelve a contar a los 5 minutos
Facciones.MaxBajasRecientes = 60 -- cuántas víctimas recientes se recuerdan por personaje
-- Privilegio de ciudad (SistemaCombate.bas:1966-1990): RecompensasX > 11, en su ciudad, aunque sea zona segura
Facciones.RangoPrivilegio = 12
Facciones.MarcaHuye = 36 -- la marca de consolaUnaVez del aviso a la víctima
Facciones.Privilegio = {
	armada = { [58] = true, [59] = true, [60] = true },
	caos = { [151] = true, [156] = true },
} :: { [string]: { [number]: boolean } }

-- ─── Los anillos (docs/36 §7; GameLogic.bas:195-247) ─────────────────────────
Facciones.Restringir = { ARMADA = "armada", CAOS = "caos" } :: { [string]: Bando }
-- Nuestro: el que entra al juego dentro de un anillo sin ser miembro aparece en la ciudad de la entrada
Facciones.EntradaAnillo = { [275] = { 60, 79, 25 }, [200] = { 151, 18, 66 } } :: { [number]: { number } }

-- ─── Barcos (ToggleBoatBody, Modulo_UsUaRiOs.bas:143-294) ────────────────────
-- [ropaje del barco] = el cuerpo de cada facción (Barca, Galera, Galeón)
Facciones.CuerposBarco = {
	[84] = { armada = 560, caos = 561 },
	[85] = { armada = 565, caos = 566 },
	[86] = { armada = 572, caos = 573 },
} :: { [number]: { [string]: number } }

-- ─── Textos ──────────────────────────────────────────────────────────────────
Facciones.Msg = {
	SinNpc = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el.", -- Protocol.bas:6998
	LejosEnlistar = "Debes acercarte mas.", -- :7006
	Lejos = "Estas demasiado lejos.", -- :7054, :7128
	ClanNeutral = "Perteneces a un clan neutro, sal de el si quieres unirte a nuestras fuerzas!!!",
	Exp = "Has sido recompensado con %d puntos de experiencia.", -- GiveExpReward (ModFacciones.bas:209)
	SinFaccion = "No perteneces a ninguna faccion!", -- Protocol.bas:8453
	Invitacion = "No perteneces a nuestra faccion. Si deseas unirte, di /ENLISTAR", -- :8447
	Objeto = "Tu alineacion no puede usar este objeto.", -- FaccionPuedeUsarItem (InvUsuario.bas:1166-1199)
	ZonaSegura = "No hay peligro aqui. Es zona segura.", -- el cuerno (InvUsuario.bas:2117, :2143)
	Llamado = "Escuchas el llamado de un companero que proviene del %s", -- AlertarFaccionarios (modSendData.bas:810-854)
	Huye = "Huye de la ciudad! Estas siendo atacado y no podras defenderte.", -- SistemaCombate.bas:1970
	GuardiaParalisis = "Solo puedes remover la paralisis de los Guardias si perteneces a su faccion.", -- modHechizos.bas:1757
	GuardiaSeguro = "Para poder atacar Guardias Reales debes quitarte el seguro.", -- SistemaCombate.bas:2097
	GuardiaCriminal = "Atacaste un Guardia Real! Eres un criminal.", -- :2100
	-- Nuestros
	Muerto = "Estas muerto!!",
	NoTirar = "No puedes tirar este objeto.",
	Confirmar = "Si cambias de alineacion seras expulsado de tu faccion. Repite el comando para confirmar.",
	GuardiaNewbie = "Los newbies no pueden atacar a los guardias.",
	NoSeEnlista = "Ahora no puedes enlistarte.",
}

-- Por facción
Facciones.MsgBando = {
	armada = {
		Bienvenida = "Bienvenido al ejercito real!!! Aqui tienes tus vestimentas. Cumple bien tu labor exterminando criminales y me encargare de recompensarte.",
		YaMiembro = "Ya perteneces a las tropas reales!!! Ve a combatir criminales.",
		EsOtra = "Maldito insolente!!! Vete de aqui seguidor de las sombras.",
		Criminal = "No se permiten criminales en el ejercito real!!!",
		Neutral = "Solo los ciudadanos pueden unirse al ejercito real.", -- nuestro (DF17-02 A)
		Bajas = "Para unirte a nuestras fuerzas debes matar al menos %d criminales, solo has matado %d.",
		Nivel = "Para unirte a nuestras fuerzas debes ser al menos de nivel 25!!!",
		Asesino = "Has asesinado gente inocente, no aceptamos asesinos en las tropas reales!",
		Reenlistadas = "Has sido expulsado de las fuerzas reales demasiadas veces!",
		NoMiembro = "No perteneces a las tropas reales!!",
		InfoFaltan = "Tu deber es combatir criminales, mata %d criminales mas y te dare una recompensa.",
		InfoAlcanza = "Tu deber es combatir criminales, y ya has matado los suficientes como para merecerte una recompensa.",
		Faltan = "Mata %d criminales mas para recibir la proxima recompensa.",
		FaltaNivel = "Mataste suficientes criminales, pero te faltan %d niveles para poder recibir la proxima recompensa.",
		Recompensa = "Aqui tienes tu recompensa %s!!!",
		Tope = "Eres uno de mis mejores soldados. Mataste %d criminales, sigue asi. Ya no tengo mas recompensa para darte que mi agradecimiento. Felicidades!",
		Retiro = "Te has retirado del ejercito real!!!",
		Expulsado = "Has sido expulsado del ejercito real!!!",
		Despedida = "Seras bienvenido a las fuerzas imperiales si deseas regresar.", -- el Rey al de la Armada que se va
		Fuera = "Sal de aqui maldito criminal!!!", -- el Rey al criminal y al de la Legión
		Intruso = "Esperabas pasar desapercibido, intruso? Los servidores del Demonio no son bienvenidos, Guardias, a el!",
		NoEnlistable = "Tus pecados son grandes, pero aun asi puedes redimirte. El pasado deja huellas, pero aun puedes limpiar tu alma.",
		Enlistable = "Limpia tu reputacion y paga por los delitos cometidos. Un miembro de la Armada Real debe tener un comportamiento ejemplar.",
		Anillo = "Mapa exclusivo para miembros del ejercito real.",
		Cuerno = "Solo miembros del ejercito real pueden usar este cuerno.",
		Venta = "Las armaduras del ejercito real solo pueden ser vendidas a los sastres reales.",
		NoGuardia = "No puedes atacar Guardias Reales siendo del ejercito real.",
		NoRobar = "Los miembros del ejercito real no tienen permitido robarle a ciudadanos.",
	},
	caos = {
		Bienvenida = "Bienvenido al lado oscuro!!! Aqui tienes tus armaduras. Derrama sangre ciudadana y real, y seras recompensado, lo prometo.",
		YaMiembro = "Ya perteneces a la legion oscura!!!",
		EsOtra = "Las sombras reinaran en Argentum. Fuera de aqui insecto real!!!",
		NoCriminal = "Largate de aqui, bufon!!!",
		FueArmada = "No permitire que ningun insecto real ingrese a mis tropas.",
		Bajas = "Para unirte a nuestras fuerzas debes matar al menos %d ciudadanos, solo has matado %d.",
		Nivel = "Para unirte a nuestras fuerzas debes ser al menos nivel 25!!!",
		Reenlistadas = "Has sido expulsado de las fuerzas oscuras demasiadas veces!",
		Traidor = "Has sido expulsado de las fuerzas oscuras y durante tu rebeldia has atacado a mi ejercito. Vete de aqui!",
		NoMiembro = "No perteneces a la legion oscura!!",
		InfoFaltan = "Tu deber es sembrar el caos y la desesperanza, mata %d ciudadanos mas y te dare una recompensa.",
		InfoAlcanza = "Tu deber es sembrar el caos y la desesperanza, y creo que estas en condiciones de merecer una recompensa.",
		Faltan = "Mata %d cuidadanos mas para recibir la proxima recompensa.", -- sic
		FaltaNivel = "Mataste suficientes ciudadanos, pero te faltan %d niveles para poder recibir la proxima recompensa.",
		Recompensa = "Bien hecho %s, aqui tienes tu recompensa!!!",
		Tope = "Eres uno de mis mejores soldados. Mataste %d ciudadanos . Tu unica recompensa sera la sangre derramada. Continua asi!!", -- sic
		Retiro = "Te has retirado de la Legion Oscura!!!",
		Expulsado = "Has sido expulsado de la Legion Oscura!!!",
		Despedida = "Ya volveras arrastrandote.",
		Fuera = "Sal de aqui bufon!!!", -- el Demonio al que no es criminal y al de la Armada
		Intruso = "Lacayo de Tancredo, ve y dile a tu gente que nadie pisara estas tierras si no se arrodilla ante mi.",
		NoEnlistable = "Tu indecision te ha condenado a una vida sin sentido, aun tienes eleccion... Pero ten mucho cuidado, mis hordas nunca descansan.",
		Enlistable = "Siento el miedo por tus venas. Deja de ser escoria y unete a mis filas, sabras que es el mejor camino.",
		Anillo = "Mapa exclusivo para miembros de la legion oscura.",
		Cuerno = "Solo miembros de la legion oscura pueden usar este cuerno.",
		Venta = "Las armaduras de la legion oscura solo pueden ser vendidas a los sastres del demonio.",
		NoGuardia = "No puedes atacar Guardias del Caos siendo de la legion oscura.",
		NoRobar = "No puedes robar a otros miembros de la legion oscura.",
	},
} :: { [string]: { [string]: string } }

-- ─── Rangos ──────────────────────────────────────────────────────────────────
export type Rango = { titulo: string, bajas: number, nivel: number, exp: number, armaduras: { number } }

Facciones.UltimoRango = 14

-- El rango k (0 a 14) de una facción
function Facciones.rango(bando: Bando, k: number): Rango
	local rs = (Datos.rangos :: any)[bando]
	return rs[math.clamp(k, 0, Facciones.UltimoRango) + 1]
end

function Facciones.titulo(bando: Bando, k: number): string
	return Facciones.rango(bando, k).titulo
end

function Facciones.tope(bando: Bando): number
	return (Datos.tope :: any)[bando]
end

-- Lo que cuenta para cada facción: criminales matados (Armada) o ciudadanos matados (Legión)
function Facciones.bajas(bando: Bando, criminales: number, ciudadanos: number): number
	return if bando == "armada" then criminales else ciudadanos
end

-- Las tres armaduras (defensa baja, media y alta) de una clase y una raza (ArmadurasFaccionarias.dat)
function Facciones.armaduras(bando: Bando, clase: string, raza: string): { number }
	local alta = raza == "Humano" or raza == "Elfo" or raza == "Drow"
	local c = (Datos.armaduras :: any)[clase] or (Datos.armaduras :: any).Guerrero
	return c[bando][if alta then "alto" else "bajo"]
end

-- ─── Enlistarse ──────────────────────────────────────────────────────────────
export type Aspirante = {
	estado: string, -- newbie | ciudadano | neutral | criminal
	nivel: number,
	criminales: number,
	ciudadanos: number,
	bando: Bando?, -- la facción actual
	fue: Bando?, -- la que tuvo alguna vez
	ingresos: number,
	traidor: boolean,
	clanNeutral: boolean,
}

-- La clave del motivo por el que no entra (Facciones.MsgBando[bando][clave], o "ClanNeutral" de Facciones.Msg), en el
-- orden del original; nil = entra. motivo_enlistar de fase17b_ref.py.
function Facciones.motivoEnlistar(bando: Bando, p: Aspirante): string?
	local ingreso = Facciones.rango(bando, 0).bajas
	if bando == "armada" then
		if p.bando == "armada" then
			return "YaMiembro"
		elseif p.bando == "caos" then
			return "EsOtra"
		elseif p.estado == "criminal" then
			return "Criminal"
		elseif p.estado ~= "ciudadano" then
			return "Neutral"
		elseif p.criminales < ingreso then
			return "Bajas"
		elseif p.nivel < Facciones.NivelIngreso then
			return "Nivel"
		elseif p.ciudadanos > 0 then
			return "Asesino"
		elseif p.ingresos >= Facciones.MaxIngresos then
			return "Reenlistadas"
		elseif p.clanNeutral then
			return "ClanNeutral"
		end
		return nil
	end
	if p.estado ~= "criminal" then
		return "NoCriminal"
	elseif p.bando == "caos" then
		return "YaMiembro"
	elseif p.bando == "armada" then
		return "EsOtra"
	elseif p.fue == "armada" then
		return "FueArmada"
	elseif p.ciudadanos < ingreso then
		return "Bajas"
	elseif p.nivel < Facciones.NivelIngreso then
		return "Nivel"
	elseif p.clanNeutral then
		return "ClanNeutral"
	elseif p.traidor then
		return "Traidor"
	elseif p.ingresos >= Facciones.MaxIngresos then
		return "Reenlistadas"
	end
	return nil
end

-- /RECOMPENSA: a lo sumo un rango por vez; primero las bajas y después el nivel. Devuelve qué pasa y el número del
-- mensaje: ("faltan", n) | ("nivel", n) | ("tope", bajas) | ("sube", rango nuevo). recompensa de fase17b_ref.py.
function Facciones.recompensa(bando: Bando, rango: number, bajas: number, nivel: number): (string, number)
	if rango >= Facciones.UltimoRango then
		local tope = Facciones.tope(bando)
		if bajas < tope then
			return "faltan", tope - bajas
		end
		return "tope", bajas
	end
	local sig = Facciones.rango(bando, rango + 1)
	if bajas < sig.bajas then
		return "faltan", sig.bajas - bajas
	elseif nivel < sig.nivel then
		return "nivel", sig.nivel - nivel
	end
	return "sube", rango + 1
end

-- Un cambio de alineación fuera del bando expulsa (docs/36 §4, DF17-20 A)
function Facciones.loExpulsa(bando: Bando, estado: string): boolean
	return estado ~= Facciones.Estado[bando]
end

-- El cuerpo del barco de un miembro (nil = el de su alineación)
function Facciones.cuerpoBarco(ropaje: number, bando: Bando?): number?
	local c = Facciones.CuerposBarco[ropaje]
	return if c and bando then c[bando] else nil
end

-- Privilegio de ciudad, solo contra el bando contrario (DF17-12 A, nuestro: en el original no hay neutrales)
function Facciones.atacaEnCiudad(bando: Bando?, rango: number, mapa: number, estadoVictima: string): boolean
	if not bando or rango < Facciones.RangoPrivilegio then
		return false
	end
	local ms = Facciones.Privilegio[bando]
	return ms ~= nil and ms[mapa] == true and estadoVictima == (if bando == "armada" then "criminal" else "ciudadano")
end

-- GetDireccion (Modulo_UsUaRiOs.bas:2742-2776): dx, dy = el que llama menos el que escucha
function Facciones.direccion(dx: number, dy: number): string
	local ns = if dy > 0 then "Sur" elseif dy < 0 then "Nor" else ""
	local eo = if dx > 0 then "Este" elseif dx < 0 then "Oeste" else ""
	if ns == "" then
		return eo
	elseif eo == "" then
		return if dy > 0 then "Sur" else "Norte"
	end
	return ns .. eo
end

-- La misma víctima vuelve a contar a los MinutosEntreBajas (DF17-21). ultima: os.time() de la última vez, o nil.
function Facciones.cuentaBaja(ultima: number?, ahora: number): boolean
	return ultima == nil or ahora - ultima >= Facciones.MinutosEntreBajas * 60
end

return Facciones
