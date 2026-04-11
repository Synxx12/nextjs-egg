#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║           nyxel / Next.js Egg  —  entrypoint.sh                 ║
# ║           https://github.com/Synxx12/nextjs-egg                 ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Helpers ──────────────────────────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

_step()  { echo -e "\n${BOLD}${CYAN}▶  $1${RESET}"; }
_ok()    { echo -e "   ${GREEN}✔  $1${RESET}"; }
_warn()  { echo -e "   ${YELLOW}⚠  $1${RESET}"; }
_err()   { echo -e "\n   ${RED}✖  $1${RESET}"; }
_info()  { echo -e "   ${DIM}→  $1${RESET}"; }
_sep()   { echo -e "${DIM}──────────────────────────────────────────────────${RESET}"; }

_banner() {
  echo -e ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║${RESET}  ${CYAN}${BOLD}nyxel / Next.js Egg${RESET}                             ${BOLD}║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
  echo -e ""
}

_die() {
  _err "$1"
  echo -e ""
  echo -e "   ${RED}${BOLD}Server startup aborted.${RESET}"
  echo -e "   ${DIM}Fix the issue above, then restart the server.${RESET}"
  echo -e ""
  exit 1
}

_banner

# ── Detect package manager ────────────────────────────────────────────────────

_step "Detecting package manager"

PM="${PACKAGE_MANAGER:-auto}"

if [ "${PM}" = "auto" ]; then
  if [ -f /home/container/pnpm-lock.yaml ]; then
    PM="pnpm"
  elif [ -f /home/container/yarn.lock ]; then
    PM="yarn"
  else
    PM="npm"
  fi
  _ok "Auto-detected: ${BOLD}${PM}${RESET}"
else
  _ok "Using: ${BOLD}${PM}${RESET}"
fi

# Install package manager globally if missing
if [ "${PM}" = "pnpm" ]; then
  if ! command -v pnpm &>/dev/null; then
    _info "pnpm not found — installing globally..."
    /usr/local/bin/npm install -g pnpm --silent \
      && _ok "pnpm installed" \
      || _die "Failed to install pnpm"
  fi
elif [ "${PM}" = "yarn" ]; then
  if ! command -v yarn &>/dev/null; then
    _info "yarn not found — installing globally..."
    /usr/local/bin/npm install -g yarn --silent \
      && _ok "yarn installed" \
      || _die "Failed to install yarn"
  fi
fi

# ── Git clone / pull ──────────────────────────────────────────────────────────

