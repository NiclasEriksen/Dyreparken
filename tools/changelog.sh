#!/usr/bin/env bash
# The changelog players read on CurseForge and GitHub, as the release workflow writes it (2026-11-19: it lived
# inline in .github/workflows/release.yml, so what players would read was seen only after the tag was public):
#   tools/changelog.sh                 HEAD since the newest tag: a preview before tagging
#   tools/changelog.sh v0.9.0          that tag since the one before it (release.yml runs this)
#   tools/changelog.sh v0.9.0 v0.8.2   from a given tag
# One line per commit subject (they're written for players), without the developer-only ones (Tests:,
# Tidy-up:, Notes:, Docs:, Developer probe), a subject's {{...}} as ***** and .github/changelog-fix.txt's
# rewordings (a pushed subject that gave a secret away), the Claude credit once at the top.
#
# Secrets (CLAUDE.md, Releasing): to stderr, a warning for each line that names an easter egg's id, a hidden
# achievement's id or name, or says "egg", "hidden" or "secret". A warning only: some egg ids are everyday
# words (jul, bom), so read them and judge.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:-HEAD}"
if [[ $# -ge 2 ]]; then
    prev="$2"
else
    prev=$(git describe --tags --abbrev=0 "${tag}^" 2>/dev/null || true)
fi
title="$tag"
[[ $tag == HEAD ]] && title="(unreleased, since ${prev:-the start})"

lines=$(git log --no-merges --format='%H %s' ${prev:+"$prev.."}"$tag" \
    | while read -r sha subject; do
        fix=$(grep -m1 "^$sha " .github/changelog-fix.txt 2>/dev/null | cut -d' ' -f2- || true)
        echo "- ${fix:-$subject}"
    done \
    | grep -vE '^- (Tests|Tidy-up|Notes|Docs|Developer probe)\b' \
    | sed -E 's/\{\{[^}]*\}\}/*****/g' || true)

echo "# Dyreparken ${title}"
echo
echo "_Developed with the help of Claude (Anthropic)._"
echo
echo "${lines:-- Small fixes and polish.}"

# The secrets' words: egg ids (Quirks.EGGS), hidden achievements' ids and names (Defs.lua `secret`, nb.lua).
# (luajit reads them; without it, as on the release runner, no warnings: they're for before the tag)
command -v luajit >/dev/null || exit 0
words=$(luajit -e '
local out = {}
local q = io.open("Menagerie/Quirks.lua"):read("*a")
local eggs = q:match("Quirks%.EGGS = (%b{})") or ""
for id in eggs:gmatch("{ id = \"([%w_]+)\"") do out[#out + 1] = id end
local defs = io.open("Achievements/Defs.lua"):read("*a")
local nb = io.open("Locale/nb.lua"):read("*a")
for line in defs:gmatch("[^\n]+") do
    local id = line:match("id = \"([^\"]+)\"")
    if id and line:find("secret = true", 1, true) then
        out[#out + 1] = id
        local name = nb:match("%[\"" .. id:gsub("%p", "%%%0") .. "\"%] = { name = \"([^\"]+)\"")
        if name then out[#out + 1] = name end
    end
end
for _, w in ipairs({ "egg", "eggs", "påskeegg", "hidden", "secret", "hemmelig" }) do out[#out + 1] = w end
print(table.concat(out, "\n"))')
warned=0
while IFS= read -r line; do
    lower=${line,,}
    while IFS= read -r w; do
        [[ -z $w ]] && continue
        if grep -qiwF -- "$w" <<<"$lower"; then
            echo "SECRET? \"$w\" in: $line" >&2
            warned=1
        fi
    done <<<"$words"
done <<<"$lines"
[[ $warned -eq 1 ]] && echo "(warnings only: wrap a giveaway in {{...}}, or reword a pushed one in .github/changelog-fix.txt)" >&2
exit 0
