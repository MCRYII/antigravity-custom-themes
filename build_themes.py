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

    # 构建主题数据元信息
    themes_data = [
        {
            "id": "gemini",
            "name": "Gemini 四色",
            "icon": "🌈",
            "titlebarColor": "#E9F0FE",
            "symbolColor": "#1B2A4A",
            "css": gemini_css
        },
        {
            "id": "sky",
            "name": "蔚蓝晴空",
            "icon": "☀️",
            "titlebarColor": "#7EC8F6",
            "symbolColor": "#1B2A4A",
            "css": sky_css
        },
        {
            "id": "stock",
            "name": "官方原版",
            "icon": "🔄",
            "titlebarColor": "#F3F3F3",
            "symbolColor": "#1B2A4A",
            "css": ""
        }
    ]

    themes_json = json.dumps(themes_data, ensure_ascii=False)

    template = f'''// Antigravity Custom Theme Engine & Companion Script
// 自动注入右上角胶囊主题切换器 + 下拉菜单选择 + 看图大图/流程图纯透明穿透
(() => {{
    if (window.__antigravityThemeEngineLoaded) return;
    window.__antigravityThemeEngineLoaded = true;

    const THEMES = {themes_json};

    let modalOpen = false;
    let savedSidebarColor = null;

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

    // 动态应用主题样式
    function applyTheme(themeId) {{
        const theme = getTheme(themeId);
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

        // 同步更新原生标题栏按钮底色（零色差融合）
        if (!modalOpen) {{
            const isDark = document.documentElement.classList.contains('dark');
            const color = isDark ? '#18181B' : (theme.titlebarColor || '#F3F3F3');
            const symbolColor = isDark ? '#FFFFFF' : (theme.symbolColor || '#1B2A4A');
            savedSidebarColor = color;
            window.electronNative?.setTitleBarOverlay?.({{
                color: color,
                symbolColor: symbolColor,
                height: 30
            }});
        }}

        updateSelectorUI(theme.id);
    }}

    // 更新胶囊与下拉项的选中标记
    function updateSelectorUI(activeId) {{
        const theme = getTheme(activeId);
        const iconEl = document.getElementById('antigravity-theme-icon');
        const labelEl = document.getElementById('antigravity-theme-label');
        if (iconEl) iconEl.textContent = theme.icon;
        if (labelEl) labelEl.textContent = theme.name;

        document.querySelectorAll('.antigravity-theme-item').forEach(el => {{
            const tid = el.dataset.themeId;
            const check = el.querySelector('.theme-check');
            const isCurrent = tid === activeId;
            if (check) check.style.visibility = isCurrent ? 'visible' : 'hidden';
            el.style.background = isCurrent ? 'rgba(66, 133, 244, 0.12)' : 'transparent';
            el.style.fontWeight = isCurrent ? '600' : 'normal';
        }});
    }}

    // 挂载右上角胶囊与下拉菜单
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
        btn.style.cssText = `
            display: inline-flex;
            align-items: center;
            justify-content: center;
            height: 26px;
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
        `;

        btn.innerHTML = `
            <span id="antigravity-theme-icon" style="font-size: 13px; line-height: 1;">${{currentTheme.icon}}</span>
            <span id="antigravity-theme-label" style="line-height: 1;">${{currentTheme.name}}</span>
            <span style="font-size: 9px; opacity: 0.6; line-height: 1; margin-left: 1px;">▾</span>
        `;

        btn.onmouseenter = () => {{
            btn.style.background = 'rgba(255, 255, 255, 0.95)';
            btn.style.borderColor = 'rgba(0, 0, 0, 0.2)';
            btn.style.boxShadow = '0 1px 3px rgba(0, 0, 0, 0.08)';
        }};
        btn.onmouseleave = () => {{
            btn.style.background = 'rgba(255, 255, 255, 0.72)';
            btn.style.borderColor = 'rgba(0, 0, 0, 0.12)';
            btn.style.boxShadow = '0 1px 2px rgba(0, 0, 0, 0.04)';
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
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.16), 0 2px 8px rgba(0, 0, 0, 0.08);
            padding: 6px;
            min-width: 150px;
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
                justify-content: space-between;
                padding: 7px 12px;
                border-radius: 8px;
                font-size: 12px;
                cursor: pointer;
                color: #1B2A4A;
                transition: all 0.12s ease;
                margin-bottom: 2px;
                font-weight: ${{isCurrent ? '600' : 'normal'}};
                background: ${{isCurrent ? 'rgba(66, 133, 244, 0.12)' : 'transparent'}};
            `;
            item.innerHTML = `
                <span style="display: flex; align-items: center; gap: 8px;">
                    <span style="font-size: 14px;">${{t.icon}}</span>
                    <span>${{t.name}}</span>
                </span>
                <span class="theme-check" style="font-size: 11px; font-weight: bold; color: #1A73E8; visibility: ${{isCurrent ? 'visible' : 'hidden'}};">✓</span>
            `;

            item.onmouseenter = () => {{
                if (item.dataset.themeId !== getActiveThemeId()) {{
                    item.style.background = 'rgba(66, 133, 244, 0.08)';
                }}
            }};
            item.onmouseleave = () => {{
                const isNow = item.dataset.themeId === getActiveThemeId();
                item.style.background = isNow ? 'rgba(66, 133, 244, 0.12)' : 'transparent';
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
            dropdown.style.right = `${{Math.max(8, window.innerWidth - rect.right)}}px`;
            dropdown.style.left = 'auto';
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
    }}

    // 大图与 Mermaid 流程图原生标题栏全透明穿透
    const updateOverlay = () => {{
        try {{
            const modal = document.querySelector('[data-testid="media-modal"], [data-testid="mermaid-lightbox-viewport"]');
            if (modal && !modalOpen) {{
                modalOpen = true;
                const rootStyle = window.getComputedStyle(document.documentElement);
                const isDark = document.documentElement.classList.contains('dark');
                const theme = getTheme(getActiveThemeId());
                savedSidebarColor = theme.titlebarColor || rootStyle.getPropertyValue('--sidebar').trim() || (isDark ? '#18181B' : '#E9F0FE');

                window.electronNative?.setTitleBarOverlay?.({{
                    color: 'rgba(0, 0, 0, 0)',
                    symbolColor: 'rgba(0, 0, 0, 0)'
                }});
            }} else if (!modal && modalOpen) {{
                modalOpen = false;
                const theme = getTheme(getActiveThemeId());
                const isDark = document.documentElement.classList.contains('dark');
                const themeSidebar = theme.titlebarColor || savedSidebarColor || (isDark ? '#18181B' : '#E9F0FE');
                const symbolColor = theme.symbolColor || (isDark ? '#FFFFFF' : '#1B2A4A');

                window.electronNative?.setTitleBarOverlay?.({{
                    color: themeSidebar,
                    symbolColor: symbolColor,
                    height: 30
                }});
            }}
        }} catch (e) {{
            console.error('TitleBarOverlay update error:', e);
        }}
    }};

    // 立即初始化当前主题
    applyTheme(getActiveThemeId());

    // 立即尝试挂载与标题栏初始化
    mountThemeSelector();
    updateOverlay();

    // 动态监听 DOM 变化：挂载选择器与模态框状态
    const observer = new MutationObserver(() => {{
        mountThemeSelector();
        updateOverlay();
    }});
    observer.observe(document.body, {{ childList: true, subtree: true }});
}})();
'''

    # 写入 current.js
    current_js_path = os.path.join(BASE_DIR, "current.js")
    with open(current_js_path, "w", encoding="utf-8") as f:
        f.write(template)
    print(f"✅ Generated {current_js_path}")

    # current.css 置空（由 current.js 统一管理动态注入，彻底杜绝双样式表覆盖冲突）
    current_css_path = os.path.join(BASE_DIR, "current.css")
    with open(current_css_path, "w", encoding="utf-8") as f:
        f.write("/* current.css is dynamically managed by current.js. Keep empty to prevent cascade conflicts. */\n")
    print(f"✅ Cleaned {current_css_path}")

if __name__ == "__main__":
    main()
