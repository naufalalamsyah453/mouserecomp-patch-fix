# Installer Mouse Fix untuk PC Recomp (Savage Wind & Tears of the Kingdom).
# Dipanggil dari "Install Mouse Fix.bat" (dobel-klik) atau:
#   powershell -File install.ps1 [-Game <1|2|SavageWind|TotK>] [-Folder <path>]
param(
    [string]$Game,            # 1: SavageWind, 2: TotK (tanpa argumen: menu interaktif)
    [string]$Folder,          # tanpa argumen: dialog pilih folder
    [switch]$NoPrompt,        # non-interaktif: semua pertanyaan dijawab "ya"
    [switch]$SkipDriverCache, # lewati pembersihan cache driver AMD
    [string]$ZipPath          # pakai zip release lokal (uji Savage Wind)
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m) { Write-Host $m }
function Fail($m) { Write-Host "`nGAGAL: $m" -ForegroundColor Red; exit 1 }

# ---- Menu Pilihan Game ---------------------------------------------------
if (-not $Game) {
    Say "=================================================="
    Say "   PC Recomp Mouse Fix Installer (Multi-Game)    "
    Say "=================================================="
    Say "Pilih game yang ingin dipasang patch mouse:"
    Say "  [1] Savage Wind Recomp (savagewind.exe)"
    Say "  [2] Tears of the Kingdom Recomp (totk.exe)"
    Say "  [Q] Keluar"
    Say ""
    $choice = Read-Host "Pilihan kamu [1/2/Q]"
    if ($choice -match '^[qQ]$' -or [string]::IsNullOrWhiteSpace($choice)) {
        Say "Batal."
        exit 0
    }
    $Game = $choice.Trim()
}

if ($Game -in @('2', 'totk', 'TotK', 'TOTK')) {
    # ---- TotK Flow -----------------------------------------------------------
    $totkScript = Join-Path $here 'totk\build-from-install.ps1'
    if (-not (Test-Path $totkScript)) { Fail "Script TotK tidak ditemukan: $totkScript" }
    $params = @{}
    if ($Folder) { $params['TotkDir'] = $Folder }
    if ($NoPrompt) { $params['NoPrompt'] = $true }
    if ($SkipDriverCache) { $params['SkipDriverCache'] = $true }
    & $totkScript @params
    exit $LASTEXITCODE
}

if ($Game -notin @('1', 'savagewind', 'SavageWind', 'sw', 'SW')) {
    Fail "Pilihan game tidak valid: $Game. Pilih 1 (Savage Wind) atau 2 (TotK)."
}

# ==========================================================================
# Savage Wind Flow
# ==========================================================================
$Release = 'https://github.com/naufalalamsyah453/SavageWindRecomp-Tbech/releases/download/v0.3.1-alpha.3-mousefix/SavageWind-0.3.1-alpha.3-windows.zip'

# git dengan aman di PowerShell 5.1 (stderr-nya jangan bikin error saat EAP=Stop)
function Invoke-Git([string]$Repo, [string[]]$GitArgs) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $Repo @GitArgs 2>&1
        [pscustomobject]@{ Code = $LASTEXITCODE; Out = (($out | ForEach-Object { "$_" }) -join "`n").Trim() }
    } finally { $ErrorActionPreference = $old }
}

# ---- pilih folder --------------------------------------------------------
if (-not $Folder) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Pilih folder install Savage Wind (mis. C:\Savage Wind) atau folder clone SavageWindRecomp.'
    $dlg.ShowNewFolderButton = $false
    if (Test-Path 'C:\Savage Wind') { $dlg.SelectedPath = 'C:\Savage Wind' }
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Say 'Batal.'; exit 0 }
    $Folder = $dlg.SelectedPath
}
if (-not (Test-Path -LiteralPath $Folder)) { Fail "Folder tidak ada: $Folder" }
$Folder = (Resolve-Path -LiteralPath $Folder).Path
Say "Folder: $Folder"

# ---- mode ----------------------------------------------------------------
$isSource = (Test-Path -LiteralPath (Join-Path $Folder '.git')) -and (Test-Path -LiteralPath (Join-Path $Folder 'runtime\hle\input.c'))
$isBinary = (Test-Path -LiteralPath (Join-Path $Folder 'savagewind.exe')) -and (Test-Path -LiteralPath (Join-Path $Folder 'extracted'))
if (-not ($isSource -or $isBinary)) {
    Fail ("Folder tidak dikenali. Harus berisi install game (savagewind.exe + extracted)`n" +
          'atau checkout git repo SavageWindRecomp (folder .git + runtime\).')
}

