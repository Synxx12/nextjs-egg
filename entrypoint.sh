#!/bin/bash

echo "[EGG] ── nyxel / Next.js Egg ─────────────────────────────────"

## ── Resolve APP_DIR (monorepo support) ───────────────────────────────────────
APP_DIR="${APP_DIR:-}"
CONTAINER_ROOT="/home/container"
WORK_DIR="${CONTAINER_ROOT}"

## ── Git section (skipped if GIT_URL is empty) ────────────────────────────────
if [ -n "${GIT_URL}" ]; then

  ## Inject auth into GIT_URL
  if [ -n "${USERNAME}" ] && [ -n "${ACCESS_TOKEN}" ]; then
    GIT_URL="https://${USERNAME}:${ACCESS_TOKEN}@$(echo "${GIT_URL}" | sed 's|https://||')"
  fi

  if [ ! -f "${CONTAINER_ROOT}/package.json" ] && [ ! -d "${CONTAINER_ROOT}/.git" ]; then
    echo "[EGG] No project found — wiping directory and cloning repository..."
    find "${CONTAINER_ROOT}" -mindepth 1 -not -path "${CONTAINER_ROOT}/.pterodactyl*" -delete 2>/dev/null || true

    ## Verify directory is clean enough for clone
    LEFTOVER=$(find "${CONTAINER_ROOT}" -mindepth 1 -not -path "${CONTAINER_ROOT}/.pterodactyl*" 2>/dev/null | wc -l)
    if [ "${LEFTOVER}" -gt 0 ]; then
      echo "[EGG] WARNING: Could not fully clean directory, trying clone to temp..."
      CLONE_TARGET="/tmp/repo_clone_$$"
      if [ -z "${GIT_BRANCH}" ]; then
        git clone "${GIT_URL}" "${CLONE_TARGET}" || { echo "[EGG] ERROR: Clone failed!"; exit 1; }
      else
        git clone --single-branch --branch "${GIT_BRANCH}" "${GIT_URL}" "${CLONE_TARGET}" || { echo "[EGG] ERROR: Clone failed!"; exit 1; }
      fi
      cp -a "${CLONE_TARGET}/." "${CONTAINER_ROOT}/"
      rm -rf "${CLONE_TARGET}"
    else
      if [ -z "${GIT_BRANCH}" ]; then
        git clone "${GIT_URL}" "${CONTAINER_ROOT}" || { echo "[EGG] ERROR: Clone failed!"; exit 1; }
      else
        git clone --single-branch --branch "${GIT_BRANCH}" "${GIT_URL}" "${CONTAINER_ROOT}" || { echo "[EGG] ERROR: Clone failed!"; exit 1; }
      fi
    fi

    echo "[EGG] Repository cloned successfully."

  elif [ -d "${CONTAINER_ROOT}/.git" ]; then
    if [ "${AUTO_UPDATE}" = "1" ]; then
      echo "[EGG] AUTO_UPDATE enabled — pulling latest changes..."
      cd "${CONTAINER_ROOT}"
      git reset --hard
      git fetch origin
      if [ -n "${GIT_BRANCH}" ]; then
        git checkout "${GIT_BRANCH}" 2>/dev/null || true
        git pull origin "${GIT_BRANCH}" || { echo "[EGG] ERROR: Git pull failed!"; exit 1; }
      else
        git pull || { echo "[EGG] ERROR: Git pull failed!"; exit 1; }
      fi
    else
      echo "[EGG] AUTO_UPDATE disabled — skipping pull."
    fi
  else
    echo "[EGG] Not a git repo — skipping pull."
  fi

else
  echo "[EGG] GIT_URL is empty — skipping clone/pull."
  if [ ! -f "${CONTAINER_ROOT}/package.json" ]; then
    echo "[EGG] ERROR: No package.json found and GIT_URL is empty."
    echo "[EGG] Please upload your project files via File Manager or set GIT_URL."
    exit 1
  fi
  echo "[EGG] package.json found — using existing files."
fi

## ── Resolve working directory (monorepo APP_DIR) ─────────────────────────────
if [ -n "${APP_DIR}" ]; then
  WORK_DIR="${CONTAINER_ROOT}/${APP_DIR}"
  if [ ! -d "${WORK_DIR}" ]; then
    echo "[EGG] ERROR: APP_DIR '${APP_DIR}' does not exist in container!"
    exit 1
  fi
  echo "[EGG] Monorepo mode — working directory: ${WORK_DIR}"
fi

cd "${WORK_DIR}"

## ── Verify package.json exists before proceeding ─────────────────────────────
if [ ! -f "${WORK_DIR}/package.json" ]; then
  echo "[EGG] ERROR: package.json not found in ${WORK_DIR}!"
  echo "[EGG] Check your GIT_URL or APP_DIR setting."
  exit 1
fi

## ── Copy .env if uploaded via panel ──────────────────────────────────────────
if [ -f "${CONTAINER_ROOT}/.env.pterodactyl" ]; then
  cp "${CONTAINER_ROOT}/.env.pterodactyl" "${WORK_DIR}/.env"
  echo "[EGG] .env.pterodactyl copied to .env"
fi

## ── Detect or use specified package manager ──────────────────────────────────
PM="${PACKAGE_MANAGER:-auto}"
if [ "${PM}" = "auto" ]; then
  if [ -f "${WORK_DIR}/pnpm-lock.yaml" ]; then
    PM="pnpm"
  elif [ -f "${WORK_DIR}/yarn.lock" ]; then
    PM="yarn"
  else
    PM="npm"
  fi
  echo "[EGG] Auto-detected package manager: ${PM}"
