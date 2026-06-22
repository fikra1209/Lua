$sh = New-Object -ComObject WScript.Shell

# 1. Tentukan Jalur Autoexec
$autoexecTarget = ""
$autoexecLnk = "d:\Aplikasi\Xeno-v1.3.25b\Xeno-v1.3.25b\autoexec.lnk"
if (Test-Path $autoexecLnk) {
    $autoexecTarget = $sh.CreateShortcut($autoexecLnk).TargetPath
}
if (-not $autoexecTarget -or -not (Test-Path $autoexecTarget)) {
    $autoexecTarget = "C:\Users\user\AppData\Local\Xeno\autoexec"
}
Write-Host "Resolved Autoexec Path: $autoexecTarget"

# 2. Tentukan Jalur Scripts
$scriptsTarget = ""
$scriptsLnk = "d:\Aplikasi\Xeno-v1.3.25b\Xeno-v1.3.25b\scripts.lnk"
if (Test-Path $scriptsLnk) {
    $scriptsTarget = $sh.CreateShortcut($scriptsLnk).TargetPath
}
if (-not $scriptsTarget -or -not (Test-Path $scriptsTarget)) {
    $scriptsTarget = "C:\Users\user\AppData\Local\Xeno\scripts"
}
Write-Host "Resolved Scripts Path: $scriptsTarget"

# 3. Tentukan Jalur Workspace
$workspaceTarget = "C:\Users\user\AppData\Local\Xeno\workspace"

# Pastikan semua folder tujuan ada
if (-not (Test-Path $autoexecTarget)) {
    New-Item -ItemType Directory -Path $autoexecTarget -Force | Out-Null
}
if (-not (Test-Path $scriptsTarget)) {
    New-Item -ItemType Directory -Path $scriptsTarget -Force | Out-Null
}
if (-not (Test-Path $workspaceTarget)) {
    New-Item -ItemType Directory -Path $workspaceTarget -Force | Out-Null
}

# 4. Salin Summon Heroes ke Autoexec (Otomatis)
$destSH = Join-Path $autoexecTarget "summon_heroes_script.lua"
Copy-Item -Path "d:\Aplikasi\summon_heroes_script.lua" -Destination $destSH -Force
Write-Host "Successfully copied Summon Heroes script to autoexec: $destSH"

# 5. Bersihkan/Hapus Violence District dari Autoexec (Agar TIDAK otomatis berjalan)
$oldVDInAutoexec = Join-Path $autoexecTarget "violence_district_script.lua"
if (Test-Path $oldVDInAutoexec) {
    Remove-Item -Path $oldVDInAutoexec -Force
    Write-Host "Removed old Violence District script from autoexec to stop auto-running: $oldVDInAutoexec"
}

# 6. Salin Violence District ke folder Scripts (Manual)
$destVD = Join-Path $scriptsTarget "violence_district_script.lua"
Copy-Item -Path "d:\Aplikasi\violence_district_script.lua" -Destination $destVD -Force
Write-Host "Successfully copied Violence District script to scripts folder: $destVD"

# 7. Salin salinan cadangan ke Workspace
Copy-Item -Path "d:\Aplikasi\summon_heroes_script.lua" -Destination (Join-Path $workspaceTarget "summon_heroes_script.lua") -Force
Copy-Item -Path "d:\Aplikasi\violence_district_script.lua" -Destination (Join-Path $workspaceTarget "violence_district_script.lua") -Force
Write-Host "Successfully backed up scripts to workspace folder."
