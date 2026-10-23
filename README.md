# Antigravity Custom Themes (自定义主题套件)

适用于 [Google Antigravity](https://antigravity.google/) 的现代化浅色高颜值定制主题套件，针对最新版 Antigravity 深度优化，告别刺眼白框、消除冗余滚动条，带来丝滑优雅的视觉体验。

---

## ✨ 特性亮点 (Highlights)

- 🌟 **Gemini Four-Color Light（Gemini 四色浅色流光主题）**
  - 融合 Gemini 标志性四色与微光渐变，低饱和度护眼设计。
  - 细节精雕：顶栏、侧边栏、对话气泡、代码块、卡片完美融入，彻底消除白框与背景色差。
- 🌊 **Sky Light（天青浅色主题）**
  - 宁静清澈的天青色系，纯净现代的极简开发体验。
- 🌈 **交互式流光胶囊滚动条（Next-Gen Overlay Scrollbars）**
  - **日常状态**：`5px` 极简半透明冰川蓝圆角胶囊（`rgba(95, 138, 230, 0.42)`），安静不打扰视野。
  - **悬停 / 拖拽状态**：优雅延展至 `6px`，并渐变为 **Gemini 经典蓝 → 星云紫 → 珊瑚粉三色流光渐变**（`linear-gradient(180deg, #4285f4, #9b72cb, #d96570)`），带来灵动细腻的操作反馈。
  - **原生 React Portal 接管**：直接深度接管 Antigravity 原生虚拟滚动条组件，彻底告别原版粗灰条，并从底层消灭原生滚动条与虚拟滚动条并存的“双滚动条”BUG。
- ⚡ **秒级热重载**：保存 CSS 文件后在 Antigravity 内按 `Ctrl + R` 即可实时生效，免重启。

---

## 📁 文件说明 (Directory Structure)

```text
├── gemini-light.css   # Gemini 四色流光浅色主题源文件（含悬停彩条滚动条）
├── sky-light.css      # 天青浅色主题源文件
├── current.css        # Antigravity 当前实际加载生效的主题文件
├── current.js         # 主题辅助注入脚本
├── stock.css          # 原版备用空样式表
├── 指南.md            # 完整架构、选择器索引与深度维护指南
├── README.md          # 项目说明文档
└── .gitignore         # Git 忽略配置
```

---

## 🚀 安装与使用 (Quick Start)

### 1. 找到主题运行目录
Antigravity 在 Windows 下的主题存放路径为：
```text
%LOCALAPPDATA%\Programs\Antigravity\resources\custom-theme\
```
*(完整路径示例：`C:\Users\<你的用户名>\AppData\Local\Programs\Antigravity\resources\custom-theme\`)*

### 2. 启用主题
将你喜欢的主题文件内容复制覆盖到 `current.css` 即可：

- **若使用 Gemini 四色浅色款**：
  将 `gemini-light.css` 复制并重命名替换为 `current.css`。
- **若使用 天青浅色款**：
  将 `sky-light.css` 复制并重命名替换为 `current.css`。

### 3. 即刻生效
回到 Antigravity 窗口，按下快捷键：
```text
Ctrl + R
```
界面将秒级完成热刷新并渲染全新主题！

---

## 📖 进阶与维护

详细的组件架构、各模块覆盖选择器以及防踩坑说明请参阅：[指南.md](指南.md)。
