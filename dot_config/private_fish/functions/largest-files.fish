function largest-files --description 'List the files with the most lines, skipping gitignored files and node_modules'
    set -l count 20
    test (count $argv) -gt 0; and set count $argv[1]

    # Let Git apply .gitignore when it can. silk-remix's root checkout has
    # core.bare=true (its worktrees hang off it), so Git refuses ls-files there
    # unless we name the work tree.
    set -l git git
    if test "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != true
        if test -d .git; and test "$(git rev-parse --is-bare-repository 2>/dev/null)" = true
            set git git --work-tree=.
        else
            set git
        end
    end

    if set -q git[1]
        $git ls-files -z --cached --others --exclude-standard -- . ':!:**/node_modules/**' |
            xargs -0 wc -l 2>/dev/null
    else
        find . -type d \( -name .git -o -name node_modules -o -name .worktrees \) -prune \
            -o -type f -exec wc -l {} +
    end |
        string match -rv ' total$' |
        sort -nr |
        head -$count
end
