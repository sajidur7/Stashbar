# Stashbar

A quiet macOS menu-bar app: copy a link, press **⌥S**, and it's stashed, cleaned of trackers and searchable.

- **Download:** <https://github.com/sajidur7/Stashbar/releases/latest/download/Stashbar.dmg>
- **Website:** `web/` (deployed by Vercel from `main`)

## Repo layout

| Path | What |
| --- | --- |
| `app/` | Native Swift/SwiftUI app (Swift Package, macOS 13+, no third-party dependencies) |
| `app/scripts/build_app.sh` | Builds a universal `Stashbar.app`, ad-hoc signs it, packs `Stashbar.dmg` |
| `web/` | Landing page, help, privacy, and `/auth` (the browser sign-in hand-off page) |
| `firebase/firestore.rules` | Firestore security rules (each user can only touch `users/{their uid}/…`) |
| `assets/` | Source SVGs from the design; `tools/build_assets.py` regenerates app/web assets |
| `.github/workflows/release.yml` | On every push to `main` that touches `app/`: test → build → smoke-launch → publish a GitHub release |

## How sign-in works

The app never embeds a Firebase SDK. It opens `https://stashbar.vercel.app/auth?provider=google|apple&port=…&state=…`,
the page runs Firebase's standard web sign-in, then redirects to a one-shot `http://127.0.0.1:<port>/callback` listener
inside the app with a refresh token. The app exchanges it with the Firebase REST APIs and talks to Firestore over REST.

## Firebase setup (project `stashbar-a2455`)

1. **Project settings → General → Your apps → Add app → Web.** Copy `apiKey` and `appId` into
   `web/js/firebase-config.js`, and `apiKey` into `app/Sources/StashBar/Config.swift`.
2. **Authentication → Sign-in method:** enable **Google**. (Apple needs an Apple Developer account: Services ID + key.)
3. **Authentication → Settings → Authorized domains:** add `stashbar.vercel.app` (and any custom domain).
4. **Firestore → Rules:** paste `firebase/firestore.rules` and publish.

## Installing an unsigned build

Builds are ad-hoc signed (no Apple Developer ID), so on first launch macOS says it can't verify the developer.
Open **System Settings → Privacy & Security → Open Anyway** once.

## Quitting

Right-click the menu-bar pin → **Quit Stashbar** (or ⌘Q while a Stashbar window is focused). The process exits fully.

## Develop

```sh
cd app && swift test          # unit tests (macOS)
VERSION=1.0.0 app/scripts/build_app.sh && open app/build/Stashbar.app
python3 tools/build_assets.py # after changing SVGs in assets/
```
