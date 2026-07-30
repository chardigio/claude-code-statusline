#!/bin/bash
# Test script for statusline.sh
# Validates output against expected behavior with various JSON inputs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"
STATUSLINE_API="$SCRIPT_DIR/../statusline-api/statusline.sh"
PASS=0
FAIL=0

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

assert_contains() {
    local test_name="$1"
    local output="$2"
    local expected="$3"
    if echo "$output" | grep -qF "$expected"; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "  Expected to contain: $expected"
        echo "  Got: $output"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local test_name="$1"
    local output="$2"
    local unexpected="$3"
    if ! echo "$output" | grep -qF "$unexpected"; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "  Expected NOT to contain: $unexpected"
        echo "  Got: $output"
        FAIL=$((FAIL + 1))
    fi
}

assert_line_count() {
    local test_name="$1"
    local output="$2"
    local expected_lines="$3"
    local actual_lines=$(echo "$output" | wc -l | tr -d ' ')
    if [ "$actual_lines" -eq "$expected_lines" ]; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "  Expected $expected_lines lines, got $actual_lines"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Statusline Tests ==="
echo ""

# --- Test 1: Basic output with rate limits from JSON input ---
echo "--- Test: Rate limits from JSON input (no external API calls) ---"
BASIC_INPUT='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":1.50,"total_duration_ms":60000,"total_lines_added":10,"total_lines_removed":5},"session_id":"test1","context_window":{"total_input_tokens":50000,"total_output_tokens":10000,"context_window_size":1000000,"used_percentage":5,"remaining_percentage":95,"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":5000}},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":'"$(($(date +%s) + 7200))"'},"seven_day":{"used_percentage":41.2,"resets_at":'"$(($(date +%s) + 432000))"'}}}'

OUTPUT=$(echo "$BASIC_INPUT" | /bin/bash "$STATUSLINE" 2>/dev/null)
# Strip ANSI codes for matching
CLEAN=$(echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g')

assert_contains "Model name abbreviated" "$CLEAN" "O4.6"
assert_contains "Has lightning bolt for rate limits" "$CLEAN" "⚡️"
assert_contains "Has context indicator" "$CLEAN" "📈"
assert_line_count "Output is 2 lines" "$OUTPUT" 2
# Verify rate limit data from JSON input is rendered (23.5% → 1 filled block of 8)
assert_contains "Rate limit bars rendered from JSON input" "$CLEAN" "█"

# --- Test 2: Rate limits absent (API key user) ---
echo ""
echo "--- Test: No rate limits (API key user) ---"
NO_LIMITS_INPUT='{"model":{"display_name":"Sonnet 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test2","context_window":{"total_input_tokens":1000,"total_output_tokens":500,"context_window_size":200000,"used_percentage":1,"remaining_percentage":99,"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

OUTPUT2=$(echo "$NO_LIMITS_INPUT" | /bin/bash "$STATUSLINE" 2>/dev/null)
CLEAN2=$(echo "$OUTPUT2" | sed 's/\x1b\[[0-9;]*m//g')

assert_contains "Model name S4.6" "$CLEAN2" "S4.6"
assert_line_count "Output is 2 lines" "$OUTPUT2" 2

# --- Test 3: Context window with 1M context (should show low percentage) ---
echo ""
echo "--- Test: 1M context window display ---"
LARGE_CTX_INPUT='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":5.00,"total_duration_ms":120000,"total_lines_added":200,"total_lines_removed":100},"session_id":"test3","context_window":{"total_input_tokens":150000,"total_output_tokens":30000,"context_window_size":1000000,"used_percentage":18,"remaining_percentage":82,"current_usage":{"input_tokens":100000,"cache_creation_input_tokens":30000,"cache_read_input_tokens":20000}},"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":'"$(($(date +%s) + 3600))"'},"seven_day":{"used_percentage":60,"resets_at":'"$(($(date +%s) + 259200))"'}}}'

OUTPUT3=$(echo "$LARGE_CTX_INPUT" | /bin/bash "$STATUSLINE" 2>/dev/null)
CLEAN3=$(echo "$OUTPUT3" | sed 's/\x1b\[[0-9;]*m//g')

# Context should show the pre-calculated percentage (18%), displayed as "150k"
assert_contains "Context shows token count in k" "$CLEAN3" "150k"
assert_contains "Has cost segment" "$CLEAN3" "$5.00"

# --- Test 4: Time remaining formatting ---
echo ""
echo "--- Test: Time remaining from Unix epoch resets_at ---"
# Set resets_at 2 hours from now for 5hr, 3 days from now for 7day
FIVE_HR_RESET=$(($(date +%s) + 7200))
SEVEN_DAY_RESET=$(($(date +%s) + 259200))
TIME_INPUT='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test4","context_window":{"total_input_tokens":5000,"total_output_tokens":1000,"context_window_size":200000,"used_percentage":3,"remaining_percentage":97,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":'"$FIVE_HR_RESET"'},"seven_day":{"used_percentage":50,"resets_at":'"$SEVEN_DAY_RESET"'}}}'

OUTPUT4=$(echo "$TIME_INPUT" | /bin/bash "$STATUSLINE" 2>/dev/null)
CLEAN4=$(echo "$OUTPUT4" | sed 's/\x1b\[[0-9;]*m//g')

# Should show time remaining like "2h0m" and "3d0h" (approximately)
assert_contains "5hr time remaining shows hours" "$CLEAN4" "h"
assert_contains "7day time remaining shows days" "$CLEAN4" "d"

# --- Test 5: Context window color thresholds ---
echo ""
echo "--- Test: Context window color thresholds ---"

# Helper to build input with specific used_percentage
make_ctx_input() {
    local pct=$1
    echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test-ctx","context_window":{"total_input_tokens":50000,"total_output_tokens":10000,"context_window_size":200000,"used_percentage":'"$pct"',"remaining_percentage":'"$((100-pct))"',"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":5000}}}'
}

# Green: < 70%
OUTPUT_GREEN=$(echo "$(make_ctx_input 50)" | /bin/bash "$STATUSLINE" 2>/dev/null)
assert_contains "Context < 70% is green" "$OUTPUT_GREEN" $'\033[2;32m'

# Yellow: 70-85%
OUTPUT_YELLOW=$(echo "$(make_ctx_input 75)" | /bin/bash "$STATUSLINE" 2>/dev/null)
assert_contains "Context 70-85% is yellow" "$OUTPUT_YELLOW" $'\033[2;33m'

# Red: > 85%
OUTPUT_RED=$(echo "$(make_ctx_input 90)" | /bin/bash "$STATUSLINE" 2>/dev/null)
assert_contains "Context > 85% is red" "$OUTPUT_RED" $'\033[2;31m'

# --- Test 6: Float resets_at values (guard against non-integer) ---
echo ""
echo "--- Test: Float resets_at values ---"
FLOAT_RESET_5H=$(echo "$(date +%s) + 7200.5" | bc)
FLOAT_RESET_7D=$(echo "$(date +%s) + 432000.9" | bc)
FLOAT_INPUT='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test-float","context_window":{"total_input_tokens":5000,"total_output_tokens":1000,"context_window_size":200000,"used_percentage":3,"remaining_percentage":97,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":'"$FLOAT_RESET_5H"'},"seven_day":{"used_percentage":40,"resets_at":'"$FLOAT_RESET_7D"'}}}'

OUTPUT_FLOAT=$(echo "$FLOAT_INPUT" | /bin/bash "$STATUSLINE" 2>/dev/null)
CLEAN_FLOAT=$(echo "$OUTPUT_FLOAT" | sed 's/\x1b\[[0-9;]*m//g')
assert_contains "Float resets_at shows hours" "$CLEAN_FLOAT" "h"
assert_contains "Float resets_at shows days" "$CLEAN_FLOAT" "d"

# --- Test 7: statusline-api variant ---
echo ""
echo "--- Test: statusline-api variant ---"
if [ -f "$STATUSLINE_API" ]; then
    API_INPUT='{"model":{"display_name":"Sonnet 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":1.25,"total_duration_ms":30000,"total_lines_added":10,"total_lines_removed":5},"session_id":"test-api","context_window":{"total_input_tokens":50000,"total_output_tokens":10000,"context_window_size":200000,"used_percentage":30,"remaining_percentage":70,"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":5000}}}'
    OUTPUT_API=$(echo "$API_INPUT" | /bin/bash "$STATUSLINE_API" 2>/dev/null)
    CLEAN_API=$(echo "$OUTPUT_API" | sed 's/\x1b\[[0-9;]*m//g')

    assert_contains "API variant shows model" "$CLEAN_API" "S4.6"
    assert_contains "API variant shows context" "$CLEAN_API" "📈"
    assert_line_count "API variant is 2 lines" "$OUTPUT_API" 2

    # API variant context color thresholds (percentage-based)
    API_GREEN=$(echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.105","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test","context_window":{"total_input_tokens":50000,"total_output_tokens":10000,"context_window_size":1000000,"used_percentage":5,"remaining_percentage":95,"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":5000}}}' | /bin/bash "$STATUSLINE_API" 2>/dev/null)
    assert_contains "API variant low ctx is green" "$API_GREEN" $'\033[2;32m'
else
    echo "SKIP: statusline-api variant not found at $STATUSLINE_API"
fi

# --- Test 8: Effort level / thinking / fast mode indicators ---
echo ""
echo "--- Test: Effort, thinking, and fast mode indicators ---"

# Builds a minimal payload, splicing an extra JSON fragment into the root so each
# case can toggle just the effort/thinking/fast_mode keys under test.
make_flags_input() {
    local extra=$1
    local sep=""
    [ -n "$extra" ] && sep=","
    echo '{"model":{"display_name":"Opus 5"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"},"version":"2.1.220","cost":{"total_cost_usd":0,"total_duration_ms":1000,"total_lines_added":0,"total_lines_removed":0},"session_id":"test-flags","context_window":{"total_input_tokens":5000,"total_output_tokens":1000,"context_window_size":200000,"used_percentage":3,"remaining_percentage":97,"current_usage":{"input_tokens":5000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}'"$sep$extra"'}'
}

# Renders both variants for the same payload so the two scripts can never drift.
run_flags() {
    local script=$1
    local extra=$2
    make_flags_input "$extra" | /bin/bash "$script" 2>/dev/null
}

for VARIANT in "$STATUSLINE:full" "$STATUSLINE_API:api"; do
    SCRIPT="${VARIANT%:*}"
    LABEL="${VARIANT##*:}"
    [ -f "$SCRIPT" ] || { echo "SKIP: $LABEL variant not found at $SCRIPT"; continue; }

    # Every effort level renders its abbreviation glued to the model name
    for PAIR in "low:O5·lo" "medium:O5·md" "high:O5·hi" "xhigh:O5·xh" "max:O5·max"; do
        LEVEL="${PAIR%:*}"
        EXPECTED="${PAIR##*:}"
        OUT=$(run_flags "$SCRIPT" '"effort":{"level":"'"$LEVEL"'"}' | sed 's/\x1b\[[0-9;]*m//g')
        assert_contains "[$LABEL] effort $LEVEL renders $EXPECTED" "$OUT" "$EXPECTED"
    done

    # Models without reasoning effort omit the key entirely - render nothing
    OUT=$(run_flags "$SCRIPT" "" | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "[$LABEL] no effort key still shows model" "$OUT" "O5"
    assert_not_contains "[$LABEL] no effort key omits suffix" "$OUT" "·"

    # Effort color escalates: green low/medium, yellow high, red xhigh/max
    assert_contains "[$LABEL] effort low is green" \
        "$(run_flags "$SCRIPT" '"effort":{"level":"low"}')" $'\033[2;32m·lo'
    assert_contains "[$LABEL] effort medium is green" \
        "$(run_flags "$SCRIPT" '"effort":{"level":"medium"}')" $'\033[2;32m·md'
    assert_contains "[$LABEL] effort high is yellow" \
        "$(run_flags "$SCRIPT" '"effort":{"level":"high"}')" $'\033[2;33m·hi'
    assert_contains "[$LABEL] effort xhigh is red" \
        "$(run_flags "$SCRIPT" '"effort":{"level":"xhigh"}')" $'\033[2;31m·xh'
    assert_contains "[$LABEL] effort max is red" \
        "$(run_flags "$SCRIPT" '"effort":{"level":"max"}')" $'\033[2;31m·max'

    # An unrecognized future level must not render a bogus suffix
    OUT=$(run_flags "$SCRIPT" '"effort":{"level":"ultra"}' | sed 's/\x1b\[[0-9;]*m//g')
    assert_not_contains "[$LABEL] unknown effort level omits suffix" "$OUT" "·"

    # Thinking indicator
    assert_contains "[$LABEL] thinking enabled shows 💭" \
        "$(run_flags "$SCRIPT" '"thinking":{"enabled":true}')" "💭"
    assert_not_contains "[$LABEL] thinking disabled hides 💭" \
        "$(run_flags "$SCRIPT" '"thinking":{"enabled":false}')" "💭"
    assert_not_contains "[$LABEL] thinking key absent hides 💭" \
        "$(run_flags "$SCRIPT" "")" "💭"

    # Fast mode indicator
    assert_contains "[$LABEL] fast_mode true shows 🚀" \
        "$(run_flags "$SCRIPT" '"fast_mode":true')" "🚀"
    assert_not_contains "[$LABEL] fast_mode false hides 🚀" \
        "$(run_flags "$SCRIPT" '"fast_mode":false')" "🚀"
    assert_not_contains "[$LABEL] fast_mode key absent hides 🚀" \
        "$(run_flags "$SCRIPT" "")" "🚀"

    # All three together, in model → effort → thinking → fast order
    OUT=$(run_flags "$SCRIPT" '"effort":{"level":"xhigh"},"thinking":{"enabled":true},"fast_mode":true' | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "[$LABEL] effort + thinking + fast render together" "$OUT" "O5·xh 💭 🚀"
    assert_line_count "[$LABEL] flags keep output at 2 lines" "$OUT" 2
done

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
