#!/bin/bash

# Read JSON input once at the top
INPUT=$(cat)

# ============================================
# Helper functions for all available data
# ============================================

get_model_name() {
    local name=$(echo "$INPUT" | jq -r '.model.display_name')
    # Extract first letter + version number (e.g., "Opus 4.5" -> "O4.5")
    local first_letter=$(echo "$name" | sed 's/[^a-zA-Z]//g' | cut -c1 | tr '[:lower:]' '[:upper:]')
    local version=$(echo "$name" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    if [ -n "$first_letter" ] && [ -n "$version" ]; then
        echo "${first_letter}${version}"
    else
        echo "${name}"
    fi
}

# Reasoning effort abbreviation, glued to the model name (e.g. "O5·xh").
# Claude Code omits the `effort` key entirely for models with no effort control,
# and an unrecognized level is treated the same way — better to show nothing than
# to invent a label for a level this script has never heard of.
get_effort_abbrev() {
    case "$(echo "$INPUT" | jq -r '.effort.level // empty' 2>/dev/null)" in
        low)    echo "lo" ;;
        medium) echo "md" ;;
        high)   echo "hi" ;;
        xhigh)  echo "xh" ;;
        max)    echo "max" ;;
        *)      echo "" ;;
    esac
}

# Effort colors escalate rather than being arbitrary, so a glance at the model
# segment says how expensive this session's reasoning is.
get_effort_color() {
    case "$(echo "$INPUT" | jq -r '.effort.level // empty' 2>/dev/null)" in
        high)      echo "2;33" ;;  # yellow
        xhigh|max) echo "2;31" ;;  # red
        *)         echo "2;32" ;;  # green (low/medium)
    esac
}

# Extended thinking and fast mode are live session toggles, so they can only come
# from the JSON payload — ~/.claude/settings.json holds the *configured* value and
# goes stale the moment either is toggled mid-session.
thinking_enabled() {
    [ "$(echo "$INPUT" | jq -r '.thinking.enabled // false' 2>/dev/null)" = "true" ]
}

fast_mode_enabled() {
    [ "$(echo "$INPUT" | jq -r '.fast_mode // false' 2>/dev/null)" = "true" ]
}

get_current_dir() {
    echo "$INPUT" | jq -r '.workspace.current_dir'
}

get_project_dir() {
    echo "$INPUT" | jq -r '.workspace.project_dir'
}

get_version() {
    echo "$INPUT" | jq -r '.version'
}

get_session_cost() {
    echo "$INPUT" | jq -r '.cost.total_cost_usd'
}

get_session_id() {
    echo "$INPUT" | jq -r '.session_id'
}

# Usage limit tracking - reads directly from Claude Code's statusline JSON input
# Claude Code provides rate_limits.five_hour and rate_limits.seven_day in the JSON
# No external API calls needed

get_five_hour_utilization() {
    echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // 0' 2>/dev/null || echo "0"
}

get_seven_day_utilization() {
    echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // 0' 2>/dev/null || echo "0"
}

# Generate ASCII progress bar
# Usage: progress_bar <percentage> <width>
# Example: progress_bar 45 10 -> "████░░░░░░"
progress_bar() {
    local pct=$1
    local width=${2:-10}
    local filled=$((pct * width / 100))
    local empty=$((width - filled))

    # Clamp values
    [ "$filled" -lt 0 ] && filled=0
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$empty" -lt 0 ] && empty=0

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# Generate ASCII progress bar with projection
# Usage: progress_bar_projected <current_pct> <projected_pct> <width>
# Example: progress_bar_projected 30 60 10 -> "███▒▒▒░░░░"
# Shows: █ = current, ▒ = projected additional, ░ = empty
progress_bar_projected() {
    local current=$1
    local projected=$2
    local width=${3:-10}

    # Clamp percentages
    [ "$current" -lt 0 ] 2>/dev/null && current=0
    [ "$current" -gt 100 ] 2>/dev/null && current=100
    [ "$projected" -lt "$current" ] 2>/dev/null && projected=$current
    [ "$projected" -gt 100 ] 2>/dev/null && projected=100

    local filled=$((current * width / 100))
    local projected_filled=$((projected * width / 100))
    local dithered=$((projected_filled - filled))
    local empty=$((width - projected_filled))

    # Clamp block counts
    [ "$filled" -lt 0 ] && filled=0
    [ "$dithered" -lt 0 ] && dithered=0
    [ "$empty" -lt 0 ] && empty=0

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<dithered; i++)); do bar+="▒"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo "$bar"
}

