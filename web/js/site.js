// Stashbar website: download links + scroll-zoom macOS desktop hero + interactive 1:1 Stashbar Mac app views.
export const DMG_URL = 'https://github.com/sajidur7/Stashbar/releases/latest/download/Stashbar.dmg';

document.querySelectorAll('[data-download]').forEach(a => { a.href = DMG_URL; });

fetch('https://api.github.com/repos/sajidur7/Stashbar/releases/latest')
  .then(r => (r.ok ? r.json() : null))
  .then(j => {
    if (!j) return;
    const v = (j.tag_name || '').replace(/^v/, '');
    const asset = (j.assets || []).find(a => a.name === 'Stashbar.dmg');
    const size = asset ? ' · ' + (asset.size / 1048576).toFixed(1) + ' MB' : '';
    document.querySelectorAll('[data-version]').forEach(el => {
      el.textContent = 'Version ' + v + size + ' · macOS 13+ · Apple silicon & Intel';
    });
  })
  .catch(() => {});

// ---- 1. Silky GPU-Damped Hero Scroll & Navbar Reveal ----
const heroPin = document.getElementById('heroPin');
const heroStage = document.getElementById('heroStage');
const heroTop = document.getElementById('heroTop');
const macAppStack = document.getElementById('macAppStack');

if (heroPin && heroStage && heroTop) {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const mobileQuery = window.matchMedia('(max-width: 768px)');

  let heroDwell = 0;
  let navHeight = 52;
  let heroStageLeft = 0;
  let heroStageWidth = 0;
  let heroStageHeight = 0;
  let heroStageDocTop = 0;
  let settledStackW = 0;
  let heroPinned = false;

  let targetP = 0;
  let smoothP = 0;
  let heroRaf = 0;
  let heroLastTs = 0;

  const heroLerp = (a, b, t) => a + (b - a) * t;
  const heroEase = t => 1 - Math.pow(1 - t, 2.25);

  const heroClearStageOverrides = () => {
    ['position', 'top', 'left', 'width', 'height', 'borderRadius', 'zIndex'].forEach(p => {
      heroStage.style[p] = '';
    });
    if (macAppStack) {
      macAppStack.style.width = '';
      macAppStack.style.transform = '';
    }
  };

  const heroClearAllOverrides = () => {
    cancelAnimationFrame(heroRaf);
    heroRaf = 0;
    heroStage.classList.remove('is-fullscreen-init');
    heroClearStageOverrides();
    heroTop.style.opacity = '';
    heroTop.style.transform = '';
    heroTop.classList.add('is-interactive');
  };

  const renderHeroFrame = p => {
    const scrollY = window.scrollY;
    if (p >= 0.9985 && scrollY >= heroDwell) {
      if (heroPinned) {
        heroClearStageOverrides();
        heroPinned = false;
      }
      heroTop.style.opacity = '1';
      heroTop.style.transform = 'translate3d(0, 0, 0)';
      heroTop.classList.add('is-interactive');
      return;
    }

    const e = heroEase(Math.min(Math.max(p, 0), 1));
    heroPinned = true;
    const vpW = document.documentElement.clientWidth;
    const vpH = window.innerHeight;

    const settledTop = scrollY > heroDwell
      ? (heroStageDocTop - scrollY)
      : (heroStageDocTop - heroDwell);

    const stageTop = heroLerp(0, settledTop, e);
    const w = heroLerp(vpW, heroStageWidth, e);
    const h = heroLerp(vpH, heroStageHeight, e);
    const left = heroLerp(0, heroStageLeft, e);
    const radius = heroLerp(0, 18, e);

    heroStage.style.position = 'fixed';
    heroStage.style.top = stageTop.toFixed(2) + 'px';
    heroStage.style.left = left.toFixed(2) + 'px';
    heroStage.style.width = w.toFixed(2) + 'px';
    heroStage.style.height = h.toFixed(2) + 'px';
    heroStage.style.borderRadius = radius.toFixed(2) + 'px';
    heroStage.style.zIndex = '45';

    if (macAppStack && settledStackW > 0) {
      const stackScale = heroLerp(1.024, 1, e);
      macAppStack.style.width = settledStackW + 'px';
      macAppStack.style.transform = `translate3d(-50%, 0, 0) scale(${stackScale.toFixed(4)})`;
    }

    const navY = heroLerp(-navHeight, 0, e);
    heroTop.style.transform = `translate3d(0, ${navY.toFixed(2)}px, 0)`;
    heroTop.style.opacity = e.toFixed(3);
    heroTop.classList.toggle('is-interactive', e > 0.25);
  };

  const stepHero = now => {
    if (reducedMotion.matches || mobileQuery.matches) {
      heroRaf = 0;
      return;
    }
    const dt = heroLastTs ? Math.min(now - heroLastTs, 64) : 16.67;
    heroLastTs = now;

    targetP = heroDwell > 0 ? Math.min(Math.max(window.scrollY / heroDwell, 0), 1) : 1;
    const alpha = 1 - Math.exp(-dt * 0.013); // softer follow (~0.25s)
    smoothP += (targetP - smoothP) * alpha;

    if (Math.abs(targetP - smoothP) < 0.0008) {
      smoothP = targetP;
    }

    renderHeroFrame(smoothP);

    if (Math.abs(targetP - smoothP) >= 0.0008) {
      heroRaf = requestAnimationFrame(stepHero);
    } else {
      heroRaf = 0;
      heroLastTs = 0;
    }
  };

  // Render in the same frame as the scroll (no second easing layer, no one-frame lag):
  // the pinned desktop moves exactly with the page, so it can't shake. The easing comes
  // from smooth wheel scrolling (and native trackpad momentum).
  const kickHeroLoop = () => {
    if (reducedMotion.matches || mobileQuery.matches) return;
    targetP = heroDwell > 0 ? Math.min(Math.max(window.scrollY / heroDwell, 0), 1) : 1;
    if (heroRaf) { cancelAnimationFrame(heroRaf); heroRaf = 0; }
    smoothP = targetP;
    renderHeroFrame(smoothP);
  };

  const measureHeroRest = () => {
    if (reducedMotion.matches || mobileQuery.matches) {
      heroPin.style.paddingTop = '';
      heroPin.style.height = '';
      heroClearAllOverrides();
      heroPinned = false;
      return;
    }

    cancelAnimationFrame(heroRaf);
    heroRaf = 0;
    heroStage.classList.remove('is-fullscreen-init');
    heroClearStageOverrides();
    heroPin.style.height = '';
    heroPin.style.paddingTop = '';

    navHeight = heroTop.offsetHeight || 52;
    heroDwell = Math.round(window.innerHeight * 0.52);
    const heroPinDocTop = heroPin.getBoundingClientRect().top + window.scrollY;
    heroPin.style.paddingTop = heroDwell + 'px';

    const stageRect = heroStage.getBoundingClientRect();
    heroStageLeft = stageRect.left;
    heroStageWidth = stageRect.width;
    heroStageHeight = stageRect.height;
    heroStageDocTop = stageRect.top + window.scrollY;
    settledStackW = macAppStack ? macAppStack.offsetWidth : 0;

    const settledContentHeight = (heroStageDocTop + heroStageHeight) - (heroPinDocTop + heroDwell);
    heroPin.style.height = (heroDwell + Math.max(settledContentHeight, 0)) + 'px';

    heroPinned = false;
    targetP = heroDwell > 0 ? Math.min(Math.max(window.scrollY / heroDwell, 0), 1) : 1;
    smoothP = targetP;
    renderHeroFrame(smoothP);
  };

  measureHeroRest();
  window.addEventListener('scroll', kickHeroLoop, { passive: true });
  window.addEventListener('resize', measureHeroRest);
}

