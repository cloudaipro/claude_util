# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Collection of utility scripts for Claude Code status line customization and session time tracking. The scripts process JSON input from Claude Code to display formatted status information including model type, project context, git branch, session duration, and context usage.

## Architecture

The repository contains shell and Go scripts for Claude Code status line functionality:

### Core Scripts (`status_line/`)

#### statusline.sh (Main Shell Implementation)
- Processes Claude Code JSON input via stdin
- Features: Model icon/color, project name, git branch (5s cache), session duration
- Cache directory: `~/.claude/cache/`
- Session tracking: `~/.claude/session-tracker/`

#### statusline.go (Go Implementation)
- Concurrent processing using goroutines for performance
- Additional features: Context usage visualization, user message extraction
- Functions: `updateSession()`, `calculateTotalHours()`, `analyzeContext()`, `extractUserMessage()`
- Supports model-specific colors and icons

#### statusline-p10k.sh (Powerlevel10k Integration)
- Minimal version for Powerlevel10k themes
- Shows model, directory (truncated to 40 chars), git status, virtual env, and time
- Git status indicators: `*` (modified), `+` (staged), `?` (untracked)

#### claude-stats.sh (Session Statistics)
- Track and analyze Claude Code usage time
- Storage: `~/.claude/session-tracker/sessions/` and `/archive/`
- Chinese weekday support
- Archive feature for organizing old sessions by date

## Input/Output Format

### JSON Input Structure
All scripts expect JSON input via stdin with:
```json
{
  "model": {"display_name": "Claude 3.5 Sonnet"},
  "session_id": "session-uuid",
  "workspace": {"current_dir": "/path/to/project"},
  "transcript_path": "/path/to/transcript.json"
}
```

### Output Format
Status line output includes:
- Model indicator with color and icon
- Project name (basename of current directory)
- Git branch (if in git repository)
- Session duration (Go/Shell versions)
- Context usage bar (Go version only)

## Commands

### Testing Status Line Scripts
```bash
# Test with sample JSON input
echo '{"model":{"display_name":"Claude 3.5 Sonnet"},"session_id":"test","workspace":{"current_dir":"'$(pwd)'"}}' | ./status_line/statusline.sh

# Go version (if Go is installed)
echo '{"model":{"display_name":"Claude 3.5 Sonnet"},"session_id":"test","workspace":{"current_dir":"'$(pwd)'"}}' | go run status_line/statusline.go
```

### Session Statistics
```bash
./status_line/claude-stats.sh          # Today's stats
./status_line/claude-stats.sh 2025-08-08  # Specific date
./status_line/claude-stats.sh week     # Current week
./status_line/claude-stats.sh month    # Current month
./status_line/claude-stats.sh all      # All time stats
./status_line/claude-stats.sh archive  # Archive old sessions
```

### Setup Permissions
```bash
chmod +x status_line/*.sh
```

## Configuration

### Model Colors and Icons
- **Claude 3 Opus**: Gold `RGB(195,158,83)` with 💛
- **Claude 3.5 Sonnet**: Cyan `RGB(118,170,185)` with 💠
- **Claude 3 Haiku**: Pink `RGB(255,182,193)` with 🌸

### Context Usage Colors (Go version)
- Green `RGB(108,167,108)`: <33% usage
- Gold `RGB(188,155,83)`: 33-66% usage
- Red `RGB(185,102,82)`: >66% usage

### Directory Structure
```
~/.claude/
├── cache/              # Git branch cache (5s TTL)
│   └── git_branch
└── session-tracker/
    ├── sessions/       # Current session files
    └── archive/        # Historical sessions by date
        └── YYYY-MM-DD/
```