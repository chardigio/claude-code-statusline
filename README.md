# Claude Code Statusline

Custom statusline configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

If you use API pricing, see [claude-code-api-statusline](https://github.com/chardigio/claude-code-api-statusline) — a variant without the rate limit progress bars.

## Preview

```
📈 ██░░░░░░42k ⚡️ ███▒░░░░2h30m ██▒░░░░░4d5h 💰 $1.23
🧠 O5·xh 💭 📁 ~/cs/my-project 🌿 main↑2 ✏️ +15/-3
```

## Features

- **Model indicator** abbreviated (e.g., Opus 5 -> `O5`, Sonnet 4.1 -> `S4.1`, etc.)
- **Reasoning effort** suffixed to the model — `·lo` `·md` `·hi` `·xh` `·max` — colored green (low/medium), yellow (high), red (xhigh/max). Hidden for models with no effort control.
- **Extended thinking** 💭 when thinking is enabled for the session
- **Fast mode** 🚀 when `/fast` is on
- **Directory** current working directory (shortened if long)
- **Git branch** with ahead/behind indicators (yellow when there are uncommitted changes, green when clean)
- **Uncommitted changes** (+added/-removed lines)
- **Context window** usage bar with token count
- **Rate limit bars** for 5-hour and 7-day windows with pace-based coloring:
  - 🟢 Green: sustainable pace
  - 🟡 Yellow: on pace to hit limit
  - 🔴 Red: at or over limit
- **Session cost** tracking

## Installation

### Quick Install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/chardigio/claude-code-statusline/main/install.sh | bash
```

This downloads the script to `~/.claude/statusline.sh` and configures Claude Code to use it.

### Manual Installation

1. Download the script:
   ```bash
   curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/chardigio/claude-code-statusline/main/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Configure Claude Code by adding to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh",
       "padding": 0
     }
   }
   ```

## Requirements

- `jq` for JSON parsing
- `git` for repository status
- macOS `security` command for OAuth token access (for rate limit display)

## License

MIT
