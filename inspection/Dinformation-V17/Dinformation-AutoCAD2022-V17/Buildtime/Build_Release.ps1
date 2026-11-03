param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$LogDir = Join-Path $Root 'log'
$BinDir = Join-Path $Root 'bin'
$ObjDir = Join-Path $Root 'obj'
$ProjectFile = Join-Path $Root 'Dinformation.csproj'
$AssetsFile = Join-Path $ObjDir 'project.assets.json'
$LogFile = Join-Path $LogDir 'Build-V17.log'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
if (Test-Path $LogFile) { Remove-Item -Force $LogFile }

function Write-Log([string]$Text) {
    $Text | Tee-Object -FilePath $LogFile -Append
}

function Stop-Build([string]$Text, [int]$Code = 1) {
    Write-Log $Text
    Write-Log ("ExitCode={0}" -f $Code)
    exit $Code
}



function Test-LispTooltipTemplate([string]$Path) {
    if (-not (Test-Path $Path)) { Stop-Build 'HARD STOP: missing Buildtime\Dinformation-Tooltip.lsp.tpl.' 18 }
    $bytes = [IO.File]::ReadAllBytes($Path)
    foreach ($b in $bytes) { if ($b -gt 127) { Stop-Build 'LISP TEMPLATE FAIL: template must be ASCII-only.' 18 } }
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    if (([regex]::Matches($text, '@@BOOTSTRAP@@')).Count -ne 1) { Stop-Build 'LISP TEMPLATE FAIL: bootstrap marker count must be exactly one.' 18 }
    foreach ($required in @('nentselp','dcad-dinf-dis','dcad-dinformation-getinfo','dcad-dinformation-reset','vl-acad-defun')) {
        if (-not $text.Contains($required)) { Stop-Build ('LISP TEMPLATE FAIL: missing ' + $required) 18 }
    }
    foreach ($forbidden in @('grread','add_solid','add_text')) {
        if ($text.Contains($forbidden)) { Stop-Build ('LISP TEMPLATE FAIL: display/loop token found: ' + $forbidden) 18 }
    }
    Write-Log '[PASS] LISP tooltip template: ASCII, bridge functions, no overlay/loop.'
}

function Test-LanguageCatalog([string]$Path) {
    if (-not (Test-Path $Path)) { Stop-Build 'HARD STOP: missing Buildtime\Language\lang.dat.' 19 }
    $blocks = @{}
    $current = $null
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = ([string]$raw).Trim()
        if ($line -match '^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$') {
            $current = [int]$Matches[1]
            if ($blocks.ContainsKey($current)) { Stop-Build ("LANGUAGE FAIL: duplicate Lang_{0}." -f $current) 19 }
            $blocks[$current] = @{}
            continue
        }
        if ($line -eq '-') { $current = $null; continue }
        if ($null -eq $current -or $line.Length -eq 0 -or $line.StartsWith('#') -or $line.StartsWith(';') -or $line.StartsWith('//')) { continue }
        $eq = $line.IndexOf('=')
        if ($eq -le 0) { continue }
        $key = $line.Substring(0,$eq).Trim()
        $value = $line.Substring($eq+1)
        if ($key.Length -eq 0) { continue }
        if ($blocks[$current].ContainsKey($key)) { Stop-Build ("LANGUAGE FAIL: duplicate key {0} in Lang_{1}." -f $key,$current) 19 }
        if ([string]::IsNullOrWhiteSpace($value)) { Stop-Build ("LANGUAGE FAIL: empty key {0} in Lang_{1}." -f $key,$current) 19 }
        $blocks[$current][$key] = $value
    }
    foreach ($id in 0..5) { if (-not $blocks.ContainsKey($id)) { Stop-Build ("LANGUAGE FAIL: missing Lang_{0}." -f $id) 19 } }
    $englishKeys = @($blocks[0].Keys | Sort-Object)
    foreach ($id in 1..5) {
        $keys = @($blocks[$id].Keys | Sort-Object)
        if ($keys.Count -ne $englishKeys.Count) { Stop-Build ("LANGUAGE FAIL: Lang_{0} key count differs from Lang_0." -f $id) 19 }
        for ($i=0; $i -lt $englishKeys.Count; $i++) {
            if ($keys[$i] -ne $englishKeys[$i]) { Stop-Build ("LANGUAGE FAIL: Lang_{0} key set differs at {1}." -f $id,$englishKeys[$i]) 19 }
            $key = $englishKeys[$i]
            $sig0 = (([regex]::Matches([string]$blocks[0][$key], '\{\d+[^}]*\}') | ForEach-Object { $_.Value } | Sort-Object) -join '|')
            $sigN = (([regex]::Matches([string]$blocks[$id][$key], '\{\d+[^}]*\}') | ForEach-Object { $_.Value } | Sort-Object) -join '|')
            if ($sig0 -ne $sigN) { Stop-Build ("LANGUAGE FAIL: placeholder mismatch at {0} in Lang_{1}." -f $key,$id) 19 }
        }
    }
    Write-Log ("LanguageFile={0}" -f $Path)
    Write-Log ("LanguageKeys={0}" -f $englishKeys.Count)
    Write-Log '[PASS] Language catalogue: 6 blocks, key parity and placeholder parity.'
}

