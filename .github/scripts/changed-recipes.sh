#!/usr/bin/env bash
set -euo pipefail

# Prints the recipes a range of commits reaches, one path per line.
#
#   changed-recipes.sh <base> <head>   recipes touched by that range
#   changed-recipes.sh all             every recipe
#
# A recipe is printed when the range touches the recipe file itself, or any
# profile or module it pulls in through `from-file`, at any depth. Anything else
# changed by the range can reach every image, so the whole list is printed then.
# A range that does not resolve (new branch, force push) prints the whole list
# too. Markdown, tests and the workflow itself are not inputs of any image, so
# they print nothing.

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repository"

all_recipes() {
    ls recipes/recipe*.yml
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

while read -r file; do
    case $file in
        ''|*.md|tests/*|.github/*) continue ;;
        recipes/*) continue ;;
        *)
            all_recipes
            exit 0
            ;;
    esac
done <<<"$changed"

# Reads the from-file includes of a profile or module; the paths they carry are
# relative to recipes/.
includes() {
    grep -oE '^[[:space:]]*- from-file: .*' "$1" 2>/dev/null | sed -E 's/.*from-file:[[:space:]]*//'
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
            printf '%s\n' "$recipe"
            break
        fi
    done < <(dependencies "$recipe")
done < <(all_recipes)
