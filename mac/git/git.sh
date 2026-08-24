#!/usr/bin/env bash
# GitHub SSH key setup -- works on macOS and Linux.
#
# Generates an ed25519 SSH key, loads it into the agent, copies the public key
# to the clipboard (pbcopy on macOS), and tests the GitHub connection.
#
# ── This step is optional ────────────────────────────────────────────────────
# Skip it with --skip-git when running headlessly (CI, first-time bootstrap
# without browser access).  Run it manually later:
#   bash git/git.sh
#
# If SSH auth already works (key already added to GitHub), this script exits
# early after a quick connection test.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../utils/utils.sh
source "$SCRIPT_DIR/../utils/utils.sh"

github_ssh_auth_works() {
    local ssh_output
    set +e
    if command_exists timeout; then
        ssh_output="$(timeout 15 ssh -T git@github.com -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new 2>&1)"
    else
        ssh_output="$(ssh -T git@github.com -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new 2>&1)"
    fi
    set -e

    if echo "$ssh_output" | grep -q "successfully authenticated"; then
        return 0
    fi
    return 1
}

setup_ssh_key() {
    echo_header "SSH key"
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    if [[ -f ~/.ssh/id_ed25519 ]]; then
        log_warn "SSH key already exists at ~/.ssh/id_ed25519"
        chmod 600 ~/.ssh/id_ed25519
        [[ -f ~/.ssh/id_ed25519.pub ]] && chmod 644 ~/.ssh/id_ed25519.pub
    else
        local local_email
        local_email="$(git config --global user.email 2>/dev/null || echo "")"
        if [[ -z "$local_email" ]]; then
            log_warn "No git email configured. Run the configure step first."
            local_email="user@example.com"
        fi
        log_info "Generating ed25519 SSH key (comment: $local_email)..."
        ssh-keygen -t ed25519 -C "$local_email" -f ~/.ssh/id_ed25519 -N ""
        chmod 600 ~/.ssh/id_ed25519
        chmod 644 ~/.ssh/id_ed25519.pub
    fi
}

load_ssh_agent() {
    echo_header "SSH agent"
    local key_loaded=false

    if [[ -n "${SSH_AGENT_PID:-}" ]] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        if ssh-add -l 2>/dev/null | grep -q "id_ed25519"; then
            log_success "Key already loaded in SSH agent."
            key_loaded=true
        fi
    fi

    if [[ "$key_loaded" == "false" ]]; then
        if [[ -z "${SSH_AGENT_PID:-}" ]] || ! kill -0 "${SSH_AGENT_PID:-0}" 2>/dev/null; then
            eval "$(ssh-agent -s)"
        fi
        ssh-add ~/.ssh/id_ed25519
    fi
}

add_key_to_github() {
    echo_header "Add key to GitHub"

    if [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
        log_warn "No public key at ~/.ssh/id_ed25519.pub; nothing to upload."
        return 0
    fi

    # Trust github.com's host key up front so the connection test below cannot
    # stall on an interactive fingerprint prompt.
    if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
        touch ~/.ssh/known_hosts
        chmod 644 ~/.ssh/known_hosts
        ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null || true
    fi

    if ! command_exists gh; then
        github_key_by_hand
        return 0
    fi

    # gh does the whole handshake: authenticate, then upload the key. This
    # replaces copying to the clipboard and visiting the settings page, and it
    # is also what makes `gh` usable at all -- the agent instructions lean on
    # it for issues, PRs and projects, and nothing else authenticates it.
    if ! gh auth status >/dev/null 2>&1; then
        log_info "Authenticating with GitHub (a browser window will open)..."
        if ! gh auth login --hostname github.com --git-protocol ssh; then
            log_warn "gh auth login did not complete."
            github_key_by_hand
            return 0
        fi
    else
        log_success "gh is already authenticated as $(gh api user --jq .login 2>/dev/null || echo '?')"
    fi

    # Idempotent: comparing the key body avoids a duplicate-title error on
    # re-runs, and gh rejects a key it already has anyway.
    local key_body
    key_body="$(awk '{print $2}' ~/.ssh/id_ed25519.pub)"
    if gh ssh-key list 2>/dev/null | grep -qF "$key_body"; then
        log_success "This key is already on your GitHub account."
    elif gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname -s) ($(date +%Y-%m-%d))" 2>/dev/null; then
        log_success "SSH key uploaded to GitHub."
    else
        log_warn "Could not upload the key with gh."
        github_key_by_hand
    fi
}

