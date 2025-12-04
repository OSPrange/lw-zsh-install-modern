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
# Sudo Authentication Notice & TouchID Setup
# ------------------------------------------------------------------------------
echo "This installer requires administrator privileges for some steps."
echo "You will need to enter your password multiple times during installation."
echo ""

PAM_SUDO_FILE="/etc/pam.d/sudo"
PAM_TID_LINE="auth       sufficient     pam_tid.so"

if ! grep -q "pam_tid.so" "$PAM_SUDO_FILE" 2>/dev/null; then
    echo "Would you like to enable TouchID for sudo authentication?"
    echo "This allows you to use your fingerprint instead of typing your password."
    echo ""
    read "ENABLE_TOUCHID?Enable TouchID for sudo? [y/N]: " </dev/tty
    
    if [[ "$ENABLE_TOUCHID" =~ ^[Yy]$ ]]; then
        echo "Enabling TouchID for sudo (requires your password once)..."
        sudo sed -i '' "2i\\
$PAM_TID_LINE
" "$PAM_SUDO_FILE"
        echo "✓ TouchID enabled for sudo"
        echo ""
    fi
else
    echo "✓ TouchID for sudo already enabled"
    echo ""
fi

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
LW_ZSH_DIR="$HOME/.lw-zsh"
LW_ZSH_REPO="git@github.com:lunarway/lw-zsh-modern.git"

# ------------------------------------------------------------------------------
# 1. Install Xcode Command Line Tools (if needed)
# ------------------------------------------------------------------------------
echo "Checking dependencies..."

if ! xcode-select -p &> /dev/null; then
    echo "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    
    echo "Waiting for Xcode Command Line Tools installation to complete..."
    echo "(Please follow the prompts in the popup window)"
    
    # Wait for installation to complete
    until xcode-select -p &> /dev/null; do
        sleep 5
    done
    echo "✓ Xcode Command Line Tools installed"
else
    echo "✓ Xcode Command Line Tools found"
fi

# ------------------------------------------------------------------------------
# 2. Install Homebrew (if needed)
# ------------------------------------------------------------------------------
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing..."
    # Run Homebrew installer with explicit TTY
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    
    # Add brew to PATH for this session (Apple Silicon vs Intel)
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew installation failed."
        exit 1
    fi
    echo "✓ Homebrew installed"
else
    echo "✓ Homebrew found"
fi

# ------------------------------------------------------------------------------
# 3. Install Essential Dependencies
# ------------------------------------------------------------------------------
echo "Installing essential tools..."

# gum - required for installer UI
if ! command -v gum &> /dev/null; then
    echo "Installing gum..."
    brew install gum
fi

# git - required for cloning
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    brew install git
fi

# gh - GitHub CLI for SSH key management
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    brew install gh
fi

echo "✓ Essential tools ready"

# ------------------------------------------------------------------------------
# 4. GitHub Access Check
# ------------------------------------------------------------------------------
gum style --foreground 99 "Checking GitHub Access..."

SSH_KEY_PATH="$HOME/.ssh/github"
SSH_KEY_PUB="$SSH_KEY_PATH.pub"

if ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 </dev/null | grep -q "successfully authenticated"; then
    gum style --foreground 82 "✓ GitHub SSH access confirmed"
else
    gum style --foreground 196 "✗ Unable to authenticate with GitHub via SSH."
    
    if gum confirm "Do you want to generate a new SSH key for GitHub?" </dev/tty; then
        EMAIL=$(gum input --placeholder "Enter your Lunar email for the key (e.g. name@lunarway.com)" </dev/tty)
        if [[ -z "$EMAIL" ]]; then
             echo "Email required for key generation."
             exit 1
        fi
        
        gum spin --spinner dot --title "Generating SSH Key..." -- \
            ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY_PATH" -N ""
        
        gum style --foreground 82 "✓ SSH Key generated at $SSH_KEY_PATH"

        # Add to ssh-agent
        eval "$(ssh-agent -s)"
        ssh-add "$SSH_KEY_PATH"
        
        # Configure ~/.ssh/config
        if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
             mkdir -p "$HOME/.ssh"
             echo "\nHost github.com\n  ForwardAgent yes\n  UseKeychain yes\n  IdentityFile $SSH_KEY_PATH\n" >> "$HOME/.ssh/config"
             gum style --foreground 82 "✓ Added github.com to ~/.ssh/config"
        fi

        # Upload to GitHub via gh
        gum style --foreground 99 "We can upload this key to GitHub automatically using the GitHub CLI (gh)."
        if gum confirm "Upload key to GitHub?" </dev/tty; then
             if ! gh auth status &>/dev/null; then
                  gum style --foreground 208 "You need to login to GitHub first."
                  gh auth login </dev/tty
             fi
             
             gum spin --spinner dot --title "Uploading key..." -- \
                  gh ssh-key add "$SSH_KEY_PUB" --title "Lunar-Workstation-$(date +%Y-%m-%d)" --type authentication
             gum style --foreground 82 "✓ Key uploaded to GitHub"
        else
             gum style --foreground 245 "Please upload '$SSH_KEY_PUB' to GitHub manually."
        fi
    else
        echo "Please ensure you have a valid SSH key added to your GitHub account."
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 5. Clone/Update Private Repository
# ------------------------------------------------------------------------------
gum style --foreground 99 "Setting up lw-zsh-modern..."

if [[ -d "$LW_ZSH_DIR" ]]; then
    gum style --foreground 245 "Updating existing installation..."
    gum spin --spinner dot --title "Pulling latest changes..." -- \
        git -C "$LW_ZSH_DIR" pull --ff-only </dev/null
else
    gum spin --spinner dot --title "Cloning lw-zsh-modern..." -- \
        git clone "$LW_ZSH_REPO" "$LW_ZSH_DIR" </dev/null
fi

gum style --foreground 82 "✓ lw-zsh-modern ready at $LW_ZSH_DIR"

# ------------------------------------------------------------------------------
# 6. Hand off to Main Installer
# ------------------------------------------------------------------------------
MAIN_INSTALLER="$LW_ZSH_DIR/install-lw-zsh.zsh"

if [[ ! -f "$MAIN_INSTALLER" ]]; then
    gum style --foreground 196 "Error: Main installer not found at $MAIN_INSTALLER"
    exit 1
fi

gum style --foreground 99 "Launching main installer..."
echo ""

exec zsh "$MAIN_INSTALLER"
