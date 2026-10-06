--!strict
--[[
	Dueno — constantes y textos de las criaturas con dueño y del estado atacable (Fase 19, docs/38 §4 y §5).
	Las cuentas están en Shared/Npcs/Dueno; la referencia, en herramientas/fase19_ref.py.
]]

local Dueno = {}

Dueno.OwnedSeg = 18 -- IntervaloOwnedNpc (Server.ini:115): desde el último golpe del dueño
Dueno.AtacableSeg = 60 -- IntervaloAtacable: desde el último golpe del atacable
-- El nombre del atacable (cli/Red/Protocol.bas:2196-2199: el color que el original usa en la consola)
Dueno.ColorAtacable = Color3.fromRGB(236, 89, 57)

Dueno.Msg = {
	-- PuedeAtacarNPC (SistemaCombate.bas:2210-2437)
	armada = "Los miembros del Ejercito Real no pueden atacar criaturas pertenecientes a otros miembros del Ejercito Real",
	seguro = "Para atacar criaturas pertenecientes a ciudadanos debes quitarte el seguro.",
	seguroArmada = "Para atacar criaturas ya pertenecientes a ciudadanos debes quitarte el seguro.", -- :2364
	atacable = "Has atacado a la criatura de un ciudadano, ahora eres atacable por el.",
	caos = "Los miembros de la Legion Oscura no pueden atacar criaturas de otros legionarios. ",
	castigo = "No puedes atacar otra criatura con dueno hasta que haya terminado tu castigo.",
	armadaPara = "Los miembros del Ejercito Real no pueden paralizar criaturas ya paralizadas pertenecientes a otros miembros del Ejercito Real",
	seguroPara = "Para paralizar criaturas ya paralizadas pertenecientes a ciudadanos debes quitarte el seguro.",
	atacablePara = "Has paralizado la criatura de un ciudadano, ahora eres atacable por el.",
	caosPara = "Los miembros de la legion oscura no pueden paralizar criaturas ya paralizadas por otros legionarios.",
	-- CanSupportNpc (modHechizos.bas:2685-2800)
	ayudaSeguro = "Para ayudar a criaturas que luchan contra ciudadanos debes sacarte el seguro.",
	ayudaFaccion = "No puedes ayudar npcs que estan luchando contra un miembro de tu faccion.",
	atacableAyuda = "Has ayudado a la criatura con la que lucha un ciudadano, ahora eres atacable por el.", -- nuestro
	-- Nuestros (DC19-09 A): con un newbie de por medio no se roba
	newbie = "Esa criatura es de otro: espera a que la deje.",
	deNewbie = "Esa criatura es de un newbie: espera a que la deje.",
	-- /COMPARTIRNPC (Protocol.bas:7255-7365)
	comparteCriminal = "No puedes compartir npcs con criminales!!",
	comparteFaccion = "Solo puedes compartir npcs con miembros de tu misma faccion!!",
	comparte = "Ahora compartes tus npcs con %s.",
	teComparten = "%s ahora comparte sus npcs contigo.",
	dejaste = "Has dejado de compartir tus npcs con %s.",
	teDejaron = "%s ha dejado de compartir sus npcs contigo.",
	-- Atacable (CanSupportUser, modHechizos.bas:2596-2618). El segundo sigue en el original con ", pero te puedes
	-- volver criminal.": ahí baja la reputación, que el port no tiene
	ayudaAtacableArmada = "Los miembros del ejercito real no pueden ayudar a ciudadanos en estado atacable.",
	ayudaAtacableSeguro = "Para ayudar ciudadanos en estado atacable debes sacarte el seguro.",
	finAtacable = "Ya no eres atacable.", -- nuestro
	teRoban = "%s se metio con tu criatura: durante un minuto puedes atacarlo sin consecuencias.", -- nuestro, al dueño
	-- Al mirar (DC19-10 A, nuestro): "(Sano) Lobo le pertenece a Fulano", como "es mascota de"
	pertenece = " le pertenece a %s",
} :: { [string]: string }

return Dueno
