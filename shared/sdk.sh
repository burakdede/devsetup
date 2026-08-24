#!/usr/bin/env bash
# SDKMAN bootstrap -- shared by macOS and Ubuntu.
#
# No OS-specific logic. Sourced by mac/sdk/sdk.sh and linux/sdk/sdk.sh, which
# only supply their skip-flag wording.
#
# SDKMAN owns the JVM ecosystem here; mise owns everything else. See
# packages/sdkman.txt for why, and for the candidate list.
#
# This does more than install: it also makes the tools usable, which SDKMAN
# does not do on its own beyond putting them on PATH. See configure_sdk_env.

SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"

# SDKMAN 5.23+ branches on the shell it detects and, for bash, uses the bash 4
# uppercase expansion "${name^^}" (see sdkman-path-helpers.sh). macOS still
# ships bash 3.2, where that is a hard syntax error:
#
#     sdkman-path-helpers.sh: line 61: ${candidate_name^^}: bad substitution
#
# and every sdk command fails. Re-exec under a newer bash when the one running
# us is too old. Homebrew's bash is in the Brewfile for exactly this.
ensure_modern_bash() {
    [[ -n "${BASH_VERSINFO:-}" ]] || return 0
    [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && return 0

    local newer
    for newer in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$newer" ]]; then
            log_info "bash ${BASH_VERSINFO[0]} is too old for SDKMAN; re-running under $newer"
            exec "$newer" "$0" "$@"
        fi
    done

    log_error "SDKMAN needs bash >= 4 but this is bash ${BASH_VERSINFO[0]}, and no newer bash was found."
    log_error "Install one first:  brew install bash"
    return 1
}

# SDKMAN's scripts are not nounset-safe, and every script here runs with
# `set -u`. Wrap the two places that touch them.
_sdk_without_nounset() {
    local restore=0
    [[ -o nounset ]] && { restore=1; set +u; }
    "$@"
    local rc=$?
    [[ "$restore" -eq 1 ]] && set -u
    return "$rc"
}

run_sdk() { _sdk_without_nounset sdk "$@"; }

load_sdkman() {
    if [[ -s "$SDKMAN_INIT" ]]; then
        # shellcheck source=/dev/null
        _sdk_without_nounset source "$SDKMAN_INIT"
        return 0
    fi

    log_info "Installing SDKMAN..."
    local tmp_installer
    tmp_installer="$(mktemp)"
    curl -fsSL "https://get.sdkman.io" -o "$tmp_installer"
    # rcupdate=false stops SDKMAN editing .zshrc/.bashrc; dotfiles/.zshrc
    # already wires it up, lazily.
    _sdk_without_nounset env SDKMAN_DIR="$HOME/.sdkman" rcupdate=false bash "$tmp_installer"
    rm -f "$tmp_installer"
    # shellcheck source=/dev/null
    _sdk_without_nounset source "$SDKMAN_INIT"
}

# Install every entry in packages/sdkman.txt.
#
# Entries are `candidate` or `candidate@version`. The first java entry becomes
# the default JDK, so JAVA_HOME resolves to it; later java entries are
# installed alongside without changing the default (this is how GraalVM gets
# installed next to Temurin).
install_sdk_packages() {
    echo_header "SDKMAN candidates"

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_warn "Missing $PACKAGES_FILE; skipping SDKMAN candidates."
        return 0
    fi

    local entry candidate version java_default=""
    while IFS= read -r entry; do
        candidate="${entry%%@*}"
        version=""
        [[ "$entry" == *"@"* ]] && version="${entry#*@}"

        if [[ -n "$version" ]]; then
            log_info "Installing ${candidate} ${version}"
            # The trailing < /dev/null stops SDKMAN prompting "make default?"
            # for each JDK; the default is set explicitly below instead.
            if ! run_sdk install "$candidate" "$version" < /dev/null; then
                log_warn "Unable to install ${candidate} ${version}. Check: sdk list $candidate"
                continue
            fi
        else
            log_info "Installing ${candidate} (SDKMAN default version)"
            if ! run_sdk install "$candidate" < /dev/null; then
                log_warn "Unable to install ${candidate}. Check: sdk list $candidate"
                continue
            fi
        fi

        # Remember the first java entry; it becomes the default JDK.
        if [[ "$candidate" == "java" && -z "$java_default" && -n "$version" ]]; then
            java_default="$version"
        fi
    done < <(read_list_file "$PACKAGES_FILE")

    if [[ -n "$java_default" ]]; then
        log_info "Setting default JDK to $java_default"
        run_sdk default java "$java_default" < /dev/null \
            || log_warn "Could not set default java to $java_default."
    fi
}

# SDKMAN puts binaries on PATH and nothing else. Several of these tools are
# only actually usable once some environment or completion is wired up, so do
# that here rather than leaving it as a manual step after install.
configure_sdk_env() {
    echo_header "JVM toolchain configuration"

    local candidates="$HOME/.sdkman/candidates"

    # JAVA_HOME and GRAALVM_HOME are exported by dotfiles/.zshrc, which derives
    # them from these paths. Report what a new shell will see, and fail loudly
    # if the expected layout is not there.
    if [[ -d "$candidates/java/current" ]]; then
        local java_ver
        java_ver="$("$candidates/java/current/bin/java" -version 2>&1 | head -1)"
        log_success "JAVA_HOME -> $candidates/java/current"
        log_info    "  $java_ver"
    else
        log_warn "No default JDK selected. Run: sdk default java <version>"
    fi

    local graal
    graal="$(find "$candidates/java" -maxdepth 1 -name '*-graal*' 2>/dev/null | sort | tail -1)"
    if [[ -n "$graal" ]]; then
        log_success "GRAALVM_HOME -> $graal"
        if [[ -x "$graal/bin/native-image" ]]; then
            log_success "native-image is available"
        else
            log_info "native-image not present in this GraalVM build."
            log_info "  Install it with: \"$graal/bin/gu\" install native-image"
        fi
    else
        log_info "No GraalVM distribution installed."
    fi

    [[ -d "$candidates/maven/current" ]]  && log_success "MAVEN_HOME -> $candidates/maven/current"
    [[ -d "$candidates/gradle/current" ]] && log_success "gradle -> $("$candidates/gradle/current/bin/gradle" --version 2>/dev/null | awk '/^Gradle/{print $2}')"

    # The Spring Boot CLI ships a zsh completion but does not install it.
    # dotfiles/.zshrc adds this directory to fpath when it exists.
    if [[ -f "$candidates/springboot/current/shell-completion/zsh/_spring" ]]; then
        log_success "spring CLI zsh completion found (wired into fpath by .zshrc)"
    fi

    # Homebrew/APT copies of maven or gradle would shadow these on PATH.
    local shadow
    for shadow in mvn gradle; do
        local resolved
        resolved="$(command -v "$shadow" 2>/dev/null || true)"
        if [[ -n "$resolved" && "$resolved" != "$candidates"/* ]]; then
            log_warn "$shadow resolves to $resolved, not SDKMAN."
            log_warn "  SDKMAN is meant to own it. Remove the other copy, e.g. brew uninstall ${shadow/mvn/maven}"
        fi
    done
}

setup_sdkman() {
    ensure_modern_bash "$@" || return 1
    load_sdkman
    run_sdk selfupdate || true
    run_sdk update     || true
    install_sdk_packages
    configure_sdk_env

    echo_header "SDKMAN setup complete"
    log_info "Open a new shell, or run: source \"$SDKMAN_INIT\""
}
