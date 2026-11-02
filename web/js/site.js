// Stashbar website: download links + live menu-bar demo.
export const DMG_URL = 'https://github.com/sajidur7/Stashbar/releases/latest/download/Stashbar.dmg';

document.querySelectorAll('[data-download]').forEach(a => { a.href = DMG_URL; });

// Show the latest version next to download buttons (best effort).
fetch('https://api.github.com/repos/sajidur7/Stashbar/releases/latest')
  .then(r => (r.ok ? r.json() : null))
  .then(j => {
    if (!j) return;
    const v = (j.tag_name || '').replace(/^v/, '');
    const asset = (j.assets || []).find(a => a.name === 'Stashbar.dmg');
    const size = asset ? ' · ' + (asset.size / 1048576).toFixed(1) + ' MB' : '';
    document.querySelectorAll('[data-version]').forEach(el => { el.textContent = 'Version ' + v + size + ' · macOS 13+ · Apple silicon & Intel'; });
  })
  .catch(() => {});

// ---- Live demo ------------------------------------------------------------
const demo = document.getElementById('demo');
if (demo) {
  const TRACK = /^(utm_|fbclid|gclid|dclid|mc_|igshid|igsh$|si$|ref_src|smid|_hs|yclid|msclkid|twclid|ttclid|_ga|_gl|spm|mkt_tok)/i;
  const LOGO = { 'github.com': 'github', 'x.com': 'twitter', 'twitter.com': 'twitter', 'youtube.com': 'youtube', 'youtu.be': 'youtube', 'developer.apple.com': 'apple', 'apple.com': 'apple', 'figma.com': 'figma', 'stripe.com': 'credit-card', 'arxiv.org': 'file-text', 'nytimes.com': 'file-text', 'medium.com': 'book-open', 'reddit.com': 'message-circle', 'notion.so': 'notebook' };
  const icon = d => `/assets/icons/${LOGO[d] || 'globe'}.svg`;
  const H = 36e5;
  let links = [
    { title: 'A talk on typographic rhythm in interfaces', domain: 'youtube.com', url: 'https://youtube.com', at: Date.now() - 2 * H },
    { title: 'swift-collections: ordered sets, deques', domain: 'github.com', url: 'https://github.com/apple/swift-collections', at: Date.now() - 4 * H },
    { title: 'Variables & modes: a practical guide', domain: 'figma.com', url: 'https://figma.com', at: Date.now() - 26 * H },
    { title: 'How we think about idempotency', domain: 'stripe.com', url: 'https://stripe.com/blog', at: Date.now() - 80 * H },
  ];
  let clip = null;
  let q = '';

  const $ = s => demo.querySelector(s);
  const esc = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  const parse = raw => {
    let s = (raw || '').trim();
    if (!s || /\s/.test(s)) return null;
    if (!/^https?:\/\//i.test(s)) { if (/^[\w-]+(\.[\w-]+)+(\/|$|\?)/.test(s)) s = 'https://' + s; else return null; }
    let u; try { u = new URL(s); } catch { return null; }
    if (!/\.[a-z]{2,}$/i.test(u.hostname)) return null;
    let n = 0;
    [...u.searchParams.keys()].forEach(k => { if (TRACK.test(k)) { u.searchParams.delete(k); n++; } });
    const domain = u.hostname.replace(/^www\./, '');
    const seg = decodeURIComponent(u.pathname.split('/').filter(Boolean).pop() || '').replace(/\.[a-z0-9]+$/i, '').replace(/[-_+]+/g, ' ').trim();
    const title = seg && !/^\d+$/.test(seg) && seg.length > 2 ? seg.charAt(0).toUpperCase() + seg.slice(1) : domain;
    return { url: u.toString(), domain, title, trackers: n };
  };

  const ago = t => {
    const m = Math.round((Date.now() - t) / 6e4);
    if (m < 1) return 'Just now';
    if (m < 60) return m + 'm';
    const h = Math.round(m / 60);
    if (h < 24) return h + 'h';
    return h < 48 ? 'Yesterday' : new Date(t).toLocaleDateString('en-GB', { weekday: 'short' });
  };

  const clock = () => {
    const now = new Date();
    $('.clock').textContent = now.toLocaleDateString('en-GB', { weekday: 'short' }) + ' ' + now.getDate() + ' ' +
      now.toLocaleDateString('en-GB', { month: 'short' }) + ' ' + now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
  };

  const render = () => {
    const top = $('#demo-top');
    if (clip) {
      top.innerHTML = `<div class="clip">
          <div class="clip-top"><img src="${icon(clip.domain)}" width="12" height="12" style="filter:invert(1)" alt=""><span>On your clipboard · ${esc(clip.domain)}</span><button class="esc" id="demo-esc" aria-label="Dismiss">Esc</button></div>
          <div class="clip-title">${esc(clip.title)}</div>
          ${clip.trackers ? `<div class="clip-trk">${clip.trackers} tracker${clip.trackers === 1 ? '' : 's'} removed</div>` : ''}
          <button class="stash-btn" id="demo-stash"><img src="/assets/brand/pin-mark-ink.svg" width="14" height="14" alt="">Stash it<small>⌥S</small></button>
        </div>`;
      $('#demo-esc').onclick = () => { clip = null; render(); };
      $('#demo-stash').onclick = stash;
    } else {
      top.innerHTML = `<div class="paste">
          <input id="demo-in" placeholder="Paste a link here — ⌘V" aria-label="Paste a link">
          <div class="paste-row"><span>Copy any link, then paste it.</span><button class="link-btn" id="demo-sample">Try a sample</button></div>
        </div>`;
      const inp = $('#demo-in');
      inp.addEventListener('paste', e => { const p = parse(e.clipboardData.getData('text')); if (p) { e.preventDefault(); clip = p; render(); } });
      inp.addEventListener('input', () => { const p = parse(inp.value); if (p && /^https?:\/\//i.test(inp.value)) { clip = p; render(); } });
      inp.addEventListener('keydown', e => { if (e.key === 'Enter') { const p = parse(inp.value); if (p) { clip = p; render(); } } });
      $('#demo-sample').onclick = () => { clip = parse('https://www.nytimes.com/2026/10/30/technology/menu-bar-apps-are-back.html?utm_source=x&utm_medium=social&smid=tw-share'); render(); };
    }
    const term = q.trim().toLowerCase();
    const list = links.filter(l => !term || (l.title + ' ' + l.domain).toLowerCase().includes(term)).slice(0, clip ? 3 : 4);
    $('#demo-search').placeholder = 'Search ' + (124 + links.length) + ' links';
    $('#demo-list').innerHTML = list.length
      ? list.map(l => `<a class="row${l.fresh ? ' fresh' : ''}" href="${esc(l.url)}" target="_blank" rel="noopener">
          <div class="tile"><img src="${icon(l.domain)}" alt=""></div>
          <div class="row-text"><div class="row-title">${esc(l.title)}</div><div class="row-meta">${esc(l.domain)} · ${ago(l.at)}</div></div></a>`).join('')
      : `<div class="empty">No links match “${esc(q)}”.</div>`;
  };

  const stash = () => {
    if (!clip) return;
    links = [{ ...clip, at: Date.now(), fresh: true }, ...links.map(l => ({ ...l, fresh: false }))];
    clip = null; q = ''; $('#demo-search').value = '';
    render();
  };

  $('#demo-search').addEventListener('input', e => { q = e.target.value; render(); });
  window.addEventListener('paste', e => {
    const t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    const p = parse(e.clipboardData && e.clipboardData.getData('text'));
    if (p) { clip = p; render(); }
  });
  window.addEventListener('keydown', e => {
    if (e.altKey && e.code === 'KeyS' && clip) { e.preventDefault(); stash(); }
    else if (e.key === 'Escape' && clip) { clip = null; render(); }
  });
  clock();
  setInterval(clock, 15000);
  render();
}
