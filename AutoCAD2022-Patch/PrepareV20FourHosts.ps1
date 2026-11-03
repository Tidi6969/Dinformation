param([switch]$Publish)
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
& git fetch origin main | Out-Host
if($LASTEXITCODE -ne 0){throw 'Cannot fetch baseline'}
if((& git ls-tree --name-only origin/main -- V20) -eq 'V20'){throw 'HARD STOP: V20 exists'}
$tmp=Join-Path $root '_origmain20'
& git worktree add --detach $tmp origin/main | Out-Host
if($LASTEXITCODE -ne 0){throw 'Cannot open main'}
try {
  $z17=Join-Path $tmp 'V17/Dinformation-V17.zip'
  $z19=Join-Path $tmp 'V19/Dinformation-V19.zip'
  if(!(Test-Path $z17) -or !(Test-Path $z19)){throw 'Missing V17 or V19 ZIP'}
  $old=Join-Path $root '_old20'
  $new=Join-Path $root '_new20'
  foreach($p in @($old,$new)){if(Test-Path $p){Remove-Item $p -Force -Recurse};New-Item -ItemType Directory -Path $p|Out-Null}
  Expand-Archive -LiteralPath $z17 -DestinationPath $old -Force
  Expand-Archive -LiteralPath $z19 -DestinationPath $new -Force
} finally {
  & git worktree remove --force $tmp | Out-Host
}
$stage=Join-Path $root '_stage20'
if(Test-Path $stage){Remove-Item $stage -Force -Recurse}
$pkg=Join-Path $stage 'Dinformation-V20'
New-Item -ItemType Directory -Path $pkg -Force|Out-Null
$targets=@(
  @{host='AutoCAD2022'; ver='V19'; dll='DinformationC22.dll'},
  @{host='AutoCAD2025'; ver='V17'; dll='DinformationC25.dll'},
  @{host='GstarCAD2018'; ver='V17'; dll='DinformationG18.dll'},
  @{host='GstarCAD2027'; ver='V17'; dll='DinformationG27.dll'}
)
foreach($t in $targets){
  $targetName=$t.host;$ver=$t.ver
  $src=if($targetName -eq 'AutoCAD2022'){Join-Path $new ('Dinformation-'+$targetName+'-V19')}else{Join-Path (Join-Path $old 'Dinformation-V17') ('Dinformation-'+$targetName+'-V17')}
  $dst=Join-Path $pkg ('Dinformation-'+$targetName+'-V20')
  if(!(Test-Path $src)){throw ('Missing source '+$src)}
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  # Preserve source of the three other hosts byte-for-byte; version metadata only.
  if($targetName -ne 'AutoCAD2022'){
    $files=@(Get-ChildItem -LiteralPath (Join-Path $src 'src') -Recurse -File)
    foreach($f in $files){
      $rel=$f.FullName.Substring($src.Length+1)
      $other=Join-Path $dst $rel
      if(!(Test-Path $other) -or (Get-FileHash $f.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $other -Algorithm SHA256).Hash){
        throw ('Host source changed '+$targetName+'/'+$rel)
      }
    }
  }
  foreach($rel in @('AssemblyInfo.cs','Dinformation.csproj','Build_Release.cmd','Buildtime/Build_Release.ps1','README.md','Data/BuildInfo.txt','Data/DataManifest.txt')){
    $p=Join-Path $dst $rel
    if(!(Test-Path $p)){throw ('Missing '+$p)}
    $c=[IO.File]::ReadAllText($p)
    $c=$c.Replace('V17','V20').Replace('V19','V20').Replace('17.0.0.0','20.0.0.0').Replace('19.0.0.0','20.0.0.0')
    if($targetName -eq 'GstarCAD2018' -and $rel -eq 'Build_Release.cmd'){$c=$c.Replace('powershell.exe -NoProfile','pwsh.exe -NoProfile')}
    if($rel -eq 'Data/BuildInfo.txt'){
      $cut=$c.IndexOf('Module=Dinformation')
      if($cut -ge 0){$c=$c.Substring(0,$cut)}
      $c+=@'
Module=Dinformation
PackageVersion=V20
MaxStoredBefore=V19
BuildStatus=PASS
RuntimeStatus=NotVerified
ReleaseApproved=NO
'@
    }
    [IO.File]::WriteAllText($p,$c,[Text.UTF8Encoding]::new($false))
  }
  foreach($part in @('bin','log','obj')){
    $p=Join-Path $dst $part
    if(Test-Path $p){Remove-Item $p -Recurse -Force}
  }
  $qa=Join-Path $dst 'Userdata'
  New-Item -ItemType Directory -Path $qa -Force | Out-Null
  Get-ChildItem -LiteralPath $qa -File | Where-Object {$_.Name -match '^QA-V(17|18|19)'} | Remove-Item -Force
  @'
QA DINFORMATION V20
NETLOAD=NotVerified
RuntimeStatus=NotVerified
ReleaseApproved=NO
'@ | Set-Content -LiteralPath (Join-Path $qa 'QA-V20.txt') -Encoding utf8
}
# Root Build_All: all 4 hosts run independently, and the shared DLL folder is
# published only if every host produced a fresh DLL.
$batch=@'
@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "ROOT=%~dp0"
if not exist "log" mkdir "log"
if not exist "Dprogram" mkdir "Dprogram"
del /q "Dprogram\*.dll" 2>nul
set "FAILED=0"
call :STEP AutoCAD2022 DinformationC22.dll
call :STEP AutoCAD2025 DinformationC25.dll
call :STEP GstarCAD2018 DinformationG18.dll
call :STEP GstarCAD2027 DinformationG27.dll
if not "!FAILED!"=="0" goto :FAIL
copy /Y "Dinformation-AutoCAD2022-V20\bin\DinformationC22.dll" "Dprogram\DinformationC22.dll" >nul
if errorlevel 1 set "FAILED=1"
copy /Y "Dinformation-AutoCAD2025-V20\bin\DinformationC25.dll" "Dprogram\DinformationC25.dll" >nul
if errorlevel 1 set "FAILED=1"
copy /Y "Dinformation-GstarCAD2018-V20\bin\DinformationG18.dll" "Dprogram\DinformationG18.dll" >nul
if errorlevel 1 set "FAILED=1"
copy /Y "Dinformation-GstarCAD2027-V20\bin\DinformationG27.dll" "Dprogram\DinformationG27.dll" >nul
if errorlevel 1 set "FAILED=1"
if not "!FAILED!"=="0" goto :FAIL
set "RETURN_RC=0"
call :REPORT PASS "[PASS] Dinformation V20: four CAD builds"
goto :FINISH
:FAIL
set "RETURN_RC=1"
del /q "Dprogram\*.dll" 2>nul
call :REPORT FAIL "[FAIL] HARD STOP: one or more CAD builds failed"
:FINISH
>"log\Build_All.log" echo Dinformation V20 FOUR HOSTS
>>"log\Build_All.log" echo AutoCAD2022=!S_AutoCAD2022!
>>"log\Build_All.log" echo AutoCAD2025=!S_AutoCAD2025!
>>"log\Build_All.log" echo GstarCAD2018=!S_GstarCAD2018!
>>"log\Build_All.log" echo GstarCAD2027=!S_GstarCAD2027!
>>"log\Build_All.log" echo ExitCode=!RETURN_RC!
>>"log\Build_All.log" echo NETLOAD=NotVerified
if /I not "%~1"=="/nopause" (
  echo Nhan phim bat ky de thoat...
  pause >nul
)
set "EXIT=!RETURN_RC!"
endlocal & exit /b %EXIT%
:STEP
call :REPORT BUILD "[BUILD] %~1"
if not exist "%ROOT%Dinformation-%~1-V20\Build_Release.cmd" (
  set "E=90"
) else (
  call "%ROOT%Dinformation-%~1-V20\Build_Release.cmd" /nopause >"%ROOT%log\%~1.log" 2>&1
  set "E=!ERRORLEVEL!"
)
cd /d "%ROOT%"
if "!E!"=="0" (
  if not exist "Dinformation-%~1-V20\bin\%~2" set "E=91"
)
if "!E!"=="0" (
  set "S_%~1=PASS"
  call :REPORT PASS "[PASS] %~1"
) else (
  set "S_%~1=FAIL !E!"
  set "FAILED=1"
  call :REPORT FAIL "[FAIL] %~1"
)
exit /b 0
:REPORT
if defined NO_COLOR (
  echo %~2
  exit /b 0
)
set "FC=Gray"
if /I "%~1"=="BUILD" set "FC=Blue"
if /I "%~1"=="PASS" set "FC=Green"
if /I "%~1"=="FAIL" set "FC=Red"
powershell.exe -NoProfile -Command "Write-Host '%~2' -ForegroundColor %FC%" 2>nul
if errorlevel 1 echo %~2
exit /b 0
'@
[IO.File]::WriteAllText((Join-Path $pkg 'Build_All.cmd'),$batch,[Text.Encoding]::ASCII)
@'
DINFORMATION V20 - 4 HOST SOURCE / BUILD CANDIDATE
AutoCAD 2022 has the recognition improvements from V19.
AutoCAD 2025, GstarCAD 2018 and GstarCAD 2027 source retained from V17.
All four hosts build separately using their host-specific Reference/SDK.
NETLOAD and CAD runtime tests remain NotVerified; ReleaseApproved=NO.
'@|Set-Content -LiteralPath (Join-Path $pkg 'README.txt') -Encoding utf8
$data=Join-Path $pkg 'Data'
New-Item -ItemType Directory -Path $data -Force|Out-Null
@'
Package=V20
Baseline=V19
AutoCAD2022=Build pending
AutoCAD2025=Build pending
GstarCAD2018=Build pending
GstarCAD2027=Build pending
NETLOAD=NotVerified
RuntimeStatus=NotVerified
ReleaseApproved=NO
'@|Set-Content -LiteralPath (Join-Path $data 'BUILD-STATUS.txt') -Encoding utf8
Push-Location $pkg
try{& cmd.exe /c 'Build_All.cmd /nopause';$rc=$LASTEXITCODE}finally{Pop-Location}
if($rc -ne 0){
  foreach($n in @('Build_All.log','AutoCAD2022.log','AutoCAD2025.log','GstarCAD2018.log','GstarCAD2027.log')){
    $log=Join-Path (Join-Path $pkg 'log') $n
    if(Test-Path $log){Write-Host ('LOG '+$n);Get-Content $log -Tail 35|ForEach-Object{Write-Host $_}}
  }
  throw ('HARD STOP: Build_All failed '+$rc)
}
$dprogram=Join-Path $pkg 'Dprogram'
foreach($t in $targets){
  $dll=$t.dll
  $src=Join-Path (Join-Path $pkg ('Dinformation-'+$t.host+'-V20')) ('bin/'+$dll)
  $shared=Join-Path $dprogram $dll
  if(!(Test-Path $src) -or !(Test-Path $shared)){throw ('Missing rebuilt '+$dll)}
  if((Get-FileHash $src -Algorithm SHA256).Hash -ne (Get-FileHash $shared -Algorithm SHA256).Hash){throw ('Portable DLL mismatch '+$dll)}
  $version=[Reflection.AssemblyName]::GetAssemblyName($src).Version.ToString()
  if($version -ne '20.0.0.0'){throw ('Wrong version '+$dll+' '+$version)}
  $obj=Join-Path (Join-Path $pkg ('Dinformation-'+$t.host+'-V20')) 'obj'
  if(Test-Path $obj){Remove-Item $obj -Recurse -Force}
}
@'
Package=V20
AutoCAD2022=Build PASS
AutoCAD2025=Build PASS
GstarCAD2018=Build PASS
GstarCAD2027=Build PASS
NETLOAD=NotVerified
RuntimeStatus=NotVerified
ReleaseApproved=NO
'@|Set-Content -LiteralPath (Join-Path $data 'BUILD-STATUS.txt') -Encoding utf8
$out=Join-Path $root '_ready20'
New-Item -ItemType Directory -Path $out -Force|Out-Null
$archive=Join-Path $out 'Dinformation-V20.zip'
Compress-Archive -Path (Join-Path $pkg '*') -DestinationPath $archive -CompressionLevel Optimal -Force
Add-Type -AssemblyName System.IO.Compression
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try {
  $names=@($zip.Entries|ForEach-Object{$_.FullName.Replace('\','/')})
  foreach($t in $targets){
    $p='Dinformation-'+$t.host+'-V20/'
    foreach($n in @('Dinformation.csproj','Build_Release.cmd','AssemblyInfo.cs',('bin/'+$t.dll))){
      if($names -notcontains ($p+$n)){throw ('ZIP missing '+$p+$n)}
    }
    if($names -notcontains ('Dprogram/'+$t.dll)){throw ('ZIP missing portable '+$t.dll)}
  }
  foreach($e in $zip.Entries){if($e.Name){$s=$e.Open();try{$s.CopyTo([IO.Stream]::Null)}finally{$s.Dispose()}}}
}finally{$zip.Dispose()}
$hash=(Get-FileHash $archive -Algorithm SHA256).Hash
$size=(Get-Item $archive).Length
Write-Host ('ZIP PASS '+$size+' sha256='+$hash)
$changes=@"
DINFORMATION V20
Baseline=V19
VersionRule=STD-17 max+1
CADTargets=AutoCAD2022,AutoCAD2025,GstarCAD2018,GstarCAD2027
Reason=Restore 3 CAD branches omitted by packaging, not requested to delete.
ChangedCode=AutoCAD2022 (from V19), other 3 host src identical to V17.
BuildStatus=PASS (each host independently built with its own SDK)
RuntimeStatus=NotVerified
NETLOAD=NotVerified
ReleaseApproved=NO
ArchiveSHA256=$hash
ArchiveSize=$size
"@
$changeFile=Join-Path $out 'V20.txt'
[IO.File]::WriteAllText($changeFile,$changes,[Text.UTF8Encoding]::new($false))
if($Publish){
  & git fetch origin main | Out-Host
  if($LASTEXITCODE -ne 0){throw 'Main fetch failed'}
  if((& git ls-tree --name-only origin/main -- V20) -eq 'V20'){throw 'HARD STOP: V20 exists; no overwrite'}
  & git switch -c dcad-release-v20 origin/main | Out-Host
  if($LASTEXITCODE -ne 0){throw 'Cannot create version branch'}
  New-Item -ItemType Directory -Path (Join-Path $root 'V20') -Force|Out-Null
  Copy-Item $archive (Join-Path $root 'V20/Dinformation-V20.zip') -Force
  Copy-Item $changeFile (Join-Path $root 'Change log/V20.txt') -Force
  @'
# Dinformation
Latest saved: **V20 — four-host source/build candidate**, baseline V19.
[Download Dinformation-V20.zip](V20/Dinformation-V20.zip)
[Changelog V20](Change%20log/V20.txt)
CAD branches: AutoCAD2022, AutoCAD2025, GstarCAD2018, GstarCAD2027.
Only the AutoCAD2022 recognition source was modified; the other 3 hosts'
functional code is identical to V17. All 4 rebuilt using separate SDKs.
Build PASS; NETLOAD/Runtime/Standards NotVerified; ReleaseApproved=NO.
CAD acceptance: Chua xac nhan.
Historical V17/V18/V19 ZIPs and changelogs remain available.
'@|Set-Content -LiteralPath (Join-Path $root 'README.md') -Encoding utf8
  & git config user.name 'github-actions[bot]'
  & git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  & git add 'V20/Dinformation-V20.zip' 'Change log/V20.txt' 'README.md'
  & git commit -m 'archive: DINFORMATION V20 four-host ZIP with C22-only behavior changes'
  if($LASTEXITCODE -ne 0){throw 'Git commit failed'}
  & git push origin HEAD:main
  if($LASTEXITCODE -ne 0){throw 'Git push failed'}
}