// ---- 2. Live macOS Menu-Bar Clock ----
const clockEl = document.getElementById('macClock');
if (clockEl) {
  const tickClock = () => {
    const now = new Date();
    const d = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' }).format(now);
    const t = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }).format(now);
    clockEl.textContent = `${d}  ${t}`;
  };
  tickClock();
  setInterval(tickClock, 10000);
}

// ---- 3. Shared Stashbar App Demo State (mirrors Store.swift & LinkCleaner.swift) ----
const demo = document.getElementById('demo');
if (demo) {
  const TRACK = /^(utm_|fbclid|gclid|dclid|mc_|igshid|igsh$|si$|ref_src|smid|_hs|yclid|msclkid|twclid|ttclid|_ga|_gl|spm|mkt_tok)/i;
  const LOGO = {
    'github.com': 'github', 'x.com': 'twitter', 'twitter.com': 'twitter',
    'youtube.com': 'youtube', 'youtu.be': 'youtube', 'developer.apple.com': 'apple',
    'apple.com': 'apple', 'figma.com': 'figma', 'stripe.com': 'credit-card',
    'arxiv.org': 'file-text', 'nytimes.com': 'file-text', 'medium.com': 'book-open',
    'reddit.com': 'message-circle', 'notion.so': 'notebook'
  };
  const siteIcon = domain => {
    if (LOGO[domain]) return `/assets/icons/${LOGO[domain]}.svg`;
    for (const [k, v] of Object.entries(LOGO)) {
      if (domain.endsWith('.' + k)) return `/assets/icons/${v}.svg`;
    }
    return '/assets/icons/globe.svg';
  };
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  const H = 36e5;
  let links = [
    {
      id: '1',
      title: 'Variables & modes: a practical guide',
      domain: 'figma.com',
      url: 'https://figma.com/blog/variables-and-modes',
      tags: ['design', 'tokens'],
      note: 'Great reference for our light/dark token naming.',
      pinned: true,
      archived: false,
      opened: true,
      removed: ['utm_source', 'fbclid', 'mc_eid'],
      createdAt: Date.now() - 2 * H
    },
    {
      id: '2',
      title: 'swift-collections: ordered sets, deques',
      domain: 'github.com',
      url: 'https://github.com/apple/swift-collections',
      tags: ['swift'],
      note: 'OrderedSet and Deque implementations for Swift.',
      pinned: true,
      archived: false,
      opened: true,
      removed: ['utm_source'],
      createdAt: Date.now() - 4 * H
    },
    {
      id: '3',
      title: 'A talk on typographic rhythm in interfaces',
      domain: 'youtube.com',
      url: 'https://youtube.com/watch?v=typographic-rhythm',
      tags: ['design'],
      note: '',
      pinned: true,
      archived: false,
      opened: false,
      removed: ['si', 'utm_medium'],
      createdAt: Date.now() - 20 * H
    },
    {
      id: '4',
      title: 'Human Interface Guidelines: Menu Bar Extras',
      domain: 'developer.apple.com',
      url: 'https://developer.apple.com/design/human-interface-guidelines/menu-bar-extras',
      tags: ['swift', 'macos'],
      note: 'Spacing and icon template sizing guidelines.',
      pinned: false,
      archived: false,
      opened: true,
      removed: [],
      createdAt: Date.now() - 36 * H
    },
    {
      id: '5',
      title: 'How we think about API idempotency',
      domain: 'stripe.com',
      url: 'https://stripe.com/blog/idempotency',
      tags: ['reading'],
      note: 'Retry safety keys.',
      pinned: false,
      archived: false,
      opened: false,
      removed: ['utm_campaign'],
      createdAt: Date.now() - 52 * H
    },
    {
      id: '6',
      title: 'Menu-bar apps are having a quiet renaissance',
      domain: 'nytimes.com',
      url: 'https://nytimes.com/2026/10/30/technology/menu-bar-apps.html',
      tags: ['reading'],
      note: '',
      pinned: false,
      archived: false,
      opened: true,
      removed: ['utm_source', 'smid'],
      createdAt: Date.now() - 78 * H
    }
  ];

  // Parse URL like LinkCleaner.swift
  const parseURL = raw => {
    let s = (raw || '').trim();
    if (!s || /\s/.test(s)) return null;
    if (!/^https?:\/\//i.test(s)) {
      if (/^[\w-]+(\.[\w-]+)+(\/|$|\?)/.test(s)) s = 'https://' + s;
      else return null;
    }
    let u;
    try { u = new URL(s); } catch { return null; }
    if (!/\.[a-z]{2,}$/i.test(u.hostname)) return null;
    const removed = [];
    [...u.searchParams.keys()].forEach(k => {
      if (TRACK.test(k)) { u.searchParams.delete(k); removed.push(k); }
    });
    const domain = u.hostname.replace(/^www\./, '');
    const seg = decodeURIComponent(u.pathname.split('/').filter(Boolean).pop() || '')
      .replace(/\.[a-z0-9]+$/i, '')
      .replace(/[-_+]+/g, ' ')
      .trim();
    const guessedTitle = seg && !/^\d+$/.test(seg) && seg.length > 2
      ? seg.charAt(0).toUpperCase() + seg.slice(1)
      : domain;
    const pathHint = u.pathname && u.pathname.length > 1 ? u.pathname.slice(0, 38) : '';
    return { url: u.toString(), original: raw, domain, pathHint, guessedTitle, removed };
  };

  const shortAgo = t => {
    const m = Math.round((Date.now() - t) / 6e4);
    if (m < 1) return 'Just now';
    if (m < 60) return m + 'm';
    const h = Math.round(m / 60);
    if (h < 24) return h + 'h';
    if (h < 48) return 'Yday';
    const d = Math.floor(h / 24);
    return d + 'd';
  };

  const longAgo = t => {
    const m = Math.round((Date.now() - t) / 6e4);
    if (m < 1) return 'just now';
    if (m < 60) return m + 'm ago';
    const h = Math.floor(m / 60);
    if (h < 24) return h + 'h ago';
    const d = Math.floor(h / 24);
    return d === 1 ? 'yesterday' : d + ' days ago';
  };

  // UI state
  let activeTab = 'canvas'; // 'canvas' | 'detail'
  let popoverOpen = false;
  let appDark = false;
  let canvasFilter = { type: 'all', tag: null }; // 'all' | 'pinned' | 'unopened' | 'archive' | 'tag'
  let canvasQuery = '';
  let detailID = null;
  let popQuery = '';
  let clipboardItem = parseURL('https://www.nytimes.com/2026/10/30/technology/menu-bar-apps-are-back.html?utm_source=x&utm_medium=social&smid=tw-share');

  const tabBtns = demo.querySelectorAll('[data-app-tab]');
  const macWindowHost = document.getElementById('macWindowHost');
  const macPopoverWrap = document.getElementById('macPopoverWrap');
  const menubarStashBtn = document.getElementById('menubarStashBtn');
  const dockPopoverBtn = document.getElementById('dockPopoverBtn');
  const dockThemeBtn = document.getElementById('dockThemeBtn');

  let toastTimer = null;
  const showToast = msg => {
    const el = document.getElementById('canvas-toast');
    const txt = document.getElementById('canvas-toast-text');
    if (!el || !txt) return;
    txt.textContent = msg;
    el.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('is-visible'), 2000);
  };

  const syncDockHighlights = () => {
    tabBtns.forEach(b => {
      const on = !popoverOpen && b.getAttribute('data-app-tab') === activeTab;
      b.classList.toggle('is-active', on);
    });
    if (dockPopoverBtn) dockPopoverBtn.classList.toggle('is-active', popoverOpen);
    if (menubarStashBtn) {
      menubarStashBtn.classList.toggle('is-active', popoverOpen);
      menubarStashBtn.setAttribute('aria-expanded', popoverOpen ? 'true' : 'false');
    }
  };

  // ---- Menu-Bar Popover Open / Close (dims & blurs center window) ----
  const openPopover = () => {
    popoverOpen = true;
    renderPopover();
    macPopoverWrap.classList.add('is-open');
    macWindowHost.classList.add('is-dimmed');
    syncDockHighlights();
  };

  const closePopover = () => {
    if (!popoverOpen) return;
    popoverOpen = false;
    macPopoverWrap.classList.remove('is-open');
    macWindowHost.classList.remove('is-dimmed');
    syncDockHighlights();
  };

  const togglePopover = () => {
    if (popoverOpen) closePopover();
    else openPopover();
  };

  if (menubarStashBtn) menubarStashBtn.addEventListener('click', togglePopover);
  if (dockPopoverBtn) dockPopoverBtn.addEventListener('click', togglePopover);
  const popCloseBtn = document.getElementById('popCloseBtn');
  if (popCloseBtn) popCloseBtn.addEventListener('click', closePopover);

  // Close popover when clicking anywhere outside it
  document.addEventListener('click', e => {
    if (!popoverOpen) return;
    if (
      macPopoverWrap.contains(e.target) ||
      (menubarStashBtn && menubarStashBtn.contains(e.target)) ||
      (dockPopoverBtn && dockPopoverBtn.contains(e.target)) ||
      (dockThemeBtn && dockThemeBtn.contains(e.target))
    ) {
      return;
    }
    closePopover();
  });

  // ---- Tok App Dark Mode Switch (Wallpaper & Menu Bar stay normal) ----
  if (dockThemeBtn && heroStage) {
    dockThemeBtn.addEventListener('click', () => {
      appDark = !appDark;
      heroStage.classList.toggle('is-dark', appDark);
      dockThemeBtn.classList.toggle('is-active', appDark);
    });
  }

  // ---- Center Window Switcher (Canvas / Link detail) ----
  const switchAppTab = tab => {
    closePopover();
    activeTab = tab === 'detail' ? 'detail' : 'canvas';
    if (activeTab === 'canvas') {
      detailID = null;
    } else if (!detailID) {
      const first = links.find(l => !l.archived) || links[0];
      detailID = first ? first.id : null;
    }
    renderCanvas();
    syncDockHighlights();
  };

  tabBtns.forEach(b => b.addEventListener('click', () => switchAppTab(b.getAttribute('data-app-tab'))));

  // ---- Render CanvasRoot (Sidebar + Grid OR Detail) ----
  const getFilteredLinks = () => {
    let arr = links.filter(l => {
      if (canvasFilter.type === 'archive') return l.archived;
      if (l.archived) return false;
      if (canvasFilter.type === 'pinned') return l.pinned;
      if (canvasFilter.type === 'unopened') return !l.opened;
      if (canvasFilter.type === 'tag') return l.tags.includes(canvasFilter.tag);
      return true;
    });
    const q = canvasQuery.trim().toLowerCase();
    if (q) {
      arr = arr.filter(l =>
        (l.title + ' ' + l.domain + ' ' + l.note + ' ' + l.tags.map(t => '#' + t).join(' '))
          .toLowerCase()
          .includes(q)
      );
    }
    return arr.sort((a, b) => b.createdAt - a.createdAt);
  };

  const viewTitleText = () => {
    if (canvasFilter.type === 'pinned') return 'Pinned';
    if (canvasFilter.type === 'unopened') return 'Unopened';
    if (canvasFilter.type === 'archive') return 'Archive';
    if (canvasFilter.type === 'tag') return '#' + canvasFilter.tag;
    return 'All links';
  };

  const renderCanvas = () => {
    const active = links.filter(l => !l.archived);
    demo.querySelector('[data-cnt="all"]').textContent = active.length;
    demo.querySelector('[data-cnt="pinned"]').textContent = active.filter(l => l.pinned).length;
    demo.querySelector('[data-cnt="unopened"]').textContent = active.filter(l => !l.opened).length;
    demo.querySelector('[data-cnt="archive"]').textContent = links.filter(l => l.archived).length;

    demo.querySelectorAll('#sb-sidebar-views .sb-nav-row').forEach(btn => {
      const v = btn.getAttribute('data-view');
      btn.classList.toggle('is-active', detailID === null && canvasFilter.type === v);
    });

    const tagCounts = {};
    active.forEach(l => l.tags.forEach(t => { tagCounts[t] = (tagCounts[t] || 0) + 1; }));
    const tagsBox = document.getElementById('sb-sidebar-tags');
    const sortedTags = Object.entries(tagCounts).sort((a, b) => b[1] - a[1]);
    tagsBox.innerHTML = sortedTags.map(([t, c]) => {
      const on = detailID === null && canvasFilter.type === 'tag' && canvasFilter.tag === t;
      return `<button class="sb-tag-row${on ? ' is-active' : ''}" type="button" data-side-tag="${esc(t)}">
        <img src="/assets/icons/hash.svg" alt="">
        <span>${esc(t)}</span>
        <span class="cnt">${c}</span>
      </button>`;
    }).join('');
    tagsBox.querySelectorAll('[data-side-tag]').forEach(btn => {
      btn.addEventListener('click', () => {
        canvasFilter = { type: 'tag', tag: btn.getAttribute('data-side-tag') };
        detailID = null;
        activeTab = 'canvas';
        syncDockHighlights();
        renderCanvas();
      });
    });

    const gridView = document.getElementById('canvas-grid-view');
    const detailView = document.getElementById('canvas-detail-view');

    if (detailID) {
      const link = links.find(l => l.id === detailID);
      if (link) {
        gridView.style.display = 'none';
        detailView.style.display = 'grid';
        renderDetailPane(link);
        return;
      }
      detailID = null;
    }

    gridView.style.display = 'flex';
    detailView.style.display = 'none';

    const tokenSlot = document.getElementById('canvas-token-slot');
    if (canvasFilter.type !== 'all') {
      const tok = canvasFilter.type === 'tag' ? '#' + canvasFilter.tag : canvasFilter.type;
      tokenSlot.innerHTML = `<button class="sb-search-token" type="button" id="clear-canvas-token">${esc(tok)} <img src="/assets/icons/x.svg" alt="Clear"></button>`;
      document.getElementById('clear-canvas-token').onclick = e => {
        e.preventDefault();
        canvasFilter = { type: 'all', tag: null };
        renderCanvas();
      };
    } else {
      tokenSlot.innerHTML = '';
    }

    document.getElementById('canvas-heading').textContent = viewTitleText();
    const sub = document.getElementById('canvas-subheading');
    sub.textContent = canvasFilter.type === 'pinned' ? 'Always on top' : (canvasFilter.type === 'archive' ? 'Hidden, not deleted' : '');

    const list = getFilteredLinks();
    document.getElementById('canvas-count-label').textContent = `${list.length} · newest first`;

    const grid = document.getElementById('sb-cards-container');
    if (!list.length) {
      grid.innerHTML = `<div style="grid-column:1/-1;padding:32px 8px;color:var(--tok-muted);font-size:13.5px">No links in this view yet.</div>`;
      return;
    }

    grid.innerHTML = list.map(l => `
      <div class="sb-link-card" data-open-detail="${esc(l.id)}">
        <div class="sb-card-preview">
          <img class="logo" src="${siteIcon(l.domain)}" alt="">
          ${l.pinned ? `<span class="sb-pin-badge"><img src="/assets/icons/pin.svg" alt="Pinned"></span>` : ''}
        </div>
        <div class="sb-card-info">
          <div class="sb-card-title">${esc(l.title)}</div>
          <div class="sb-card-foot">
            <span class="sb-card-domain">${esc(l.domain)} · ${shortAgo(l.createdAt)}</span>
            <button class="sb-icon-btn" type="button" data-card-archive="${esc(l.id)}" title="${l.archived ? 'Restore' : 'Archive'}">
              <img src="/assets/icons/${l.archived ? 'archive-restore' : 'archive'}.svg" alt="">
            </button>
            <button class="sb-icon-btn" type="button" data-card-del="${esc(l.id)}" title="Delete">
              <img src="/assets/icons/trash-2.svg" alt="">
            </button>
          </div>
        </div>
      </div>
    `).join('');

    grid.querySelectorAll('[data-open-detail]').forEach(card => {
      card.addEventListener('click', e => {
        if (e.target.closest('button')) return;
        detailID = card.getAttribute('data-open-detail');
        activeTab = 'detail';
        syncDockHighlights();
        renderCanvas();
      });
    });

    grid.querySelectorAll('[data-card-archive]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const id = btn.getAttribute('data-card-archive');
        const item = links.find(x => x.id === id);
        if (item) {
          item.archived = !item.archived;
          showToast(item.archived ? 'Archived' : 'Restored');
          renderCanvas();
        }
      });
    });

    grid.querySelectorAll('[data-card-del]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const id = btn.getAttribute('data-card-del');
        if (links.length <= 1) return;
        links = links.filter(x => x.id !== id);
        showToast('Deleted');
        renderCanvas();
      });
    });
  };

  // ---- Render LinkDetailView (LinkDetailView.swift) ----
  const renderDetailPane = link => {
    document.getElementById('detail-back-label').textContent = viewTitleText();
    document.getElementById('detail-big-logo').src = siteIcon(link.domain);
    document.getElementById('detail-preview-caption').textContent = `page preview · ${link.domain}`;

    const pinBtn = document.getElementById('detail-pin-btn');
    pinBtn.classList.toggle('is-filled', link.pinned);
    pinBtn.onclick = () => {
      link.pinned = !link.pinned;
      showToast(link.pinned ? 'Pinned to top' : 'Unpinned');
      renderCanvas();
    };

    document.getElementById('detail-archive-btn').onclick = () => {
      link.archived = !link.archived;
      detailID = null;
      activeTab = 'canvas';
      syncDockHighlights();
      showToast(link.archived ? 'Archived' : 'Restored');
      renderCanvas();
    };

    document.getElementById('detail-delete-btn').onclick = () => {
      if (links.length > 1) {
        links = links.filter(x => x.id !== link.id);
        detailID = null;
        activeTab = 'canvas';
        syncDockHighlights();
        showToast('Deleted');
        renderCanvas();
      }
    };

    document.getElementById('detail-title').textContent = link.title;
    document.getElementById('detail-small-logo').src = siteIcon(link.domain);
    document.getElementById('detail-domain-meta').textContent = `${link.domain} · stashed ${longAgo(link.createdAt)}`;
    document.getElementById('detail-clean-url').textContent = link.url;

    const trkBadge = document.getElementById('detail-trackers-badge');
    const strikeList = document.getElementById('detail-strike-list');
    if (link.removed && link.removed.length) {
      trkBadge.style.display = 'inline-flex';
      document.getElementById('detail-trackers-count').textContent =
        `${link.removed.length} TRACKER${link.removed.length === 1 ? '' : 'S'} REMOVED`;
      strikeList.innerHTML = link.removed.map(r => `<span class="sb-strike-chip">${esc(r)}</span>`).join('');
    } else {
      trkBadge.style.display = 'none';
      strikeList.innerHTML = '';
    }

    const tagsWrap = document.getElementById('detail-tags-wrap');
    tagsWrap.innerHTML = link.tags.map(t => `
      <button class="sb-tag-pill" type="button" data-rm-tag="${esc(t)}" title="Remove tag">
        <span>${esc(t)}</span>
        <img src="/assets/icons/x.svg" alt="">
      </button>
    `).join('') + `
      <label class="sb-add-tag-box">
        <img src="/assets/icons/plus.svg" alt="">
        <input id="detail-new-tag" placeholder="Tag" aria-label="Add tag">
      </label>
    `;
    tagsWrap.querySelectorAll('[data-rm-tag]').forEach(b => {
      b.onclick = () => {
        const tg = b.getAttribute('data-rm-tag');
        link.tags = link.tags.filter(x => x !== tg);
        renderCanvas();
      };
    });
    const newTagInp = document.getElementById('detail-new-tag');
    newTagInp.addEventListener('keydown', e => {
      if (e.key === 'Enter') {
        const val = newTagInp.value.trim().toLowerCase().replace(/^#+/, '').replace(/\s+/g, '-');
        if (val && !link.tags.includes(val)) {
          link.tags.push(val);
          renderCanvas();
        }
      }
    });

    const noteEl = document.getElementById('detail-note-input');
    noteEl.value = link.note || '';
    noteEl.oninput = () => { link.note = noteEl.value; };

    document.getElementById('detail-copy-btn').onclick = () => {
      navigator.clipboard?.writeText(link.url).catch(() => {});
      showToast('Clean URL copied');
    };
    document.getElementById('detail-open-btn').onclick = () => {
      window.open(link.url, '_blank', 'noopener');
    };
  };

  demo.querySelectorAll('#sb-sidebar-views .sb-nav-row').forEach(btn => {
    btn.addEventListener('click', () => {
      canvasFilter = { type: btn.getAttribute('data-view'), tag: null };
      detailID = null;
      activeTab = 'canvas';
      syncDockHighlights();
      renderCanvas();
    });
  });

  document.getElementById('detail-back-btn').addEventListener('click', () => {
    detailID = null;
    activeTab = 'canvas';
    syncDockHighlights();
    renderCanvas();
  });

  const canvasSearch = document.getElementById('canvas-search-input');
  canvasSearch.addEventListener('input', () => {
    canvasQuery = canvasSearch.value;
    renderCanvas();
  });

  // AddLinkForm modal
  const modal = document.getElementById('add-modal-backdrop');
  const modalInp = document.getElementById('add-modal-url');
  const modalHint = document.getElementById('add-modal-hint');
  const openAddModal = () => {
    modal.classList.add('is-open');
    modalInp.value = '';
    modalHint.textContent = 'Paste any web address. Trackers are stripped automatically.';
    setTimeout(() => modalInp.focus(), 40);
  };
  const closeAddModal = () => modal.classList.remove('is-open');

  document.getElementById('canvas-add-btn').onclick = openAddModal;
  document.getElementById('add-modal-close').onclick = closeAddModal;
  document.getElementById('add-modal-cancel').onclick = closeAddModal;
  modalInp.addEventListener('input', () => {
    const p = parseURL(modalInp.value);
    if (p && p.removed.length) {
      modalHint.textContent = `${p.removed.length} tracker${p.removed.length === 1 ? '' : 's'} will be removed: ${p.removed.join(', ')}`;
    } else if (p) {
      modalHint.textContent = `Ready to stash · ${p.domain}`;
    } else {
      modalHint.textContent = 'Paste any web address. Trackers are stripped automatically.';
    }
  });
  const saveModalLink = () => {
    const p = parseURL(modalInp.value || 'https://figma.com/blog/design-systems?utm_source=x&fbclid=IwAR');
    if (!p) return;
    links.unshift({
      id: String(Date.now()),
      title: p.guessedTitle,
      domain: p.domain,
      url: p.url,
      tags: [],
      note: '',
      pinned: false,
      archived: false,
      opened: false,
      removed: p.removed,
      createdAt: Date.now()
    });
    closeAddModal();
    detailID = null;
    showToast('Stashed');
    renderCanvas();
  };
  document.getElementById('add-modal-save').onclick = saveModalLink;
  modalInp.addEventListener('keydown', e => { if (e.key === 'Enter') saveModalLink(); });

  document.getElementById('canvas-export-btn').onclick = () => showToast(`Exported ${links.filter(l => !l.archived).length} links`);
  document.getElementById('canvas-signin-btn').onclick = () => showToast('Sign-in runs in the macOS app');

  // ---- Render Top-Right Menu-Bar Popover (PopoverView.swift) ----
  const renderPopover = () => {
    const clipSlot = document.getElementById('pop-clipboard-slot');
    if (clipboardItem) {
      const trkCount = clipboardItem.removed.length;
      clipSlot.innerHTML = `
        <div class="sb-clip-wrap">
          <div class="sb-clip-card">
            <div class="sb-clip-head">
              <img class="w" src="${siteIcon(clipboardItem.domain)}" alt="">
              <span>ON YOUR CLIPBOARD</span>
              <span style="flex:1"></span>
              ${trkCount ? `<img class="w" src="/assets/icons/shield-check.svg" alt="" style="opacity:.7"><span>${trkCount} TRACKER${trkCount === 1 ? '' : 'S'} OFF</span>` : ''}
            </div>
            <div class="sb-clip-title">${esc(clipboardItem.guessedTitle)}</div>
            <div class="sb-clip-domain">${esc(clipboardItem.domain + clipboardItem.pathHint)}</div>
            <div class="sb-clip-btns">
              <button class="sb-clip-stash" type="button" id="pop-stash-now">
                <img src="/assets/brand/pin-mark-ink.svg" width="15" height="15" alt="">
                <span>Stash it</span>
                <img src="/assets/icons/corner-down-left.svg" width="12" height="12" alt="" style="opacity:.55">
              </button>
              <button class="sb-clip-dismiss" type="button" id="pop-dismiss-clip" title="Dismiss (Esc)">
                <img src="/assets/icons/x.svg" alt="Dismiss">
              </button>
            </div>
          </div>
        </div>
      `;
      document.getElementById('pop-stash-now').onclick = e => {
        e.stopPropagation();
        links.unshift({
          id: String(Date.now()),
          title: clipboardItem.guessedTitle,
          domain: clipboardItem.domain,
          url: clipboardItem.url,
          tags: [],
          note: '',
          pinned: false,
          archived: false,
          opened: false,
          removed: clipboardItem.removed,
          createdAt: Date.now(),
          fresh: true
        });
        clipboardItem = null;
        renderPopover();
        renderCanvas();
        syncDockHighlights();
      };
      document.getElementById('pop-dismiss-clip').onclick = e => {
        e.stopPropagation();
        clipboardItem = null;
        renderPopover();
        syncDockHighlights();
      };
    } else {
      clipSlot.innerHTML = '';
    }

    const active = links.filter(l => !l.archived);
    const popInp = document.getElementById('pop-search-input');
    popInp.placeholder = `Search ${active.length} links`;
    document.getElementById('pop-section-label').textContent = popQuery.trim() ? 'RESULTS' : 'RECENT';

    const term = popQuery.trim().toLowerCase();
    const list = active
      .filter(l => !term || (l.title + ' ' + l.domain + ' ' + l.tags.join(' ')).toLowerCase().includes(term))
      .slice(0, clipboardItem ? 3 : 5);

    const rowsEl = document.getElementById('pop-rows-list');
    rowsEl.innerHTML = list.length
      ? list.map(l => `
        <button class="sb-pop-row${l.fresh ? ' fresh' : ''}" type="button" data-pop-item="${esc(l.id)}">
          <div class="sb-logo-tile"><img src="${siteIcon(l.domain)}" alt=""></div>
          <div class="sb-pop-row-text">
            <div class="sb-pop-row-title">${esc(l.title)}</div>
            <div class="sb-pop-row-meta">${esc(l.domain)} · ${shortAgo(l.createdAt)}</div>
          </div>
          ${l.pinned ? `<img class="tok-ic" src="/assets/icons/pin.svg" width="12" height="12" alt="" style="opacity:.55">` : ''}
        </button>
      `).join('')
      : `<div style="padding:16px 12px;font-size:12.5px;color:var(--tok-muted)">No links match “${esc(popQuery)}”.</div>`;

    rowsEl.querySelectorAll('[data-pop-item]').forEach(row => {
      row.onclick = () => {
        detailID = row.getAttribute('data-pop-item');
        switchAppTab('detail');
      };
    });
  };

  document.getElementById('pop-search-input').addEventListener('input', e => {
    popQuery = e.target.value;
    renderPopover();
  });
  document.getElementById('pop-plus-btn').onclick = () => {
    switchAppTab('canvas');
    openAddModal();
  };
  document.getElementById('pop-go-canvas').onclick = () => switchAppTab('canvas');
  document.getElementById('pop-signin-btn').onclick = () => {
    closePopover();
    showToast('Sign-in runs in the macOS app');
  };

  demo.querySelectorAll('[data-sample-clip]').forEach(btn => {
    btn.addEventListener('click', e => {
      e.stopPropagation();
      clipboardItem = parseURL(btn.getAttribute('data-sample-clip'));
      renderPopover();
      syncDockHighlights();
    });
  });

  // Global keyboard shortcuts: ⌥S toggles menu-bar popover, Escape closes modal/popover
  document.addEventListener('keydown', e => {
    const t = e.target;
    const typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable);
    if (e.key === 'Escape') {
      if (modal.classList.contains('is-open')) {
        closeAddModal();
      } else if (popoverOpen) {
        closePopover();
      } else if (activeTab === 'detail') {
        switchAppTab('canvas');
      }
      return;
    }
    if (!typing && e.altKey && e.code === 'KeyS') {
      e.preventDefault();
      togglePopover();
    }
  });

  // Paste anywhere on the page -> opens menu-bar Popover with that URL ready to stash!
  window.addEventListener('paste', e => {
    const t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    const p = parseURL(e.clipboardData && e.clipboardData.getData('text'));
    if (p) {
      clipboardItem = p;
      openPopover();
    }
  });

  renderCanvas();
  renderPopover();
  syncDockHighlights();
}

