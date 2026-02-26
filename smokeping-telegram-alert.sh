#!/bin/bash

# Telegram Bot Configuration
BOT_TOKEN="Enter Your Bot Token Here"  # Replace with your bot token
CHAT_ID="-Enter Your Chat ID Here"      # Replace with your chat ID

#!/bin/bash

#==============================================================================
# Smokeping Telegram Alert - v6.1 (ipinfo.io Support)
#==============================================================================

IPINFO_TOKEN="Enter your IPinfo Api Token here"  # <-- PASTE TOKEN HERE
DASHBOARD_URL="http://add-dashboard-url-here/smokeping.cgi"
LOG_FILE="/var/log/smokeping/telegram-alerts.log"

# Ensure log exists
touch "$LOG_FILE" 2>/dev/null && chmod 666 "$LOG_FILE" 2>/dev/null

#==============================================================================
# 1. Capture Arguments
#==============================================================================
ALERT_NAME="${1:-Unknown}"
TARGET_RAW="${2:-Unknown}"
LOSS_STR="${3:-0%}"
RTT_STR="${4:-0ms}"
HOSTNAME="${5:-N/A}"

#==============================================================================
# 2. Smart Data Extraction
#==============================================================================
#==============================================================================
# 2. Data Extraction (Logic Fix: Get LATEST value)
#==============================================================================

# Function to get the LATEST value (Last item in comma list)
# OLD: "100%, 100%, 0%" -> gave 100 (Max) -> FAILED to detect recovery
# NEW: "100%, 100%, 0%" -> gives 0 (Last) -> SUCCESS
get_val() {
    # Extract numbers, replace newlines with commas just in case
    # Then grab the very last number found (tail -1)
    echo "$1" | grep -oE '[0-9]+' | tail -1 || echo "0"
}

LOSS_VAL=$(get_val "$LOSS_STR")
RTT_VAL=$(get_val "$RTT_STR")

# Cleanup Target Name
LAST_PART=$(echo "$TARGET_RAW" | awk -F'.' '{print $NF}')
if [[ "$LAST_PART" =~ ^[0-9] ]]; then
    PARENT_PART=$(echo "$TARGET_RAW" | awk -F'.' '{print $(NF-1)}')
    CLEAN_TARGET="$PARENT_PART ($LAST_PART)"
else
    CLEAN_TARGET="$LAST_PART"
fi
CLEAN_TARGET=$(echo "$CLEAN_TARGET" | tr '_' ' ')
[ -z "$CLEAN_TARGET" ] && CLEAN_TARGET="$TARGET_RAW"

