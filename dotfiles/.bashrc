# shellcheck shell=bash
# ~/.bashrc -- bash configuration, mirroring the zsh setup.
#
# zsh is the daily driver (see .zshrc). This file exists so that dropping into
# bash -- a script, a rescue shell, a remote box without zsh -- still gives you
# the same PATH, the same runtime versions, and the same muscle memory.
#
# KEEP IT LEAN. No plugin framework, no prompt framework. When you change
# something fundamental in .zshenv/.zprofile/.zshrc, mirror it here only if it
# is one of the basics below.

# ─── PATH ─────────────────────────────────────────────────────────────────────
# bash has no equivalent of zsh's `typeset -U path`, so de-duplicate by hand:
# drop any existing occurrence, then prepend. Without this, nested login shells
# (WezTerm spawns $SHELL -l, tmux spawns it again per pane) grow PATH forever.
path_prepend() {
    [[ -d "$1" ]] || return 0
    PATH="${PATH//":$1:"/:}"        # middle
    PATH="${PATH/#"$1:"/}"          # front
    PATH="${PATH/%":$1"/}"          # end
    export PATH="$1${PATH:+:$PATH}"
}

# ─── Cached shell integrations ────────────────────────────────────────────────
# Same idea as the _evalcache in .zshenv: brew, mise, fzf and direnv each print
# shell code that has to be eval'd, and each is a fork+exec on every start. The
# output only changes when the tool does, so cache it and re-source.
#
# bash has no zcompile, so this is a plain cached file.
# To force a rebuild:  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/bash/init
_evalcache() {
    local name="$1" gen="$2"
    shift 2                      # drop the cache name and the mtime reference
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/bash/init"
    local cache="$dir/${name}.bash"

    if [[ ! -s "$cache" || "$gen" -nt "$cache" ]]; then
        [[ -d "$dir" ]] || mkdir -p "$dir"
        if ! "$@" > "$cache" 2>/dev/null; then
            rm -f "$cache"
            return 1
        fi
    fi

    # shellcheck source=/dev/null
    source "$cache"
}

# ─── Homebrew (macOS) ─────────────────────────────────────────────────────────
# Must run AFTER /etc/profile, which calls path_helper and hoists /usr/bin to
# the front. Same reasoning as ~/.zprofile; see the long note there.
if [[ "$OSTYPE" == "darwin"* ]]; then
    for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$_brew" ]]; then
            _evalcache brew "$_brew" "$_brew" shellenv
            break
        fi
    done
    unset _brew
fi

path_prepend "$HOME/go/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.local/bin"

# ─── XDG + defaults ───────────────────────────────────────────────────────────
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R --quit-if-one-screen"
# LANG only, never LC_ALL -- see the note in .zshenv.
export LANG="${LANG:-en_US.UTF-8}"

# ─── mise ─────────────────────────────────────────────────────────────────────
# Without this, bash gets whatever node/python happen to be on PATH rather than
# the versions pinned in dotfiles/.config/mise/config.toml -- so a script run in
# bash would use a different runtime than the same script run in zsh.
if [[ -x "$HOME/.local/bin/mise" ]]; then
    _evalcache mise "$HOME/.local/bin/mise" "$HOME/.local/bin/mise" activate bash
fi

# ─── SDKMAN (lazy) ────────────────────────────────────────────────────────────
# Same approach as .zshrc: put the candidates on PATH cheaply and defer the real
# init until `sdk` is actually used, because sdkman-init.sh is slow.
if [[ -d "$HOME/.sdkman/candidates" ]]; then
    export SDKMAN_DIR="$HOME/.sdkman"

    for _sdk_bin in "$SDKMAN_DIR"/candidates/*/current/bin; do
        path_prepend "$_sdk_bin"
    done
    unset _sdk_bin

    [[ -d "$SDKMAN_DIR/candidates/java/current" ]] \
        && export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
    for _graal in "$SDKMAN_DIR"/candidates/java/*-graal*/; do
        [[ -d "$_graal" ]] && export GRAALVM_HOME="${_graal%/}"
    done
    unset _graal
    [[ -d "$SDKMAN_DIR/candidates/maven/current" ]] \
        && export MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"

    sdk() {
        unset -f sdk
        # shellcheck source=/dev/null
        source "$SDKMAN_DIR/bin/sdkman-init.sh"
        sdk "$@"
    }
fi

# ─── Everything below is interactive-only ─────────────────────────────────────
case $- in
    *i*) ;;
      *) return ;;
esac

# ─── History ──────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.bash_history"
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth          # skip duplicates and lines starting with a space
shopt -s histappend             # append rather than overwrite
shopt -s checkwinsize
shopt -s cdspell

# ─── Aliases (mirroring .zshrc) ───────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --group-directories-first'
    alias ll='eza -lah --group-directories-first'
    alias lt='eza --tree --level=2'
fi
alias vi='nvim'
alias vim='nvim'

# ─── bat ──────────────────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    export MANPAGER="sh -c 'col -bx | bat --language man --style plain'"
    export MANROFFOPT="-c"
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :200 {}'"
fi

# ─── fzf ──────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    if ! _evalcache fzf "$(command -v fzf)" fzf --bash; then
        [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
        [[ -f /usr/share/doc/fzf/examples/completion.bash ]]   && source /usr/share/doc/fzf/examples/completion.bash
    fi

    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
fi

# ─── Clipboard parity ─────────────────────────────────────────────────────────
if [[ "$OSTYPE" != "darwin"* ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
        alias pbcopy='wl-copy'
        alias pbpaste='wl-paste'
    elif command -v xclip &>/dev/null; then
        alias pbcopy='xclip -selection clipboard'
        alias pbpaste='xclip -selection clipboard -o'
    fi
fi

# ─── direnv ───────────────────────────────────────────────────────────────────
command -v direnv &>/dev/null && _evalcache direnv "$(command -v direnv)" direnv hook bash

# ─── Completion ───────────────────────────────────────────────────────────────
if [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
    source /opt/homebrew/etc/profile.d/bash_completion.sh
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
fi

# ─── Prompt ───────────────────────────────────────────────────────────────────
# Deliberately hand-rolled and small. powerlevel10k is zsh-only, and adding a
# second prompt framework for a fallback shell is not worth the moving parts.
# Shows: user@host, cwd, git branch, and a red marker on non-zero exit.
_bash_prompt() {
    local last=$?
    local branch=""
    if command -v git &>/dev/null; then
        branch="$(git branch --show-current 2>/dev/null)"
        [[ -n "$branch" ]] && branch=" \[\e[35m\](${branch})\[\e[0m\]"
    fi
    local mark="\[\e[32m\]\$\[\e[0m\]"
    [[ $last -ne 0 ]] && mark="\[\e[31m\]\$\[\e[0m\]"
    PS1="\[\e[32m\]\u@\h\[\e[0m\] \[\e[34m\]\w\[\e[0m\]${branch} ${mark} "
}
PROMPT_COMMAND=_bash_prompt

# ─── Local overrides ──────────────────────────────────────────────────────────
# Machine-specific settings, not committed. Mirrors ~/.zshrc.local.
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"
