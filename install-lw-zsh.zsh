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

EOF

# ------------------------------------------------------------------------------
# Constants & Paths
# ------------------------------------------------------------------------------
LW_ZSH_DIR="$HOME/.lw-zsh"
ANTIDOTE_DIR="$LW_ZSH_DIR/antidote"
LW_LOCAL_PATH="$LW_ZSH_DIR/local"
ZSHRC="$HOME/.zshrc"
ZSH_PLUGINS_TXT="$LW_ZSH_DIR/zsh_plugins.txt"
BACKUP_TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Get absolute path of the script directory
REPO_ROOT=${0:a:h}

# Source the terminal setup module
source "$REPO_ROOT/terminal-setup.zsh"

# ------------------------------------------------------------------------------
# 1. Pre-flight & Dependency Checks (Gum)
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
# 2. Welcome
# ------------------------------------------------------------------------------
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"Welcome to the" "Lunar Way Zsh Modernized Installer"

# ------------------------------------------------------------------------------
# A. Developer Tools (Brewfile)
# ------------------------------------------------------------------------------
gum style --foreground 99 "Developer Tools"
echo "We can install standard developer tools for you (Git, Docker, AWS CLI, Fonts, etc.)"
echo "This uses 'brew bundle' with the bundled Brewfile."

if gum confirm "Install developer tools?"; then
    if [[ -f "$REPO_ROOT/Brewfile" ]]; then
        gum spin --spinner dot --title "Installing tools via Homebrew..." -- \
            brew bundle --file="$REPO_ROOT/Brewfile"
        gum style --foreground 82 "✓ Developer tools installed"
    else
        gum style --foreground 196 "⚠ Brewfile not found in $REPO_ROOT"
    fi
else
    gum style --foreground 245 "Skipping developer tools installation."
fi

# ------------------------------------------------------------------------------
# B. Terminal Configuration
# ------------------------------------------------------------------------------
# Calls the function defined in terminal-setup.zsh
configure_terminal "$REPO_ROOT"

# ------------------------------------------------------------------------------
# 3. Git Access & Credentials
# ------------------------------------------------------------------------------
gum style --foreground 99 "Checking GitHub Access..."

SSH_KEY_PATH="$HOME/.ssh/github"
SSH_KEY_PUB="$SSH_KEY_PATH.pub"

if ssh -T -o ConnectTimeout=5 git@github.com 2>&1 | grep -q "successfully authenticated"; then
    gum style --foreground 82 "✓ GitHub SSH access confirmed"
else
    gum style --foreground 196 "✗ Unable to authenticate with GitHub via SSH."
    
    if gum confirm "Do you want to generate a new SSH key for GitHub?"; then
        # C. SSH Key Generation
        EMAIL=$(gum input --placeholder "Enter your Lunar email for the key (e.g. name@lunarway.com)")
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
        if command -v gh &> /dev/null; then
             gum style --foreground 99 "We can upload this key to GitHub automatically using the GitHub CLI (gh)."
             if gum confirm "Upload key to GitHub?"; then
                  if ! gh auth status &>/dev/null; then
                       gum style --foreground 208 "You need to login to GitHub first."
                       gh auth login
                  fi
                  
                  gum spin --spinner dot --title "Uploading key..." -- \
                       gh ssh-key add "$SSH_KEY_PUB" --title "Lunar-Workstation-$(date +%Y-%m-%d)" --type authentication
                  gum style --foreground 82 "✓ Key uploaded to GitHub"
             else
                  gum style --foreground 245 "Please upload '$SSH_KEY_PUB' to GitHub manually."
             fi
        else
             gum style --foreground 208 "'gh' CLI not found. Please install it or upload '$SSH_KEY_PUB' manually."
        fi

    else
        echo "Please ensure you have a valid SSH key added to your GitHub account."
        exit 1
    fi
fi

# Check for 'github.com-work' alias
if ! ssh -G github.com-work >/dev/null 2>&1; then
    gum style --foreground 208 "⚠ WARNING: 'github.com-work' SSH alias not found."
    echo "The default plugins list uses 'git@github.com-work:lunarway/lw-zsh'."
    if ! gum confirm "Continue anyway? (You may need to fix ~/.ssh/config later)"; then
        exit 1
    fi
fi

# Git Credentials
gum style --foreground 99 "Checking Git Configuration..."
CURRENT_NAME=$(git config --global user.name || echo "")
CURRENT_EMAIL=$(git config --global user.email || echo "")

