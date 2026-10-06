--!strict
--[[
	Constantes de combate del slice. Fuente: docs/14-spec-combate-slice.md §7 (cada valor citado ahí
	con archivo:línea del servidor VB6 clásico). Intervalos: perfil AO20 para las acciones del jugador (DF11-01 B,
	docs/20 §2); el perfil "clasico" es el set de D-01 A.
]]

local Combate = {}

-- ─── Intervalos (ms) ─────────────────────────────────────────────────────────
-- Las seis acciones del jugador salen del perfil (datos/intervalos_clasico.json y intervalos_ao20.json).
-- El poteo (IntervaloUserPuedeUsar), la caminata, los NPCs y la regeneración no cambian con el perfil.
Combate.Perfiles = {
	clasico = { atacar = 1500, magiaGolpe = 1000, golpeMagia = 1000, golpeUsar = 1200, hechizo = 1400, flechas = 1400 },
	ao20 = { atacar = 1165, magiaGolpe = 800, golpeMagia = 800, golpeUsar = 800, hechizo = 1230, flechas = 1200 },
}
Combate.Perfil = "ao20"
local P = Combate.Perfiles[Combate.Perfil]
Combate.IntervaloUserPuedeAtacar = P.atacar
Combate.IntervaloMagiaGolpe = P.magiaGolpe
Combate.IntervaloGolpeMagia = P.golpeMagia
Combate.IntervaloGolpeUsar = P.golpeUsar
Combate.IntervaloLanzaHechizo = P.hechizo
Combate.IntervaloFlechasCazadores = P.flechas
Combate.IntervaloUserPuedeUsar = 125
-- Tolerancia por latencia restada en los gates (DF7-05 A, concreta D-39) y tope anti-ráfaga de
-- IntervaloMagiaGolpe - gracia entre dos acciones cualesquiera (DF7-16 B). docs/15 §4.4
Combate.GraciaLatencia = 50
Combate.AntiRafaga = true

-- ─── Regeneración (en ticks de 40 ms; el evento cae en el tick siguiente: período = intervalo + 1) ──
Combate.TickMs = 40
Combate.StaminaIntervaloSinDescansar = 10 -- 440 ms
Combate.SanaIntervaloSinDescansar = 1600 -- 64,04 s
-- Fase 19 (docs/38 §3): descansando junto a una fogata (Server.ini:118-121)
Combate.StaminaIntervaloDescansar = 5 -- 240 ms
Combate.SanaIntervaloDescansar = 100 -- 4,04 s
Combate.RegenPorcentajeMaxSta = 5 -- vida y stamina se calculan con MaxSta (D-10)
Combate.RegenStaMin = 1
Combate.RegenHpMin = 2
-- Frío por estar desnudo (DF11-11 A): EfectoFrio en un mapa sin nieve resta 5 % de MaxSta cada IntervaloFrio + 1
-- ticks (Server.ini:128, General.bas:927-930), y RecStamina no regenera (General.bas:1290)
Combate.IntervaloFrio = 15
Combate.FrioPorcentajeMaxSta = 5
-- Hambre y sed (Fase 16a, docs/31 §1, DR16-01 A): -10 cada IntervaloHambre / IntervaloSed ticks (Server.ini:122-123)
Combate.IntervaloHambre = 6500 -- 260 s
Combate.IntervaloSed = 6000 -- 240 s
Combate.BajaHambreSed = 10
Combate.MaxHambreSed = 100

