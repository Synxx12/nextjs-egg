#!/bin/bash

echo "[EGG] ── nyxel / Next.js Egg ─────────────────────────────────"

## ── Git section (skipped if GIT_URL is empty) ────────────────────────────────
if [ -n "${GIT_URL}" ]; then

    ## Inject auth into GIT_URL
    if [ -n "${USERNAME}" ] && [ -n "${ACCESS_TOKEN}" ]; then
        GIT_URL="https://${USERNAME}:${ACCESS_TOKEN}@$(echo ${GIT_URL} | sed 's|https://||')"
    fi

    if [ ! -f /home/container/package.json ]; then
        echo "[EGG] No package.json found — cloning repository..."
        rm -rf /home/container/* /home/container/.[!.]* 2>/dev/null || true
        if [ -z "${GIT_BRANCH}" ]; then
            git clone "${GIT_URL}" /home/container
        else
            git clone --single-branch --branch "${GIT_BRANCH}" "${GIT_URL}" /home/container
        fi
    else
        if [ -d /home/container/.git ]; then
            if [ "${AUTO_UPDATE}" = "1" ]; then
                echo "[EGG] AUTO_UPDATE enabled — pulling latest changes..."
                cd /home/container
                git reset --hard
                git fetch origin
                if [ -n "${GIT_BRANCH}" ]; then
                    git checkout "${GIT_BRANCH}"
                    git pull origin "${GIT_BRANCH}"
                else
                    git pull
                fi
            else
                echo "[EGG] AUTO_UPDATE disabled — skipping pull."
            fi
        else
            echo "[EGG] Not a git repo — skipping pull."
        fi
    fi

else
    echo "[EGG] GIT_URL is empty — skipping clone/pull."
    if [ ! -f /home/container/package.json ]; then
        echo "[EGG] ERROR: No package.json found and GIT_URL is empty."
        echo "[EGG] Please upload your project files via File Manager or set GIT_URL."
        exit 1
    fi
    echo "[EGG] package.json found — using existing files."
fi

cd /home/container

## Copy .env if uploaded via panel
if [ -f /home/container/.env.pterodactyl ]; then
    cp /home/container/.env.pterodactyl /home/container/.env
    echo "[EGG] .env.pterodactyl copied to .env"
fi

## ── Detect or use specified package manager ───────────────────────────────────
PM="${PACKAGE_MANAGER:-auto}"

if [ "${PM}" = "auto" ]; then
    if [ -f /home/container/pnpm-lock.yaml ]; then
        PM="pnpm"
    elif [ -f /home/container/yarn.lock ]; then
        PM="yarn"
    else
        PM="npm"
    fi
    echo "[EGG] Auto-detected package manager: ${PM}"
else
    echo "[EGG] Using package manager: ${PM}"
fi

## Install package manager if needed
if [ "${PM}" = "pnpm" ]; then
    if ! command -v pnpm &>/dev/null; then
        echo "[EGG] Installing pnpm..."
        /usr/local/bin/npm install -g pnpm
    fi
elif [ "${PM}" = "yarn" ]; then
    if ! command -v yarn &>/dev/null; then
        echo "[EGG] Installing yarn..."
        /usr/local/bin/npm install -g yarn
    fi
fi

## Install dependencies
if [ -f /home/container/package.json ]; then
    echo "[EGG] Installing dependencies with ${PM}..."
    if [ "${PM}" = "pnpm" ]; then
        pnpm install --frozen-lockfile 2>/dev/null || pnpm install
    elif [ "${PM}" = "yarn" ]; then
        yarn install --frozen-lockfile 2>/dev/null || yarn install
    else
        if [ -f /home/container/package-lock.json ]; then
            /usr/local/bin/npm ci
        else
            /usr/local/bin/npm install
        fi
    fi
fi

## ── Install cloudflared if token is set ──────────────────────────────────────
if [ -n "${CLOUDFLARE_TOKEN}" ]; then
    if ! command -v cloudflared &>/dev/null; then
        echo "[EGG] cloudflared not found — installing..."
        ARCH=$(uname -m)
        if [ "${ARCH}" = "x86_64" ]; then
            CF_ARCH="amd64"
        elif [ "${ARCH}" = "aarch64" ]; then
            CF_ARCH="arm64"
        else
            CF_ARCH="amd64"
        fi
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
            -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
        echo "[EGG] cloudflared installed successfully."
    else
        echo "[EGG] cloudflared already installed — skipping."
    fi
fi

## ── Build ────────────────────────────────────────────────────────────────────
export NODE_ENV=${NODE_RUN_ENV}

if [ "${NODE_RUN_ENV}" = "production" ]; then
    echo "[EGG] Building for production..."
    if [ "${PM}" = "pnpm" ]; then
        pnpm run build
    elif [ "${PM}" = "yarn" ]; then
        yarn build
    else
        /usr/local/bin/npm run build
    fi
    echo "[EGG] Starting on port ${SERVER_PORT}..."
else
    echo "[EGG] Starting dev server on port ${SERVER_PORT}..."
fi

## ── Start Cloudflare Tunnel in background if token is set ────────────────────
if [ -n "${CLOUDFLARE_TOKEN}" ]; then
    echo "[EGG] Starting Cloudflare Tunnel..."
    cloudflared tunnel --no-autoupdate run --token "${CLOUDFLARE_TOKEN}" &
    CF_PID=$!
    echo "[EGG] Cloudflare Tunnel started (PID: ${CF_PID})"
fi

## ── Start Next.js (foreground) ───────────────────────────────────────────────
if [ "${NODE_RUN_ENV}" = "production" ]; then
    exec /usr/local/bin/npx next start -p ${SERVER_PORT}
else
    exec /usr/local/bin/npx next dev -p ${SERVER_PORT}
fi
