# mouserecomp-patch-fix

Mouse input fixes for PC Recomp projects:
1. **[Savage Wind Recomp](https://github.com/Revivedx/SavageWindRecomp)** (Breath of the Wild)
2. **[Tears of the Kingdom Recomp](https://github.com/valentderah/totk-pc-recomp)** (TotK)

Works as a patch you can apply to source checkouts, or via an automated installer for installed game folders.

---

## Fixes Overview

### 1. Savage Wind Recomp
- **Mouse 4 / 5 (side buttons)**: Detected reliably even before the cursor is captured or when in menus.
- **Mouse camera latency**: Deadzone floor model (`MOUSE_TILT_FLOOR 0.40`), sampling once per game frame, removing sluggish ramp curves.

### 2. Tears of the Kingdom Recomp
- **Mouse camera responsiveness**: Introduces a 40% tilt floor (`MOUSE_TILT_FLOOR 0.40`, `MOUSE_MIN_TILT 0.02`) in `runtime/input_map.c`. Micro-movements immediately overcome the game's internal stick deadzone without sticky friction.
- **Direct Cursor Interaction in Menus/Inventory/Map**:
  - When opening Inventory (`Tab`), Map (`M`), or pressing Toggle (`Alt` or Middle Mouse Click):
    - Cursor is freed and visible across the screen.
    - Mouse movement does **not** move the analog stick / 3D camera.
    - **Left Click (LMB)**: Directly selects items / confirms (`A` button).
    - **Right Click (RMB)**: Cancels / goes back (`B` button).
    - **Mouse Wheel**: Scrolls between inventory category tabs (`L` / `R`).
  - Closing menu (`Tab`, `M`, `Shift`/`B`, or `Esc`) immediately locks the cursor back into 3D mouselook.
- **Automated CI Builds**: All runtime builds and patch verifications run via GitHub Actions CI to avoid local system overhead.

---

## Easy Install (Windows) - Double-Click

1. Double-click **`Install Mouse Fix.bat`** (or run `powershell -ExecutionPolicy Bypass -File install.ps1`).
2. Select your game:
   - `[1]` Savage Wind Recomp
   - `[2]` Tears of the Kingdom Recomp
3. The installer handles backup, patching, compilation (for TotK) / binary update (for SW), and AMD shader cache cleaning.

---

## Manual Patching (Source)

### Savage Wind
```sh
cd SavageWindRecomp
git apply --check ../mouserecomp-patch-fix/mouse-fix.main.patch
git apply        ../mouserecomp-patch-fix/mouse-fix.main.patch
# Then rebuild runtime (make -j in MSYS2 UCRT64)
```

### Tears of the Kingdom
```sh
cd totk-pc-recomp
git apply --check ../mouserecomp-patch-fix/totk/mouse-fix.patch
git apply        ../mouserecomp-patch-fix/totk/mouse-fix.patch
# Build runtime and link totk.exe
```

Or run the automated TotK script directly:
```powershell
powershell -ExecutionPolicy Bypass -File totk\build-from-install.ps1 -TotkDir "C:\totkrecomp" -PayloadDir "C:\Totk-recomp"
```

---

## License & Copyright

- Patches for Savage Wind Recomp remain under the MIT License (© Revivedx & contributors).
- Patches for TotK Recomp remain under GPLv3 (© valentderah & contributors).
- The Legend of Zelda: Breath of the Wild and Tears of the Kingdom are © Nintendo. This repo contains no copyrighted Nintendo game files, keys, ROMs, or decompiled/lifted game code.
