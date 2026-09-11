#!/usr/bin/env bash
# sync.sh — pull the latest main and dev for the workspace and every submodule.
#
# Run this first on any machine. It fetches every repository and
# fast-forwards the local `main` and `dev` branches to their remotes,
# without switching which branch is checked out and without ever creating a
# merge commit. A branch that cannot fast-forward (local commits, diverged)
# is reported and left alone.
#
#   scripts/sync.sh            fast-forward both main and dev everywhere
#   scripts/sync.sh main       only main
#   scripts/sync.sh dev        only dev
#
# On a fresh clone it also checks out any submodule that is not yet
# populated.

set -u
cd "$(dirname "$(readlink -f "$0")")/.."
root=$PWD

case "${1:-both}" in
    both) branches=(main dev) ;;
    main) branches=(main) ;;
    dev)  branches=(dev) ;;
    *) echo "usage: sync.sh [both|main|dev]" >&2; exit 2 ;;
esac

bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; grn=$'\e[32m'; yel=$'\e[33m'; rst=$'\e[0m'
rc=0

# Submodule paths, in .gitmodules order.
mapfile -t submodules < <(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}')

# Populate any submodule that a fresh clone left empty.
for sub in "${submodules[@]}"; do
    if [ ! -e "$sub/.git" ]; then
        printf '%s\n' "${bold}=== $sub (first checkout) ===${rst}"
        git submodule update --init -- "$sub" || rc=1
        git -C "$sub" checkout main 2>/dev/null || true
    fi
done

sync_repo() {
    local label=$1 dir=$2
    printf '%s\n' "${bold}=== $label ===${rst}"

    if ! git -C "$dir" fetch --quiet --prune --tags origin; then
        printf '  %sfetch failed%s\n' "$red" "$rst"; rc=1; return
    fi

    local current dirty
    current=$(git -C "$dir" symbolic-ref --quiet --short HEAD || echo '(detached)')
    dirty=$(git -C "$dir" status --porcelain --untracked-files=no)

    local b
    for b in "${branches[@]}"; do
        if ! git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$b"; then
            printf '  %s%-5s%s no origin/%s\n' "$dim" "$b" "$rst" "$b"
            continue
        fi

        local local_sha remote_sha
        remote_sha=$(git -C "$dir" rev-parse "origin/$b")
        local_sha=$(git -C "$dir" rev-parse --verify --quiet "$b" || echo '')

        if [ "$b" = "$current" ]; then
            if [ -n "$dirty" ]; then
                printf '  %s%-5s working tree dirty — skipped%s\n' "$yel" "$b" "$rst"
                rc=1; continue
            fi
            if [ "$local_sha" = "$remote_sha" ]; then
                printf '  %s%-5s up to date%s\n' "$dim" "$b" "$rst"
            elif git -C "$dir" merge --ff-only --quiet "origin/$b"; then
                printf '  %s%-5s fast-forwarded%s\n' "$grn" "$b" "$rst"
            else
                printf '  %s%-5s cannot fast-forward — resolve by hand%s\n' "$red" "$b" "$rst"
                rc=1
            fi
        else
            if [ "$local_sha" = "$remote_sha" ]; then
                printf '  %s%-5s up to date%s\n' "$dim" "$b" "$rst"
            elif git -C "$dir" fetch --quiet origin "$b:$b" 2>/dev/null; then
                printf '  %s%-5s fast-forwarded%s\n' "$grn" "$b" "$rst"
            else
                printf '  %s%-5s cannot fast-forward — check out and resolve by hand%s\n' "$red" "$b" "$rst"
                rc=1
            fi
        fi
    done
    echo
}

sync_repo "phiOS-workspace" "$root"
for sub in "${submodules[@]}"; do
    sync_repo "$sub" "$root/$sub"
done

exit $rc