if [ -n "${GIT_URL}" ]; then
  _step "Git repository"

  # Inject auth into URL
  if [ -n "${USERNAME}" ] && [ -n "${ACCESS_TOKEN}" ]; then
    _info "Private repo — injecting credentials"
    GIT_URL="https://${USERNAME}:${ACCESS_TOKEN}@$(echo ${GIT_URL} | sed 's|https://||')"
  fi

  if [ ! -f /home/container/package.json ]; then
    _info "No project found — cloning repository..."
    rm -rf /home/container/* /home/container/.[!.]* 2>/dev/null || true

    if [ -z "${GIT_BRANCH}" ]; then
      git clone "${GIT_URL}" /home/container 2>&1 | tail -3 \
        || _die "Git clone failed. Check GIT_URL and credentials."
    else
      git clone --single-branch --branch "${GIT_BRANCH}" "${GIT_URL}" /home/container 2>&1 | tail -3 \
        || _die "Git clone failed. Check GIT_URL, GIT_BRANCH, and credentials."
    fi
    _ok "Repository cloned"

  else
    if [ -d /home/container/.git ]; then
      if [ "${AUTO_UPDATE}" = "1" ]; then
        _info "AUTO_UPDATE enabled — pulling latest changes..."
        cd /home/container
        git reset --hard HEAD 2>/dev/null
        git fetch origin 2>&1 | tail -2

        if [ -n "${GIT_BRANCH}" ]; then
          git checkout "${GIT_BRANCH}" 2>/dev/null
          git pull origin "${GIT_BRANCH}" 2>&1 | tail -2 \
            || _warn "git pull failed — continuing with existing code"
        else
          git pull 2>&1 | tail -2 \
            || _warn "git pull failed — continuing with existing code"
        fi
        _ok "Repository up to date"
      else
        _ok "AUTO_UPDATE disabled — using existing code"
      fi
    else
      _warn "Not a git repo — skipping pull"
    fi
  fi

else
  _step "Git repository"
  _info "GIT_URL is empty — using files from File Manager"
  if [ ! -f /home/container/package.json ]; then
    _die "No package.json found. Upload your project files via File Manager or set GIT_URL."
  fi
  _ok "Project files found"
fi

cd /home/container

# ── .env setup ───────────────────────────────────────────────────────────────

_step "Environment configuration"

if [ -f /home/container/.env.pterodactyl ]; then
  cp /home/container/.env.pterodactyl /home/container/.env
  _ok ".env.pterodactyl → .env (copied)"
elif [ -f /home/container/.env ]; then
  _ok ".env file found"
else
  _warn "No .env file found — make sure environment variables are set if needed"
fi

_info "NODE_ENV = ${NODE_RUN_ENV}"
_info "Port     = ${SERVER_PORT}"

# ── Install dependencies ──────────────────────────────────────────────────────

_step "Installing dependencies"

SHOULD_INSTALL=1
if [ "${AUTO_UPDATE}" != "1" ] && [ -d /home/container/node_modules ]; then
  _ok "node_modules exists and AUTO_UPDATE is off — skipping install"
  SHOULD_INSTALL=0
fi

if [ "${SHOULD_INSTALL}" = "1" ] && [ -f /home/container/package.json ]; then
  if [ "${PM}" = "pnpm" ]; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install \
      || _die "pnpm install failed"
  elif [ "${PM}" = "yarn" ]; then
    yarn install --frozen-lockfile 2>/dev/null || yarn install \
      || _die "yarn install failed"
  else
    if [ -f /home/container/package-lock.json ]; then
      /usr/local/bin/npm ci \
        || _die "npm ci failed. Try deleting node_modules and restarting."
    else
      /usr/local/bin/npm install \
        || _die "npm install failed"
    fi
  fi
  _ok "Dependencies installed"
fi

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────

CF_DIR="/home/container/.pterodactyl"
CF_BIN="${CF_DIR}/cloudflared"
CF_VERSION="2026.3.0"

if [ -n "${CLOUDFLARE_TOKEN}" ]; then
  _step "Cloudflare Tunnel"
  mkdir -p "${CF_DIR}"

  if [ ! -f "${CF_BIN}" ]; then
    _info "Downloading cloudflared v${CF_VERSION}..."
    ARCH=$(uname -m)
    [ "${ARCH}" = "aarch64" ] && CF_ARCH="arm64" || CF_ARCH="amd64"

    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${CF_VERSION}/cloudflared-linux-${CF_ARCH}" \
      -o "${CF_BIN}" || _die "Failed to download cloudflared"
    chmod +x "${CF_BIN}"
    _ok "cloudflared v${CF_VERSION} downloaded"
  else
    _ok "cloudflared already installed"
  fi
fi

# ── Build ─────────────────────────────────────────────────────────────────────

export NODE_ENV=${NODE_RUN_ENV}

if [ "${NODE_RUN_ENV}" = "production" ]; then
  _step "Building for production"

  # Check if we can skip build
  SKIP_BUILD="${SKIP_BUILD:-0}"
  BUILD_CACHE_VALID=0

  if [ "${SKIP_BUILD}" = "1" ]; then
    if [ -d /home/container/.next ] && [ -f /home/container/.next/BUILD_ID ]; then
      _ok "SKIP_BUILD=1 — using existing .next/ build"
      BUILD_CACHE_VALID=1
    else
      _warn "SKIP_BUILD=1 but no valid .next/ found — will build anyway"
    fi
  fi

  if [ "${BUILD_CACHE_VALID}" = "0" ]; then
    BUILD_CMD="${BUILD_COMMAND:-}"

    _sep

    if [ -n "${BUILD_CMD}" ]; then
      _info "Custom build command: ${BUILD_CMD}"
      eval "${BUILD_CMD}" || _die "Custom build command failed: ${BUILD_CMD}"
    else
      if [ "${PM}" = "pnpm" ]; then
        pnpm run build || _die "Build failed. Check the logs above for errors."
      elif [ "${PM}" = "yarn" ]; then
        yarn build || _die "Build failed. Check the logs above for errors."
      else
        /usr/local/bin/npm run build || _die "Build failed. Check the logs above for errors."
      fi
    fi

    _sep
    _ok "Build complete"
  fi
fi

# ── Start Cloudflare Tunnel in background ─────────────────────────────────────

if [ -n "${CLOUDFLARE_TOKEN}" ]; then
  _step "Starting Cloudflare Tunnel"
  "${CF_BIN}" tunnel --no-autoupdate run --token "${CLOUDFLARE_TOKEN}" &>/dev/null &
  CF_PID=$!
  sleep 2

  if kill -0 "${CF_PID}" 2>/dev/null; then
    _ok "Tunnel running (PID: ${CF_PID})"
  else
    _warn "Tunnel failed to start — check CLOUDFLARE_TOKEN"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo -e ""
_sep
echo -e "  ${BOLD}${GREEN}▶  Starting Next.js${RESET}"
_sep
echo -e "   ${DIM}Mode  : ${BOLD}${NODE_RUN_ENV}${RESET}"
echo -e "   ${DIM}Port  : ${BOLD}${SERVER_PORT}${RESET}"
echo -e "   ${DIM}PM    : ${BOLD}${PM}${RESET}"
[ -n "${CLOUDFLARE_TOKEN}" ] && echo -e "   ${DIM}Tunnel: ${BOLD}enabled${RESET}"
_sep
echo -e ""

# ── Start Next.js (foreground) ────────────────────────────────────────────────

if [ "${NODE_RUN_ENV}" = "production" ]; then
  exec /usr/local/bin/npx next start -p ${SERVER_PORT}
else
  exec /usr/local/bin/npx next dev -p ${SERVER_PORT}
fi