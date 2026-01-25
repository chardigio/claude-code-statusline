# Claude Code Statusline

Custom statusline configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Preview

```
🧠 O4.5 📈 ██░░░░░░42k ⚡️ ███▒░░░░2h30m ██▒░░░░░4d5h 💰 $1.23
📁 ~/cs/my-project 🌿 main↑2 ✏️ +15/-3
```

## Features

- **Model indicator** abbreviated (e.g., Opus 4.5 -> O4.5, Sonnet 4.1 -> S4.1, etc.)
- **Context window** usage bar with token count
- **Rate limit bars** for 5-hour and 7-day windows with pace-based coloring:
  - 🟢 Green: sustainable pace
  - 🟡 Yellow: on pace to hit limit
  - 🔴 Red: at or over limit
- **Session cost** tracking
- **Git branch** with ahead/behind indicators
- **Uncommitted changes** (+added/-removed lines)

## Installation

1. Download the script:
   ```bash
   curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/chardigio/claude-code-statusline/main/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Configure Claude Code to use it by adding to `~/.claude/settings.json`:
   ```json
   {
     "statusline": {
       "script": "~/.claude/statusline.sh"
     }
   }
   ```

## Requirements

- `jq` for JSON parsing
- `git` for repository status
- macOS `security` command for OAuth token access (for rate limit display)

## License

MIT
