#!/usr/bin/env bash
# Instala o actualiza el kit init-agent en un proyecto. Idempotente: volver a ejecutarlo actualiza.
#
#   curl -fsSL https://raw.githubusercontent.com/Brunvelop/init-agent/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Brunvelop/init-agent/main/install.sh | bash -s -- --claude
#
# Opciones:
#   --dir DIR    proyecto destino (por defecto, el directorio actual)
#   --ref REF    rama o tag del kit (por defecto, main)
#   --claude     instala también en .claude/ (automático si el proyecto ya tiene .claude/)
#   --force      sobrescribe ficheros del kit modificados localmente
#
# Variables: INIT_AGENT_REPO (URL git del kit), INIT_AGENT_SRC (checkout local, en vez de clonar).
#
# Destinos:  skills/<s>/**  -> .agents/skills/<s>/**   (+ .claude/skills/<s>/**)
#            agents/<a>.md  -> .omp/agents/<a>.md      (+ .claude/agents/<a>.md)
# Estado:    .agents/init-agent.lock (commit instalado + sha256 de cada fichero, formato sha256sum).
#            Un fichero cuyo contenido ya no coincide con el lock es tuyo: no se toca sin --force.
set -euo pipefail

REPO="${INIT_AGENT_REPO:-https://github.com/Brunvelop/init-agent.git}"
REF="main"
TARGET="$PWD"
FORCE=0
CLAUDE=0

while [ $# -gt 0 ]; do
	case "$1" in
	--dir) TARGET="${2:?--dir necesita un directorio}"; shift 2 ;;
	--ref) REF="${2:?--ref necesita una rama o tag}"; shift 2 ;;
	--claude) CLAUDE=1; shift ;;
	--force) FORCE=1; shift ;;
	-h | --help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
	*) echo "Opción desconocida: $1" >&2; exit 2 ;;
	esac
done

[ -d "$TARGET" ] || { echo "No existe el directorio destino: $TARGET" >&2; exit 2; }
TARGET="$(cd "$TARGET" && pwd)"
[ -d "$TARGET/.claude" ] && CLAUDE=1

if command -v sha256sum >/dev/null 2>&1; then
	sha() { sha256sum "$1" | cut -d' ' -f1; }
else
	sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

# --- origen: INIT_AGENT_SRC, el checkout que contiene este script, o un clon temporal ---
TMP=""
trap '[ -n "$TMP" ] && rm -rf "$TMP"' EXIT
SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
	SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "${INIT_AGENT_SRC:-}" ]; then
	SRC="$(cd "$INIT_AGENT_SRC" && pwd)"
elif [ -n "$SELF_DIR" ] && [ -d "$SELF_DIR/skills" ] && [ -d "$SELF_DIR/agents" ]; then
	SRC="$SELF_DIR"
else
	command -v git >/dev/null 2>&1 || { echo "Hace falta git para descargar el kit." >&2; exit 1; }
	TMP="$(mktemp -d)"
	git clone --quiet --depth 1 --branch "$REF" "$REPO" "$TMP/kit"
	SRC="$TMP/kit"
fi
[ -d "$SRC/skills" ] && [ -d "$SRC/agents" ] || { echo "Origen sin skills/ y agents/: $SRC" >&2; exit 1; }
[ "$SRC" != "$TARGET" ] || { echo "El destino es el propio kit; usa --dir <proyecto>." >&2; exit 2; }
COMMIT="$(git -C "$SRC" rev-parse --verify -q HEAD 2>/dev/null)" || COMMIT="local"
LOCK="$TARGET/.agents/init-agent.lock"
[ -n "$TMP" ] || TMP="$(mktemp -d)"
OLD_LOCK="$TMP/old.lock"
NEW_LOCK="$TMP/new.lock"
if [ -f "$LOCK" ]; then cp "$LOCK" "$OLD_LOCK"; else : >"$OLD_LOCK"; fi
: >"$NEW_LOCK"

old_hash() { awk -v p="$1" '!/^#/ && $2 == p { print $1; exit }' "$OLD_LOCK"; }

n_new=0 n_upd=0 n_same=0 n_skip=0 n_del=0

# place <fichero origen> <ruta destino relativa al proyecto>
place() {
	local src="$1" rel="$2" dest="$TARGET/$2" new cur old
	new="$(sha "$src")"
	if [ -f "$dest" ]; then
		cur="$(sha "$dest")"
		old="$(old_hash "$rel")"
		if [ "$cur" = "$new" ]; then
			n_same=$((n_same + 1))
		elif [ "$cur" = "$old" ] || [ "$FORCE" = 1 ]; then
			cp "$src" "$dest"
			n_upd=$((n_upd + 1))
			echo "  actualizado  $rel"
		else
			n_skip=$((n_skip + 1))
			echo "  CONSERVADO   $rel (modificado localmente; --force para sobrescribir)"
			[ -z "$old" ] || echo "$old  $rel" >>"$NEW_LOCK"
			return 0
		fi
	else
		mkdir -p "$(dirname "$dest")"
		cp "$src" "$dest"
		n_new=$((n_new + 1))
		echo "  nuevo        $rel"
	fi
	echo "$new  $rel" >>"$NEW_LOCK"
}

echo "init-agent @ ${COMMIT:0:12} -> $TARGET"

while IFS= read -r f; do
	rel="${f#"$SRC"/skills/}"
	place "$f" ".agents/skills/$rel"
	[ "$CLAUDE" = 0 ] || place "$f" ".claude/skills/$rel"
done < <(find "$SRC/skills" -type f ! -name '*.pyc' | LC_ALL=C sort)

while IFS= read -r f; do
	rel="${f#"$SRC"/agents/}"
	place "$f" ".omp/agents/$rel"
	[ "$CLAUDE" = 0 ] || place "$f" ".claude/agents/$rel"
done < <(find "$SRC/agents" -type f -name '*.md' | LC_ALL=C sort)

# Ficheros que el kit ya no trae: se borran solo si siguen intactos.
while read -r old rel; do
	case "$old" in '' | '#'*) continue ;; esac
	awk -v p="$rel" '$2 == p { found = 1 } END { exit !found }' "$NEW_LOCK" && continue
	[ -f "$TARGET/$rel" ] || continue
	if [ "$(sha "$TARGET/$rel")" = "$old" ] || [ "$FORCE" = 1 ]; then
		rm "$TARGET/$rel"
		rmdir -p "$(dirname "$TARGET/$rel")" 2>/dev/null || true
		n_del=$((n_del + 1))
		echo "  eliminado    $rel"
	else
		echo "  CONSERVADO   $rel (ya no está en el kit, pero lo modificaste)"
	fi
done <"$OLD_LOCK"

mkdir -p "$TARGET/.agents"
{
	echo "# init-agent $REPO $REF $COMMIT"
	LC_ALL=C sort -k2 "$NEW_LOCK"
} >"$LOCK"

echo "Hecho: $n_new nuevos, $n_upd actualizados, $n_same sin cambios, $n_skip conservados, $n_del eliminados."
echo "Commitea .agents/ .omp/$([ "$CLAUDE" = 0 ] || echo ' .claude/') en tu proyecto. Para actualizar, vuelve a ejecutar este script."
