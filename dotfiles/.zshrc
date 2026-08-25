# ~/.zshrc -- interactive zsh configuration.
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
    _evalcache mise "$HOME/.local/bin/mise" "$HOME/.local/bin/mise" activate zsh
fi

# ─── SDKMAN activation (lazy) ─────────────────────────────────────────────────
# Sourcing sdkman-init.sh at every shell start costs ~90ms, because it loops
# over every installed candidate in shell to build PATH -- roughly 40% of total
# startup with ten candidates installed.
#
# Almost all of that work is just putting <candidate>/current/bin on PATH,
# which a glob does for free. So do that eagerly (java, mvn, gradle and friends
# are available immediately) and defer the real init until the `sdk` command is
# actually used, which is rare by comparison.
if [[ -d "$HOME/.sdkman/candidates" ]]; then
    export SDKMAN_DIR="$HOME/.sdkman"

    # (N/) = ignore non-matches, directories only.
    for _sdkman_bin in "$SDKMAN_DIR"/candidates/*/current/bin(N/); do
        path=("$_sdkman_bin" $path)
    done
    unset _sdkman_bin

    # SDKMAN puts binaries on PATH and stops there. Everything below is the
    # environment those tools actually need, which sdkman-init would otherwise
    # have set for us.

    # JAVA_HOME: read by Gradle, Maven and jdtls rather than searching PATH.
    # Points at the default JDK, i.e. the first java entry in packages/sdkman.txt.
    [[ -d "$SDKMAN_DIR/candidates/java/current" ]] \
        && export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"

    # GRAALVM_HOME: GraalVM is installed as a second JDK alongside the default,
    # so it is deliberately NOT "current". Native-image builds and Micronaut
    # look this up. Picks the highest-versioned graal install.
    for _graal in "$SDKMAN_DIR"/candidates/java/*-graal*(N/); do
        export GRAALVM_HOME="$_graal"
    done
    unset _graal

    # MAVEN_HOME: not needed by Maven itself since 3.5, but various IDEs and
    # plugins still look for it.
    [[ -d "$SDKMAN_DIR/candidates/maven/current" ]] \
        && export MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"

    # The Spring Boot CLI ships a zsh completion but never installs it.
    # fpath is consumed by compinit further down this file.
    [[ -d "$SDKMAN_DIR/candidates/springboot/current/shell-completion/zsh" ]] \
        && fpath=("$SDKMAN_DIR/candidates/springboot/current/shell-completion/zsh" $fpath)

    # First call to `sdk` replaces this stub with the real implementation.
    # SDKMAN internals are not nounset-safe, hence the defensive set +u.
    sdk() {
        unfunction sdk
        emulate -L zsh
        set +u
        source "$SDKMAN_DIR/bin/sdkman-init.sh"
        sdk "$@"
    }
fi

# ─── Prompt + plugins (antidote + powerlevel10k) ──────────────────────────────
# Plugins are declared in ~/.zsh_plugins.txt and bundled by antidote into a
# single sourceable file, which is what keeps startup fast.
load_plugins_and_prompt() {
    local antidote_home="${ANTIDOTE_HOME:-$HOME/.local/share/antidote}"
    local zsh_plugins="${ZDOTDIR:-$HOME}/.zsh_plugins"
    local zsh_plugins_clean="${zsh_plugins}.clean.txt"
    local needs_rebuild=0

    if [[ -d "$antidote_home/functions" ]]; then
        fpath=("$antidote_home/functions" $fpath)
        autoload -Uz antidote

        if [[ -f "${zsh_plugins}.txt" ]]; then
            # Rebuild when the spec changed, the bundle is missing, or the
            # bundle was poisoned by antidote warning output.
            if [[ ! -f "${zsh_plugins}.zsh" ]] || [[ ! "${zsh_plugins}.zsh" -nt "${zsh_plugins}.txt" ]]; then
                needs_rebuild=1
            elif grep -Eq '^[[:space:]]*warning:' "${zsh_plugins}.zsh" 2>/dev/null; then
                needs_rebuild=1
            fi

            if [[ "$needs_rebuild" == "1" ]]; then
                # antidote emits warnings for comment lines, so bundle from a
                # comment-free copy and strip any stray warning output.
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
load_plugins_and_prompt

# ─── Completion ───────────────────────────────────────────────────────────────
# Runs AFTER the plugin block above so that fpath already contains
# zsh-completions; compinit only sees the fpath it is given at call time.
#
# Rebuilding the dump means scanning every fpath directory, which costs ~450ms.
# Doing that synchronously -- even once a day -- is a visible stall when you
# open a terminal. So: always load the cached dump (instant), and if it has
# gone stale, rebuild it in the BACKGROUND for the next shell. The only cost is
# that a newly installed completion shows up one shell launch later.
#
# To force a rebuild now:
#   rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/zsh/.zcompdump-*
autoload -Uz compinit
zmodload zsh/complist

_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-${ZSH_VERSION}"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"

if [[ ! -s "$_zcompdump" ]]; then
    # No dump at all (first ever run): there is nothing to load from, so pay
    # the full scan once rather than start with no completions.
    compinit -d "$_zcompdump"
    zcompile -R -- "${_zcompdump}.zwc" "$_zcompdump" 2>/dev/null
else
    # -C: trust the dump, skip the fpath security audit. Always instant.
    compinit -C -d "$_zcompdump"

    # Glob qualifiers: N = no match is fine, . = plain file,
    # mh-24 = modified within the last 24 hours.
    _zcompdump_fresh=( $_zcompdump(N.mh-24) )
    if (( ! $#_zcompdump_fresh )); then
        # Rebuild detached, writing to a temp file and moving it into place so
        # two shells starting at once cannot corrupt each other's dump.
        {
            _zcompdump_tmp="${_zcompdump}.$$"
            compinit -d "$_zcompdump_tmp"
            zcompile -R -- "${_zcompdump_tmp}.zwc" "$_zcompdump_tmp" 2>/dev/null
            mv -f "$_zcompdump_tmp" "$_zcompdump" 2>/dev/null
            mv -f "${_zcompdump_tmp}.zwc" "${_zcompdump}.zwc" 2>/dev/null
        } &!
    fi
    unset _zcompdump_fresh
fi
unset _zcompdump

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
# Modern replacements (installed by system.sh)
if command -v eza &>/dev/null; then
    # --icons is safe here: the JetBrainsMono Nerd Font is installed by the
    # system step and is what WezTerm renders with.
    alias ls='eza --group-directories-first --icons'
    alias ll='eza -lah --group-directories-first --icons --git'
    alias lt='eza --tree --level=2 --icons'
fi
# bat is available as its own command -- not aliased over cat because it adds
# decorations that interfere with piping and copy-pasting output.
# rg and fd are available as their own commands -- not aliased over grep/find
# because they have different flags and aliasing breaks scripts that rely on
# standard grep/find behaviour.

# Editor shortcuts
alias vi='nvim'
alias vim='nvim'

# ─── fzf ──────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
    # fzf 0.48+ prints its own shell integration, which removes all per-distro
    # path guessing. Fall back to the packaged scripts for older builds --
    # Ubuntu 22.04 ships 0.29 and 24.04 ships 0.44, neither of which has it.
    if _evalcache fzf "$(command -v fzf)" fzf --zsh; then
        :
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        _fzf_prefix="$(brew --prefix 2>/dev/null)/opt/fzf/shell"
        [[ -f "$_fzf_prefix/key-bindings.zsh" ]] && source "$_fzf_prefix/key-bindings.zsh"
        [[ -f "$_fzf_prefix/completion.zsh" ]]   && source "$_fzf_prefix/completion.zsh"
        unset _fzf_prefix
    else
        [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
        [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]   && source /usr/share/doc/fzf/examples/completion.zsh
    fi

    # Back fzf with fd so it honours .gitignore and skips .git. Without this
    # fzf shells out to find and walks node_modules and friends.
    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
fi

# ─── bat ──────────────────────────────────────────────────────────────────────
# bat is installed on both platforms but was wired to nothing. It is not
# aliased over `cat`, deliberately: bat adds decorations that break piping and
# copy-paste. These are the places where it is unambiguously an improvement.
if command -v bat &>/dev/null; then
    # Syntax-highlighted man pages.
    export MANPAGER="sh -c 'col -bx | bat --language man --style plain'"
    export MANROFFOPT="-c"

    # Preview file contents in fzf's Ctrl-T picker.
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :200 {}'"
fi

# ─── Clipboard parity ─────────────────────────────────────────────────────────
# pbcopy/pbpaste are macOS built-ins. Alias the Linux equivalents to the same
# names so the same muscle memory and the same scripts work on both machines.
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
if command -v direnv &>/dev/null; then
    _evalcache direnv "$(command -v direnv)" direnv hook zsh
fi

# ─── zoxide ───────────────────────────────────────────────────────────────────
# `--cmd cd` replaces cd itself rather than adding a `z` command beside it.
# That is the point: a second command only helps once you remember to use it,
# and the habit being replaced here is the most-typed command on this machine.
#
# Nothing about the old behaviour is lost. zoxide's cd still takes real paths,
# `cd -`, `cd ..` and a bare `cd` for $HOME; it only adds a fallback that
# matches against directories you have already visited when the argument is
# not a path. `cdi` opens the interactive picker, which uses fzf when present.
#
# This MUST stay below compinit -- zoxide's completions attach to the existing
# completion system and are silently dropped if it has not been initialised.
# It is deliberately below direnv too, so a directory jump fires direnv's hook.
if command -v zoxide &>/dev/null; then
    _evalcache zoxide "$(command -v zoxide)" zoxide init zsh --cmd cd
fi

# ─── tmux auto-attach (optional) ──────────────────────────────────────────────
# Keep disabled by default for predictable shell startup.
if [[ "${ZSH_TMUX_AUTO_ATTACH:-0}" == "1" ]] \
    && command -v tmux &>/dev/null \
    && [[ -z "$TMUX" ]] \
    && [[ "$TERM_PROGRAM" != "vscode" ]]; then
    tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi

# ─── Byte-compile our own config ──────────────────────────────────────────────
# zsh will load <file>.zwc instead of parsing <file> when the .zwc is newer, so
# compiling the files we source on every start saves re-parsing them each time.
# Cheap and self-maintaining: each is recompiled only when the source changes.
#
# The symlinked dotfiles live in the repo, so the .zwc files land there too and
# are gitignored. Compiling happens after everything else so it never delays the
# prompt on the run that does the work.
() {
    local f
    for f in "${ZDOTDIR:-$HOME}"/.zshrc "${ZDOTDIR:-$HOME}"/.zshenv \
             "${ZDOTDIR:-$HOME}"/.zprofile "${ZDOTDIR:-$HOME}"/.p10k.zsh \
             "${ZDOTDIR:-$HOME}"/.zsh_plugins.zsh; do
        # -L resolves the symlink so the .zwc sits next to the real file.
        local real="${f:A}"
        [[ -r "$real" ]] || continue
        if [[ ! -s "${real}.zwc" || "$real" -nt "${real}.zwc" ]]; then
            zcompile -R -- "${real}.zwc" "$real" 2>/dev/null
        fi
    done
}

# ─── Local overrides ──────────────────────────────────────────────────────────
# Machine-specific settings that should not be committed to version control.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
