--!strict
--[[
	Supervivencia — constantes y textos de las fogatas y el descanso (Fase 19, docs/38 §2 y §3).
	Las cuentas están en Shared/Jugador/Supervivencia; la referencia, en herramientas/fase19_ref.py.
]]

local Supervivencia = {}

-- Declares.bas:432-460 y Dat/obj.dat
Supervivencia.Madera = 58 -- Lena
Supervivencia.Ramitas = 136 -- FOGATA_APAG
Supervivencia.Fogata = 63 -- FOGATA
Supervivencia.Daga = 15 -- DAGA: la única herramienta
Supervivencia.MaderasPorFogata = 3
Supervivencia.Distancia = 2 -- Distancia(): la suma de los dos ejes
-- HayOBJarea (TCP.bas:991-992): toda la pantalla. El sonido llega menos (Config/Ambiente.FogataX/Y)
Supervivencia.VistaX, Supervivencia.VistaY = 11, 9
Supervivencia.DuraSeg = 600 -- DC19-04 A: la fogata prendida dura 10 minutos (el original: hasta la limpieza del mundo)
-- El fallo no se repite seguido (UltimoMensaje = 10, Trabajo.bas:1802-1808). Acá otra marca: la 10 ya la usa "Estas
-- muy cansado." de los oficios, y una taparía a la otra
Supervivencia.MarcaNoHecha = 19
Supervivencia.PrenderMs = 500 -- nuestro: entre dos intentos de prender (cada intento sube el skill)
-- Fase 28 (docs/48 §5, pedido del autor): con este skill se ve, debajo de cada paralizado o inmovilizado (jugador o
-- criatura), una barra con el tiempo que le queda
Supervivencia.SkillVerParalisis = 87
Supervivencia.ParalisisCadaMs = 250 -- cada cuánto mira el servidor si hay algo nuevo que avisar
Supervivencia.ParalisisTolerancia = 0.8 -- s: un cambio menor en lo que queda no se vuelve a mandar (ni mueve la barra)
-- Fase 28 (docs/48 §5.2, pedido del autor): con este skill se ve la barra de vida de las criaturas y de los demás
-- jugadores del mapa. El servidor manda la vida en pasos (los pixeles de la barra), no el número.
Supervivencia.SkillVerVida = 100
Supervivencia.VidaCadaMs = 250
Supervivencia.BarraAncho = 34 -- px: el ancho de las dos barras, y los pasos en que viaja la vida

-- Fase 28 (docs/48 §1.1, pedido del autor): con este skill, doble click sobre un árbol que tengas al lado para comer y
-- sobre el agua (río, lago, mar) o una fuente para beber
Supervivencia.SkillForraje = 60
Supervivencia.ComeArbol = 25 -- lo que sube el hambre (de 0 a 100) cada vez
Supervivencia.BebeAgua = 25 -- lo que sube la sed
Supervivencia.ForrajeMs = 1000 -- entre una vez y la siguiente
-- consolaUnaVez: cada aviso de "no podés" no se repite seguido. Comer usa MarcaForraje + 0 a 3 (sin skill, lleno,
-- lejos, muerto) y beber + 4 a 7. Al comer o beber la marca se suelta, y el próximo aviso vuelve a salir.
Supervivencia.MarcaForraje = 37
-- Las fuentes y las cascadas: son dibujos de la capa 3 del mapa, no objetos. [grh] = { ancho, alto } en pixeles (los
-- del dibujo; herramientas/fase28_ref.py los compara con el atlas). 22070: la fuente de Ullathorpe (animada); 7163 a
-- 7170: la fuente de Gotland, cortada en ocho tiras; 4544 y 1468: las cascadas. Solo cuentan sus tiles bloqueados.
Supervivencia.FuentesGrh = {
	[22070] = { 266, 256 }, [4544] = { 298, 154 }, [1468] = { 105, 222 },
	[7163] = { 256, 32 }, [7164] = { 256, 32 }, [7165] = { 256, 32 }, [7166] = { 256, 32 },
	[7167] = { 256, 32 }, [7168] = { 256, 32 }, [7169] = { 256, 32 }, [7170] = { 256, 32 },
} :: { [number]: { number } }

Supervivencia.Msg = {
	equipar = "Antes de usar la herramienta deberias equipartela.",
	ocupado = "No puedes hacer ramitas con alguien parado sobre la lena.", -- nuestro: el original sale callado
	sinMadera = "Necesitas clickear sobre lena para hacer ramitas.",
	lejosHacer = "Estas demasiado lejos para prender la fogata.",
	pocas = "Necesitas por lo menos tres troncos para hacer una fogata.",
	hechas = "Has hecho %d fogatas.",
	noHecha = "No has podido hacer la fogata.",
	lejosPrender = "Estas demasiado lejos.",
	zonaSegura = "No puedes hacer fogatas en zona segura.",
	ciudad = "La ley impide realizar fogatas en las ciudades.",
	prendida = "Has prendido la fogata.",
	noPrendida = "No has podido hacer fuego.",
	descansa = "Te acomodas junto a la fogata y comienzas a descansar.",
	levanta = "Te levantas.",
	sinFogata = "No hay ninguna fogata junto a la cual descansar.",
	termina = "Has terminado de descansar.",
	deja = "Has dejado de descansar.",
	-- Fase 28 (docs/48 §1.1): comer de los árboles y beber del agua. Nuestros.
	sinSkillComer = "Necesitas %d de Supervivencia para comer de los arboles.",
	sinSkillBeber = "Necesitas %d de Supervivencia para beber del agua.",
	come = "Comes los frutos del arbol.",
	bebe = "Bebes agua.",
	sinHambre = "No tienes hambre.",
	sinSed = "No tienes sed.",
	muerto = "No puedes realizar esta accion estando muerto.",
} :: { [string]: string }

return Supervivencia
