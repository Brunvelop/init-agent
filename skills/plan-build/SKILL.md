---
name: plan-build
description: Usar cuando el usuario pide EJECUTAR un plan de docs/plans/<slug>.md commit a commit (commitea el plan, tag base, subagente plan-worker por commit, verificación, revisión final aceptar/corregir/revertir).
---

Vas a EJECUTAR un plan de implementación commit-a-commit. El slug es el que indicó el usuario. Si no lo dio, lista los planes en `docs/plans/*.md` (sin contar `done/`) y pregunta cuál ejecutar.

## Antes de empezar

1. Lee el plan completo desde `docs/plans/<slug>.md`. Si no existe, para y dilo.
2. Si el working tree tiene cambios sin commitear, para y avisa antes de tocar nada (no se mezcla trabajo en curso con el plan).
3. **Commitea el plan** si aún no está en git: `git add docs/plans/<slug>.md && git commit -m "docs: plan <slug>"`. El plan queda en la historia ANTES del tag base, así que un revert nunca lo borra del árbol.
4. Crea el ancla de reversión: `git tag -a plan-<slug>-base -m "Base del plan <slug>"` sobre HEAD (que ahora incluye el commit del plan). Si el tag ya existe, para y pregunta.
5. Inicializa la lista de tareas de tu harness (`todo` en OMP, `TodoWrite` en Claude Code) con un item por commit del plan, en orden.

## El bucle (un commit cada vez, en orden)

Para CADA commit del plan, respetando las dependencias declaradas:

0. **Re-ancla.** Antes de cada commit, relee su sección en `docs/plans/<slug>.md` y la lista de tareas; no te fíes de la memoria de la conversación (en planes largos habrá compactación).
1. **Delega a subagente(s) `plan-worker`** (ya trae el protocolo explorar → micro-plan → implementar, sin verificar ni commitear; vive en `.omp/agents/plan-worker.md` o `.claude/agents/plan-worker.md`, y si viene de un plugin puede aparecer con prefijo, p. ej. `plan-kit:plan-worker`). Cada subagente recibe en su encargo la SECCIÓN ENTERA de ese commit del plan (cópiala literal) más las "Critical files & anchors" relevantes. Si el commit agrupa pasos independientes sobre ficheros disjuntos, lanza varios en paralelo en una misma llamada; si hay dependencia interna, secuéncialos. Si tu harness no tiene el agente `plan-worker`, usa un subagente genérico y antepón a su encargo el protocolo del worker; si no tiene subagentes, implementa tú el commit siguiendo ese mismo protocolo.
2. **Verifica TÚ el commit.** Corre la "Verificación del commit" de esa sección. Si falla, corrige tú o relanza un `plan-worker` con el fallo como contexto, hasta que pase. No avances con un commit roto. Si la verificación pide algo que no puedes ejecutar aquí (p. ej. mirar una UI en un navegador), haz la comprobación más cercana que sí puedas (arrancar en un puerto libre y pedir la página con `curl`, un script de humo) y anótalo para la revisión final.
3. **Commitea.** `git add` de los ficheros tocados (nunca `git add -A` ni `git add .`) + `git commit -m "<mensaje del plan>"`. Marca el item como hecho y pasa al siguiente commit en el mismo turno.

Protocolo del worker (por si hay que dárselo a un subagente genérico): leer los ficheros reales antes de editar; implementar exactamente la sección, sin mejoras no pedidas ni ficheros fuera de alcance; no verificar, formatear ni commitear; ante ambigüedad o conflicto plan↔código, parar e informar con evidencia; al terminar, listar ficheros tocados, cambios por fichero y desviaciones.

## Empatía con implementador externo

Los subagentes NO han visto la conversación de diseño ni conocen el proyecto. Todo lo que necesitan para implementar su commit debe ir en el encargo: rutas exactas, símbolos, firmas, valores literales, qué reutilizar vs crear, casos límite. Si el plan no trae ese detalle para un commit, complétalo tú leyendo la base antes de delegar; nunca dejes que un subagente adivine. Si el subagente informa de un conflicto plan↔código, resuélvelo tú leyendo el código; si cambia el resultado visible, pregúntalo al usuario.

## Al terminar los N commits — REVISIÓN FINAL (para aquí)

1. Corre la "Verification (global)" del plan y reporta el resultado.
2. Muestra `git log --oneline plan-<slug>-base..HEAD`.
3. PARA y ofrece tres salidas explícitas (si el usuario quiere una segunda opinión antes de decidir, lanza el subagente `plan-reviewer` con el slug y el rango `plan-<slug>-base..HEAD` y enséñale su veredicto):
   - **Aceptar**: archiva el plan y cierra el ciclo:
     1. `mkdir -p docs/plans/done && git mv docs/plans/<slug>.md docs/plans/done/<slug>.md`
     2. `git commit -m "docs: archive plan <slug>"`
     3. `git tag -a plan-<slug>-done -m "Plan <slug> completado"` en HEAD
     4. `git tag -d plan-<slug>-base`
   - **Corregir**: el usuario dice qué ajustar y lo haces sobre la serie.
   - **Revertir**: `git reset --hard plan-<slug>-base` (deshace los commits de implementación; el plan, commiteado antes del tag, sigue intacto).
4. No borres el tag `plan-<slug>-base` hasta que el usuario confirme "aceptar".

No sigas con otro plan ni hagas trabajo extra tras la revisión final sin que el usuario lo pida.

## Estado de planes derivado de git

- **Activos:** tags `plan-<slug>-base` sin su `plan-<slug>-done` correspondiente.
- **Cerrados:** tags `plan-<slug>-done` (plan archivado en `docs/plans/done/`).
- Listado rápido: `git tag -n -l 'plan-*'`.
- Ojo con tags legacy de flujos antiguos (bases huérfanos de series ya cerradas): antes de derivar estado, comprueba el git real; no los borres sin confirmación.
