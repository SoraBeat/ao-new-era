--!strict
--[[
	Clanes (Fase 15b, docs/28 §3; investigación en docs/datos/fase15-investigacion/clanes-retos.md §1).

	Constantes, alineaciones, textos del original y el nombre del clan (DS15-24 A: letras con tildes y ñ, y espacios,
	de 3 a 20; la clave única no distingue mayúsculas, tildes ni ñ). Verificado contra herramientas/fase15_ref.py
	(nombresClan).
]]

local Clanes = {}

-- DS15-13 A: fundar como el original (modGuilds.bas:705-706), gratis
-- Fase 21 (docs/40 §9, D21-31 a D21-36): nivel 30 (era 25) y una Gema de Fundación (el objeto 613), que se gasta al
-- fundar. Los personajes de prueba, que son de nivel 25, fundan con 25 pero también con gema (la da el panel de Admin).
Clanes.NivelFundar = 30
Clanes.NivelFundarPrueba = 25
Clanes.LiderazgoFundar = 90
-- (Fase 31, docs/51, D31-14: el Liderazgo del líder también da el tope de miembros del clan; la cuenta está en
-- Shared.Jugador.Liderazgo.topeClan: 20 más uno cada 5 puntos.)
Clanes.Gema = 613

-- Por qué no puede fundar: "nivel", "gema" o nil si puede (motivo_fundar de herramientas/fase21_ref.py)
function Clanes.motivoFundar(nivel: number, liderazgo: number, gemas: number, prueba: boolean?): string?
	if nivel < (if prueba then Clanes.NivelFundarPrueba else Clanes.NivelFundar) or liderazgo < Clanes.LiderazgoFundar then
		return "nivel"
	end
	if gemas < 1 then
		return "gema"
	end
	return nil
end
Clanes.MaxAspirantes = 10 -- MAXASPIRANTES (modGuilds.bas:50)
Clanes.MaxAntifaccion = 5 -- MAXANTIFACCION (modGuilds.bas:54)
Clanes.LineasCodex = 8 -- CANTIDADMAXIMACODEX (modGuilds.bas:46)
Clanes.LargoCodex = 256 -- CODEXLENGTH (clsClan.cls:65-67)
Clanes.LargoDesc = 256 -- DESCLENGTH
Clanes.LargoNoticias = 1024 -- NEWSLENGTH
Clanes.LargoSolicitud = 400 -- nuestro (el original no limita)
Clanes.LargoMotivo = 200 -- nuestro
Clanes.LargoChat = 160 -- como el chat normal
Clanes.NombreMin, Clanes.NombreMax = 3, 20
-- 15b-2 (DS15-15 A): la elección dura 24 h (cierre perezoso); si el líder no entra hace 30 días, cualquier miembro la
-- puede abrir (nuestro)
Clanes.DuracionEleccion = 24 * 3600
Clanes.AusenciaLider = 30 * 24 * 3600
Clanes.LargoPropuesta = 200

-- DS15-12 A: Legal (ciudadanos), Criminal (criminales) y Neutral (cualquiera que no sea newbie). texto:
-- Alineacion2String (modGuilds.bas:881-941); permite: los estados de docs/23.
-- P8 (docs/36 §8, DF17-18 A; m_EstadoPermiteEntrar, modGuilds.bas:849-876): vuelven Real y Del Mal, que desde el nivel
-- 25 piden la facción (faccion), y el Neutral ya no admite al que tiene una (sinFaccion).
Clanes.Alineaciones = {
	real = { texto = "Real", permite = { ciudadano = true }, faccion = "armada" },
	legal = { texto = "Legal", permite = { ciudadano = true } },
	neutral = { texto = "Neutral", permite = { ciudadano = true, neutral = true, criminal = true }, sinFaccion = true },
	criminal = { texto = "Criminal", permite = { criminal = true } },
	delmal = { texto = "Del Mal", permite = { criminal = true }, faccion = "caos" },
} :: { [string]: { texto: string, permite: { [string]: boolean }, faccion: string?, sinFaccion: boolean? } }
Clanes.OrdenAlineaciones = { "real", "legal", "neutral", "criminal", "delmal" }
Clanes.NivelFaccion = 25 -- desde este nivel, el clan Real pide la Armada y el Del Mal la Legión

