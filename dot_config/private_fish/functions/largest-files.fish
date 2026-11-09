function largest-files --description 'List the source files with the most lines, skipping gitignored, binary, lock, and generated files'
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

    set -l files
    if set -q git[1]
        set files ($git ls-files -z --cached --others --exclude-standard -- . ':!:**/node_modules/**' | string split0)
    else
        set files (find . -type d \( -name .git -o -name node_modules -o -name .worktrees \) -prune \
            -o -type f -print0 | string split0)
    end

    # Lockfiles and tool output are long but nobody edits them by hand.
    set -l generated '(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Cargo\.lock|Gemfile\.lock|poetry\.lock|uv\.lock|composer\.lock|Podfile\.lock|flake\.lock|go\.sum)$|_snapshot\.json$|baseline-prof\.txt$|\.min\.(js|css)$|\.(map|snap)$'
    set files (string match -rv -- $generated $files)

    # grep -I drops binary files such as fonts and images. BSD grep reads -Z as
    # "decompress", so spell out --null.
    printf '%s\0' $files |
        xargs -0 grep -Il --null -- '' 2>/dev/null |
        xargs -0 wc -l 2>/dev/null |
        string match -rv ' total$' |
        sort -nr |
        head -$count
end
