# 🥚 Pterodactyl Egg — Next.js

A production-ready Pterodactyl egg for hosting **Next.js** applications directly from a Git repository. Supports both `production` and `development` modes, private repositories, auto-update on startup, `.env` injection, monorepo support, Cloudflare Tunnel, and configurable package manager.

---

## ✨ Features

- **Production & Development modes** — runs `next build + next start` for production, or `next dev` for hot-reload development
- **Auto-update on startup** — optionally pull the latest commits every time the server starts
- **Private repository support** — authenticate with a GitHub/GitLab personal access token
- **`.env` injection** — upload a `.env.pterodactyl` file via the panel and it gets copied automatically as `.env` on startup
- **Smart dependency install** — auto-detects lockfile and uses `npm ci`, `pnpm install --frozen-lockfile`, or `yarn install --frozen-lockfile` for deterministic installs
- **Multi package manager** — supports `npm`, `pnpm`, and `yarn` with auto-detection
- **Multi-version Node.js** — choose between Node.js 18, 20, 22, 23, or 24
- **Monorepo support** — set `APP_DIR` to point to a subdirectory (e.g. `apps/web`)
- **Skip build** — skip rebuild if `.next` already exists for faster restarts
- **Custom build command** — override the default build with any command (e.g. `turbo build`)
- **Cloudflare Tunnel** — optional built-in tunnel support via Zero Trust token
- **Memory control** — configure `NODE_OPTIONS` to prevent OOM crashes on limited-RAM servers

---

## 📦 Supported Docker Images

| Image                            | Tag                                 |
| -------------------------------- | ----------------------------------- |
| Node.js 24                       | `ghcr.io/parkervcp/yolks:nodejs_24` |
| Node.js 23                       | `ghcr.io/parkervcp/yolks:nodejs_23` |
| Node.js 22 LTS ✓ **Recommended** | `ghcr.io/parkervcp/yolks:nodejs_22` |
| Node.js 20 LTS                   | `ghcr.io/parkervcp/yolks:nodejs_20` |
| Node.js 18 LTS                   | `ghcr.io/parkervcp/yolks:nodejs_18` |

---

## 🚀 Installation

1. In your Pterodactyl Admin Panel, go to **Nests** → **Import Egg**
2. Upload the `next-js-egg.json` file
3. Assign the egg to a nest of your choice
4. Create a new server using this egg and fill in the variables below

---

## ⚙️ Variables

| Variable                | Env Key            | Default                    | Description                                                                                 |
| ----------------------- | ------------------ | -------------------------- | ------------------------------------------------------------------------------------------- |
| Git Repository URL      | `GIT_URL`          | _(empty)_                  | Full HTTPS URL of your repo. Leave empty to upload files manually via File Manager          |
| Git Branch              | `GIT_BRANCH`       | `main`                     | Branch to clone and run. Leave empty for the repo's default branch                          |
| Auto Update             | `AUTO_UPDATE`      | `1`                        | Set to `1` to pull latest commits on every startup, `0` to disable                          |
| Git Username            | `USERNAME`         | _(empty)_                  | Your GitHub/GitLab username — only needed for private repos                                 |
| Git Access Token        | `ACCESS_TOKEN`     | _(empty)_                  | Personal access token with `repo` scope — only needed for private repos _(hidden in panel)_ |
| Run Environment         | `NODE_RUN_ENV`     | `production`               | `production` for optimized build, `development` for hot-reload dev mode                     |
| Package Manager         | `PACKAGE_MANAGER`  | `auto`                     | `auto` detects from lockfile, or set explicitly: `npm`, `pnpm`, `yarn`                      |
| Build Command           | `BUILD_COMMAND`    | _(empty)_                  | Custom build command override (e.g. `turbo build`). Leave empty to use default              |
| Skip Build              | `SKIP_BUILD`       | `0`                        | Set to `1` to skip rebuild if `.next` already exists. Useful for quick restarts             |
| App Directory           | `APP_DIR`          | _(empty)_                  | Relative path to your Next.js app for monorepos (e.g. `apps/web`). Leave empty for root     |
| Node Options            | `NODE_OPTIONS`     | `--max-old-space-size=512` | Node.js runtime flags. Adjust memory limit based on your server RAM                         |
| **Public Domain**       | `PUBLIC_DOMAIN`    | _(empty)_                  | Your public domain (e.g. `https://www.example.com`). Auto-injects `NEXTAUTH_URL` and `NEXT_PUBLIC_BASE_URL` into `.env` to prevent localhost redirect issues |
| Cloudflare Tunnel Token | `CLOUDFLARE_TOKEN` | _(empty)_                  | Zero Trust tunnel token. Leave empty to disable _(hidden in panel)_                         |

---

## 🔒 Private Repository Setup

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens) and create a **Personal Access Token (classic)** with the `repo` scope
2. Set `USERNAME` to your GitHub username
3. Set `ACCESS_TOKEN` to the token you generated
4. Set `GIT_URL` to your repo URL **without** credentials in the URL — the egg handles injection automatically

> `ACCESS_TOKEN` is marked as hidden in the panel (`user_viewable: false`) so it won't be visible to server users.

