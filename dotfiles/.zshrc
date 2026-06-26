# ~/.zshrc — interactive zsh configuration.
#
# This file is sourced for interactive shells only.
# Cross-platform defaults are tuned for low latency.

# ─── Powerlevel10k instant prompt ─────────────────────────────────────────────
# Keep this near the top for lower first-prompt and first-command latency.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ─── mise runtime activation ──────────────────────────────────────────────────
if [[ -x "$HOME/.local/bin/mise" ]]; then
    eval "$("$HOME/.local/bin/mise" activate zsh)"
fi

# ─── SDKMAN activation ────────────────────────────────────────────────────────
# sdkman-init.sh is not nounset-safe in all versions; source it defensively.
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    sdkman_restore_nounset=0
    if [[ -o nounset ]]; then
        sdkman_restore_nounset=1
        set +u
    fi
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    if [[ "$sdkman_restore_nounset" == "1" ]]; then
        set -u
    fi

    # SDKMAN internals are not fully nounset-safe; wrap sdk calls defensively.
    if typeset -f sdk >/dev/null 2>&1; then
        functions -c sdk __sdkman_inner
        sdk() {
            emulate -L zsh
            set +u
            __sdkman_inner "$@"
        }
    fi
fi

# ─── Completion ───────────────────────────────────────────────────────────────
autoload -Uz compinit
zmodload zsh/complist
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-${ZSH_VERSION}"

# ─── History ──────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # no duplicate entries
setopt HIST_IGNORE_SPACE      # skip commands starting with a space
setopt SHARE_HISTORY          # share history across sessions
setopt HIST_FCNTL_LOCK        # faster and safer history writes

# ─── Navigation ───────────────────────────────────────────────────────────────
setopt AUTO_CD                # type a directory name to cd into it

# ─── Key bindings ─────────────────────────────────────────────────────────────
bindkey -e                    # emacs key bindings (change to -v for vi mode)

# ─── Aliases ──────────────────────────────────────────────────────────────────
# Source shared aliases if present.
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# Modern replacements (installed by system.sh)
if command -v eza &>/dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -lah --group-directories-first'
    alias lt='eza --tree --level=2'
fi
# bat is available as its own command — not aliased over cat because it adds
# decorations that interfere with piping and copy-pasting output.
# rg and fd are available as their own commands — not aliased over grep/find
# because they have different flags and aliasing breaks scripts that rely on
# standard grep/find behaviour.

# Editor shortcuts
alias vi='nvim'
alias vim='nvim'

# ─── fzf ──────────────────────────────────────────────────────────────────────
# Enable fzf key bindings and fuzzy completion if installed.
# Homebrew (macOS) installs fzf shell scripts under $(brew --prefix)/opt/fzf/shell/
# while Linux distros put them in /usr/share/doc/fzf/examples/.
if [[ "$OSTYPE" == "darwin"* ]]; then
    _fzf_prefix="$(brew --prefix 2>/dev/null)/opt/fzf/shell"
    [[ -f "$_fzf_prefix/key-bindings.zsh" ]] && source "$_fzf_prefix/key-bindings.zsh"
    [[ -f "$_fzf_prefix/completion.zsh" ]]   && source "$_fzf_prefix/completion.zsh"
    unset _fzf_prefix
else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]   && source /usr/share/doc/fzf/examples/completion.zsh
fi

# ─── Prompt + plugin profile ──────────────────────────────────────────────────
# Supported values:
#   antidote-p10k  (default, low-latency explicit setup)
#   zsh4humans
ZSH_PROFILE="${ZSH_PROFILE:-antidote-p10k}"

load_antidote_p10k() {
    local antidote_home="${ANTIDOTE_HOME:-$HOME/.local/share/antidote}"
    local zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins"
    local zsh_plugins_clean="${zsh_plugins}.clean.txt"
    local needs_rebuild=0

    if [[ -d "$antidote_home/functions" ]]; then
        fpath=("$antidote_home/functions" $fpath)
        autoload -Uz antidote

        if [[ -f "${zsh_plugins}.txt" ]]; then
            # Rebuild when spec changed, bundle missing, or bundle is poisoned by warning output.
            if [[ ! -f "${zsh_plugins}.zsh" ]] || [[ ! "${zsh_plugins}.zsh" -nt "${zsh_plugins}.txt" ]]; then
                needs_rebuild=1
            elif grep -Eq '^[[:space:]]*warning:' "${zsh_plugins}.zsh" 2>/dev/null; then
                needs_rebuild=1
            fi

            if [[ "$needs_rebuild" == "1" ]]; then
                # Antidote may emit warning lines when comments are present in spec.
                # Build from a comment-free spec and strip any stray warning output.
                grep -Ev '^[[:space:]]*(#|$)' "${zsh_plugins}.txt" >| "$zsh_plugins_clean"
                antidote bundle < "$zsh_plugins_clean" | grep -Ev '^[[:space:]]*warning:' >| "${zsh_plugins}.zsh"
                rm -f "$zsh_plugins_clean"
            fi
            source "${zsh_plugins}.zsh"
        fi
    fi

    if [[ -r "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
        source "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
    fi
    [[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
}

load_zsh4humans() {
    if [[ -r "$HOME/.local/share/zsh4humans/z4h.zsh" ]]; then
        source "$HOME/.local/share/zsh4humans/z4h.zsh"
    else
        load_antidote_p10k
    fi
}

case "$ZSH_PROFILE" in
    antidote|antidote-p10k)
        load_antidote_p10k
        ;;
    z4h|zsh4humans)
        load_zsh4humans
        ;;
    *)
        load_antidote_p10k
        ;;
esac

# ─── direnv ───────────────────────────────────────────────────────────────────
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# ─── tmux auto-attach (optional) ──────────────────────────────────────────────
# Keep disabled by default for predictable shell startup.
if [[ "${ZSH_TMUX_AUTO_ATTACH:-0}" == "1" ]] \
    && command -v tmux &>/dev/null \
    && [[ -z "$TMUX" ]] \
    && [[ "$TERM_PROGRAM" != "vscode" ]]; then
    tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi

# ─── Local overrides ──────────────────────────────────────────────────────────
# Machine-specific settings that should not be committed to version control.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