# --- GEO-LOCATION LOOKUP (ipinfo.io) ---
REGION_INFO=""
if [[ "$HOSTNAME" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    # Fetch JSON from ipinfo.io
    # We use a 3-second timeout to ensure the script doesn't hang
    GEO_JSON=$(curl -s --max-time 3 "https://ipinfo.io/${HOSTNAME}?token=${IPINFO_TOKEN}")
    
    # Extract City and Country using grep/sed (avoids installing 'jq')
    CITY=$(echo "$GEO_JSON" | grep -oP '"city":\s*"\K[^"]+')
    COUNTRY=$(echo "$GEO_JSON" | grep -oP '"country":\s*"\K[^"]+')
    ORG=$(echo "$GEO_JSON" | grep -oP '"org":\s*"\K[^"]+' | sed 's/AS[0-9]* //') 

    # Combine them nicely
    if [ -n "$CITY" ]; then
        REGION_INFO="$CITY, $COUNTRY"
        # Optional: Append ISP/Org if you want (uncomment line below)
        # REGION_INFO="$CITY, $COUNTRY ($ORG)"
    fi
fi

#==============================================================================
# 3. Status Logic
#==============================================================================

#==============================================================================
# 3. Smart Status Logic
#==============================================================================
#==============================================================================
# 3. Smart Status Logic (Context-Aware Naming)
#==============================================================================

STATUS="ALERT"
ICON="🔴"
HEADER="CRITICAL ALERT"

# --- AUTO-DETECT THRESHOLDS ---
DETECTED_NUM=$(echo "$ALERT_NAME" | grep -oE '[0-9]+' | head -1)
T_RTT=${DETECTED_NUM:-55}

# --- DETERMINE STATUS ---
IS_RECOVERED=false

if [[ "$ALERT_NAME" == *"electricity"* ]]; then
    if [ "$LOSS_VAL" -lt 100 ]; then IS_RECOVERED=true; fi

elif [[ "$ALERT_NAME" == *"latency"* ]] || [[ "$ALERT_NAME" == *"rtt"* ]]; then
    if [ "$RTT_VAL" -lt "$T_RTT" ]; then IS_RECOVERED=true; fi

elif [[ "$ALERT_NAME" == *"loss"* ]]; then
    if [ "$LOSS_VAL" -eq 0 ]; then IS_RECOVERED=true; fi
    
else
    # Fallback
    if [ "$LOSS_VAL" -eq 0 ] && [ "$RTT_VAL" -lt 55 ]; then IS_RECOVERED=true; fi
fi

# --- APPLY SMART HEADERS ---

if [ "$IS_RECOVERED" = true ]; then
    STATUS="RECOVERED"
    ICON="✅"
    
    # Dynamic Success Message based on Alert Type
    if [[ "$ALERT_NAME" == *"electricity"* ]]; then
        HEADER="Power Restored in Server Room"
    elif [[ "$ALERT_NAME" == *"latency"* ]] || [[ "$ALERT_NAME" == *"rtt"* ]]; then
        HEADER="Latency is now optimal"
    elif [[ "$ALERT_NAME" == *"loss"* ]]; then
        HEADER="Packet Loss Recovered"
    else
        HEADER="Issue Resolved"
    fi

else
    # IT IS AN ALERT
    if [[ "$ALERT_NAME" == *"electricity"* ]]; then
        HEADER="Power Failure Detected in Server Room"
        ICON="💀"
    elif [ "$LOSS_VAL" -ge 1 ]; then
        HEADER="Packet Loss Detected"
        [ "$LOSS_VAL" -ge 10 ] && ICON="🔴" || ICON="🟠"
    elif [ "$RTT_VAL" -ge "$T_RTT" ]; then
        HEADER="High Latency Detected"
        ICON="⚠️"
    fi
fi

#==============================================================================
# 4. Construct JSON Payload
#==============================================================================

E_TARGET=${CLEAN_TARGET//\"/\\\"}
E_ALERT=${ALERT_NAME//\"/\\\"}

TEXT="$ICON <b>$HEADER</b>\n\n"
TEXT+="<b>Target:</b> <code>$E_TARGET</code>\n"
TEXT+="<b>Host:</b> <code>$HOSTNAME</code>\n"

# Add Region line if found
if [ -n "$REGION_INFO" ]; then
    TEXT+="<b>Region:</b> 🌍 $REGION_INFO\n"
fi

TEXT+="\n<b>Metrics:</b>\n"
TEXT+="📉 Loss: <code>$LOSS_VAL%</code>\n"
TEXT+="⏱️ RTT:  <code>$RTT_VAL ms</code>"

KEYBOARD="{\"inline_keyboard\":[[{\"text\":\"📊 View Dashboard\",\"url\":\"$DASHBOARD_URL\"}]]}"
JSON_PAYLOAD="{\"chat_id\": \"$CHAT_ID\", \"text\": \"$TEXT\", \"parse_mode\": \"HTML\", \"reply_markup\": $KEYBOARD, \"disable_web_page_preview\": true}"

#==============================================================================
# 5. Send & Log
#==============================================================================

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -H 'Content-Type: application/json' \
    -d "$JSON_PAYLOAD")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "[$(date)] SUCCESS: $STATUS $E_TARGET" >> "$LOG_FILE"
    exit 0
else
    echo "[$(date)] FAILED: $RESPONSE" >> "$LOG_FILE"
    exit 1
fi