-- Si un personaje (estado de docs/23, nivel y facción "armada" | "caos" | nil) puede estar en un clan de esa alineación
-- (clan_permite de herramientas/fase17b_ref.py). Los newbies no entran a ninguno.
function Clanes.permite(alineacion: string, estado: string, nivel: number, faccion: string?): boolean
	local a = Clanes.Alineaciones[alineacion]
	if not a or a.permite[estado] ~= true then
		return false
	end
	if a.faccion then
		return nivel < Clanes.NivelFaccion or faccion == a.faccion
	end
	if a.sinFaccion then
		return faccion == nil
	end
	return true
end

-- BajarGrado (modGuilds.bas:299-318): Real → Legal, Del Mal → Criminal, y las demás → Neutral
function Clanes.bajar(alineacion: string): string
	return if alineacion == "real" then "legal" elseif alineacion == "delmal" then "criminal" else "neutral"
end

-- La ventana de elegir alineación del clan (frmEligeAlineacion, spanish.json FRM_ELIJEALINEACION_*), sin las facciones
Clanes.TextosAlineacion = {
	-- P8 (docs/36 §8): los cinco del original (cli/spanish.json FRM_ELIJEALINEACION_*), con sus erratas; el Neutral
	-- suma a los neutrales, que el original no tiene
	real = { titulo = "Alineacion Real", texto = "En los clanes de alineacion real solo se admiten miembros del ejerctio Real de Banderbill. Lucharan contra todos los criminales de estas tierras siempre junto al rey y bajo las ordenes del consejo de Banderbil. Los personajes que se alejen del ejercito no podran pertenecer a un clan real" },
	legal = { titulo = "Alineacion Legal", texto = "En los clanes de orientacion legal podran coexistir miembros de las fuerzas reales de Banderbill con ciudadanos. Cualquier personaje que se vuelva criminial sera expulsado automaticamente del clan" },
	neutral = { titulo = "Alineacion Neutral", texto = "Los clanes neutrales son aquellos que no tienen ninguna alineacion manifesta. Solo se aceptaran personajes criminales, neutrales o ciudadanos que no pertenezcan a ninguna faccion." },
	criminal = { titulo = "Alineacion Criminal", texto = "Los clanes criminales son aquellos que no se guian por las leyes. Coexisten criminales normales y miembros de la legion oscura. Cualquier personaje que se vuelva ciudadano sera expulsado del clan de forma automatica." },
	delmal = { titulo = "Alineacion Caos", texto = "Estos clanes estaran formados unicamente por miembros de la legion oscura y bajo las ordenes del demonio y sus eruditos. Los clanes que le juren lealtad no podran tener miembros que se alejen a sus ejercitos" },
}

-- ─── Nombre del clan (DS15-24 A) ─────────────────────────────────────────────
local MAYUS: { [number]: number } = { [193] = 225, [201] = 233, [205] = 237, [211] = 243, [218] = 250, [220] = 252, [209] = 241 }
local SIN_TILDE: { [number]: number } = { [225] = 97, [233] = 101, [237] = 105, [243] = 111, [250] = 117, [252] = 117, [241] = 110 }

local function minuscula(c: number): number
	if c >= 65 and c <= 90 then
		return c + 32
	end
	return MAYUS[c] or c
end

-- Devuelve (nombre, clave) si el nombre es válido: letras (con tildes y ñ) y espacios, de 3 a 20 caracteres, sin
-- espacios en los bordes ni dobles. La clave: minúsculas y sin tildes ni ñ. (El filtro de Roblox lo pasa el servidor.)
function Clanes.validarNombre(n: any): (string?, string?)
	if typeof(n) ~= "string" or not utf8.len(n) then
		return nil, nil
	end
	local largo = utf8.len(n) :: number
	if largo < Clanes.NombreMin or largo > Clanes.NombreMax then
		return nil, nil
	end
	if string.sub(n, 1, 1) == " " or string.sub(n, -1) == " " or string.find(n, "  ", 1, true) then
		return nil, nil
	end
	local clave = {}
	for _, c in utf8.codes(n) do
		local m = minuscula(c)
		if not ((m >= 97 and m <= 122) or m == 32 or SIN_TILDE[m]) then
			return nil, nil
		end
		table.insert(clave, utf8.char(SIN_TILDE[m] or m))
	end
	return n, table.concat(clave)
end