// ============================================================================
// Interactive 4-Step Privacy & Link-Cleaning Workflow Showcase (#wfShowcase)
// ============================================================================
const wfShowcase = document.getElementById('wfShowcase');
if (wfShowcase) {
  const wfItems = Array.from(wfShowcase.querySelectorAll('[data-wf-step]'));
  const wfPanels = Array.from(wfShowcase.querySelectorAll('[data-wf-panel]'));
  const wfTopPillText = document.getElementById('wfTopPillText');
  const STEP_MS = 6000;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  let wfIdx = 0;
  let wfElapsed = 0;
  let wfLastTs = 0;
  let wfHoverPaused = false;
  let wfInView = false;
  let wfRaf = 0;
  let wfScrollMode = false; // true: steps are driven by scroll position, not the timer

  const setWfStep = (nextIdx, resetTimer = true) => {
    wfIdx = ((nextIdx % wfItems.length) + wfItems.length) % wfItems.length;
    if (resetTimer) wfElapsed = 0;

    wfItems.forEach((item, i) => {
      const active = i === wfIdx;
      item.classList.toggle('is-active', active);
      const head = item.querySelector('.wf-head');
      if (head) head.setAttribute('aria-selected', active ? 'true' : 'false');
      const fill = item.querySelector('.wf-line-fill');
      if (fill) {
        fill.style.width = active ? (reduceMotion ? '100%' : '0%') : '0%';
      }
    });

    wfPanels.forEach((panel, i) => {
      panel.classList.toggle('is-active', i === wfIdx);
    });

    const pillLabel = wfItems[wfIdx]?.getAttribute('data-wf-pill');
    if (wfTopPillText && pillLabel) {
      wfTopPillText.textContent = pillLabel;
    }
  };

  const tickWf = now => {
    if (!wfLastTs) wfLastTs = now;
    const dt = Math.min(now - wfLastTs, 120);
    wfLastTs = now;

    if (!reduceMotion && !wfScrollMode && wfInView && !wfHoverPaused && !document.hidden) {
      wfElapsed += dt;
      const pct = Math.min((wfElapsed / STEP_MS) * 100, 100);
      const activeFill = wfItems[wfIdx]?.querySelector('.wf-line-fill');
      if (activeFill) activeFill.style.width = pct.toFixed(2) + '%';

      if (wfElapsed >= STEP_MS) {
        setWfStep(wfIdx + 1, true);
      }
    }

    if (wfInView && !reduceMotion) {
      wfRaf = requestAnimationFrame(tickWf);
    } else {
      wfRaf = 0;
    }
  };

  const startWfLoop = () => {
    if (reduceMotion || wfRaf) return;
    wfLastTs = 0;
    wfRaf = requestAnimationFrame(tickWf);
  };

  wfItems.forEach((item, i) => {
    const head = item.querySelector('.wf-head');
    if (!head) return;
    head.addEventListener('click', () => {
      if (wfScrollMode && wfScrollTo) { wfScrollTo(i); return; }
      setWfStep(i, true);
      startWfLoop();
    });
    head.addEventListener('keydown', e => {
      if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
        e.preventDefault();
        const next = (i + 1) % wfItems.length;
        setWfStep(next, true);
        wfItems[next]?.querySelector('.wf-head')?.focus();
      } else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
        e.preventDefault();
        const prev = (i - 1 + wfItems.length) % wfItems.length;
        setWfStep(prev, true);
        wfItems[prev]?.querySelector('.wf-head')?.focus();
      }
    });
  });

  wfShowcase.addEventListener('mouseenter', () => { wfHoverPaused = true; });
  wfShowcase.addEventListener('mouseleave', () => { wfHoverPaused = false; wfLastTs = 0; });
  wfShowcase.addEventListener('focusin', () => { wfHoverPaused = true; });
  wfShowcase.addEventListener('focusout', e => {
    if (!wfShowcase.contains(e.relatedTarget)) {
      wfHoverPaused = false;
      wfLastTs = 0;
    }
  });

  // ---- Scroll-driven steps: the block pins while each of the 4 steps opens in turn ----
  var wfScrollTo = null;
  {
    const track = document.getElementById('wfTrack');
    const pin = document.getElementById('wfPin');
    const STEP_VH = 0.55; // scroll distance per step, as a share of the viewport height
    let pinTop = 96, dist = 0, ticking = false;

    const navOffset = () => (document.querySelector('.nav-wrap')?.offsetHeight || 52) + 24;

    const grid = pin ? pin.querySelector('.wf-grid') : null;
    let compact = false, lastW = 0;

    // Compact (narrow) mode: a 4-segment progress bar above the open step.
    let dots = null;
    if (pin) {
      dots = document.createElement('div');
      dots.className = 'wf-dots';
      dots.setAttribute('aria-hidden', 'true');
      dots.innerHTML = wfItems.map(() => '<span><i></i></span>').join('');
      pin.querySelector('.wf-list')?.prepend(dots);
    }

    const layout = () => {
      if (!track || !pin || !grid) return;
      lastW = window.innerWidth;
      track.style.height = '';
      pin.classList.remove('is-pinned');
      grid.style.zoom = '';
      wfScrollMode = true; // every window size: scrolling drives the steps
      compact = window.innerWidth <= 900;
      pin.classList.toggle('is-compact', compact);
      const vh = window.innerHeight;
      const avail = vh - navOffset() - 16;
      // Measure the tallest step so the pinned block never jumps or overflows.
      const keep = wfIdx;
      let pinH = 0;
      wfItems.forEach((_, i) => { setWfStep(i, true); pinH = Math.max(pinH, pin.getBoundingClientRect().height); });
      setWfStep(keep, true);
      // Too tall for the window? Scale the whole block down to fit (not below 55%).
      let z = 1;
      if (pinH > avail) {
        z = Math.max(0.55, avail / pinH);
        grid.style.zoom = z.toFixed(3);
        pinH = pinH * z;
      }
      pinTop = Math.max(navOffset(), Math.round((vh - pinH) / 2));
      if (pinH + pinTop > vh) pinTop = navOffset();
      dist = Math.round(vh * STEP_VH * wfItems.length);
      track.style.height = Math.ceil(pinH + dist) + 'px';
      pin.style.top = pinTop + 'px';
      pin.classList.add('is-pinned');
      onScroll();
    };

    // ---- Eased parallax layers ----
    let plxTarget = 0, plxPos = 0, plxRaf = 0, plxLast = 0;
    const plxApply = v => {
      const n = wfItems.length;
      const f = v - Math.floor(v);
      pin.style.setProperty('--wf-p', (Math.min(Math.max(v / n, 0), 1)).toFixed(4));
      pin.style.setProperty('--wf-float', Math.sin(f * Math.PI).toFixed(4)); // 0 → 1 → 0 within each step
    };
    const plxStep = now => {
      const dt = plxLast ? Math.min(now - plxLast, 64) : 16.7;
      plxLast = now;
      plxPos += (plxTarget - plxPos) * (1 - Math.exp(-dt * 0.008)); // ~0.35s glide, frame-rate independent
      if (Math.abs(plxTarget - plxPos) < 0.0005) plxPos = plxTarget;
      plxApply(plxPos);
      plxRaf = plxPos === plxTarget ? 0 : requestAnimationFrame(plxStep);
    };

    const onScroll = () => {
      if (!wfScrollMode || ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        ticking = false;
        const p = Math.min(Math.max((pinTop - track.getBoundingClientRect().top) / dist, 0), 0.99999);
        const pos = p * wfItems.length;
        const idx = Math.floor(pos);
        if (idx !== wfIdx) setWfStep(idx, true);
        const frac = pos - idx;
        // Parallax target; the layers ease towards it in plxStep (smoother than following each wheel tick).
        plxTarget = pos;
        if (!plxRaf) { plxLast = 0; plxRaf = requestAnimationFrame(plxStep); }
        const fill = wfItems[idx]?.querySelector('.wf-line-fill');
        if (fill) fill.style.width = (frac * 100).toFixed(2) + '%';
        if (dots) dots.querySelectorAll('i').forEach((el, i) => {
          el.style.width = (i < idx ? 100 : i === idx ? frac * 100 : 0).toFixed(2) + '%';
        });
      });
    };

    wfScrollTo = i => {
      const trackTop = track.getBoundingClientRect().top + window.scrollY;
      const y = trackTop - pinTop + (dist / wfItems.length) * (i + 0.15);
      window.scrollTo({ top: y, behavior: 'smooth' });
    };

    if (track && pin) {
      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', () => { if (window.innerWidth !== lastW || window.innerWidth > 900) layout(); });
      window.addEventListener('load', layout);
      layout();
    }
  }

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        wfInView = entry.isIntersecting;
        if (wfInView) startWfLoop();
      });
    }, { threshold: 0.18 });
    io.observe(wfShowcase);
  } else {
    wfInView = true;
    startWfLoop();
  }

  setWfStep(0, true);
}

