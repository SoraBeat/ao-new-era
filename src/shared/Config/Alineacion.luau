--!strict
--[[
	Alineación (docs/23 §2-§3, DN-01 a DN-04): newbie, ciudadano, neutral y criminal.

	Ciudadanos y criminales son dos bandos; el neutral pelea contra todos; los newbies quedan fuera del PvP.

	Fase 26 (docs/46 §3, pedido del autor): la alineación cambia solo por elección. Pelear, robar o atacar a un
	guardia ya no vuelve criminal a nadie, y el seguro no se mira para pelear contra otro jugador (queda para las
	criaturas con dueño y los Guardias Reales). El camino se elige una vez, sin "más tarde"; después, se jura ante el
	Rey (ciudadano) o el Demonio (criminal), o se usa /ABANDONAR (neutral). Volver a ciudadano cuesta una multa por
	cada ciudadano matado. Las funciones son puras (las usan el servidor y las pruebas; herramientas/fase26_ref.py).
]]

local Alineacion = {}

export type Estado = string -- "newbie" | "ciudadano" | "neutral" | "criminal"

Alineacion.LimiteNewbie = 12 -- Declares.bas:235

-- Sin elegir (o un perfil de antes de la Fase 13): neutral, y fuera del PvP hasta que elija (Fase 26)
Alineacion.PorDefecto = "neutral" -- docs/24 DA-10 A (docs/23 DN-02 A decía ciudadano)
Alineacion.Elegibles = { ciudadano = true, neutral = true, criminal = true } :: { [string]: boolean }

function Alineacion.estado(elv: number, alineacion: string?): Estado
	if elv <= Alineacion.LimiteNewbie then
		return "newbie"
	end
	return if alineacion and Alineacion.Elegibles[alineacion] then alineacion else Alineacion.PorDefecto
end

-- ─── Colores del nombre (DN-01 A) ────────────────────────────────────────────
Alineacion.Colores = {
	newbie = Color3.fromRGB(0, 200, 0),
	ciudadano = Color3.fromRGB(0, 128, 255), -- [Ci] de colores.dat
	neutral = Color3.fromRGB(170, 170, 170),
	criminal = Color3.fromRGB(255, 0, 0), -- [Cr]
} :: { [string]: Color3 }
Alineacion.ColorMuerto = Color3.fromRGB(220, 220, 255) -- RenderName (TileEngine.bas:1692)
Alineacion.ColorNpc = Color3.fromRGB(0, 128, 255) -- los NPCs no hostiles: el de ciudadano

-- ─── Quién ataca a quién (DN-03) ─────────────────────────────────────────────
Alineacion.MsgNoAtacarNewbie = "No puedes atacar a un newbie."
Alineacion.MsgNewbieNoAtaca = "Los newbies no pueden atacar a otros jugadores."
Alineacion.MsgNoAtacarCiudadanos = "No puedes atacar a otros ciudadanos."
Alineacion.MsgNoAtacarCriminales = "No puedes atacar a otros criminales."
Alineacion.MsgTeVolvisteCriminal = "Te has convertido en criminal." -- (queda para el panel de administración)
-- Fase 26 (docs/46 §3.3): el que todavía no eligió su camino no pelea con otros jugadores
Alineacion.MsgSinElegir = "Primero tenes que elegir tu camino."
Alineacion.MsgNoEligio = "Ese jugador todavia no eligio su camino."
-- El seguro ya no hace falta para pelear: queda para no pegarle sin querer a un compañero de grupo o de clan (D26-06)
Alineacion.MsgSeguroCompanero = "Para atacar a un compañero de tu grupo o de tu clan debes quitarte el seguro."
-- La ventana obligatoria (docs/46 §3.3): se abre en un momento de calma (zona segura, o SegCalma sin pegar ni recibir
-- daño) y, como mucho, a los SegTopeElegir de estar pendiente. Mientras elige no puede hacer nada y nada lo daña.
Alineacion.SegCalma = 5
Alineacion.SegTopeElegir = 30
Alineacion.SegReabrir = 8 -- cada cuánto se le vuelve a pedir al cliente que la muestre, por si no la tiene
Alineacion.MsgEligiendo = "Primero tenes que elegir tu camino."
Alineacion.MsgNivel13 = "Llegaste al nivel 13! Cuando dejes de pelear vas a elegir tu camino: ciudadano, neutral o criminal."
Alineacion.MsgNoRobarCiudadanos = "No puedes robarle a otros ciudadanos."
Alineacion.MsgNoRobarCriminales = "No puedes robarle a otros criminales."

-- Motivo por el que `a` no puede atacar a `v` por su alineación (nil = puede). No mira el seguro.
function Alineacion.motivoNoAtaca(a: Estado, v: Estado): string?
	if a == "newbie" then
		return Alineacion.MsgNewbieNoAtaca
	end
	if v == "newbie" then
		return Alineacion.MsgNoAtacarNewbie
	end
	if a == "ciudadano" and v == "ciudadano" then
		return Alineacion.MsgNoAtacarCiudadanos
	end
	if a == "criminal" and v == "criminal" then
		return Alineacion.MsgNoAtacarCriminales
	end
	return nil
end

