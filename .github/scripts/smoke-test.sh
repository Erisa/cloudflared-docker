#!/usr/bin/env bash
# Usage: smoke-test.sh IMAGE [EXPECTED_VERSION]
#
# Runs IMAGE as a quick tunnel to cloudflared's built-in hello world server and
# requests it several times through trycloudflare.com, the same check that's
# done by hand before releasing a new version.
#
# Set PLATFORM to run an image for another architecture under QEMU, and
# QEMU_CPU to choose which CPU QEMU emulates.
set -euo pipefail

image=$1
expected=${2:-}
requests=${REQUESTS:-5}
name=cloudflared-smoke-test-$$
url=

# Without an init, a crash under QEMU leaves it hung as PID 1 instead of exiting
run_args=(--init)
if [ -n "${PLATFORM:-}" ]; then
	run_args+=(--platform "$PLATFORM")
fi
if [ -n "${QEMU_CPU:-}" ]; then
	run_args+=(-e "QEMU_CPU=$QEMU_CPU")
fi

trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

fail() {
	echo "::error::$*"
	echo "--- cloudflared logs"
	docker logs "$name" 2>&1 || true
	exit 1
}

running() { [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" = true ]; }

start_tunnel() {
	local logs
	docker rm -f "$name" >/dev/null 2>&1 || true
	docker run -d --name "$name" "${run_args[@]}" "$image" --hello-world >/dev/null
	for _ in $(seq 60); do
		logs=$(docker logs "$name" 2>&1)
		url=$(sed -n -E 's/.*\|[[:space:]]+(https:\/\/[a-z0-9-]+\.trycloudflare\.com).*/\1/p' <<<"$logs" | tail -n1)
		if [ -n "$url" ] && grep -q 'Registered tunnel connection' <<<"$logs"; then
			return 0
		fi
		running || break
		sleep 1
	done
	echo "$logs" | tail -n 20
	return 1
}

# Resolve over DoH at first, so a lookup made before the record existed isn't
# cached. Lookups of new hostnames are flaky, so once one works, reuse its IP.
resolve=(--doh-url https://1.1.1.1/dns-query)

request() {
	local out ip
	out=$(curl -fsS --max-time 15 "${resolve[@]}" -w '\n%{remote_ip}' "$url") || return 1
	ip=${out##*$'\n'}
	if [[ $ip == *:* ]]; then
		ip="[$ip]"
	fi
	resolve=(--resolve "${url#https://}:443:$ip")
	grep -q 'Congrats! You created a tunnel!' <<<"$out"
}

if [ -n "$expected" ]; then
	if ! version=$(docker run --rm "${run_args[@]}" "$image" version 2>&1); then
		echo "$version"
		echo "::error::cloudflared crashed"
		exit 1
	fi
	echo "$version"
	if [[ $version != *"cloudflared version $expected "* ]]; then
		echo "::error::Expected cloudflared version $expected"
		exit 1
	fi
fi

# Quick tunnels are best effort, so give creating one a few tries
for attempt in 1 2 3; do
	start_tunnel && break
	echo "Couldn't start a quick tunnel (attempt $attempt)"
	if [ "$attempt" -eq 3 ]; then
		fail "Couldn't start a quick tunnel"
	fi
	sleep $((attempt * 10))
done
echo "Tunnel up at $url"

# New hostnames can take a moment to resolve, but once one request gets
# through, the rest all have to as well
deadline=$((SECONDS + 90))
until request; do
	[ "$SECONDS" -lt "$deadline" ] || fail "$url never became reachable"
	sleep 3
done
echo "Request 1/$requests OK"
for i in $(seq 2 "$requests"); do
	request || fail "Request $i/$requests to $url failed"
	echo "Request $i/$requests OK"
done

running || fail "cloudflared exited during the test"
echo "Smoke test passed"
