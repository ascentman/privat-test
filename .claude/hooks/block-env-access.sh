#!/usr/bin/env bash
# Blocks Claude from reading or writing files that hold the TMDB API key.
#
# Covers the file tools and Bash alike: a deny permission rule stops Read and
# Edit, but nothing stops `cat assets/env/app.env`, which is the easier way to
# leak a secret into the transcript.
#
# `*.example` templates are deliberately allowed — they carry no secret and are
# committed, so Claude needs to be able to read and update them.
set -uo pipefail

payload=$(cat)

# Fail closed rather than open: without jq the checks below cannot run, so a
# payload that so much as mentions an env file is refused outright.
if ! command -v jq >/dev/null 2>&1; then
  if [[ "$payload" == *.env* ]]; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by the project hook: jq is not installed, so the env-file guard cannot inspect this call."}}'
  fi
  exit 0
fi

# `file_path` covers Read/Edit/Write; `path` is what Grep uses, and Grep prints
# file contents just as directly.
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')
command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')

# A path is a secret env file when its last segment ends in `.env`, or is `.env`
# itself, and it is not a `.example` template.
secret_path='(^|/)([^/]*\.)?env$|(^|/)\.env(\.[^/.]+)?$'
# Grep can be pointed at the directory rather than the file and still print
# what is inside it.
secret_dir='(^|/)assets/env/?$'
# The same, spotted inside a shell command: `.env` not followed by another
# filename character, so `app.env.example` does not match.
secret_in_command='[^[:space:]"'"'"']*\.env([^[:alnum:]._-]|$)'
# And the directory, since `cat assets/env/*` or `grep -r "" assets/env` reach
# the key without the string `.env` ever appearing.
secret_dir_in_command='(^|[^[:alnum:]_.~/-])[^[:space:]"'"'"']*assets/env([^[:alnum:]_-]|$)'
# Shell traversals that read file *contents* recursively reach the key without
# naming it or its directory at all. Unlike the Grep tool — which is ripgrep,
# and skips the key because it is git-ignored — plain `grep -r` and
# `find -exec cat` honour no such thing. Verified: in a scratch repo with the
# file ignored, `rg` finds nothing and `grep -rl` finds it.
recursive_read='(^|[;&|(][[:space:]]*|[[:space:]])(grep|egrep|fgrep)[[:space:]]+(-[[:alnum:]]*[rR]|--recursive|--dereference-recursive)|(^|[;&|(][[:space:]]*|[[:space:]])rg[[:space:]][^;&|]*(--no-ignore|-u{2,})|(^|[;&|(][[:space:]]*|[[:space:]])find[[:space:]][^;&|]*-exec[[:space:]]+(cat|grep|egrep|head|tail|less|more|awk|sed|xxd|base64)|(^|[;&|(][[:space:]]*|[[:space:]])(tar|cpio)[[:space:]]'

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

if [[ -n "$file" ]]; then
  # Match the path as given *and* as resolved: a symlink pointing at the key
  # file would otherwise sail through on its own harmless-looking name.
  resolved=$(realpath "$file" 2>/dev/null || printf '%s' "$file")
  for candidate in "$file" "$resolved"; do
    if [[ "$candidate" == *.example ]]; then
      continue
    fi
    if [[ "$candidate" =~ $secret_path || "$candidate" =~ $secret_dir ]]; then
      deny "Blocked by the project hook: $file holds (or contains) the TMDB API key. Read assets/env/app.env.example instead, and ask the user to edit the real file themselves."
    fi
  done
fi

if [[ -n "$command" ]]; then
  # Drop `.example` arguments before matching, so committing or reading the
  # template is not mistaken for touching the real thing.
  scrubbed=$(printf '%s' "$command" | sed -E 's/[^[:space:]]*\.example//g')
  [[ -z "$scrubbed" ]] && scrubbed=$command
  # Match a backslash-stripped copy too. `\grep` is the usual way to sidestep an
  # alias, and it also sidesteps a regex that expects the command name to sit on
  # a word boundary; `\c\a\t` does the same per character. Only the copy used
  # for matching is stripped — nothing here changes what would run.
  unescaped=${scrubbed//\\/}
  if [[ "$scrubbed" =~ $secret_in_command || "$scrubbed" =~ $secret_dir_in_command ||
        "$unescaped" =~ $secret_in_command || "$unescaped" =~ $secret_dir_in_command ]]; then
    deny "Blocked by the project hook: that command reaches an env file holding the TMDB API key. Use assets/env/app.env.example, and ask the user to edit the real file themselves."
  fi
  if [[ "$scrubbed" =~ $recursive_read || "$unescaped" =~ $recursive_read ]]; then
    deny "Blocked by the project hook: recursive content reads in the shell ignore .gitignore, so they reach assets/env/app.env and its API key. Use the Grep tool instead — it is ripgrep and skips ignored files — or scope the command to a single file."
  fi
fi

exit 0
