#!/usr/bin/env bash
set -euo pipefail

notary_profile="${NOTARY_PROFILE:-notarytool-password}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

cd "$repo_root"

exec "$script_dir/release.sh" next \
    --notary-profile "$notary_profile" \
    --github \
    "$@"
