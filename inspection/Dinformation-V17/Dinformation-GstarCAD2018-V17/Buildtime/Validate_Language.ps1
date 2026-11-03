param([string]$Root)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($Root)){ $Root=Split-Path -Parent $PSScriptRoot }
$Path=Join-Path $Root 'Buildtime\Language\lang.dat'
if(-not(Test-Path $Path)){ Write-Host 'HARD STOP: missing Buildtime\Language\lang.dat'; exit 19 }
$blocks=@{}; $current=$null
foreach($raw in Get-Content -LiteralPath $Path -Encoding UTF8){
  $line=([string]$raw).Trim()
  if($line -match '^Lang_(\d+)\(([^_()]+)_([^_()]+)\)$'){
    $current=[int]$Matches[1]
    if($blocks.ContainsKey($current)){ Write-Host ("LANGUAGE FAIL: duplicate Lang_{0}." -f $current); exit 19 }
    $blocks[$current]=@{}; continue
  }
  if($line -eq '-'){ $current=$null; continue }
  if($null -eq $current -or $line.Length -eq 0 -or $line.StartsWith('#') -or $line.StartsWith(';') -or $line.StartsWith('//')){ continue }
  $eq=$line.IndexOf('='); if($eq -le 0){ continue }
  $key=$line.Substring(0,$eq).Trim(); $value=$line.Substring($eq+1)
  if($key.Length -eq 0){ continue }
  if($blocks[$current].ContainsKey($key)){ Write-Host ("LANGUAGE FAIL: duplicate key {0} in Lang_{1}." -f $key,$current); exit 19 }
  if([string]::IsNullOrWhiteSpace($value)){ Write-Host ("LANGUAGE FAIL: empty key {0} in Lang_{1}." -f $key,$current); exit 19 }
  $blocks[$current][$key]=$value
}
foreach($id in 0..5){ if(-not $blocks.ContainsKey($id)){ Write-Host ("LANGUAGE FAIL: missing Lang_{0}." -f $id); exit 19 } }
$keys0=@($blocks[0].Keys|Sort-Object)
foreach($id in 1..5){
  $keys=@($blocks[$id].Keys|Sort-Object)
  if($keys.Count -ne $keys0.Count){ Write-Host ("LANGUAGE FAIL: Lang_{0} key count differs from Lang_0." -f $id); exit 19 }
  for($i=0;$i -lt $keys0.Count;$i++){
    if($keys[$i] -ne $keys0[$i]){ Write-Host ("LANGUAGE FAIL: Lang_{0} key set differs." -f $id); exit 19 }
    $k=$keys0[$i]
    $a=(([regex]::Matches([string]$blocks[0][$k],'\{\d+[^}]*\}')|%{$_.Value}|Sort-Object)-join '|')
    $b=(([regex]::Matches([string]$blocks[$id][$k],'\{\d+[^}]*\}')|%{$_.Value}|Sort-Object)-join '|')
    if($a -ne $b){ Write-Host ("LANGUAGE FAIL: placeholder mismatch at {0}/Lang_{1}." -f $k,$id); exit 19 }
  }
}
Write-Host ("LANGUAGE QA PASS: 6 blocks, {0} keys/block." -f $keys0.Count)
exit 0
