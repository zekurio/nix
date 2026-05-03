# Manual fish config backed up from the Home Manager setup.

alias la 'eza -la'
alias ll 'eza -lah'
alias ls eza
alias lt 'eza --tree'

set fish_greeting

if status is-interactive
    if command -q zoxide
        zoxide init fish --cmd cd | source
    end

    if test "$TERM" != dumb; and command -q starship
        starship init fish | source
    end

    if command -q carapace
        carapace _carapace fish | source
    end

    if command -q atuin
        atuin init fish | source
    end

end
