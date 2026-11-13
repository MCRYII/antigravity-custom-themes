# =====================================================================
#  Antigravity Custom Themes - One-Click Installer
#  1) 备份 app.asar  2) 注入主题加载钩子（幂等）  3) 分发主题文件
#  用法:  右键"使用 PowerShell 运行" 或 双击 install.bat
#  卸载:  powershell -File install.ps1 -Uninstall
# =====================================================================
param(
    [switch]$Uninstall,
    [switch]$CheckUpdate
)
$ErrorActionPreference = 'Stop'

$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$LegacyMarker    = 'custom-theme injection hook'
$HookVersion     = 'v1'
$HookStartMarker = "// === Antigravity custom-theme injection hook $HookVersion (start) ==="
$HookEndMarker   = "// === Antigravity custom-theme injection hook $HookVersion (end) ==="
$Anchor          = "void win.loadURL(url);"
$Payloads        = @('current.css', 'current.js')
$CurrentVersion  = 'v2.3.2'
$Repo            = 'MCRYII/antigravity-custom-themes'
$ReleasesUrl     = "https://github.com/$Repo/releases/latest"

function Die([string]$msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }
function Ok([string]$msg)  { Write-Host "[OK] $msg" -ForegroundColor Green }
$hex = { param($b) ([System.BitConverter]::ToString($b)).Replace('-', '').ToLower() }

# ---------- 统一 ASAR 解析与条目查找 ----------
function ConvertFrom-AsarJson([string]$Json) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($Json | ConvertFrom-Json -AsHashtable)
    }
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    return $serializer.DeserializeObject($Json)
}

function Read-AsarHeader([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "ASAR 文件不存在: $Path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.LongLength -lt 16) {
        throw "ASAR 文件长度不足 16 字节（已损坏或截断）: $Path"
    }
    $payloadSize = [BitConverter]::ToUInt32($bytes, 8)
    $jsonLen     = [BitConverter]::ToUInt32($bytes, 12)
    $dataStart   = [int64]12 + [int64]$payloadSize
    if ($jsonLen -eq 0 -or ([int64]16 + [int64]$jsonLen) -gt $bytes.LongLength) {
        throw "ASAR 头部 JSON 长度越界 (jsonLen=$jsonLen, fileLen=$($bytes.LongLength))"
    }
    if ($dataStart -lt ([int64]16 + [int64]$jsonLen) -or $dataStart -gt $bytes.LongLength) {
        throw "ASAR 数据区起始偏移越界 (dataStart=$dataStart, fileLen=$($bytes.LongLength))"
    }
    $json = [System.Text.Encoding]::UTF8.GetString($bytes, 16, [int]$jsonLen)
    $tree = ConvertFrom-AsarJson -Json $json
    if (-not ($tree -is [System.Collections.IDictionary])) {
        throw "ASAR 头部 JSON 根节点格式无效"
    }
    return [PSCustomObject]@{
        Path      = $Path
        Bytes     = $bytes
        DataStart = $dataStart
        JsonLen   = [int]$jsonLen
        Json      = $json
        Tree      = $tree
    }
}

function Test-DictKey($Dict, [string]$Key) {
    if ($Dict -is [System.Collections.IDictionary]) {
        return ([System.Collections.IDictionary]$Dict).Contains($Key)
    }
    return $false
}

