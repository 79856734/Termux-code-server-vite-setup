#!/data/data/com.termux/files/usr/bin/bash

clear

set -o errexit
set -o pipefail
set -o nounset

# Colors (256-color orange + standard)
RESET="\e[0m"
BOLD="\e[1m"
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
ORANGE="\e[38;5;208m"   # orange-ish (256 color)

# Print helpers
info(){ echo -e "${CYAN}[i]${RESET} $*"; }
ok(){ echo -e "${GREEN}[✓]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[!]${RESET} $*"; }
err(){ echo -e "${RED}[✗]${RESET} $*"; }

prompt_yesno() {
  # prompt_yesno "Question?" -> returns 0 for yes, 1 for no
  local prompt="$1"
  local ans
  while true; do
    echo -n -e "${BOLD}${prompt}${RESET} ${CYAN}(y/n)${RESET}: "
    read -r ans
    ans="$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]' | xargs || true)"
    case "$ans" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) echo -e "${YELLOW}Please answer y or n.${RESET}" ;;
    esac
  done
}

echo -e "${BOLD}${CYAN}############################################################${RESET}"
echo -e "${BOLD}${CYAN}-  Mostafa_XS1's code-server, proot and vite setup script  -${RESET}"
echo -e "${BOLD}${CYAN}############################################################${RESET}"
echo

if prompt_yesno "This script will install code-server, proot-distro with either Ubuntu or Debian, npm with vite and some helper scripts.
${YELLOW}Install size may be 1GB or greater${RESET}
${GREEN}Would you like to install?"; then
  info "Running package updates and installs..."
  pkg update
  pkg i tur-repo -y
  pkg i code-server -y
  pkg i proot-distro -y
  pkg i net-tools -y
  pkg i jq -y
  pkg i git -y
  ok "pkg commands finished."
else
  err "${RED}Canceled.${RESET}"
  exit 0
fi


# Option: replace open-vsx with official VS Code marketplace
if prompt_yesno "Would you like to replace open-vsx with the official VS Code Marketplace (modify code-server's product.json)?"; then
  PRODUCT="/data/data/com.termux/files/usr/lib/code-server/lib/vscode/product.json"
  if [ ! -f "$PRODUCT" ]; then
    warn "product.json not found at $PRODUCT. Skipping replacement."
  else
    info "Backing up current product.json..."
    cp -a "$PRODUCT" "${PRODUCT}.bak.$(date +%s)" || true

    info "Updating product.json using jq..."
    jq '.extensionsGallery = {
      "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
      "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
      "itemUrl": "https://marketplace.visualstudio.com/items",
      "controlUrl": ""
    }' "$PRODUCT" > /tmp/product.json && mv /tmp/product.json "$PRODUCT"
    ok "product.json updated."
  fi
else
  info "Skipping VS Code marketplace replacement."
fi

# Ask which distro to install
DIST=""
while true; do
  echo -n -e "Do you want ${ORANGE}Ubuntu${RESET} or ${RED}Debian${RESET}? ${CYAN}(u/d)${RESET}: "
  read -r choice
  choice="$(printf "%s" "$choice" | tr '[:upper:]' '[:lower:]' | xargs || true)"
  case "$choice" in
    u|ubuntu) DIST="ubuntu"; break ;;
    d|debian) DIST="debian"; break ;;
    *) echo -e "${YELLOW}Please answer 'u' for Ubuntu or 'd' for Debian.${RESET}" ;;
  esac
done

if [ "$DIST" = "ubuntu" ]; then
  echo -e "${BOLD}You chose: ${ORANGE}${DIST^}${RESET}"
else
  echo -e "${BOLD}You chose: ${RED}${DIST^}${RESET}"
fi

# proot-distro alias support: prefer `pd` if available, otherwise use proot-distro
if command -v pd >/dev/null 2>&1; then
  PROOT_CMD="pd"
else
  PROOT_CMD="proot-distro"
fi

info "Installing ${DIST} via ${PROOT_CMD} (this can take a while)..."
# If already installed, proot-distro will indicate so.
$PROOT_CMD install "$DIST" || warn "proot-distro install returned non-zero exit code; continuing."

# Run initial root-level setup inside the distro (apt update/upgrade, add user)
info "Running initial setup inside ${DIST} (apt update/upgrade, adduser 'code')..."
$PROOT_CMD login "$DIST" -- bash -lc $'set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y
apt install -y sudo nano adduser
# create code user non-interactively if missing
if ! id -u code >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" code || true
fi
usermod -aG sudo code || true
# Ensure sudoers.d exists, then create a safe sudoers drop-in for passwordless sudo
mkdir -p /etc/sudoers.d
# write file atomically and set secure permissions
printf "%s\n" "code ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/code.tmp && \
mv /etc/sudoers.d/code.tmp /etc/sudoers.d/code && \
chmod 0440 /etc/sudoers.d/code || true
# finish up
mkdir -p /home/code/vite-projects
chown -R code:code /home/code/vite-projects
echo "[+] In-distro root setup complete."'

