--!strict
--[[
	Transporte — navegación y monturas (paquete P7, docs/34-spec-transporte.md).

	Navegar (docs/34 §1; UseInvItem otBarcos, InvUsuario.bas:2174-2227, y DoNavega, Trabajo.bas:175-296): el barco se usa
	con agua libre al lado; navegando solo se pisa agua. Los números y los mensajes están verificados contra
	herramientas/fase16d_ref.py (muestras/fase16d_vectores.json).
]]

local Transporte = {}

-- ─── Navegar ─────────────────────────────────────────────────────────────────
-- Fase 26 (docs/46 §6, pedido del autor): nivel 18 para todos. En el original eran 25, y 20 para el Pirata y el
-- Trabajador (este, de 20 a 24, con Pesca 100): con el mínimo en 18 esa ventaja de clase ya no tiene lugar.
Transporte.NivelNavegar = 18
Transporte.NivelNavegarPirata = 18 -- (igual que el resto; queda para la wiki)
-- EsGalera / EsGaleon miran el Ropaje del objeto (84 Barca, 85 Galera, 86 Galeón)
Transporte.RopajeGalera, Transporte.RopajeGaleon = 85, 86
Transporte.Galera = { Pirata = true, Asesino = true, Bandido = true, Clerigo = true, Ladron = true, Paladin = true }
Transporte.Galeon = { Ladron = true, Pirata = true }

-- ToggleBoatBody (Modulo_UsUaRiOs.bas:143-294): el cuerpo según el Ropaje y la alineación. DT16-06 A: el neutral,
-- con el del criminal; los de la Armada y la Legión llegan con las facciones (P8).
Transporte.CuerposBarco = {
	[84] = { ciudadano = 395, criminal = 396 },
	[85] = { ciudadano = 397, criminal = 398 },
	[86] = { ciudadano = 399, criminal = 400 },
} :: { [number]: { ciudadano: number, criminal: number } }
Transporte.Fragata = 87 -- iFragataFantasmal: el muerto que navega y el Pirata oculto en el agua

Transporte.Msg = {
	Nivel = "Para recorrer los mares debes ser nivel 18 o superior.",
	Costa = "Debes aproximarte al agua para usar un barco y a la tierra para desembarcar!",
	Montado = "No puedes navegar mientras estas en tu montura!!",
	Galera = "Solo los Piratas, Asesinos, Bandidos, Clerigos, Bandidos y Paladines pueden usar Galera!!", -- sic
	Galeon = "Solo los Ladrones y Piratas pueden usar Galeon!!",
	Skill = "No tienes suficientes conocimientos para usar este barco.",
	TirarAltamar = "Solo los Piratas pueden tirar items en altamar",
	OcultarNavegando = "No puedes ocultarte si estas navegando.",
	InvisibleNavegando = "No podes hacerte invisible navegando.", -- el que el original tiene y no usa bien (DT16-08 C)
	BarcoEnUso = "No puedes vender tu barco mientras lo estes usando.", -- Protocol.bas:4728-4736; acá también tirar y depositar
	Visible = "Has vuelto a ser visible!",
	Fragata = "Te has camuflado como barco fantasma!", -- nuestro
	AparienciaNormal = "Has recuperado tu apariencia normal!",
	MonturaEnUso = "No podes tirar tu montura mientras la estas usando.", -- InvUsuario.bas:514-517
	SinBarco = "No tienes ningun barco.", -- nuestro (Fase 21, docs/40 §8): la tecla Navegar sin barco en el inventario
}

-- El Pirata con Galera hasta nivel 20 o con Galeón hasta 25 no pierde lo suyo en el agua (InvUsuario.bas:2413-2446):
-- [ropaje] = nivel tope
Transporte.NivelPirata = { [85] = 20, [86] = 25 } :: { [number]: number }
function Transporte.msgPirata(barco: any): string
	if barco and barco.ropaje == 86 then
		return "Por que sos Pirata y nivel menor o igual a 25 no se te caen las cosas con el Galeon. Cuando llegues a nivel 26 perderas esta condicion."
	end
	return "Por que sos Pirata y nivel menor o igual a 20 no se te caen las cosas con la Galera. Cuando llegues a nivel 21 perderas esta condicion."
end

