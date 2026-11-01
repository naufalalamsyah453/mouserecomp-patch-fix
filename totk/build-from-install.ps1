# Build dan pasang fix mouse untuk TotK Recomp (Tears of the Kingdom).
# Kompilasi lokal menggunakan toolchain installer (C:\Totk-recomp) dan source repo.
# Exe tidak didistribusikan langsung (hak cipta guest code).
param(
    [string]$TotkDir = 'C:\totkrecomp',
    [string]$PayloadDir = 'C:\Totk-recomp',
    [string]$SourceDir,
    [switch]$NoPrompt,
    [switch]$SkipDriverCache,
    [string]$Version = 'v143'
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m) { Write-Host $m }
function Fail($m) { Write-Host "`nGAGAL: $m" -ForegroundColor Red; exit 1 }

Say "=== TotK Recomp Mouse Fix Installer ==="

# 1. Validasi folder TotK install
if (-not (Test-Path (Join-Path $TotkDir 'totk.exe')) -or -not (Test-Path (Join-Path $TotkDir 'exefs'))) {
    if (-not $NoPrompt) {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Pilih folder install TotK Recomp (berisi totk.exe dan exefs).'
        $dlg.ShowNewFolderButton = $false
        if (Test-Path $TotkDir) { $dlg.SelectedPath = $TotkDir }
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Say 'Batal.'; exit 0 }
        $TotkDir = $dlg.SelectedPath
    }
}
if (-not (Test-Path (Join-Path $TotkDir 'totk.exe')) -or -not (Test-Path (Join-Path $TotkDir 'exefs'))) {
    Fail "Folder install TotK tidak valid: $TotkDir (totk.exe atau exefs tidak ditemukan)."
}
Say "Folder Install: $TotkDir"

# 2. Validasi toolchain payload
$python = Join-Path $PayloadDir 'python\python.exe'
$llvm = Join-Path $PayloadDir 'llvm'
$ninja = Join-Path $PayloadDir 'bin\ninja.exe'
$deps = Join-Path $PayloadDir 'runtime\deps'

if (-not (Test-Path $python) -or -not (Test-Path (Join-Path $llvm 'bin\clang.exe')) -or -not (Test-Path $ninja)) {
    Fail "Toolchain payload tidak ditemukan di $PayloadDir (butuh C:\Totk-recomp dari installer resmi)."
}
Say "Toolchain: $PayloadDir"

# 3. Validasi / clone source repository
if (-not $SourceDir) {
    $candidate = 'C:\Users\tb\Projects\totk-pc-recomp'
    if (Test-Path (Join-Path $candidate 'recomp\gen.py')) {
        $SourceDir = $candidate
    } else {
        $SourceDir = Join-Path $here 'totk-pc-recomp'
        if (-not (Test-Path (Join-Path $SourceDir 'recomp\gen.py'))) {
            Say "`nMengkloning repository source totk-pc-recomp ..."
            & git clone https://github.com/naufalalamsyah453/totk-pc-recomp.git $SourceDir
            if ($LASTEXITCODE -ne 0) { Fail "Gagal mengkloning totk-pc-recomp." }
        }
    }
}
$SourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
Say "Source Dir: $SourceDir"

# 4. Terapkan patch mouse-fix jika belum terpasang
$patchFile = Join-Path $here 'mouse-fix.patch'
if (Test-Path $patchFile) {
    $checkPatch = & git -C $SourceDir apply --check $patchFile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Say "Menerapkan mouse-fix.patch ke source ..."
        & git -C $SourceDir apply $patchFile
        if ($LASTEXITCODE -ne 0) { Fail "Gagal menerapkan mouse-fix.patch." }
        Say "Patch berhasil diterapkan."
    } else {
        $checkReverse = & git -C $SourceDir apply --reverse --check $patchFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            Say "Patch mouse-fix sudah terpasang di source."
        } else {
            Say "Catatan: Patch tidak cocok langsung (mungkin sudah ada modifikasi lain); melanjutkan..."
        }
    }
}

# 5. Bangun runtime library (libtotkrt.a)
Say "`n[1/3] Membangun runtime library ber-patch (libtotkrt.a) ..."
$rtlibDir = Join-Path $SourceDir 'build\rtlib'
$genDir = Join-Path $SourceDir "generated\$Version"

