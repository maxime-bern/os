#!/usr/bin/env bash
set -euo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper_directory=$(mktemp -d)
trap 'rm -rf -- "$helper_directory"' EXIT

if [[ -n "${BLUEBUILD_BIN:-}" ]]; then
    bluebuild=$BLUEBUILD_BIN
elif [[ -x /usr/bin/bluebuild ]]; then
    bluebuild=/usr/bin/bluebuild
else
    bluebuild=$(command -v bluebuild || true)
fi

if [[ -z "$bluebuild" || ! -x "$bluebuild" ]]; then
    printf 'bluebuild is not installed\n' >&2
    exit 1
fi

if [[ ! -x /usr/bin/pkexec ]]; then
    printf 'pkexec is not installed\n' >&2
    exit 1
fi

cat >"$helper_directory/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

while (($#)); do
    case "$1" in
        -A|--preserve-env|--preserve-env=*)
            shift
            ;;
        -p|--prompt)
            shift
            (($#)) || exit 2
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

(($#)) || exit 2
directory=$PWD
exec /usr/bin/pkexec /bin/bash -c 'cd -- "$1" && shift && exec "$@"' bluebuild-switch "$directory" "$@"
EOF
chmod 700 "$helper_directory/sudo"

PATH="$helper_directory:$PATH" "$bluebuild" switch "$@" "$repository/recipes/recipe.yml"
