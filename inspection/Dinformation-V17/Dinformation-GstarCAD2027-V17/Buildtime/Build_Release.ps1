param()
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$LogDir=Join-Path $Root 'log'; $BinDir=Join-Path $Root 'bin'; $ObjDir=Join-Path $Root 'obj'; $ProjectFile=Join-Path $Root 'Dinformation.csproj'; $AssetsFile=Join-Path $ObjDir 'project.assets.json'; $LogFile=Join-Path $LogDir 'Build-V17.log'
New-Item -ItemType Directory -Force -Path $LogDir,$BinDir | Out-Null
if(Test-Path $LogFile){Remove-Item -Force $LogFile}
function L([string]$s){$s|Tee-Object -FilePath $LogFile -Append}
function Fail([string]$s,[int]$c=1){L $s; L ("ExitCode={0}" -f $c); exit $c}

function Test-LanguageCatalog([string]$Path) {
    if (-not (Test-Path $Path)) { Fail 'HARD STOP: missing Buildtime\Language\lang.dat.' 19 }
    $blocks = @{}
    $current = $null
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = ([string]$raw).Trim()
        if ($line -match '^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$') {
            $current = [int]$Matches[1]
            if ($blocks.ContainsKey($current)) { Fail ("LANGUAGE FAIL: duplicate Lang_{0}." -f $current) 19 }
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
        if ($blocks[$current].ContainsKey($key)) { Fail ("LANGUAGE FAIL: duplicate key {0} in Lang_{1}." -f $key,$current) 19 }
        if ([string]::IsNullOrWhiteSpace($value)) { Fail ("LANGUAGE FAIL: empty key {0} in Lang_{1}." -f $key,$current) 19 }
        $blocks[$current][$key] = $value
    }
    foreach ($id in 0..5) { if (-not $blocks.ContainsKey($id)) { Fail ("LANGUAGE FAIL: missing Lang_{0}." -f $id) 19 } }
    $englishKeys = @($blocks[0].Keys | Sort-Object)
    foreach ($id in 1..5) {
        $keys = @($blocks[$id].Keys | Sort-Object)
        if ($keys.Count -ne $englishKeys.Count) { Fail ("LANGUAGE FAIL: Lang_{0} key count differs from Lang_0." -f $id) 19 }
        for ($i=0; $i -lt $englishKeys.Count; $i++) {
            if ($keys[$i] -ne $englishKeys[$i]) { Fail ("LANGUAGE FAIL: Lang_{0} key set differs at {1}." -f $id,$englishKeys[$i]) 19 }
            $key = $englishKeys[$i]
            $sig0 = (([regex]::Matches([string]$blocks[0][$key], '\{\d+[^}]*\}') | ForEach-Object { $_.Value } | Sort-Object) -join '|')
            $sigN = (([regex]::Matches([string]$blocks[$id][$key], '\{\d+[^}]*\}') | ForEach-Object { $_.Value } | Sort-Object) -join '|')
            if ($sig0 -ne $sigN) { Fail ("LANGUAGE FAIL: placeholder mismatch at {0} in Lang_{1}." -f $key,$id) 19 }
        }
    }
    L ("LanguageFile={0}" -f $Path)
    L ("LanguageKeys={0}" -f $englishKeys.Count)
    L '[PASS] Language catalogue: 6 blocks, key parity and placeholder parity.'
}


function Test-LispTooltipTemplate([string]$Path) {
    if (-not (Test-Path $Path)) { Fail 'HARD STOP: missing Buildtime\Dinformation-Tooltip.lsp.tpl.' 18 }
    $bytes = [IO.File]::ReadAllBytes($Path)
    foreach ($b in $bytes) { if ($b -gt 127) { Fail 'LISP TEMPLATE FAIL: template must be ASCII-only.' 18 } }
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    if (([regex]::Matches($text, '@@BOOTSTRAP@@')).Count -ne 1) { Fail 'LISP TEMPLATE FAIL: bootstrap marker count must be exactly one.' 18 }
    foreach ($required in @('nentselp','dcad-dinf-dis','dcad-dinformation-getinfo','dcad-dinformation-reset','vl-acad-defun')) { if (-not $text.Contains($required)) { Fail ('LISP TEMPLATE FAIL: missing ' + $required) 18 } }
    foreach ($forbidden in @('grread','add_solid','add_text')) { if ($text.Contains($forbidden)) { Fail ('LISP TEMPLATE FAIL: display/loop token found: ' + $forbidden) 18 } }
    L '[PASS] LISP tooltip template: ASCII, bridge functions, no overlay/loop.'
}

L 'Dinformation V17 - GstarCAD 2027 - Build Gate'; L 'TargetFramework=net8.0-windows'; L 'Platform=x64'; L ('BuildTime='+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
L '[1/6] Checking exact sample references...'
$required=@('GcCoreMgd.dll','GcDbMgd.dll','GcMgd.dll'); $refDir=Join-Path $Root 'Reference'; foreach($n in $required){if(-not(Test-Path (Join-Path $refDir $n))){Fail "HARD STOP: missing Reference\$n" 11}}; $extra=Get-ChildItem $refDir -File|?{$_.Name-notin$required}; if($extra){Fail ('HARD STOP: unexpected Reference files: '+(($extra.Name)-join ',')) 12}; L '[PASS] Reference set valid.'
L '[LANG] Validating embedded language source...'; Test-LanguageCatalog (Join-Path $Root 'Buildtime\Language\lang.dat')
Test-LispTooltipTemplate (Join-Path $Root 'Buildtime\Dinformation-Tooltip.lsp.tpl')
L '[2/6] Locating .NET 8 SDK...'; $dotnet=Get-Command dotnet -ErrorAction SilentlyContinue; if(-not$dotnet){Fail 'HARD STOP: dotnet not found.' 16}; $v=(& dotnet --version 2>&1|Select-Object -First 1).Trim(); L ('ResolvedSdk='+$v); if($v-notmatch'^8\.'){Fail 'HARD STOP: build must use .NET 8 SDK.' 17}
L '[3/6] Restoring...'; $ro=@(& dotnet restore $ProjectFile -p:Platform=x64 --ignore-failed-sources 2>&1); $rr=$LASTEXITCODE; $ro|%{L([string]$_)}; L("RestoreExitCode={0}"-f$rr); if($rr-ne0){Fail "RESTORE FAIL: $rr" 20}
L '[4/6] Checking project.assets.json...'; if(-not(Test-Path $AssetsFile)){Fail 'RESTORE FAIL: obj\project.assets.json not created.' 21}
L '[5/6] Building Release x64...'; Get-ChildItem $BinDir -File -ErrorAction SilentlyContinue|Remove-Item -Force; $bo=@(& dotnet build $ProjectFile -c Release -p:Platform=x64 --no-restore --nologo 2>&1); $br=$LASTEXITCODE; $bo|%{L([string]$_)}; L("BuildExitCode={0}"-f$br); if($br-ne0){Fail "BUILD FAIL: dotnet returned $br" 30}
L '[6/6] Checking final output...'; $dll=Join-Path $BinDir 'DinformationG27.dll'; if(-not(Test-Path $dll)){Fail 'BUILD FAIL: bin\DinformationG27.dll not created.' 31}; $extraBin=Get-ChildItem $BinDir -File|?{$_.Name-ne'DinformationG27.dll'}; if($extraBin){Fail ('BUILD FAIL: unexpected bin files: '+(($extraBin.Name)-join ',')) 32}; L ('AssemblyVersion='+([Reflection.AssemblyName]::GetAssemblyName($dll).Version)); L ('OutputPath='+$dll); L 'BUILD PASS'; exit 0
