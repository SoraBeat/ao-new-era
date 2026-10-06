--!strict
--[[
	Quests — constantes y textos de las misiones (Fase 20, docs/39 §2). Las quests están en Generado/Quests; las reglas,
	en Shared/Quests/Reglas; la referencia, en herramientas/fase20_ref.py (quests).
]]

local Quests = {}

Quests.Max = 15 -- MAXUSERQUESTS (modQuests.bas:20): las que se pueden tener a la vez
Quests.Dist = 5 -- Distancia() al NPC, la suma de los dos ejes (modQuests.bas:338)
Quests.RepetirSeg = 20 * 3600 -- D20-10: cada una se puede volver a hacer a las 20 horas de entregarla
Quests.DistParty = 18 -- a los de la party del que mata, hasta esta distancia de la criatura (la de la experiencia)
Quests.MaxPila = 10000 -- MAX_INVENTORY_OBJS: lo que entra en un slot

Quests.Msg = {
	-- Consola (modQuests.bas)
	lejos = "Estas demasiado lejos.",
	muerto = "No puedes realizar esta accion estando muerto.",
	sinNpc = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el.",
	aceptada = 'Has aceptado la mision "%s".',
	completada = 'Has completado la mision "%s"!',
	exp = "Has ganado %d puntos de experiencia como recompensa.",
	oro = "Has ganado %d monedas de oro como recompensa.",
	objeto = "Has recibido %d %s como recompensa.",
	-- Lo que dice el NPC sobre su cabeza
	sinMision = "No tengo ninguna mision para ti.",
	nivel = "Debes ser por lo menos nivel %d para emprender esta mision.",
	demasiadas = "Estas haciendo demasiadas misiones. Vuelve cuando hayas completado alguna.",
	faltanObjetos = "No has conseguido todos los objetos que te he pedido.",
	faltanCriaturas = "No has matado todas las criaturas que te he pedido.",
	sinEspacio = "No tienes suficiente espacio en el inventario para recibir la recompensa. Vuelve cuando hayas hecho mas espacio.",
	-- Nuestros (docs/39 §2.4 y §2.5)
	espera = "Ya has hecho esta mision. Vuelve en %s.",
	progreso = "%s: %s %d/%d.",
	lista = 'Has matado todo lo que pide la mision "%s": ya puedes volver.',
	abandonada = 'Has abandonado la mision "%s".',
	-- Del cliente (frmQuests.frm)
	ninguna = "No tienes ninguna mision!",
	elegir = "Primero debes seleccionar una mision!",
	confirmar = "Estas seguro que deseas abandonar la mision?",
	-- Las ventanas (spanish.json: FRM_QUEST_* y FRM_QUESTINFO_*)
	tituloOferta = "Informacion de la mision:",
	tituloLista = "Informacion de misiones:",
} :: { [string]: string }

return Quests
