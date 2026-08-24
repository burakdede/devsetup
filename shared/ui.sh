#!/usr/bin/env bash
# Terminal output for the devsetup scripts -- shared by macOS and Ubuntu.
#
# This is the first thing that runs on a new machine, before anything has been
# installed, so it has NO dependencies: pure bash 3.2 plus coreutils. No gum,
# no dialog, no fzf. `tput` is used when present and degraded around when not.
#
# ── What it handles ───────────────────────────────────────────────────────────
# * Colour and box drawing only when stdout is a terminal. Piped or redirected
#   output is plain and greppable, which matters because every run is tee'd to
#   a log file and read back later.
# * Real terminal width, not a hardcoded 80. Narrow terminals no longer wrap
#   mid-box and wide ones are not left half empty.
# * Padding by CHARACTER count, not byte count. `printf %-78s` pads by bytes,
#   so a title containing "·" (2 bytes) pushed the box edge 1 column left per
#   occurrence. bash counts characters in a UTF-8 locale, so ${#s} is correct.
# * ASCII fallback when the terminal cannot render box drawing.
#
# Everything is prefixed ui_ and safe to source more than once.

# ─── Capability detection ─────────────────────────────────────────────────────
ui_init() {
    # Colour: only for a terminal, and honour the informal NO_COLOR convention.
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
        UI_TTY=1
        UI_RED=$'\033[0;31m';    UI_GREEN=$'\033[0;32m'
        UI_YELLOW=$'\033[1;33m'; UI_BLUE=$'\033[0;34m'
        UI_CYAN=$'\033[0;36m';   UI_DIM=$'\033[2m'
        UI_BOLD=$'\033[1m';      UI_RESET=$'\033[0m'
    else
        UI_TTY=0
        UI_RED=''; UI_GREEN=''; UI_YELLOW=''; UI_BLUE=''
        UI_CYAN=''; UI_DIM=''; UI_BOLD=''; UI_RESET=''
    fi

    # Width: real terminal width, clamped so output stays readable either way.
    UI_WIDTH="${COLUMNS:-0}"
    if [ "$UI_WIDTH" -le 0 ] 2>/dev/null; then
        UI_WIDTH="$(tput cols 2>/dev/null || echo 80)"
    fi
    case "$UI_WIDTH" in (*[!0-9]*|'') UI_WIDTH=80 ;; esac
    [ "$UI_WIDTH" -lt 40 ] && UI_WIDTH=40
    [ "$UI_WIDTH" -gt 100 ] && UI_WIDTH=100

    # Box drawing needs a UTF-8 locale; fall back to ASCII otherwise so the
    # output is never mojibake on a plain console.
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf8*|*UTF8*) UI_UNICODE=1 ;;
        *)                     UI_UNICODE=0 ;;
    esac

    if [ "$UI_UNICODE" -eq 1 ]; then
        UI_H='─'; UI_TL='┌'; UI_TR='┐'; UI_BL='└'; UI_BR='┘'; UI_V='│'
        UI_MARK_OK='✓'; UI_MARK_ERR='✗'; UI_MARK_WARN='!'; UI_MARK_SKIP='-'
        UI_ARROW='▸'
    else
        UI_H='-'; UI_TL='+'; UI_TR='+'; UI_BL='+'; UI_BR='+'; UI_V='|'
        UI_MARK_OK='OK'; UI_MARK_ERR='XX'; UI_MARK_WARN='!!'; UI_MARK_SKIP='--'
        UI_ARROW='>'
    fi
}

# Repeat $1 $2 times. Pure bash, no seq or printf tricks that break on 3.2.
ui_repeat() {
    local char="$1" count="$2" out=''
    while [ "$count" -gt 0 ]; do
        out="$out$char"
        count=$((count - 1))
    done
    printf '%s' "$out"
}

