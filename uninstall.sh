#!/usr/bin/env bash
set -euo pipefail
umask 077

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ollama-adreno-termux"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ollama-adreno-termux"
if [[ ! -f "$state_dir/active-backup" ]]; then
  printf 'No active installation to remove.\n'
  exit 0
fi
IFS= read -r backup_dir < "$state_dir/active-backup"
[[ "$backup_dir" == "$state_dir"/backup.* && -d "$backup_dir" ]] || {
  printf 'Backup directory is missing or invalid; no files changed.\n' >&2
  exit 1
}
saved_dir=$(mktemp -d "$state_dir/uninstalled.XXXXXXXX")
targets=("$HOME/.local/bin/ollama" "$HOME/.local/bin/ollama-gpu-check" "$config_dir/gpu.env")
keys=(launcher diagnostics configuration)
for i in "${!targets[@]}"; do
  target="${targets[$i]}"
  key="${keys[$i]}"
  if [[ -e "$target" || -L "$target" ]]; then
    mv -- "$target" "$saved_dir/$key"
  fi
  if [[ -e "$backup_dir/$key" || -L "$backup_dir/$key" ]]; then
    cp -a -- "$backup_dir/$key" "$target"
  fi
done
rm -- "$state_dir/active-backup"
printf 'Restored the files that existed before installation.\n'
printf 'Removed files and any edits are saved in: %s\n' "$saved_dir"
printf 'Packages and models remain installed. Restart Ollama for startup settings to change.\n'
