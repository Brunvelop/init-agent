---
name: plan-commits
description: Usar cuando el usuario pide diseñar/planificar un cambio dividido commit a commit (solo diseño, sin implementar). Escribe docs/plans/<slug>.md para ejecutarlo luego con la skill plan-build.
---

Vas a DISEÑAR un plan de implementación. NO escribes ni modificas código de producto, NO ejecutas comandos que cambien estado: esta fase es solo de diseño y exploración (read-only sobre el codebase). La ÚNICA escritura permitida es el fichero del plan.

## Tarea

La tarea es lo que el usuario pidió planificar en su mensaje (y la conversación de diseño previa, si la hay). Si no está claro qué planificar, pregunta brevemente antes de continuar.

## Regla de oro: empatía con un implementador externo

El plan lo ejecutará un programador EXTERNO, nuevo en este codebase, que NO ha visto esta conversación ni conoce nada del proyecto. Es lo más importante de todo: el plan debe ser autosuficiente. Esa persona lo lee de arriba abajo y lo implementa SIN tomar ni una sola decisión de diseño y SIN tener que adivinar nada.

Por tanto, para CADA paso incluye el contexto que un recién llegado necesitaría: rutas de fichero exactas, nombres de símbolos/funciones, firmas literales, valores concretos (strings, claves de config, campos JSON), snippets de código reales (no pseudocódigo vago), qué reutilizar (con su path) vs qué crear nuevo, y cómo se manejan los casos límite (vacío, ausente, error, conflicto). Todo el conocimiento implícito que diste por sentado en la conversación debe quedar explícito. Ninguna decisión queda abierta en el plan, pero no todas las cierras tú (ver «Quién cierra cada decisión»).

## Quién cierra cada decisión

- **La cierra el usuario (pregúntalas todas juntas en UNA sola ronda ANTES de escribir el plan, con opciones y la recomendada primero; usa la herramienta de preguntas de tu harness si la hay):** todo lo que el usuario verá o notará al usar el resultado — cuándo aparece/desaparece algo, qué acción lo dispara, textos y controles nuevos de UI, qué se persiste y cuánto dura, comportamiento por defecto. Si ya la preguntaste y no ha respondido, NO la contestes tú en el plan: espera o vuelve a preguntar. Ejemplo: «¿el resaltado se borra al salir o con un botón?» es del usuario, aunque una opción parezca más conservadora.
- **La cierras tú, con la opción más conservadora y anotada en el plan:** detalles internos que el usuario no ve (nombres de funciones, dónde vive un estado, orden de pasos, formato interno).
- **Lo que el código responde no se pregunta ni se supone: se lee.**

## Contrato de infraestructura del repo (fíjalo al explorar, antes de diseñar)

- **Tests:** antes de escribir la sección Tests, comprueba si el repo tiene suite (`package.json`/`pyproject`/`Makefile` scripts, directorios `test*`, CI). Si NO la tiene, el plan NO añade ficheros de test, runners ni módulos nuevos sólo para hacerlos testeables; lo dice con la evidencia («`package.json` sin scripts; `git ls-files` sin tests») y la verificación es la de abajo. Si la tiene, nombra el fichero de test existente que sirve de patrón y el comando exacto.
- **Ficheros nuevos:** sólo si el repo ya organiza así código equivalente; si no, el cambio va en los ficheros existentes.
- **Arranque y comandos:** cualquier comando que el plan use (arrancar servidor, puerto, URL, CLI) sale de algo leído (scripts, README, punto de entrada con su línea) y se cita con `path:línea`. Nunca dejes «comando sin verificar» si una lectura o una búsqueda lo resuelve.
- **Cómo provocar el comportamiento nuevo sin dependencias vivas** (agente, navegador, servicios externos): busca endpoints HTTP del servidor (`rg -n` sobre las rutas que enruta), ficheros de datos/log que lee, fixtures. Anota la llamada concreta (`curl` con su body) y sus precondiciones (qué debe existir antes y cómo crearlo). De aquí sale la Verificación de cada commit.

## Procedimiento

