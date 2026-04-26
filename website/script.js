const translations = {
    en: {
        "nav-features": "Features",
        "hero-title": "Stop Switching,",
        "hero-title-gradient": "Start Routing.",
        "hero-desc": "The intelligent link dispatcher for macOS. Automatically open links in the right browser or profile based on powerful, custom rules.",
        "hero-cta": "Download on GitHub",
        "hero-tag": "Open Source",
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
        "cta-btn": "View on GitHub",
        "footer-text": "&copy; 2026 BrowserRouter. Crafted with ❤️ for macOS."
    },
    cn: {
        "nav-features": "功能",
        "hero-title": "告别繁琐切换，<br>",
        "hero-title-gradient": "开启智能路由。",
        "hero-desc": "macOS 上的智能链接分发中心。基于强大的自定义规则，自动在正确的浏览器或配置文件夹中打开链接。",
        "hero-cta": "在 GitHub 上下载",
        "hero-tag": "开源",
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
        "cta-btn": "在 GitHub 上查看",
        "footer-text": "&copy; 2026 BrowserRouter. 为 macOS 用心打造 ❤️"
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
    
    // Determine initial theme: localStorage first, then system preference
    let currentTheme = localStorage.getItem('theme') || (systemPrefersDark.matches ? 'dark' : 'light');

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

    // Initialize theme without forcing it into localStorage if it was auto-detected
    updateTheme(currentTheme, !!localStorage.getItem('theme'));

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
    if (copyBtn && installCmd) {
        copyBtn.addEventListener('click', () => {
            navigator.clipboard.writeText(installCmd.innerText).then(() => {
                const originalHTML = copyBtn.innerHTML;
                // Show a checkmark icon when copied
                copyBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
                copyBtn.classList.add('copied');
                setTimeout(() => {
                    copyBtn.innerHTML = originalHTML;
                    copyBtn.classList.remove('copied');
                }, 2000);
            });
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
        document.documentElement.lang = lang;
        localStorage.setItem('lang', lang);
    };

    // Initialize language
    updateLanguage(currentLang);

    langToggleBtn.addEventListener('click', () => {
        currentLang = currentLang === 'en' ? 'cn' : 'en';
        updateLanguage(currentLang);
    });
});