function Find-AsarEntry {
    param(
        [Parameter(Mandatory = $true)]$Header,
        [Parameter(Mandatory = $true)][string]$FileName
    )
    $results = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $stack.Push(@{ Node = $Header.Tree; Path = '' })

    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        $node = $item.Node
        if (-not (Test-DictKey $node 'files')) {
            continue
        }
        $files = $node['files']
        if (-not ($files -is [System.Collections.IDictionary])) { continue }

        foreach ($key in $files.Keys) {
            $child = $files[$key]
            if (-not ($child -is [System.Collections.IDictionary])) { continue }
            $relPath = if ($item.Path) { "$($item.Path)/$key" } else { "$key" }

            if (Test-DictKey $child 'files') {
                $stack.Push(@{ Node = $child; Path = $relPath })
                continue
            }

            if ($key -ceq $FileName -and (Test-DictKey $child 'size') -and (Test-DictKey $child 'offset')) {
                $sz  = [int64]$child['size']
                $off = [int64]$child['offset']
                if ($off -lt 0 -or $sz -le 0 -or ($Header.DataStart + $off + $sz) -gt $Header.Bytes.LongLength) {
                    continue
                }
                $integrity = if (Test-DictKey $child 'integrity') { $child['integrity'] } else { $null }
                $hash      = $null
                $blockSize = 0
                $blocks    = @()
                if ($integrity -is [System.Collections.IDictionary]) {
                    if (Test-DictKey $integrity 'hash')      { $hash      = [string]$integrity['hash'] }
                    if (Test-DictKey $integrity 'blockSize') { $blockSize = [int]$integrity['blockSize'] }
                    if (Test-DictKey $integrity 'blocks')    { $blocks    = @($integrity['blocks']) }
                }
                [void]$results.Add([PSCustomObject]@{
                    Name      = [string]$key
                    RelPath   = $relPath
                    Size      = [int]$sz
                    Offset    = $off
                    Hash      = $hash
                    BlockSize = $blockSize
                    Blocks    = $blocks
                })
            }
        }
    }
    return $results.ToArray()
}

function Find-JsonEntrySpan([string]$Json, [string]$EntryKey, [int64]$Offset, [int]$Size) {
    $pattern = '"' + [regex]::Escape($EntryKey) + '"\s*:\s*\{'
    foreach ($m in [regex]::Matches($Json, $pattern)) {
        $braceStart = $Json.IndexOf('{', $m.Index)
        if ($braceStart -lt 0) { continue }
        $depth = 0
        $inStr = $false
        $escaped = $false
        $endIdx = -1
        for ($i = $braceStart; $i -lt $Json.Length; $i++) {
            $ch = $Json[$i]
            if ($inStr) {
                if ($escaped) {
                    $escaped = $false
                } elseif ($ch -eq '\') {
                    $escaped = $true
                } elseif ($ch -eq '"') {
                    $inStr = $false
                }
                continue
            }
            if ($ch -eq '"') {
                $inStr = $true
            } elseif ($ch -eq '{') {
                $depth++
            } elseif ($ch -eq '}') {
                $depth--
                if ($depth -eq 0) {
                    $endIdx = $i
                    break
                }
            }
        }
        if ($endIdx -gt $braceStart) {
            $slice = $Json.Substring($m.Index, $endIdx - $m.Index + 1)
            if ($slice -match ('"offset"\s*:\s*"' + $Offset + '"') -and $slice -match ('"size"\s*:\s*' + $Size + '\b')) {
                return [PSCustomObject]@{
                    Index  = $m.Index
                    Length = $endIdx - $m.Index + 1
                }
            }
        }
    }
    return $null
}

function Test-AsarBytesIntegrity($Header, $Entry) {
    if (-not $Entry -or -not $Entry.Hash -or $Entry.BlockSize -le 0 -or $Entry.Blocks.Count -eq 0) {
        return $false
    }
    $absOff = $Header.DataStart + $Entry.Offset
    if ($Entry.Offset -lt 0 -or $Entry.Size -le 0 -or ($absOff + $Entry.Size) -gt $Header.Bytes.LongLength) {
        return $false
    }
    $expectedBlocks = [int][Math]::Ceiling($Entry.Size / [double]$Entry.BlockSize)
    if ($Entry.Blocks.Count -ne $expectedBlocks) {
        return $false
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fullHash = & $hex $sha.ComputeHash($Header.Bytes, [int]$absOff, $Entry.Size)
        if ($fullHash -ne $Entry.Hash.ToLowerInvariant()) {
            return $false
        }
        for ($i = 0; $i -lt $Entry.Blocks.Count; $i++) {
            $rel = $i * $Entry.BlockSize
            $len = [Math]::Min($Entry.BlockSize, $Entry.Size - $rel)
            $blockHash = & $hex $sha.ComputeHash($Header.Bytes, [int]($absOff + $rel), $len)
            if ($blockHash -ne ([string]$Entry.Blocks[$i]).ToLowerInvariant()) {
                return $false
            }
        }
        return $true
    } finally {
        $sha.Dispose()
    }
}

