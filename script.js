/* BrowserRouter site behaviour. Shared by index.html and changelog.html. */

(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch { /* unavailable */ } },
  };

  /* ---------------- Language ---------------- */

  const browserLang = (navigator.language || '').toLowerCase().startsWith('zh') ? 'cn' : 'en';
  let lang = store.get('lang') === 'cn' || store.get('lang') === 'en' ? store.get('lang') : browserLang;
  const tr = (key) => (translations[lang] && translations[lang][key]) || translations.en[key] || '';
  const langListeners = [];

  function applyLang(next) {
    lang = next;
    store.set('lang', next);
    document.documentElement.lang = next === 'cn' ? 'zh-CN' : 'en';
    $$('[data-i18n]').forEach((el) => {
      const value = tr(el.dataset.i18n);
      if (value) el.innerHTML = value;
    });
    $$('[data-i18n-placeholder]').forEach((el) => { el.placeholder = tr(el.dataset.i18nPlaceholder); });
    const btn = $('#lang-toggle');
    if (btn) {
      btn.textContent = next === 'en' ? '中' : 'EN';
      btn.setAttribute('aria-label', next === 'en' ? '切换到中文' : 'Switch to English');
    }
    langListeners.forEach((fn) => fn());
  }

  $('#lang-toggle')?.addEventListener('click', () => applyLang(lang === 'en' ? 'cn' : 'en'));

  /* ---------------- Theme ---------------- */

  const darkQuery = window.matchMedia('(prefers-color-scheme: dark)');
  const currentTheme = () => document.documentElement.getAttribute('data-theme') || (darkQuery.matches ? 'dark' : 'light');
  $('#theme-toggle')?.addEventListener('click', () => {
    const next = currentTheme() === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    store.set('theme', next);
  });

  /* ---------------- Routing board ---------------- */

  const board = $('.board');
  if (board) initBoard();

  function initBoard() {
    const ROUTES = {
      work: { browser: 'Chrome', sub: 'st-work', color: 'c-red', args: 'open -na "Google Chrome" --args --profile-directory="Profile 1"' },
      personal: { browser: 'Safari', sub: 'st-personal', color: 'c-blue', args: 'NSWorkspace → com.apple.Safari' },
      testing: { browser: 'Firefox', sub: 'st-testing', color: 'c-green', args: 'open -na Firefox --args -P "Testing"' },
      client: { browser: 'Edge', sub: 'st-client', color: 'c-yellow', args: 'open -na "Microsoft Edge" --args --profile-directory="Profile 3"' },
    };

    // First match wins, like the app's rule list.
    const RULES = [
      { kind: 'rule-host-suffix', value: 'figma.com', route: 'work', test: (u) => u.host === 'figma.com' || u.host.endsWith('.figma.com') },
      { kind: 'rule-source', value: 'Slack', route: 'work', test: (u, app) => app === 'Slack' },
      { kind: 'rule-host-contains', value: 'localhost', route: 'testing', test: (u) => u.host.includes('localhost') },
      { kind: 'rule-path', value: '/o/oauth2', route: 'client', test: (u) => u.path.startsWith('/o/oauth2') },
      { kind: 'rule-url', value: 'youtube', route: 'personal', test: (u) => u.href.includes('youtube') },
    ];
    const ruleItems = $$('.rule-list li');

    const train = $('#train');
    const chooser = $('#chooser');
    const status = $('#chooser-status');
    const always = $('#always-chooser');
    const out = {
      url: $('#res-url'),
      rule: $('#res-rule'),
      dest: $('#res-dest'),
      args: $('#res-args'),
    };
    let animation = null;
    let last = null;
    let pending = null;

    function parse(raw) {
      let text = raw.trim();
      if (!text) return null;
      if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(text)) text = `https://${text}`;
      try {
        const u = new URL(text);
        return { href: u.href, host: u.hostname.toLowerCase(), path: u.pathname };
      } catch {
        return null;
      }
    }

    function match(u, app) {
      const index = RULES.findIndex((r) => r.test(u, app));
      return index === -1 ? { index: RULES.length, route: 'personal', rule: null } : { index, route: RULES[index].route, rule: RULES[index] };
    }

    function ruleLabel(result) {
      if (result.chosen) return tr('res-chosen');
      if (!result.rule) return `${tr('rule-default')} · Safari`;
      return `${tr(result.rule.kind)} · ${result.rule.value}`;
    }

    function renderResult(result) {
      if (!result) {
        out.url.textContent = '—';
        out.rule.textContent = tr('res-empty');
        out.dest.textContent = '—';
        out.args.textContent = '—';
        return;
      }
      const route = ROUTES[result.route];
      out.url.textContent = result.url.href;
      out.rule.textContent = ruleLabel(result);
      out.dest.innerHTML = '';
      const dot = document.createElement('i');
      dot.className = route.color;
      const label = document.createElement('span');
      label.textContent = `${route.browser} · ${tr(route.sub)}`;
      out.dest.append(dot, label);
      out.args.textContent = route.args;
      ruleItems.forEach((li, i) => li.classList.toggle('is-hit', !result.chosen && i === result.index));
    }

    function route(result) {
      last = result;
      cancelAnimationFrame(animation);
      const path = $(`#r-${result.route}`);
      $$('.rail').forEach((r) => r.classList.toggle('is-on', r === path));
      path.parentNode.appendChild(path);
      $$('.station').forEach((s) => {
        s.classList.toggle('is-on', s.dataset.route === result.route);
        s.classList.remove('is-arrived');
      });
      board.classList.add('is-routing');
      train.style.stroke = getComputedStyle(path).stroke;
      renderResult(result);
      $('.board-result').classList.remove('flash');
      void $('.board-result').offsetWidth;
      $('.board-result').classList.add('flash');

      const length = path.getTotalLength();
      const duration = reduceMotion ? 1 : 900;
      const start = performance.now();
      const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
      const step = (now) => {
        const t = Math.min(1, (now - start) / duration);
        const p = path.getPointAtLength(length * ease(t));
        train.setAttribute('cx', p.x);
        train.setAttribute('cy', p.y);
        if (t < 1) {
          animation = requestAnimationFrame(step);
        } else {
          $(`.station[data-route="${result.route}"]`).classList.add('is-arrived');
        }
      };
      animation = requestAnimationFrame(step);
    }

    // Chooser: hold ⌘⇧ (or ⌥⇧, ⌃⇧) while opening, or tick "always show".
    const modifiers = { meta: false, alt: false, ctrl: false, shift: false };
    const armed = () => always.checked || (modifiers.shift && (modifiers.meta || modifiers.alt || modifiers.ctrl));
    function refreshStatus() {
      status.classList.toggle('is-armed', armed());
      const hint = $('span', status);
      if (hint) hint.textContent = armed() ? tr('board-chooser-armed') : tr('board-chooser-hint');
    }
    function syncModifiers(e) {
      modifiers.meta = !!e.metaKey;
      modifiers.alt = !!e.altKey;
      modifiers.ctrl = !!e.ctrlKey;
      modifiers.shift = !!e.shiftKey;
      refreshStatus();
    }
    window.addEventListener('keydown', syncModifiers);
    window.addEventListener('keyup', syncModifiers);
    window.addEventListener('blur', () => syncModifiers({}));
    always.addEventListener('change', refreshStatus);

    function openChooser(url, x, y) {
      pending = url;
      $('#chooser-url').textContent = url.href;
      chooser.hidden = false;
      const rect = board.getBoundingClientRect();
      const w = chooser.offsetWidth;
      const h = chooser.offsetHeight;
      const left = Math.max(8, Math.min(x - rect.left, rect.width - w - 8));
      const top = Math.max(8, Math.min(y - rect.top, rect.height - h - 8));
      chooser.style.left = `${left}px`;
      chooser.style.top = `${top}px`;
      $('button', chooser).focus({ preventScroll: true });
    }
    function closeChooser() {
      chooser.hidden = true;
      pending = null;
    }
    $$('button', chooser).forEach((btn) => {
      btn.addEventListener('click', () => {
        const url = pending;
        closeChooser();
        if (url) route({ url, route: btn.dataset.route, chosen: true });
      });
    });
    document.addEventListener('pointerdown', (e) => {
      if (!chooser.hidden && !chooser.contains(e.target)) closeChooser();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !chooser.hidden) closeChooser();
    });

    function open(raw, app, point) {
      const url = parse(raw);
      if (!url) {
        const input = $('#url-input');
        input.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'translateX(0)' }], { duration: 240 });
        return;
      }
      if (armed()) {
        openChooser(url, point.x, point.y);
        return;
      }
      const m = match(url, app);
      route({ url, route: m.route, rule: m.rule, index: m.index, chosen: false });
    }

    $$('.chip').forEach((chip) => {
      chip.addEventListener('click', (e) => {
        syncModifiers(e);
        $$('.chip').forEach((c) => c.classList.toggle('is-active', c === chip));
        const point = e.clientX || e.clientY ? { x: e.clientX, y: e.clientY } : centerOf(chip);
        open(chip.dataset.url, chip.dataset.app, point);
      });
    });

    $('#url-form').addEventListener('submit', (e) => {
      e.preventDefault();
      $$('.chip').forEach((c) => c.classList.remove('is-active'));
      const btn = $('button[type="submit"]', e.currentTarget);
      open($('#url-input').value, 'Browser', centerOf(btn));
    });

    function centerOf(el) {
      const r = el.getBoundingClientRect();
      return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
    }

    langListeners.push(() => {
      renderResult(last);
      refreshStatus();
    });

    // Play the first link once the board scrolls into view.
    const firstChip = $('.chip');
    const autoplay = new IntersectionObserver((entries) => {
      if (!entries[0].isIntersecting) return;
      autoplay.disconnect();
      if (!last) setTimeout(() => { if (!last) firstChip.click(); }, 400);
    }, { threshold: 0.5 });
    autoplay.observe(board);
    renderResult(null);
  }

  /* ---------------- Transit lines end at their last stop ---------------- */

  function fitLine(list, itemSelector) {
    const items = $$(itemSelector, list);
    if (!items.length) return;
    const last = items[items.length - 1];
    const dotTop = parseFloat(getComputedStyle(list).getPropertyValue('--dot-top')) || 0;
    const dot = parseFloat(getComputedStyle(list).getPropertyValue('--dot')) || 0;
    const lastCenter = last.offsetTop + dotTop + dot / 2;
    list.style.setProperty('--end', `${Math.max(0, list.clientHeight - lastCenter)}px`);
  }
  const fitAll = () => {
    $$('.stops').forEach((l) => fitLine(l, '.stop'));
    $$('.cl-line').forEach((l) => fitLine(l, '.cl-item'));
  };
  window.addEventListener('resize', fitAll);
  langListeners.push(fitAll);
  if (document.fonts) document.fonts.ready.then(fitAll);

  /* ---------------- Feature line fill ---------------- */

  const stops = $('#stops');
  if (stops) {
    const items = $$('.stop', stops);
    const update = () => {
      const r = stops.getBoundingClientRect();
      const mid = window.innerHeight * 0.6;
      const fill = Math.max(0, Math.min(1, (mid - r.top) / r.height));
      stops.style.setProperty('--fill', fill.toFixed(3));
      items.forEach((it) => it.classList.toggle('is-passed', it.getBoundingClientRect().top + 16 < mid));
    };
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    update();
  }

  /* ---------------- Copy install command ---------------- */

  const copyBtn = $('#copy-terminal-btn');
  if (copyBtn) {
    copyBtn.addEventListener('click', async () => {
      const text = $('#install-cmd').innerText;
      try {
        if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(text);
        else {
          const ta = document.createElement('textarea');
          ta.value = text;
          ta.style.position = 'fixed';
          ta.style.opacity = '0';
          document.body.append(ta);
          ta.select();
          document.execCommand('copy');
          ta.remove();
        }
        copyBtn.classList.add('is-done');
        copyBtn.textContent = tr('cta-copied');
      } catch {
        copyBtn.textContent = tr('cta-btn');
      }
      setTimeout(() => {
        copyBtn.classList.remove('is-done');
        copyBtn.textContent = tr('cta-btn');
      }, 2200);
    });
  }

  /* ---------------- Latest release ---------------- */

  if ($('[data-release-link]')) {
    fetch('https://api.github.com/repos/KhalilHsu/browserSwitch/releases/latest', { headers: { Accept: 'application/vnd.github+json' } })
      .then((res) => (res.ok ? res.json() : null))
      .then((release) => {
        const dmg = release && (release.assets || []).find((a) => /\.dmg$/i.test(a.name));
        if (!dmg) return;
        const version = release.tag_name.startsWith('v') ? release.tag_name : `v${release.tag_name}`;
        $$('[data-release-link]').forEach((a) => { a.href = dmg.browser_download_url; });
        $$('[data-release-version]').forEach((el) => { el.textContent = version; });
        $$('[data-release-size]').forEach((el) => { el.textContent = `${(dmg.size / 1048576).toFixed(1)} MB`; });
      })
      .catch(() => { /* keep static links */ });
  }

  /* ---------------- Changelog side nav ---------------- */

  const sideLinks = $$('.cl-side a');
  if (sideLinks.length) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        sideLinks.forEach((a) => a.classList.toggle('is-current', a.getAttribute('href') === `#${entry.target.id}`));
      });
    }, { rootMargin: '-40% 0px -55% 0px' });
    $$('.cl-item').forEach((item) => io.observe(item));
  }

  /* ---------------- Reveal ---------------- */

  if (!reduceMotion && 'IntersectionObserver' in window) {
    const targets = $$('.line-card, .stop, .terminus, .cl-item, .section > .h2, .section > .kicker');
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px' });
    targets.forEach((el, i) => {
      el.classList.add('reveal');
      if (el.classList.contains('line-card')) el.style.transitionDelay = `${(i % 3) * 90}ms`;
      io.observe(el);
    });
  }

  applyLang(lang);
})();
