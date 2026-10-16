#!/usr/bin/env bash
set -euo pipefail

# Prints the recipes a range of commits reaches, one name per line, as the
# bluebuild action wants them: relative to the recipes/ directory.
#
#   changed-recipes.sh <base> <head>   recipes touched by that range
#   changed-recipes.sh all             every recipe
#
# A recipe is printed when the range touches the recipe file itself, or any
# profile or module it pulls in through `from-file`, at any depth, or any file
# under files/ that one of those modules reads. A recipe is not printed when the
# range only reaches a module nothing includes, or a files/ entry nothing names.
# Markdown, the tests and the workflow itself are inputs of no image.
#
# A range that does not resolve (new branch, force push) prints every recipe.

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repository"

recipe_paths() {
    local recipe
    for recipe in recipes/recipe*.yml; do
        printf '%s\n' "$recipe"
    done
}

# The same list, as the action wants it.
all_recipes() {
    local recipe
    for recipe in $(recipe_paths); do
        printf '%s\n' "${recipe#recipes/}"
    done
}

if [[ ${1:-all} == all ]]; then
    all_recipes
    exit 0
fi

base=$1
head=$2

if ! git cat-file -e "$base^{commit}" 2>/dev/null || ! git cat-file -e "$head^{commit}" 2>/dev/null; then
    all_recipes
    exit 0
fi

changed=$(git diff --name-only "$base" "$head")

# Anything outside recipes/ can reach every recipe, except the files/ entries
# resolved against the modules further down, markdown and the CI plumbing.
inputs=()
while read -r file; do
    case $file in
        ''|*.md|tests/*|.github/*) continue ;;
        recipes/*) continue ;;
        files/*) inputs+=("${file#files/}") ;;
        *)
            all_recipes
            exit 0
            ;;
    esac
done <<<"$changed"

# Reads the from-file includes of a profile or a module; they carry paths
# relative to recipes/.
includes() {
    grep -oE '^[[:space:]]*- from-file: .*' "$1" 2>/dev/null | sed -E 's/.*from-file:[[:space:]]*//'
}

# Whether a module reads one of the changed files/ entries. A module names its
# inputs: a source: for the files module, which is a path or the directory
# holding it, and otherwise the name of the file itself, be it the .repo of a
# dnf module, the script of a script module or the unit of a systemd module.
reads() {
    local module=$1 path name
    for path in "${inputs[@]}"; do
        name=${path##*/}
        awk -v path="$path" '
            /^[[:space:]]*(- )?source:/ {
                sub(/^.*source:[[:space:]]*/, "")
                if ($0 == path || index(path, $0 "/") == 1) found = 1
            }
            END { exit !found }
        ' "$module" && return 0
        grep -qF "$name" "$module" && return 0
    done
    return 1
}

# Every file a recipe reaches, itself included.
dependencies() {
    local queue=("$1") file include seen=''
    while ((${#queue[@]})); do
        file=${queue[0]}
        queue=("${queue[@]:1}")
        [[ " $seen " == *" $file "* ]] && continue
        seen+=" $file"
        while read -r include; do
            [[ -n $include ]] && queue+=("recipes/$include")
        done < <(includes "$file")
    done
    printf '%s\n' $seen
}

while read -r recipe; do
    while read -r file; do
        if grep -qxF "$file" <<<"$changed"; then
            printf '%s\n' "${recipe#recipes/}"
            break
        fi
        if [[ $file == recipes/modules/* && ${#inputs[@]} -gt 0 ]] && reads "$file"; then
            printf '%s\n' "${recipe#recipes/}"
            break
        fi
    done < <(dependencies "$recipe")
done < <(recipe_paths)