1. **Destila la conversación (no la transcribas).** Identifica: el problema, la solución/idea técnica acordada, las decisiones de diseño tomadas (con su porqué), las alternativas descartadas, y cualquier suposición sin verificar. Si algo clave quedó ambiguo, resuélvelo o márcalo como suposición a confirmar con el comando exacto para verificarlo.
2. **Explora la base a fondo** antes de proponer nada. Usa las herramientas de búsqueda y lectura de tu harness y, si el alcance lo justifica, subagentes de exploración en paralelo (`scout` en OMP, `Explore` en Claude Code). Cada ruta, símbolo, firma y comportamiento que el plan afirme como hecho debe venir de algo que hayas leído esta sesión. Lo no confirmado se marca inline (`sin verificar — confirmar primero`).
3. **Diseña una única aproximación** y comprométete. Pondera trade-offs en una línea, decide, sigue.
4. **Divide el trabajo en N COMMITS** ordenados. Cada commit:
   - Es un incremento coherente y autocontenido: el árbol compila y los tests existentes pasan al terminarlo.
   - Agrupa pasos por comportamiento, nunca un commit por fichero porque sí.
   - Declara qué commits dependen de cuáles y cuáles son independientes (paralelizables).
   - Lleva un mensaje de commit propuesto (imperativo, conciso).
   - Si salen más de ~10 commits, propón partir en varios planes encadenados.
5. **Escribe el plan** en `docs/plans/<slug>.md` (slug kebab-case que nombre la tarea; NO en `docs/plans/done/`, que es el archivo de planes cerrados). No lo commitees tú: eso lo hace `plan-build` como paso previo al tag base. Usa la estructura de abajo. Si el fichero ya existe para ese slug, reescríbelo entero.
6. **Comprueba el plan contra el código** con el script de esta skill y corrige cada hallazgo (ver «Antes de pedir revisión»).
7. **No implementes nada.** Al terminar, di el slug y un resumen de 2-3 líneas de los commits, y **ofrece revisar/ajustar el plan** antes de ejecutarlo con `plan-build <slug>`.

## Honestidad técnica (aplícala a lo largo del plan)

- Haz explícitas las decisiones de diseño, con su justificación ("se elige X sobre Y porque...").
- Cuando una decisión sea cuestionable o el usuario podría querer lo contrario, dilo abiertamente y ofrece la alternativa ("Recomiendo A; si prefieres B, ajusto el plan").
- Marca claramente cualquier suposición sin verificar y deja el cómo verificarla.
- Respeta y nombra las invariantes de arquitectura del repo que el trabajo no debe romper.

## Estructura del fichero `docs/plans/<slug>.md`

