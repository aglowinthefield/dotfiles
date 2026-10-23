function mochi --description 'Show the mochi ZFS flavors'
    set -l rows (command zfs list -Hp -o name,used,avail,mountpoint kura kura/anko kura/choco kura/ichigo kura/sakura kura/yuki)
    or return $status

    printf '%s\n' $rows | awk -F '\t' '
        function size(bytes, unit) {
            unit = 1
            while (bytes >= 1024 && unit < 6) {
                bytes /= 1024
                unit++
            }
            return sprintf("%.2f %s", bytes, units[unit])
        }
        BEGIN {
            split("B KiB MiB GiB TiB PiB", units, " ")
            emoji["anko"] = "🫘"
            emoji["choco"] = "🍫"
            emoji["ichigo"] = "🍓"
            emoji["sakura"] = "🌸"
            emoji["yuki"] = "⛄"
            print "╭◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡◡╮"
            print "┊                       ♡  🍡 mochi flavors  ♡                        ┊"
            print "┊                                                                    ┊"
            printf "┊ %-13s ┊ %10s ┊ %10s ┊ %-24s ┊\n", "flavor", "used", "capacity", "home"
            print "┊┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┼┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┊"
        }
        $1 == "kura" { available = $3; next }
        {
            sub(/^kura\//, "", $1)
            printf "┊ %s %-10s ┊ %10s ┊ %10s ┊ %-24s ┊\n", emoji[$1], $1, size($2), size($2 + $3), $4
        }
        END {
            print "╰◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠◠╯"
            printf "  🍡 room for more mochi: %s shared in kura\n", size(available)
            print "  Capacity = used + shared free space. Flavors share that space."
        }
    '
end
