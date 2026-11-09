function largest-files --description 'List the files with the most lines, skipping .git, node_modules, and .worktrees'
    set -l count 20
    test (count $argv) -gt 0; and set count $argv[1]
    find . -type d \( -name .git -o -name node_modules -o -name .worktrees \) -prune \
        -o -type f -exec wc -l {} + |
        string match -rv ' total$' |
        sort -nr |
        head -$count
end
