# Test the direnv integration
#
# Our main concern is that `devenv shell` should not trigger direnv to immediately reload.
# Because direnv only checks the modification time of watched files, we need to take extra care not to "carelessly" write to such files.
set -xeuo pipefail

# Install direnv
export PATH="$(nix build nixpkgs#direnv --print-out-paths)/bin:$PATH"

export TMPDIR=$(mktemp -d)
export XDG_CONFIG_HOME=${TMPDIR}/config
export XDG_DATA_HOME=${TMPDIR}/data

direnv_eval() {
  eval "$(direnv export bash)"
}

# Setup direnv
mkdir -p $XDG_CONFIG_HOME/.config/direnv/
cat > $XDG_CONFIG_HOME/.config/direnv/direnv.toml << 'EOF'
[global]
strict_env = true
EOF

# Define the devenv arguments
DEVENV_ARGS="--verbose"

# Initialize direnv
cat > .envrc << EOF
  eval "\$(devenv direnvrc)"
  use devenv $DEVENV_ARGS
EOF

# Load the environment
direnv allow
direnv_eval

# Enter shell and capture initial watches
DIRENV_WATCHES_BEFORE=$DIRENV_WATCHES

# Verify DEVENV_CMDLINE matches the expected arguments
if [[ "${DEVENV_CMDLINE:-}" != "$DEVENV_ARGS" ]]; then
  echo "FAIL: DEVENV_CMDLINE is not set to '$DEVENV_ARGS', got: '${DEVENV_CMDLINE:-}'" >&2
  exit 1
fi
echo "PASS: DEVENV_CMDLINE is correctly set to: $DEVENV_CMDLINE" >&2

# Execute some operations that should not cause direnv to reload
echo "Running commands that should not trigger direnv reload..." >&2
devenv shell "echo 'Hello from devenv shell'"

direnv_eval

# Capture watches after
DIRENV_WATCHES_AFTER=$DIRENV_WATCHES

echo "Checking whether direnv reload was triggered..." >&2
if [[ "$DIRENV_WATCHES_BEFORE" == "$DIRENV_WATCHES_AFTER" ]]; then
  echo "PASS: DIRENV_WATCHES remained unchanged" >&2
  exit 0
else
  echo "FAIL: DIRENV_WATCHES changed, indicating unwanted reload" >&2
  echo "Before: $DIRENV_WATCHES_BEFORE" >&2
  echo "After:  $DIRENV_WATCHES_AFTER" >&2
  exit 1
fi
