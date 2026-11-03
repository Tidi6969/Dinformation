param([switch]$PublishCandidate)

$ErrorActionPreference = 'Stop'
$repoRoot = (Get-Location).Path
& git fetch origin main | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch main for V18 baseline.' }
$worktree = Join-Path $repoRoot '_v18origin'
& git worktree add --detach $worktree origin/main | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Cannot read V18 baseline from main.' }
$baselineZip = Join-Path $repoRoot '_v18_baseline_original.zip'
Copy-Item -LiteralPath (Join-Path $worktree 'V18/Dinformation-V18.zip') -Destination $baselineZip -Force
& git worktree remove --force $worktree | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Cannot release temporary V18 worktree.' }
if (-not (Test-Path -LiteralPath $baselineZip)) { throw 'Missing authoritative V18 baseline ZIP.' }
$stage = Join-Path $repoRoot '_v18stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
$sourceRoot = Join-Path $stage 'Dinformation-V18'
New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null
Expand-Archive -LiteralPath $baselineZip -DestinationPath $sourceRoot -Force
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'Dinformation-AutoCAD2022-V18'))) { throw 'V18 source archive missing target project.' }

$sourceHost = Join-Path $sourceRoot 'Dinformation-AutoCAD2022-V18'
$projectFiles = @('AssemblyInfo.cs','Dinformation.csproj','Build_Release.cmd','Buildtime/Build_Release.ps1','src/Core/DinformationCommands.cs','README.md','Data/BuildInfo.txt','Data/DataManifest.txt')
foreach ($rel in @('src/Information/InformationSession.cs','src/Core/LispInfoEngine.cs','Buildtime/Dinformation-Tooltip.lsp.tpl')) {
    $from = Join-Path $repoRoot (Join-Path 'AutoCAD2022-Patch' $rel)
    $to = Join-Path $sourceHost $rel
    if (!(Test-Path -LiteralPath $from) -or !(Test-Path -LiteralPath $to)) { throw "Source patch missing $rel" }
    Copy-Item -LiteralPath $from -Destination $to -Force
}
Rename-Item -LiteralPath $sourceRoot -NewName 'Dinformation-V19'
$package = Join-Path $stage 'Dinformation-V19'
Rename-Item -LiteralPath (Join-Path $package 'Dinformation-AutoCAD2022-V18') -NewName 'Dinformation-AutoCAD2022-V19'
$hostDir = Join-Path $package 'Dinformation-AutoCAD2022-V19'
foreach ($rel in $projectFiles) {
    $path = Join-Path $hostDir $rel
    if (!(Test-Path -LiteralPath $path)) { throw "Missing version metadata: $rel" }
    $src = [IO.File]::ReadAllText($path)
    $src = $src.Replace('V18','V19').Replace('18.0.0.0','19.0.0.0')
    [IO.File]::WriteAllText($path,$src,[Text.UTF8Encoding]::new($false))
}
foreach ($oldHost in @('Dinformation-AutoCAD2025-V18','Dinformation-GstarCAD2018-V18','Dinformation-GstarCAD2027-V18')) {
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
call :PRINT "TITLE" "Dinformation V19 - AutoCAD 2022"
call :PRINT "BUILD" "[BUILD] AutoCAD 2022 Release x64"
call "%~dp0Dinformation-AutoCAD2022-V19\Build_Release.cmd" /nopause >"log\AutoCAD2022.log" 2>&1
cd /d "%~dp0"
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" goto :FINISH
if not exist "Dinformation-AutoCAD2022-V19\bin\DinformationC22.dll" (
    set "RC=2"
    goto :FINISH
)
copy /Y "Dinformation-AutoCAD2022-V19\bin\DinformationC22.dll" "Dprogram\DinformationC22.dll" >nul
if errorlevel 1 (
    set "RC=3"
    goto :FINISH
)
set "RC=0"
:FINISH
>"log\Build_All.log" echo Dinformation V19 - AutoCAD 2022
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
# Dinformation V19 - AutoCAD 2022 SOURCE / PENDING CAD TEST

Baseline: V18. Target: AutoCAD 2022 only.
Source patch: native PointMonitor pick with LISP fallback and safe unknown-object metadata.
Build: PASS Release x64, framework net48, SDK Autodesk 24.1.
NETLOAD / real AutoCAD 2022 tooltip tests: NotVerified.
Standards / release approval: NotVerified / NO.
Dprogram/DinformationC22.dll was built from V19 source; reference SDK DLLs are build-time only.
GstarCAD 2018, AutoCAD 2025, GstarCAD 2027: outside this package and unchanged in archived V18.
This is a source/build candidate for user CAD testing, NOT a completed V19 release.
'@ | Set-Content -LiteralPath (Join-Path $package 'README.md') -Encoding utf8
$qaFile = Join-Path $repoRoot 'AutoCAD2022-Patch/QA-V19.md'
$qaTarget = Join-Path $hostDir 'Userdata'
if (!(Test-Path -LiteralPath $qaTarget)) { New-Item -ItemType Directory -Path $qaTarget | Out-Null }
$legacyQa = Join-Path $qaTarget 'QA-V18.md'
if (Test-Path -LiteralPath $legacyQa) { Remove-Item -LiteralPath $legacyQa -Force }
Copy-Item -LiteralPath $qaFile -Destination (Join-Path $qaTarget 'QA-V19.md') -Force
foreach ($oldOutput in @((Join-Path $package 'log'),(Join-Path $hostDir 'log'),(Join-Path $hostDir 'bin'),(Join-Path $hostDir 'obj'))) {
    if (Test-Path -LiteralPath $oldOutput) { Remove-Item -LiteralPath $oldOutput -Recurse -Force }
}
@'
Dinformation V19 package changelog
Baseline=V18
Change=Clear old V17 audit metadata; rebuild V19, AutoCAD2022 only.
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
'@ | Set-Content -LiteralPath (Join-Path $rootData 'CHANGELOG.txt') -Encoding utf8

Write-Host 'Building V19 via package root Build_All.cmd ...'
Push-Location $package
try {
    & cmd.exe /c 'Build_All.cmd /nopause'
    $buildExit = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($buildExit -ne 0) {
    foreach ($diagPath in @((Join-Path $package 'log/Build_All.log'),(Join-Path $package 'log/AutoCAD2022.log'),(Join-Path $hostDir 'log/Build-V19.log'))) {
        if (Test-Path -LiteralPath $diagPath) {
            Write-Host "DIAGNOSTIC: $diagPath"
            Get-Content -LiteralPath $diagPath -Tail 70 | ForEach-Object { Write-Host $_ }
        }
    }
    throw "HARD STOP: V19 build failed, exit=$buildExit"
}
$dll = Join-Path $hostDir 'bin/DinformationC22.dll'
$portableDll = Join-Path $oldDprogram 'DinformationC22.dll'
if (!(Test-Path $dll) -or !(Test-Path $portableDll)) { throw 'HARD STOP: new compiled DLL missing.' }
if ([Reflection.AssemblyName]::GetAssemblyName($dll).Version.ToString() -ne '19.0.0.0') { throw 'Assembly version mismatch, expected V19.' }
if ((Get-FileHash $dll -Algorithm SHA256).Hash -ne (Get-FileHash $portableDll -Algorithm SHA256).Hash) { throw 'Portable DLL is not identical to new build.' }

$buildInfo = Join-Path $hostDir 'Data/BuildInfo.txt'
$oldBuildInfo = [IO.File]::ReadAllText($buildInfo)
$marker = $oldBuildInfo.IndexOf('Module=Dinformation')
if ($marker -ge 0) { $oldBuildInfo = $oldBuildInfo.Substring(0,$marker).TrimEnd() + [Environment]::NewLine }
[IO.File]::WriteAllText($buildInfo,$oldBuildInfo,[Text.UTF8Encoding]::new($false))
@'
Module=Dinformation
Repository=Tidi6969/Dinformation
BaselineVersion=V18
MaximumStoredBeforeUpdate=V18
PlannedVersion=V19
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
# Old source candidate carried obsolete V17 root audit files. They are
# historical artifacts, not current V19 package metadata; remove them here.
Get-ChildItem -LiteralPath $rootData -File | Remove-Item -Force
@'
DINFORMATION V19 - SOURCE/BUILD CANDIDATE, NOT A COMPLETED RELEASE
Baseline V18 original ZIP: untouched.
CAD Target AutoCAD2022 ONLY.
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
NETLOAD=NotVerified
Cursor/hover responsiveness=NotVerified
Color console visual inspection=NotVerified
Other CAD hosts in baseline V18=Unmodified, not in V19 package.
'@ | Set-Content -LiteralPath (Join-Path $rootData 'BUILD-STATUS.txt') -Encoding utf8
$rootLog=Join-Path $package 'log'
if (!(Test-Path $rootLog)) { throw 'Root log missing' }
$projectObj=Join-Path $hostDir 'obj'
if (Test-Path -LiteralPath $projectObj) { Remove-Item -LiteralPath $projectObj -Recurse -Force }
$packZipDir=Join-Path $repoRoot '_v18prepared'
if (!(Test-Path -LiteralPath $packZipDir)) { New-Item -ItemType Directory -Path $packZipDir | Out-Null }
$archive=Join-Path $packZipDir 'Dinformation-V19.zip'
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive -CompressionLevel Optimal

Add-Type -AssemblyName System.IO.Compression
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entries=@($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
    $needed=@('Build_All.cmd','Dprogram/DinformationC22.dll','Dinformation-AutoCAD2022-V19/bin/DinformationC22.dll','Dinformation-AutoCAD2022-V19/Dinformation.csproj','Dinformation-AutoCAD2022-V19/src/Information/InformationSession.cs','Dinformation-AutoCAD2022-V19/Buildtime/Dinformation-Tooltip.lsp.tpl','Dinformation-AutoCAD2022-V19/Reference/AcMgd.dll','Data/BUILD-STATUS.txt')
    foreach ($neededFile in $needed) { if ($entries -notcontains $neededFile) { throw "ZIP missing $neededFile" } }
    foreach ($e in $zip.Entries) {
        if ($e.FullName -match '(GstarCAD2018|AutoCAD2025|GstarCAD2027)') { throw "Unexpected CAD host in V19 package: $($e.FullName)" }
        if ($e.FullName -match '^Data/.*V(17|18)') { throw "Stale root package metadata: $($e.FullName)" }
        if ($e.Name -ne '') { $read=$e.Open(); try { $read.CopyTo([IO.Stream]::Null) } finally { $read.Dispose() } }
    }
} finally {
    $zip.Dispose()
}
$checksum=(Get-FileHash $archive -Algorithm SHA256).Hash
$length=(Get-Item $archive).Length
Write-Host "V19 ZIP: byteLength=$length sha256=$checksum; Build PASS; Runtime NotVerified; ReleaseApproved=NO"

$changelog=@"
Dinformation V19
Module=Dinformation
Repository=Tidi6969/Dinformation
Baseline=V18
MaxStoredBefore=V18
TargetVersion=V19
VersionReason=STD-17 default +1
CADTargets=AutoCAD2022
VersionType=SOURCE/BUILD CANDIDATE - PENDING CAD RUNTIME TEST
BuildStatus=PASS
RuntimeStatus=NotVerified
StandardsStatus=NotVerified
ReleaseApproved=NO
VersionAssembly=19.0.0.0
BuildSDK=Autodesk AcCoreMgd/AcDbMgd/AcMgd 24.1, net48, x64
FilesChanged=InformationSession.cs; LispInfoEngine.cs; Dinformation-Tooltip.lsp.tpl; required V19 packaging metadata/scripts
Summary=Native-picked-object cache avoids repeating LISP hit tests. Original LISP nentselp fallback is immediate when native picker misses. Unsupported property reader returns DXF type/layer/handle.
Preserved=All GstarCAD 2018, AutoCAD 2025, GstarCAD 2027 originals in V18; geometry/settings/XData/language/command remain unchanged.
KnownIssues=Real AutoCAD 2022 NETLOAD, speed, entity coverage, nested blocks/proxies, ESC, UCS, visual build console and six languages NotVerified. Not a completed release.
ArchiveSha256=$checksum
ArchiveSize=$length
"@
$changelogPath=Join-Path $packZipDir 'V19.txt'
[IO.File]::WriteAllText($changelogPath,$changelog,[Text.UTF8Encoding]::new($false))

if ($PublishCandidate) {
    & git fetch origin main | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch current main branch for release conflict check.' }
    $already=& git ls-tree --name-only origin/main -- V19
    if ($already) { throw 'HARD STOP: V19 already exists on main. No overwrite.' }
    & git switch -c dcad-v18-candidate-publish origin/main | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create publishing worktree.' }
    $destDir=Join-Path $repoRoot 'V19'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    Copy-Item $archive (Join-Path $destDir 'Dinformation-V19.zip') -Force
    $logDir=Join-Path $repoRoot 'Change log'
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    Copy-Item $changelogPath (Join-Path $logDir 'V19.txt') -Force
    $repoReadme=@'
# Dinformation

Latest saved: **V19 — source/build candidate pending AutoCAD 2022 test**, baseline V18.
Target: AutoCAD 2022 ONLY. Build PASS (.NET Framework 4.8, Autodesk SDK 24.1); NETLOAD/Runtime/Standards NotVerified; RELEASE_APPROVED=NO.
Stable/accepted version: Not confirmed.
Download candidate for CAD runtime testing: [Dinformation-V19.zip](V19/Dinformation-V19.zip)
Change log: [V19](Change%20log/V19.txt)
V18 baseline: [Dinformation-V18.zip](V18/Dinformation-V18.zip) (unchanged).
Other CAD targets are unchanged in baseline V18 and not rebuilt for V19.
'@
    [IO.File]::WriteAllText((Join-Path $repoRoot 'README.md'),$repoReadme,[Text.UTF8Encoding]::new($false))
    & git config user.name 'github-actions[bot]'
    & git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    & git add 'V19/Dinformation-V19.zip' 'Change log/V19.txt' 'README.md'
    if ($LASTEXITCODE -ne 0) { throw 'Git add failed.' }
    & git commit -m 'archive: DINFORMATION V19 AutoCAD 2022 source/build candidate pending runtime'
    if ($LASTEXITCODE -ne 0) { throw 'Git commit failed.' }
    & git push origin HEAD:main
    if ($LASTEXITCODE -ne 0) { throw 'Git push main failed.' }
    Write-Host 'Uploaded source/build candidate to main; runtime remains NotVerified.'
}