# ---- mode source: git apply ---------------------------------------------
if ($isSource) {
    $rev = Invoke-Git $Folder @('rev-parse', '--abbrev-ref', 'HEAD')
    if ($rev.Code -ne 0) { Fail 'Folder punya .git tapi git tidak bisa membacanya (git terpasang? repo utuh?).' }
    $branch = $rev.Out
    $order = if ($branch -eq 'test') { 'test', 'main' } else { 'main', 'test' }
    foreach ($name in $order) {
        $patch = Join-Path $here "mouse-fix.$name.patch"
        if ((Invoke-Git $Folder @('apply', '--check', $patch)).Code -eq 0) {
            $app = Invoke-Git $Folder @('apply', $patch)
            if ($app.Code -ne 0) { Fail "git apply gagal untuk $patch`n$($app.Out)" }
            Say "`nSUKSES: mouse-fix.$name.patch terpasang di branch '$branch'."
            Say 'Langkah terakhir: bangun ulang runtime seperti biasa (Windows: make -j dari shell MSYS2 UCRT64).'
            exit 0
        }
        if ((Invoke-Git $Folder @('apply', '--reverse', '--check', $patch)).Code -eq 0) {
            Say "`nSudah terpasang: mouse-fix.$name.patch sudah ada di checkout ini - tidak ada yang diubah."
            Say 'Tinggal bangun ulang runtime kalau belum.'
            exit 0
        }
    }
    Fail ("Patch tidak cocok dengan isi folder ini (mungkin versi repo berbeda dari patch).`n" +
          'Coba: git -C "<folder>" apply -3 mouse-fix.main.patch, atau buka issue di repo patch.')
}

# ---- mode binary: unduh zip, backup, timpa -------------------------------
$stage = Join-Path $env:TEMP 'mouserecomp-patch-fix'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
if (-not $ZipPath) {
    $ZipPath = Join-Path $stage 'SavageWind-0.3.1-alpha.3-windows.zip'
    if (-not (Test-Path $ZipPath)) {
        Say "`nMengunduh build patch (~87 MB) dari rilis GitHub ..."
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Release -OutFile $ZipPath -UseBasicParsing
        } catch {
            Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
            Fail ("Unduhan gagal: $($_.Exception.Message)`nUnduh manual lalu jalankan ulang:`n$Release")
        }
    } else { Say "`nZip sudah ada di $stage - pakai itu." }
}
$work = Join-Path $stage 'payload'
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $ZipPath -DestinationPath $work -Force
$d = Get-ChildItem $work -Directory | Select-Object -First 1
$payload = if ($d) { $d.FullName } else { $work }
if (-not (Test-Path (Join-Path $payload 'savagewind.exe'))) { Fail 'Zip tidak berisi savagewind.exe - zip rusak?' }

$localExe = Join-Path $Folder 'savagewind.exe'
$same = ((Get-FileHash $localExe -Algorithm SHA256).Hash -eq (Get-FileHash (Join-Path $payload 'savagewind.exe') -Algorithm SHA256).Hash)

# backup file yang akan ditimpa DAN berbeda isinya
$keep = @('extracted', 'save', 'cache', 'savagewind.ini', 'save.lock')
$backup = $null
foreach ($item in Get-ChildItem $payload) {
    if ($keep -contains $item.Name -or $item.PSIsContainer) { continue }
    $dest = Join-Path $Folder $item.Name
    if (-not (Test-Path -LiteralPath $dest)) { continue }
    if ((Get-FileHash -LiteralPath $dest).Hash -eq (Get-FileHash -LiteralPath $item.FullName).Hash) { continue }
    if (-not $backup) {
        $backup = Join-Path $Folder ("backup-sebelum-patch-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force -Path $backup | Out-Null
    }
    Copy-Item $dest (Join-Path $backup $item.Name) -Force
}

# timpa (merge, timpa file, jangan hapus apa pun)
function Copy-Tree($src, $dst) {
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    foreach ($f in Get-ChildItem $src -Recurse) {
        $rel = $f.FullName.Substring($src.Length).TrimStart('\')
        $d = Join-Path $dst $rel
        if ($f.PSIsContainer) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
        else {
            $parent = Split-Path $d
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            Copy-Item $f.FullName $d -Force
        }
    }
}
Say "`nMemasang file build patch ..."
foreach ($item in Get-ChildItem $payload) {
    if ($keep -contains $item.Name) { continue }
    if ($item.PSIsContainer) { Copy-Tree $item.FullName (Join-Path $Folder $item.Name) }
    else { Copy-Item $item.FullName (Join-Path $Folder $item.Name) -Force }
}

# cache driver AMD
$amd = @()
if (-not $SkipDriverCache) {
    $amd = @('VkCache', 'DxCache', 'DxcCache') | ForEach-Object { Join-Path $env:LOCALAPPDATA "AMD\$_" } | Where-Object { Test-Path $_ }
}
if ($amd) {
    $ans = 'y'
    if (-not $NoPrompt) {
        $ans = Read-Host "`nBersihkan cache driver AMD? (dianjurkan - cegah crash GPU; cache dibangun ulang otomatis) [Y/n]"
        if (-not $ans) { $ans = 'y' }
    }
    if ($ans -match '^(n|t|no)$') {
        Say 'Cache driver AMD tidak disentuh.'
    } else {
        foreach ($dir in $amd) { Remove-Item (Join-Path $dir '*') -Recurse -Force -ErrorAction SilentlyContinue }
        Say 'Cache driver AMD dibersihkan.'
    }
}

Say "`nSELESAI - build patch terpasang$(if ($same) { ' (sudah terpasang sebelumnya, file disinkronkan ulang)' })."
if ($backup) { Say "Backup file lama yang diganti: $backup" }
else { Say 'Tidak ada file lama yang diganti (semua sudah identik).' }
Say 'Jalankan savagewind.exe (atau shortcut kamu). Catatan:'
Say ' - save/, cache/, extracted/ dan savagewind.ini tidak berubah.'
Say ' - Game code (extracted\swgame.dll) akan di-build ulang otomatis di layar awal bila id-nya beda (tunggu sekali di awal).'
exit 0
