#!/usr/bin/env python3
"""Package-only orchestration for the explicitly approved Dinformation V17 -> V21 C22 change.
Runs on Windows GitHub Actions. Do not use this as evidence of CAD runtime acceptance.
"""
from __future__ import annotations
import hashlib
import os
from pathlib import Path
import re
import shutil
import sys
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
SOURCE_ARCHIVE = ROOT / 'V17' / 'Dinformation-V17.zip'
ORIGINAL = ROOT / 'stage-v21' / 'Dinformation-V17'
PACKAGE = ROOT / 'package-v21'
DEST_ZIP = ROOT / 'Dinformation-V21.zip'
HOSTS = {
    'AutoCAD2022': ('DinformationC22.dll', 'C22'),
    'AutoCAD2025': ('DinformationC25.dll', 'C25'),
    'GstarCAD2027': ('DinformationG27.dll', 'G27'),
}
PATCH_FILES = (
    'src/Information/InformationSession.cs',
    'src/Core/LispInfoEngine.cs',
    'Buildtime/Dinformation-Tooltip.lsp.tpl',
)

def write_cmd(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(('\r\n'.join(lines) + '\r\n').encode('utf-8'))

def safe_unzip(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with ZipFile(source) as z:
        for item in z.infolist():
            rel = Path(item.filename.replace('\\', '/'))
            if rel.is_absolute() or '..' in rel.parts:
                raise ValueError('Unsafe archive path: ' + item.filename)
            target = destination / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.write_bytes(z.read(item))

def text_version_replace(path: Path) -> None:
    if path.suffix.lower() not in ('.cs', '.csproj', '.sln', '.ps1', '.cmd', '.txt', '.md', '.json', '.xml', '.props', '.targets'):
        return
    data = path.read_bytes()
    try:
        content = data.decode('utf-8-sig')
    except UnicodeDecodeError:
        return
    changed = content.replace('V17', 'V21').replace('17.0.0.0', '21.0.0.0')
    if changed != content:
        if path.suffix.lower() == '.cmd':
            write_cmd(path, changed.replace('\r\n','\n').replace('\r','\n').splitlines())
        else:
            path.write_bytes(changed.encode('utf-8'))

def make_child_cmd(host: str, dll: str) -> list[str]:
    return [
        '@echo off',
        'setlocal EnableExtensions',
        'set "RESULT=1"',
        'set "NO_PAUSE=0"',
        'if /I "%~1"=="/nopause" set "NO_PAUSE=1"',
        'cd /d "%~dp0"',
        'if not exist "log" mkdir "log"',
        'call :PRINT "[BUILD] Dinformation ' + host + ' V21" "Blue"',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Buildtime\Build_Release.ps1"',
        'set "RESULT=%ERRORLEVEL%"',
        'goto :FINISH',
        ':FINISH',
        'if not "%RESULT%"=="0" goto :FAILED',
        'if not exist "%~dp0bin\\' + dll + '" (set "RESULT=1" & goto :FAILED)',
        'call :PRINT "[PASS] ' + host + ' DLL ' + dll + '" "Green"',
        'goto :ENDMESSAGE',
        ':FAILED',
        'call :PRINT "[FAIL] ' + host + ' build failed" "Red"',
        ':ENDMESSAGE',
        'echo Log: %~dp0log',
        'if "%NO_PAUSE%"=="1" goto :EXIT',
        'echo Nhan phim bat ky de thoat...',
        'pause >nul',
        ':EXIT',
        'endlocal & exit /b %RESULT%',
        ':PRINT',
        'if defined NO_COLOR (echo %~1 & exit /b 0)',
        'powershell.exe -NoProfile -Command "Write-Host \'%~1\' -ForegroundColor %~2"',
        'if errorlevel 1 echo %~1',
        'exit /b 0',
    ]

def make_root_cmd() -> list[str]:
    L = [
        '@echo off',
        'setlocal EnableExtensions EnableDelayedExpansion',
        'set "ROOT=%~dp0"',
        'set "NO_PAUSE=0"',
        'if /I "%~1"=="/nopause" set "NO_PAUSE=1"',
        'set "FINAL_RESULT=1"',
        'cd /d "%ROOT%"',
        'if not exist "log" mkdir "log"',
        'if not exist "Dprogram" mkdir "Dprogram"',
        'del /q "Dprogram\\DinformationC22.dll" "Dprogram\\DinformationC25.dll" "Dprogram\\DinformationG27.dll" >nul 2>nul',
        'call :PRINT "DINFORMATION V21 - BUILD ALL" "Cyan"',
        'call :PRINT "[BUILD] Three approved CAD hosts" "Blue"',
        'set "S22=FAIL"',
        'set "S25=FAIL"',
        'set "S27=FAIL"',
    ]
    for host, code, log, dll, stat in [
        ('AutoCAD2022','C22','AutoCAD2022.log','DinformationC22.dll','S22'),
        ('AutoCAD2025','C25','AutoCAD2025.log','DinformationC25.dll','S25'),
        ('GstarCAD2027','G27','GstarCAD2027.log','DinformationG27.dll','S27'),
    ]:
        L += [
            'call :BUILD "' + host + '" "' + dll + '" "' + log + '" "' + stat + '"',
        ]
    L += [
        'if not "!S22!"=="PASS" goto :FINISH',
        'if not "!S25!"=="PASS" goto :FINISH',
        'if not "!S27!"=="PASS" goto :FINISH',
        'set "STAGING=%ROOT%log\\.publish_v21"',
        'if exist "!STAGING!" rmdir /s /q "!STAGING!"',
        'mkdir "!STAGING!"',
    ]
    for host, (dll,code) in HOSTS.items():
        L += [
            'copy /Y "%ROOT%Dinformation-' + host + '-V21\\bin\\' + dll + '" "!STAGING!\\' + dll + '" >nul',
            'if errorlevel 1 goto :FINISH',
        ]
    L += [
        'copy /Y "!STAGING!\\Dinformation*.dll" "%ROOT%Dprogram\\" >nul',
        'if errorlevel 1 goto :FINISH',
        'rmdir /s /q "!STAGING!"',
        'set "FINAL_RESULT=0"',
        'goto :FINISH',
        ':BUILD',
        'set "P=%ROOT%Dinformation-%~1-V21"',
        'if not exist "!P!\\Build_Release.cmd" (',
        '  echo [FAIL] Missing Build_Release.cmd for %~1 > "%ROOT%log\\%~3"',
        '  call :PRINT "[FAIL] Missing build script for %~1" "Red"',
        '  set "%~4=FAIL"',
        '  exit /b 0',
        ')',
        'call :PRINT "[BUILD] %~1" "Blue"',
        'call "!P!\\Build_Release.cmd" /nopause > "%ROOT%log\\%~3" 2>&1',
        'set "BR=%ERRORLEVEL%"',
        'type "%ROOT%log\\%~3"',
        'if not "!BR!"=="0" (',
        '  set "%~4=FAIL"',
        '  call :PRINT "[FAIL] %~1 compiler exit !BR!" "Red"',
        ') else (',
        '  if exist "!P!\\bin\\%~2" (',
        '    set "%~4=PASS"',
        '    call :PRINT "[PASS] %~1" "Green"',
        '  ) else (',
        '    set "%~4=FAIL"',
        '    call :PRINT "[FAIL] %~1 output DLL missing" "Red"',
        '  )',
        ')',
        'exit /b 0',
        ':FINISH',
        'echo ------------------------------------------------------------',
        'echo AutoCAD 2022: !S22!',
        'echo AutoCAD 2025: !S25!',
        'echo GstarCAD 2027: !S27!',
        'if not "%FINAL_RESULT%"=="0" goto :FAILED',
        'call :PRINT "[PASS] BUILD ALL: PASS" "Green"',
        'goto :ENDMESSAGE',
        ':FAILED',
        'if exist "%ROOT%log\\.publish_v21" rmdir /s /q "%ROOT%log\\.publish_v21"',
        'del /q "Dprogram\\DinformationC22.dll" "Dprogram\\DinformationC25.dll" "Dprogram\\DinformationG27.dll" >nul 2>nul',
        'call :PRINT "[FAIL] BUILD ALL: FAIL" "Red"',
        ':ENDMESSAGE',
        'echo Logs: %ROOT%log',
        'if "%NO_PAUSE%"=="1" goto :EXIT',
        'echo Nhan phim bat ky de thoat...',
        'pause >nul',
        ':EXIT',
        'endlocal & exit /b %FINAL_RESULT%',
        ':PRINT',
        'if defined NO_COLOR (echo %~1 & exit /b 0)',
        'powershell.exe -NoProfile -Command "Write-Host \'%~1\' -ForegroundColor %~2"',
        'if errorlevel 1 echo %~1',
        'exit /b 0',
    ]
    return L

def prepare() -> None:
    if PACKAGE.exists(): shutil.rmtree(PACKAGE)
    srcdir = ROOT / 'stage-v21'
    if srcdir.exists(): shutil.rmtree(srcdir)
    safe_unzip(SOURCE_ARCHIVE, srcdir)
    if not ORIGINAL.exists(): raise RuntimeError('Source archive has unexpected structure')
    PACKAGE.mkdir(parents=True)
    (PACKAGE / 'log').mkdir()
    (PACKAGE / 'Dprogram').mkdir()
    for host, (dll, code) in HOSTS.items():
        original_host = ORIGINAL / ('Dinformation-' + host + '-V17')
        if not original_host.is_dir(): raise RuntimeError('Original baseline host missing: '+host)
        target = PACKAGE / ('Dinformation-' + host + '-V21')
        shutil.copytree(original_host, target)
        for directory in ('bin','log','Reference','Runtime','icon','Buildtime','Userdata','src'):
            (target / directory).mkdir(exist_ok=True)
        for old_path in ('bin','obj','log'):
            folder=target/old_path
            for p in list(folder.iterdir()) if folder.is_dir() else []:
                if p.is_dir(): shutil.rmtree(p)
                else: p.unlink()
        if host=='AutoCAD2022':
            for rel in PATCH_FILES:
                patch = ROOT/'inspection'/'Dinformation-V17'/'Dinformation-AutoCAD2022-V17'/rel
                old = original_host/rel
                if not patch.is_file() or not old.is_file() or patch.read_bytes()==old.read_bytes():
                    raise RuntimeError('C22 source patch missing/unchanged: '+rel)
                destination=target/rel
                destination.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(patch,destination)
        # Preserve the full baseline source and original SDKs; replace only package version metadata.
        for p in target.rglob('*'):
            if p.is_file(): text_version_replace(p)
        metadata = target/'Userdata'
        (metadata/'BuildInfo.txt').write_text(
            'Project=Dinformation\nPackageVersion=V21\nBaseline=V17\n'
            'Host='+host+'\nAssembly='+dll+'\n'
            'BuildStatus=NotVerified\nNETLOAD=NotVerified\nRuntimeStatus=NotVerified\n'
            'StandardsStatus=NotVerified\nReleaseApproved=NO\n'
            'ChangedBusinessCode=AutoCAD2022 hover recognition only\n',
            encoding='utf-8')
        # The old V17 Data folder contains stale metadata; canonical source metadata
        # belongs directly under Userdata per STD-03. Do not modify business logic.
        legacy_data=target/'Data'
        if legacy_data.exists():
            shutil.rmtree(legacy_data)
        (metadata/'DataManifest.txt').write_text(
            'Project=Dinformation\\nPackageVersion=V21\\nOwnerModule=Dinformation\\n'
            'ResourceName=Buildtime/Language/lang.dat;Type=BuildTime;Required=true;Embedded=true;AccessMode=Read;DefaultBehavior=Error\\n'
            'ResourceName=MIS_SET.SET;Type=RuntimeSystem;Required=true;LogicalFolder=DUser;AccessMode=ReadOnly;DefaultBehavior=LegacySourceFallback;SourcePath=CAD Support Path\\n'
            'ResourceName=24.0_(IDD)-object-information.LSP;Type=Documentation;Required=false;SourcePath=Userdata;Embedded=false;DefaultBehavior=NotLoadedAtRuntime\\n'
            'KnownDeviation=V17 DUser resolver and TEMP diagnostics remain legacy; source behavior intentionally unchanged by C22 recognition patch; STD05/06 compliance NotVerified\\n',
            encoding='utf-8')
        write_cmd(target/'Build_Release.cmd',make_child_cmd(host,dll))
    write_cmd(PACKAGE/'Build_All.cmd',make_root_cmd())
    (PACKAGE/'Dinformation-AutoCAD2022-V21'/'Userdata'/'ReleaseNotes.txt').write_text(
        'Dinformation V21 source candidate (not CAD runtime accepted)\n'
        'Baseline V17, latest saved before change V20\n'
        'Scope: only AutoCAD 2022 recognition behavior changed, C25/G27 source logic otherwise unchanged\n'
        'CAD hosts: AutoCAD 2022, AutoCAD 2025, GstarCAD 2027\n'
        'GstarCAD 2018 used as read-only functional reference; not a supported build host\n'
        'NETLOAD/Runtime/Standards: NotVerified; ReleaseApproved=NO\n'
        'No CAD runtime has been exercised by this workflow.\n',
        encoding='utf-8')
    print('STAGE_OK Three approved CAD source branches and C22 three-file patch')

def finalize() -> None:
    if DEST_ZIP.exists(): DEST_ZIP.unlink()
    output=[PACKAGE/'Dprogram'/dll for dll,_ in HOSTS.values()]
    if not all(x.is_file() and x.stat().st_size>150000 for x in output):
        raise RuntimeError('Not all three new DLLs were built and staged; refusing ZIP')
    for host, (dll, code) in HOSTS.items():
        asm = PACKAGE / ('Dinformation-'+host+'-V21') / 'AssemblyInfo.cs'
        if '"21.0.0.0"' not in asm.read_text(encoding='utf-8'):
            raise RuntimeError('Version metadata mismatch in '+host)
        info=PACKAGE/('Dinformation-'+host+'-V21')/'Userdata'/'BuildInfo.txt'
        info.write_text(info.read_text(encoding='utf-8').replace('BuildStatus=NotVerified','BuildStatus=PASS'),encoding='utf-8')
    with ZipFile(DEST_ZIP,'w',ZIP_DEFLATED,compresslevel=6) as z:
        files=sorted(p for p in PACKAGE.rglob('*') if p.is_file())
        for f in files:
            rel=f.relative_to(PACKAGE).as_posix()
            if '/obj/' in '/'+rel or rel.endswith('.cache'):
                continue
            z.write(f,rel)
        for host in HOSTS:
            for d in ('bin','log','Reference','Runtime','icon','Buildtime','Userdata','src'):
                rel=f'Dinformation-{host}-V21/{d}/'
                if rel not in z.namelist():z.writestr(rel,b'')
    with ZipFile(DEST_ZIP) as z:
        assert z.testzip() is None
        names=set(z.namelist())
        assert 'Build_All.cmd' in names
        assert all('Dprogram/'+dll in names for dll,_ in HOSTS.values())
        assert all('Dinformation-'+h+'-V21/Build_Release.cmd' in names for h in HOSTS)
        assert not any('GstarCAD2018' in n or 'DinformationG18.dll' in n for n in names)
        assert all(z.read('Dprogram/'+dll)==z.read(f'Dinformation-{host}-V21/bin/{dll}') for host,(dll,code) in HOSTS.items())
        for name in [x for x in names if x.lower().endswith('.cmd')]:
            b=z.read(name)
            assert b.startswith(b'@echo off\r\n') and b'\xef\xbb\xbf' not in b and b'\r\r\n' not in b
            assert b'\n' not in b.replace(b'\r\n',b'')
        for host in HOSTS:
            branch=f'Dinformation-{host}-V21/'
            assert (branch+'Dinformation.csproj') in names
            assert (branch+'Dinformation.sln') in names
            for d in ('bin','log','Reference','Runtime','icon','Buildtime','Userdata','src'):
                assert (branch+d+'/') in names
    print('PACKAGE_QA_PASS:',DEST_ZIP,DEST_ZIP.stat().st_size,
          'SHA256='+hashlib.sha256(DEST_ZIP.read_bytes()).hexdigest(),
          'Hosts='+','.join(HOSTS))

if __name__ == '__main__':
    if len(sys.argv)!=2 or sys.argv[1] not in ('prepare','finalize'):
        raise SystemExit('Usage: build_v21_package.py prepare|finalize')
    (prepare if sys.argv[1]=='prepare' else finalize)()
