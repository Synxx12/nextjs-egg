# 🥚 Pterodactyl Egg — Next.js

A production-ready Pterodactyl egg for hosting **Next.js** applications directly from a Git repository. Supports both `production` and `development` modes, private repositories, auto-update on startup, and `.env` injection via the panel file manager.

---

## ✨ Features

- **Production & Development modes** — runs `next build + next start` for production, or `next dev` for hot-reload development
- **Auto-update on startup** — optionally pull the latest commits every time the server starts
- **Private repository support** — authenticate with a GitHub/GitLab personal access token
- **`.env` injection** — upload a `.env.pterodactyl` file via the panel and it gets copied automatically as `.env` on startup
- **Smart dependency install** — uses `npm ci` when `package-lock.json` exists for deterministic installs
- **Multi-version Node.js** — choose between Node.js 18, 20, 21, or 22

---

## 📦 Supported Docker Images

| Image | Tag |
|---|---|
| Node.js 22 *(recommended)* | `ghcr.io/parkervcp/yolks:nodejs_22` |
| Node.js 21 | `ghcr.io/parkervcp/yolks:nodejs_21` |
| Node.js 20 LTS | `ghcr.io/parkervcp/yolks:nodejs_20` |
| Node.js 18 LTS | `ghcr.io/parkervcp/yolks:nodejs_18` |

---

## 🚀 Installation

1. In your Pterodactyl Admin Panel, go to **Nests** → **Import Egg**
2. Upload the `nextjs-egg.json` file
3. Assign the egg to a nest of your choice
4. Create a new server using this egg and fill in the variables below

---

## ⚙️ Variables

| Variable | Env Key | Default | Description |
|---|---|---|---|
| Git Repository URL | `GIT_URL` | *(required)* | Full HTTPS URL of your repo, e.g. `https://github.com/user/repo` |
| Git Branch | `GIT_BRANCH` | `main` | Branch to clone and run. Leave empty for the repo's default branch |
| Auto Update | `AUTO_UPDATE` | `1` | Set to `1` to pull latest commits on every startup, `0` to disable |
| Git Username | `USERNAME` | *(empty)* | Your GitHub/GitLab username — only needed for private repos |
| Git Access Token | `ACCESS_TOKEN` | *(empty)* | Personal access token with `repo` scope — only needed for private repos |
| Run Environment | `NODE_RUN_ENV` | `production` | `production` for optimized build, `development` for hot-reload dev mode |

---

## 🔒 Private Repository Setup

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens) and create a **Personal Access Token (classic)** with the `repo` scope
2. Set `USERNAME` to your GitHub username
3. Set `ACCESS_TOKEN` to the token you generated
4. Set `GIT_URL` to your repo URL **without** credentials in the URL — the egg handles injection automatically

---

## 📄 .env File Injection

If your application requires environment variables, you can inject them without exposing secrets in the panel variables:

1. Create your `.env` file locally with all required keys
2. Rename it to `.env.pterodactyl`
3. Upload it to `/home/container/` via the panel's **File Manager**
4. Restart the server — the egg will automatically copy it to `.env` before the app starts

---

## 🛠️ How It Works

**On first start (empty container):**
```
Clone repo → Copy .env → npm ci / npm install → build (if production) → start
```

**On subsequent starts with AUTO_UPDATE=1:**
```
git reset --hard → git pull → Copy .env → npm ci / npm install → build → start
```

**On subsequent starts with AUTO_UPDATE=0:**
```
Copy .env → npm ci / npm install → build (if production) → start
```

---

## 📋 Requirements

- Pterodactyl Panel **v1.x** or **Pelican Panel**
- A Next.js app with a valid `package.json` and `next` as a dependency
- Your `next.config.js` should not hardcode a port — the egg injects `{{SERVER_PORT}}` at runtime

---

## 🐛 Troubleshooting

**Server stays at "Starting..." forever**
Make sure your Next.js app outputs one of these strings on ready: `ready on`, `started server on`, or `Compiled successfully`. Custom startup scripts that suppress stdout may prevent detection.

**Build fails in production mode**
Check that all required environment variables are present in `.env.pterodactyl`. Missing env vars that are required at build time will cause `next build` to fail.

**Private repo cloning fails**
Ensure your access token has the `repo` scope and has not expired. Also make sure `GIT_URL` is the plain HTTPS URL with no credentials embedded.

**`npm ci` fails**
This happens when `package-lock.json` is out of sync with `package.json`. Commit an up-to-date lockfile to your repo or delete it so the egg falls back to `npm install`.

---

## 📝 License

MIT — free to use, modify, and redistribute.

---

<div align="center">
  Made with ☕ by <strong>nyxel</strong>
</div>