# Format seconds into human readable time (e.g., "2h 30m" or "3d 5h")
format_time_remaining() {
    local seconds=$1
    if [ "$seconds" -lt 0 ] 2>/dev/null; then
        echo "0m"
        return
    fi

    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local mins=$(((seconds % 3600) / 60))

    if [ "$days" -gt 0 ]; then
        echo "${days}d${hours}h"
    elif [ "$hours" -gt 0 ]; then
        echo "${hours}h${mins}m"
    else
        echo "${mins}m"
    fi
}

get_five_hour_seconds_remaining() {
    local resets_at=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
    if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
        echo ""
        return
    fi
    # Guard against floats or non-integer values
    local resets_at_int=$(printf '%.0f' "$resets_at" 2>/dev/null)
    if [ -z "$resets_at_int" ]; then echo ""; return; fi
    local now=$(date +%s)
    echo $((resets_at_int - now))
}

get_five_hour_time_remaining() {
    local secs=$(get_five_hour_seconds_remaining)
    if [ -n "$secs" ]; then
        format_time_remaining "$secs"
    else
        echo ""
    fi
}

get_seven_day_seconds_remaining() {
    local resets_at=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
    if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
        echo ""
        return
    fi
    # Guard against floats or non-integer values
    local resets_at_int=$(printf '%.0f' "$resets_at" 2>/dev/null)
    if [ -z "$resets_at_int" ]; then echo ""; return; fi
    local now=$(date +%s)
    echo $((resets_at_int - now))
}

get_seven_day_time_remaining() {
    local secs=$(get_seven_day_seconds_remaining)
    if [ -n "$secs" ]; then
        format_time_remaining "$secs"
    else
        echo ""
    fi
}

# Calculate projected utilization at end of window
# Args: $1 = current utilization (0-100), $2 = seconds remaining, $3 = total window seconds
# Returns: projected percentage (capped at 100)
get_projected_utilization() {
    local util=$1
    local secs_remaining=$2
    local total_window=$3

    # Can't calculate without valid time data - return current
    if [ -z "$secs_remaining" ] || [ "$secs_remaining" -le 0 ] 2>/dev/null; then
        echo "$util"
        return
    fi

    local elapsed=$((total_window - secs_remaining))
    if [ "$elapsed" -le 0 ] 2>/dev/null; then
        echo "$util"  # just started
        return
    fi

    # projected = util * total_window / elapsed
    local projected=$((util * total_window / elapsed))
    [ "$projected" -gt 100 ] && projected=100
    echo "$projected"
}

# Calculate pace color based on utilization and time remaining
# Returns: "red" if at limit, "yellow" if on pace to hit limit, "green" if sustainable
# Args: $1 = utilization (0-100), $2 = projected utilization (0-100)
get_pace_color() {
    local util=$1
    local projected=$2

    # Already at or over limit
    if [ "$util" -ge 100 ] 2>/dev/null; then
        echo "2;31"  # red
        return
    fi

    # On pace to hit limit
    if [ "$projected" -ge 100 ] 2>/dev/null; then
        echo "2;33"  # yellow
    else
        echo "2;32"  # green (sustainable pace)
    fi
}

get_duration() {
    echo "$INPUT" | jq -r '.cost.total_duration_ms'
}

get_lines_added() {
    echo "$INPUT" | jq -r '.cost.total_lines_added'
}

get_lines_removed() {
    echo "$INPUT" | jq -r '.cost.total_lines_removed'
}

get_input_tokens() {
    echo "$INPUT" | jq -r '.context_window.total_input_tokens'
}

get_output_tokens() {
    echo "$INPUT" | jq -r '.context_window.total_output_tokens'
}

