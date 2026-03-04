# Claude Code Statusline

Custom statusline configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Preview

```
🧠 O4.5 📈 ██░░░░░░42k ⚡️ ███▒░░░░2h30m ██▒░░░░░4d5h 💰 $1.23
📁 ~/cs/my-project 🌿 main↑2 ✏️ +15/-3
```

## Features

- **Model indicator** abbreviated (e.g., Opus 4.5 -> `O4.5`, Sonnet 4.1 -> `S4.1`, etc.)
- **Directory** current working directory (shortened if long)
- **Git branch** with ahead/behind indicators (yellow when there are uncommitted changes, green when clean)
- **Uncommitted changes** (+added/-removed lines)
- **Context window** usage bar with token count
- **Rate limit bars** for 5-hour and 7-day windows with pace-based coloring:
  - 🟢 Green: sustainable pace
  - 🟡 Yellow: on pace to hit limit
  - 🔴 Red: at or over limit
- **Session cost** tracking

## API Pricing Variant

If you use **API pricing** instead of a Pro/Team plan, check out [claude-code-api-statusline](https://github.com/chardigio/claude-code-api-statusline) — a variant without the rate limit progress bars, since API users don't have 5-hour/7-day usage limits.

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