-- ─── Monturas (docs/34 §4; DoEquita, Trabajo.bas:3191-3269) ─────────────────
-- Velocidad (DT16-10 A): el paso del cliente pasa de 222 a 167 ms (32 px a 0,192 px/ms, cli Engine_BaseSpeed 0,024) y
-- el servidor rellena el balde de pasos a 145 ms por ficha (el mismo margen que a pie: 193 × 167 / 222)
Transporte.MsPasoMontado = 167
Transporte.MsFichaMontado = 145
Transporte.EsperaMontura = 10 -- MonturaCounter: segundos para volver a montar después de bajarse
Transporte.ZonaDungeon = "DUNGEON"
Transporte.MarcaMontura = 34 -- la marca de consolaUnaVez del aviso de no caminar bajo techo

Transporte.MsgMontura = {
	Invisible = "Estas invisible, no puedes montarte ni desmontarte en este estado!!",
	Muerto = "Estas muerto, no puedes montarte ni desmontarte en este estado!!",
	Navegando = "Estas navegando, no puedes montarte ni desmontarte en este estado!!",
	Techo = "No puedes utilizar la montura bajo techo o dungeons!",
	Caminar = "No puedes caminar aqui con tu montura, bajate para poder entrar a un lugar con techo o dungeons.",
	Equipar = "No puedes equiparte o desequiparte mientras estas en tu montura!",
	Herramienta = "No puedes usar una herramienta mientras estas en tu montura!!",
	Meditar = "No puedes meditar mientras si estas montado.", -- sic
	Visible = "Has vuelto a ser visible!",
	-- Nuestros (DT16-14 A y DT16-15 B)
	Ocultar = "No puedes ocultarte montado.",
	SinMontura = "No tenes una montura. Las vende el mercader; los dragones, la Tienda.", -- nuestro (Fase 23)
	Mimetizado = "No puedes montar mientras estas mimetizado.",
}
function Transporte.msgEspera(seg: number): string
	return `Debe esperar {seg} segundos para volver a usar tu montura`
end

-- La clave del motivo por el que no puede navegar, o nil (puede_navegar de fase16d_ref.py): primero el nivel
-- (UseInvItem) y, después de mirar la costa, lo del barco (DoNavega). DT16-07 A: el Trabajador necesita el MinSkill
-- del barco, no 60 fijo.
function Transporte.motivo(_clase: string, nivel: number, _pesca: number): string?
	return if nivel < Transporte.NivelNavegar then "Nivel" else nil
end

-- Las que mira DoNavega, después de la costa: clase de la Galera y del Galeón y el skill
function Transporte.motivoBarco(clase: string, navegacion: number, barco: any): string?
	if barco.ropaje == Transporte.RopajeGalera and not Transporte.Galera[clase] then
		return "Galera"
	end
	if barco.ropaje == Transporte.RopajeGaleon and not Transporte.Galeon[clase] then
		return "Galeon"
	end
	if navegacion < (barco.minSkill or 0) then
		return "Skill"
	end
	return nil
end

-- El cuerpo del barco de un vivo según su estado (newbie y ciudadano, el de ciudadano; neutral y criminal, el otro)
function Transporte.cuerpoBarco(ropaje: number, estado: string): number
	local c = Transporte.CuerposBarco[ropaje]
	if not c then
		return Transporte.Fragata
	end
	return if estado == "newbie" or estado == "ciudadano" then c.ciudadano else c.criminal
end

-- Fase 20 (docs/39 §10; ToggleBoatBody, Modulo_UsUaRiOs.bas:210-244): el barco del que está atacable lleva la bandera
-- violeta. [ropaje] = { ciudadano o neutral, Armada }. El Galeón tiene uno solo (el original nunca dibujó el otro).
Transporte.BarcosAtacable = { [84] = { 562, 563 }, [85] = { 567, 568 }, [86] = { 564, 564 } } :: { [number]: { number } }
function Transporte.cuerpoBarcoAtacable(ropaje: number, armada: boolean): number?
	local c = Transporte.BarcosAtacable[ropaje]
	return if c then c[if armada then 2 else 1] else nil
end

-- La apariencia completa navegando: sin cabeza ni arma, escudo o casco a la vista (el equipo sigue puesto)
function Transporte.aparienciaBarco(cuerpo: number): any
	return { cuerpo = cuerpo, cabeza = 0, casco = 0, arma = 0, escudo = 0 }
end

return Transporte