-- ─── Textos del original ─────────────────────────────────────────────────────
Clanes.Msg = {
	-- Fundar (modGuilds.bas:699-759, Protocol.bas:8628-8711)
	YaFundo = "Ya has fundado un clan, no puedes fundar otro!",
	YaEnClan = "Ya perteneces a un clan, no puedes fundar otro",
	NivelFundar = "Para fundar un clan debes ser nivel 30 y tener 90 skills en liderazgo.",
	NivelFundarPrueba = "Para fundar un clan debes ser nivel 25 y tener 90 skills en liderazgo.",
	-- Fase 21 (docs/40 §9; nuestros)
	FaltaGema = "Para fundar un clan necesitas una Gema de Fundacion. La vende Sir Gerard, el mercader de Ullathorpe.",
	GemaSeGasta = "Al fundar el clan se gasta tu Gema de Fundacion.",
	FundacionPendiente = "No se pudo confirmar si el clan se fundo. Tu gema queda guardada: volve a intentar en un momento.",
	FundacionTerminada = "Tu clan ya quedo fundado.",
	YaFiguras = "Ya figuras en ese clan. Si lo fundaste vos, fundalo de nuevo con el mismo nombre para recuperarlo.",
	FundandoYa = "Ya estas fundando un clan: espera un momento.",
	GemaDevuelta = "El clan no se fundo: la Gema de Fundacion volvio a tu inventario.",
	GemaGuardada = "El clan no se fundo y no tenias lugar: la Gema de Fundacion se te entrega cuando lo haya.",
	FundarLegal = "Para fundar un clan de ciudadanos no debes ser criminal.",
	FundarCriminal = "Para fundar un clan de criminales no debes ser ciudadano.",
	-- P8 (docs/36 §8; modGuilds.bas:716, :740, :756)
	FundarReal = "Para fundar un clan real debes ser miembro del ejercito real.",
	FundarDelMal = "Para fundar un clan del mal debes pertenecer a la legion oscura.",
	FundarNeutral = "Para fundar un clan neutro no debes pertenecer a ninguna faccion.",
	SaleSinFaccion = "Tu clan paso a ser Neutral y no admite miembros de una faccion: has dejado el clan.", -- nuestro
	AlineacionInvalida = "Alineacion invalida.",
	NombreInvalido = "Nombre de clan invalido.",
	NombreRepetido = "Ya existe un clan con ese nombre.",
	-- Solicitudes (modGuilds.bas:2162-2326)
	YaEnClanSolicitar = "Ya perteneces a un clan, debes salir del mismo antes de solicitar ingresar a otro.",
	NewbieClan = "Los newbies no tienen derecho a entrar a un clan.",
	NoExiste = "Ese clan no existe, avise a un administrador.",
	NoAceptaSolicitudes = "Ese clan no está aceptando solicitudes por ahora.", -- Fase 29
	NoAceptaPropuestas = "Ese clan no está aceptando propuestas por ahora.", -- Fase 29
	DemasiadosAspirantes = "El clan tiene demasiados aspirantes. Contactate con un miembro para que procese las solicitudes.",
	-- Fase 31 (docs/51, D31-14; nuestro): al aceptar con el clan en su tope. %d: cuántos son, el Liderazgo del líder y
	-- el tope que le da (Shared.Jugador.Liderazgo.topeClan)
	ClanLleno = "El clan ya tiene %d miembros y con tu Liderazgo (%d) admite hasta %d. Subi tu Liderazgo para aceptar a mas.",
	-- Salir y expulsar (Protocol.bas:6172-6198, :5694-5754)
	DejasClan = "Dejas el clan.",
	LiderNoSale = "Tu no puedes salir de este clan.",
	NoExpulsar = "No puedes expulsar ese personaje del clan.",
	-- Varios
	NoEsMiembro = "No eres miembro de ningun clan.",
	NoEsLider = "No eres el lider de tu clan.",
	NoPertenece = "No pertences a ningUn clan.",
	EstadoNoPermite = "Tu estado no te permite entrar al clan.",
	Expulsado = "Has sido expulsado del clan. El clan ha sumado un punto de antifaccion!",
	-- Nuestros (docs/28 §3.3)
	PruebaNoClan = "Los personajes de prueba no pueden usar clanes.",
	-- Playtest 3 (docs/30, DP3-01 A): los clanes de prueba no se mezclan con los reales
	PruebaMezcla = "Los personajes de prueba solo pueden estar en clanes de prueba (y los reales, en clanes reales).",
	PruebaRelacion = "Los clanes de prueba solo pueden relacionarse con otros clanes de prueba.",
	ErrorGuardado = "No se pudo guardar el clan. Proba de nuevo en un momento.",
	LiderNoBorra = "Este personaje es lider de un clan: primero cerra el clan.",
	YaNoPerteneces = "Ya no perteneces al clan %s.",
	ClanCerrado = "El clan %s ha cerrado sus puertas.",
}

return Clanes
