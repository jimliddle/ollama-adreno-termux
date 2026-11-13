#!/usr/bin/env bash
set -euo pipefail
umask 077

skip_packages=0
case "${1:-}" in
  --skip-packages) skip_packages=1 ;;
  --help|-h)
    printf 'Usage: bash install.sh [--skip-packages]\nInstalls official Termux packages and a user-local Ollama launcher.\n'
    exit 0 ;;
  '') ;;
  *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Too many arguments.\n' >&2; exit 2; }

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
termux_prefix="${PREFIX:-/data/data/com.termux/files/usr}"
[[ -x "$termux_prefix/bin/bash" ]] || {
  printf 'Run this installer in native Termux; its bash was not found at %s.\n' "$termux_prefix/bin/bash" >&2
  exit 1
}

if (( ! skip_packages )); then
  "$termux_prefix/bin/apt-get" update
  "$termux_prefix/bin/apt-get" install -y --no-install-recommends \
    ollama ollama-backend-vulkan vulkan-loader-android libc++ python
fi
[[ -x "$termux_prefix/bin/ollama" && -f "$termux_prefix/lib/ollama/vulkan/libggml-vulkan.so" ]] || {
  printf 'Ollama and ollama-backend-vulkan must be installed first.\n' >&2
  exit 1
}
[[ -x "$termux_prefix/bin/python" ]] || {
  printf 'Install the Termux python package for diagnostics.\n' >&2; exit 1
}

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ollama-adreno-termux"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ollama-adreno-termux"
bin_dir="$HOME/.local/bin"
mkdir -p "$bin_dir" "$config_dir" "$state_dir"
targets=("$bin_dir/ollama" "$bin_dir/ollama-gpu-check" "$config_dir/gpu.env")
keys=(launcher diagnostics configuration)
fresh_install=0

if [[ ! -f "$state_dir/active-backup" ]]; then
  fresh_install=1
  backup_dir=$(mktemp -d "$state_dir/backup.XXXXXXXX")
  for i in "${!targets[@]}"; do
    if [[ -e "${targets[$i]}" || -L "${targets[$i]}" ]]; then
      cp -a -- "${targets[$i]}" "$backup_dir/${keys[$i]}"
    fi
  done
  printf '%s\n' "$backup_dir" > "$state_dir/active-backup"
fi

staging_dir=$(mktemp -d "$state_dir/staging.XXXXXXXX")
trap 'rm -rf -- "$staging_dir"' EXIT
{
  printf '#!%s/bin/bash\n' "$termux_prefix"
  tail -n +2 "$repo_dir/bin/ollama"
} > "$staging_dir/ollama"
{
  printf '#!%s/bin/python\n' "$termux_prefix"
  tail -n +2 "$repo_dir/bin/ollama-gpu-check"
} > "$staging_dir/ollama-gpu-check"
chmod 700 "$staging_dir/ollama" "$staging_dir/ollama-gpu-check"
mv -f -- "$staging_dir/ollama" "$bin_dir/ollama"
mv -f -- "$staging_dir/ollama-gpu-check" "$bin_dir/ollama-gpu-check"

# Reinstalling preserves user edits to the existing configuration.
if (( fresh_install )) || [[ ! -e "$config_dir/gpu.env" ]]; then
  {
    printf 'export OLLAMA_TERMUX_PREFIX=%q\n' "$termux_prefix"
    cat "$repo_dir/config/gpu.env"
  } > "$staging_dir/gpu.env"
  chmod 600 "$staging_dir/gpu.env"
  mv -- "$staging_dir/gpu.env" "$config_dir/gpu.env"
fi

printf 'Installed. Enable the launcher in this shell:\n\n'
printf '  export PATH="$HOME/.local/bin:$PATH"\n  hash -r\n\n'
printf 'Then restart your existing Ollama server and run: ollama serve\n'
printf 'Verify with: ollama-gpu-check --generate MODEL_ALREADY_INSTALLED\n'
printf 'Configuration: %s/gpu.env\nRollback: bash %s/uninstall.sh\n' "$config_dir" "$repo_dir"
