#!/usr/bin/env bash
# =============================================================================
# PreToolUse Hook: Block-Secrets Fast-Path Wrapper
# =============================================================================
#
# Wraps block-secrets.py so the Python interpreter (~30-80ms cold start) is
# only invoked when the target file path looks plausibly sensitive. Most
# Edit/Write operations target ordinary code files in non-sensitive
# directories — those exit immediately with no Python startup cost.
#
# Detection rule: extract file_path with a cheap grep+sed (avoiding `jq`),
# match it against a coarse OR-of-suspicious-patterns. Any match hands off
# to block-secrets.py for the authoritative decision (which still applies
# the SAFE_FILENAMES allowlist for .env.example, .env.template, etc.).
#
# Behavior is preserved exactly: every file Python would have blocked is
# still blocked, every file Python would have allowed is still allowed.
# Only the latency of the "obviously safe" path changes.
#
# Exit codes:
#   0 = Allow operation
#   2 = Block operation (Python emits the error message)
# =============================================================================

set -euo pipefail

INPUT=$(cat)

# Cheap JSON extract — tool_input.file_path is always a flat string.
# If the regex misses (e.g., escaped quotes), FILE_PATH stays empty and we
# fall through to Python so security is never silently skipped.
FILE_PATH=$(printf '%s' "$INPUT" \
    | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')

# No file_path detected — let Python handle whatever this is (it has its own
# fail-open error handling and may fall back on tool_input.path / .filename).
if [[ -z "$FILE_PATH" ]]; then
    exec python3 ~/.claude/hooks/block-secrets.py <<< "$INPUT"
fi

# Sensitive-extension shortlist — any of these need Python's full check
# (Python also handles the case where the extension is uppercase, etc.).
case "$FILE_PATH" in
    *.pem|*.PEM|*.key|*.KEY|*.p12|*.pfx|*.jks|*.keystore|*.crt|*.cer)
        exec python3 ~/.claude/hooks/block-secrets.py <<< "$INPUT"
        ;;
esac

# Sensitive-name / sensitive-directory patterns. Anything that hints at
# secrets or credentials hands off — Python decides definitively, including
# allow-listing .env.example, .env.template, .env.sample, .env.schema.
case "$FILE_PATH" in
    *.env|*.env.*|*/.env|*/.env.*|\
    *secret*|*Secret*|*SECRET*|\
    *credential*|*Credential*|*CREDENTIAL*|\
    *id_rsa*|*id_ed25519*|*id_ecdsa*|*id_dsa*|\
    *known_hosts*|*authorized_keys*|\
    *.npmrc|*.pypirc|*.yarnrc|\
    */.aws/*|*/.ssh/*|*/.azure/*|*/.docker/config.json|\
    *.gitconfig|*/.git/config|*.git-credentials|\
    *.pgpass|*.my.cnf|*.mongorc.js|\
    */service-account.json|*/service_account.json|*/gcloud/credentials.db)
        exec python3 ~/.claude/hooks/block-secrets.py <<< "$INPUT"
        ;;
esac

# Obviously safe — exit fast, no Python startup.
exit 0