// ---- 5. Vestris-Style Character-by-Character Scroll Title Reveal ----
const scrollTitleEls = Array.from(document.querySelectorAll('[data-scroll-title]'));
if (scrollTitleEls.length && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const titleItems = scrollTitleEls.map(el => {
    const plain = (el.textContent || '').replace(/\s+/g, ' ').trim();
    if (plain) el.setAttribute('aria-label', plain);

    const chars = [];
    const frag = document.createDocumentFragment();

    Array.from(el.childNodes).forEach(node => {
      if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'BR') {
        const br = document.createElement('br');
        br.setAttribute('aria-hidden', 'true');
        frag.appendChild(br);
        return;
      }
      const txt = node.textContent || '';
      const tokens = txt.split(/(\s+)/);
      tokens.forEach(tok => {
        if (!tok) return;
        if (/^\s+$/.test(tok)) {
          frag.appendChild(document.createTextNode(' '));
          return;
        }
        const wordSpan = document.createElement('span');
        wordSpan.className = 'sr-word';
        wordSpan.setAttribute('aria-hidden', 'true');
        for (const ch of Array.from(tok)) {
          const cSpan = document.createElement('span');
          cSpan.className = 'sr-char';
          cSpan.textContent = ch;
          wordSpan.appendChild(cSpan);
          chars.push(cSpan);
        }
        frag.appendChild(wordSpan);
      });
    });

    el.textContent = '';
    el.appendChild(frag);
    return { el, chars, cur: -1, target: 0 };
  });

  let srRaf = 0;
  let srLastTs = 0;

  const applyTitleChars = (item, p) => {
    const n = item.chars.length;
    if (!n) return;
    const band = Math.max(0.14, 3.6 / n);
    for (let i = 0; i < n; i++) {
      const start = (i / n) * (1 - band);
      const t = Math.min(Math.max((p - start) / band, 0), 1);
      const op = 0.2 + 0.8 * t;
      item.chars[i].style.opacity = op.toFixed(3);
    }
  };

  const stepScrollTitles = now => {
    const dt = srLastTs ? Math.min(now - srLastTs, 64) : 16.67;
    srLastTs = now;
    const alpha = 1 - Math.exp(-dt * 0.017);

    const vpH = window.innerHeight;
    const startY = vpH * 0.90;
    const endY = vpH * 0.48;
    const maxScroll = Math.max(0, document.documentElement.scrollHeight - vpH);
    const nearBottom = maxScroll > 0 && window.scrollY >= maxScroll - 36;

    let stillMoving = false;
    titleItems.forEach(item => {
      const rect = item.el.getBoundingClientRect();
      let raw = (startY - rect.top) / Math.max(1, startY - endY);
      if (nearBottom && rect.top < vpH * 0.86) raw = 1;
      item.target = Math.min(Math.max(raw, 0), 1);

      if (item.cur < 0) {
        item.cur = item.target;
        applyTitleChars(item, item.cur);
      } else {
        const next = item.cur + (item.target - item.cur) * alpha;
        if (Math.abs(item.target - next) < 0.001) {
          if (item.cur !== item.target) {
            item.cur = item.target;
            applyTitleChars(item, item.cur);
          }
        } else {
          item.cur = next;
          applyTitleChars(item, item.cur);
          stillMoving = true;
        }
      }
    });

    if (stillMoving) {
      srRaf = requestAnimationFrame(stepScrollTitles);
    } else {
      srRaf = 0;
      srLastTs = 0;
    }
  };

  const kickScrollTitles = () => {
    if (!srRaf) {
      srLastTs = 0;
      srRaf = requestAnimationFrame(stepScrollTitles);
    }
  };

  kickScrollTitles();
  window.addEventListener('scroll', kickScrollTitles, { passive: true });
  window.addEventListener('resize', kickScrollTitles);
}

