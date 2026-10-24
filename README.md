# Antigravity Custom Themes (自定义主题套件)

适用于 [Google Antigravity](https://antigravity.google/) 的现代化浅色高颜值定制主题套件，针对最新版 Antigravity 深度优化，告别刺眼白框、消除冗余滚动条，带来丝滑优雅的视觉体验。

---

## ✨ 特性亮点 (Highlights)

- 🌈 **四色极光（Gemini Four-Color Light）**
  - 融合 Gemini 标志性四色与微光渐变，低饱和度护眼设计，原生标题栏无缝零色差融合。
- ☀️ **蔚蓝晴空（Sky Light）**
  - 宁静清澈的天青色系，纯净现代的极简开发体验。
- 🍃 **碧水青波（Cyan Light）**
  - 清新薄荷水波与碧青色调，温润透亮，护眼舒适。
- 🌅 **落霞暖橙（Orange Light）**
  - 温暖落日晚霞与暖阳橙色调，带来温润柔和的心流沉浸感。
- 🌺 **丹霞绯红（Red Light）**
  - 优雅海棠山茶柔粉绯红，高雅明亮，绝不刺眼。
- 🎛️ **免刷新即时换肤引擎（Built-in Theme Switcher）**
  - 右上角内置精致毛玻璃动态等宽下拉菜单，全量统一为工整的 4 字名称体系，点击任意主题毫秒级免刷新无缝换肤；主题选择经 app 原生持久化存储记忆，重启后自动恢复上次主题。
- 🌈 **交互式流光胶囊滚动条（Next-Gen Overlay Scrollbars）**
  - **日常状态**：`5px` 极简半透明圆角胶囊，安静不打扰视野。
  - **悬停 / 拖拽状态**：优雅延展至 `6px`，并渐变为主色流光，带来灵动细腻的操作反馈。
  - **原生 React Portal 接管**：直接深度接管 Antigravity 原生虚拟滚动条组件，彻底告别原版粗灰条，并从底层消灭原生滚动条与虚拟滚动条并存的“双滚动条”BUG。

---

## 📁 文件说明 (Directory Structure)

```text
├── gemini-light.css   # 四色极光浅色主题源文件（含悬停彩条滚动条）
├── sky-light.css      # 蔚蓝晴空浅色主题源文件（结构母版）
├── cyan-light.css     # 碧水青波浅色主题源文件
├── orange-light.css   # 落霞暖橙浅色主题源文件
├── red-light.css      # 丹霞绯红浅色主题源文件
├── current.css        # 看图双胶囊通用结构 + 官方原版浅灰胶囊配色兜底（不带 !important）
├── current.js         # 主题辅助注入脚本（含下拉换肤选择器、标题栏配色与看图模态系统按钮区同色贴合）
├── build_themes.py    # 主题打包编译与自动多端分发脚本
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
主题样式由 `current.js` 动态注入（含看图模态的顶部/底部胶囊皮肤，来自各主题 CSS 第 16 节），`current.css` 只承载看图双胶囊的通用结构与「官方原版」浅灰胶囊配色兜底（不带 `!important`，主题变量永远优先）。**请勿用主题文件覆盖 `current.css`**。

日常换肤直接用界面右上角的下拉菜单即可，无需改动任何文件。

如需直接以指定主题作为默认主题，修改 `current.js` 顶部注册表中 `getActiveThemeId()` 的默认返回值即可：

- **四色极光**：`return localStorage.getItem('antigravity_selected_theme') || 'gemini';`
- **蔚蓝晴空**：把上面的 `'gemini'` 改为 `'sky'`（其余主题同理：`cyan` / `orange` / `red` / `stock`）。

> ⚠️ 不要用主题文件覆盖 `current.css`：胶囊兜底配色依赖「不带 `!important`、主题变量永远优先」的层级设计，混入主题级规则会破坏该层级（官方原版浅色下看图双胶囊为浅灰毛玻璃、看图模态为浅灰实底，深色为半透浅色胶囊 + 近黑实底模态）。

### 3. 即刻生效
回到 Antigravity 窗口，按下快捷键：
```text
Ctrl + R
```
界面将秒级完成热刷新并渲染全新主题！

---

## 📖 进阶与维护

详细的组件架构、各模块覆盖选择器以及防踩坑说明请参阅：[指南.md](指南.md)。
