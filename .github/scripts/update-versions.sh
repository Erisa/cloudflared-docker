#!/usr/bin/env bash
# Updates docker-bake.hcl to the latest cloudflared release, and Go to the
# newest golang alpine image that can build it. Results are printed as
# key=value lines, and also written to $GITHUB_OUTPUT when running in Actions.
#
# Set TARGET_VERSION to update to a specific release instead of the latest.
# Needs an authenticated gh, curl, jq and docker buildx.
set -euo pipefail

cd "$(dirname "$0")/../.."

version_re='^[0-9]{4}\.[0-9]+\.[0-9]+$'
go_re='^[0-9]+\.[0-9]+(\.[0-9]+)?$'

# Bake variables can be overridden from the environment, so make sure none are
bake_args() {
	env -u CLOUDFLARED_VERSION -u GOVERSION -u ALPINEVERSION \
		docker buildx bake --print --progress=quiet default | jq -c '.target.default.args'
}

max_version() { printf '%s\n' "$@" | sort -V | tail -n1; }

minor() { cut -d. -f1,2 <<<"$1"; }

set_bake_var() {
	sed -i -E "/^variable \"$1\" \{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$2\"/" docker-bake.hcl
}

output() {
	echo "$1=$2"
	if [ -n "${GITHUB_OUTPUT:-}" ]; then
		echo "$1=$2" >>"$GITHUB_OUTPUT"
	fi
}

args=$(bake_args)
old_version=$(jq -r .VERSION <<<"$args")
old_go=$(jq -r .GOVERSION <<<"$args")
alpine=$(jq -r .ALPINEVERSION <<<"$args")

new_version=${TARGET_VERSION:-$(gh api repos/cloudflare/cloudflared/releases/latest --jq .tag_name)}
if ! [[ $new_version =~ $version_re ]]; then
	echo "Unexpected cloudflared version: $new_version" >&2
	exit 1
fi

if [ "$new_version" = "$old_version" ]; then
	echo "Already at cloudflared $old_version"
	output changed false
	exit 0
fi
if [ -z "${TARGET_VERSION:-}" ] && [ "$(max_version "$old_version" "$new_version")" = "$old_version" ]; then
	echo "Latest release $new_version is older than $old_version, not downgrading"
	output changed false
	exit 0
fi

# The go and toolchain lines in go.mod are the oldest Go that can build this
# release. golang images set GOTOOLCHAIN=local, so they won't fetch a newer one.
go_mod=$(gh api -H 'Accept: application/vnd.github.raw' "repos/cloudflare/cloudflared/contents/go.mod?ref=$new_version")
mapfile -t required < <(awk '$1 == "go" || $1 == "toolchain" { sub(/^go/, "", $2); print $2 }' <<<"$go_mod" | grep -E "$go_re")
if [ "${#required[@]}" -eq 0 ]; then
	echo "Couldn't find a Go version in cloudflared $new_version's go.mod" >&2
	exit 1
fi
required_go=$(max_version "${required[@]}")
go_minor=$(max_version "$(minor "$old_go")" "$(minor "$required_go")")

# Images are published a while after Go releases, so use what's on Docker Hub
tags=
url="https://hub.docker.com/v2/namespaces/library/repositories/golang/tags?name=-alpine$alpine&page_size=100"
while [ "$url" != null ]; do
	page=$(curl -fsS --retry 3 "$url")
	tags+=$(jq -r '.results[].name' <<<"$page")$'\n'
	url=$(jq -r .next <<<"$page")
done
mapfile -t candidates < <(sed -n -E "s/^(${go_minor//./\\.}\.[0-9]+)-alpine${alpine//./\\.}\$/\1/p" <<<"$tags")
if [ "${#candidates[@]}" -eq 0 ]; then
	echo "No golang:$go_minor.x-alpine$alpine image exists yet, ALPINEVERSION may need bumping" >&2
	exit 1
fi
new_go=$(max_version "${candidates[@]}" "$old_go")
if [ "$(max_version "$new_go" "$required_go")" != "$new_go" ]; then
	echo "cloudflared $new_version needs Go $required_go, but the newest golang:$go_minor.x-alpine$alpine is $new_go" >&2
	exit 1
fi

set_bake_var CLOUDFLARED_VERSION "$new_version"
set_bake_var GOVERSION "$new_go"
# Builds without bake use the Dockerfile's default, so keep it on the same minor
sed -i -E "s/^ARG GOVERSION=.*/ARG GOVERSION=$(minor "$new_go")/" Dockerfile

args=$(bake_args)
if [ "$(jq -r .VERSION <<<"$args")" != "$new_version" ] || [ "$(jq -r .GOVERSION <<<"$args")" != "$new_go" ]; then
	echo "docker-bake.hcl didn't update as expected: $args" >&2
	exit 1
fi

title="Upgrade cloudflared to $new_version"
if [ "$new_go" != "$old_go" ]; then
	title+=", Go to $new_go"
fi

output changed true
output old_version "$old_version"
output version "$new_version"
output old_go "$old_go"
output go "$new_go"
output title "$title"