# ─── Section header ───────────────────────────────────────────────────────────
# A boxed title when interactive; a plain "== title ==" line when not, so log
# files and CI output stay readable and greppable.
ui_header() {
    local title="$1"

    if [ "$UI_TTY" -eq 0 ]; then
        printf '\n== %s ==\n' "$title"
        return
    fi

    # ${#title} counts characters, not bytes, which is what the box needs.
    local inner=$((UI_WIDTH - 4))
    [ "${#title}" -gt "$inner" ] && title="${title:0:$inner}"
    local pad=$((inner - ${#title}))

    printf '\n%s%s%s%s%s\n' "$UI_BLUE" "$UI_TL" "$(ui_repeat "$UI_H" $((UI_WIDTH - 2)))" "$UI_TR" "$UI_RESET"
    printf '%s%s%s %s%s%s%s %s%s\n' \
        "$UI_BLUE" "$UI_V" "$UI_RESET" \
        "$UI_BOLD" "$title" "$UI_RESET" "$(ui_repeat ' ' "$pad")" \
        "$UI_BLUE$UI_V" "$UI_RESET"
    printf '%s%s%s%s%s\n' "$UI_BLUE" "$UI_BL" "$(ui_repeat "$UI_H" $((UI_WIDTH - 2)))" "$UI_BR" "$UI_RESET"
}

ui_rule() {
    printf '%s%s%s\n' "$UI_DIM" "$(ui_repeat "$UI_H" "$UI_WIDTH")" "$UI_RESET"
}

# ─── Status lines ─────────────────────────────────────────────────────────────
ui_ok()    { printf '  %s%s%s %s\n' "$UI_GREEN"  "$UI_MARK_OK"   "$UI_RESET" "$1"; }
ui_warn()  { printf '  %s%s%s %s\n' "$UI_YELLOW" "$UI_MARK_WARN" "$UI_RESET" "$1" >&2; }
ui_err()   { printf '  %s%s%s %s\n' "$UI_RED"    "$UI_MARK_ERR"  "$UI_RESET" "$1" >&2; }
ui_skip()  { printf '  %s%s %s%s\n' "$UI_DIM"    "$UI_MARK_SKIP" "$1" "$UI_RESET"; }
ui_info()  { printf '  %s%s%s %s\n' "$UI_CYAN"   "$UI_ARROW"     "$UI_RESET" "$1"; }
ui_plain() { printf '    %s\n' "$1"; }

# ─── Step banner ──────────────────────────────────────────────────────────────
# ui_step <n> <total> <name> <description>
ui_step() {
    local n="$1" total="$2" name="$3" desc="$4"
    local counter="[$n/$total]"

    if [ "$UI_TTY" -eq 0 ]; then
        printf '\n== %s %s -- %s ==\n' "$counter" "$name" "$desc"
        return
    fi

    printf '\n%s%s%s %s%s%s  %s%s%s\n' \
        "$UI_DIM" "$counter" "$UI_RESET" \
        "$UI_BOLD" "$name" "$UI_RESET" \
        "$UI_DIM" "$desc" "$UI_RESET"
    printf '%s%s%s\n' "$UI_DIM" "$(ui_repeat "$UI_H" "$UI_WIDTH")" "$UI_RESET"
}

# ─── Prompts ──────────────────────────────────────────────────────────────────
# Deliberately loud. A bootstrap that silently waits for input looks like a
# hang, so a prompt gets its own visual block saying what is wanted and what
# happens if you just press Enter.
#
# ui_prompt <question> <default> <varname>
ui_prompt() {
    local question="$1" default="$2" varname="$3" reply=''

    printf '\n%s%s input needed%s\n' "$UI_YELLOW$UI_BOLD" "$UI_ARROW" "$UI_RESET"
    printf '  %s\n' "$question"
    if [ -n "$default" ]; then
        printf '  %spress Enter to accept:%s %s%s%s\n' "$UI_DIM" "$UI_RESET" "$UI_BOLD" "$default" "$UI_RESET"
    fi
    printf '  %s>%s ' "$UI_CYAN" "$UI_RESET"

    IFS= read -r reply || reply=''
    [ -z "$reply" ] && reply="$default"
    eval "$varname=\$reply"
}

# ui_confirm <question>  -> 0 for yes, 1 for no. Defaults to yes on Enter.
ui_confirm() {
    local question="$1" reply=''
    printf '\n%s%s %s%s [Y/n] ' "$UI_YELLOW$UI_BOLD" "$UI_ARROW" "$question" "$UI_RESET"
    IFS= read -r reply || reply=''
    case "$reply" in
        ''|y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# ─── Run summary ──────────────────────────────────────────────────────────────
# bash 3.2 has no associative arrays, so the summary is accumulated as
# newline-separated "status<TAB>name<TAB>seconds" records.
UI_SUMMARY=''

ui_summary_add() {
    UI_SUMMARY="${UI_SUMMARY}$1	$2	$3
"
}

ui_summary_print() {
    local total_seconds="$1"
    local status name secs symbol colour
    local n_ok=0 n_fail=0 n_skip=0

    ui_header "Summary"

    while IFS='	' read -r status name secs; do
        [ -z "$name" ] && continue
        case "$status" in
            ok)   symbol="$UI_MARK_OK";   colour="$UI_GREEN";  n_ok=$((n_ok + 1)) ;;
            fail) symbol="$UI_MARK_ERR";  colour="$UI_RED";    n_fail=$((n_fail + 1)) ;;
            *)    symbol="$UI_MARK_SKIP"; colour="$UI_DIM";    n_skip=$((n_skip + 1)) ;;
        esac
        printf '  %s%s%s %-16s %s%ss%s\n' \
            "$colour" "$symbol" "$UI_RESET" "$name" "$UI_DIM" "$secs" "$UI_RESET"
    done <<EOF
$UI_SUMMARY
EOF

    printf '\n  %s%s completed%s' "$UI_GREEN" "$n_ok" "$UI_RESET"
    [ "$n_skip" -gt 0 ] && printf '%s, %s skipped%s' "$UI_DIM" "$n_skip" "$UI_RESET"
    [ "$n_fail" -gt 0 ] && printf '%s, %s failed%s' "$UI_RED" "$n_fail" "$UI_RESET"
    printf '   %sin %ss%s\n' "$UI_DIM" "$total_seconds" "$UI_RESET"
}

ui_init