---

## 📄 .env File Injection

If your application requires environment variables, you can inject them without exposing secrets in the panel variables:

1. Create your `.env` file locally with all required keys
2. Rename it to `.env.pterodactyl`
3. Upload it to `/home/container/` via the panel's **File Manager**
4. Restart the server — the egg will automatically copy it to `.env` before the app starts

---

## 📦 Monorepo Support

If your repository is a monorepo (e.g. Turborepo, Nx), set `APP_DIR` to the relative path of your Next.js app:

```
APP_DIR = apps/web
```

All operations — dependency install, build, and server start — will run from that subdirectory. The repo is still cloned to `/home/container/` root.

---

## ☁️ Cloudflare Tunnel

If you want to expose your app via Cloudflare Zero Trust without opening a public port:

1. Go to your [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com) → **Networks** → **Tunnels**
2. Create a tunnel and copy the **Run token**
3. Paste it into the `CLOUDFLARE_TOKEN` variable

The egg will automatically download `cloudflared` on first start and run the tunnel in the background alongside your app.

> **Important:** When using Cloudflare Tunnel, you **must** set `PUBLIC_DOMAIN` to your public URL (e.g. `https://www.example.com`). Without this, your app will think it's running on `localhost` and authentication redirects (login, logout, OAuth) will break.

---

## 🌐 Public Domain & Localhost Redirect Fix

When running behind Cloudflare Tunnel or any reverse proxy, Next.js doesn't know your public URL — it only sees `localhost:PORT`. This causes:
- Login/logout redirecting to `http://localhost:3000/auth` instead of your domain
- NextAuth OAuth callbacks failing
- Open Graph meta tags pointing to localhost

**The fix:** Set `PUBLIC_DOMAIN` in your server's Startup variables:

```
PUBLIC_DOMAIN = https://www.example.com
```

The egg will automatically inject these into your `.env` file on every startup:
```
NEXTAUTH_URL=https://www.example.com
NEXT_PUBLIC_BASE_URL=https://www.example.com
```

> If you already have these values in your `.env` or `.env.pterodactyl`, they will be **overwritten** by `PUBLIC_DOMAIN` to ensure consistency.

---

## 🛠️ How It Works

**On first start (empty container):**

```
Clone repo → Copy .env → Install deps → build (if production) → start
```

**On subsequent starts with `AUTO_UPDATE=1`:**

```
git reset --hard → git pull → Copy .env → Install deps → build → start
```

**On subsequent starts with `AUTO_UPDATE=0`:**

```
Copy .env → (skip install if node_modules exists) → build → start
```

**With `SKIP_BUILD=1` and `.next` exists:**

```
Copy .env → (skip install) → skip build → start
```

---

## 📋 Requirements

- Pterodactyl Panel **v1.x** or **Pelican Panel**
- A Next.js app with a valid `package.json` and `next` as a dependency
- Your app **must not hardcode a port** — the egg passes `SERVER_PORT` from the panel at runtime via `next start -p $SERVER_PORT`

---

## 🐛 Troubleshooting

**Server stays at "Starting..." forever**
Make sure your Next.js app outputs one of these strings on ready: `ready on`, `started server on`, `Local: http://`, `Compiled successfully`, or `▲ Next.js`. Custom server wrappers that suppress stdout may prevent detection.

**Build fails in production mode**
Check that all required environment variables are present in `.env.pterodactyl`. Missing env vars required at build time will cause `next build` to fail. The egg will exit with a clear `[EGG] ERROR: Build failed!` message in the console.

**Out of memory during build**
Increase `NODE_OPTIONS` to `--max-old-space-size=1024` or higher depending on your server RAM. Default is `512`.

**Private repo cloning fails**
Ensure your access token has the `repo` scope and has not expired. Make sure `GIT_URL` is the plain HTTPS URL with no credentials embedded.

**`npm ci` fails**
This happens when `package-lock.json` is out of sync with `package.json`. Commit an up-to-date lockfile or delete it so the egg falls back to `npm install`.

**`pnpm` or `yarn` not found**
The egg installs `pnpm`/`yarn` automatically at runtime if not present. If it fails, check that the container has internet access.

**Cloudflare Tunnel not connecting**
Check that your token is correct and hasn't been revoked. The egg prints a warning if `cloudflared` fails to start — check the console for `[EGG] WARNING: Cloudflare Tunnel failed to start`.

**Redirected to localhost after login/logout**
This happens when Next.js doesn't know your public URL (common behind Cloudflare Tunnel or reverse proxies). Set `PUBLIC_DOMAIN` to your full public URL (e.g. `https://www.example.com`) in the Startup variables. The egg will auto-inject `NEXTAUTH_URL` and `NEXT_PUBLIC_BASE_URL` into your `.env` on startup.

**Monorepo: APP_DIR not found**
Make sure the path in `APP_DIR` matches the actual directory structure in your repo (case-sensitive). The egg will exit with an error if the directory doesn't exist after cloning.

---

## 📝 License

MIT — free to use, modify, and redistribute.

---

Made with ☕ by **nyxel**
