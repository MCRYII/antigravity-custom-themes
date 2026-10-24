# =====================================================================
#  Antigravity Custom Themes - One-Click Installer
#  1) 备份 app.asar  2) 注入主题加载钩子（idempotent）  3) 分发主题文件
#  用法:  右键"使用 PowerShell 运行" 或 双击 install.bat
#  卸载:  powershell -File install.ps1 -Uninstall
# =====================================================================
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResDir     = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\resources'
$AsarPath   = Join-Path $ResDir 'app.asar'
$BackupPath = Join-Path $ResDir 'app.asar.stock-backup'
$ThemeDirs  = @(
    (Join-Path $ResDir 'custom-theme'),
    (Join-Path $env:APPDATA 'Antigravity\custom-theme')
)
$Marker   = 'custom-theme injection hook'
$Anchor   = "win.webContents.on('did-finish-load'"
$Payloads = @('current.css', 'current.js')

function Die([string]$msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }
function Ok([string]$msg)  { Write-Host "[OK] $msg" -ForegroundColor Green }

# ---------- 卸载 ----------
if ($Uninstall) {
    if (Test-Path $BackupPath) {
        Copy-Item $BackupPath $AsarPath -Force
        Ok "已还原原生 app.asar（来自 app.asar.stock-backup）"
    } else {
        Write-Host "[!] 未找到 app.asar.stock-backup，跳过还原" -ForegroundColor Yellow
    }
    foreach ($d in $ThemeDirs) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force; Ok "已删除 $d" }
    }
    Write-Host "`n卸载完成。重启 Antigravity 即恢复原版外观。"
    exit 0
}

# ---------- 前置检查 ----------
if (-not (Test-Path $AsarPath)) {
    Die "未找到 Antigravity 客户端：$AsarPath`n    请确认已在默认位置安装官方 Antigravity。"
}
foreach ($f in $Payloads) {
    if (-not (Test-Path (Join-Path $ScriptDir $f))) {
        Die "缺少主题文件 $f —— 请在完整的主题包内运行本脚本。"
    }
}

# 关闭正在运行的客户端（asar 与主题文件需要落盘）
$running = Get-Process Antigravity -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "检测到 Antigravity 正在运行。"
    $ans = Read-Host "自动关闭它并继续安装？(Y/N)"
    if ($ans -match '^[Yy]') {
        $running | Stop-Process -Force
        Start-Sleep -Seconds 2
        Ok "已关闭 Antigravity"
    } else {
        Die "请手动关闭 Antigravity 后重新运行本脚本。"
    }
}

# ---------- 分发主题文件 ----------
foreach ($d in $ThemeDirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    foreach ($f in $Payloads) {
        Copy-Item (Join-Path $ScriptDir $f) (Join-Path $d $f) -Force
    }
}
Ok ("主题文件已安装到 {0} 个位置" -f $ThemeDirs.Count)

# ---------- app.asar 补丁 ----------
if (-not (Test-Path $BackupPath)) {
    Copy-Item $AsarPath $BackupPath
    Ok "已备份原版 app.asar -> app.asar.stock-backup"
}

$bytes = [System.IO.File]::ReadAllBytes($AsarPath)
$jsonLen   = [BitConverter]::ToUInt32($bytes, 12)
$dataStart = 12 + [BitConverter]::ToUInt32($bytes, 8)
$json      = [System.Text.Encoding]::UTF8.GetString($bytes, 16, $jsonLen)