// ---- 6. Subtle Settle / Scroll Reveal Observer ----
if ('IntersectionObserver' in window && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
  const revealEls = document.querySelectorAll('[data-reveal]');
  const ro = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-revealed');
        ro.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  revealEls.forEach(el => ro.observe(el));
} else {
  document.querySelectorAll('[data-reveal]').forEach(el => el.classList.add('is-revealed'));
}

// ---- "See pricing": smooth scroll to the pricing section (also when arriving via /#pricing) ----
{
  const pricing = document.getElementById('pricing');
  if (pricing) {
    const goToPricing = (smooth = true) => {
      const navH = (document.querySelector('.nav-wrap')?.offsetHeight || 52) + 20;
      const y = pricing.getBoundingClientRect().top + window.scrollY - navH;
      window.scrollTo({ top: y, behavior: smooth && !matchMedia('(prefers-reduced-motion: reduce)').matches ? 'smooth' : 'auto' });
    };
    document.querySelectorAll('a[href="#pricing"], a[href="/#pricing"]').forEach(a => {
      a.addEventListener('click', e => { e.preventDefault(); history.replaceState(null, '', '#pricing'); goToPricing(); });
    });
    if (location.hash === '#pricing') {
      // The hero resizes the page after load; land on pricing once layout has settled.
      window.addEventListener('load', () => setTimeout(() => goToPricing(false), 60));
    }
  }
}

