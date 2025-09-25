#!/bin/bash

# Read input
input=$(cat)

# Cache file paths
CACHE_DIR="$HOME/.claude/cache"
GIT_CACHE="$CACHE_DIR/git_branch"
mkdir -p "$CACHE_DIR"

# Parse JSON input with single jq invocation
read -r MODEL SESSION_ID CURRENT_DIR TRANSCRIPT_PATH <<< $(echo "$input" | jq -r '
    .model.display_name,
    .session_id,
    .workspace.current_dir // .cwd,
    (.transcript_path // "")
' | tr '\n' ' ')

PROJECT_NAME=$(basename "$CURRENT_DIR")

# Model colors and icons based on PRD
MODEL_COLOR=""
MODEL_ICON=""
case "$MODEL" in
    *"Opus"*)
        MODEL_COLOR="\033[38;2;195;158;83m"
        MODEL_ICON="💛"
        ;;
    *"Sonnet"*)
        MODEL_COLOR="\033[38;2;118;170;185m"
        MODEL_ICON="💠"
        ;;
    *"Haiku"*)
        MODEL_COLOR="\033[38;2;255;182;193m"
        MODEL_ICON="🌸"
        ;;
    *)
        MODEL_COLOR="\033[34m"
        MODEL_ICON="🤖"
        ;;
esac

COLOR_RESET="\033[0m"
COLOR_GRAY="\033[38;2;64;64;64m"
COLOR_GREEN="\033[38;2;108;167;108m"
COLOR_GOLD="\033[38;2;188;155;83m"
COLOR_RED="\033[38;2;185;102;82m"
COLOR_MESSAGE="\033[38;2;152;195;121m"

