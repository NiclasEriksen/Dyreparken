# Dyreparken

A World of Warcraft: Forever addon for the guild Dyreparken.

- **Menagerie:** adopt a companion pet for your character. Adoptions sync across the guild (first come, first
  served), show in the Pet Journal and on companion tooltips, and your companion can get a nickname after a week. It's
  summoned automatically when you're idle.
- **Party games:** a framework for leader-run guild events (work in progress).

Commands: `/dp` lists them all.

## Development

- Load it straight from the git checkout in `_forever_/Interface/AddOns/Dyreparken`. It reports its version as `dev`.
- `tools/check.sh` runs the static checks and the test suite: several simulated players syncing over a fake network, with coverage floors (needs `luajit`). `tools/check.sh --quick` skips coverage. CI runs the full check on every push. To run it before every push locally too: `git config core.hooksPath .githooks`.
- Notes for contributors (and AI agents): `CLAUDE.md`, plus `docs/FOREVER_API.md` for client quirks.

## Releasing

Push a tag: `v0.1.0` (release), `v0.1.0-beta1` (beta) or `v0.1.0-alpha1` (alpha). GitHub Actions runs the checks and
then the [BigWigs packager](https://github.com/BigWigsMods/packager), which uploads to CurseForge and creates a GitHub
release. It needs the repository secrets `CF_API_KEY` and `CF_PROJECT_ID`.

## License

MIT for Dyreparken's own code. The bundled libraries in `Libs/` keep their own licenses (see `LICENSE`).