// ---- Pricing currency: USD by default, BDT for visitors in Bangladesh (remembered per browser) ----
{
  const btn = document.getElementById('prCurBtn');
  const q = document.getElementById('prCurQ');
  if (btn && q) {
    const prices = document.querySelectorAll('#pricing [data-usd]');
    const apply = cur => {
      prices.forEach(el => {
        if (cur === 'BDT') {
          // The site font has no ৳ glyph, so draw it as an SVG (outline from Noto Sans Bengali, OFL).
          el.innerHTML = '<svg class="pr-taka" viewBox="60 -784 472 786" aria-hidden="true"><path transform="scale(1,-1)" fill="currentColor" d="M280 -2Q207 -2 170.0 43.0Q133 88 133 178V711H194Q194 685 177.0 663.5Q160 642 130 642Q96 642 78.0 663.0Q60 684 60 712Q60 744 82.0 764.0Q104 784 139 784Q179 784 203.5 758.0Q228 732 228 682V168Q228 126 241.0 104.0Q254 82 289 82Q320 82 347.5 99.0Q375 116 395.5 143.0Q416 170 428.0 203.5Q440 237 440 269Q440 298 427.5 313.0Q415 328 382 328L388 401Q427 401 445.5 381.5Q464 362 464 334Q464 302 446.5 280.0Q429 258 394 258Q361 258 339.0 278.5Q317 299 317 334Q317 374 344.0 395.0Q371 416 411 416Q447 416 474.5 399.0Q502 382 517.0 350.5Q532 319 532 275Q532 225 513.5 176.0Q495 127 461.5 87.0Q428 47 382.0 22.5Q336 -2 280 -2ZM60 480V563H485V480Z"/></svg>' + el.dataset.bdt.replace('৳', '');
        } else {
          // Same separate sign as ৳ so $ isn't squeezed by the tight number tracking.
          el.innerHTML = '<span class="pr-cur">$</span>' + el.dataset.usd.replace('$', '');
        }
      });
      q.textContent = cur === 'BDT' ? 'Outside Bangladesh?' : 'In Bangladesh?';
      btn.textContent = cur === 'BDT' ? 'Show prices in USD' : 'Show prices in BDT';
      btn.dataset.cur = cur;
    };
    let saved = 'USD';
    try { saved = localStorage.getItem('sb_currency') === 'BDT' ? 'BDT' : 'USD'; } catch (e) {}
    apply(saved);
    btn.addEventListener('click', () => {
      const next = btn.dataset.cur === 'BDT' ? 'USD' : 'BDT';
      apply(next);
      try { localStorage.setItem('sb_currency', next); } catch (e) {}
    });
  }
}

