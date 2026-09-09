#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

migration="$ROOT/migrations/1788960568.sh"
[[ -f $migration ]] || fail "omarchy-vm skill migration exists"

skills_dirs=(.agents/skills .claude/skills .codex/skills .pi/agent/skills .gemini/config/skills .hermes/skills)

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
home="$test_dir/home"

run_migration() {
  HOME="$home" OMARCHY_PATH="$ROOT" bash -euo pipefail "$migration" >/dev/null ||
    fail "migration exits clean"
}

assert_link() {
  local link="$1" description="$2"

  [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/omarchy-vm" ]] ||
    fail "$description" "$link -> $(readlink "$link" 2>/dev/null || echo missing)"
}

# ------------------------------------------------------------------ fresh home

rm -rf "$home"
mkdir -p "$home"
run_migration

for skills_dir in "${skills_dirs[@]}"; do
  assert_link "$home/$skills_dir/omarchy-vm" "migration links the skill into $skills_dir"
done
pass "migration links the skill into every agent skills directory"

# ------------------------------------------------------------------ run twice

run_migration
for skills_dir in "${skills_dirs[@]}"; do
  assert_link "$home/$skills_dir/omarchy-vm" "migration is idempotent for $skills_dir"
done
pass "migration is idempotent"

# ------------------------------------------------------------------ existing unrelated skill

rm -rf "$home"
mkdir -p "$home/.claude/skills"
ln -s /nonexistent "$home/.claude/skills/vm"
run_migration

[[ $(readlink "$home/.claude/skills/vm") == "/nonexistent" ]] ||
  fail "migration leaves an unrelated skill alone" "vm -> $(readlink "$home/.claude/skills/vm")"
assert_link "$home/.claude/skills/omarchy-vm" "migration still links its own skill"
pass "migration leaves unrelated skills alone"

# ------------------------------------------------------------------ missing skill source

rm -rf "$home"
mkdir -p "$home" "$test_dir/empty-omarchy"
HOME="$home" OMARCHY_PATH="$test_dir/empty-omarchy" bash -euo pipefail "$migration" >/dev/null ||
  fail "migration exits clean when the skill source is missing"
[[ -e $home/.claude ]] && fail "migration no-ops when the skill source is missing"
pass "migration no-ops when the skill source is missing"
