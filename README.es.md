# discourse-category-lockdown-nautas

[ENGLISH](README.md) | **ESPAÑOL**

Mantenido por Criptonautas. Sin afiliación ni respaldo de Discourse (Civilized Discourse Construction Kit, Inc.).

Bloquea todos los temas de una categoría para que solo puedan leerlos los miembros de los grupos
especificados. Todos los demás son redirigidos al tema de descripción de la propia categoría.

Fork de [paviliondev/discourse-category-lockdown](https://github.com/paviliondev/discourse-category-lockdown),
mantenido para [criptonautas.co](https://criptonautas.co).

## En qué se diferencia este fork

**Upstream** redirige a los visitantes bloqueados a una URL configurada por el operador: un
ajuste del sitio `category_lockdown_redirect_url`, sobrescribible por categoría mediante un
campo personalizado `redirect_url`. Se aceptaba cualquier URL, incluidas las externas, así que la
redirección se hacía con `allow_other_host: true`.

**Este fork** elimina ambos y siempre redirige al tema de descripción de la propia
categoría ("Acerca de la categoría …"). La cadena de respaldo es:

1. el tema de descripción de la categoría, si existe y el visitante puede verlo;
2. la página de la categoría, si el visitante puede ver la categoría;
3. la raíz del sitio.

Consecuencias:

- **El destino siempre es del mismo origen.** Nada suministrado por el usuario o el contenido llega a
  `redirect_to`, y `allow_other_host` desaparece. El ajuste de upstream era una
  redirección abierta controlada por el administrador; esto la cierra.
- **El destino de la redirección se explica solo.** Los visitantes bloqueados llegan al texto que el propietario
  de la categoría ya escribió para describirla, en lugar de una página de marketing genérica que
  hay que mantener sincronizada a mano.
- **Sin configuración.** Un ajuste del sitio menos y un campo de categoría menos donde equivocarse.
  Discourse crea automáticamente el tema de descripción de una categoría.
- **El tema de descripción nunca se bloquea.** Se exime dentro de
  `CategoryLockdown.is_locked`, así que la redirección no puede entrar en bucle y el destino no puede
  dar 404. Ten en cuenta que esto exime todo el tema, respuestas incluidas: no publiques nada
  privado en el tema de descripción de una categoría bloqueada.

## Requisitos

Probado contra Discourse `main` en cada push mediante el flujo estándar de CI de plugins.
Las líneas anteriores **no están soportadas**: este fork usa rutas actuales de la API de plugins y de importación,
y antes incluía commits fijados de la era upstream para instalaciones anteriores a la 3.4, commits que
aún contenían la redirección externa que este README describe como eliminada. Esos anclajes se han
borrado en lugar de dejarlos contradecir el texto anterior.

## Dos modos independientes

Una categoría usa uno u otro. Se configuran por separado y no interactúan.

### Lockdown: ocultar todo el tema

Los no miembros son redirigidos al tema de descripción de la categoría. La categoría y los títulos de
sus temas siguen listados públicamente, que es el objetivo: es un muro de pago con embudo, no una
categoría privada.

Como la categoría sigue siendo legible, las rutas de consulta que construyen SQL directamente no ven
la sobrescritura de `Guardian` del plugin. La búsqueda, el flujo `/posts.json` y los flujos de
actividad de usuario se filtran explícitamente (`Search`, `LatestPostsQuery`, `UserAction`), cada uno con una
prueba de regresión. También las demás rutas que muestran contenido de un post tras comprobar solo que
el tema es visible: los feeds RSS de listas de temas (que omiten los temas bloqueados) y sus extractos,
la actividad y los feeds de grupos, los marcadores, los oneboxes, `/t/:id/excerpts`, los temas
similares y los resúmenes por correo. `/topics/timings` tampoco registra nada en un tema bloqueado,
para que los no miembros no acumulen progreso de lectura. **Si añades una función que expone contenido de posts por una nueva ruta de consulta,
la sobrescritura de `Guardian` no la cubrirá: compruébala.**

### Mantener respuestas privadas: primer post público, respuestas privadas

Por categoría, en **Ajustes → Seguridad**. El primer post de cada tema sigue siendo público;
cada respuesta se crea como un **susurro** (whisper) del núcleo. Pensado para un curso publicado cuyas lecciones
son públicas y cuya discusión de soporte es para suscriptores.

Como las respuestas son susurros, el núcleo las excluye de la búsqueda, los feeds, los resúmenes y los
endpoints de flujo para los lectores que no pueden ver susurros, sin necesidad de parchear cada ruta.

**Este modo depende del ajuste del sitio `whispers_allowed_groups`.** Los lectores que pueden ver
susurros son exactamente los miembros de esos grupos, *no* los `lockdown_allowed_groups` de la categoría.
Dos consecuencias:

- Añade a tus suscriptores **y a tus instructores** a `whispers_allowed_groups`. Los administradores son
  susurradores automáticamente; **los moderadores que no son administradores no lo son** y no verán, sin avisar,
  las respuestas que deben contestar.
- Es una única lista global, así que este modo no puede dar a distintas categorías distintos grupos
  de lectores. El modo Lockdown sí.

Los visitantes ven un adelanto sobre los temas sugeridos: cuántas respuestas hay y quién
participa (avatares y nombres de usuario, nunca nada de lo que escribieron). Ten en cuenta que esto revela quién
está inscrito. Reescríbelo en **Admin → Personalizar → Texto** bajo `lockdown.hidden_replies`.

#### Activarlo en una categoría que ya tiene respuestas

Las respuestas publicadas antes de activarlo son posts normales y siguen siendo públicas. Conviértelas:

```bash
rake category_lockdown:whisper_existing_replies[123,dry_run]   # count first
rake category_lockdown:whisper_existing_replies[123]
```

#### Nota sobre estilos globales

El plugin incluye CSS que neutraliza el estilo de susurro del núcleo (el indicador y el
texto atenuado en cursiva) para que las respuestas del curso se lean como posts normales. **Es global**, en la
suposición de que no usas también susurros para notas de moderación. Si lo haces, limita el alcance de
esas reglas en `assets/stylesheets/common/category-lockdown.scss`.

## Ajustes

| Ajuste | Propósito |
| --- | --- |
| `category_lockdown_enabled` | Interruptor general del plugin. |
| `category_lockdown_list_icon` | Icono FontAwesome mostrado junto a los temas bloqueados en las listas. |
| `category_lockdown_allow_crawlers` | Permite a los rastreadores de buscadores leer temas bloqueados. **Los rastreadores se identifican solo por User-Agent, que cualquiera puede enviar**: por sí sola esta exención es orientativa, no se aplica de forma estricta. |
| `category_lockdown_crawler_require_verified_ip` | Exige además que la petición provenga de un ASN del ajuste `crawler_asns` del núcleo. Cierra el rodeo por User-Agent, pero nada califica como rastreador hasta que se rellene `crawler_asns`. |
| `category_lockdown_crawler_noarchive` | Envía `<meta name="robots" content="noarchive">`. |
| `category_lockdown_crawler_indicate_paywall` | Emite schema.org `isAccessibleForFree: False`. |

Por categoría, en **Ajustes → Seguridad**: activa el bloqueo y elige los grupos que pueden
leerla. Los administradores siempre tienen acceso; **los moderadores no**: el bloqueo comprueba la pertenencia
a grupos, y los grupos permitidos se comparan **por nombre**, así que renombrar un grupo revoca
el acceso (falla cerrado).

## Quitar el plugin

Desactivar `category_lockdown_enabled` detiene todo comportamiento. No se destruye nada:
los campos personalizados de categoría permanecen, y las respuestas ya convertidas en susurros **siguen
siendo susurros**: no vuelven a ser posts públicos. Revierte eso con SQL si lo necesitas.

## Upstream

Discusión original del plugin: https://meta.discourse.org/t/discourse-category-lockdown/70649

Para traer cambios de upstream:

```bash
git remote add upstream https://github.com/paviliondev/discourse-category-lockdown.git
git fetch upstream
```

## Licencia

GPL-2.0, heredada de upstream. Consulta [LICENSE.txt](LICENSE.txt).

Texto de este README bajo [CC BY-NC-SA 4.0](CC-BY-NC-SA-4.0.txt).
