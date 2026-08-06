#!/usr/bin/env bash
set -euo pipefail

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper_directory=$(mktemp -d)
switch_temp_directory=$(mktemp -d /var/tmp/bluebuild-switch.XXXXXXXXXX)

cleanup() {
    status=$?
    rm -rf -- "$helper_directory" "$switch_temp_directory" 2>/dev/null || true
    if [[ -e "$helper_directory" || -e "$switch_temp_directory" ]]; then
        /usr/bin/pkexec /usr/bin/rm -rf -- "$helper_directory" "$switch_temp_directory" || true
    fi
    exit "$status"
}

trap cleanup EXIT

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

cat >"$helper_directory/podman" <<'EOF'
#!/usr/bin/env bash

case "${1:-}" in
    image)
        if [[ "${2:-}" == rm ]]; then
            shift 2
            exec /usr/bin/podman image rm --force "$@"
        fi
        ;;
    rmi)
        shift
        exec /usr/bin/podman rmi --force "$@"
        ;;
esac

exec /usr/bin/podman "$@"
EOF
chmod 700 "$helper_directory/podman"

recipe="$repository/recipes/recipe.yml"
build_driver=podman
inspect_driver=podman
run_driver=podman
temp_directory="$switch_temp_directory"

for argument in "$@"; do
    case "$argument" in
        -B|--build-driver|--build-driver=*) build_driver= ;;
        -I|--inspect-driver|--inspect-driver=*) inspect_driver= ;;
        -R|--run-driver|--run-driver=*) run_driver= ;;
        --tempdir|--tempdir=*) temp_directory= ;;
    esac
done

[[ -z "$build_driver" ]] || set -- --build-driver "$build_driver" "$@"
[[ -z "$inspect_driver" ]] || set -- --inspect-driver "$inspect_driver" "$@"
[[ -z "$run_driver" ]] || set -- --run-driver "$run_driver" "$@"
[[ -z "$temp_directory" ]] || set -- --tempdir "$temp_directory" "$@"

attempt=1
while ((attempt <= 3)); do
    log="$helper_directory/bluebuild.log"
    : >"$log"

    if PATH="$helper_directory:$PATH" "$bluebuild" switch "$@" "$recipe" 2>&1 | tee "$log"; then
        exit 0
    else
        status=${PIPESTATUS[0]}
    fi

    blocker=$(grep -aoE 'image used by [0-9a-f]{64}' "$log" | tail -1 | awk '{print $4}' || true)
    if [[ -z "$blocker" || $attempt -eq 3 ]]; then
        exit "$status"
    fi

    podman rm --force --storage "$blocker"
    printf 'Retrying after removing stale BlueBuild container %s\n' "$blocker" >&2
    attempt=$((attempt + 1))
done

exit "$status"
