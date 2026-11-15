#!/usr/bin/env bash
# Checks that need no game client. Run from anywhere:
#   tools/check.sh           everything, with coverage floors (CI runs this)
#   tools/check.sh --quick   tests without coverage (a few seconds)
#  1. Every file in the TOC exists, and every addon .lua is listed in the TOC.
#  2. Lua 5.1 syntax (luajit parses 5.1; it also accepts goto, so we grep for that).
#  3. Constructs WoW's Lua 5.1 lacks: goto/labels, //, bitwise operators.
#  4. No read of a lowercase global but the known ones (Lua's and the client's): a misspelt or out-of-order local
#     reads as nil there, silently (2026-11-15: Parken's rings read `match` before it was declared).
#  5. luacheck (2026-11-15), its config built from the harness's stubs (tools/lint_config.lua): writes to
#     globals, reads of globals and C_* fields the stubs lack (GetZonetext, C_PetJournal.GetPetInfoBySpeciesId).
#  6. tools/test/run.lua: the test suite (simulated clients, see tools/test/harness.lua).
#     Coverage floors: Menagerie 95%, Achievements 95%, Core 90%. Games has none on purpose (see CLAUDE.md).
set -u
quick=0
[[ "${1:-}" == "--quick" ]] && quick=1
cd "$(dirname "$0")/.."
fail=0
toc=Dyreparken.toc

mapfile -t listed < <(grep -vE '^\s*(#|$)' "$toc" | tr -d '\r' | sed 's#\\#/#g')
for f in "${listed[@]}"; do
    [[ -f "$f" ]] || { echo "TOC: missing file $f"; fail=1; }
done
while IFS= read -r f; do
    f=${f#./}
    printf '%s\n' "${listed[@]}" | grep -qxF "$f" || { echo "TOC: $f not listed"; fail=1; }
done < <(find . -name '*.lua' -not -path './Libs/*' -not -path './tools/*' -not -path './.claude/*')

own=$(find . -name '*.lua' -not -path './Libs/*' -not -path './tools/*' -not -path './.claude/*')
# One luajit for every file (a process per file was most of this step's time).
out=$(luajit -e "local bad = false
for _, f in ipairs(arg) do
    local ok, e = loadfile(f)
    if not ok then io.stderr:write('SYNTAX: ', e, '\n'); bad = true end
end
os.exit(bad and 1 or 0)" $own 2>&1) || { echo "$out"; fail=1; }
# Strip comments and strings roughly, then look for 5.2+ syntax.
for f in $own; do
    hits=$(sed -E 's/--.*$//; s/"([^"\\]|\\.)*"//g; s/'"'"'([^'"'"'\\]|\\.)*'"'"'//g' "$f" \
        | grep -nE '\bgoto\b|::[A-Za-z_]+::|//|[^~<>=]~[^=]|<<|>>|[^&]&[^&]|\|' \
        | sed "s#^#LUA51: $f:#")
    [[ -n "$hits" ]] && { echo "$hits"; fail=1; }
done

# The lowercase globals the addon may read (Lua 5.1's, and the client's own lowercase functions).
known=" ipairs pairs tostring tonumber type math table string pcall error assert select next unpack rawget rawset
 setmetatable getmetatable _G date time hooksecurefunc geterrorhandler seterrorhandler debugstack issecretvalue
 issecrettable debugprofilestop wipe strtrim strsplit format tinsert tremove "
known=" $(echo $known) " # (one line: the list's line breaks as spaces)
for f in $own; do
    [[ $f == ./tools/* ]] && continue
    while IFS= read -r g; do
        [[ $known == *" $g "* ]] || { echo "GLOBAL: $f reads \"$g\" (a misspelt or undeclared local? else add it to check.sh's known)"; fail=1; }
    done < <(luajit -bl "$f" 2>/dev/null | grep 'GGET' | grep -o '"[a-z_][A-Za-z0-9_]*"$' | tr -d '"' | sort -u)
done

if command -v luacheck >/dev/null; then
    rc=$(mktemp); trap 'rm -f "$rc"' EXIT
    if luajit tools/lint_config.lua > "$rc"; then
        out=$(luacheck --config "$rc" --formatter plain --codes --quiet . 2>&1) || { echo "$out" | sed 's/^/LINT: /'; fail=1; }
    else
        echo "LINT: tools/lint_config.lua failed"; fail=1
    fi
else
    echo "LINT: luacheck not installed (Arch: pacman -S luacheck; Debian/Ubuntu: apt install lua-check)"; fail=1
fi

if [[ $fail -eq 0 ]]; then
    if [[ $quick -eq 1 ]]; then
        out=$(luajit tools/test/run.lua 2>&1) || { echo "$out" | tail -60; fail=1; }
    else
        out=$(luajit tools/test/run.lua --min=Menagerie/=95 --min=Achievements/=95 --min=Core/=90 2>&1) \
            || { echo "$out" | tail -60; fail=1; }
    fi
    [[ $fail -eq 0 ]] && echo "$out" | tail -1
fi
[[ $fail -eq 0 ]] && echo "OK" || exit 1