$languageQa=Join-Path $Root 'Buildtime\Validate_Language.ps1'
if(-not(Test-Path $languageQa)){ Add-Content -LiteralPath $LogFile -Value 'HARD STOP: missing Buildtime\Validate_Language.ps1'; exit 19 }
$languageQaOutput=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $languageQa -Root $Root 2>&1); $languageQaExit=$LASTEXITCODE
$languageQaOutput|ForEach-Object{ Add-Content -LiteralPath $LogFile -Value ([string]$_); Write-Host ([string]$_) }
if($languageQaExit -ne 0){ Add-Content -LiteralPath $LogFile -Value ('LANGUAGE QA FAIL: validator returned '+$languageQaExit); exit 19 }
Write-Log '============================================================'
Write-Log 'Dinformation V17 - AutoCAD 2022 - Build Gate'
Write-Log '============================================================'
Write-Log 'AutoCADTargetVersion=2022'
Write-Log 'TargetFramework=net48'
Write-Log 'Configuration=Release'
Write-Log 'Platform=x64'
Write-Log ('BuildTime=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

Write-Log ''
Write-Log '[1/6] Checking project and Autodesk references...'
if (-not (Test-Path $ProjectFile)) {
    Stop-Build 'HARD STOP: Dinformation.csproj not found.' 10
}

$required = @('AcCoreMgd.dll','AcDbMgd.dll','AcMgd.dll')
$refDir = Join-Path $Root 'Reference'
foreach ($name in $required) {
    $path = Join-Path $refDir $name
    if (-not (Test-Path $path)) {
        Stop-Build "HARD STOP: missing Reference\$name" 11
    }
}

$extraRefs = Get-ChildItem -Path $refDir -File | Where-Object { $_.Name -notin $required }
if ($extraRefs) {
    Stop-Build ('HARD STOP: Reference must contain only 3 Autodesk DLLs. Extra=' + (($extraRefs.Name) -join ',')) 12
}

$assemblyVersions = @()
foreach ($name in $required) {
    $path = Join-Path $refDir $name
    try {
        $v = [Reflection.AssemblyName]::GetAssemblyName($path).Version
        $assemblyVersions += $v
        Write-Log ("Reference {0} AssemblyVersion={1}" -f $name,$v)
        if ($v.Major -ne 24) {
            Stop-Build "$name is not an AutoCAD 2022 managed assembly (expected major 24)." 13
        }
    }
    catch {
        Stop-Build ("HARD STOP: cannot read managed assembly identity for ${name}: " + $_.Exception.Message) 14
    }
}

$majorMinor = $assemblyVersions | ForEach-Object { "{0}.{1}" -f $_.Major,$_.Minor } | Select-Object -Unique
if ($majorMinor.Count -ne 1) {
    Stop-Build 'HARD STOP: Autodesk references are from mixed versions.' 15
}
Write-Log '[PASS] Project and references are valid.'

Write-Log ''
Write-Log '[LANG] Validating embedded language source...'
Test-LanguageCatalog (Join-Path $Root 'Buildtime\Language\lang.dat')
Test-LispTooltipTemplate (Join-Path $Root 'Buildtime\Dinformation-Tooltip.lsp.tpl')

Write-Log ''
Write-Log '[2/6] Locating MSBuild...'
$msbuild = $null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $found = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
    if ($found) { $msbuild = $found }
}
if (-not $msbuild) {
    $cmd = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if ($cmd) { $msbuild = $cmd.Source }
}
if (-not $msbuild) {
    Stop-Build 'HARD STOP: MSBuild not found. Install Visual Studio/Build Tools with .NET Framework 4.8 targeting pack.' 16
}
Write-Log ("MSBuild={0}" -f $msbuild)
Write-Log '[PASS] MSBuild found.'