# ---------- 检查更新分支 ----------
if ($CheckUpdate) {
    Write-Host "[*] 正在检测 GitHub 最新发行版..." -ForegroundColor Cyan
    try {
        try {
            $proto = [Net.ServicePointManager]::SecurityProtocol
            if ($proto -ne [Net.SecurityProtocolType]::SystemDefault) {
                [Net.ServicePointManager]::SecurityProtocol = $proto -bor [Net.SecurityProtocolType]::Tls12
            }
        } catch { }

        $apiUrl  = "https://api.github.com/repos/$Repo/releases/latest"
        $headers = @{ 'User-Agent' = 'Antigravity-Theme-Updater' }
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop

        $remoteTag = [string]$release.tag_name
        $publishedAt = "近期"
        if ($release.published_at) {
            if ($release.published_at -is [datetime]) {
                $publishedAt = $release.published_at.ToString('yyyy-MM-dd')
            } else {
                $parsedDt = [datetime]::MinValue
                $rawPub = [string]$release.published_at
                if ([datetime]::TryParse($rawPub, [ref]$parsedDt)) {
                    $publishedAt = $parsedDt.ToString('yyyy-MM-dd')
                } elseif ($rawPub.Length -ge 10) {
                    $publishedAt = $rawPub.Substring(0, 10)
                }
            }
        }

        $htmlUrl = $ReleasesUrl
        if ($release.html_url -and ([string]$release.html_url -match '^https://github\.com/')) {
            $htmlUrl = [string]$release.html_url
        }

        $hasUpdate = $false
        if ($remoteTag) {
            $rClean = $remoteTag.Trim().TrimStart('v', 'V')
            $cClean = $CurrentVersion.Trim().TrimStart('v', 'V')
            $rVer = $null; $cVer = $null
            if ([version]::TryParse($rClean, [ref]$rVer) -and [version]::TryParse($cClean, [ref]$cVer)) {
                $hasUpdate = ($rVer -gt $cVer)
            } else {
                $hasUpdate = ($remoteTag.Trim().ToLower() -ne $CurrentVersion.Trim().ToLower())
            }
        }

        Write-Host ""
        if ($hasUpdate) {
            Write-Host "[!] 发现新版本：$remoteTag （当前版本：$CurrentVersion）" -ForegroundColor Green
            Write-Host "    发布时间：$publishedAt" -ForegroundColor Gray
            if ($release.body) {
                Write-Host "`n更新摘要：" -ForegroundColor Yellow
                $summary = ($release.body -split "`n" | Where-Object { $_ -match '^[-*#0-9]' } | Select-Object -First 5) -join "`n"
                if ($summary) { Write-Host $summary -ForegroundColor Gray }
            }
            Write-Host ""
            $open = Read-Host "是否在浏览器中打开最新版本下载页面？(Y/N) [默认 Y]"
            if ($open -eq '' -or $open -match '^[Yy]') {
                Start-Process $htmlUrl
                Ok "已调起默认浏览器打开发布页面。"
            }
        } else {
            Ok "当前已是最新版本 ($CurrentVersion)，无需更新。"
        }
    } catch {
        Write-Host "[!] 检查更新失败（$($_.Exception.Message)）。" -ForegroundColor Yellow
        Write-Host "    您也可以随时直接在浏览器中访问：" -ForegroundColor Gray
        Write-Host "    $ReleasesUrl" -ForegroundColor Cyan
    }
    exit 0
}

