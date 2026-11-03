param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$LogDir = Join-Path $Root 'log'
$BinDir = Join-Path $Root 'bin'
$ObjDir = Join-Path $Root 'obj'
$ProjectFile = Join-Path $Root 'Dinformation.csproj'
$SolutionFile = Join-Path $Root 'Dinformation.sln'
$LogFile = Join-Path $LogDir 'Build-V17.log'
New-Item -ItemType Directory -Force -Path $LogDir,$BinDir | Out-Null
if (Test-Path $LogFile) { Remove-Item -Force $LogFile }
function L([string]$s) { $s | Out-File -LiteralPath $LogFile -Append -Encoding utf8 }
function StopBuild([string]$s,[int]$c=1) { L $s; L ("ExitCode={0}" -f $c); exit $c }
function TestLanguage([string]$Path) {
  if (-not (Test-Path $Path)) { StopBuild 'HARD STOP: missing Buildtime\Language\lang.dat.' 19 }
  $blocks=@{}; $current=$null
  foreach($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
    $line=([string]$raw).Trim()
    if($line -match '^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$') { $current=[int]$Matches[1]; if($blocks.ContainsKey($current)){StopBuild ("LANGUAGE FAIL: duplicate Lang_{0}." -f $current) 19}; $blocks[$current]=@{}; continue }
    if($line -eq '-') { $current=$null; continue }
    if($null -eq $current -or $line.Length -eq 0 -or $line.StartsWith('#') -or $line.StartsWith(';') -or $line.StartsWith('//')) { continue }
    $eq=$line.IndexOf('='); if($eq -le 0){continue}; $key=$line.Substring(0,$eq).Trim(); $value=$line.Substring($eq+1)
    if($blocks[$current].ContainsKey($key)){StopBuild ("LANGUAGE FAIL: duplicate key {0} in Lang_{1}." -f $key,$current) 19}
    if([string]::IsNullOrWhiteSpace($value)){StopBuild ("LANGUAGE FAIL: empty key {0} in Lang_{1}." -f $key,$current) 19}
    $blocks[$current][$key]=$value
  }
  foreach($id in 0..5){if(-not $blocks.ContainsKey($id)){StopBuild ("LANGUAGE FAIL: missing Lang_{0}." -f $id) 19}}
  $keys0=@($blocks[0].Keys | Sort-Object)
  foreach($id in 1..5){$keys=@($blocks[$id].Keys | Sort-Object); if($keys.Count -ne $keys0.Count){StopBuild ("LANGUAGE FAIL: Lang_{0} key count differs." -f $id) 19}; for($i=0;$i -lt $keys0.Count;$i++){if($keys[$i] -ne $keys0[$i]){StopBuild ("LANGUAGE FAIL: key set differs in Lang_{0}." -f $id) 19}; $k=$keys0[$i]; $a=(([regex]::Matches([string]$blocks[0][$k],'\{\d+[^}]*\}')|%{$_.Value}|Sort-Object)-join '|'); $b=(([regex]::Matches([string]$blocks[$id][$k],'\{\d+[^}]*\}')|%{$_.Value}|Sort-Object)-join '|'); if($a -ne $b){StopBuild ("LANGUAGE FAIL: placeholder mismatch at {0}/Lang_{1}." -f $k,$id) 19}}}
  L ("LanguageKeys={0}" -f $keys0.Count); L '[PASS] Language catalogue.'
}
$languageQa=Join-Path $Root 'Buildtime\Validate_Language.ps1'
if(-not(Test-Path $languageQa)){ Add-Content -LiteralPath $LogFile -Value 'HARD STOP: missing Buildtime\Validate_Language.ps1'; exit 19 }
$languageQaOutput=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $languageQa -Root $Root 2>&1); $languageQaExit=$LASTEXITCODE
$languageQaOutput|ForEach-Object{ Add-Content -LiteralPath $LogFile -Value ([string]$_); Write-Host ([string]$_) }
if($languageQaExit -ne 0){ Add-Content -LiteralPath $LogFile -Value ('LANGUAGE QA FAIL: validator returned '+$languageQaExit); exit 19 }
L '============================================================'
L 'Dinformation V17 - GstarCAD 2018 - Build Gate'
L '============================================================'
L 'GstarCADTargetVersion=2018'; L 'TargetFramework=v4.8'; L 'Configuration=Release'; L 'Platform=x64'; L ('BuildTime='+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
L '[1/5] Checking project, references, language and LISP template...'
if(-not (Test-Path $ProjectFile)){StopBuild 'HARD STOP: Dinformation.csproj not found.' 10}
$expected=@{'gmap.dll'='1bee8db4d300d6f64ebec7ba4046d0edc47a8b626f246a8fd7dac58fc836c15c';'gmdb.dll'='bc764cea1b2836bc84c79bb85f671f827b6929f66ca9685bab6a144948774eae'}
foreach($name in $expected.Keys){$p=Join-Path $Root ('Reference\'+$name);if(-not(Test-Path $p)){StopBuild ('HARD STOP: missing Reference\'+$name) 11};$h=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant();L ("{0} SHA256={1}" -f $name,$h);if($h -ne $expected[$name]){StopBuild ('HARD STOP: '+$name+' does not match DPrint-GstarCAD2018-V17 reference set.') 12}}
$extra=Get-ChildItem (Join-Path $Root 'Reference') -File | ?{$_.Name -notin @('gmap.dll','gmdb.dll')};if($extra){StopBuild ('HARD STOP: Reference contains extra files: '+(($extra.Name)-join ',')) 13}
TestLanguage (Join-Path $Root 'Buildtime\Language\lang.dat')
$template=Join-Path $Root 'Buildtime\Dinformation-GstarCAD2018.lsp.tpl';if(-not(Test-Path $template)){StopBuild 'HARD STOP: missing embedded LISP template.' 14};$bytes=[IO.File]::ReadAllBytes($template);if(($bytes|?{$_ -gt 127}).Count -gt 0){StopBuild 'HARD STOP: LISP template must be ASCII-only.' 15};L '[PASS] Inputs/reference hashes/language/template.'
L '[2/5] Locating MSBuild...'
$msbuild=$null;$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe';if(Test-Path $vswhere){$found=& $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null|Select-Object -First 1;if($found){$msbuild=$found}}
if(-not $msbuild){$cmd=Get-Command msbuild.exe -ErrorAction SilentlyContinue;if($cmd){$msbuild=$cmd.Source}}
if(-not $msbuild){StopBuild 'HARD STOP: MSBuild not found. Install Visual Studio/Build Tools + .NET Framework 4.8 targeting pack.' 16};L ('MSBuild='+$msbuild);L '[PASS] MSBuild found.'
L '[3/5] Cleaning obj/bin...';if(Test-Path $ObjDir){Remove-Item $ObjDir -Recurse -Force};Get-ChildItem $BinDir -File -ErrorAction SilentlyContinue|Remove-Item -Force;L '[PASS] Clean.'
L '[4/5] Building classic .NET Framework project...';$out=@(& $msbuild $SolutionFile /nologo /t:Rebuild /p:Configuration=Release /p:Platform=x64 /m /v:minimal 2>&1);$rc=$LASTEXITCODE;$out|%{L ([string]$_)};L ('BuildExitCode='+$rc);if($rc -ne 0){StopBuild ('BUILD FAIL: MSBuild returned '+$rc) 30}
L '[5/5] Checking final output...';$dll=Join-Path $BinDir 'DinformationG18.dll';if(-not(Test-Path $dll)){StopBuild 'BUILD FAIL: bin\DinformationG18.dll was not created.' 31};$extraBin=Get-ChildItem $BinDir -File|?{$_.Name -ne 'DinformationG18.dll'};if($extraBin){StopBuild ('BUILD FAIL: bin contains unexpected files: '+(($extraBin.Name)-join ',')) 32};$ver=[Reflection.AssemblyName]::GetAssemblyName($dll).Version;L ('AssemblyVersion='+$ver);L ('OutputPath='+$dll);L '[PASS] DinformationG18.dll verified.';L 'BUILD PASS';L 'NETLOAD=NotVerified';exit 0