else
  echo "[EGG] Using package manager: ${PM}"
fi

## ── Install package manager if needed ────────────────────────────────────────
if [ "${PM}" = "pnpm" ]; then
  if ! command -v pnpm &>/dev/null; then
    echo "[EGG] Installing pnpm..."
    npm install -g pnpm --quiet
  fi
elif [ "${PM}" = "yarn" ]; then
  if ! command -v yarn &>/dev/null; then
    echo "[EGG] Installing yarn..."
    npm install -g yarn --quiet
  fi
fi

## ── Install dependencies ─────────────────────────────────────────────────────
SHOULD_INSTALL=1
if [ "${AUTO_UPDATE}" != "1" ] && [ -d "${WORK_DIR}/node_modules" ]; then
  echo "[EGG] node_modules exists and AUTO_UPDATE is disabled — skipping install."
  SHOULD_INSTALL=0
fi

if [ "${SHOULD_INSTALL}" = "1" ]; then
  echo "[EGG] Installing dependencies with ${PM}..."
  if [ "${PM}" = "pnpm" ]; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  elif [ "${PM}" = "yarn" ]; then
    yarn install --frozen-lockfile 2>/dev/null || yarn install
  else
    if [ -f "${WORK_DIR}/package-lock.json" ]; then
      npm ci
    else
      npm install
    fi
  fi

  if [ $? -ne 0 ]; then
    echo "[EGG] ERROR: Dependency installation failed!"
    exit 1
  fi
fi

## ── Install cloudflared (persistent, pinned version) ─────────────────────────
CF_DIR="${CONTAINER_ROOT}/.pterodactyl"
CF_BIN="${CF_DIR}/cloudflared"
CF_VERSION="2026.3.0"

if [ -n "${CLOUDFLARE_TOKEN}" ]; then
  mkdir -p "${CF_DIR}"

  if [ ! -f "${CF_BIN}" ]; then
    echo "[EGG] cloudflared not found — installing v${CF_VERSION}..."
    ARCH=$(uname -m)
    case "${ARCH}" in
      x86_64)  CF_ARCH="amd64" ;;
      aarch64) CF_ARCH="arm64" ;;
      armv7l)  CF_ARCH="arm" ;;
      *)       CF_ARCH="amd64" ;;
    esac

    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${CF_VERSION}/cloudflared-linux-${CF_ARCH}" \
      -o "${CF_BIN}" || { echo "[EGG] ERROR: Failed to download cloudflared!"; exit 1; }
    chmod +x "${CF_BIN}"
    echo "[EGG] cloudflared v${CF_VERSION} installed."
  else
    echo "[EGG] cloudflared already present — skipping download."
  fi
fi

## ── NODE_OPTIONS (memory limit, etc.) ────────────────────────────────────────
if [ -n "${NODE_OPTIONS}" ]; then
  export NODE_OPTIONS="${NODE_OPTIONS}"
  echo "[EGG] NODE_OPTIONS: ${NODE_OPTIONS}"
fi

## ── Build ────────────────────────────────────────────────────────────────────
export NODE_ENV="${NODE_RUN_ENV:-production}"

if [ "${NODE_RUN_ENV}" = "production" ]; then

  ## SKIP_BUILD: skip rebuild if .next already exists
  if [ "${SKIP_BUILD}" = "1" ] && [ -d "${WORK_DIR}/.next" ]; then
    echo "[EGG] SKIP_BUILD=1 and .next exists — skipping build."
  else
    ## Use custom BUILD_COMMAND if set, otherwise use package manager script
    if [ -n "${BUILD_COMMAND}" ]; then
      echo "[EGG] Running custom build command: ${BUILD_COMMAND}"
      eval "${BUILD_COMMAND}"
    else
      echo "[EGG] Building for production..."
      if [ "${PM}" = "pnpm" ]; then
        pnpm run build
      elif [ "${PM}" = "yarn" ]; then
        yarn build
      else
        npm run build
      fi
    fi

    if [ $? -ne 0 ]; then
      echo "[EGG] ERROR: Build failed! Check logs above."
      exit 1
    fi
    echo "[EGG] Build complete."
  fi

  echo "[EGG] Starting production server on port ${SERVER_PORT}..."

else
  echo "[EGG] Starting dev server on port ${SERVER_PORT}..."
fi

## ── Start Cloudflare Tunnel in background ────────────────────────────────────
if [ -n "${CLOUDFLARE_TOKEN}" ] && [ -f "${CF_BIN}" ]; then
  echo "[EGG] Starting Cloudflare Tunnel..."
  "${CF_BIN}" tunnel --no-autoupdate run --token "${CLOUDFLARE_TOKEN}" &
  CF_PID=$!
  sleep 3
  if kill -0 "${CF_PID}" 2>/dev/null; then
    echo "[EGG] Cloudflare Tunnel started (PID: ${CF_PID})"
  else
    echo "[EGG] WARNING: Cloudflare Tunnel failed to start — check your token!"
  fi
fi

## ── Cleanup trap ─────────────────────────────────────────────────────────────
cleanup() {
  [ -n "${CF_PID}" ] && kill "${CF_PID}" 2>/dev/null
  exit 0
}
trap cleanup EXIT INT TERM

## ── Start Next.js (foreground) ───────────────────────────────────────────────
if [ "${NODE_RUN_ENV}" = "production" ]; then
  npx next start -p "${SERVER_PORT:-3000}"
else
  npx next dev -p "${SERVER_PORT:-3000}"
fi