ok "In-distro root setup finished."

# Prepare code-scripts directory and download the appropriate scripts for the chosen distro
SCRIPTS_DIR="$HOME/code-scripts"
mkdir -p "$SCRIPTS_DIR"
info "Downloading helper scripts into $SCRIPTS_DIR ..."

if [ "$DIST" = "ubuntu" ]; then
  declare -A files=(
    ["vite.sh"]="https://pastebin.com/raw/nqSmrhhR"
    ["cdvite.sh"]="https://pastebin.com/raw/BvtbatUj"
    ["start-dev.sh"]="https://pastebin.com/raw/awf1F7uJ"
    ["show-local-ip.sh"]="https://pastebin.com/raw/yXQUpGkh"
    ["code-server-start.sh"]="https://pastebin.com/raw/aSiLFnX9"
  )
else
  declare -A files=(
    ["vite.sh"]="https://pastebin.com/raw/AT77nbh3"
    ["cdvite.sh"]="https://pastebin.com/raw/Eek9cfjF"
    ["start-dev.sh"]="https://pastebin.com/raw/pbDKy2ye"
    ["show-local-ip.sh"]="https://pastebin.com/raw/yXQUpGkh"
    ["code-server-start.sh"]="https://pastebin.com/raw/aSiLFnX9"
  )
fi

for name in "${!files[@]}"; do
  url="${files[$name]}"
  dest="$SCRIPTS_DIR/$name"
  info "Fetching $name from $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest" || { warn "Failed to download $url"; continue; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url" || { warn "Failed to download $url"; continue; }
  else
    warn "Neither curl nor wget found; cannot download $name."
    continue
  fi
  chmod +x "$dest" || true
  ok "Saved $dest"
done

# short snippet: symlink scripts (strip .sh) into ~/bin and ensure ~/bin is on PATH
SCRIPTS_DIR="${SCRIPTS_DIR:-$HOME/code-scripts}"; BIN="$HOME/bin"
mkdir -p "$BIN"
[ -d "$SCRIPTS_DIR" ] && for f in "$SCRIPTS_DIR"/*; do [ -f "$f" ] || continue; chmod +x "$f" || true; ln -sf "$f" "$BIN/$(basename "${f%.sh}")"; done
_add='export PATH="$HOME/bin:$PATH"'
for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
  touch "$rc"
  grep -qxF "$_add" "$rc" || printf '\n# ensure user bin in PATH\n%s\n' "$_add" >> "$rc"
done
# apply now (best-effort)
for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do [ -f "$rc" ] && . "$rc"; done

# After preparing everything, login as 'code' user, install node, and create a vite project
echo
info "Now will log into the distro as user ${BOLD}code${RESET}, install Node, and run 'npm create vite@latest'."
info "If npm create prompts, follow prompts to scaffold your project. After these commands you will be dropped into an interactive shell inside the distro."

# Run the node install + npm create as the 'code' user, then drop to interactive shell
# Use sudo (the 'code' user is a sudoer and passwordless)
$PROOT_CMD login "$DIST" --user code -- bash -lc $'set -euo pipefail
echo "[*] Updating apt and installing node/npm (via sudo)..."
sudo apt update
sudo apt install -y nodejs npm
mkdir -p ~/vite-projects
cd ~/vite-projects || exit 1
echo "[*] Running: npm create vite@latest — this may prompt interactively. If it does, follow the prompts."
rm -rf ~/.npm/_cacache && npm cache clean --force && npm install -g npm@latest && npm --cache /tmp/npm-cache create vite@latest
# Allow npm create to run; if it exits non-zero, continue to drop into shell.
npm create vite@latest || true
# Keep an interactive shell open for the user
exec bash -l'

# If the user exits the distro shell, the script will continue here
echo
ok "If you exited the distro, the script finished. If you are still inside the distro, you are in an interactive shell as 'code'."
echo -e "${BOLD}${CYAN}############################################################${RESET}"
echo -e "${BOLD}${CYAN}Installation and setup complete.${RESET}"
echo -e "${GREEN}* Scripts saved to:${RESET} $SCRIPTS_DIR"
echo -e "${GREEN}* Symlinks created in:${RESET} $HOME/bin (add to PATH if necessary)"
echo -e "${GREEN}* To re-enter distro interactively as user 'code':${RESET} ${YELLOW}$PROOT_CMD login $DIST --user code${RESET}"
echo -e "${BOLD}${CYAN}############################################################${RESET}"
