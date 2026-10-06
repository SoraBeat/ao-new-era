--!strict
--[[
	Ambiente — constantes y textos de la Fase 18 (docs/37): lluvia, frío de la nieve, lava y el día.
	Las cuentas están en Shared/Mundo/Ambiente; la referencia, en herramientas/fase18_ref.py.
]]

local Ambiente = {}

-- ─── Lluvia (docs/37 §2) ─────────────────────────────────────────────────────
-- Cuándo (DA18-02 A): por el reloj. tLluviaEvent (frmMain.frm:987-1016): 65 min sin lluvia y hasta 5 de lluvia, con
-- 2 % de cortarse en cada minuto
Ambiente.SecoMin = 65
Ambiente.MaxLluviaMin = 5
Ambiente.ProbCorte = 2
-- Fase 21 (docs/40 §6, D21-23 A y D21-24 A): la lluvia empieza en un minuto sorteado del ciclo (de InicioMin a
-- SecoMin), no siempre al final; y un servidor recién abierto no ve llover (la lluvia que caiga ahí se saltea entera)
Ambiente.InicioMin = 10
Ambiente.GraciaServidorSeg = 15 * 60
-- Qué hace: desde la Fase 24 (docs/43 §2, pedido del autor), nada: la lluvia solo se ve y se oye. Hasta la Fase 23
-- (DA18-03 A) era EfectoLluvia (General.bas:839-864): 3 % de la energía máxima por segundo a la intemperie y sin
-- recuperar vida ni energía mientras se mojaba. Con 0 no saca energía; con false se recupera igual.
Ambiente.LluviaPorcSta = 0
Ambiente.LluviaSinRegenerar = false
Ambiente.TicksSegundo = 25 -- PasarSegundo, en ticks de 40 ms
Ambiente.MsgLluvia = "Ha comenzado a llover." -- nuestros (DA18-06 A): el original no avisa
Ambiente.MsgFinLluvia = "Ha dejado de llover."
-- Atributos del Workspace: llegan solos a los clientes
Ambiente.AtribLluvia = "AO_Lluvia" -- boolean: está lloviendo
Ambiente.AtribHora = "AO_Hora" -- string?: la fase fija que puso el Admin (nil = por el reloj)
-- Fase 21 (docs/40 §6, D21-25 A): cada servidor arranca en una hora del día al azar. number: los segundos que este
-- servidor le suma al reloj para la hora (de 0 a un día). La noche es solo visual: no importa que no coincidan.
Ambiente.AtribDesfaseHora = "AO_HoraDesfase"

-- ─── Frío de la nieve (docs/37 §3, DA18-07 B) ────────────────────────────────
-- En el original es código muerto (General.bas:914 compara "1" con "NIEVE") y sus 27 "mapas de nieve" no lo son.
-- Acá: el Reino Helado. Gotland (296) es de nieve, pero ciudad segura y hogar con sacerdote: sin frío que saque vida
-- Fase 30 (docs/50 §5, pedido del autor): el frío ya no saca vida en ningún mapa. El Reino Helado (295, 297, 298 y
-- 299) pasó a ser la zona de farmeo de las clases sin magia, y el que revive ahí sin armadura no tiene que morir de
-- nuevo. La regla queda (Shared/Mundo/Ambiente.frioNieve): para volver a prenderla alcanza con poner acá los mapas.
Ambiente.MapasFrio = {} :: { [number]: boolean }
-- Fase 20 (docs/39 §9, D20-36 A y D20-37 A): donde nieva, siempre y solo a la vista: el Reino Helado y la Ciudad de
-- Gotland (296). No es del original, que la dejó a medio hacer (los copos de particulas.ini [57] no los usa nadie).
Ambiente.MapasNieve = { [295] = true, [296] = true, [297] = true, [298] = true, [299] = true } :: { [number]: boolean }
-- La caída de "Nieve I": bastante más lenta que la lluvia (330 px/s), con un vaivén hacia los costados
Ambiente.NieveVY = 80 -- px por segundo hacia abajo
Ambiente.NieveVaiven = 18 -- px a cada lado
Ambiente.NievePeriodo = 4 -- segundos que tarda un vaivén completo
Ambiente.FrioPorc = 5 -- % de MaxHp por golpe (General.bas:916)
Ambiente.NieveTicks = 125 -- un golpe cada 5 s (el original, cada 16 ticks)
Ambiente.GraciaRevivirSeg = 30 -- recién resucitado: sin frío de nieve, para vestirse
Ambiente.MsgFrio = "Estas muriendo de frio, abrigate o moriras!!"
Ambiente.MsgMuerteFrio = "Has muerto de frio!!"

-- ─── Lava (docs/37 §4, DA18-08 A): EfectoLava (General.bas:942-977) ──────────
Ambiente.LavaMin, Ambiente.LavaMax = 5837, 5852 -- HayLava: el Grh de la capa 1
Ambiente.LavaTicks = 16 -- IntervaloFrio = 15 con el `<` del contador: 0,64 s
Ambiente.LavaPorc = 5
Ambiente.LavaAvisoSeg = 3 -- nuestro: el aviso, como mucho cada 3 s (el original lo repite con cada golpe)
Ambiente.MsgLava = "Quitate de la lava, te estas quemando!!"
Ambiente.MsgMuerteLava = "Has muerto quemado!!"

-- ─── El día (docs/37 §5, DA18-09 A a DA18-12 A) ──────────────────────────────
Ambiente.DiaMin = 100 -- no divide a 24 h: la noche se corre 40 min por día
Ambiente.TransicionSeg = 60
-- Los cinco colores del cliente original (cli/Motor/mDx8_Clima.bas:23-66)
Ambiente.Color = {
	amanecer = Color3.fromRGB(255, 200, 200),
	dia = Color3.fromRGB(255, 255, 255),
	mediodia = Color3.fromRGB(240, 250, 210),
	atardecer = Color3.fromRGB(150, 120, 120),
	noche = Color3.fromRGB(100, 100, 100),
} :: { [string]: Color3 }
-- { fase, minuto en que empieza, aviso }: los avisos de DiaNoche (cli/Motor/mDx8_Ambiente.bas:141-200)
Ambiente.Fases = {
	{ "amanecer", 0, "Ha comenzado a amanecer." },
	{ "dia", 5 },
	{ "mediodia", 37, "Es medio dia." },
	{ "dia", 42 },
	{ "atardecer", 75, "Ha comenzado a anochecer." },
	{ "noche", 80 },
} :: { { any } }
Ambiente.MedianocheMin = 90
Ambiente.MsgMedianoche = "Es media noche."
Ambiente.FasesAdmin = { "amanecer", "dia", "mediodia", "atardecer", "noche" }

-- ─── Fogata (docs/37 §6): Map_CheckBonfire (cli/Areas/mPooMap.bas:297-319) ───
Ambiente.GrhFogata = 1521
Ambiente.FogataX, Ambiente.FogataY = 8, 6

return Ambiente
