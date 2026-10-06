--!strict
--[[
	Chat (docs/23 §4, DN-05 a DN-09): hablar, gritar, susurrar, comandos y la consola del celular.
]]

local Chat = {}

Chat.Largo = 160 -- SendTxt.MaxLength (frmMain.frm:237)
Chat.AreaX, Chat.AreaY = 16, 14 -- ±16 × ±14 tiles en el mismo mapa (los bloques de área del original, ModAreas.bas)
Chat.SusurroX, Chat.SusurroY = 11, 9 -- el destinatario tiene que estar en pantalla (EstaPCarea)
Chat.SegEntreMensajes = 0.7 -- anti-spam nuestro
Chat.LargoMensaje = 160 -- lo que deja escribir la caja de chat (client/UI/Chat); el tope de lo que dice un bot (Fase 29)
Chat.SegEscribiendo = 0.3 -- como mucho un aviso de "escribiendo" cada 0,3 s

-- Colores del texto (HandleTalk, HandleYell, HandleWhisper; CHAT_COLOR_DEAD_CHAR)
Chat.Colores = {
	hablar = Color3.fromRGB(255, 255, 255),
	gritar = Color3.fromRGB(255, 0, 0),
	susurro = Color3.fromRGB(0, 0, 255),
	muerto = Color3.fromRGB(192, 192, 192),
	party = Color3.fromRGB(252, 203, 130), -- /PMSG: FONTTYPE_PARTY, solo en la consola (docs/28 §2.3)
	clan = Color3.fromRGB(228, 199, 27), -- /CMSG: FONTTYPE_GUILDMSG; va por el canal del clan (Fase 23, docs/42 §3.4)
} :: { [string]: Color3 }
-- El azul puro casi no se lee en la consola: ahí el susurro va más claro (nuestro)
Chat.ColorSusurroConsola = Color3.fromRGB(100, 150, 255)

Chat.MsgSpam = "Espera un momento antes de volver a hablar."
Chat.MsgSinChat = "Tu cuenta no tiene el chat habilitado."
Chat.MsgNoEnviado = "No se pudo enviar el mensaje."
Chat.MsgSusurroNadie = "No hay nadie con ese nombre cerca."
Chat.MsgSusurroPrivado = "No puedes enviarle mensajes privados a ese usuario."
Chat.MsgMuerto = "No puedes realizar esta accion estando muerto."
Chat.MsgComandoIncorrecto = "Comando incorrecto." -- spanish.json:619-620
Chat.MsgSinObjetivo = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el."
Chat.MsgResucitarLejos = "El sacerdote no puede resucitarte debido a que estas demasiado lejos."
Chat.MsgCurarLejos = "El sacerdote no puede curarte debido a que estas demasiado lejos."
Chat.DistResucitar, Chat.DistCurar = 5, 10 -- Protocol.bas:6617-6646, :6742-6770

Chat.Ayuda = {
	"La Guia del juego explica todo: /GUIA, la tecla F1 o el boton Guia.",
	"Comandos: /HOGAR (muerto, vuelve a tu ciudad), /MEDITAR, /EST (tus estadisticas), /ONLINE (quienes estan),",
	"/RESUCITAR y /CURAR (con el sacerdote clickeado), /DESCANSAR (junto a una fogata), /MONTAR, /SALIR (cambiar de personaje),",
	"/BANCARROTA (5.000 monedas de oro, una vez por hora), /TIENDA, /REGLAS, /REPORTE texto, /DENUNCIAR nick.",
	"Camino: /CAMINO (elegirlo), /ABANDONAR (pasar a neutral, en Ullathorpe). Para ser ciudadano o criminal: /ENLISTAR con el",
	"Rey (Banderbill) o el Demonio (Arkhein) clickeado. /SERCIUDADANO y /SERCRIMINAL te dicen a donde ir.",
	"/ADMIN (panel para probar, solo con personaje de prueba).",
	"Party: /CREARPARTY, /PARTY (con el lider clickeado), /ACCEPTPARTY nick, /ECHARPARTY nick, /PARTYLIDER nick,",
	"/SALIRPARTY, /PMSG texto (a tu party), /ONLINEPARTY.",
	"Mascotas: /QUIETO, /ACOMPANAR y /LIBERAR (con la mascota clickeada), o la ventana Mascotas.",
	"Retos: /RETOS (la ventana), /ACEPTAR nick. Para practicar sin perder nada: el portal de la plaza de Ullathorpe.",
	"Clan contra clan: /CVC clan (el lider desafia), /ACVC (el otro lider acepta), /IRCVC (anotarse, o viajar a la sala si el otro clan esta en otro servidor).",
	"Criaturas: /COMPARTIRNPC (con un jugador clickeado: le pega a las tuyas) y /NOCOMPARTIRNPC.",
	"Facciones: /ENLISTAR, /INFORMACION y /RECOMPENSA (con el Rey o el Demonio clickeado, o doble click sobre el),",
	"/RETIRARFACCION.",
	"Quests: /QUEST (con el NPC clickeado, o doble click sobre el: la pide o la entrega), /INFOQUEST (tus misiones).",
	"Entrenador: /ENTRENAR (con el entrenador de Banderbill clickeado, o doble click sobre el).",
	"Casas: /CASAS (con el vendedor de propiedades de la ciudad clickeado, o doble click sobre el).",
	"Chat: Enter para hablar, -texto para gritar, \\nick texto para susurrar (espacios del nick con +).",
}

-- Tamaños de la consola del celular (DN-09 A): líneas; 0 = oculta. El botón los recorre en este orden.
Chat.TamanosConsola = { 4, 12, 1, 0 }

return Chat
