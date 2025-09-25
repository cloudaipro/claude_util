#!/bin/bash
input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model_name=$(echo "$input" | jq -r '.model.display_name')

# Shorten path
[[ "$current_dir" == "$HOME"* ]] && short_dir="~${current_dir#$HOME}" || short_dir="$current_dir"
[[ ${#short_dir} -gt 40 ]] && short_dir="...${short_dir: -37}"

# Git info
git_info=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    cd "$current_dir" 2>/dev/null
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    status=""
    git diff-index --quiet HEAD -- 2>/dev/null || status+="*"
    git diff-index --quiet --cached HEAD -- 2>/dev/null || status+="+"
    [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]] && status+="?"
    git_info=" on \033[36m$branch\033[0m${status:+\033[33m$status\033[0m}"
fi

# Time & venv
current_time=$(date '+%H:%M:%S')
venv_info=""
[[ -n "$VIRTUAL_ENV" ]] && venv_info=" (\033[32m$(basename "$VIRTUAL_ENV")\033[0m)"

printf "\033[34m$model_name\033[0m \033[2min\033[0m \033[35m$short_dir\033[0m$git_info$venv_info \033[2mat\033[0m \033[33m$current_time\033[0m"
