const translations = {
    en: {
        "nav-features": "Features",
        "hero-title": "Stop Switching,",
        "hero-title-gradient": "Start Routing.",
        "hero-desc": "The intelligent link dispatcher for macOS. Automatically open links in the right browser or profile based on powerful, custom rules.",
        "hero-cta": "Try Now",
        "hero-tag": "Beta · macOS 12+ · Local",
        "use-kicker": "Built for messy everyday browsing",
        "use-title": "One Mac, many browser",
        "use-title-gradient": "contexts.",
        "use1-label": "Work links",
        "use1-title": "Keep team tools in your work profile",
        "use1-desc": "Open Slack, email, docs, and dashboards in the browser profile where your work accounts are already signed in.",
        "use2-label": "Personal browsing",
        "use2-title": "Separate private links from work sessions",
        "use2-desc": "Send personal sites to Safari or another browser while keeping work cookies, history, and accounts isolated.",
        "use3-label": "Testing and OAuth",
        "use3-title": "Pick the right account before a link opens",
        "use3-desc": "Use the chooser shortcut for client accounts, test tenants, login flows, and links that need a deliberate destination.",
        "feature-title": "Everything you need to",
        "feature-title-gradient": "master your browsers.",
        "feat1-title": "Smart Rule Engine",
        "feat1-desc": "Route links based on domains, paths, or even the source application. Work links to Chrome, personal to Safari.",
        "feat2-title": "Instant Switcher",
        "feat2-desc": "Hold a modifier key to pop up a beautiful browser picker. Swift, fluid, and always where your mouse is.",
        "feat3-title": "Privacy First",
        "feat3-desc": "100% open source. No tracking, no data collection. Your browsing habits stay on your machine.",
        "feat4-title": "Browser Profiles",
        "feat4-desc": "Full support for Chrome, Firefox, and Edge profiles. Open work accounts and personal accounts seamlessly.",
        "cta-title": "Try BrowserRouter Beta",
        "cta-desc": "BrowserRouter is currently in beta. You can install it directly from the source using our installation script.",
        "cta-btn": "Copy and run in Terminal",
        "cta-copied": "Open Terminal and run it",
        "install1-title": "Source install",
        "install1-desc": "Requires local Swift build tools and installs the app into /Applications.",
        "install2-title": "Local configuration",
        "install2-desc": "Rules and browser preferences stay in Application Support on your Mac.",
        "install3-title": "No telemetry",
        "install3-desc": "BrowserRouter does not upload URLs or collect browsing history.",
        "footer-text": "&copy; " + new Date().getFullYear() + " BrowserRouter. Crafted with ❤️ for macOS.",
        "nav-home": "Home",
        "nav-changelog": "Changelog",
        "releases-title": "Releases",
        "changelog-hero-title": "Release Notes",
        "changelog-hero-desc": "The journey of BrowserRouter — from the first commit to the latest features.",
        "badge-latest": "Latest",
        "v120-title": "Experience & Precision",
        "v120-f1": "<b>Source App Routing:</b> Route links based on the application that triggered them.",
        "v120-f2": "<b>Browser Management:</b> Reorder or hide browser profiles in the chooser.",
        "v120-f3": "<b>Auto-Restore:</b> Automatically switch back to your system browser on quit.",
        "v120-f4": "<b>UI Polish:</b> Refined onboarding flow and settings layout.",
        "v110-title": "Architecture & Stability",
        "v110-f1": "Modularized code structure for better long-term maintainability.",
        "v110-f2": "Migrated testing suite to XCTest for robust quality assurance.",
        "v110-f3": "Improved shortcut detection reliability across different keyboard layouts.",
        "v100-title": "The Beginning",
        "v100-f1": "Initial release of the native macOS link router.",
        "v100-f2": "Core browser and profile discovery for Chrome, Firefox, Edge, and more.",
        "v100-f3": "Keyboard-triggered chooser for manual link routing."
    },
    cn: {
        "nav-features": "功能",
        "hero-title": "告别繁琐切换，<br>",
        "hero-title-gradient": "开启智能路由。",
        "hero-desc": "macOS 上的智能链接分发中心。基于强大的自定义规则，自动在正确的浏览器或配置文件夹中打开链接。",
        "hero-cta": "立即尝试",
        "hero-tag": "Beta · macOS 12+ · 本地运行",
        "use-kicker": "为日常混乱的浏览场景而生",
        "use-title": "一台 Mac，多个浏览器",
        "use-title-gradient": "上下文。",
        "use1-label": "工作链接",
        "use1-title": "工作链接，告别重复登录",
        "use1-desc": "让 Lark、邮件等链接，精准跳入已经登录了的浏览器中，彻底告别“复制链接再去浏览器粘帖”的繁琐。",
        "use2-label": "个人浏览",
        "use2-title": "把私人链接和工作会话分开",
        "use2-desc": "个人网站可以进入 Safari 或其他浏览器，避免和工作 Cookie、历史记录、账号混在一起。",
        "use3-label": "测试与 OAuth",
        "use3-title": "链接打开前，先选对账号环境",
        "use3-desc": "遇到客户账号、测试租户、登录流程或不确定目的地的链接时，用快捷键呼出选择器。",
        "feature-title": "化繁为简，",
        "feature-title-gradient": "掌控浏览器。",
        "feat1-title": "智能规则引擎",
        "feat1-desc": "根据域名、路径甚至来源 App 分发链接。工作链接用 Chrome，个人链接用 Safari。",
        "feat2-title": "极速选择器",
        "feat2-desc": "按住快捷键即可呼出精美的浏览器选择器。流畅、敏捷，并且始终跟随鼠标。",
        "feat3-title": "隐私优先",
        "feat3-desc": "100% 开源。无跟踪，无数据收集。您的浏览习惯永远保存在本地。",
        "feat4-title": "浏览器配置文件",
        "feat4-desc": "全面支持 Chrome、Firefox 和 Edge 的配置文件。无缝切换工作与个人账号。",
        "cta-title": "体验 BrowserRouter Beta 版",
        "cta-desc": "BrowserRouter 目前处于 Beta 测试阶段。您可以通过克隆源代码并使用内置脚本直接安装。",
        "cta-btn": "复制并去终端运行",
        "cta-copied": "请打开终端应用运行",
        "install1-title": "源码安装",
        "install1-desc": "需要本地 Swift 构建工具，并会把应用安装到 /Applications。",
        "install2-title": "本地配置",
        "install2-desc": "规则和浏览器偏好会保存在这台 Mac 的 Application Support 中。",
        "install3-title": "无遥测",
        "install3-desc": "BrowserRouter 不上传 URL，也不收集浏览历史。",
        "footer-text": "&copy; " + new Date().getFullYear() + " BrowserRouter. 为 macOS 用心打造 ❤️",
        "nav-home": "首页",
        "nav-changelog": "更新日志",
        "releases-title": "所有版本",
        "changelog-hero-title": "更新日志",
        "changelog-hero-desc": "BrowserRouter 的进化之路 — 从第一次 Commit 到最新的核心特性。",
        "badge-latest": "最新",
        "v120-title": "体验与精细化管理",
        "v120-f1": "<b>来源 App 路由:</b> 根据发起链接的应用进行分发（如 Slack 链接走 Chrome）。",
        "v120-f2": "<b>浏览器管理:</b> 在选择器中隐藏或重新排序不同的浏览器配置文件。",
        "v120-f3": "<b>自动恢复:</b> 退出应用时自动切回之前的系统默认浏览器。",
        "v120-f4": "<b>UI 细节:</b> 全新设计的初次运行引导与设置页布局。",
        "v110-title": "架构与稳定性",
        "v110-f1": "模块化重构代码，为后续功能迭代打下坚实基础。",
        "v110-f2": "全面迁移至 XCTest 测试框架，核心逻辑 100% 覆盖。",
        "v110-f3": "优化了快捷键监听机制，在不同键盘布局下更加稳定。",
        "v100-title": "项目启动",
        "v100-f1": "BrowserRouter 首个原生 macOS 版本发布。",
        "v100-f2": "核心浏览器嗅探功能，支持 Chrome, Firefox, Edge 等多 Profile 识别。",
        "v100-f3": "支持通过快捷键呼出原生菜单选择器。"
    }
};