# 只读检测：app.asar 内是否已包含主题注入钩子（兼容新旧版本钩子，异常时安全返回 $false）
function Test-AsarPatched([string]$path) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return $false }
        $hdr = Read-AsarHeader -Path $path
        $entries = @(Find-AsarEntry -Header $hdr -FileName 'utils.js')
        foreach ($e in $entries) {
            $content = [System.Text.Encoding]::UTF8.GetString($hdr.Bytes, [int]($hdr.DataStart + $e.Offset), $e.Size)
            if ($content.Contains($HookStartMarker) -or $content.Contains($LegacyMarker)) {
                return $true
            }
        }
    } catch { }
    return $false
}

# ---------- 定位 Antigravity 客户端（默认位置 → 注册表兜底） ----------
function Get-ClientResources {
    $found = @()
    $default = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\resources'
    if (Test-Path -LiteralPath (Join-Path $default 'app.asar')) { $found += $default }

    $regPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $props = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue
    foreach ($prop in $props) {
        if (-not $prop.DisplayName -or $prop.DisplayName -notlike 'Antigravity*') { continue }
        if ($prop.DisplayName -like '*IDE*') { continue }
        try {
            $candidates = @()
            if ($prop.DisplayIcon) {
                $exe = (($prop.DisplayIcon -split ',')[0]).Trim().Trim('"')
                if ($exe) {
                    $parent = Split-Path -Parent $exe
                    if ($parent) { $candidates += (Join-Path $parent 'resources') }
                }
            }
            if ($prop.InstallLocation) {
                $loc = ([string]$prop.InstallLocation).Trim().Trim('"')
                if ($loc) { $candidates += (Join-Path $loc 'resources') }
            }
            foreach ($res in $candidates) {
                if ((Test-Path -LiteralPath (Join-Path $res 'app.asar')) -and ($found -notcontains $res)) {
                    $found += $res
                }
            }
        } catch {
            continue
        }
    }
    return $found
}

