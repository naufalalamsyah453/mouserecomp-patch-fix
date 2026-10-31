# mouserecomp-patch-fix

Mouse input fixes for [Savage Wind Recomp](https://github.com/Revivedx/SavageWindRecomp), as a patch you can apply
on top of an **existing checkout of the main repository** - for players who already cloned/built Revivedx's repo and
do not want to switch to another fork.

Fixes (same as [Revivedx/SavageWindRecomp#310](https://github.com/Revivedx/SavageWindRecomp/pull/310)):

- **Mouse 4 / 5 (the side buttons, Back/Forward) are detected.** They were dropped whenever the cursor was not held
  in the window (before the game captured it, after Esc, with a menu up), so a binding on them did nothing.
- **The mouse camera's input lag is cut.** The right-stick camera fallback held a stale value across frames behind a
  fixed 4 ms gate and added a ramp that made a slow mouse move turn slower than the hand. It now samples once per
  game frame and only applies the offset past the game's own dead zone.

## Which patch?

| Your source is ...                                        | Patch                |
| --------------------------------------------------------- | -------------------- |
| branch `main`, or the `v0.3.1-alpha.3` release source     | `mouse-fix.main.patch` |
| branch `test`                                             | `mouse-fix.test.patch` |

Both were verified with `git apply --check` on 2026-10-31 (`main` @ `c23173d`, `test` @ `0aa6f04`); the `main`
patch was also built (`make -j`, MSYS2 UCRT64). If upstream has moved on and the context no longer matches,
`git apply -3` does a three-way merge, or open an issue.

## Apply (source builds)

```sh
cd SavageWindRecomp
git apply --check ../mouserecomp-patch-fix/mouse-fix.main.patch   # dry run: prints nothing on success
git apply        ../mouserecomp-patch-fix/mouse-fix.main.patch
```

(or `git am mouse-fix.main.patch` instead of `git apply` if you want it as a commit with the full message.)

Windows from PowerShell: `.\apply.ps1` - picks the patch for your branch, dry-runs, then applies.
Shell: `sh apply.sh` - same.

Then rebuild the runtime exactly as you built it the first time (Windows: `make -j` from an MSYS2 UCRT64 shell;
see the upstream `docs/BUILD-windows.md` / `docs/BUILD.md`). The game code (`extracted/swgame.dll`) does not need
rebuilding for this patch.

## Binary installs (unpacked a release, no source tree)

A patch needs the source. For an installed release, use the prebuilt fixed build instead:

- <https://github.com/naufalalamsyah453/SavageWindRecomp-Tbech/releases/tag/v0.3.1-alpha.3-mousefix>
  (`SavageWind-0.3.1-alpha.3-windows.zip`, built by CI from this same fix on top of `test`) - unpack it over your
  install and keep your `savagewind.ini`, `save/` and `extracted/`; the start screen rebuilds the game code from
  your own dump if the build id differs.

## License

The patch is part of Savage Wind Recomp and stays under its license (`LICENSE`, MIT - © Revivedx and the Savage
Wind Recomp contributors). The Legend of Zelda: Breath of the Wild and all game files are © Nintendo; this repo
contains no game files, no keys and no generated game code.