// ---- Smooth wheel scrolling (desktop mice/trackpads), like Lenis "smoothWheel" ----
// Keyboard, scrollbar and touch scrolling stay native. Off with Reduce Motion.
(() => {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches || matchMedia('(pointer: coarse)').matches) return;
  let target = window.scrollY, current = window.scrollY, raf = 0, last = 0, animating = false;
  const maxY = () => document.documentElement.scrollHeight - window.innerHeight;
  // Let inner scroll areas (popover lists, text boxes, code blocks) scroll themselves.
  const innerCanScroll = (el, dy) => {
    for (; el && el !== document.body && el !== document.documentElement; el = el.parentElement) {
      if (el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') return true;
      const oy = getComputedStyle(el).overflowY;
      if ((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight + 1) {
        if (dy < 0 ? el.scrollTop > 0 : el.scrollTop + el.clientHeight < el.scrollHeight - 1) return true;
      }
    }
    return false;
  };
  const step = now => {
    const dt = last ? Math.min(now - last, 64) : 16.7;
    last = now;
    current += (target - current) * (1 - Math.exp(-dt * 0.011)); // ~0.3s glide
    if (Math.abs(target - current) < 0.5) current = target;
    window.scrollTo({ top: current, behavior: 'instant' });
    if (current !== target) { raf = requestAnimationFrame(step); } else { raf = 0; animating = false; }
  };
  window.addEventListener('wheel', e => {
    if (e.ctrlKey || e.defaultPrevented) return;                 // pinch-zoom / handled elsewhere
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;           // horizontal swipes stay native
    if (innerCanScroll(e.target, e.deltaY)) return;
    e.preventDefault();
    const unit = e.deltaMode === 1 ? 32 : e.deltaMode === 2 ? window.innerHeight : 1;
    if (!animating) { current = window.scrollY; target = window.scrollY; animating = true; }
    target = Math.max(0, Math.min(maxY(), target + e.deltaY * unit));
    if (!raf) { last = 0; raf = requestAnimationFrame(step); }
  }, { passive: false });
  // Any other scroll (keyboard, scrollbar, anchor links) resets the glide.
  window.addEventListener('scroll', () => { if (!animating) { current = target = window.scrollY; } }, { passive: true });
  ['keydown', 'mousedown', 'touchstart'].forEach(t => window.addEventListener(t, () => {
    if (animating) { cancelAnimationFrame(raf); raf = 0; animating = false; current = target = window.scrollY; }
  }, { passive: true }));
})();