get_context_window_size() {
    echo "$INPUT" | jq -r '.context_window.context_window_size'
}

get_current_context_tokens() {
    # Current context = input tokens + cache tokens in current message
    local usage=$(echo "$INPUT" | jq '.context_window.current_usage')
    if [ "$usage" != "null" ]; then
        local input=$(echo "$usage" | jq -r '.input_tokens // 0')
        local cache_create=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
        local cache_read=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
        echo $((input + cache_create + cache_read))
    else
        echo "0"
    fi
}

# Git helpers
get_git_branch() {
    local cwd=$(get_current_dir)
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null
    fi
}

get_git_status() {
    local cwd=$(get_current_dir)
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        if [[ -n $(git -C "$cwd" -c core.useBuiltinFSMonitor=false status --porcelain 2>/dev/null) ]]; then
            echo "dirty"
        else
            echo "clean"
        fi
    fi
}

# ============================================
# Build the status line
# ============================================

build_status_line() {
    local model=$(get_model_name)
    local cwd=$(get_current_dir)
    local display_dir="${cwd/#$HOME/~}"

    # Detect worktree and shorten prefix
    local dir_emoji="📁"
    if [[ "$display_dir" == "~/.worktrees/"* ]]; then
        dir_emoji="🌲"
        display_dir="${display_dir/#~\/.worktrees\//}"
    fi

    # Shorten directory if too long
    if [ ${#display_dir} -gt 30 ]; then
        display_dir="...${display_dir: -27}"
    fi

    # Get metrics
    local session_cost=$(get_session_cost)
    local five_hour_pct=$(get_five_hour_utilization)
    local seven_day_pct=$(get_seven_day_utilization)
    local five_hour_remaining=$(get_five_hour_time_remaining)
    local seven_day_remaining=$(get_seven_day_time_remaining)
    local ctx_size=$(get_context_window_size)

    # Use pre-calculated context percentage from Claude Code
    local current_ctx=$(get_current_context_tokens)
    local ctx_pct=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
    local ctx_pct_int=${ctx_pct%.*}  # Truncate to integer

    # Directory segment (blue) - folder emoji or tree emoji for worktrees (leading space since it follows model on line 2)
    local dir_segment=$(printf " %s \033[2;34m%s\033[0m" "$dir_emoji" "$display_dir")

    # Model segment (cyan) - brain emoji, with effort suffix and live mode flags
    local model_segment=$(printf "🧠 \033[2;36m%s\033[0m" "$model")
    local effort_abbrev=$(get_effort_abbrev)
    if [ -n "$effort_abbrev" ]; then
        model_segment+=$(printf "\033[%sm·%s\033[0m" "$(get_effort_color)" "$effort_abbrev")
    fi
    if thinking_enabled; then
        model_segment+=" 💭"
    fi
    if fast_mode_enabled; then
        model_segment+=" 🚀"
    fi

    # Git segment - branch emoji with ahead/behind remote
    # Branch name is yellow if there are uncommitted changes, green if clean
    local git_segment=""
    local git_branch=$(get_git_branch)
    if [ -n "$git_branch" ]; then
        local cwd=$(get_current_dir)
        local ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        local behind=$(git -C "$cwd" rev-list --count HEAD..@{upstream} 2>/dev/null || echo "0")
        local remote_status=""
        if [ "$ahead" -gt 0 ] 2>/dev/null; then
            remote_status="${remote_status}↑${ahead}"
        fi
        if [ "$behind" -gt 0 ] 2>/dev/null; then
            remote_status="${remote_status}↓${behind}"
        fi
        local git_status=$(get_git_status)
        local branch_color="2;32"  # green (clean)
        if [ "$git_status" = "dirty" ]; then
            branch_color="2;33"  # yellow (uncommitted changes)
        fi
        git_segment=$(printf " 🌿 \033[%sm%s%s\033[0m" "$branch_color" "$git_branch" "$remote_status")
    fi

    # Usage limit segment - shows 5h/7d utilization with projected pace
    local five_hr_int=${five_hour_pct%.*}  # Truncate to integer
    local seven_day_int=${seven_day_pct%.*}

    # Calculate projected utilization at end of each window
    # 5h window = 18000 seconds, 7d window = 604800 seconds
    local five_hr_secs=$(get_five_hour_seconds_remaining)
    local seven_day_secs=$(get_seven_day_seconds_remaining)
    local five_hr_projected=$(get_projected_utilization "$five_hr_int" "$five_hr_secs" 18000)
    local seven_day_projected=$(get_projected_utilization "$seven_day_int" "$seven_day_secs" 604800)

    # Color based on pace: green if sustainable, yellow if on pace to hit limit, red if at limit
    local five_hr_color=$(get_pace_color "$five_hr_int" "$five_hr_projected")
    local seven_day_color=$(get_pace_color "$seven_day_int" "$seven_day_projected")

    # Format: ⚡️ ███▒▒░░░2h30m ██▒░░░░░4d5h (solid=current, dithered=projected)
    local five_hr_bar=$(progress_bar_projected "$five_hr_int" "$five_hr_projected" 8)
    local five_hr_part=$(printf "\033[%sm%s\033[0m" "$five_hr_color" "$five_hr_bar")
    if [ -n "$five_hour_remaining" ]; then
        five_hr_part=$(printf "\033[%sm%s\033[0m%s" "$five_hr_color" "$five_hr_bar" "$five_hour_remaining")
    fi

    local seven_day_bar=$(progress_bar_projected "$seven_day_int" "$seven_day_projected" 8)
    local seven_day_part=$(printf "\033[%sm%s\033[0m" "$seven_day_color" "$seven_day_bar")
    if [ -n "$seven_day_remaining" ]; then
        seven_day_part=$(printf "\033[%sm%s\033[0m%s" "$seven_day_color" "$seven_day_bar" "$seven_day_remaining")
    fi

    local usage_segment=$(printf " ⚡️ %s %s" "$five_hr_part" "$seven_day_part")

    # Cost segment (session cost only now)
    local cost_segment=""
    if [ "$session_cost" != "null" ] && [ "$session_cost" != "0" ]; then
        cost_segment=$(printf " 💰 \033[2;32m\$%.2f\033[0m" "$session_cost")
    fi

    # Lines changed segment - pencil emoji - shows uncommitted git changes (always shown)
    local lines_segment=""
    local cwd=$(get_current_dir)
    if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
        local diff_stats=$(git -C "$cwd" diff --numstat 2>/dev/null | awk '{add+=$1; del+=$2} END {printf "%d %d", add+0, del+0}')
        local staged_stats=$(git -C "$cwd" diff --cached --numstat 2>/dev/null | awk '{add+=$1; del+=$2} END {printf "%d %d", add+0, del+0}')
        local added=$(( ${diff_stats%% *} + ${staged_stats%% *} ))
        local removed=$(( ${diff_stats##* } + ${staged_stats##* } ))
        lines_segment=$(printf " ✏️ \033[2;32m+%d\033[0m/\033[2;31m-%d\033[0m" "$added" "$removed")
    fi

    # Context window segment - progress bar with size in thousands
    # Color based on percentage: green < 70%, yellow 70-85%, red > 85%
    local ctx_color="2;32"  # green
    if [ "$ctx_pct_int" -gt 85 ] 2>/dev/null; then
        ctx_color="2;31"  # red
    elif [ "$ctx_pct_int" -gt 70 ] 2>/dev/null; then
        ctx_color="2;33"  # yellow
    fi
    local ctx_bar=$(progress_bar "$ctx_pct_int" 8)
    local ctx_k=$((current_ctx / 1000))
    local ctx_segment=$(printf "📈 \033[%sm%s\033[0m%dk" "$ctx_color" "$ctx_bar" "$ctx_k")

    # Combine all segments
    # Line 1: context window, rate limits, session cost
    # Line 2: model, directory, git branch, uncommitted changes
    printf "%s%s%s\n%s%s%s%s" \
        "$ctx_segment" \
        "$usage_segment" \
        "$cost_segment" \
        "$model_segment" \
        "$dir_segment" \
        "$git_segment" \
        "$lines_segment"
}

# Execute
build_status_line