# Fallback for when gh is unavailable or the login did not finish.
github_key_by_hand() {
    if command_exists pbcopy; then
        pbcopy < ~/.ssh/id_ed25519.pub
        log_success "Public key copied to clipboard (pbcopy)."
    elif command_exists xclip; then
        xclip -selection clipboard < ~/.ssh/id_ed25519.pub
        log_success "Public key copied to clipboard (xclip)."
    else
        log_info "Public key, to paste into GitHub:"
        cat ~/.ssh/id_ed25519.pub
    fi

    log_info "Add it at: https://github.com/settings/keys"
    if command_exists open; then
        open "https://github.com/settings/keys" 2>/dev/null || true
    fi
    is_interactive && read -r -p "Press Enter once the key is added..."
}

test_github_connection() {
    echo_header "Testing SSH connection to GitHub"
    local ssh_out ssh_code

    set +e
    ssh_out="$(timeout 30 ssh -T git@github.com -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=yes 2>&1)"
    ssh_code=$?
    set -e

    if echo "$ssh_out" | grep -q "successfully authenticated"; then
        local username
        username="$(echo "$ssh_out" | grep "Hi " | cut -d' ' -f2 | cut -d'!' -f1)"
        log_success "Connected to GitHub as: $username"
    elif [[ $ssh_code -eq 124 ]]; then
        log_error "Connection timed out. Check network or firewall."
        exit 1
    else
        log_error "Authentication failed. Check that the key was added to GitHub correctly."
        log_info "SSH output: $ssh_out"
        exit 1
    fi
}

# Registering git-lfs is a separate act from installing it. Without this, the
# smudge/clean filters are absent and cloning an LFS repo gives you pointer
# files instead of content -- with no error to explain why.
configure_git_extras() {
    echo_header "Git integrations"

    if command_exists git-lfs; then
        if git config --get filter.lfs.clean >/dev/null 2>&1; then
            log_info "git-lfs filters already registered."
        elif git lfs install --skip-repo >/dev/null 2>&1; then
            log_success "git-lfs filters registered."
        else
            log_warn "Could not register git-lfs. Run: git lfs install"
        fi
    fi

    # gh defaults to https, which would have it clone over HTTPS on a machine
    # where this step just set up an SSH key. Keep the two agreeing.
    if command_exists gh && gh auth status >/dev/null 2>&1; then
        if [[ "$(gh config get git_protocol 2>/dev/null)" != "ssh" ]]; then
            gh config set git_protocol ssh
            log_success "gh will use SSH for git operations."
        fi
    fi
}

# An SSH key that is not in the agent has to be unlocked on every use, and on
# macOS it is forgotten at every reboot without UseKeychain. Manage a single
# block rather than the whole file, so anything else in there survives.
configure_ssh_client() {
    echo_header "SSH client"

    local config="$HOME/.ssh/config"
    local marker="# managed by machinist"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$config"
    chmod 600 "$config"

    if grep -qF "$marker" "$config" 2>/dev/null; then
        log_info "SSH client block already present."
        return 0
    fi

    local keychain_line=""
    [[ "$OSTYPE" == "darwin"* ]] && keychain_line="    UseKeychain yes"

    # Prepended, not appended: ssh takes the FIRST value it sees for each
    # keyword, so a block added at the end loses to anything already above it.
    local tmp
    tmp="$(mktemp)"
    {
        printf '%s\n' "$marker"
        printf 'Host *\n'
        printf '    AddKeysToAgent yes\n'
        [[ -n "$keychain_line" ]] && printf '%s\n' "$keychain_line"
        printf '    IdentityFile ~/.ssh/id_ed25519\n'
        printf '\n'
        cat "$config"
    } > "$tmp"
    mv "$tmp" "$config"
    chmod 600 "$config"

    log_success "SSH client configured (agent + ed25519 key)."
    if [[ "$(grep -c '^Host \*' "$config")" -gt 1 ]]; then
        log_warn "$config has more than one 'Host *' block."
        log_warn "  ssh uses the first value it finds for each keyword; the rest are dead."
    fi
}

main() {
    echo_header "Checking Git installation"
    if ! command_exists git; then
        log_error "Git is not installed. Run the system step first."
        exit 1
    fi
    log_success "Git is installed."

    configure_ssh_client
    setup_ssh_key
    load_ssh_agent

    if github_ssh_auth_works; then
        echo_header "GitHub SSH"
        log_success "GitHub SSH authentication is already working."
        return 0
    fi

    add_key_to_github
    test_github_connection

    echo_header "GitHub SSH setup complete"
    log_success "SSH key: ~/.ssh/id_ed25519"
    log_info "Clone repos with: git clone git@github.com:username/repo.git"

    configure_git_extras
}

main
