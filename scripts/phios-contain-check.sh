#!/usr/bin/env bash
#
# phiOS — containment preflight (Phase 0 of docs/external-packages-plan.md).
#
# Proves that bubblewrap containment works on THIS machine. It is deliberately
# independent of the agent: it tests the kernel and bwrap, nothing phiOS owns.
#
# Run as your normal user, on zotac and on razer. It changes nothing: no
# install, no systemctl, no writes outside a temp dir it removes.

set -uo pipefail

pass=0; fail=0
ok() { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }

# The minimal container the harness builds: /usr read-only, the Arch symlinks,
# pseudo-filesystems, and no environment at all.
base=(
	--unshare-user-try
	--ro-bind /usr /usr
	--symlink usr/bin /bin --symlink usr/bin /sbin
	--symlink usr/lib /lib --symlink usr/lib /lib64
	--proc /proc --dev /dev --tmpfs /tmp
	--clearenv --setenv PATH /usr/bin
)

echo
echo "C-01  bubblewrap present and runnable"
if command -v bwrap >/dev/null 2>&1 && bwrap --version >/dev/null 2>&1; then
	ok "$(bwrap --version)"
else
	no "bwrap missing or not runnable"
	echo; echo "STOP — install bubblewrap before anything else."; exit 1
fi

echo "C-02  unprivileged user namespaces enabled"
unpriv=1
if [[ -r /proc/sys/user/max_user_namespaces ]] \
	&& [[ "$(< /proc/sys/user/max_user_namespaces)" == 0 ]]; then unpriv=0; fi
if [[ -r /proc/sys/kernel/unprivileged_userns_clone ]] \
	&& [[ "$(< /proc/sys/kernel/unprivileged_userns_clone)" == 0 ]]; then unpriv=0; fi
if ((unpriv)); then ok "available"
else no "disabled by sysctl — T3 containment is impossible on this kernel"; fi

echo "C-03  the full namespace set the harness uses"
if bwrap "${base[@]}" \
	--unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup \
	--new-session --die-with-parent \
	-- /usr/bin/true 2>/dev/null
then ok "container starts and executes a binary"
else no "one of the namespace flags is refused by this kernel"; fi

echo "C-04  \$HOME is invisible unless explicitly bound"
if bwrap "${base[@]}" -- /usr/bin/test -d "$HOME" 2>/dev/null
then no "\$HOME WAS VISIBLE inside the container — containment is not working"
else ok "\$HOME unreachable, as required"; fi

echo "C-05  --unshare-net leaves no network at all"
if bwrap "${base[@]}" --unshare-net \
	-- /usr/bin/timeout 5 /usr/bin/curl -sS --max-time 4 https://archlinux.org \
	>/dev/null 2>&1
then no "NETWORK REACHABLE inside --unshare-net — egress control would be a lie"
else ok "no network, as required"; fi

echo "C-06  a bound unix socket still crosses the netns boundary (optional)"
if ! command -v socat >/dev/null 2>&1; then
	printf '  skip  socat not installed — only needed for proxied egress\n'
else
	d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
	socat UNIX-LISTEN:"$d/t.sock",fork EXEC:'/usr/bin/echo phios-ok' >/dev/null 2>&1 &
	sp=$!
	sleep 0.4
	got=$(bwrap "${base[@]}" --unshare-net --bind "$d" /run/br \
		-- /usr/bin/timeout 5 /usr/bin/socat -T3 - UNIX-CONNECT:/run/br/t.sock 2>/dev/null)
	kill "$sp" 2>/dev/null
	if [[ $got == *phios-ok* ]]
	then ok "socket bridge works — the proxied-egress shape is viable"
	else no "socket bridge did not return (re-run once; a slow listener can race)"; fi
fi

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
if ((fail)); then
	echo "Containment is NOT proven on this machine. Send me the output above."
	exit 1
fi
echo "Containment proven. Phase 1 can proceed."