if [[ -z "$CURRENT_NAME" ]]; then
    gum style --foreground 208 "Git user.name is not set."
    NEW_NAME=$(gum input --placeholder "Enter your full name for Git commits")
    if [[ -n "$NEW_NAME" ]]; then
        git config --global user.name "$NEW_NAME"
        gum style --foreground 82 "✓ Git user.name set to '$NEW_NAME'"
    fi
fi

if [[ -z "$CURRENT_EMAIL" ]]; then
    gum style --foreground 208 "Git user.email is not set."
    NEW_EMAIL=$(gum input --placeholder "Enter your email for Git commits")
    if [[ -n "$NEW_EMAIL" ]]; then
        git config --global user.email "$NEW_EMAIL"
        gum style --foreground 82 "✓ Git user.email set to '$NEW_EMAIL'"
    fi
fi

# D. Git SSH Signing
gum style --foreground 99 "Git SSH Signing"
SIGNING_KEY=$(git config --global user.signingkey || echo "")

if [[ -z "$SIGNING_KEY" ]]; then
    if gum confirm "Configure Git to sign commits with SSH?"; then
        # Use the key we just checked/generated
        # Defaulting to checking standard locations if we didn't just generate one
        KEY_TO_USE="$SSH_KEY_PUB"
        if [[ ! -f "$KEY_TO_USE" ]]; then
            # Try finding another public key
            KEY_TO_USE=$(find ~/.ssh -name "*.pub" | head -n 1)
        fi

        if [[ -f "$KEY_TO_USE" ]]; then
             git config --global gpg.format ssh
             git config --global user.signingkey "$KEY_TO_USE"
             git config --global commit.gpgsign true
             gum style --foreground 82 "✓ Git configured to sign commits with $KEY_TO_USE"
             
             # If we have gh, we should upload it as a signing key too if asked
             if command -v gh &> /dev/null && gum confirm "Upload this key as a Signing Key to GitHub?"; then
                  # Check if already uploaded? gh doesn't easily let us check by content, but adding duplicate might error gracefully or we just try.
                   gum spin --spinner dot --title "Uploading signing key..." -- \
                       gh ssh-key add "$KEY_TO_USE" --title "Lunar-Workstation-Signing-$(date +%Y-%m-%d)" --type signing
                   gum style --foreground 82 "✓ Signing key uploaded to GitHub"
             fi
        else
             gum style --foreground 196 "No SSH public key found to use for signing."
        fi
    fi
else
    gum style --foreground 82 "✓ Git signing already configured"
fi


# ------------------------------------------------------------------------------
# 4. Theme Selection
# ------------------------------------------------------------------------------
gum style --foreground 99 "Select your prompt theme:"
echo "Powerlevel10k is faster and native to Zsh."
echo "Starship is written in Rust and has easy TOML configuration."
THEME_CHOICE=$(gum choose \
    "Powerlevel10k (Recommended - Faster, Native Zsh)" \
    "Starship (Rust, TOML Configurable)")

# ------------------------------------------------------------------------------
# 5. Install Antidote & Prepare Directories
# ------------------------------------------------------------------------------
gum spin --spinner dot --title "Setting up directories..." -- sleep 1
mkdir -p "$LW_LOCAL_PATH"

if [[ ! -d "$ANTIDOTE_DIR" ]]; then
    gum spin --spinner dot --title "Installing Antidote..." -- \
        git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
else
    gum style --foreground 82 "✓ Antidote already installed"
fi

# ------------------------------------------------------------------------------
# 6. Setup Plugins File
# ------------------------------------------------------------------------------
gum spin --spinner dot --title "Configuring plugins..." -- sleep 1

if [[ -f "$REPO_ROOT/zsh_plugins.txt" ]]; then
    cp "$REPO_ROOT/zsh_plugins.txt" "$ZSH_PLUGINS_TXT"
else
    gum style --foreground 196 "Error: zsh_plugins.txt not found in $REPO_ROOT"
    exit 1
fi

# Adjust plugins based on theme
if [[ "$THEME_CHOICE" == *"Starship"* ]]; then
    # Remove powerlevel10k from plugins if Starship is chosen
    grep -v "romkatv/powerlevel10k" "$ZSH_PLUGINS_TXT" > "$ZSH_PLUGINS_TXT.tmp" && mv "$ZSH_PLUGINS_TXT.tmp" "$ZSH_PLUGINS_TXT"
    
    # Install Starship if needed
    if ! command -v starship &> /dev/null; then
        gum spin --spinner dot --title "Installing Starship..." -- brew install starship
    fi
