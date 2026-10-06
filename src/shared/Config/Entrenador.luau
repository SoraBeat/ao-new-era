--!strict
--[[
	Entrenador — constantes y textos del entrenador de Banderbill (Fase 20, docs/39 §4).
	La referencia está en herramientas/fase20_ref.py (entrenador).
]]

local Entrenador = {}

Entrenador.Dist = 10 -- HandleTrainList (Protocol.bas:6451): Distancia(), la suma de los dos ejes
Entrenador.MaxPorEntrenador = 7 -- MAXMASCOTASENTRENADOR (Declares.bas:277)
Entrenador.MaxPorJugador = 2 -- nuestro (D20-25 A): entre los dos entrenadores
Entrenador.DistSeVa = 15 -- nuestro (D20-26 A): más lejos que esto del entrenador, la criatura se va
Entrenador.DuraSeg = 300 -- nuestro: a los 5 minutos se va sola

Entrenador.Msg = {
	muerto = "No puedes realizar esta accion estando muerto.",
	sinNpc = "Primero tienes que seleccionar un personaje, haz click izquierdo sobre el.",
	lejos = "Estas demasiado lejos.",
	lleno = "No puedo traer mas criaturas, mata las existentes.", -- lo dice el entrenador (Protocol.bas:4141)
	tope = "Ya tienes %d criaturas: mata alguna antes de pedir otra.", -- nuestro
	seFue = "La criatura de entrenamiento se fue.", -- nuestro
	deOtro = "Esa criatura esta entrenando con otro.", -- nuestro
	titulo = "Con que criatura deseas combatir?", -- FRM_ENTRENADOR_TITLE
} :: { [string]: string }

return Entrenador
