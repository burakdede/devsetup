# Minimal fast powerlevel10k config
# Keep this lean to reduce first-prompt and command lag.

typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
# nerdfont-v3, not nerdfont-complete: Nerd Fonts v3 relocated many glyphs, and
# packages/versions.txt pins 3.3.0. The v2 codepoints render as wrong or
# missing icons against a v3 font.
typeset -g POWERLEVEL9K_MODE=nerdfont-v3
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off

typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir
    vcs
)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    command_execution_time
    background_jobs
    time
)

typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3

typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=
typeset -g POWERLEVEL9K_STATUS_OK=true