-- Fase 26 (docs/46 §3.2): robar sigue la misma tabla que pelear (el que roba no es newbie: lo mira el que llama)
function Alineacion.motivoNoRoba(a: Estado, v: Estado): string?
	if a == "ciudadano" and v == "ciudadano" then
		return Alineacion.MsgNoRobarCiudadanos
	end
	if a == "criminal" and v == "criminal" then
		return Alineacion.MsgNoRobarCriminales
	end
	return nil
end

-- Hechizos de ayuda sobre otro jugador (DN-03)
Alineacion.MsgNewbieAyuda = "Los newbies solo pueden ayudar a otros newbies."
Alineacion.MsgNoAyudarCriminal = "No puedes ayudar a un criminal."
Alineacion.MsgNoAyudarCiudadano = "No puedes ayudar a un ciudadano."

function Alineacion.motivoNoAyuda(a: Estado, v: Estado): string?
	if a == "newbie" and v ~= "newbie" then
		return Alineacion.MsgNewbieAyuda
	end
	if a == "ciudadano" and v == "criminal" then
		return Alineacion.MsgNoAyudarCriminal
	end
	if a == "criminal" and v == "ciudadano" then
		return Alineacion.MsgNoAyudarCiudadano
	end
	return nil
end

-- El seguro arranca puesto salvo para los criminales (TCP.bas:1449-1486)
function Alineacion.seguroInicial(e: Estado): boolean
	return e ~= "criminal"
end

-- ─── Cambiar de bando (DN-04) ────────────────────────────────────────────────
Alineacion.MultaPorCiudadano = 10000
Alineacion.SegEntreCambios = 3600 -- una vez por hora (os.time)
Alineacion.SegFueraDePelea = 60
Alineacion.MapaCambio = 1 -- Ullathorpe

Alineacion.MsgSoloUllathorpe = "Solo puedes hacerlo en Ullathorpe."
Alineacion.MsgEnPelea = "No puedes hacerlo en medio de una pelea."
Alineacion.MsgNewbie = "Primero debes dejar de ser newbie."
Alineacion.MsgMuerto = "No puedes realizar esta accion estando muerto."
Alineacion.MsgYaNeutral = "Ya eres neutral."
Alineacion.MsgYaCiudadano = "Ya eres ciudadano."
Alineacion.MsgAhoraNeutral = "Ahora eres neutral."
Alineacion.MsgAhoraCiudadano = "Ahora eres ciudadano."
Alineacion.MsgAhoraCriminal = "Ahora eres criminal."
Alineacion.MsgYaCriminal = "Ya eres criminal."
-- Fase 26 (docs/46 §3.4): ciudadano y criminal se juran ante el Rey y el Demonio (/ENLISTAR con ellos seleccionados)
Alineacion.MsgIrAlRey = "Para ser ciudadano presentate ante el Rey, en Banderbill, y decile /ENLISTAR."
Alineacion.MsgIrAlDemonio = "Para ser criminal presentate ante el Demonio, en Arkhein, y decile /ENLISTAR."
-- Los guardias de cada ciudad atacan al del otro bando: el criminal no llega vivo al Rey, ni el ciudadano al Demonio
Alineacion.MsgGuardiasRey = "Ojo: los guardias de Banderbill atacan a los criminales. Pasa primero a neutral con /ABANDONAR, en Ullathorpe."
Alineacion.MsgGuardiasDemonio = "Ojo: los guardias de Arkhein atacan a los ciudadanos. Pasa primero a neutral con /ABANDONAR, en Ullathorpe."
Alineacion.MsgJuraRey = "Has jurado lealtad al Rey."
Alineacion.MsgJuraDemonio = "Has jurado lealtad al Demonio."

function Alineacion.multa(ciudadanosMatados: number): number
	return Alineacion.MultaPorCiudadano * math.max(0, ciudadanosMatados)
end

function Alineacion.msgEspera(segundos: number): string
	local m = math.max(1, math.ceil(segundos / 60))
	return `Debes esperar {m} {if m == 1 then "minuto" else "minutos"} para volver a cambiar.`
end

function Alineacion.msgFaltaOro(n: number): string
	return `Necesitas {n} monedas de oro para pagar la multa.`
end

function Alineacion.msgPagaste(n: number): string
	return `Has pagado {n} monedas de oro de multa. Ahora eres ciudadano.`
end

-- ─── La ventana (DN-02 A) ────────────────────────────────────────────────────
Alineacion.Opciones = {
	{
		clave = "ciudadano",
		titulo = "Ciudadano",
		texto = "Respetás la ley. Peleás contra criminales y neutrales, nunca contra otros ciudadanos.",
	},
	{
		clave = "neutral",
		titulo = "Neutral",
		texto = "No seguís a nadie: peleás contra todos, y todos pueden pelear contra vos.",
	},
	{
		clave = "criminal",
		titulo = "Criminal",
		texto = "Vivís fuera de la ley. Peleás contra ciudadanos y neutrales, nunca contra otros criminales.",
	},
}
Alineacion.TituloVentana = "Elegí tu camino"
Alineacion.MsgConfirmar = "¿Seguro? Para cambiar después hay que jurar ante el Rey (Banderbill) o el Demonio (Arkhein), o usar /ABANDONAR en Ullathorpe."
Alineacion.MsgObligatorio = "Tenés que elegir para seguir jugando."

return Alineacion