& $python (Join-Path $SourceDir 'tools\build_game.py') `
    --make-runtime-lib `
    --gen $genDir `
    --out $rtlibDir `
    --runtime (Join-Path $SourceDir 'runtime') `
    --toolchain $llvm `
    --deps $deps `
    --ninja $ninja `
    --version $Version

if ($LASTEXITCODE -ne 0) { Fail "Gagal membangun libtotkrt.a." }

# 6. Lift ExeFS jika belum dilakukan
if (-not (Test-Path (Join-Path $genDir 'main'))) {
    Say "`n[2/3] Mengangkat ExeFS menjadi kode C (gen.py, ~2 menit) ..."
    $patchesTxt = Join-Path $SourceDir "recomp\patches-$Version.txt"
    & $python (Join-Path $SourceDir 'recomp\gen.py') `
        --exefs (Join-Path $TotkDir 'exefs') `
        --out $genDir `
        --patches $patchesTxt

    if ($LASTEXITCODE -ne 0) { Fail "Gagal menjalankan recomp gen.py." }
} else {
    Say "`n[2/3] Kode C ExeFS (generated\$Version) sudah ada, memakai cache..."
}

# 7. Kompilasi dan link totk.exe
Say "`n[3/3] Mengompilasi dan link totk.exe ..."
$buildOut = Join-Path $SourceDir "build\$Version"
$rtlibFile = Join-Path $rtlibDir 'libtotkrt.a'
$expectedFile = Join-Path $SourceDir 'tools\data\expected-v1.4.3.json'
$romfsDir = Join-Path $TotkDir 'romfs'
$profileDir = Join-Path $TotkDir 'profile'

& $python (Join-Path $SourceDir 'tools\build_game.py') `
    --gen $genDir `
    --out $buildOut `
    --toolchain $llvm `
    --deps $deps `
    --runtime (Join-Path $SourceDir 'runtime') `
    --runtime-lib $rtlibFile `
    --ninja $ninja `
    --version $Version `
    --expected $expectedFile `
    --exefs (Join-Path $TotkDir 'exefs') `
    --romfs $romfsDir `
    --profile $profileDir

if ($LASTEXITCODE -ne 0) { Fail "Gagal mengompilasi/link totk.exe." }

# 8. Verifikasi mandiri (--probe-cfg & --selftest)
Say "`nMemverifikasi build ..."
Copy-Item (Join-Path $PayloadDir 'bin\SDL3.dll') $buildOut -Force
Copy-Item (Join-Path $PayloadDir 'bin\libopus-0.dll') $buildOut -Force

$builtExe = Join-Path $buildOut 'totk.exe'
& $builtExe --probe-cfg
if ($LASTEXITCODE -ne 0) { Fail "Verifikasi --probe-cfg gagal!" }

& $builtExe --selftest
if ($LASTEXITCODE -ne 0) { Fail "Verifikasi --selftest gagal!" }
Say "Verifikasi lolos: 0 error."

# 9. Backup dan pasang totk.exe baru
$targetExe = Join-Path $TotkDir 'totk.exe'
$backupDir = Join-Path $TotkDir ("backup-totk-exe-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item $targetExe (Join-Path $backupDir 'totk.exe') -Force
Say "Backup exe lama disimpan di: $backupDir"

Copy-Item $builtExe $targetExe -Force
Say "SUKSES: totk.exe ber-patch telah dipasang ke $TotkDir"

# 10. Bersihkan cache driver AMD jika ada
if (-not $SkipDriverCache) {
    $amd = @('VkCache', 'DxCache', 'DxcCache') | ForEach-Object { Join-Path $env:LOCALAPPDATA "AMD\$_" } | Where-Object { Test-Path $_ }
    if ($amd) {
        $ans = 'y'
        if (-not $NoPrompt) {
            $ans = Read-Host "`nBersihkan cache driver AMD? (dianjurkan - cegah crash GPU) [Y/n]"
            if (-not $ans) { $ans = 'y' }
        }
        if ($ans -notmatch '^(n|t|no)$') {
            foreach ($dir in $amd) { Remove-Item (Join-Path $dir '*') -Recurse -Force -ErrorAction SilentlyContinue }
            Say "Cache driver AMD dibersihkan."
        }
    }
}

Say "`nSelesai! Tips optimal TotK Recomp:"
Say " - Atur 'fps_limit = 60' di $TotkDir\totk.ini untuk responsivitas mouse terbaik."
Say " - Mouse camera kini memiliki 40% deadzone floor untuk responsivitas instan pada gerakan halus."
