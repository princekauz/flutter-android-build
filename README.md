# Flutter Android Build Pipeline

A self-hosted build farm for Flutter Android APKs, running on GitHub Actions, with a live status dashboard on GitHub Pages.

```
┌─────────────┐    push     ┌──────────────────┐    artifacts     ┌──────────────┐
│  Your       │ ─────────▶ │  GitHub Actions  │ ───────────────▶ │  APKs (per   │
│  machine    │             │  (Ubuntu + SDK)  │                 │  ABI)        │
└─────────────┘             └──────────────────┘                 └──────────────┘
                                      │
                                      │ updates docs/*.json
                                      ▼
                             ┌──────────────────┐
                             │  GitHub Pages    │
                             │  status dashboard│
                             └──────────────────┘
```

## What's in here

| Path | Purpose |
|---|---|
| `.github/workflows/build.yml` | The build pipeline. Runs on every push to `main`, or manually from the Actions tab. |
| `app/` | A minimal Flutter sample app — replace with your own. |
| `docs/` | The GitHub Pages dashboard (`index.html`, `style.css`, `app.js`). |
| `docs/latest.json` | Auto-written by the workflow after every build. |
| `docs/history.json` | Rolling history of the last 50 builds. |
| `docs/builds.json` | Artifact manifest for the latest build. |
| `scripts/build_metadata.py` | Builds `meta.json` from APK outputs. |
| `scripts/update_history.py` | Merges a new build into `docs/history.json`. |

## How to use it

1. **Create the GitHub repo** (one-time, in your browser):
   `github.com/new` → name it `flutter-android-build` (or anything) → **Public** → Create.

2. **Push this directory** — see [`PUSH.md`](PUSH.md) for the exact commands.

3. **Enable GitHub Pages**:
   Repo → Settings → Pages → **Source**: `Deploy from a branch` → Branch: `main` → Folder: `/docs` → Save.

4. **Trigger the first build** by either:
   - Pushing a commit to `main`, **or**
   - Actions tab → *Build Flutter Android APK* → **Run workflow**

5. **Watch the dashboard** at `https://<your-username>.github.io/flutter-android-build/`

## Triggering builds

Every push to `main` triggers a build automatically. To start one without committing:

1. Go to **Actions** → **Build Flutter Android APK** → **Run workflow**
2. Pick:
   - **build_mode**: `release` (default), `profile`, or `debug`
   - **split_per_abi**: `true` (default — 3 smaller APKs) or `false` (one fat APK)
3. Hit **Run workflow**

## What you'll get back

After a build, four things happen:

1. **Workflow artifacts** — `flutter-apks-<run-number>` zip on the Actions run page (retained 30 days)
2. **Build summary** — table in the Actions run summary
3. **`docs/latest.json` + `docs/history.json`** — committed back to the repo, feeds the dashboard
4. **Dashboard auto-updates** at your Pages URL within seconds

## Replacing the sample app

Put your real Flutter project under `app/` (or change `working-directory:` in the workflow if you prefer a different layout). The workflow expects a standard Flutter project: `pubspec.yaml`, `lib/`, `android/`.

## Customizing

- **Flutter version**: change `env.FLUTTER_VERSION` in `build.yml`.
- **Java version**: change `env.JAVA_VERSION`.
- **Build artifacts retention**: `retention-days:` in the upload step.
- **Dashboard refresh rate**: `REFRESH_INTERVAL_MS` in `docs/app.js`.
- **Pages theme**: CSS variables at the top of `docs/style.css`.

## Sign your release APKs

The sample `build.gradle` uses the **debug** signing config so CI produces a runnable APK without managing a keystore. For Play Store distribution, create a keystore, base64-encode it, and add it as repo secrets. Then update `app/android/app/build.gradle` to use a `release` signing config that reads from a `key.properties` file written from secrets. Not included here because keystore handling is project-specific — see Flutter's [official signing guide](https://docs.flutter.dev/deployment/android#signing-the-app).

## License

MIT.