fi

# Bundle plugins
# We source antidote to ensure the 'antidote' function is available for bundling
gum spin --spinner dot --title "Bundling plugins..." -- \
    zsh -c "source $ANTIDOTE_DIR/antidote.zsh; antidote bundle < $ZSH_PLUGINS_TXT > $LW_ZSH_DIR/zsh_plugins.zsh"

# ------------------------------------------------------------------------------
# 7. Configure .zshrc & Theme Configs
# ------------------------------------------------------------------------------
if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "$ZSHRC.backup.$BACKUP_TIMESTAMP"
    gum style --foreground 245 "Backed up existing .zshrc to $ZSHRC.backup.$BACKUP_TIMESTAMP"
fi

# Copy .zshrc.example
if [[ -f "$REPO_ROOT/.zshrc.example" ]]; then
    cp "$REPO_ROOT/.zshrc.example" "$ZSHRC"
else
    gum style --foreground 196 "Error: .zshrc.example not found"
    exit 1
fi

# Determine SED command based on OS (macOS requires empty string for backup extension)
SED_CMD="sed -i"
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_CMD="sed -i ''"
fi

# Customize .zshrc based on Theme
if [[ "$THEME_CHOICE" == *"Powerlevel10k"* ]]; then
    # Copy p10k config
    cp "$REPO_ROOT/default-appearance.zsh" "$LW_ZSH_DIR/p10k.zsh"
    
    # Update .zshrc to point to new p10k config location
    eval $SED_CMD "s|~/.zsh/.p10k.zsh|$LW_ZSH_DIR/p10k.zsh|g" "$ZSHRC"
    
    # Update Antidote load to point to our specific plugins file
    eval $SED_CMD "s|antidote load|antidote load $ZSH_PLUGINS_TXT|g" "$ZSHRC"

else
    # Starship selected
    # Comment out p10k specific blocks
    eval $SED_CMD '/p10k-instant-prompt/s/^/#/' "$ZSHRC"
    eval $SED_CMD '/source.*p10k-instant-prompt/s/^/#/' "$ZSHRC"
    eval $SED_CMD '/p10k configure/s/^/#/' "$ZSHRC"
    eval $SED_CMD '/\.p10k\.zsh/s/^/#/' "$ZSHRC"
    
    echo '\n# Starship Prompt' >> "$ZSHRC"
    echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
    
    # Configure Starship
    mkdir -p "$HOME/.config"
    cp "$REPO_ROOT/starship.toml" "$HOME/.config/starship.toml"
    
    # Update Antidote load path
    eval $SED_CMD "s|antidote load|antidote load $ZSH_PLUGINS_TXT|g" "$ZSHRC"
fi

# ------------------------------------------------------------------------------
# 8. Interactive Variable Setup
# ------------------------------------------------------------------------------
gum style --foreground 99 "Configuration"

EMAIL=$(gum input --placeholder "Enter your Lunar email (e.g. name@lunarway.com)")
if [[ -n "$EMAIL" ]]; then
    eval $SED_CMD "s|your-initials@lunarway.com|$EMAIL|g" "$ZSHRC"
fi

LW_PATH=$(gum input --placeholder "Path to Lunar repositories" --value "$HOME/lunar")
if [[ -n "$LW_PATH" ]]; then
     eval $SED_CMD "s|LW_PATH=~/lunar|LW_PATH=$LW_PATH|g" "$ZSHRC"
fi

GO_PATH=$(gum input --placeholder "Go path" --value "$HOME/go")
if [[ -n "$GO_PATH" ]]; then
     eval $SED_CMD "s|GOPATH=~/go|GOPATH=$GO_PATH|g" "$ZSHRC"
fi

# ------------------------------------------------------------------------------
# 9. Finalize
# ------------------------------------------------------------------------------
gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"Installation Complete!"

echo "1. Configuration: $ZSHRC"
echo "2. Plugins: $ZSH_PLUGINS_TXT"
if [[ "$THEME_CHOICE" == *"Starship"* ]]; then
    echo "3. Theme: Starship (~/.config/starship.toml)"
else
    echo "3. Theme: Powerlevel10k ($LW_ZSH_DIR/p10k.zsh)"
fi

echo "\nPlease restart your terminal or run 'exec zsh' to apply changes."