document.addEventListener('DOMContentLoaded', () => {
    // --- Smooth Scroll ---
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            document.querySelector(this.getAttribute('href')).scrollIntoView({
                behavior: 'smooth'
            });
        });
    });

    // --- Reveal Elements on Scroll ---
    const observerOptions = {
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);

    document.querySelectorAll('.feature-card').forEach(card => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = 'all 0.6s ease-out';
        observer.observe(card);
    });

    // --- Theme Toggle Logic ---
    const themeToggleBtn = document.getElementById('theme-toggle');
    const moonIcon = document.getElementById('moon-icon');
    const sunIcon = document.getElementById('sun-icon');

    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)');

    // Determine initial theme: now handled by blocking script in head
    // but we need to update icons and currentTheme variable here
    let currentTheme = document.documentElement.getAttribute('data-theme') || 'light';

    const updateTheme = (theme, saveToStorage = true) => {
        document.documentElement.setAttribute('data-theme', theme);
        if (theme === 'light') {
            moonIcon.style.display = 'block';
            sunIcon.style.display = 'none';
        } else {
            moonIcon.style.display = 'none';
            sunIcon.style.display = 'block';
        }
        if (saveToStorage) {
            localStorage.setItem('theme', theme);
        }
    };

    // Initialize icon states
    updateTheme(currentTheme, false);

    themeToggleBtn.addEventListener('click', () => {
        currentTheme = currentTheme === 'dark' ? 'light' : 'dark';
        updateTheme(currentTheme, true);
    });

    // Listen for system theme changes and apply them immediately
    systemPrefersDark.addEventListener('change', (e) => {
        currentTheme = e.matches ? 'dark' : 'light';
        updateTheme(currentTheme, false);
        localStorage.removeItem('theme'); // Reset manual override on OS change
    });

    // --- Copy Code Logic ---
    const copyBtn = document.getElementById('copy-install-cmd');
    const installCmd = document.getElementById('install-cmd');
    const showCopiedState = (button = copyBtn) => {
        const originalHTML = button.innerHTML;
        button.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        button.classList.add('copied');
        setTimeout(() => {
            button.innerHTML = originalHTML;
            button.classList.remove('copied');
        }, 2000);
    };

    const showTextState = (button, text, restoreKey) => {
        button.textContent = text;
        button.classList.add('copied');
        setTimeout(() => {
            button.textContent = translations[currentLang][restoreKey];
            button.classList.remove('copied');
        }, 2000);
    };

    const selectInstallCommand = () => {
        const range = document.createRange();
        range.selectNodeContents(installCmd);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
    };

    const copyText = async (text) => {
        if (navigator.clipboard && window.isSecureContext) {
            try {
                await navigator.clipboard.writeText(text);
                return;
            } catch {
                // Fall back to the selection-based copy path below.
            }
        }

        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'fixed';
        textarea.style.top = '-9999px';
        document.body.appendChild(textarea);
        textarea.select();
        const copied = document.execCommand('copy');
        document.body.removeChild(textarea);
        if (!copied) {
            throw new Error('Copy command failed');
        }
    };

    if (copyBtn && installCmd) {
        copyBtn.addEventListener('click', async () => {
            try {
                await copyText(installCmd.innerText);
                showCopiedState();
            } catch {
                copyBtn.title = 'Copy failed. Select the command manually.';
            }
        });
    }

    const copyTerminalBtn = document.getElementById('copy-terminal-btn');
    if (copyTerminalBtn && installCmd) {
        copyTerminalBtn.addEventListener('click', async () => {
            try {
                await copyText(installCmd.innerText);
                showTextState(copyTerminalBtn, translations[currentLang]["cta-copied"], "cta-btn");
            } catch {
                selectInstallCommand();
                showTextState(copyTerminalBtn, translations[currentLang]["cta-copied"], "cta-btn");
                copyTerminalBtn.title = 'Copy failed. Select the command manually.';
            }
        });
    }

    // --- Language Toggle Logic ---
    const langToggleBtn = document.getElementById('lang-toggle');

    // Detect system/browser language (starts with 'zh' for any Chinese variant, else English)
    const browserLang = navigator.language || navigator.userLanguage;
    const defaultLang = browserLang.toLowerCase().startsWith('zh') ? 'cn' : 'en';

    let currentLang = localStorage.getItem('lang') || defaultLang;

    const updateLanguage = (lang) => {
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            if (translations[lang][key]) {
                el.innerHTML = translations[lang][key];
            }
        });

        langToggleBtn.textContent = lang === 'en' ? '中' : 'EN';
        document.documentElement.lang = lang === 'cn' ? 'zh-CN' : 'en';
        localStorage.setItem('lang', lang);
    };

    // Initialize language
    updateLanguage(currentLang);

    langToggleBtn.addEventListener('click', () => {
        currentLang = currentLang === 'en' ? 'cn' : 'en';
        updateLanguage(currentLang);
    });
});
