// Antigravity Custom Theme Companion Script
// Automatically eliminates [-] [口] [X] native titlebar buttons and rectangular color block when viewing images (media-modal) or diagrams (mermaid-lightbox)
(() => {
    if (window.__antigravityThemeCompanionLoaded) return;
    window.__antigravityThemeCompanionLoaded = true;

    let modalOpen = false;
    let savedSidebarColor = null;

    const updateOverlay = () => {
        try {
            const modal = document.querySelector('[data-testid="media-modal"], [data-testid="mermaid-lightbox-viewport"]');
            if (modal && !modalOpen) {
                modalOpen = true;
                const rootStyle = window.getComputedStyle(document.documentElement);
                const isDark = document.documentElement.classList.contains('dark');

                // Save current sidebar color for restoring later
                savedSidebarColor = rootStyle.getPropertyValue('--sidebar').trim() || (isDark ? '#18181B' : '#E9F0FE');

                // Completely eliminate [-] [口] [X] and rectangular color block by setting overlay to 100% transparent.
                // Chromium skips background rendering when alpha is 0, seamlessly revealing the modal backdrop.
                window.electronNative?.setTitleBarOverlay?.({
                    color: 'rgba(0, 0, 0, 0)',
                    symbolColor: 'rgba(0, 0, 0, 0)'
                });
            } else if (!modal && modalOpen) {
                modalOpen = false;
                const rootStyle = window.getComputedStyle(document.documentElement);
                const isDark = document.documentElement.classList.contains('dark');
                const themeSidebar = rootStyle.getPropertyValue('--sidebar').trim() || savedSidebarColor || (isDark ? '#18181B' : '#E9F0FE');
                const symbolColor = isDark ? '#FFFFFF' : '#1B2A4A';

                // Restore normal titlebar overlay when exiting media modal
                window.electronNative?.setTitleBarOverlay?.({
                    color: themeSidebar,
                    symbolColor: symbolColor,
                    height: 30
                });
            }
        } catch (e) {
            console.error('TitleBarOverlay update error:', e);
        }
    };

    // Initial check
    updateOverlay();

    // Observe document for modal mount/unmount
    const observer = new MutationObserver(updateOverlay);
    observer.observe(document.body, { childList: true, subtree: true });
})();