if ($json.Contains($Marker)) {
    Ok "app.asar 已包含主题钩子，跳过补丁"
} else {
    # 解析头部，定位 dist/utils.js
    $header = $json | ConvertFrom-Json
    $entry  = $header.files.dist.files.'utils.js'
    if (-not $entry) { Die "asar 头部未找到 dist/utils.js（客户端结构可能已变化）" }
    $uOffset = [int64]$entry.offset; $uSize = [int]$entry.size
    $blockSize = [int]$entry.integrity.blockSize

    $utils = [System.Text.Encoding]::UTF8.GetString($bytes, [int]($dataStart + $uOffset), $uSize)
    if ($utils.Contains($Marker)) { Die "检测到异常状态：正文含钩子但头部无标记，请用 app.asar.stock-backup 还原后重试" }
    $idx = $utils.IndexOf($Anchor)
    if ($idx -lt 0) { Die "未找到代码注入锚点（客户端版本可能已变化），已取消修改" }

    # 注入点对齐到锚点所在行的行首
    $lineStart = $utils.LastIndexOf("`n", $idx) + 1
    $hook = @'
// === Antigravity custom-theme injection hook (start) ===
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
        // === Antigravity custom-theme injection hook (end) ===

'@
    $newUtils = $utils.Substring(0, $lineStart) + $hook + $utils.Substring($lineStart)
    $newUtilsBytes = [System.Text.Encoding]::UTF8.GetBytes($newUtils)

    # 重算 asar integrity（整文件 SHA256 + 分块 SHA256）
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hex = { param($b) ([System.BitConverter]::ToString($b)).Replace('-', '').ToLower() }
    $blocks = @()
    for ($i = 0; $i -lt $newUtilsBytes.Length; $i += $blockSize) {
        $len = [Math]::Min($blockSize, $newUtilsBytes.Length - $i)
        $chunk = New-Object byte[] $len
        [Array]::Copy($newUtilsBytes, $i, $chunk, 0, $len)
        $blocks += (& $hex $sha.ComputeHash($chunk))
    }
    $fullHash = & $hex $sha.ComputeHash($newUtilsBytes)
    $sha.Dispose()

    # 头部精准替换：新补丁的 utils.js 追加到数据区末尾，仅改它的 size / offset / integrity
    # （asar 头部存在多个同名 utils.js 条目，必须用「解析出的完整原条目」做字面量整段替换，保证唯一命中）
    $newOffset = $bytes.Length - $dataStart
    $oldEntryJson = '"utils.js":{"size":' + $entry.size + ',"offset":"' + $entry.offset + '","integrity":{"algorithm":"SHA256","hash":"' + $entry.integrity.hash + '","blockSize":' + $entry.integrity.blockSize + ',"blocks":[' + (($entry.integrity.blocks | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']}}'
    $newEntryJson = '"utils.js":{"size":' + $newUtilsBytes.Length + ',"offset":"' + $newOffset + '","integrity":{"algorithm":"SHA256","hash":"' + $fullHash + '","blockSize":' + $blockSize + ',"blocks":[' + (($blocks | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']}}'
    $entryCount = ([regex]::Matches($json, [regex]::Escape($oldEntryJson))).Count
    if ($entryCount -ne 1) { Die ("asar 头部条目匹配异常（{0} 处），已取消修改" -f $entryCount) }
    $newJson = $json.Replace($oldEntryJson, $newEntryJson)

    # 重建 asar：[4][H][payloadSize][strLen][json+pad][原数据区][新 utils.js]
    # 布局与 Electron/Chromium pickle 实测对齐：数据区起点 = 8 + H（H = 8 + jsonLen + pad）
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($newJson)
    $pad = (4 - ($jsonBytes.Length % 4)) % 4
    $H = 8 + $jsonBytes.Length + $pad
    $payloadSize = 4 + $jsonBytes.Length + $pad
    $out = New-Object byte[] (8 + $H + ($bytes.Length - $dataStart) + $newUtilsBytes.Length)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]4), 0, $out, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$H), 0, $out, 4, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$payloadSize), 0, $out, 8, 4)
    [Array]::Copy([BitConverter]::GetBytes([UInt32]$jsonBytes.Length), 0, $out, 12, 4)
    [Array]::Copy($jsonBytes, 0, $out, 16, $jsonBytes.Length)
    [Array]::Copy($bytes, $dataStart, $out, 8 + $H, $bytes.Length - $dataStart)
    [Array]::Copy($newUtilsBytes, 0, $out, 8 + $H + ($bytes.Length - $dataStart), $newUtilsBytes.Length)

    [System.IO.File]::WriteAllBytes($AsarPath, $out)
    Ok ("app.asar 补丁完成（+{0} 字节）" -f ($out.Length - $bytes.Length))

    # 自检：重新解析新文件
    $vbytes = [System.IO.File]::ReadAllBytes($AsarPath)
    $vJsonLen = [BitConverter]::ToUInt32($vbytes, 12)
    $vStart = 12 + [BitConverter]::ToUInt32($vbytes, 8)
    $vHeader = [System.Text.Encoding]::UTF8.GetString($vbytes, 16, $vJsonLen) | ConvertFrom-Json
    $vEntry = $vHeader.files.dist.files.'utils.js'
    $vUtils = [System.Text.Encoding]::UTF8.GetString($vbytes, [int]($vStart + [int64]$vEntry.offset), [int]$vEntry.size)
    if (-not $vUtils.Contains($Marker)) { Die "自检失败：新 asar 中未找到钩子" }
    $vsha = [System.Security.Cryptography.SHA256]::Create()
    $vUtilsBytes = [System.Text.Encoding]::UTF8.GetBytes($vUtils)
    $vHash = (& $hex $vsha.ComputeHash($vUtilsBytes))
    $vsha.Dispose()
    if ($vHash -ne $vEntry.integrity.hash) { Die "自检失败：integrity 校验不一致" }
    Ok "自检通过：钩子已注入且 integrity 一致"
}

Write-Host ""
Write-Host "================ 安装完成 ================" -ForegroundColor Cyan
Write-Host " 启动 Antigravity，点击右上角胶囊按钮即可切换主题。"
Write-Host " 卸载：powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall"
Write-Host "=========================================="
