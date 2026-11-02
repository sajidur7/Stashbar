import Foundation

/// Sign-in page served by the app at http://localhost:<port>/auth.
/// Runs Firebase's standard web sign-in (Google / Apple) in the user's browser, then
/// navigates to /callback on the same loopback server with the refresh token.
enum SignInPage {
    static var html: String {
        template
            .replacingOccurrences(of: "__API_KEY__", with: Config.firebaseAPIKey)
            .replacingOccurrences(of: "__PROJECT__", with: Config.firebaseProjectID)
    }

    private static let template = #"""
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="referrer" content="no-referrer"><title>Sign in to Stashbar</title>
    <style>
    body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f2f0;font-family:Duplet,Outfit,-apple-system,system-ui,sans-serif;color:#0c0a08;padding:24px;box-sizing:border-box}
    .c{width:100%;max-width:440px;background:#fff;border:1px solid #ebe6df;border-radius:16px;padding:36px;display:flex;flex-direction:column;gap:20px;box-sizing:border-box}
    .i{width:56px;height:56px;border-radius:13px;background:#e4f222;display:grid;place-items:center}
    h1{font-weight:500;font-size:32px;letter-spacing:-.04em;margin:0;line-height:1.1}p{margin:0;color:#6d6c6b;font-size:14px;line-height:1.55}
    button{font:inherit;width:100%;height:50px;border-radius:10px;font-size:15px;font-weight:500;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:10px;border:1px solid #0c0a08;background:#e4f222;color:#0c0a08}
    button.ghost{border:0;background:transparent;height:40px;font-weight:400;color:#6d6c6b}
    button:disabled{opacity:.6;cursor:default}
    .e{padding:12px 14px;border-radius:10px;background:#f4f2f0;font-size:13px}
    .s{width:18px;height:18px;border:2px solid #ebe6df;border-top-color:#0c0a08;border-radius:50%;animation:r .8s linear infinite}@keyframes r{to{transform:rotate(360deg)}}
    </style></head>
    <body><main class="c">
    <div class="i"><svg width="30" height="30" viewBox="11.95 13.90 66.10 66.10"><g transform="rotate(-28 50 50)"><g fill="none" stroke="#000" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="50" cy="32" rx="26" ry="13"/><path d="M24 32v7a26 13 0 0 0 52 0v-7"/></g><path d="M46 52h8l-2.6 27.5a1.4 1.4 0 0 1-2.8 0z" fill="#000"/></g></svg></div>
    <h1 id="t">Sign in to Stashbar</h1>
    <p id="sub">Back up your links and sync them across your Macs.</p>
    <div id="a" style="display:flex;flex-direction:column;gap:8px"></div>
    <div id="e" class="e" hidden></div>
    <p style="font-size:12px">We store the links you pin — never your browsing history.</p>
    </main>
    <script type="module">
    import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
    import { getAuth, GoogleAuthProvider, OAuthProvider, signInWithPopup, signOut, inMemoryPersistence, setPersistence }
      from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
    const q = new URLSearchParams(location.search);
    const state = q.get('state') || '';
    const which = q.get('provider') === 'apple' ? 'apple' : 'google';
    const $ = id => document.getElementById(id);
    const err = m => { $('e').hidden = false; $('e').textContent = m; };
    const back = o => location.replace('/callback?' + new URLSearchParams({ state, ...o }));
    const app = initializeApp({ apiKey: '__API_KEY__', authDomain: '__PROJECT__.firebaseapp.com', projectId: '__PROJECT__' });
    const auth = getAuth(app);
    await setPersistence(auth, inMemoryPersistence);
    const provider = which === 'apple' ? new OAuthProvider('apple.com') : new GoogleAuthProvider();
    if (which === 'apple') { provider.addScope('email'); provider.addScope('name'); } else provider.setCustomParameters({ prompt: 'select_account' });
    const pid = which === 'apple' ? 'apple.com' : 'google.com';
    const label = which === 'apple' ? 'Continue with Apple' : 'Continue with Google';
    $('a').innerHTML = '<button id="go">' + label + '</button><button class="ghost" id="x">Cancel</button>';
    const go = async (auto) => {
      $('e').hidden = true; $('go').disabled = true;
      try {
        const r = await signInWithPopup(auth, provider);
        $('t').textContent = 'Returning to Stashbar…';
        $('sub').textContent = 'Signed in as ' + (r.user.email || r.user.displayName || 'you') + '.';
        $('a').innerHTML = '<div class="s"></div>';
        const rt = r.user.refreshToken;
        await signOut(auth).catch(() => {});
        back({ refresh_token: rt, provider: pid });
      } catch (e) {
        $('go').disabled = false;
        const c = (e && e.code) || '';
        if (c.includes('popup-closed') || c.includes('cancelled-popup')) return;
        if (c.includes('popup-blocked')) return auto ? undefined : err('Your browser blocked the sign-in window. Allow pop-ups for localhost and try again.');
        if (c.includes('operation-not-allowed')) return err(label.replace('Continue with ', '') + ' sign-in isn’t switched on in Firebase.');
        if (c.includes('account-exists-with-different-credential')) return err('This email already uses another sign-in method. Use that one instead.');
        if (c.includes('network')) return err('Network problem. Check your connection and try again.');
        err((e && e.message) || 'Something went wrong. Try again.');
      }
    };
    $('go').onclick = () => go(false);
    $('x').onclick = () => back({ error: 'cancelled' });
    go(true); // try straight away; if the browser wants a click, the button is there
    </script></body></html>
    """#
}
