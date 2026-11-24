# init-agent

Kit para inicializar cualquier repo con el flujo **planificar commit a commit → ejecutar con ancla de reversión**. Funciona en [OMP](https://github.com/can1357/oh-my-pi), Claude Code y cualquier harness que lea `SKILL.md` (Codex, Cursor, OpenCode…).

## Qué trae

| Pieza | Tipo | Qué hace |
|---|---|---|
| `plan-commits` | skill | Diseña un cambio dividido en commits y escribe `docs/plans/<slug>.md`, pensado para un implementador que no ha visto la conversación. No implementa nada. |
| `plan-commits/scripts/check_plan.py` | script | Comprobación mecánica (solo lectura) del plan contra el repo: rutas, líneas, anclas, `rg`/`grep` citados, pendientes. |
| `plan-build` | skill | Ejecuta el plan: commitea el plan, tag `plan-<slug>-base`, un subagente `plan-worker` por commit, verifica y commitea; al final ofrece aceptar / corregir / revertir. |
| `plan-worker` | subagente | Implementa UNA sección de commit. No verifica ni commitea. |
| `plan-reviewer` | subagente | Revisión en solo lectura de `plan-<slug>-base..HEAD` contra el plan. Veredicto en la primera línea. |

## Instalar en un proyecto

Desde la raíz del proyecto:

```bash
curl -fsSL https://raw.githubusercontent.com/Brunvelop/init-agent/main/install.sh | bash
```

Copia los ficheros dentro del repo (para commitearlos con él):

```
.agents/skills/plan-commits/   .agents/skills/plan-build/     # skills (OMP, Codex, Cursor, OpenCode…)
.omp/agents/plan-worker.md     .omp/agents/plan-reviewer.md   # subagentes de OMP
.agents/init-agent.lock                                        # versión instalada + hashes
```

Con Claude Code, añade `--claude` (automático si el proyecto ya tiene `.claude/`): copia además a `.claude/skills/` y `.claude/agents/`.

```bash
curl -fsSL https://raw.githubusercontent.com/Brunvelop/init-agent/main/install.sh | bash -s -- --claude
```

Opciones: `--dir <proyecto>`, `--ref <rama|tag>`, `--claude`, `--force`. Requiere `bash` y `git`.

## Actualizar

Vuelve a ejecutar el mismo comando. El instalador compara cada fichero con `.agents/init-agent.lock`:

- intacto desde la última instalación → se actualiza;
- modificado por ti → se conserva y se avisa (`--force` lo sobrescribe);
- eliminado del kit → se borra solo si estaba intacto.

Revisa el resultado con `git diff` y commitea.

## Otras vías

**Plugin (OMP o Claude Code)** — instala skills y subagentes fuera del repo, a nivel de usuario o de proyecto:

```bash
omp plugin marketplace add Brunvelop/init-agent
omp plugin install plan-kit@init-agent            # --scope project para un solo repo
# actualizar: /marketplace update init-agent  (dentro de OMP)
```

```
/plugin marketplace add Brunvelop/init-agent      # Claude Code
/plugin install plan-kit@init-agent
```

**Solo las skills, con `npx skills`** (no instala los subagentes; `plan-build` se apaña con un subagente genérico):

```bash
npx skills add Brunvelop/init-agent
npx skills update
```

## Uso

1. «Planifica X commit a commit» → `plan-commits` escribe `docs/plans/<slug>.md`. Revísalo.
2. «Ejecuta el plan `<slug>`» → `plan-build` crea el tag `plan-<slug>-base` y avanza commit a commit.
3. Revisión final: **aceptar** (archiva en `docs/plans/done/`, tag `plan-<slug>-done`), **corregir** o **revertir** (`git reset --hard plan-<slug>-base`). Antes de decidir puedes pedir el informe de `plan-reviewer`.

## Modelo de los subagentes

Los subagentes no fijan modelo: heredan el del agente principal. Para abaratar `plan-worker`:

- OMP, en `~/.omp/agent/config.yml`:
  ```yaml
  task:
    agentModelOverrides:
      plan-worker: anthropic/claude-haiku-5-5
  ```
- Claude Code: añade `model: haiku` al frontmatter de `.claude/agents/plan-worker.md` (el instalador respetará tu cambio).

## Desarrollo del kit

La fuente son `skills/` y `agents/`. Para probar sin publicar: `./install.sh --dir /ruta/al/proyecto`. Al publicar cambios, sube `version` en `.claude-plugin/plugin.json` para que la vía plugin los detecte.

Licencia: MIT.
