# ---- Lazy-load NVM ----
set -gx NVM_DIR "$HOME/.nvm"

# Resolve default node version and add to PATH without loading nvm.sh
if test -s "$NVM_DIR/alias/default"
    set -l default_version (cat "$NVM_DIR/alias/default")

    if test "$default_version" = "lts/*"
        if test -d "$NVM_DIR/versions/node"
            set default_version (find "$NVM_DIR/versions/node" -maxdepth 1 -name "v*" -type d 2>/dev/null | \
                xargs -I {} basename {} | \
                string match -r '^v[0-9]+\.[0-9]+\.[0-9]+$' | \
                sort -V | tail -1)
        end
    else if string match -q 'lts/*' "$default_version"
        if test -s "$NVM_DIR/alias/$default_version"
            set default_version (cat "$NVM_DIR/alias/$default_version")
            if test -s "$NVM_DIR/alias/$default_version"
                set default_version (cat "$NVM_DIR/alias/$default_version")
            end
        end
    end

    set -l version_dir ""
    if test "$default_version" = node; or test "$default_version" = stable
        set version_dir (find "$NVM_DIR/versions/node" -maxdepth 1 -name "v*" -type d 2>/dev/null | sort -V | tail -1)
    else
        set version_dir (find "$NVM_DIR/versions/node" -maxdepth 1 -name "$default_version*" -type d 2>/dev/null | head -1)
        if test -z "$version_dir"; and test -d "$NVM_DIR/$default_version"
            set version_dir "$NVM_DIR/$default_version"
        end
    end

    if test -n "$version_dir"; and test -d "$version_dir/bin"
        fish_add_path -gP "$version_dir/bin"
    end
end