-- ─── Golpe ───────────────────────────────────────────────────────────────────
Combate.StaMinParaAtacar = 10
Combate.ProbBase = 50
-- El golpe físico de un jugador a una criatura (armas, puños, arcos y arrojadizas). El original usa base 50, piso 10 y
-- techo 90; docs/24 DA-09 A subió la base a 65. Fase 24 (docs/43 §15, D24-30 B, elegida por el autor: "fallan un
-- montón"): base 90, piso 50 y techo 95. Entre jugadores, y de criatura a jugador, sigue la del original.
Combate.ProbBaseVsCriatura = 90
Combate.ProbMinVsCriatura = 50
Combate.ProbMaxVsCriatura = 95
Combate.ProbPendiente = 0.4
Combate.ProbMin = 10
Combate.ProbMax = 90
Combate.BonusNivelPorNivel = 2.5
Combate.NivelBaseBonus = 12
Combate.DivisorTacticas = 33
Combate.DivisorEscudo = 2
Combate.MultArma = 3
-- Fase 21 (docs/40 §3): la Espada Mata Dragones (EspadaMataDragonesIndex, Declares.bas:257). De un golpe mata al
-- Gran Dragón Rojo (Config/Npcs.DragonesMataDragones; hasta la Fase 33, a los cinco dragones grandes); contra todo lo
-- demás el arma vale 1 (SistemaCombate.bas:372-384).
Combate.MataDragones = 402
Combate.MsgEspadaRota = "Tu Espada Mata Dragones se ha roto."
Combate.FuerzaBase = 15
Combate.DivisorFuerza = 5
Combate.ZonaCabeza = 1 -- zonas 1..6: 1 cabeza, 2..6 cuerpo

-- ─── Muerte y resurrección ───────────────────────────────────────────────────
Combate.CuerpoMuerto = 8
Combate.CabezaMuerto = 500
-- El altar del Mapa 39 (DF6-04) y su zona segura (DF10-04 B) se sacaron en la Fase 13 (DF13-06 A): resucita el
-- sacerdote de Ullathorpe (Config.Ciudad).

-- ─── FX y números ────────────────────────────────────────────────────────────
Combate.FxSangre = 14
-- Colores de los números de daño (colores.dat [51..56], docs/10 §5): normal y fallo
Combate.ColorDanio = Color3.fromRGB(0, 179, 0)
Combate.ColorFallo = Color3.fromRGB(30, 179, 0)

-- ─── Clases (Balance.dat): Config.Clases (docs/27 §1) ─────────────────────────
local Clases = require(script.Parent.Clases)
Combate.mod = {} :: { [string]: { [string]: number } }
for nombre, d in Clases.datos do
	Combate.mod[nombre] = d.mod
end

-- ─── Mecánicas de clase en el golpe (Fase 14a, docs/27 §3) ──────────────────
Combate.MinApunalar = 10 -- MIN_APUNALAR (Declares.bas:497): el Asesino apuñala desde 0
Combate.EspadaVikinga = 123 -- ESPADA_VIKINGA (Declares.bas:2377): el crítico del Bandido
Combate.GuantesHurto = 873 -- GUANTE_HURTO: desequipar (Bandido) y paralizar con el golpe (Ladrón)
Combate.ProbAcuchillar = 20 -- PROB_ACUCHILLAR (Declares.bas:273-275)
Combate.ProbVenenoArma = 60 -- UserEnvenena: RandomNumber(1, 100) < 60 (SistemaCombate.bas:2642)
Combate.StaMinDisparo = 10 -- LanzarProyectil (SistemaCombate.bas:2751-2765): pide 10 y gasta 1 a 10
Combate.ColorPunal = Color3.fromRGB(255, 51, 85) -- colores.dat [52]: DAMAGE_PUNAL

-- Pelea sin arma (DF11-06 A, docs/20 §6.5): el "arma" es 4..9 (SistemaCombate.bas:426-447)
Combate.DanoPunosMin = 4
Combate.DanoPunosMax = 9

-- Los números del equipo (ataque y defensa) salen de Shared.Generado.ObjetosInventario (obj.dat).

-- ─── Preset nivel 25 (docs/14 §1; HP con la esperanza exacta, DF6-01 B; las 12 clases, docs/27 §1.5) ─────
Combate.preset = {} :: { [string]: any }
for nombre, d in Clases.datos do
	local skills = { Armas = 0, Tacticas = 0, Defensa = 0, Magia = 0, Meditar = 0, Wrestling = 0 }
	for k, v in d.prueba.skills do
		skills[k] = v
	end
	Combate.preset[nombre] = {
		elv = 25,
		atrib = { Fuerza = 19, Agilidad = 19, Inteligencia = 18, Carisma = 18, Constitucion = 20 },
		skills = skills,
		maxHp = d.prueba.vida,
		maxSta = d.prueba.energia,
		maxMana = d.prueba.mana,
		minHit = d.prueba.golpe,
		maxHit = d.prueba.golpe + 1,
	}
end

return Combate
