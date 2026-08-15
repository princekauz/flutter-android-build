# Pushing this project to GitHub

Follow these steps once. After the first push, every `git push` triggers an Android build automatically.

## 1. Create the empty repo on GitHub

1. Open https://github.com/new
2. **Repository name**: `flutter-android-build` (or whatever you want — update the Pages URL below if you change it)
3. **Visibility**: **Public** (Pages is free for public repos)
4. **Do NOT** initialize with README, license, or .gitignore — we'll push our own
5. Click **Create repository**

Note the URL GitHub shows you, e.g. `https://github.com/yourusername/flutter-android-build.git`.

## 2. Push from this directory

Replace `yourusername` with your actual GitHub username in the commands below:

```bash
cd /root/flutter-android-build

git remote add origin https://github.com/yourusername/flutter-android-build.git

git branch -M main

git add .
git commit -m "Initial commit: Flutter APK build pipeline + status dashboard"

git push -u origin main
```

Git will ask for your username and password. **Use a Personal Access Token as the password** — GitHub no longer accepts account passwords for HTTPS pushes.

To create a token:
- https://github.com/settings/tokens → **Generate new token** → **Classic**
- Scopes: just `repo` (full control of private repositories)
- Expiration: 30 days is fine
- Copy the token and paste it when `git push` asks for your password

## 3. Enable GitHub Pages

After the first push lands:

1. Open your repo on GitHub → **Settings** → **Pages** (left sidebar)
2. Under **Source**, pick **Deploy from a branch**
3. Branch: `main`, Folder: **`/docs`**
4. Click **Save**

It takes ~30 seconds. Your dashboard will be at:

```
https://yourusername.github.io/flutter-android-build/
```

## 4. Trigger the first build

Either:

- Push any commit: `git commit --allow-empty -m "trigger first build" && git push`
- Or: open the **Actions** tab → *Build Flutter Android APK* → **Run workflow**

Watch the Actions run finish (~3-5 minutes for the first one, faster on subsequent builds thanks to caching). The dashboard will populate as soon as the run completes and the workflow commits `docs/latest.json` + `docs/history.json` back to `main`.

## 5. Day-to-day workflow

From now on, the loop is just:

```bash
# Edit anything under app/
cd /root/flutter-android-build
git add .
git commit -m "feat: your change"
git push                       # → GitHub Actions builds the APK
                               # → Dashboard updates within seconds
                               # → APKs available under the Actions run page
```

To grab the latest APK:

- Click into the latest run from the dashboard, then **Artifacts** at the bottom of the run page.

## Troubleshooting

**`fatal: Authentication failed`** — Your token is wrong or expired. Generate a new one.

**Dashboard shows "No builds yet"** — Check that at least one Actions run has completed *successfully*. Failed runs still produce a status file, so this only appears if no run has ever finished.

**`Actions are not running`** — Go to Settings → Actions → General → **Allow all actions and reusable workflows** (it's the default for new repos but worth checking).

**Pages site is blank** — Hard-refresh (Ctrl+Shift+R / Cmd+Shift+R). Make sure `docs/.nojekyll` is in the repo (it's included in the initial commit).
