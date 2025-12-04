#!/usr/bin/env zsh

set -e

# ------------------------------------------------------------------------------
# ASCII Banner
# ------------------------------------------------------------------------------
cat << 'EOF'

██╗     ██╗    ██╗     ███████╗███████╗██╗  ██╗
██║     ██║    ██║     ╚══███╔╝██╔════╝██║  ██║
██║     ██║ █╗ ██║█████╗ ███╔╝ ███████╗███████║
██║     ██║███╗██║╚════╝███╔╝  ╚════██║██╔══██║
███████╗╚███╔███╔╝     ███████╗███████║██║  ██║
╚══════╝ ╚══╝╚══╝      ╚══════╝╚══════╝╚═╝  ╚═╝

        Modern Bootstrap Installer

EOF

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
LW_ZSH_DIR="$HOME/.lw-zsh"
LW_ZSH_REPO="git@github.com-work:lunarway/lw-zsh-modern.git"

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks
# ------------------------------------------------------------------------------
echo "Checking dependencies..."

if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. Please install Homebrew first."
    exit 1
fi

if ! command -v gum &> /dev/null; then
    echo "Installing gum via Homebrew..."
    brew install gum
fi

# ------------------------------------------------------------------------------
# 2. GitHub Access Check
# ------------------------------------------------------------------------------
gum style --foreground 99 "Checking GitHub Access..."

if ! ssh -T -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"; then
    gum style --foreground 196 "✗ Unable to authenticate with GitHub via SSH."
    echo "Please ensure you have a valid SSH key added to your GitHub account."
    echo "Run: ssh-add ~/.ssh/your-key"
    exit 1
fi
gum style --foreground 82 "✓ GitHub SSH access confirmed"

# Check for 'github.com-work' alias
if ! ssh -G github.com-work >/dev/null 2>&1; then
    gum style --foreground 196 "✗ 'github.com-work' SSH alias not found in ~/.ssh/config"
    echo ""
    echo "The installer needs this SSH alias to clone the private lw-zsh-modern repository."
    echo "Add the following to ~/.ssh/config:"
    echo ""
    echo "Host github.com-work"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile ~/.ssh/your-work-key"
    echo ""
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Clone/Update Private Repository
# ------------------------------------------------------------------------------
gum style --foreground 99 "Setting up lw-zsh-modern..."

if [[ -d "$LW_ZSH_DIR" ]]; then
    gum style --foreground 245 "Updating existing installation..."
    gum spin --spinner dot --title "Pulling latest changes..." -- \
        git -C "$LW_ZSH_DIR" pull --ff-only
else
    gum spin --spinner dot --title "Cloning lw-zsh-modern..." -- \
        git clone "$LW_ZSH_REPO" "$LW_ZSH_DIR"
fi

gum style --foreground 82 "✓ lw-zsh-modern ready at $LW_ZSH_DIR"

# ------------------------------------------------------------------------------
# 4. Hand off to Main Installer
# ------------------------------------------------------------------------------
MAIN_INSTALLER="$LW_ZSH_DIR/install-lw-zsh.zsh"

if [[ ! -f "$MAIN_INSTALLER" ]]; then
    gum style --foreground 196 "Error: Main installer not found at $MAIN_INSTALLER"
    exit 1
fi

gum style --foreground 99 "Launching main installer..."
echo ""

exec zsh "$MAIN_INSTALLER"
