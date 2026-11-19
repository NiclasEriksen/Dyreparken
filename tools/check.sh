#!/usr/bin/env bash
# Checks that need no game client. Run from anywhere:
#   tools/check.sh           everything, with coverage floors (CI runs this)
#   tools/check.sh --quick   tests without coverage (a few seconds)
#  1. Every file in the TOC exists, and every addon .lua is listed in the TOC.
#  2. Lua 5.1 syntax (luajit parses 5.1; it also accepts goto, so we grep for that).
#  3. Constructs WoW's Lua 5.1 lacks: goto/labels, //, bitwise operators.
#  4. (A bytecode scan for reads of unknown lowercase globals went 2026-11-19: luacheck's W113 reports the same, a
#     misspelt or out-of-order local, like Parken's rings reading `match` before it was declared, 2026-11-15.)
#  5. luacheck (2026-11-15), its config built from the harness's stubs (tools/lint_config.lua): writes to
#     globals, reads of globals and C_* fields the stubs lack (GetZonetext, C_PetJournal.GetPetInfoBySpeciesId, match).
#  6. The Lua language server, headless (2026-11-15): the namespace's fields and modules' methods
#     (tools/types.lua writes tools/types/ns.lua from the code), arguments past a function's. Types of values
#     are left out (.luarc.json: our `a and b or c` idioms read as mismatches). It runs in the background,
#     alongside 5 and 7, and is read last.
#  7. tools/test/run.lua: the test suite (simulated clients, see tools/test/harness.lua).
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

# The language server is most of the static checks' time (6 of --quick's 10 s): it runs alongside luacheck and the
# tests, and its result is read at the end (2026-11-19).
luals_pid=
luals_log=$(mktemp -d)
rc=$(mktemp)
trap 'rm -f "$rc"; rm -rf "$luals_log"' EXIT
if command -v lua-language-server >/dev/null; then
    if luajit tools/types.lua; then
        lua-language-server --check="$PWD" --checklevel=Warning --logpath="$luals_log" --check_format=json \
            > "$luals_log/out.txt" 2>&1 &
        luals_pid=$!
    else
        echo "TYPES: tools/types.lua failed"; fail=1
    fi
else
    echo "TYPES: lua-language-server not installed (Arch: pacman -S lua-language-server; CI: its release)"; fail=1
fi

if command -v luacheck >/dev/null; then
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
    # In CI, the coverage table on the run's page (check.sh prints only the last line when all is well).
    if [[ $quick -eq 0 && -n ${GITHUB_STEP_SUMMARY:-} ]]; then
        { echo '```'; echo "$out" | sed -n '/^file /,$p'; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
    fi
fi
if [[ -n $luals_pid ]]; then
    wait "$luals_pid"
    out=$(cat "$luals_log/out.txt")
    if ! grep -qE "no problems found|complete, 0 problems" <<<"$out"; then
        if [[ -f $luals_log/check.json ]]; then
            # (one line a problem: file:line code message; its lines count from 0)
            python3 -I -c 'import json, sys
for f, ds in sorted(json.load(open(sys.argv[1])).items()):
    for d in ds:
        print("%s:%d %s %s" % (f.split("Dyreparken/")[-1], d["range"]["start"]["line"] + 1, d["code"], d["message"].splitlines()[0]))' \
                "$luals_log/check.json" | head -40 | sed 's/^/TYPES: /'
        else
            echo "$out" | tail -5 | sed 's/^/TYPES: /'
        fi
        fail=1
    fi
fi
[[ $fail -eq 0 ]] && echo "OK" || exit 1
