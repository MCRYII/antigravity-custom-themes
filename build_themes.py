#!/usr/bin/env python3
"""
Antigravity Theme Compiler
读取 gemini-light.css, sky-light.css 及配置，打包生成 current.js，实现纯前端免刷新动态主题切换与下拉菜单。
"""
import os
import json

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def read_file(filename):
    path = os.path.join(BASE_DIR, filename)
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return ""

def main():
    gemini_css = read_file("gemini-light.css")
    sky_css = read_file("sky-light.css")
    cyan_css = read_file("cyan-light.css")
    orange_css = read_file("orange-light.css")
    red_css = read_file("red-light.css")

    # 各主题手绘现代高质感矢量 SVG 图标（15x15，微质感渐变）
    THEME_ICONS = {
        "gemini": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-gemini" x1="1" y1="1" x2="15" y2="15" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#4285F4"/><stop offset="35%" stop-color="#8B5CF6"/><stop offset="70%" stop-color="#EC4899"/><stop offset="100%" stop-color="#F59E0B"/></linearGradient></defs><path d="M8 1C8 4.866 4.866 8 1 8C4.866 8 8 11.134 8 15C8 11.134 11.134 8 15 8C11.134 8 8 4.866 8 1Z" fill="url(#ag-svg-gemini)"/><circle cx="8" cy="8" r="1.6" fill="#FFFFFF" fill-opacity="0.95"/></svg>',
        "sky": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-sun" x1="4" y1="4" x2="12" y2="12" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FDE047"/><stop offset="100%" stop-color="#EA580C"/></linearGradient><linearGradient id="ag-svg-ray" x1="8" y1="1" x2="8" y2="15" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#F59E0B"/><stop offset="100%" stop-color="#D97706"/></linearGradient></defs><circle cx="8" cy="8" r="3.4" fill="url(#ag-svg-sun)"/><path d="M8 1.5V3M8 13V14.5M1.5 8H3M13 8H14.5M3.4 3.4L4.5 4.5M11.5 11.5L12.6 12.6M3.4 12.6L4.5 11.5M11.5 4.5L12.6 3.4" stroke="url(#ag-svg-ray)" stroke-width="1.6" stroke-linecap="round"/></svg>',
        "cyan": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-leaf" x1="1" y1="2" x2="15" y2="14" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#34D399"/><stop offset="60%" stop-color="#059669"/><stop offset="100%" stop-color="#0D9488"/></linearGradient><linearGradient id="ag-svg-wave" x1="2" y1="13" x2="14" y2="13" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#06B6D4"/><stop offset="100%" stop-color="#10B981"/></linearGradient></defs><path d="M14 2C10.5 2 6 4 4 8C2.5 11 3.5 13 4.5 13C6.5 13 11 11.5 13 8C14 6 14 3.5 14 2Z" fill="url(#ag-svg-leaf)"/><path d="M4 8C7 7.5 10 5.5 12 3" stroke="#A7F3D0" stroke-width="1.2" stroke-linecap="round"/><path d="M2 13.5C4 12 6.5 12 8.5 13.5C10.5 15 13 15 15 13.5" stroke="url(#ag-svg-wave)" stroke-width="1.5" stroke-linecap="round"/></svg>',
        "orange": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-sunset" x1="8" y1="3" x2="8" y2="9.5" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FBBF24"/><stop offset="60%" stop-color="#F97316"/><stop offset="100%" stop-color="#E11D48"/></linearGradient><linearGradient id="ag-svg-sea" x1="2" y1="10" x2="14" y2="14.5" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#EA580C"/><stop offset="50%" stop-color="#FB923C"/><stop offset="100%" stop-color="#FBBF24"/></linearGradient></defs><path d="M3.5 9.5C3.5 7 5.5 5 8 5C10.5 5 12.5 7 12.5 9.5H3.5Z" fill="url(#ag-svg-sunset)"/><path d="M8 2.5V3.8M4.2 4.2L5.1 5.1M11.8 4.2L10.9 5.1" stroke="#FBBF24" stroke-width="1.3" stroke-linecap="round"/><path d="M2 10.5H14M3.5 12.5H12.5M5.5 14.5H10.5" stroke="url(#ag-svg-sea)" stroke-width="1.4" stroke-linecap="round"/></svg>',
        "red": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-petal" x1="2" y1="2" x2="14" y2="14" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FB7185"/><stop offset="50%" stop-color="#E11D48"/><stop offset="100%" stop-color="#BE123C"/></linearGradient><radialGradient id="ag-svg-center" cx="8" cy="8" r="2.2" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FDE047"/><stop offset="100%" stop-color="#F59E0B"/></radialGradient></defs><circle cx="8" cy="4.8" r="2.7" fill="url(#ag-svg-petal)"/><circle cx="11.2" cy="7.1" r="2.7" fill="url(#ag-svg-petal)"/><circle cx="10" cy="11" r="2.7" fill="url(#ag-svg-petal)"/><circle cx="6" cy="11" r="2.7" fill="url(#ag-svg-petal)"/><circle cx="4.8" cy="7.1" r="2.7" fill="url(#ag-svg-petal)"/><circle cx="8" cy="8" r="2.2" fill="url(#ag-svg-center)"/><circle cx="8" cy="8" r="0.8" fill="#FFFBEB"/></svg>',
        "stock": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="ag-svg-stock" x1="2" y1="2" x2="14" y2="14" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#3B82F6"/><stop offset="100%" stop-color="#64748B"/></linearGradient></defs><path d="M13.5 6.5C13 4.2 11 2.5 8.5 2.5C5.5 2.5 3 4.8 2.6 7.8M13.5 3V6.5H10" stroke="url(#ag-svg-stock)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/><path d="M2.5 9.5C3 11.8 5 13.5 7.5 13.5C10.5 13.5 13 11.2 13.4 8.2M2.5 13V9.5H6" stroke="url(#ag-svg-stock)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
    }

    # 构建主题数据元信息
    themes_data = [
        {
            "id": "gemini",
            "name": "四色极光",
            "icon": THEME_ICONS["gemini"],
            "titlebarColor": "#E9F0FE",
            "symbolColor": "#1B2A4A",
            "css": gemini_css
        },
        {
            "id": "sky",
            "name": "蔚蓝晴空",
            "icon": THEME_ICONS["sky"],
            "titlebarColor": "#7EC8F6",
            "symbolColor": "#1B2A4A",
            "css": sky_css
        },
        {
            "id": "cyan",
            "name": "碧水青波",
            "icon": THEME_ICONS["cyan"],
            "titlebarColor": "#63D2C6",
            "symbolColor": "#0F3834",
            "css": cyan_css
        },
        {
            "id": "orange",
            "name": "落霞暖橙",
            "icon": THEME_ICONS["orange"],
            "titlebarColor": "#FFA066",
            "symbolColor": "#4A1E06",
            "css": orange_css
        },
        {
            "id": "red",
            "name": "丹霞绯红",
            "icon": THEME_ICONS["red"],
            "titlebarColor": "#F77E90",
            "symbolColor": "#451119",
            "css": red_css
        },
        {
            "id": "stock",
            "name": "官方原版",
            "icon": THEME_ICONS["stock"],
            "titlebarColor": None,
            "symbolColor": None,
            "css": ""
        }
    ]

    themes_json = json.dumps(themes_data, ensure_ascii=False)

    template = f'''// Antigravity Custom Theme Engine & Companion Script
// 自动注入右上角胶囊主题切换器 + 下拉菜单选择
(() => {{
    if (window.__antigravityThemeEngineLoaded) return;
    window.__antigravityThemeEngineLoaded = true;

    const THEMES = {themes_json};

    let savedSidebarColor = null;
    let lastAppliedOverlay = null;
    let lastIsDark = null;
    let lastActiveId = null;
    // 看图模态：系统窗口按钮区「贴合标题栏」临时色缓存
    let modalChromeActive = false;
    let modalChromeThemeId = null;
    let preModalOverlay = null;

    // 检测是否处于深色模式（Antigravity 客户端在 document.body 上切换 dark / dark-theme / theme-dark）
    function isDarkMode() {{
        return document.body.classList.contains('dark') ||
               document.body.classList.contains('theme-dark') ||
               document.body.classList.contains('dark-theme') ||
               document.documentElement.classList.contains('dark') ||
               document.documentElement.classList.contains('theme-dark');
    }}

    // 获取当前激活主题 ID（安全持久化）
    function getActiveThemeId() {{
        try {{
            return localStorage.getItem('antigravity_selected_theme') || 'gemini';
        }} catch (e) {{
            return 'gemini';
        }}
    }}

    function getTheme(id) {{
        return THEMES.find(t => t.id === id) || THEMES[0];
    }}

    // 把任意 CSS 颜色解析为 [r,g,b,a]
    function parseCssColor(str) {{
        if (!str || str === 'none' || str === 'transparent') return null;
        let m = str.match(/^#([0-9a-fA-F]{{3,8}})$/);
        if (m) {{
            let h = m[1];
            if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
            if (h.length === 6) return [parseInt(h.slice(0,2),16), parseInt(h.slice(2,4),16), parseInt(h.slice(4,6),16), 1];
        }}
        m = str.match(/rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:[,\s/]+([\d.]+))?\s*\)/);
        if (m) return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
        m = str.match(/color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)/);
        if (m) return [Math.round(+m[1]*255), Math.round(+m[2]*255), Math.round(+m[3]*255), 1];
        return null;
    }}

    function toHex(r, g, b) {{
        return '#' + [r,g,b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2,'0')).join('');
    }}

    // 依据底色亮度挑选对比色（深底配浅符号，浅底配深符号）
    function contrastColor(hex) {{
        const c = parseCssColor(hex);
        if (!c) return '#1B2A4A';
        const lum = (0.299*c[0] + 0.587*c[1] + 0.114*c[2]) / 255;
        return lum > 0.55 ? '#1B2A4A' : '#FFFFFF';
    }}

    // 动态提取宿主真实未偏色的 CSS 变量十六进制色值（1:1 复刻 Antigravity 官方 main.js 的 Bvb 取色算法）
    function readCssVarHex(varName, fallback) {{
        try {{
            const el = document.createElement('div');
            el.style.color = `var(${{varName}})`;
            el.style.display = 'none';
            document.body.appendChild(el);
            const computed = getComputedStyle(el).color;
            el.remove();
            const srgbMatch = computed.match(/color\\(srgb\\\\s+([\\\\d.]+)\\\\s+([\\\\d.]+)\\\\s+([\\\\d.]+)/);
            if (srgbMatch) {{
                const r = Math.round(parseFloat(srgbMatch[1]) * 255);
                const g = Math.round(parseFloat(srgbMatch[2]) * 255);
                const b = Math.round(parseFloat(srgbMatch[3]) * 255);
                return '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('');
            }}
            const rgbMatch = computed.match(/rgba?\\(([\\\\d]+),\\\\s*([\\\\d]+),\\\\s*([\\\\d]+)/);
            if (rgbMatch) {{
                const r = parseInt(rgbMatch[1], 10);
                const g = parseInt(rgbMatch[2], 10);
                const b = parseInt(rgbMatch[3], 10);
                return '#' + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('');
            }}
        }} catch (e) {{}}
        return fallback;
    }}

    // 动态应用主题样式
    function applyTheme(themeId) {{
        const theme = getTheme(themeId);
        const prevId = lastActiveId;
        try {{
            localStorage.setItem('antigravity_selected_theme', theme.id);
        }} catch (e) {{}}

        let styleEl = document.getElementById('antigravity-active-theme');
        if (!styleEl) {{
            styleEl = document.createElement('style');
            styleEl.id = 'antigravity-active-theme';
            (document.head || document.documentElement).appendChild(styleEl);
        }}
        styleEl.textContent = theme.css;

        lastActiveId = theme.id;
        lastIsDark = isDarkMode();

        // 仅在自定义主题之间切换或从自定义主题切回原版时执行标题栏色彩校准；
        // 若初次加载本就是官方原版，则完全不插手，留给官方原生代码处理
        if (theme.id !== 'stock' || (prevId && prevId !== 'stock')) {{
            enforceTitleBarColor(true);
        }}

        updateSelectorUI(theme.id);
        // 主题切换时若正在看图，立即重算系统按钮区同色
        syncModalChrome();
    }}

    // 强制校准原生标题栏覆盖色（防御 React 挂载后重设为纯白，浅色主题坚决防死黑）
    function enforceTitleBarColor(force = false) {{
        const activeId = getActiveThemeId();
        if (activeId === 'stock') {{
            // 官方原版：日常运行与刷新完全由官方原生接管，0 干预；
            // 仅在从自定义主题刚切回原版时（force === true），调用一次官方算法重置
            if (force) {{
                const isDark = isDarkMode();
                const color = readCssVarHex('--sidebar', isDark ? '#161616' : '#f2f2f2');
                const symbolColor = readCssVarHex('--foreground', isDark ? '#cccccc' : '#101010');
                if (!lastAppliedOverlay || lastAppliedOverlay.color !== color || lastAppliedOverlay.symbolColor !== symbolColor) {{
                    lastAppliedOverlay = {{ color: color, symbolColor: symbolColor, height: 30 }};
                    window.electronNative?.setTitleBarOverlay?.(lastAppliedOverlay);
                }}
            }}
            return;
        }}

        const theme = getTheme(activeId);
        const color = theme.titlebarColor || '#F3F3F3';
        const symbolColor = theme.symbolColor || '#1B2A4A';

        if (!force && lastAppliedOverlay &&
            lastAppliedOverlay.color === color &&
            lastAppliedOverlay.symbolColor === symbolColor &&
            lastAppliedOverlay.height === 30) {{
            return;
        }}

        lastAppliedOverlay = {{ color: color, symbolColor: symbolColor, height: 30 }};
        savedSidebarColor = color;
        window.electronNative?.setTitleBarOverlay?.(lastAppliedOverlay);
    }}

    // === 看图模态：把 Windows 原生系统按钮区（− □ ×）染成"与看图遮罩完全同一个颜色" ===
    // 取模态元素的实际渲染背景色（来自主题 --media-modal-bg），系统按钮区与遮罩 0 色差。
    // 官方原版（stock）在此直接退避：0 调用，完全呈现 app 原生外观。
    function applyModalChrome() {{
        const activeId = getActiveThemeId();
        if (activeId === 'stock') return;

        const modalEl = document.querySelector('[data-testid="media-modal"], [data-testid="mermaid-lightbox-viewport"]');
        if (!modalEl) return;

        // 已贴合且主题未变：不再重复读取样式（避免流式输出时高频 getComputedStyle）
        if (modalChromeActive && modalChromeThemeId === activeId) return;

        const bg = parseCssColor(getComputedStyle(modalEl).backgroundColor);
        if (!bg) return;
        const color = toHex(bg[0], bg[1], bg[2]);

        if (!modalChromeActive) {{
            preModalOverlay = lastAppliedOverlay ? {{ ...lastAppliedOverlay }} : null;
            modalChromeActive = true;
        }}
        modalChromeThemeId = activeId;

        const overlay = {{ color: color, symbolColor: contrastColor(color), height: 30 }};
        lastAppliedOverlay = overlay;
        window.electronNative?.setTitleBarOverlay?.(overlay);
    }}

    function restoreModalChrome() {{
        if (!modalChromeActive) return;
        modalChromeActive = false;
        modalChromeThemeId = null;
        const restore = preModalOverlay;
        preModalOverlay = null;
        if (restore) {{
            lastAppliedOverlay = restore;
            window.electronNative?.setTitleBarOverlay?.(restore);
        }} else {{
            // 无历史缓存时按当前主题重新校准
            lastAppliedOverlay = null;
            enforceTitleBarColor(true);
        }}
    }}

    // 监听看图/流程图模态的挂载与卸载
    function syncModalChrome() {{
        const modal = document.querySelector('[data-testid="media-modal"], [data-testid="mermaid-lightbox-viewport"]');
        if (modal) applyModalChrome();
        else restoreModalChrome();
    }}

    // 同步深色与主题状态，按需更新标题栏与选择器风格
    function syncThemeState() {{
        const currentDark = isDarkMode();
        const currentId = getActiveThemeId();
        if (currentDark !== lastIsDark || currentId !== lastActiveId) {{
            lastIsDark = currentDark;
            lastActiveId = currentId;
            if (currentId !== 'stock') {{
                enforceTitleBarColor(true);
            }}
            updateSelectorUI(currentId);
        }}
    }}

    // 更新胶囊与下拉项的选中标记及深浅色自适应风格
    function updateSelectorUI(activeId) {{
        const theme = getTheme(activeId);
        const isDarkTheme = (activeId === 'stock') && isDarkMode();
        const iconEl = document.getElementById('antigravity-theme-icon');
        const labelEl = document.getElementById('antigravity-theme-label');
        const btn = document.getElementById('antigravity-theme-btn');
        const dropdown = document.getElementById('antigravity-theme-dropdown');

        if (iconEl) iconEl.innerHTML = theme.icon;
        if (labelEl) labelEl.textContent = theme.name;

        if (btn) {{
            if (isDarkTheme) {{
                btn.style.color = '#F3F4F6';
                btn.style.background = 'rgba(255, 255, 255, 0.08)';
                btn.style.borderColor = 'rgba(255, 255, 255, 0.15)';
                btn.style.boxShadow = '0 1px 2px rgba(0, 0, 0, 0.2)';
            }} else {{
                btn.style.color = '#374151';
                btn.style.background = 'rgba(255, 255, 255, 0.72)';
                btn.style.borderColor = 'rgba(0, 0, 0, 0.12)';
                btn.style.boxShadow = '0 1px 2px rgba(0, 0, 0, 0.04)';
            }}
        }}

        if (dropdown) {{
            if (isDarkTheme) {{
                dropdown.style.background = 'rgba(24, 24, 27, 0.96)';
                dropdown.style.borderColor = 'rgba(255, 255, 255, 0.12)';
                dropdown.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.4), 0 2px 6px rgba(0, 0, 0, 0.2)';
            }} else {{
                dropdown.style.background = 'rgba(255, 255, 255, 0.96)';
                dropdown.style.borderColor = 'rgba(0, 0, 0, 0.08)';
                dropdown.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.06)';
            }}
        }}

        document.querySelectorAll('.antigravity-theme-item').forEach(el => {{
            const tid = el.dataset.themeId;
            const isCurrent = tid === activeId;
            el.style.color = isDarkTheme ? '#F3F4F6' : '#1B2A4A';
            el.style.background = isCurrent 
                ? (isDarkTheme ? 'rgba(66, 133, 244, 0.25)' : 'rgba(66, 133, 244, 0.12)')
                : 'transparent';
            el.style.fontWeight = isCurrent ? '600' : 'normal';
        }});
    }}

    // 挂载右上角主题选择器
    function mountThemeSelector() {{
        const toolbar = document.querySelector('[data-testid="pane-titlebar-toolbar"]');
        if (!toolbar) return;

        const existing = document.getElementById('antigravity-theme-selector');
        if (existing) {{
            if (toolbar.contains(existing)) return;
            existing.remove();
        }}

        const currentId = getActiveThemeId();
        const currentTheme = getTheme(currentId);

        const container = document.createElement('div');
        container.id = 'antigravity-theme-selector';
        container.style.cssText = 'position: relative; display: inline-flex; align-items: center; margin-right: 8px; flex: 0 0 auto; user-select: none; z-index: 10000;';

        const btn = document.createElement('button');
        btn.id = 'antigravity-theme-btn';
        btn.setAttribute('type', 'button');

        // 浅白磨砂卡片按钮：对标原版高质感微立体视觉，不塌陷，半透微磨砂
        btn.style.cssText = `
            display: inline-flex;
            align-items: center;
            justify-content: center;
            height: 26px;
            width: auto;
            min-width: unset;
            max-width: none;
            padding: 0 8px;
            font-size: 12px;
            font-weight: 500;
            color: #374151;
            background: rgba(255, 255, 255, 0.72);
            border: 1px solid rgba(0, 0, 0, 0.12);
            border-radius: 6px;
            box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            cursor: pointer;
            transition: all 0.15s ease;
            outline: none;
            gap: 5px;
            font-family: inherit;
            line-height: 1;
            white-space: nowrap;
            flex: 0 0 auto;
            user-select: none;
        `;

        btn.innerHTML = `
            <span id="antigravity-theme-icon" style="display: inline-flex; align-items: center; justify-content: center; width: 15px; height: 15px; flex-shrink: 0; line-height: 1;">${{currentTheme.icon}}</span>
            <span id="antigravity-theme-label" style="line-height: 1; display: inline-block; white-space: nowrap;">${{currentTheme.name}}</span>
            <span style="font-size: 9px; opacity: 0.6; line-height: 1; margin-left: 1px; display: inline-block;">▾</span>
        `;

        btn.onmouseenter = () => {{
            const isDarkTheme = (getActiveThemeId() === 'stock') && isDarkMode();
            if (isDarkTheme) {{
                btn.style.background = 'rgba(255, 255, 255, 0.14)';
                btn.style.borderColor = 'rgba(255, 255, 255, 0.25)';
                btn.style.boxShadow = '0 1px 3px rgba(0, 0, 0, 0.3)';
            }} else {{
                btn.style.background = 'rgba(255, 255, 255, 0.95)';
                btn.style.borderColor = 'rgba(0, 0, 0, 0.2)';
                btn.style.boxShadow = '0 1px 3px rgba(0, 0, 0, 0.08)';
            }}
        }};
        btn.onmouseleave = () => {{
            const isDarkTheme = (getActiveThemeId() === 'stock') && isDarkMode();
            if (isDarkTheme) {{
                btn.style.background = 'rgba(255, 255, 255, 0.08)';
                btn.style.borderColor = 'rgba(255, 255, 255, 0.15)';
                btn.style.boxShadow = '0 1px 2px rgba(0, 0, 0, 0.2)';
            }} else {{
                btn.style.background = 'rgba(255, 255, 255, 0.72)';
                btn.style.borderColor = 'rgba(0, 0, 0, 0.12)';
                btn.style.boxShadow = '0 1px 2px rgba(0, 0, 0, 0.04)';
            }}
        }};

        // 下拉菜单采用 Portal 模式直接挂在 document.body，彻底杜绝宿主容器 overflow:hidden 的截断
        let dropdown = document.getElementById('antigravity-theme-dropdown');
        if (!dropdown) {{
            dropdown = document.createElement('div');
            dropdown.id = 'antigravity-theme-dropdown';
            document.body.appendChild(dropdown);
        }}

        dropdown.style.cssText = `
            display: none;
            position: fixed;
            background: rgba(255, 255, 255, 0.96);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(0, 0, 0, 0.08);
            border-radius: 8px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.06);
            padding: 4px;
            box-sizing: border-box;
            max-height: 280px;
            overflow-y: auto;
            scrollbar-width: thin;
            z-index: 9999999;
        `;
        dropdown.innerHTML = '';

        THEMES.forEach(t => {{
            const isCurrent = t.id === currentId;
            const item = document.createElement('div');
            item.className = 'antigravity-theme-item';
            item.dataset.themeId = t.id;
            item.style.cssText = `
                display: flex;
                align-items: center;
                justify-content: flex-start;
                padding: 6px 8px;
                border-radius: 6px;
                font-size: 12px;
                cursor: pointer;
                color: #1B2A4A;
                transition: all 0.12s ease;
                margin-bottom: 2px;
                font-weight: ${{isCurrent ? '600' : 'normal'}};
                background: ${{isCurrent ? 'rgba(66, 133, 244, 0.12)' : 'transparent'}};
                box-sizing: border-box;
            `;
            item.innerHTML = `
                <span style="display: inline-flex; align-items: center; gap: 7px; width: 100%;">
                    <span style="display: inline-flex; align-items: center; justify-content: center; width: 15px; height: 15px; flex-shrink: 0; line-height: 1;">${{t.icon}}</span>
                    <span style="font-size: 12px; line-height: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${{t.name}}</span>
                </span>
            `;

            item.onmouseenter = () => {{
                if (item.dataset.themeId !== getActiveThemeId()) {{
                    const isDarkTheme = (getActiveThemeId() === 'stock') && isDarkMode();
                    item.style.background = isDarkTheme ? 'rgba(255, 255, 255, 0.08)' : 'rgba(66, 133, 244, 0.08)';
                }}
            }};
            item.onmouseleave = () => {{
                const isNow = item.dataset.themeId === getActiveThemeId();
                const isDarkTheme = (getActiveThemeId() === 'stock') && isDarkMode();
                item.style.background = isNow
                    ? (isDarkTheme ? 'rgba(66, 133, 244, 0.25)' : 'rgba(66, 133, 244, 0.12)')
                    : 'transparent';
            }};
            item.onclick = (e) => {{
                e.stopPropagation();
                applyTheme(t.id);
                dropdown.style.display = 'none';
            }};
            dropdown.appendChild(item);
        }});

        function updateDropdownPosition() {{
            const rect = btn.getBoundingClientRect();
            dropdown.style.top = `${{rect.bottom + 6}}px`;
            dropdown.style.left = `${{rect.left}}px`;
            dropdown.style.right = 'auto';
            dropdown.style.width = `${{rect.width}}px`;
            dropdown.style.minWidth = 'unset';
            dropdown.style.boxSizing = 'border-box';
        }}

        btn.onclick = (e) => {{
            e.stopPropagation();
            const isOpen = dropdown.style.display === 'block';
            if (!isOpen) {{
                updateDropdownPosition();
                dropdown.style.display = 'block';
            }} else {{
                dropdown.style.display = 'none';
            }}
        }};

        if (!window.__antigravityThemeListenersAttached) {{
            window.__antigravityThemeListenersAttached = true;
            document.addEventListener('click', (e) => {{
                const dd = document.getElementById('antigravity-theme-dropdown');
                const b = document.getElementById('antigravity-theme-btn');
                if (dd && b && !b.contains(e.target) && !dd.contains(e.target)) {{
                    dd.style.display = 'none';
                }}
            }});

            document.addEventListener('keydown', (e) => {{
                if (e.key === 'Escape') {{
                    const dd = document.getElementById('antigravity-theme-dropdown');
                    if (dd) dd.style.display = 'none';
                }}
            }});

            window.addEventListener('resize', () => {{
                const dd = document.getElementById('antigravity-theme-dropdown');
                if (dd) dd.style.display = 'none';
            }});
        }}

        container.appendChild(btn);

        // 插在最左边（⋮ 菜单的前面）
        toolbar.insertBefore(container, toolbar.firstChild);
        updateSelectorUI(currentId);
        if (currentId !== 'stock') {{
            enforceTitleBarColor(true);
        }}
    }}

    // 立即初始化当前主题
    applyTheme(getActiveThemeId());

    // 立即尝试挂载与标题栏初始化
    mountThemeSelector();
    syncModalChrome();

    // 动态监听 DOM 变化：挂载选择器、主题/深浅模式同步、看图模态挂载/卸载
    const observer = new MutationObserver(() => {{
        mountThemeSelector();
        syncModalChrome();
        syncThemeState();
    }});
    observer.observe(document.body, {{ childList: true, subtree: true, attributes: true, attributeFilter: ['class'] }});
    observer.observe(document.documentElement, {{ attributes: true, attributeFilter: ['class'] }});
}})();
'''

    # 写入 current.js
    current_js_path = os.path.join(BASE_DIR, "current.js")
    with open(current_js_path, "w", encoding="utf-8") as f:
        f.write(template)
    print(f"[OK] Generated {current_js_path}")

    # current.css：手工维护的「主题无关通用规则」，构建脚本严禁改写它。
    # 它承载看图模态胶囊坞、缩放条、用户消息浮条等跨主题通用避让规则，
    # 由本仓库直接维护并原样同步到运行时目录。
    current_css_path = os.path.join(BASE_DIR, "current.css")
    if not os.path.exists(current_css_path):
        print(f"[WARN] current.css missing: {current_css_path}")

    # 自动分发到 Windows 运行时与持久化母库目录及 WSL 镜像备份
    import shutil
    target_dirs = [
        "/mnt/c/Users/MCRYII/AppData/Local/Programs/Antigravity/resources/custom-theme",
        "/mnt/c/Users/MCRYII/AppData/Roaming/Antigravity/custom-theme",
        os.path.expanduser("~/.antigravity-custom-theme-backup")
    ]
    sync_files = [
        "gemini-light.css",
        "sky-light.css",
        "cyan-light.css",
        "orange-light.css",
        "red-light.css",
        "stock.css",
        "build_themes.py",
        "指南.md",
        "README.md"
    ]
    for tdir in target_dirs:
        if os.path.exists(tdir):
            try:
                shutil.copy2(current_js_path, os.path.join(tdir, "current.js"))
                shutil.copy2(current_css_path, os.path.join(tdir, "current.css"))
                for fname in sync_files:
                    src = os.path.join(BASE_DIR, fname)
                    if os.path.exists(src):
                        shutil.copy2(src, os.path.join(tdir, fname))
                print(f"[SYNC] Synced to target directory: {tdir}")
            except Exception as e:
                print(f"[WARN] Failed to sync to {tdir}: {e}")

if __name__ == "__main__":
    main()