Write-Log ''
Write-Log '[3/6] Restoring SDK project...'
Write-Log 'RestoreCommand=MSBuild Dinformation.csproj /t:Restore /p:Configuration=Release /p:Platform=x64'
$restoreOutput = @(& $msbuild $ProjectFile /nologo /t:Restore /p:Configuration=Release /p:Platform=x64 /v:minimal 2>&1)
$restoreExitCode = $LASTEXITCODE
$restoreOutput | ForEach-Object { Write-Log ([string]$_) }
Write-Log ("RestoreExitCode={0}" -f $restoreExitCode)
if ($restoreExitCode -ne 0) {
    Stop-Build "RESTORE FAIL: MSBuild returned $restoreExitCode" 20
}
Write-Log '[PASS] Restore completed.'

Write-Log ''
Write-Log '[4/6] Verifying project.assets.json...'
if (-not (Test-Path $AssetsFile)) {
    Stop-Build 'RESTORE FAIL: obj\project.assets.json was not created.' 21
}
Write-Log ("AssetsFile={0}" -f $AssetsFile)
Write-Log '[PASS] project.assets.json exists.'

Write-Log ''
Write-Log '[5/6] Building Release x64 / net48...'
if (Test-Path $BinDir) {
    Get-ChildItem -Path $BinDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
}
Write-Log 'BuildCommand=MSBuild Dinformation.csproj /t:Build /p:Configuration=Release /p:Platform=x64'
$buildOutput = @(& $msbuild $ProjectFile /nologo /t:Build /p:Configuration=Release /p:Platform=x64 /v:minimal 2>&1)
$buildExitCode = $LASTEXITCODE
$buildOutput | ForEach-Object { Write-Log ([string]$_) }

$warningCount = @($buildOutput | Select-String -Pattern '\bwarning\s+[A-Z]+[0-9]+').Count
$errorCount = @($buildOutput | Select-String -Pattern '\berror\s+[A-Z]+[0-9]+').Count
Write-Log ("CompilerWarningLines={0}" -f $warningCount)
Write-Log ("CompilerErrorLines={0}" -f $errorCount)
Write-Log ("BuildExitCode={0}" -f $buildExitCode)
if ($buildExitCode -ne 0) {
    Stop-Build "BUILD FAIL: MSBuild returned $buildExitCode" 30
}
Write-Log '[PASS] MSBuild completed.'

Write-Log ''
Write-Log '[6/6] Checking final output...'
$dll = Join-Path $BinDir 'DinformationC22.dll'
if (-not (Test-Path $dll)) {
    Stop-Build 'BUILD FAIL: bin\DinformationC22.dll was not created.' 31
}

$extraBin = Get-ChildItem -Path $BinDir -File | Where-Object { $_.Name -ne 'DinformationC22.dll' }
if ($extraBin) {
    Stop-Build ('BUILD FAIL: bin contains unexpected files: ' + (($extraBin.Name) -join ',')) 32
}

$builtVersion = [Reflection.AssemblyName]::GetAssemblyName($dll).Version
Write-Log ('AssemblyVersion=' + $builtVersion)
Write-Log ('OutputPath=' + $dll)
Write-Log ('ErrorCount=' + $errorCount)
Write-Log ('WarningCount=' + $warningCount)
Write-Log '[PASS] DinformationC22.dll verified.'
Write-Log 'BUILD PASS'
Write-Log 'NETLOAD=NotVerified'
exit 0