function Get-RunningClientProcesses([string]$ResourcesDir) {
    $appRoot = (Split-Path -Parent $ResourcesDir).TrimEnd('\') + '\'
    $matched = @()
    foreach ($p in (Get-Process -Name 'Antigravity' -ErrorAction SilentlyContinue)) {
        $exePath = $null
        try {
            $exePath = $p.MainModule.FileName
        } catch {
            try {
                $cim = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue
                if ($cim) { $exePath = $cim.ExecutablePath }
            } catch { }
        }
        if ($exePath -and $exePath.StartsWith($appRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matched += $p
        }
    }
    return $matched
}

function Wait-FileUnlocked([string]$FilePath, [int]$TimeoutMs = 5000) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        try {
            $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $fs.Dispose()
            return $true
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return $false
}

$locations = @(Get-ClientResources)
if ($locations.Count -eq 0) {
    Die "未找到 Antigravity 客户端。请确认已安装官方 Antigravity（默认位于 %LOCALAPPDATA%\Programs\Antigravity）。"
}
$ResDir     = $locations[0]
$AsarPath   = Join-Path $ResDir 'app.asar'
$BackupPath = Join-Path $ResDir 'app.asar.stock-backup'
$ThemeDirs  = @(
    (Join-Path $ResDir 'custom-theme'),
    (Join-Path $env:APPDATA 'Antigravity\custom-theme')
)
Ok "已定位客户端：$ResDir"

# ---------- 载荷校验（安装前 Fail-Fast：在关闭客户端进程之前完成，包体残缺时绝不误杀正在运行的客户端） ----------
if (-not $Uninstall) {
    foreach ($f in $Payloads) {
        if (-not (Test-Path -LiteralPath (Join-Path $ScriptDir $f))) {
            Die "缺少主题文件 $f —— 请在完整的主题包内运行本脚本。"
        }
    }
}

# ---------- 机器级目录提权预检（Program Files 需管理员权限，提前给出友好提示而非裸异常崩溃） ----------
$machineRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
$needsAdmin = $false
foreach ($root in $machineRoots) {
    $prefix = $root.TrimEnd('\') + '\'
    if ($ResDir.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $needsAdmin = $true
        break
    }
}
if ($needsAdmin) {
    $isAdmin = $false
    try {
        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal -ArgumentList $identity
        $isAdmin   = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { }
    if (-not $isAdmin) {
        $launcherName = if ($Uninstall) { 'uninstall.bat' } else { 'install.bat' }
        Die "目标客户端位于受保护的 Program Files 目录（$ResDir）。请右键 $launcherName 选择「以管理员身份运行」后重试。"
    }
}

# ---------- 关闭正在运行的客户端（按路径匹配，先优雅关闭再兜底强杀并确认句柄释放） ----------
$running = @(Get-RunningClientProcesses -ResourcesDir $ResDir)
if ($running.Count -gt 0) {
    Write-Host "检测到目标目录的 Antigravity 正在运行（$($running.Count) 个进程）。"
    $ans = Read-Host "自动关闭它并继续？(Y/N)"
    if ($ans -match '^[Yy]') {
        foreach ($p in $running) {
            try {
                if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
                    $null = $p.CloseMainWindow()
                }
            } catch { }
        }
        $ids = @($running | ForEach-Object { $_.Id })
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $alive = @($running)
        while ($sw.ElapsedMilliseconds -lt 5000) {
            $alive = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
            if ($alive.Count -eq 0) { break }
            Start-Sleep -Milliseconds 250
        }
        if ($alive.Count -gt 0) {
            $alive | Stop-Process -Force -ErrorAction SilentlyContinue
            $sw.Restart()
            while ($sw.ElapsedMilliseconds -lt 5000) {
                $alive = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
                if ($alive.Count -eq 0) { break }
                Start-Sleep -Milliseconds 250
            }
        }
        if ($alive.Count -gt 0) {
            foreach ($p in $alive) {
                try { & taskkill.exe /F /T /PID $p.Id 2>$null | Out-Null } catch { }
            }
            $sw.Restart()
            while ($sw.ElapsedMilliseconds -lt 3000) {
                $alive = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
                if ($alive.Count -eq 0) { break }
                Start-Sleep -Milliseconds 250
            }
        }
        $stillRunning = @(Get-RunningClientProcesses -ResourcesDir $ResDir)
        if ($stillRunning.Count -gt 0) {
            Die "关闭 Antigravity 失败（进程仍在运行，PID: $(($stillRunning | ForEach-Object { $_.Id }) -join ', ')），可能需要管理员权限或请手动关闭后重试。"
        }
        if (-not (Wait-FileUnlocked -FilePath $AsarPath -TimeoutMs 5000)) {
            Die "app.asar 文件句柄尚未释放，请稍后或手动关闭相关进程后重试。"
        }
        Ok "已关闭 Antigravity"
    } else {
        Die "请手动关闭 Antigravity 后重新运行本脚本。"
    }
}

# ---------- 卸载 ----------
if ($Uninstall) {
    $currentPatched = Test-AsarPatched $AsarPath
    if (Test-Path -LiteralPath $BackupPath) {
        if (-not $currentPatched) {
            Write-Host "[!] 当前 app.asar 未检测到主题钩子（客户端可能已自动升级）。" -ForegroundColor Yellow
            Write-Host "    为避免把新版客户端回滚成旧版，已跳过还原，仅清理主题文件。" -ForegroundColor Yellow
        } elseif (Test-AsarPatched $BackupPath) {
            Write-Host "[!] app.asar.stock-backup 自身含主题钩子（备份已被污染），已跳过还原以避免残留。" -ForegroundColor Yellow
        } else {
            $tmpRestore = "$AsarPath.restore.tmp"
            try {
                Copy-Item -LiteralPath $BackupPath -Destination $tmpRestore -Force
                $expectedHash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
                [void](Read-AsarHeader -Path $tmpRestore)
                if (Test-AsarPatched $tmpRestore) {
                    throw "备份文件校验异常（仍含钩子）"
                }
                try {
                    [System.IO.File]::Replace($tmpRestore, $AsarPath, $null, $true)
                } catch {
                    Move-Item -LiteralPath $tmpRestore -Destination $AsarPath -Force
                }
                $restoredHash = (Get-FileHash -LiteralPath $AsarPath -Algorithm SHA256).Hash
                if ($restoredHash -ne $expectedHash -or (Test-AsarPatched $AsarPath)) {
                    throw "还原后 app.asar 哈希校验失败"
                }
                Remove-Item -LiteralPath $BackupPath -Force
                Ok "已还原原生 app.asar 并清理备份文件（app.asar.stock-backup）"
            } catch {
                if (Test-Path -LiteralPath $tmpRestore) { Remove-Item -LiteralPath $tmpRestore -Force -ErrorAction SilentlyContinue }
                Die "还原原生 app.asar 失败：$($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "[!] 未找到 app.asar.stock-backup，跳过还原" -ForegroundColor Yellow
    }
    foreach ($d in $ThemeDirs) {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force; Ok "已删除 $d" }
    }
    Write-Host "`n卸载完成。重启 Antigravity 即恢复原版外观。"
    exit 0
}

# ---------- 只读预检：解析 app.asar 并定位注入锚点（前置到复制主题文件之前） ----------
try {
    $hdr = Read-AsarHeader -Path $AsarPath
} catch {
    Die "解析 app.asar 失败：$($_.Exception.Message)"
}

$entries = @(Find-AsarEntry -Header $hdr -FileName 'utils.js')
if ($entries.Count -eq 0) {
    Die "asar 头部未找到 utils.js 条目（客户端结构可能已变化），已取消修改"
}

$entry = $null; $utils = $null
$hasLatestHook = $false; $hasLegacyHook = $false
foreach ($e in $entries) {
    $content = [System.Text.Encoding]::UTF8.GetString($hdr.Bytes, [int]($hdr.DataStart + $e.Offset), $e.Size)
    if ($content.Contains($Anchor)) {
        $entry = $e; $utils = $content
        if ($utils.Contains($HookStartMarker)) {
            $hasLatestHook = $true
        } elseif ($utils.Contains($LegacyMarker)) {
            $hasLegacyHook = $true
        }
        break
    }
}
if (-not $entry) { Die "未找到代码注入锚点（客户端版本可能已变化），已取消修改" }

# ---------- 分发主题文件 ----------
foreach ($d in $ThemeDirs) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    foreach ($f in $Payloads) {
        Copy-Item -LiteralPath (Join-Path $ScriptDir $f) -Destination (Join-Path $d $f) -Force
    }
}
Ok ("主题文件已安装到 {0} 个位置" -f $ThemeDirs.Count)

# ---------- 原生备份维护（版本自愈） ----------
$isAnyPatched = $hasLatestHook -or $hasLegacyHook
if (Test-Path -LiteralPath $BackupPath) {
    if (-not $isAnyPatched) {
        $currentHash = (Get-FileHash -LiteralPath $AsarPath -Algorithm SHA256).Hash
        $backupHash  = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
        if ($currentHash -ne $backupHash) {
            Copy-Item -LiteralPath $AsarPath -Destination $BackupPath -Force
            Ok "检测到客户端版本已升级，已自动更新原生备份：app.asar.stock-backup"
        }
    }
} elseif ($isAnyPatched) {
    Write-Host "[!] app.asar 已含主题钩子但缺少原生备份，跳过备份以免污染（如后续异常请重新安装客户端）。" -ForegroundColor Yellow
} else {
    Copy-Item -LiteralPath $AsarPath -Destination $BackupPath
    Ok "已备份原版 app.asar -> app.asar.stock-backup"
}

# ---------- app.asar 补丁（临时文件写入 + 原始字节整包/分块自检 + 原子替换 + 失败回滚） ----------
$skipPatch = $hasLatestHook
if ($hasLegacyHook -and -not $hasLatestHook) {
    $legacyPattern = '(?s)[ \t]*// === Antigravity custom-theme injection hook(?: v\d+)? \(start\) ===.*?// === Antigravity custom-theme injection hook(?: v\d+)? \(end\) ===\r?\n?'
    if ($utils -match $legacyPattern) {
        $utils = [regex]::Replace($utils, $legacyPattern, '', 1)
        Write-Host "[*] 检测到旧版主题钩子，正在升级至 $HookVersion..." -ForegroundColor Cyan
    } else {
        $skipPatch = $true
    }
}

if ($skipPatch) {
    Ok "app.asar 已包含最新主题钩子（$HookVersion），跳过补丁"
} else {
    $entrySpan = Find-JsonEntrySpan -Json $hdr.Json -EntryKey 'utils.js' -Offset $entry.Offset -Size $entry.Size
    if (-not $entrySpan) {
        Die "无法在 asar 头部 JSON 中定位目标 utils.js 条目边界，已取消修改"
    }

    $anchorIdx = $utils.IndexOf($Anchor)
    if ($anchorIdx -lt 0) { Die "未找到代码注入锚点，已取消修改" }
    $lineStart = $utils.LastIndexOf("`n", $anchorIdx) + 1
    $prefix    = $utils.Substring($lineStart, $anchorIdx - $lineStart)
    $insertAt  = if ($prefix -match '^\s*$') { $lineStart } else { $anchorIdx }

    $hook = @"
$HookStartMarker
        win.webContents.on('dom-ready', () => {
            try {
                const path_ = require('path');
                const fs_ = require('fs');
                const dirs = [
                    path_.join(process.resourcesPath, 'custom-theme'),
                    path_.join(process.env.APPDATA || '', 'Antigravity', 'custom-theme')
                ];
                const readThemeFile = (name) => {
                    for (const d of dirs) {
                        try {
                            const f = path_.join(d, name);
                            if (fs_.existsSync(f)) return fs_.readFileSync(f, 'utf8');
                        } catch (e) { }
                    }
                    return null;
                };
                const css = readThemeFile('current.css');
                if (css && css.trim()) win.webContents.insertCSS(css).catch(() => { });
                const js = readThemeFile('current.js');
                if (js && js.trim()) win.webContents.executeJavaScript(js, true).catch(() => { });
            } catch (e) { }
        });
        $HookEndMarker

"@
    $newUtils = $utils.Substring(0, $insertAt) + $hook + $utils.Substring($insertAt)
    $newUtilsBytes = [System.Text.Encoding]::UTF8.GetBytes($newUtils)

    $blockSize = if ($entry.BlockSize -gt 0) { $entry.BlockSize } else { 4194304 }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $blocks = @()
        for ($i = 0; $i -lt $newUtilsBytes.Length; $i += $blockSize) {
            $len = [Math]::Min($blockSize, $newUtilsBytes.Length - $i)
            $blocks += (& $hex $sha.ComputeHash($newUtilsBytes, $i, $len))
        }
        $fullHash = & $hex $sha.ComputeHash($newUtilsBytes)
    } finally {
        $sha.Dispose()
    }

    $newOffset = $hdr.Bytes.LongLength - $hdr.DataStart
    $newEntryJson = '"utils.js":{"size":' + $newUtilsBytes.Length + ',"offset":"' + $newOffset + '","integrity":{"algorithm":"SHA256","hash":"' + $fullHash + '","blockSize":' + $blockSize + ',"blocks":[' + (($blocks | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']}}'
    $newJson = $hdr.Json.Substring(0, $entrySpan.Index) + $newEntryJson + $hdr.Json.Substring($entrySpan.Index + $entrySpan.Length)

    $jsonBytes   = [System.Text.Encoding]::UTF8.GetBytes($newJson)
    $pad         = (4 - ($jsonBytes.Length % 4)) % 4
    $H           = 8 + $jsonBytes.Length + $pad
    $payloadSize = 4 + $jsonBytes.Length + $pad
    $origDataLen = $hdr.Bytes.Length - [int]$hdr.DataStart
    $out = New-Object byte[] (8 + $H + $origDataLen + $newUtilsBytes.Length)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]4), 0, $out, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$H), 0, $out, 4, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$payloadSize), 0, $out, 8, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$jsonBytes.Length), 0, $out, 12, 4)
    [Array]::Copy($jsonBytes, 0, $out, 16, $jsonBytes.Length)
    [Array]::Copy($hdr.Bytes, [int]$hdr.DataStart, $out, 8 + $H, $origDataLen)
    [Array]::Copy($newUtilsBytes, 0, $out, 8 + $H + $origDataLen, $newUtilsBytes.Length)

    $TmpPath = "$AsarPath.tmp"
    $asarTouched = $false
    try {
        [System.IO.File]::WriteAllBytes($TmpPath, $out)

        # 替换前先对 app.asar.tmp 原始字节流做整包 SHA256 + blocks 逐块 SHA256 自检
        $vHdr = Read-AsarHeader -Path $TmpPath
        $vEntries = @(Find-AsarEntry -Header $vHdr -FileName 'utils.js')
        $tmpVerified = $false
        foreach ($ve in $vEntries) {
            $vContent = [System.Text.Encoding]::UTF8.GetString($vHdr.Bytes, [int]($vHdr.DataStart + $ve.Offset), $ve.Size)
            if (-not $vContent.Contains($HookStartMarker) -or -not $vContent.Contains($Anchor)) { continue }
            if (Test-AsarBytesIntegrity -Header $vHdr -Entry $ve) {
                $tmpVerified = $true
                break
            }
        }
        if (-not $tmpVerified) {
            throw "临时文件 app.asar.tmp 完整性校验失败（整包或分块 SHA256 不匹配）"
        }

        $asarTouched = $true
        try {
            [System.IO.File]::Replace($TmpPath, $AsarPath, $null, $true)
        } catch {
            Move-Item -LiteralPath $TmpPath -Destination $AsarPath -Force
        }
        Ok ("app.asar 补丁完成（+{0} 字节）" -f ($out.Length - $hdr.Bytes.Length))
    } catch {
        if ($asarTouched -and (Test-Path -LiteralPath $BackupPath)) {
            try {
                Copy-Item -LiteralPath $BackupPath -Destination $AsarPath -Force
                Write-Host "[!] 已从 app.asar.stock-backup 自动回滚 app.asar。" -ForegroundColor Yellow
            } catch {
                Write-Host "[X] 自动回滚失败，请手动用 app.asar.stock-backup 覆盖 app.asar。" -ForegroundColor Red
            }
        }
        Die "写入或校验 app.asar 失败：$($_.Exception.Message)"
    } finally {
        if (Test-Path -LiteralPath $TmpPath) {
            Remove-Item -LiteralPath $TmpPath -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------- 最终只读自检：确认线上 app.asar 钩子存在且原始字节整包+分块 integrity 一致 ----------
try {
    $finalHdr = Read-AsarHeader -Path $AsarPath
    $finalEntries = @(Find-AsarEntry -Header $finalHdr -FileName 'utils.js')
    $verified = $false
    foreach ($fe in $finalEntries) {
        $fContent = [System.Text.Encoding]::UTF8.GetString($finalHdr.Bytes, [int]($finalHdr.DataStart + $fe.Offset), $fe.Size)
        if (-not $fContent.Contains($HookStartMarker)) { continue }
        if (Test-AsarBytesIntegrity -Header $finalHdr -Entry $fe) {
            $verified = $true
            break
        }
    }
    if (-not $verified) {
        if (Test-Path -LiteralPath $BackupPath) {
            Copy-Item -LiteralPath $BackupPath -Destination $AsarPath -Force -ErrorAction SilentlyContinue
        }
        Die "自检失败：钩子缺失或 integrity 不一致（已尝试回滚，可运行 uninstall.bat 后重试）"
    }
} catch {
    Die "自检异常：$($_.Exception.Message)"
}
Ok "自检通过：钩子已注入且整包与分块 integrity 一致"

Write-Host ""
Write-Host "================ 安装完成 ================" -ForegroundColor Cyan
Write-Host " 启动 Antigravity，点击右上角胶囊按钮即可切换主题。"
Write-Host " 卸载：powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall"
Write-Host "=========================================="
