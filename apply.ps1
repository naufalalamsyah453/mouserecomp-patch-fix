# Applies the mouse fix to the current Savage Wind Recomp checkout (PowerShell, Windows).
# Picks the patch for the checked-out branch, dry-runs it, then applies it. Usage: .\apply.ps1 [path-to-repo]
$ErrorActionPreference = 'Stop'
$repo = if ($args.Count -ge 1) { $args[0] } else { '.' }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Push-Location $repo
try {
    git rev-parse --is-inside-work-tree | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "'$repo' is not a git checkout of SavageWindRecomp." }
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    $order = if ($branch -eq 'test') { 'test', 'main' } else { 'main', 'test' }
    foreach ($name in $order) {
        $patch = Join-Path $here "mouse-fix.$name.patch"
        git apply --check $patch 2>$null
        if ($LASTEXITCODE -eq 0) {
            git apply $patch
            if ($LASTEXITCODE -ne 0) { throw "git apply failed for $patch" }
            Write-Host "Applied mouse-fix.$name.patch to branch '$branch'."
            Write-Host "Rebuild the runtime next (Windows: make -j from an MSYS2 UCRT64 shell)."
            exit 0
        }
    }
    Write-Error ("Neither patch applies cleanly here (branch '$branch'). " +
                 "Try 'git apply -3 mouse-fix.main.patch' for a three-way merge, or open an issue.")
} finally { Pop-Location }
