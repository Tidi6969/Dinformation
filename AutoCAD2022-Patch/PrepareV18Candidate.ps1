param([switch]$PublishCandidate)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Location).Path
$baselineZip = Join-Path $repoRoot 'V17/Dinformation-V17.zip'
if (-not (Test-Path -LiteralPath $baselineZip)) { throw 'Missing authoritative V17 baseline ZIP.' }
$stage = Join-Path $repoRoot '_v18stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
Expand-Archive -LiteralPath $baselineZip -DestinationPath $stage -Force
$sourceRoot = Join-Path $stage 'Dinformation-V17'
if (-not (Test-Path -LiteralPath $sourceRoot)) { throw 'Baseline archive has unexpected root.' }

$sourceHost = Join-Path $sourceRoot 'Dinformation-AutoCAD2022-V17'
$projectFiles = @('AssemblyInfo.cs','Dinformation.csproj','Build_Release.cmd','Buildtime/Build_Release.ps1','src/Core/DinformationCommands.cs','README.md','Data/BuildInfo.txt','Data/DataManifest.txt')
foreach ($rel in @('src/Information/InformationSession.cs','src/Core/LispInfoEngine.cs','Buildtime/Dinformation-Tooltip.lsp.tpl')) {
    $from = Join-Path $repoRoot (Join-Path 'AutoCAD2022-Patch' $rel)
    $to = Join-Path $sourceHost $rel
    if (!(Test-Path -LiteralPath $from) -or !(Test-Path -LiteralPath $to)) { throw "Source patch missing $rel" }
    Copy-Item -LiteralPath $from -Destination $to -Force
}
Rename-Item -LiteralPath $sourceRoot -NewName 'Dinformation-V18'
$package = Join-Path $stage 'Dinformation-V18'
Rename-Item -LiteralPath (Join-Path $package 'Dinformation-AutoCAD2022-V17') -NewName 'Dinformation-AutoCAD2022-V18'
$hostDir = Join-Path $package 'Dinformation-AutoCAD2022-V18'
foreach ($rel in $projectFiles) {
    $path = Join-Path $hostDir $rel
    if (!(Test-Path -LiteralPath $path)) { throw "Missing version metadata: $rel" }
    $src = [IO.File]::ReadAllText($path)
    $src = $src.Replace('V17','V18').Replace('17.0.0.0','18.0.0.0')
    [IO.File]::WriteAllText($path,$src,[Text.UTF8Encoding]::new($false))
}
foreach ($oldHost in @('Dinformation-AutoCAD2025-V17','Dinformation-GstarCAD2018-V17','Dinformation-GstarCAD2027-V17')) {
    $path = Join-Path $package $oldHost
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
$oldDprogram = Join-Path $package 'Dprogram'
if (Test-Path -LiteralPath $oldDprogram) { Remove-Item -LiteralPath $oldDprogram -Recurse -Force }
New-Item -ItemType Directory -Path $oldDprogram | Out-Null
$rootScript = @'
@echo off
setlocal EnableExtensions EnableDelayedExpansion
pushd "%~dp0"
if not exist "log" mkdir "log"
if not exist "Dprogram" mkdir "Dprogram"
if exist "Dprogram\DinformationC22.dll" del /q "Dprogram\DinformationC22.dll"
set "RC=1"
call :PRINT "TITLE" "Dinformation V18 - AutoCAD 2022"
call :PRINT "BUILD" "[BUILD] AutoCAD 2022 Release x64"
call "%~dp0Dinformation-AutoCAD2022-V18\Build_Release.cmd" /nopause >"log\AutoCAD2022.log" 2>&1
cd /d "%~dp0"
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" goto :FINISH
if not exist "Dinformation-AutoCAD2022-V18\bin\DinformationC22.dll" (
    set "RC=2"
    goto :FINISH
)
copy /Y "Dinformation-AutoCAD2022-V18\bin\DinformationC22.dll" "Dprogram\DinformationC22.dll" >nul
if errorlevel 1 (
    set "RC=3"
    goto :FINISH
)
set "RC=0"
:FINISH
>"log\Build_All.log" echo Dinformation V18 - AutoCAD 2022
>>"log\Build_All.log" echo Target=AutoCAD2022
>>"log\Build_All.log" echo BuildExitCode=!RC!
>>"log\Build_All.log" echo RuntimeStatus=NotVerified
if "!RC!"=="0" (
    call :PRINT "PASS" "[PASS] BUILD ALL: PASS - AutoCAD 2022"
) else (
    call :PRINT "FAIL" "[FAIL] BUILD ALL: FAIL - AutoCAD 2022"
)
echo Log: %~dp0log\Build_All.log
set "FINAL_RC=!RC!"
if /I not "%~1"=="/nopause" (
    echo Nhan phim bat ky de thoat...
    pause >nul
)
popd
endlocal & exit /b %FINAL_RC%
:PRINT
if defined NO_COLOR (
    echo COLOR_MODE=PLAIN; REASON=NO_COLOR
    echo %~2
    exit /b 0
)
set "COLOR=Gray"
if /I "%~1"=="TITLE" set "COLOR=Cyan"
if /I "%~1"=="BUILD" set "COLOR=Blue"
if /I "%~1"=="PASS" set "COLOR=Green"
if /I "%~1"=="FAIL" set "COLOR=Red"
if /I "%~1"=="WARNING" set "COLOR=Yellow"
powershell.exe -NoProfile -Command "Write-Host '%~2' -ForegroundColor %COLOR%" 2>nul
if errorlevel 1 (
    echo COLOR_MODE=PLAIN; REASON=COLOR_UNAVAILABLE
    echo %~2
)
exit /b 0
'@
[IO.File]::WriteAllText((Join-Path $package 'Build_All.cmd'),$rootScript,[Text.Encoding]::ASCII)
@'
# Dinformation V18 - AutoCAD 2022 SOURCE / PENDING CAD TEST

Baseline: V17. Target: AutoCAD 2022 only.
Source patch: native PointMonitor pick with LISP fallback and safe unknown-object metadata.
Build: PASS Release x64, framework net48, SDK Autodesk 24.1.
NETLOAD / real AutoCAD 2022 tooltip tests: NotVerified.
Standards / release approval: NotVerified / NO.
Dprogram/DinformationC22.dll was built from V18 source; reference SDK DLLs are build-time only.
GstarCAD 2018, AutoCAD 2025, GstarCAD 2027: outside this package and unchanged in archived V17.
This is a source/build candidate for user CAD testing, NOT a completed V18 release.
'@ | Set-Content -LiteralPath (Join-Path $package 'README.md') -Encoding utf8
$qaFile = Join-Path $repoRoot 'AutoCAD2022-Patch/QA-V18.md'
$qaTarget = Join-Path $hostDir 'Userdata'
if (!(Test-Path -LiteralPath $qaTarget)) { New-Item -ItemType Directory -Path $qaTarget | Out-Null }
Copy-Item -LiteralPath $qaFile -Destination (Join-Path $qaTarget 'QA-V18.md') -Force

Write-Host 'Building V18 via package root Build_All.cmd ...'
Push-Location $package
try {
    & cmd.exe /c 'Build_All.cmd /nopause'
    $buildExit = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($buildExit -ne 0) {
    foreach ($diagPath in @((Join-Path $package 'log/Build_All.log'),(Join-Path $package 'log/AutoCAD2022.log'),(Join-Path $hostDir 'log/Build-V18.log'))) {
        if (Test-Path -LiteralPath $diagPath) {
            Write-Host "DIAGNOSTIC: $diagPath"
            Get-Content -LiteralPath $diagPath -Tail 70 | ForEach-Object { Write-Host $_ }
        }
    }
    throw "HARD STOP: V18 build failed, exit=$buildExit"
}
$dll = Join-Path $hostDir 'bin/DinformationC22.dll'
$portableDll = Join-Path $oldDprogram 'DinformationC22.dll'
if (!(Test-Path $dll) -or !(Test-Path $portableDll)) { throw 'HARD STOP: new compiled DLL missing.' }
if ([Reflection.AssemblyName]::GetAssemblyName($dll).Version.ToString() -ne '18.0.0.0') { throw 'Assembly version mismatch, expected V18.' }
if ((Get-FileHash $dll -Algorithm SHA256).Hash -ne (Get-FileHash $portableDll -Algorithm SHA256).Hash) { throw 'Portable DLL is not identical to new build.' }

$buildInfo = Join-Path $hostDir 'Data/BuildInfo.txt'
@'
Module=Dinformation
Repository=Tidi6969/Dinformation
BaselineVersion=V17
MaximumStoredBeforeUpdate=V17
PlannedVersion=V18
VersionReason=STD-17 default latest+1
CADTargets=AutoCAD2022
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
PackageType=SourceBuildCandidate_PendingAutoCAD2022RuntimeTest
'@ | Add-Content -LiteralPath $buildInfo -Encoding utf8
$rootData = Join-Path $package 'Data'
if (!(Test-Path -LiteralPath $rootData)) { New-Item -ItemType Directory -Path $rootData | Out-Null }
@'
DINFORMATION V18 - SOURCE/BUILD CANDIDATE, NOT A COMPLETED RELEASE
Baseline V17 original ZIP: untouched.
CAD Target AutoCAD2022 ONLY.
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
NETLOAD=NotVerified
Cursor/hover responsiveness=NotVerified
Color console visual inspection=NotVerified
Other CAD hosts in baseline V17=Unmodified, not in V18 package.
'@ | Set-Content -LiteralPath (Join-Path $rootData 'BUILD-STATUS.txt') -Encoding utf8
$rootLog=Join-Path $package 'log'
if (!(Test-Path $rootLog)) { throw 'Root log missing' }
$projectObj=Join-Path $hostDir 'obj'
if (Test-Path -LiteralPath $projectObj) { Remove-Item -LiteralPath $projectObj -Recurse -Force }
$packZipDir=Join-Path $repoRoot '_v18prepared'
if (!(Test-Path -LiteralPath $packZipDir)) { New-Item -ItemType Directory -Path $packZipDir | Out-Null }
$archive=Join-Path $packZipDir 'Dinformation-V18.zip'
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive -CompressionLevel Optimal

Add-Type -AssemblyName System.IO.Compression
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries=@($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    $needed=@('Build_All.cmd','Dprogram/DinformationC22.dll','Dinformation-AutoCAD2022-V18/bin/DinformationC22.dll','Dinformation-AutoCAD2022-V18/Dinformation.csproj','Dinformation-AutoCAD2022-V18/src/Information/InformationSession.cs','Dinformation-AutoCAD2022-V18/Buildtime/Dinformation-Tooltip.lsp.tpl','Dinformation-AutoCAD2022-V18/Reference/AcMgd.dll','Data/BUILD-STATUS.txt')
    foreach ($neededFile in $needed) { if ($entries -notcontains $neededFile) { throw "ZIP missing $neededFile" } }
    foreach ($e in $zip.Entries) {
        if ($e.FullName -match '(GstarCAD2018|AutoCAD2025|GstarCAD2027)') { throw "Unexpected CAD host in V18 package: $($e.FullName)" }
        if ($e.Name -ne '') { $read=$e.Open(); try { $read.CopyTo([IO.Stream]::Null) } finally { $read.Dispose() } }
    }
} finally {
    $zip.Dispose()
}
$checksum=(Get-FileHash $archive -Algorithm SHA256).Hash
$length=(Get-Item $archive).Length
Write-Host "V18 ZIP: byteLength=$length sha256=$checksum; Build PASS; Runtime NotVerified; ReleaseApproved=NO"

$changelog=@"
Dinformation V18
Module=Dinformation
Repository=Tidi6969/Dinformation
Baseline=V17
MaxStoredBefore=V17
TargetVersion=V18
VersionReason=STD-17 default +1
CADTargets=AutoCAD2022
VersionType=SOURCE/BUILD CANDIDATE - PENDING CAD RUNTIME TEST
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
VersionAssembly=18.0.0.0
BuildSDK=Autodesk AcCoreMgd/AcDbMgd/AcMgd 24.1, net48, x64
FilesChanged=InformationSession.cs; LispInfoEngine.cs; Dinformation-Tooltip.lsp.tpl; required V18 packaging metadata/scripts
Summary=Native-picked-object cache avoids repeating LISP hit tests. Original LISP nentselp fallback is immediate when native picker misses. Unsupported property reader returns DXF type/layer/handle.
Preserved=All GstarCAD 2018, AutoCAD 2025, GstarCAD 2027 originals in V17; geometry/settings/XData/language/command remain unchanged.
KnownIssues=Real AutoCAD 2022 NETLOAD, speed, entity coverage, nested blocks/proxies, ESC, UCS, visual build console and six languages NotVerified. Not a completed release.
ArchiveSha256=$checksum
ArchiveSize=$length
"@
$changelogPath=Join-Path $packZipDir 'V18.txt'
[IO.File]::WriteAllText($changelogPath,$changelog,[Text.UTF8Encoding]::new($false))

if ($PublishCandidate) {
    & git fetch origin main | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch current main branch for release conflict check.' }
    $already=& git ls-tree --name-only origin/main -- V18
    if ($already) { throw 'HARD STOP: V18 already exists on main. No overwrite.' }
    & git switch -c dcad-v18-candidate-publish origin/main | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create publishing worktree.' }
    $destDir=Join-Path $repoRoot 'V18'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $archive (Join-Path $destDir 'Dinformation-V18.zip') -Force
    $logDir=Join-Path $repoRoot 'Change log'
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    Copy-Item $changelogPath (Join-Path $logDir 'V18.txt') -Force
    $repoReadme=@'
# Dinformation

Latest saved: **V18 — source/build candidate pending AutoCAD 2022 test**, baseline V17.
Target: AutoCAD 2022 ONLY. Build PASS (.NET Framework 4.8, Autodesk SDK 24.1); NETLOAD/Runtime/Standards NotVerified; RELEASE_APPROVED=NO.
Stable/accepted version: Not confirmed.
Download candidate for CAD runtime testing: [Dinformation-V18.zip](V18/Dinformation-V18.zip)
Change log: [V18](Change%20log/V18.txt)
V17 baseline: [Dinformation-V17.zip](V17/Dinformation-V17.zip) (unchanged).
Other CAD targets are unchanged in baseline V17 and not rebuilt for V18.
'@
    [IO.File]::WriteAllText((Join-Path $repoRoot 'README.md'),$repoReadme,[Text.UTF8Encoding]::new($false))
    & git config user.name 'github-actions[bot]'
    & git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    & git add 'V18/Dinformation-V18.zip' 'Change log/V18.txt' 'README.md'
    if ($LASTEXITCODE -ne 0) { throw 'Git add failed.' }
    & git commit -m 'archive: DINFORMATION V18 AutoCAD 2022 source/build candidate pending runtime'
    if ($LASTEXITCODE -ne 0) { throw 'Git commit failed.' }
    & git push origin HEAD:main
    if ($LASTEXITCODE -ne 0) { throw 'Git push main failed.' }
    Write-Host 'Uploaded source/build candidate to main; runtime remains NotVerified.'
}
