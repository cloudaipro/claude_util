# Product Requirements Document (PRD)
## Claude Code Status Line Shell Script (statusline.sh)

### Executive Summary
A high-performance shell script that provides real-time status information for Claude Code sessions, including model identification, project context, Git integration, session time tracking, context usage visualization, and user message display.

### Product Overview

#### Purpose
Enable Claude Code users to visualize critical session information in their terminal status line, providing instant feedback about their current AI assistant context, usage metrics, and project state.

#### Target Users
- Claude Code users
- Developers using terminal-based workflows
- Users requiring session time tracking and usage monitoring

### Core Features

#### 1. Model Identification & Visualization
**Description**: Automatically detect and display the active Claude model with visual indicators.

**Requirements**:
- Parse model name from JSON input (`model.display_name`)
- Apply model-specific color schemes and icons:
  - Claude Opus: Gold (RGB 195,158,83) + 💛 emoji
  - Claude Sonnet: Cyan (RGB 118,170,185) + 💠 emoji  
- Display format: `[icon MODEL_NAME]`

#### 2. Project Context Display
**Description**: Show current working directory project name.

**Requirements**:
- Extract project name from `workspace.current_dir`
- Display basename of directory (last path component)
- Format: `📂 PROJECT_NAME`

#### 3. Git Branch Integration with Caching
**Description**: Display current Git branch with optimized caching mechanism.

**Requirements**:
- Detect if current directory is a Git repository
- Cache branch name for 5 seconds to reduce Git operations
- Cache location: `~/.claude/cache/git_branch`
- Check cache validity using file modification time
- Display format: `⚡ BRANCH_NAME`
- Gracefully handle non-Git directories (no display)

#### 4. Session Time Tracking
**Description**: Track and accumulate time spent in Claude Code sessions.

**Requirements**:
- Create unique session files in `~/.claude/session-tracker/sessions/`
- Track session intervals with start/end timestamps
- Consider session active if heartbeat within 10 minutes (600 seconds)
- Calculate total time for all sessions today
- Display multiple active sessions count when applicable
- Format: `Xh Ym` or `Ym` (hours omitted if zero)

**Session File Structure**:
```json
{
    "id": "session-uuid",
    "date": "YYYY-MM-DD",
    "start": timestamp,
    "last_heartbeat": timestamp,
    "total_seconds": number,
    "intervals": [{"start": timestamp, "end": timestamp}]
}
```

#### 5. Automatic Session Archiving
**Description**: Archive old session files to maintain performance.

**Requirements**:
- Move non-today sessions to date-based archive folders
- Archive structure: `~/.claude/session-tracker/archive/YYYY-MM-DD/`
- Run automatically on each script execution
- Preserve session data integrity during archiving

#### 6. Context Usage Visualization
**Description**: Display Claude's context window usage as percentage and visual progress bar.

**Requirements**:
- Parse transcript file for usage metrics
- Calculate total tokens: `input_tokens + cache_read + cache_creation`
- Maximum context: 200,000 tokens
- Display components:
  - 10-character progress bar with filled/empty segments
  - Percentage value (0-100%)
  - Formatted token count (K/M notation)
- Color coding by usage level:
  - Green (RGB 108,167,108): <60%
  - Gold (RGB 188,155,83): 60-80%
  - Red (RGB 185,102,82): >80%

#### 7. User Message Extraction & Display
**Description**: Extract and display the last user message from current session.

**Requirements**:
- Parse last 200 lines of transcript (performance optimization)
- Filter criteria:
  - Match current session ID
  - Role = "user", type = "user"
  - Not sidechain message
  - Not command/system message
- Display formatting:
  - Maximum 3 lines
  - 80 characters per line (truncate with "...")
  - Prefix with colored pipe character (｜)
  - Show line count if truncated

### Technical Specifications

#### Input Format
JSON via stdin with structure:
```json
{
    "model": {"display_name": "Claude 3.5 Sonnet"},
    "session_id": "uuid",
    "workspace": {"current_dir": "/path/to/project"},
    "transcript_path": "/path/to/transcript.json"
}
```

#### Output Format
Two-line status display:
1. Status line: `[model] 📂 project branch | progress% tokens | time`
2. User message lines (optional, max 3 lines)

#### Dependencies
- **bash**: Shell interpreter
- **jq**: JSON parsing (1.6+)
- **git**: Branch detection
- **awk**: Text processing
- **Standard utilities**: cat, date, find, tail, tac, stat, mkdir, mv

#### Performance Optimizations
1. **Single jq invocations**: Minimize process spawning
2. **Git branch caching**: 5-second TTL
3. **Batch file processing**: Use find with -exec
4. **Tail sampling**: Process last 100-200 lines only
5. **AWK processing**: Replace multiple grep/sed chains
6. **Bash built-in arithmetic**: Avoid external calculators

### File System Structure
```
~/.claude/
├── cache/
│   └── git_branch          # 5-second TTL cache
└── session-tracker/
    ├── sessions/           # Active session files
    │   └── {session-id}.json
    └── archive/           # Historical sessions
        └── YYYY-MM-DD/
            └── {session-id}.json
```

### Error Handling
- Graceful degradation when transcript unavailable
- Handle missing Git repositories silently
- Default values for missing JSON fields
- Safe file operations with atomic moves
- Validate JSON parsing before processing

### Localization
- Chinese comments throughout codebase
- Chinese text in user message truncation indicator
- Support for both GNU (Linux) and BSD (macOS) utilities

### Performance Requirements
- Script execution: <100ms typical
- Git operations: Cached for 5 seconds
- Session updates: Atomic file operations
- Memory usage: Minimal (streaming processing)

### Security Considerations
- No sensitive data in cache files
- Proper file permissions on session data
- Safe handling of user input via jq parsing
- No command injection vulnerabilities

### Future Enhancements
- Configurable color schemes
- Multiple language support
- Extended context window support (>200k)
- Session statistics aggregation
- Integration with other shell frameworks

### Success Metrics
- Execution time under 100ms
- Zero data loss in session tracking
- Accurate context usage calculation
- Reliable Git branch detection
- Proper message extraction and formatting