```markdown
# Plan: <título>

## Contexto para quien implementa (léelo primero)
Qué es el proyecto, los conceptos de dominio mínimos, el mapa de archivos relevantes, y las convenciones del repo que afectan al trabajo (arquitectura, tests, comandos).

## Context
Qué se pide (literal), por qué, y el estado final esperado. 2-4 frases.

## El problema y la solución / idea técnica
Antes de los commits: por qué se eligió este enfoque, por qué funciona, y qué alternativas se descartaron.

## Commits
Lista ordenada. Para cada commit:

### Commit N — <mensaje de commit propuesto>
- **Depende de:** commit(s) previos, o "independiente".
- **Objetivo:** qué comportamiento entrega este commit, en una frase.
- **Archivos y cambios:** rutas concretas, funciones/líneas ancla, y snippets de código reales que muestren exactamente qué escribir. Qué reutilizar (con path) vs crear nuevo. Para renames/cambios de firma/borrados: lista cada callsite (o el `grep` exacto que los devuelve) y qué se borra.
- **Tests:** qué tests añadir o ajustar, siguiendo los patrones del repo; nombra los ficheros y el comando para correrlos.
- **Casos límite:** vacío/ausente/conflicto/error por cada path nuevo, o por qué no aplica. Además, para cada estado nuevo, cómo interactúa con el estado EXISTENTE que toca lo mismo: primera vez/sin datos previos, ediciones del usuario sobre el mismo dato, estados transitorios abiertos (editor inline, re-render que reemplaza el DOM, peticiones en vuelo), fallo de persistencia (`try/catch` en lectura Y escritura si lo afirmas), ids duplicados. Cada uno con la decisión tomada, no como pregunta.
- **UI nueva (si aplica):** elemento, id/clase exactos, en qué contenedor y posición (`path:línea`), qué clase/estilo existente reutiliza y cómo se coloca en el layout del contenedor (flex/grid leído del CSS).
- **Verificación del commit:** el check concreto (comando + entrada → salida observable) que prueba que ESTE commit funciona end-to-end, no solo que compila. Si el comportamiento depende de un estado difícil de producir (un agente vivo, un servicio externo, datos históricos), busca y da la vía reproducible: endpoint existente (`curl` literal con body), fichero/fixture con su contenido literal (formato y unidades de cada campo, p. ej. `t` en ms) y qué más necesita para cargarse, o script de consola. «Hacer que X ocurra» sin cómo no es una verificación.

## Critical files & anchors
Los <=5 ficheros que desambiguan el trabajo no obvio: path + símbolo/región + una línea de por qué.

## Verification (global)
Cómo probar el conjunto end-to-end. Comandos exactos, working dir, env vars, fixtures. Al menos un check que ejercite el comportamiento NUEVO.

## Riesgos / cosas que te van a morder
Los puntos donde la implementación puede descarrilar y cómo evitarlo.

## Assumptions & contingencies
Solo decisiones que el usuario podría querer cambiar. Para cada supuesto load-bearing que pueda resultar falso en ejecución, pre-decide el fallback ("si la realidad es X, haz Y").

## Checklist
Lista commit-a-commit marcable, apta para inicializar la lista de tareas en la ejecución.
```

## Antes de pedir revisión: checklist del plan

Ejecuta desde la raíz del repo `python3 <directorio de esta skill>/scripts/check_plan.py docs/plans/<slug>.md` (instalación por proyecto: `.agents/skills/plan-commits/scripts/check_plan.py`). Es de solo lectura; repítelo tras cada cambio del plan hasta 0 hallazgos relevantes (RUTA/LINEA/ANCLA/CMD/NUMERO; un RUTA de un fichero que el plan crea se ignora; cada PENDIENTE que se resuelva leyendo, se resuelve). Si no hay `python3`, haz las mismas comprobaciones a mano. Después recorre el fichero escrito y corrige hasta que todo sea «sí»:

1. Cada decisión que el usuario tomó en la conversación aparece en el plan con «(decisión del usuario)», y nada del plan la contradice.
2. Ningún «sin verificar» que se resuelva con una lectura o una búsqueda: resuélvelo ahora y bórralo. Los que queden llevan comando y fallback.
3. Cada comando de comprobación del plan (`rg`, `grep`, `curl`) lo has ejecutado o lo has construido sobre texto leído, y devuelve lo que el plan dice (p. ej. `const f = () =>` no casa con `rg "function f"`). Cada ancla `path:N` que lista `check_plan.py` apunta a la línea que el plan describe; si dudas, cita el símbolo en vez del número.
4. Cada snippet existe en UNA sola versión: sin notas posteriores que lo corrijan ni condiciones duplicadas distintas; numeraciones correlativas.
5. Cada commit tiene verificación ejecutable según el contrato de arriba (arranque citado + forma reproducible de producir el estado).
6. Casos límite de interacción con estado existente y ubicación de UI nueva cerrados en cada commit que los toca.
7. Cada evento, entrada o estado nuevo que el plan mete en un flujo existente tiene recorridos TODOS sus consumidores actuales (búsqueda del `type`/`kind`/nombre en todo el repo). El plan dice cómo se comporta cada uno; si alguno lo trataría como error o aviso falso, el plan lo corrige y lo pone en la verificación.

## Estilo

Escribe en español, directo y técnico. Usa snippets de código, tablas (para inventarios o mapeos) y comandos ejecutables; evita la palabrería. Sé denso y concreto: corta cualquier sección que no elimine una decisión. Cambios quirúrgicos: cada línea del plan debe trazar al objetivo del usuario; nada especulativo ni "mejoras" no pedidas.
