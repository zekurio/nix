{...}: {
  xdg.configFile."zed/settings.json".text = ''
    {
      "agent": {
        "favorite_models": [],
        "notify_when_agent_waiting": "primary_screen",
        "model_parameters": []
      },
      "agent_servers": {
        "opencode": {
          "favorite_config_option_values": {
            "model": [
              "opencode-go/kimi-k2.6",
              "opencode-go/glm-5.1"
            ]
          },
          "type": "registry"
        },
        "codex-acp": {
          "type": "custom",
          "command": "/run/current-system/sw/bin/codex-acp",
          "favorite_config_option_values": {
            "model": [
              "gpt-5.5"
            ]
          },
          "env": {
            "PATH": "/run/current-system/sw/bin:/etc/profiles/per-user/zekurio/bin"
          }
        },
        "claude-acp": {
          "default_config_options": {
            "mode": "bypassPermissions"
          },
          "favorite_config_option_values": {
            "model": [
              "claude-opus-4-6",
              "claude-opus-4-7"
            ]
          },
          "type": "registry"
        }
      },
      "ui_font_size": 16,
      "buffer_font_size": 15,
      "theme": {
        "mode": "system",
        "light": "One Light",
        "dark": "One Dark"
      }
    }
  '';
}
