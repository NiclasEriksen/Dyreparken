#!/usr/bin/env bash
# Checks that need no game client. Run from anywhere:
#   tools/check.sh           everything, with coverage floors (CI runs this)
#   tools/check.sh --quick   tests without coverage (a few seconds)
#  1. Every file in the TOC exists, and every addon .lua is listed in the TOC.
#  2. Lua 5.1 syntax (luajit parses 5.1; it also accepts goto, so we grep for that).
#  3. Constructs WoW's Lua 5.1 lacks: goto/labels, //, bitwise operators.
#  4. tools/test/run.lua: the test suite (simulated clients, see tools/test/harness.lua).
#     Coverage floors: Menagerie 95%, Core 90%. Games has none on purpose (see CLAUDE.md).
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
done < <(find . -name '*.lua' -not -path './Libs/*' -not -path './tools/*')

own=$(find . -name '*.lua' -not -path './Libs/*' -not -path './tools/*')
for f in $own; do
    out=$(luajit -e "local f, e = loadfile('$f'); if not f then io.stderr:write(e, '\n'); os.exit(1) end" 2>&1) \
        || { echo "SYNTAX: $out"; fail=1; }
done
# Strip comments and strings roughly, then look for 5.2+ syntax.
for f in $own; do
    hits=$(sed -E 's/--.*$//; s/"([^"\\]|\\.)*"//g; s/'"'"'([^'"'"'\\]|\\.)*'"'"'//g' "$f" \
        | grep -nE '\bgoto\b|::[A-Za-z_]+::|//|[^~<>=]~[^=]|<<|>>|[^&]&[^&]|\|' \
        | sed "s#^#LUA51: $f:#")
    [[ -n "$hits" ]] && { echo "$hits"; fail=1; }
done

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
