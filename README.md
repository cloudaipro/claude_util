# claude_util

Collection of utility scripts for Claude Code status line customization and session time tracking.

## Features

### Status Line Scripts

#### `status_line/statusline-p10k.sh`
Powerlevel10k-optimized status line for Claude Code showing:
- Model indicator with color-coded icon (💛 Opus, 💠 Sonnet, 🌸 Haiku)
- Current directory (truncated to 40 chars)
- Git branch with status indicators (`*` modified, `+` staged, `?` untracked)
- Context usage visualization:
  - 5-character progress bar (█████ full, ░░░░░ empty)
  - Color-coded by usage: Green <60%, Gold 60-80%, Red >80%
  - Percentage and token count (e.g., `████░ 87% 174k`)
- Audio alerts for context thresholds:
  - 50-60%: 1 beep sound
  - 60-70%: 2 beep sounds (0.3s interval)
  - 70-80%: 3 beep sounds (0.3s interval)
  - Alerts trigger only once per threshold crossing
- Session duration tracking
- Last user message preview (truncated to 50 chars)

#### `status_line/statusline.sh`
Main shell implementation with full features.

#### `status_line/statusline.go`
Go implementation with concurrent processing and additional features.

### Session Statistics

#### `status_line/claude-stats.sh`
Track and analyze Claude Code usage:
```bash
./status_line/claude-stats.sh          # Today's stats
./status_line/claude-stats.sh week     # Current week
./status_line/claude-stats.sh month    # Current month
./status_line/claude-stats.sh all      # All time stats
./status_line/claude-stats.sh archive  # Archive old sessions
```

## Installation

1. Clone the repository
2. Make scripts executable:
   ```bash
   chmod +x status_line/*.sh
   ```
3. Configure Claude Code to use the status line script

## Testing

Test status line with sample input:
```bash
echo '{"model":{"display_name":"Claude 3.5 Sonnet"},"session_id":"test","workspace":{"current_dir":"'$(pwd)'"}}' | ./status_line/statusline-p10k.sh
```

## Context Usage Colors

- **Green** (RGB 108,167,108): <60% context usage
- **Gold** (RGB 188,155,83): 60-80% context usage
- **Red** (RGB 185,102,82): >80% context usage

## File Structure

```
~/.claude/
├── cache/              # Git branch cache (5s TTL)
│   └── git_branch
└── session-tracker/
    ├── sessions/       # Current session files
    └── archive/        # Historical sessions by date
        └── YYYY-MM-DD/
```