# Shorten path for p10k style
[[ "$CURRENT_DIR" == "$HOME"* ]] && short_dir="~${CURRENT_DIR#$HOME}" || short_dir="$CURRENT_DIR"
[[ ${#short_dir} -gt 40 ]] && short_dir="...${short_dir: -37}"

# Git branch with 5-second cache
git_info=""
if git -C "$CURRENT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    current_time=$(date +%s)
    BRANCH=""

    # Check cache validity
    if [ -f "$GIT_CACHE" ]; then
        cache_time=$(stat -f %m "$GIT_CACHE" 2>/dev/null || stat -c %Y "$GIT_CACHE" 2>/dev/null)
        if [ $((current_time - cache_time)) -lt 5 ]; then
            BRANCH=$(cat "$GIT_CACHE")
        fi
    fi

    # Cache expired or doesn't exist
    if [ -z "$BRANCH" ]; then
        cd "$CURRENT_DIR" 2>/dev/null
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        status=""
        git diff-index --quiet HEAD -- 2>/dev/null || status+="*"
        git diff-index --quiet --cached HEAD -- 2>/dev/null || status+="+"
        [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]] && status+="?"
        BRANCH="$branch${status:+$status}"
        echo "$BRANCH" > "$GIT_CACHE"
    fi

    git_info=" on \033[36m⚡${BRANCH}\033[0m"
fi

# Session tracking directory
TRACKER_DIR="$HOME/.claude/session-tracker"
SESSIONS_DIR="$TRACKER_DIR/sessions"
mkdir -p "$SESSIONS_DIR"

# Current time
CURRENT_TIME=$(date +%s)
TODAY=$(date +%Y-%m-%d)

# Update session function
update_session() {
    local session_file="$SESSIONS_DIR/$SESSION_ID.json"

    if [ ! -f "$session_file" ]; then
        # New session
        cat > "$session_file" <<EOF
{
    "id": "$SESSION_ID",
    "date": "$TODAY",
    "start": $CURRENT_TIME,
    "last_heartbeat": $CURRENT_TIME,
    "total_seconds": 0,
    "intervals": [{"start": $CURRENT_TIME, "end": null}]
}
EOF
    else
        # Update existing session
        jq --argjson now "$CURRENT_TIME" '
            . as $orig |
            ($now - .last_heartbeat) as $gap |
            .last_heartbeat = $now |
            if $gap < 600 then
                .intervals[-1].end = $now
            else
                .intervals += [{"start": $now, "end": $now}]
            end |
            .total_seconds = ([.intervals[] | if .end != null then (.end - .start) else 0 end] | add // 0)
        ' "$session_file" > "$session_file.tmp" && mv "$session_file.tmp" "$session_file"
    fi
}

# Calculate total hours for today
calculate_total_hours() {
    local total_seconds=0
    local active_sessions=0

    while IFS= read -r -d '' session_file; do
        read -r session_date session_seconds last_heartbeat <<< $(jq -r '
            .date // "",
            (.total_seconds // 0),
            (.last_heartbeat // 0)
        ' "$session_file" 2>/dev/null | tr '\n' ' ')

        if [ "$session_date" = "$TODAY" ] && [ -n "$session_seconds" ]; then
            total_seconds=$((total_seconds + session_seconds))

            if [ $((CURRENT_TIME - last_heartbeat)) -lt 600 ]; then
                active_sessions=$((active_sessions + 1))
            fi
        fi
    done < <(find "$SESSIONS_DIR" -name "*.json" -print0 2>/dev/null)

    # Format output
    local hours=$((total_seconds / 3600))
    local minutes=$(((total_seconds % 3600) / 60))

    local time_str=""
    if [ $hours -gt 0 ]; then
        time_str="${hours}h"
        [ $minutes -gt 0 ] && time_str="${time_str}${minutes}m"
    else
        time_str="${minutes}m"
    fi

    [ $active_sessions -gt 1 ] && echo "$time_str [$active_sessions]" || echo "$time_str"
}

# Archive old sessions
archive_old_sessions() {
    find "$SESSIONS_DIR" -name "*.json" -exec sh -c '
        for file; do
            session_date=$(jq -r ".date // \"\"" "$file" 2>/dev/null)
            if [ "$session_date" != "'"$TODAY"'" ] && [ -n "$session_date" ]; then
                archive_dir="'"$TRACKER_DIR"'/archive/$session_date"
                mkdir -p "$archive_dir"
                mv "$file" "$archive_dir/"
            fi
        done
    ' sh {} +
}

# Context usage calculation
calculate_context_usage() {
    local transcript_path="$1"

    [ ! -f "$transcript_path" ] && { echo "0"; return; }

    tail -100 "$transcript_path" 2>/dev/null | awk '
        {
            if (match($0, /"isSidechain":[[:space:]]*false/) &&
                match($0, /"usage":[[:space:]]*\{/)) {

                input_tokens = 0
                cache_read = 0
                cache_creation = 0

                if (match($0, /"input_tokens":[[:space:]]*([0-9]+)/, arr))
                    input_tokens = arr[1]
                if (match($0, /"cache_read_input_tokens":[[:space:]]*([0-9]+)/, arr))
                    cache_read = arr[1]
                if (match($0, /"cache_creation_input_tokens":[[:space:]]*([0-9]+)/, arr))
                    cache_creation = arr[1]

                context_length = input_tokens + cache_read + cache_creation
                if (context_length > 0) {
                    print context_length
                    exit
                }
            }
        }
        END { if (NR == 0 || context_length == 0) print "0" }
    '
}

# Format number with K/M notation
format_number() {
    local num="$1"

    [ -z "$num" ] || [ "$num" = "0" ] && { echo ""; return; }

    if [ "$num" -ge 1000000 ]; then
        echo "$((num / 1000000))M"
    elif [ "$num" -ge 1000 ]; then
        echo "$((num / 1000))k"
    else
        echo "$num"
    fi
}

# Generate compact progress bar for p10k
generate_progress_bar() {
    local percentage="$1"
    local width=5  # Smaller for p10k

    local filled=$(( percentage * width / 100 ))
    [ "$filled" -lt 0 ] && filled=0
    [ "$filled" -gt "$width" ] && filled=$width

    local empty=$((width - filled))

    # Get color based on percentage
    local bar_color=""
    if [ "$percentage" -lt 60 ]; then
        bar_color="$COLOR_GREEN"
    elif [ "$percentage" -lt 80 ]; then
        bar_color="$COLOR_GOLD"
    else
        bar_color="$COLOR_RED"
    fi

    # Generate bar
    local bar=""

    if [ $filled -gt 0 ]; then
        bar="${bar}${bar_color}"
        for ((i=0; i<filled; i++)); do
            bar="${bar}█"
        done
        bar="${bar}${COLOR_RESET}"
    fi

    if [ $empty -gt 0 ]; then
        bar="${bar}${COLOR_GRAY}"
        for ((i=0; i<empty; i++)); do
            bar="${bar}░"
        done
        bar="${bar}${COLOR_RESET}"
    fi

    echo "$bar"
}

# Extract last user message
extract_last_user_message() {
    local transcript_path="$1"
    local current_session_id="$2"

    [ ! -f "$transcript_path" ] && return

    tail -200 "$transcript_path" 2>/dev/null | tac | awk -v session_id="$current_session_id" '
        /^$/ { next }
        {
            if (!match($0, /^\{.*\}$/)) next

            is_sidechain = match($0, /"isSidechain":[[:space:]]*true/)
            session_match = match($0, /"sessionId":[[:space:]]*"'"'"'"$current_session_id"'"'"'"/)
            is_user = match($0, /"role":[[:space:]]*"user"/) && match($0, /"type":[[:space:]]*"user"/)

            if (!is_sidechain && session_match && is_user) {
                if (match($0, /"content":[[:space:]]*"([^"]*)"/, arr)) {
                    content = arr[1]

                    if (match(content, /^[\[\{].*[\]\}]$/) ||
                        match(content, /<(local-command-stdout|command-name|command-message|command-args)>/) ||
                        match(content, /^Caveat:/) ||
                        content == "" || content == "null") {
                        next
                    }

                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", content)
                    if (length(content) > 0) {
                        print content
                        exit
                    }
                }
            }
        }
    '
}

# Main execution
update_session
archive_old_sessions
TOTAL_HOURS=$(calculate_total_hours)

# Context usage
CONTEXT_USAGE=""
if [ -n "$TRANSCRIPT_PATH" ] && [ "$TRANSCRIPT_PATH" != "null" ] && [ "$TRANSCRIPT_PATH" != "" ]; then
    CONTEXT_LENGTH=$(calculate_context_usage "$TRANSCRIPT_PATH")

    if [ -n "$CONTEXT_LENGTH" ] && [ "$CONTEXT_LENGTH" != "0" ]; then
        CONTEXT_PERCENTAGE=$((CONTEXT_LENGTH * 100 / 200000))
        [ "$CONTEXT_PERCENTAGE" -gt 100 ] && CONTEXT_PERCENTAGE=100

        PROGRESS_BAR=$(generate_progress_bar "$CONTEXT_PERCENTAGE")
        FORMATTED_NUM=$(format_number "$CONTEXT_LENGTH")

        # Color for percentage
        if [ "$CONTEXT_PERCENTAGE" -lt 60 ]; then
            PCT_COLOR="$COLOR_GREEN"
        elif [ "$CONTEXT_PERCENTAGE" -lt 80 ]; then
            PCT_COLOR="$COLOR_GOLD"
        else
            PCT_COLOR="$COLOR_RED"
        fi

        CONTEXT_USAGE=" ${PROGRESS_BAR} ${PCT_COLOR}${CONTEXT_PERCENTAGE}%${COLOR_RESET}"
        [ -n "$FORMATTED_NUM" ] && CONTEXT_USAGE="${CONTEXT_USAGE} ${FORMATTED_NUM}"
    fi

    # Extract user message for compact display
    LAST_USER_MESSAGE=$(extract_last_user_message "$TRANSCRIPT_PATH" "$SESSION_ID")
fi

# Virtual env info
venv_info=""
[[ -n "$VIRTUAL_ENV" ]] && venv_info=" (\033[32m$(basename "$VIRTUAL_ENV")\033[0m)"

# Output status line in p10k style
# Model with icon | Directory | Git | Context | Time | Hours
printf "${MODEL_COLOR}${MODEL_ICON} ${MODEL}${COLOR_RESET} \033[2min\033[0m \033[35m${short_dir}\033[0m${git_info}${CONTEXT_USAGE}${venv_info} | ${TOTAL_HOURS}"

# Optionally add truncated user message (very compact for p10k)
if [ -n "$LAST_USER_MESSAGE" ]; then
    # Truncate to max 50 chars for p10k
    TRUNCATED_MSG="${LAST_USER_MESSAGE:0:50}"
    [ ${#LAST_USER_MESSAGE} -gt 50 ] && TRUNCATED_MSG="${TRUNCATED_MSG}..."
    printf " ${COLOR_GRAY}｜${COLOR_MESSAGE}${TRUNCATED_MSG}${COLOR_RESET}"
fi