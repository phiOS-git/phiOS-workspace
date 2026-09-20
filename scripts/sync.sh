#!/usr/bin/env bash
# sync.sh — fast-forward `dev` for the workspace and every submodule.
#
# Run this first on any machine. It fetches every repository and
# fast-forwards the local `dev` branch to its remote, without switching
# which branch is checked out and without ever creating a merge commit. A
# branch that cannot fast-forward, or a dirty working tree, is reported and
# left alone.
#
# `dev` is the only branch these repositories use. On a fresh clone this
# also checks out any submodule that is not yet populated.

set -u
cd "$(dirname "$(readlink -f "$0")")/.."
root=$PWD

bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; grn=$'\e[32m'; yel=$'\e[33m'; rst=$'\e[0m'
rc=0

# Submodule paths, in .gitmodules order.
mapfile -t submodules < <(git config --file .gitmodules --get-regexp '\.path$' | awk '{print $2}')

# Populate any submodule a fresh clone left empty, and put it on dev rather
# than the detached HEAD `git submodule update` would otherwise leave.
for sub in "${submodules[@]}"; do
    if [ ! -e "$sub/.git" ]; then
        printf '%s\n' "${bold}=== $sub (first checkout) ===${rst}"
        git submodule update --init -- "$sub" || rc=1
        git -C "$sub" checkout dev 2>/dev/null || true
    fi
done

sync_repo() {
    local label=$1 dir=$2
    printf '%s\n' "${bold}=== $label ===${rst}"

    # A repository cloned --single-branch keeps a narrowed fetch refspec
    # (+refs/heads/main:refs/remotes/origin/main), so a plain `git fetch
    # origin` asks for that one branch by name. Since `main` and `master`
    # were deleted when `dev` became the only branch, such a clone fails
    # with "couldn't find remote ref refs/heads/main" and can never recover
    # on its own. Widen it to the wildcard first; idempotent, and reported
    # when it actually changes something.
    local want='+refs/heads/*:refs/remotes/origin/*'
    if [ "$(git -C "$dir" config --get-all remote.origin.fetch)" != "$want" ]; then
        git -C "$dir" config --replace-all remote.origin.fetch "$want"
        printf '  %swidened a single-branch fetch refspec%s\n' "$dim" "$rst"
    fi

    if ! git -C "$dir" fetch --quiet --prune --tags origin; then
        printf '  %sfetch failed%s\n' "$red" "$rst"; rc=1; return
    fi

    if ! git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/dev"; then
        printf '  %sno origin/dev%s\n' "$dim" "$rst"; echo; return
    fi

    local current dirty local_sha remote_sha
    current=$(git -C "$dir" symbolic-ref --quiet --short HEAD || echo '(detached)')
    dirty=$(git -C "$dir" status --porcelain --untracked-files=no)
    remote_sha=$(git -C "$dir" rev-parse origin/dev)
    local_sha=$(git -C "$dir" rev-parse --verify --quiet dev || echo '')

    if [ "$current" != dev ]; then
        printf '  %son %s, not dev — left alone%s\n' "$yel" "$current" "$rst"
        rc=1; echo; return
    fi

    if [ "$local_sha" = "$remote_sha" ]; then
        printf '  %sup to date%s\n' "$dim" "$rst"
    elif [ -n "$dirty" ]; then
        printf '  %sworking tree dirty — skipped%s\n' "$yel" "$rst"
        rc=1
    elif git -C "$dir" merge --ff-only --quiet origin/dev; then
        printf '  %sfast-forwarded%s\n' "$grn" "$rst"
    else
        printf '  %scannot fast-forward — resolve by hand%s\n' "$red" "$rst"
        rc=1
    fi
    echo
}

sync_repo "phiOS-workspace" "$root"
for sub in "${submodules[@]}"; do
    sync_repo "$sub" "$root/$sub"
done

exit $rc
