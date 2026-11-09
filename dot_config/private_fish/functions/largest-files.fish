function largest-files --description 'List the files with the most lines, skipping gitignored files and node_modules'
    set -l count 20
    test (count $argv) -gt 0; and set count $argv[1]

    # Inside a Git work tree, let Git apply .gitignore. Elsewhere, including a
    # checkout whose repo has core.bare=true, fall back to find.
    if test "(git rev-parse --is-inside-work-tree 2>/dev/null)" = true
        git ls-files -z --cached --others --exclude-standard -- . ':!:**/node_modules/**' |
            xargs -0 wc -l 2>/dev/null
    else
        find . -type d \( -name .git -o -name node_modules -o -name .worktrees \) -prune \
            -o -type f -exec wc -l {} +
    end |
        string match -rv ' total$' |
        sort -nr |
        head -$count
end
