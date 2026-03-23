#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="editors"

SCSS_FILE="$STATE_DIR/user/generated/material_colors.scss"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VSCODE_THEMEGEN_BIN="$STATE_DIR/user/generated/bin/inir-vscode-themegen"

ensure_vscode_themegen() {
  command -v go &>/dev/null || return 1
  mkdir -p "$STATE_DIR/user/generated/bin"
  if [[ ! -x "$VSCODE_THEMEGEN_BIN" || "$REPO_ROOT/go.mod" -nt "$VSCODE_THEMEGEN_BIN" || "$SCRIPT_DIR/vscode_themegen/main.go" -nt "$VSCODE_THEMEGEN_BIN" ]]; then
    (cd "$REPO_ROOT" && go build -o "$VSCODE_THEMEGEN_BIN" ./scripts/colors/vscode_themegen) >/dev/null 2>&1 || return 1
  fi
  [[ -x "$VSCODE_THEMEGEN_BIN" ]]
}

apply_code_editors() {
  [[ -f "$SCSS_FILE" ]] || return 0
  local python_cmd
  python_cmd=$(venv_python)

  local enable_zed enable_vscode
  enable_zed=$(config_json 'if .appearance.wallpaperTheming | has("enableZed") then .appearance.wallpaperTheming.enableZed else true end' true)
  enable_vscode=$(config_json 'if .appearance.wallpaperTheming | has("enableVSCode") then .appearance.wallpaperTheming.enableVSCode else true end' true)

  if [[ "$enable_zed" == 'true' ]] && { command -v zed &>/dev/null || command -v zeditor &>/dev/null; }; then
    "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --zed >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
  fi

  if [[ "$enable_vscode" == 'true' ]]; then
    local enabled_forks=()
    local disabled_forks=()
    if [[ -f "$CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
      local editors_config
      editors_config=$(jq -r '.appearance.wallpaperTheming.vscodeEditors // {}' "$CONFIG_FILE" 2>/dev/null || echo '{}')

      _check_vscode_fork() {
        local jq_key="$1" fork_key="$2" config_dir="$3"
        if [[ $(echo "$editors_config" | jq -r ".$jq_key // true") == 'true' ]] && [[ -d "$config_dir" ]]; then
          enabled_forks+=("$fork_key")
        elif [[ -d "$config_dir" ]]; then
          disabled_forks+=("$fork_key")
        fi
      }

      _check_vscode_fork code code "$HOME/.config/Code"
      _check_vscode_fork codium codium "$HOME/.config/VSCodium"
      _check_vscode_fork codeOss code-oss "$HOME/.config/Code - OSS"
      _check_vscode_fork codeInsiders code-insiders "$HOME/.config/Code - Insiders"
      _check_vscode_fork cursor cursor "$HOME/.config/Cursor"
      _check_vscode_fork windsurf windsurf "$HOME/.config/Windsurf"
      _check_vscode_fork windsurfNext windsurf-next "$HOME/.config/Windsurf - Next"
      _check_vscode_fork qoder qoder "$HOME/.config/Qoder"
      _check_vscode_fork antigravity antigravity "$HOME/.config/Antigravity"
      _check_vscode_fork positron positron "$HOME/.config/Positron"
      _check_vscode_fork voidEditor void "$HOME/.config/Void"
      _check_vscode_fork melty melty "$HOME/.config/Melty"
      _check_vscode_fork pearai pearai "$HOME/.config/PearAI"
      _check_vscode_fork aide aide "$HOME/.config/Aide"

      unset -f _check_vscode_fork
    fi

    if [[ ${#enabled_forks[@]} -gt 0 ]]; then
      if ensure_vscode_themegen; then
        local vscode_cmd=("$VSCODE_THEMEGEN_BIN" "--colors" "$STATE_DIR/user/generated/colors.json" "--scss" "$SCSS_FILE")
        for fork in "${enabled_forks[@]}"; do
          vscode_cmd+=("--forks" "$fork")
        done
        "${vscode_cmd[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/generate_terminal_configs.py" --scss "$SCSS_FILE" --vscode --vscode-forks "${enabled_forks[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi

    # Strip theme from individually disabled forks
    if [[ ${#disabled_forks[@]} -gt 0 ]]; then
      if ensure_vscode_themegen; then
        local strip_cmd=("$VSCODE_THEMEGEN_BIN" "--strip")
        for fork in "${disabled_forks[@]}"; do
          strip_cmd+=("--forks" "$fork")
        done
        "${strip_cmd[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      else
        "$python_cmd" "$SCRIPT_DIR/vscode/theme_generator.py" --strip --forks "${disabled_forks[@]}" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
      fi
    fi
  else
    # VSCode theming globally disabled — strip all installed forks
    if ensure_vscode_themegen; then
      "$VSCODE_THEMEGEN_BIN" --strip >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    else
      "$python_cmd" "$SCRIPT_DIR/vscode/theme_generator.py" --strip >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    fi
  fi

  if command -v opencode &>/dev/null; then
    local enable_opencode
    enable_opencode=$(config_bool '.appearance.wallpaperTheming.enableOpenCode' true)
    if [[ "$enable_opencode" == 'true' ]]; then
      "$python_cmd" "$SCRIPT_DIR/opencode/theme_generator.py" "$SCSS_FILE" >> "$STATE_DIR/user/generated/code_editor_themes.log" 2>&1 || true
    fi
  fi
}

main() {
  apply_code_editors
}

main "$@"
