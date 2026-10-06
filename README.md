# AO New Era

AO New Era es un port de **Argentum Online** clásico a **Roblox**. Toma como base la versión 0.13 que mantiene la comunidad de [ao-libre](https://github.com/ao-libre) y la reescribe en Luau, en 2.5D y con los gráficos originales, para que se pueda jugar desde la PC, el celular o la tableta sin instalar nada más que Roblox.

El objetivo es que quienes jugaron AO lo reencuentren tal como lo recuerdan, y que las nuevas generaciones tengan una puerta de entrada simple a un clásico del desarrollo de juegos argentino.

## Qué tiene el juego

- El mundo de AO: 298 mapas, con sus ciudades, dungeons, criaturas y NPCs.
- Las 12 clases, con el combate, la magia, los skills y la progresión del servidor clásico. Las fórmulas se verifican contra el código original.
- Inventario, comercio, banco, herrería, carpintería, minería, tala y pesca.
- Clanes, party, facciones (Armada Real y Legión Oscura), retos y misiones.
- Mascotas, monturas y navegación.
- Interfaz de PC igual a la del cliente clásico, y una interfaz propia para celular, tableta y mando.

## Qué hay en este repositorio

Este repositorio publica el código de AO New Era que deriva de Argentum Online:

| Carpeta | Contenido |
|---|---|
| `src/shared/` | Configuración, fórmulas y datos del juego: clases, hechizos, objetos, NPCs, recetas, mapas. Es lo que comparten el servidor y el cliente. |
| `src/client/` | El cliente: render de los gráficos de AO, controles, sonido y las ventanas que reproducen las del cliente clásico. |
| `src/first/` | La pantalla de carga. |
| `src/server/` | Dos módulos del servidor portados de ao-libre: los retos y la limpieza del mundo. |

En un proyecto de [Rojo](https://rojo.space), `src/shared` va a `ReplicatedStorage.Shared`, `src/client` a `StarterPlayer.StarterPlayerScripts.Client`, `src/first` a `ReplicatedFirst` y `src/server` a `ServerScriptService.Server`.

## Qué no hay

**Este repositorio no es el juego completo y no alcanza para levantar un servidor propio.** No incluye:

- El resto del servidor.
- Los sistemas propios de AO New Era que no vienen de Argentum Online: los bots, el panel de administración, la tienda, el mercado entre jugadores, el tutorial, la guía, el mapa del mundo, el soporte de mando y la interfaz acomodable del celular. Algunos archivos publicados hacen referencia a esos módulos.
- Los gráficos, los sonidos y la música.

Los comentarios del código citan al original con el formato `Archivo.bas:línea`. Esas citas apuntan a [ao-libre/ao-server](https://github.com/ao-libre/ao-server) y [ao-libre/ao-cliente](https://github.com/ao-libre/ao-cliente). Las referencias a `docs/` y `herramientas/` son a documentos y scripts internos del proyecto, que no están publicados.

## Créditos

AO New Era existe gracias al trabajo de mucha gente que hizo y mantuvo Argentum Online durante más de veinte años:

- **Argentum Online**, © 2002 Pablo Ignacio Márquez (Gulfas Morgolock) y todos los que colaboraron con el proyecto.
- Argentum Online se basó a su vez en **VB6 Online RPG Engine (ORE)**, de Baronsoft.
- La comunidad de **ao-libre**, que mantiene el servidor y el cliente clásicos de los que parte este port.

El port a Roblox es de SoraBeat.

## Licencia

El código de este repositorio es software libre. Se distribuye bajo los términos de la **Affero General Public License, versión 1 o cualquier versión posterior**, la misma licencia que figura en los archivos de Argentum Online de los que deriva. El texto completo está en [`LICENSE`](LICENSE) y los avisos de copyright en [`NOTICE`](NOTICE).

Se distribuye con la esperanza de que sea útil, pero SIN NINGUNA GARANTÍA.

La licencia cubre el código. Los gráficos, los sonidos y la música de Argentum Online no forman parte de este repositorio.
