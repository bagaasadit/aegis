#!/data/data/com.termux/files/usr/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
#  🛡️ AEGIS SYSTEM DEFENSE v2.0 - Hybrid Edition
#  Advanced App & Folder Protection with Sentinel Monitoring
#  
#  Usage: 
#    Interactive:  ./aegis.sh  (or ./aegis.sh menu)
#    CLI Mode:     ./aegis.sh <command> [args]
# ═══════════════════════════════════════════════════════════════════════════

# --- CONFIG ---
DATA_DIR="/sdcard/Android/.sys_log_config"
APP_LIST="$DATA_DIR/sys_app_log"
FILE_LIST="$DATA_DIR/sys_file_log"
CACHE_FILE="$DATA_DIR/app_names.cache"
LOCK_FILE="$DATA_DIR/.aegis_sentinel.lock"
PID_FILE="$DATA_DIR/.aegis_sentinel.pid"
HISTORY_FILE="$DATA_DIR/.search_history"
PROTECTED_APPS=("com.termux" "android" "com.android.settings" "com.android.phone")

# Detect Termux User
TERMUX_USER=$(stat -c '%U' /data/data/com.termux/files/home 2>/dev/null)

# --- THEME (Semantic Colors) ---
SUCCESS=$'\e[0;32m'    # Green - successful operations
ERROR=$'\e[0;31m'      # Red - errors/destructive actions
WARNING=$'\e[1;33m'    # Yellow - warnings/caution
INFO=$'\e[0;36m'       # Cyan - informational
HIGHLIGHT=$'\e[1;37m'  # White - important text
MUTED=$'\e[2m'         # Dim - secondary info
PRIMARY=$'\e[0;35m'    # Purple - interactive elements
RESET=$'\e[0m'         # Reset

# Legacy aliases for backward compatibility
C=$INFO; P=$PRIMARY; G=$SUCCESS; R=$ERROR; Y=$WARNING; W=$HIGHLIGHT; N=$RESET; DIM=$MUTED

# --- 1. DEPENDENCY CHECK (ENHANCED) ---
check_deps_safe() {
    local MISSING=0
    
    # Install sudo FIRST - critical for script operation
    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "${WARNING}[!] Installing sudo...${RESET}"
        pkg update -y >/dev/null 2>&1 && pkg install sudo -y >/dev/null 2>&1
        if ! command -v sudo >/dev/null 2>&1; then
            echo -e "${ERROR}[!] Failed to install sudo. Please run manually: pkg install sudo${RESET}"
            MISSING=1
        else
            echo -e "${SUCCESS}[✓] sudo installed${RESET}"
        fi
    fi
    
    if ! command -v aapt >/dev/null 2>&1; then
        echo -e "${WARNING}[!] Installing aapt...${RESET}"
        pkg update -y >/dev/null 2>&1 && pkg install aapt -y >/dev/null 2>&1
        if command -v aapt >/dev/null 2>&1; then
            echo -e "${SUCCESS}[✓] aapt installed${RESET}"
        fi
    fi
    
    if ! command -v termux-notification >/dev/null 2>&1; then
        echo -e "${WARNING}[!] Installing Termux:API...${RESET}"
        pkg install termux-api -y >/dev/null 2>&1
        echo -e "${ERROR}[!] IMPORTANT: Install 'Termux:API' app from F-Droid too!${RESET}"
        echo -e "${MUTED}    Download: https://f-droid.org/packages/com.termux.api/${RESET}"
    fi
    
    [ $MISSING -eq 1 ] && exit 1
}

if [ "$(id -u)" != "0" ]; then check_deps_safe; fi

# --- 2. ROOT CHECK ---
CMD="$1"; ARG2="$2"
MY_PARENT_PID=$PPID

if [ "$(id -u)" != "0" ]; then 
    sudo "$0" "$CMD" "$ARG2" "$MY_PARENT_PID" || { 
        echo -e "${ERROR}[!] Root access required. Grant sudo permission or use: su -c '$0 $CMD'${RESET}"
        exit 1
    }
    exit $?
fi

SHELL_PID=${3:-$PPID}

# --- INIT & CRASH RECOVERY ---
[ ! -d "$DATA_DIR" ] && mkdir -p "$DATA_DIR"
[ ! -f "$APP_LIST" ] && touch "$APP_LIST"
[ ! -f "$FILE_LIST" ] && touch "$FILE_LIST"
[ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"

if [ -f "$LOCK_FILE" ]; then
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ! ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${ERROR}╔════════════════════════════════════════╗${RESET}"
            echo -e "${ERROR}║  ⚠️  CRASH DETECTED                   ║${RESET}"
            echo -e "${ERROR}║  Termux was killed improperly         ║${RESET}"
            echo -e "${ERROR}║  INITIATING AEGIS LOCKDOWN...         ║${RESET}"
            echo -e "${ERROR}╚════════════════════════════════════════╝${RESET}"
            rm "$LOCK_FILE" "$PID_FILE" 2>/dev/null
            sleep 2
            $0 hide --force
            exit
        fi
    else
        rm "$LOCK_FILE" 2>/dev/null
        $0 hide --force
        exit
    fi
fi

# --- HELPER FUNCTIONS (ENHANCED) ---
run_as_user() { 
    su "$TERMUX_USER" -c "export PATH=/data/data/com.termux/files/usr/bin:\$PATH; $1"
}

clean_pkg() { 
    echo "$1" | tr -cd '[:alnum:]._' 
}

is_protected() { 
    for a in "${PROTECTED_APPS[@]}"; do 
        [[ "$1" == "$a" ]] && echo 1 && return
    done
    echo 0
}

get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

header() { 
    clear
    local WIDTH=$(get_terminal_width)
    local PADDING=$(( (WIDTH - 35) / 2 ))
    [ $PADDING -lt 0 ] && PADDING=0
    
    printf "%*s" $PADDING ""
    echo -e "${INFO}╔═══════════════════════════════════╗${RESET}"
    printf "%*s" $PADDING ""
    echo -e "${INFO}║      🛡️ AEGIS SYSTEM DEFENSE     ║${RESET}"
    printf "%*s" $PADDING ""
    echo -e "${INFO}╚═══════════════════════════════════╝${RESET}"
    echo ""
}

print_status() { 
    printf " ${HIGHLIGHT}%-35s${RESET} [ ${3}%-8s${RESET} ]\n" "${1:0:35}" "$2"
}

pause() {
    echo ""
    echo -ne "${MUTED}Press any key to continue...${RESET}"
    read -n 1 -s
    echo ""
}

spinner() {
    local pid=$1
    local msg=$2
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r ${INFO}[%c]${RESET} %s" "$spinstr" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r${SUCCESS}[✓]${RESET} %s\n" "$msg"
}

progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${INFO}["
    printf "%${filled}s" '' | tr ' ' '█'
    printf "%${empty}s" '' | tr ' ' '░'
    printf "]${RESET} ${HIGHLIGHT}%d%%${RESET} ${MUTED}(%d/%d)${RESET}" $percentage $current $total
}

# --- NAME RESOLVER (WITH PROGRESS) ---
get_label() {
    PKG=$(clean_pkg "$1")
    [ -z "$PKG" ] && return
    
    if [ -f "$CACHE_FILE" ]; then
        CACHED=$(grep "|$PKG$" "$CACHE_FILE" | cut -d'|' -f1 | head -1)
        if [ -n "$CACHED" ]; then echo "$CACHED"; return; fi
    fi
    
    LABEL=""
    PATH_APK=$(pm path "$PKG" 2>/dev/null | grep "base.apk" | head -n 1 | sed 's/^package://')
    
    if [ -f "$PATH_APK" ]; then
        INFO_DATA=$(aapt d badging "$PATH_APK" 2>/dev/null)
        LABEL=$(echo "$INFO_DATA" | grep "application: label=" | head -n 1 | cut -d"'" -f2)
        if [ -z "$LABEL" ]; then
            LABEL=$(echo "$INFO_DATA" | grep "application-label:" | head -n 1 | cut -d"'" -f2)
        fi
    fi
    
    if [ -z "$LABEL" ]; then
        DUMP=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null)
        LABEL=$(echo "$DUMP" | sed -n 's/.*nonLocalizedLabel="\([^"]*\)".*/\1/p')
    fi
    
    if [ -z "$LABEL" ] || [[ "$LABEL" == *"labelRes"* ]]; then
        echo "$PKG"
    else
        echo "$LABEL"
    fi
}

# --- CACHE MANAGEMENT (WITH PROGRESS) ---
update_cache() {
    > "$CACHE_FILE"
    
    echo -e "${WARNING}[!] Building app cache...${RESET}"
    mapfile -t RAW_LIST < <(pm list packages -3 | cut -d: -f2)
    local TOTAL=${#RAW_LIST[@]}
    
    echo -e "${INFO}[i] Found $TOTAL user-installed apps${RESET}"
    
    local count=0
    for pkg in "${RAW_LIST[@]}"; do
        ((count++))
        progress_bar $count $TOTAL
        
        pkg=$(clean_pkg "$pkg")
        LABEL=""
        PATH_APK=$(pm path "$pkg" 2>/dev/null | grep "base.apk" | head -n 1 | sed 's/^package://')
        
        if [ -f "$PATH_APK" ]; then
            INFO_DATA=$(aapt d badging "$PATH_APK" 2>/dev/null)
            LABEL=$(echo "$INFO_DATA" | grep "application: label=" | head -n 1 | cut -d"'" -f2)
            if [ -z "$LABEL" ]; then
                LABEL=$(echo "$INFO_DATA" | grep "application-label:" | head -n 1 | cut -d"'" -f2)
            fi
        fi
        
        if [ -z "$LABEL" ]; then
            DUMP=$(cmd package resolve-activity --brief "$pkg" 2>/dev/null)
            LABEL=$(echo "$DUMP" | sed -n 's/.*nonLocalizedLabel="\([^"]*\)".*/\1/p')
        fi
        
        if [ -z "$LABEL" ]; then LABEL="$pkg"; fi
        echo "$LABEL|$pkg" >> "$CACHE_FILE"
    done
    
    echo ""
    echo -e "${SUCCESS}[✓] Cache updated successfully${RESET}"
}

ensure_cache() {
    if [ ! -f "$CACHE_FILE" ]; then 
        update_cache
        return
    fi
    
    CUR=$(pm list packages -3 | wc -l)
    CAC=$(wc -l < "$CACHE_FILE")
    
    if [ "$CUR" -ne "$CAC" ]; then
        echo -e "${WARNING}[!] Cache outdated (has $CAC apps, found $CUR)${RESET}"
        update_cache
    fi
}

# --- SENTINEL MONITORING ---
start_sentinel() {
    stop_sentinel
    touch "$LOCK_FILE"
    
    nohup bash -c "
        echo \$$ > '$PID_FILE'
        su '$TERMUX_USER' -c 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; termux-notification --id aegis_guard --title \"🛡️ AEGIS: DISENGAGED\" --content \"SYSTEM UNLOCKED. Closing Termux will trigger lockdown.\" --priority max --ongoing --alert-once'
        
        while [ -f '$LOCK_FILE' ]; do
            SCREEN_OFF=\$(dumpsys power | grep 'mWakefulness=Asleep')
            DO_KILL=0
            REASON=''
            
            if [ -n \"\$SCREEN_OFF\" ]; then
                REASON='Screen Off'
                DO_KILL=1
            fi

            if ! kill -0 $SHELL_PID 2>/dev/null; then
                REASON='Termux Closed'
                DO_KILL=1
            fi

            if [ \"\$DO_KILL\" == \"1\" ]; then
                $0 hide --force >/dev/null 2>&1
                su '$TERMUX_USER' -c \"export PATH=/data/data/com.termux/files/usr/bin:\$PATH; termux-notification --id aegis_guard --title '🛡️ AEGIS: LOCKDOWN' --content 'Threat detected: \$REASON. System secured.' --priority high\"
                rm '$LOCK_FILE' '$PID_FILE' 2>/dev/null
                break
            fi
            sleep 1
        done
    " >/dev/null 2>&1 & disown
}

stop_sentinel() {
    if [ -f "$PID_FILE" ]; then
        SPID=$(cat "$PID_FILE")
        kill "$SPID" 2>/dev/null
        rm "$PID_FILE" 2>/dev/null
    fi
    rm "$LOCK_FILE" 2>/dev/null
    run_as_user "termux-notification-remove aegis_guard" 2>/dev/null
}

get_sentinel_status() {
    if [ -f "$LOCK_FILE" ] && [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "active"
            return
        fi
    fi
    echo "inactive"
}

get_sentinel_uptime() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            ps -o etime= -p "$PID" | tr -d ' '
            return
        fi
    fi
    echo "N/A"
}

# --- PROCESSOR (WITH ENHANCED FEEDBACK) ---
process() {
    MODE=$1
    FORCE=$2
    
    echo -e "${INFO}╔════ PROCESSING ══════════════════╗${RESET}"
    
    # Clean up lists
    sed -i '/^$/d' "$APP_LIST" 2>/dev/null
    sed -i 's/\r//g' "$APP_LIST" 2>/dev/null
    sed -i '/^$/d' "$FILE_LIST" 2>/dev/null
    sed -i 's/\r//g' "$FILE_LIST" 2>/dev/null

    # Process apps
    mapfile -t TARGET_APPS < "$APP_LIST"
    local APP_COUNT=${#TARGET_APPS[@]}
    
    if [ $APP_COUNT -gt 0 ]; then
        echo -e "${INFO}[i] Processing $APP_COUNT apps...${RESET}"
        local processed=0
        
        for raw_p in "${TARGET_APPS[@]}"; do
            ((processed++))
            p=$(clean_pkg "$raw_p")
            [[ -z "$p" ]] && continue
            
            if [ "$MODE" == "h" ]; then
                if [ $(is_protected "$p") -eq 1 ]; then 
                    print_status "$p" "SKIP" "$WARNING"
                    continue
                fi
                
                OUT=$(cmd package disable-user --user 0 "$p" < /dev/null 2>&1)
                RET=$?
                
                if [[ "$OUT" == *"new state: disabled"* ]] || [ $RET -eq 0 ]; then
                    print_status "$p" "HIDDEN" "$ERROR"
                else
                    STATE=$(cmd package list packages -d | grep "$p")
                    if [ -n "$STATE" ]; then
                        print_status "$p" "HIDDEN" "$ERROR"
                    else
                        if [[ "$OUT" == *"Unknown package"* ]]; then
                            print_status "$p" "NOT FOUND" "$WARNING"
                            echo -e "   ${MUTED}→ App uninstalled. Run 'st remove' to clean list${RESET}"
                        elif [[ "$OUT" == *"does not exist"* ]]; then
                            print_status "$p" "INVALID" "$WARNING"
                        else
                            print_status "$p" "FAILED" "$WARNING"
                            echo -e "   ${MUTED}→ ${OUT:0:60}${RESET}"
                        fi
                    fi
                fi
            else
                # Unhide logic
                OUT=$(cmd package enable --user 0 "$p" < /dev/null 2>&1)
                if [[ "$OUT" == *"new state: enabled"* ]] || [ $? -eq 0 ]; then
                    print_status "$p" "ACTIVE" "$SUCCESS"
                else
                    print_status "$p" "FAILED" "$WARNING"
                    echo -e "   ${MUTED}→ ${OUT:0:60}${RESET}"
                fi
            fi
        done
    else
        echo -e "${MUTED}[i] No apps to process${RESET}"
    fi
    
    # Process files/folders
    mapfile -t TARGET_FILES < "$FILE_LIST"
    local FILE_COUNT=${#TARGET_FILES[@]}
    
    if [ $FILE_COUNT -gt 0 ]; then
        echo -e "${INFO}[i] Processing $FILE_COUNT folders...${RESET}"
        
        for raw_f in "${TARGET_FILES[@]}"; do
            f=$(echo "$raw_f" | sed 's/\r//g' | sed 's|//|/|g')
            [[ -z "$f" ]] && continue
            D=$(dirname "$f")
            N=$(basename "$f")
            H="$D/.$N"
            DISP="${N:0:30}"
            
            if [ "$MODE" == "h" ]; then
                if [ -e "$f" ]; then 
                    if [ -e "$H" ]; then 
                        print_status "$DISP" "COLLISION" "$WARNING"
                        echo -e "   ${MUTED}→ Both visible and hidden versions exist${RESET}"
                    else 
                        mv "$f" "$H" && touch "$H/.nomedia"
                        print_status "$DISP" "LOCKED" "$ERROR"
                    fi
                elif [ -e "$H" ]; then 
                    print_status "$DISP" "ALREADY" "$MUTED"
                fi
            else
                # Show logic
                if [ -e "$H" ]; then 
                    if [ -e "$f" ]; then 
                        print_status "$DISP" "COLLISION" "$WARNING"
                    else 
                        rm "$H/.nomedia" 2>/dev/null
                        mv "$H" "$f"
                        print_status "$DISP" "OPEN" "$SUCCESS"
                    fi
                elif [ -e "$f" ]; then 
                    print_status "$DISP" "VISIBLE" "$MUTED"
                fi
            fi
        done
    else
        echo -e "${MUTED}[i] No folders to process${RESET}"
    fi
    
    # Handle sentinel based on mode
    if [ "$MODE" == "u" ]; then
        echo ""
        echo -e "${WARNING}[!] AEGIS SENTINEL ACTIVATING...${RESET}"
        start_sentinel
        echo -e "${SUCCESS}[✓] Sentinel active - monitoring Termux & screen${RESET}"
    elif [ "$MODE" == "free" ]; then
        echo ""
        echo -e "${ERROR}[!] WARNING: FREE ROAM MODE ACTIVATED${RESET}"
        stop_sentinel
        run_as_user "termux-notification --id aegis_guard --title '🛡️ AEGIS: FREE ROAM' --content 'Protection Disabled. Apps are permanently visible.' --priority high"
    else
        stop_sentinel
    fi
    
    echo -e "${INFO}╚══════════════════════════════════╝${RESET}"
}

# --- CONFIRMATION WRAPPER ---
confirm_and_process() {
    local MODE=$1
    local FORCE=$2
    
    # Skip confirmation if --force flag
    if [ "$FORCE" == "--force" ]; then
        process "$MODE" "--force"
        return
    fi
    
    header
    
    case "$MODE" in
        h)
            APP_COUNT=$(wc -l < "$APP_LIST" 2>/dev/null || echo 0)
            FOLDER_COUNT=$(wc -l < "$FILE_LIST" 2>/dev/null || echo 0)
            
            echo -e "${ERROR}╔════════════════════════════════════════╗${RESET}"
            echo -e "${ERROR}║  ⚠️  LOCKDOWN CONFIRMATION            ║${RESET}"
            echo -e "${ERROR}╚════════════════════════════════════════╝${RESET}"
            echo ""
            echo -e "${WARNING}This will HIDE:${RESET}"
            echo -e "  • ${HIGHLIGHT}$APP_COUNT${RESET} apps"
            echo -e "  • ${HIGHLIGHT}$FOLDER_COUNT${RESET} folders"
            echo ""
            echo -e "${WARNING}Closing Termux will keep them hidden.${RESET}"
            echo ""
            ;;
        u)
            echo -e "${INFO}╔════════════════════════════════════════╗${RESET}"
            echo -e "${INFO}║  🔓 UNLOCK CONFIRMATION               ║${RESET}"
            echo -e "${INFO}╚════════════════════════════════════════╝${RESET}"
            echo ""
            echo -e "${SUCCESS}This will UNLOCK all protected items.${RESET}"
            echo ""
            echo -e "${WARNING}SENTINEL will monitor:${RESET}"
            echo -e "  • Screen lock/off events"
            echo -e "  • Termux app closure"
            echo ""
            echo -e "${ERROR}Auto-lockdown will trigger on detection.${RESET}"
            echo ""
            ;;
        free)
            echo -e "${ERROR}╔════════════════════════════════════════╗${RESET}"
            echo -e "${ERROR}║  ⚠️  FREE ROAM WARNING                ║${RESET}"
            echo -e "${ERROR}╚════════════════════════════════════════╝${RESET}"
            echo ""
            echo -e "${ERROR}This will DISABLE all protection!${RESET}"
            echo ""
            echo -e "  • Apps stay visible permanently"
            echo -e "  • No auto-lockdown on Termux close"
            echo -e "  • Sentinel monitoring stopped"
            echo ""
            ;;
    esac
    
    echo -ne "${HIGHLIGHT}Continue? [y/N]: ${RESET}"
    read -n 1 CONFIRM
    echo ""
    
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo ""
        process "$MODE"
        pause
    else
        echo -e "${INFO}[i] Operation cancelled${RESET}"
        sleep 1
    fi
}

# --- STATUS DISPLAY ---
show_status() {
    header
    
    local STATUS=$(get_sentinel_status)
    local UPTIME=$(get_sentinel_uptime)
    local APP_COUNT=$(wc -l < "$APP_LIST" 2>/dev/null || echo 0)
    local FOLDER_COUNT=$(wc -l < "$FILE_LIST" 2>/dev/null || echo 0)
    
    # Count currently hidden apps
    local HIDDEN_COUNT=0
    if [ -f "$APP_LIST" ] && [ -s "$APP_LIST" ]; then
        mapfile -t APPS < "$APP_LIST"
        for app in "${APPS[@]}"; do
            app=$(clean_pkg "$app")
            [ -z "$app" ] && continue
            STATE=$(cmd package list packages -d 2>/dev/null | grep "^package:$app$")
            [ -n "$STATE" ] && ((HIDDEN_COUNT++))
        done
    fi
    
    echo -e "${INFO}╔════════════════════════════════════════╗${RESET}"
    echo -e "${INFO}║           SYSTEM STATUS                ║${RESET}"
    echo -e "${INFO}╠════════════════════════════════════════╣${RESET}"
    
    # Sentinel status
    if [ "$STATUS" == "active" ]; then
        printf "${INFO}║${RESET} Sentinel:    ${SUCCESS}● ACTIVE${RESET} (up %-11s ${INFO}║${RESET}\n" "$UPTIME)"
        printf "${INFO}║${RESET} Monitoring:  ${WARNING}Screen + Termux Close${RESET}      ${INFO}║${RESET}\n"
        printf "${INFO}║${RESET} Action:      ${ERROR}Auto-Lockdown${RESET}              ${INFO}║${RESET}\n"
    else
        printf "${INFO}║${RESET} Sentinel:    ${MUTED}○ Inactive${RESET}                 ${INFO}║${RESET}\n"
        printf "${INFO}║${RESET} Monitoring:  ${MUTED}Disabled${RESET}                   ${INFO}║${RESET}\n"
    fi
    
    echo -e "${INFO}╠════════════════════════════════════════╣${RESET}"
    
    # Protection targets
    printf "${INFO}║${RESET} Apps:        ${HIGHLIGHT}%-3d${RESET} protected              ${INFO}║${RESET}\n" $APP_COUNT
    printf "${INFO}║${RESET} Folders:     ${HIGHLIGHT}%-3d${RESET} protected              ${INFO}║${RESET}\n" $FOLDER_COUNT
    printf "${INFO}║${RESET} Currently:   ${ERROR}%-3d${RESET} hidden                 ${INFO}║${RESET}\n" $HIDDEN_COUNT
    
    echo -e "${INFO}╚════════════════════════════════════════╝${RESET}"
    
    pause
}

# --- APP MANAGEMENT MENUS ---
show_all_users() {
    header
    ensure_cache
    
    echo -e "${PRIMARY} :: USER APPS (From Cache) ::${RESET}\n"
    
    mapfile -t SORTED_LIST < <(sort -f -t'|' -k1,1 "$CACHE_FILE")
    local TOTAL=${#SORTED_LIST[@]}
    
    if [ $TOTAL -eq 0 ]; then
        echo -e "${WARNING}[!] No apps found. Try: st refresh${RESET}"
        pause
        return
    fi
    
    i=1
    declare -a PKG_MAP
    
    for line in "${SORTED_LIST[@]}"; do
        NAME="${line%|*}"
        PKG="${line#*|}"
        PKG_MAP+=("$PKG")
        
        if grep -Fqx "$PKG" "$APP_LIST" 2>/dev/null; then
            STATUS="${ERROR}[IN LIST]${RESET}"
        else
            STATUS=""
        fi
        
        printf "${PRIMARY}[%02d]${RESET} ${HIGHLIGHT}%-30s${RESET} ${MUTED}(%s)${RESET} %s\n" $i "${NAME:0:30}" "$PKG" "$STATUS"
        ((i++))
    done
    
    echo -e "${INFO}─────────────────────────────────────${RESET}"
    echo -e "${MUTED}Enter numbers (space-separated) or 'q' to cancel${RESET}"
    echo -ne "${HIGHLIGHT}Select #: ${RESET}"
    read -a IN
    
    if [[ "${IN[0]}" == "q" ]]; then
        echo -e "${INFO}[i] Cancelled${RESET}"
        sleep 1
        return
    fi
    
    echo ""
    echo -e "${INFO}[i] Adding targets...${RESET}"
    
    for N in "${IN[@]}"; do 
        if [[ "$N" =~ ^[0-9]+$ ]]; then 
            IDX=$((N-1))
            if [ $IDX -ge 0 ] && [ $IDX -lt ${#PKG_MAP[@]} ]; then 
                T="${PKG_MAP[$IDX]}"
                if ! grep -Fqx "$T" "$APP_LIST" 2>/dev/null; then 
                    echo "$T" >> "$APP_LIST"
                    print_status "$(get_label $T)" "ADDED" "$SUCCESS"
                else 
                    print_status "$(get_label $T)" "EXISTS" "$WARNING"
                fi
            fi
        fi
    done
    
    pause
}

app_search_picker() {
    header
    KEY="$1"
    
    # If no key provided, ask user
    if [ -z "$KEY" ]; then
        echo -e "${PRIMARY} :: FAST SEARCH ::${RESET}\n"
        echo -ne "${HIGHLIGHT}Search keyword: ${RESET}"
        read KEY
        [ -z "$KEY" ] && return
    fi
    
    SAFE_KEY=$(echo "$KEY" | tr -cd '[:alnum:]_.-')
    
    # Save to history
    echo "$SAFE_KEY" >> "$HISTORY_FILE"
    tail -n 20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    
    echo -e "${PRIMARY} :: SEARCH RESULTS :: ${HIGHLIGHT}'$SAFE_KEY'${RESET}\n"
    
    ensure_cache
    mapfile -t MATCHES < <(grep -i "$SAFE_KEY" "$CACHE_FILE")
    CNT=${#MATCHES[@]}
    
    if [ $CNT -eq 0 ]; then
        echo -e "${WARNING}[!] No matches found${RESET}"
        pause
        return
    fi
    
    echo -e "${SUCCESS}[✓] Found $CNT match(es)${RESET}\n"
    
    i=1
    declare -a MATCH_PKGS
    
    for line in "${MATCHES[@]}"; do 
        NAME="${line%|*}"
        PKG="${line#*|}"
        MATCH_PKGS+=("$PKG")
        
        if grep -Fqx "$PKG" "$APP_LIST" 2>/dev/null; then
            STATUS="${ERROR}[IN LIST]${RESET}"
        else
            STATUS=""
        fi
        
        printf "${PRIMARY}[%02d]${RESET} ${HIGHLIGHT}%-30s${RESET} ${MUTED}(%s)${RESET} %s\n" $i "${NAME:0:30}" "$PKG" "$STATUS"
        ((i++))
    done
    
    echo -e "${INFO}─────────────────────────────────────${RESET}"
    echo -ne "${HIGHLIGHT}Select # (or 'q' to cancel): ${RESET}"
    read -a IN
    
    if [[ "${IN[0]}" == "q" ]]; then
        return
    fi
    
    echo ""
    for N in "${IN[@]}"; do 
        if [[ "$N" =~ ^[0-9]+$ ]]; then 
            IDX=$((N-1))
            if [ $IDX -ge 0 ] && [ $IDX -lt $CNT ]; then 
                T="${MATCH_PKGS[$IDX]}"
                if ! grep -Fqx "$T" "$APP_LIST" 2>/dev/null; then
                    echo "$T" >> "$APP_LIST"
                    print_status "$(get_label $T)" "ADDED" "$SUCCESS"
                else
                    print_status "$(get_label $T)" "EXISTS" "$WARNING"
                fi
            fi
        fi
    done
    
    pause
}

show_recent_searches() {
    header
    echo -e "${PRIMARY} :: RECENT SEARCHES ::${RESET}\n"
    
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${MUTED}No search history${RESET}"
        pause
        return
    fi
    
    mapfile -t HISTORY < <(tac "$HISTORY_FILE" | awk '!seen[$0]++')
    
    i=1
    for term in "${HISTORY[@]}"; do
        printf "${PRIMARY}[%d]${RESET} %s\n" $i "$term"
        ((i++))
        [ $i -gt 10 ] && break
    done
    
    echo ""
    echo -ne "${HIGHLIGHT}Select # to search again (or Enter to skip): ${RESET}"
    read CHOICE
    
    if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
        IDX=$((CHOICE-1))
        if [ $IDX -ge 0 ] && [ $IDX -lt ${#HISTORY[@]} ]; then
            app_search_picker "${HISTORY[$IDX]}"
        fi
    fi
}

app_menu() {
    while true; do
        header
        echo -e "${PRIMARY}═══ APP MANAGEMENT ═══${RESET}\n"
        echo -e "${PRIMARY}[1]${RESET} 🔍 Quick Search"
        echo -e "${PRIMARY}[2]${RESET} 📚 Browse All Apps"
        echo -e "${PRIMARY}[3]${RESET} ⭐ Recent Searches"
        echo -e "${PRIMARY}[0]${RESET} ← Back to Main Menu"
        echo ""
        echo -ne "${HIGHLIGHT}Select option: ${RESET}"
        read -n 1 OPT
        echo ""
        
        case "$OPT" in
            1) app_search_picker "" ;;
            2) show_all_users ;;
            3) show_recent_searches ;;
            0) break ;;
            *) echo -e "${WARNING}Invalid option${RESET}"; sleep 1 ;;
        esac
    done
}

# --- FILE/FOLDER PICKER ---
file_picker() {
    CDIR="/sdcard"
    
    while true; do 
        header
        echo -e "${PRIMARY} :: FOLDER EXPLORER :: ${WARNING}$CDIR${RESET}\n"
        
        mapfile -t F < <(ls -1p "$CDIR" 2>/dev/null | grep '/$' | sed 's/\///')
        
        if [ ${#F[@]} -eq 0 ]; then
            echo -e "${WARNING}[!] No folders found or permission denied${RESET}"
            echo ""
            echo -e "${MUTED}Commands: ${RESET}"
            echo -e "  ${HIGHLIGHT}0${RESET} = Go back"
            echo -e "  ${HIGHLIGHT}q${RESET} = Quit"
        else
            i=1
            for f in "${F[@]}"; do 
                printf "${HIGHLIGHT}[%02d]${RESET} 📁 %s\n" $i "$f"
                ((i++))
            done
            
            echo ""
            echo -e "${MUTED}Commands: ${RESET}"
            echo -e "  ${HIGHLIGHT}<number>${RESET} = Enter folder"
            echo -e "  ${HIGHLIGHT}s <number>${RESET} = Select folder to protect"
            echo -e "  ${HIGHLIGHT}0${RESET} = Go up one level"
            echo -e "  ${HIGHLIGHT}q${RESET} = Cancel"
        fi
        
        echo ""
        echo -ne "${HIGHLIGHT}> ${RESET}"
        read IN
        
        [ "$IN" == "q" ] && break
        
        if [ "$IN" == "0" ]; then
            CDIR=${CDIR%/}
            CDIR=$(dirname "$CDIR")
            continue
        fi
        
        if [[ $IN == s* ]]; then 
            IDX=$(echo $IN | cut -d' ' -f2)
            if [[ "$IDX" =~ ^[0-9]+$ ]]; then
                ((IDX--))
                if [ $IDX -ge 0 ] && [ $IDX -lt ${#F[@]} ]; then
                    T="${F[$IDX]}"
                    FULL_PATH="$CDIR/$T"
                    
                    if grep -Fqx "$FULL_PATH" "$FILE_LIST" 2>/dev/null; then
                        echo -e "${WARNING}[!] Already in list${RESET}"
                    else
                        echo "$FULL_PATH" >> "$FILE_LIST"
                        print_status "$T" "ADDED" "$SUCCESS"
                    fi
                    sleep 1
                    break
                fi
            fi
        elif [[ "$IN" =~ ^[0-9]+$ ]]; then 
            ((IN--))
            if [ $IN -ge 0 ] && [ $IN -lt ${#F[@]} ]; then
                T="${F[$IN]}"
                [ -n "$T" ] && CDIR="$CDIR/$T"
            fi
        fi
    done
}

# --- REMOVE/DELETE FROM LIST ---
remover() {
    KEY="$1"
    
    # Quick remove by keyword
    if [ -n "$KEY" ]; then 
        SAFE_KEY=$(echo "$KEY" | tr -cd '[:alnum:]_.-')
        IT=$(grep -i "$SAFE_KEY" "$APP_LIST" 2>/dev/null | head -1)
        TF="$APP_LIST"
        TP="APP"
        
        if [ -z "$IT" ]; then
            IT=$(grep -i "$SAFE_KEY" "$FILE_LIST" 2>/dev/null | head -1)
            TF="$FILE_LIST"
            TP="FLD"
        fi
        
        if [ -z "$IT" ]; then
            echo -e "${WARNING}[!] Not found in any list${RESET}"
            pause
            return
        fi
        
        # Restore before removing
        if [ "$TP" == "APP" ]; then
            cmd package enable --user 0 "$IT" >/dev/null 2>&1
        else
            D=$(dirname "$IT")
            N=$(basename "$IT")
            H="$D/.$N"
            if [ -e "$H" ] && [ ! -e "$IT" ]; then
                rm "$H/.nomedia" 2>/dev/null
                mv "$H" "$IT"
            fi
        fi
        
        ESC_IT=$(echo "$IT" | sed 's/[\/&]/\\&/g')
        sed -i "/^$ESC_IT$/d" "$TF"
        print_status "$IT" "REMOVED" "$SUCCESS"
        pause
        return
    fi
    
    # Interactive remove
    header
    echo -e "${PRIMARY}═══ REMOVE FROM LIST ═══${RESET}\n"
    echo -e "${PRIMARY}[1]${RESET} Remove Apps"
    echo -e "${PRIMARY}[2]${RESET} Remove Folders"
    echo -e "${PRIMARY}[0]${RESET} Cancel"
    echo ""
    echo -ne "${HIGHLIGHT}Select: ${RESET}"
    read -n 1 O
    echo ""
    
    [ "$O" == "0" ] && return
    
    if [ "$O" == "1" ]; then
        TF="$APP_LIST"
        TP="APP"
    else
        TF="$FILE_LIST"
        TP="FLD"
    fi
    
    header
    
    mapfile -t I < "$TF"
    
    if [ ${#I[@]} -eq 0 ]; then
        echo -e "${WARNING}[!] List is empty${RESET}"
        pause
        return
    fi
    
    echo -e "${PRIMARY}═══ ${TP} LIST ═══${RESET}\n"
    
    i=1
    for x in "${I[@]}"; do 
        if [ "$TP" == "APP" ]; then
            L=$(get_label "$x")
            D="${HIGHLIGHT}$L${RESET} ${MUTED}($x)${RESET}"
        else
            D="$x"
        fi
        printf "${PRIMARY}[%02d]${RESET} %s\n" $i "$D"
        ((i++))
    done
    
    echo ""
    echo -e "${MUTED}Enter numbers (space-separated) or 'q' to cancel${RESET}"
    echo -ne "${HIGHLIGHT}Remove #: ${RESET}"
    read -a IN
    
    if [[ "${IN[0]}" == "q" ]]; then
        echo -e "${INFO}[i] Cancelled${RESET}"
        sleep 1
        return
    fi
    
    echo ""
    for N in "${IN[@]}"; do 
        if [[ "$N" =~ ^[0-9]+$ ]]; then 
            IDX=$((N-1))
            if [ $IDX -ge 0 ] && [ $IDX -lt ${#I[@]} ]; then 
                IT="${I[$IDX]}"
                
                # Restore before removing
                if [ "$TP" == "APP" ]; then
                    cmd package enable --user 0 "$IT" >/dev/null 2>&1
                else
                    D=$(dirname "$IT")
                    NM=$(basename "$IT")
                    H="$D/.$NM"
                    if [ -e "$H" ] && [ ! -e "$IT" ]; then
                        rm "$H/.nomedia" 2>/dev/null
                        mv "$H" "$IT"
                    fi
                fi
                
                ESC_IT=$(echo "$IT" | sed 's/[\/&]/\\&/g')
                sed -i "/^$ESC_IT$/d" "$TF"
                print_status "$IT" "DELETED" "$SUCCESS"
            fi
        fi
    done
    
    pause
}

# --- SHOW CURRENT TARGETS ---
show_list() {
    header
    
    echo -e "${PRIMARY} :: TARGET APPS ::${RESET}\n"
    
    if [ -s "$APP_LIST" ]; then 
        mapfile -t SHOW_APPS < "$APP_LIST"
        i=1
        for l in "${SHOW_APPS[@]}"; do
            l=$(clean_pkg "$l")
            [ -z "$l" ] && continue
            NAME=$(get_label "$l")
            
            # Check if currently hidden
            STATE=$(cmd package list packages -d 2>/dev/null | grep "^package:$l$")
            if [ -n "$STATE" ]; then
                STATUS="${ERROR}[HIDDEN]${RESET}"
            else
                STATUS="${SUCCESS}[VISIBLE]${RESET}"
            fi
            
            printf "${INFO}%02d${RESET} │ ${HIGHLIGHT}%-30s${RESET} ${MUTED}(%s)${RESET} %s\n" $i "${NAME:0:30}" "$l" "$STATUS"
            ((i++))
        done
    else 
        echo -e "${MUTED}(Empty)${RESET}"
    fi
    
    echo -e "\n${PRIMARY} :: TARGET FOLDERS ::${RESET}\n"
    
    if [ -s "$FILE_LIST" ]; then
        cat -n "$FILE_LIST"
    else
        echo -e "${MUTED}(Empty)${RESET}"
    fi
    
    echo ""
    pause
}

# --- HELP/GUIDE ---
show_help() {
    header
    echo -e " ${HIGHLIGHT}🛡️ AEGIS COMMAND GUIDE${RESET}\n"
    
    echo -e "${INFO}═══ PROTECTION MODES ═══${RESET}"
    printf "  ${SUCCESS}%-15s${RESET} %s\n" "st hide" "🔒 Lock all apps (with confirmation)"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st h, st on${RESET}\n" ""
    printf "  ${SUCCESS}%-15s${RESET} %s\n" "st unlock" "🔓 Unlock + Sentinel watch"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st u, st off${RESET}\n" ""
    printf "  ${ERROR}%-15s${RESET} %s\n" "st free" "⚠️  Disable protection (permanent)"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st perm${RESET}\n" ""
    
    echo -e "\n${INFO}═══ MANAGE TARGETS ═══${RESET}"
    printf "  ${INFO}%-15s${RESET} %s\n" "st list" "📋 Show all targets (apps + folders)"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st l${RESET}\n" ""
    printf "  ${INFO}%-15s${RESET} %s\n" "st search" "🔍 Search apps by name"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Usage: st search whatsapp${RESET}\n" ""
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st aa <keyword>${RESET}\n" ""
    printf "  ${INFO}%-15s${RESET} %s\n" "st browse" "📚 Browse all installed apps"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st all${RESET}\n" ""
    printf "  ${INFO}%-15s${RESET} %s\n" "st folder" "📁 Add folder to protect"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st af${RESET}\n" ""
    printf "  ${ERROR}%-15s${RESET} %s\n" "st remove" "🗑️  Remove from list"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Usage: st remove <keyword>${RESET}\n" ""
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st r, st rm${RESET}\n" ""
    
    echo -e "\n${INFO}═══ UTILITIES ═══${RESET}"
    printf "  ${WARNING}%-15s${RESET} %s\n" "st status" "📊 Check sentinel & system status"
    printf "  ${WARNING}%-15s${RESET} %s\n" "st refresh" "🔄 Rebuild app cache"
    printf "  ${MUTED}%-15s${RESET} ${MUTED}Aliases: st db${RESET}\n" ""
    printf "  ${WARNING}%-15s${RESET} %s\n" "st menu" "📱 Interactive menu mode"
    printf "  ${WARNING}%-15s${RESET} %s\n" "st help" "❓ Show this help"
    
    echo -e "\n${INFO}═══ EXAMPLES ═══${RESET}"
    echo -e "  ${MUTED}# Quick search and add${RESET}"
    echo -e "  ${HIGHLIGHT}st search telegram${RESET}"
    echo -e ""
    echo -e "  ${MUTED}# Lock everything immediately${RESET}"
    echo -e "  ${HIGHLIGHT}st hide${RESET}"
    echo -e ""
    echo -e "  ${MUTED}# Unlock with auto-lock on Termux close${RESET}"
    echo -e "  ${HIGHLIGHT}st unlock${RESET}"
    echo -e ""
    echo -e "  ${MUTED}# Check current status${RESET}"
    echo -e "  ${HIGHLIGHT}st status${RESET}"
    echo -e ""
    echo -e "  ${MUTED}# Remove app from list${RESET}"
    echo -e "  ${HIGHLIGHT}st remove whatsapp${RESET}"
    
    echo ""
    pause
}

# --- INTERACTIVE MAIN MENU ---
main_menu() {
    while true; do
        header
        
        # Status bar
        SENTINEL_STATUS=$(get_sentinel_status)
        UPTIME=$(get_sentinel_uptime)
        APP_COUNT=$(wc -l < "$APP_LIST" 2>/dev/null || echo 0)
        FOLDER_COUNT=$(wc -l < "$FILE_LIST" 2>/dev/null || echo 0)
        
        # Count hidden apps
        HIDDEN_COUNT=0
        if [ -f "$APP_LIST" ] && [ -s "$APP_LIST" ]; then
            mapfile -t APPS < "$APP_LIST"
            for app in "${APPS[@]}"; do
                app=$(clean_pkg "$app")
                [ -z "$app" ] && continue
                STATE=$(cmd package list packages -d 2>/dev/null | grep "^package:$app$")
                [ -n "$STATE" ] && ((HIDDEN_COUNT++))
            done
        fi
        
        echo -e "${INFO}╔════════════════════════════════════════╗${RESET}"
        echo -e "${INFO}║              STATUS BAR                ║${RESET}"
        echo -e "${INFO}╠════════════════════════════════════════╣${RESET}"
        
        if [ "$SENTINEL_STATUS" == "active" ]; then
            printf "${INFO}║${RESET} Sentinel: ${SUCCESS}● ACTIVE${RESET} (up %-13s ${INFO}║${RESET}\n" "$UPTIME)"
        else
            printf "${INFO}║${RESET} Sentinel: ${MUTED}○ Inactive${RESET}                   ${INFO}║${RESET}\n"
        fi
        
        printf "${INFO}║${RESET} Targets:  ${HIGHLIGHT}%3d apps${RESET} │ ${HIGHLIGHT}%3d folders${RESET}       ${INFO}║${RESET}\n" $APP_COUNT $FOLDER_COUNT
        printf "${INFO}║${RESET} Status:   ${ERROR}%3d hidden${RESET} │ ${SUCCESS}%3d visible${RESET}     ${INFO}║${RESET}\n" $HIDDEN_COUNT $((APP_COUNT - HIDDEN_COUNT))
        echo -e "${INFO}╚════════════════════════════════════════╝${RESET}"
        echo ""
        
        echo -e "${PRIMARY}[1]${RESET} 🔒 Lock System ${MUTED}(Hide Apps)${RESET}"
        echo -e "${PRIMARY}[2]${RESET} 🔓 Unlock System ${MUTED}(Sentinel Watch)${RESET}"
        echo -e "${PRIMARY}[3]${RESET} ⚠️  Free Roam Mode ${MUTED}(No Protection)${RESET}"
        echo -e "${INFO}────────────────────────────────────────${RESET}"
        echo -e "${PRIMARY}[4]${RESET} ➕ Add Apps to List"
        echo -e "${PRIMARY}[5]${RESET} 📁 Add Folders to List"
        echo -e "${PRIMARY}[6]${RESET} 📋 View Current Targets"
        echo -e "${PRIMARY}[7]${RESET} 🗑️  Remove from List"
        echo -e "${INFO}────────────────────────────────────────${RESET}"
        echo -e "${PRIMARY}[8]${RESET} 📊 System Status"
        echo -e "${PRIMARY}[9]${RESET} 🔄 Refresh App Database"
        echo -e "${PRIMARY}[h]${RESET} ❓ Help & Guide"
        echo -e "${PRIMARY}[0]${RESET} 🚪 Exit"
        echo ""
        
        echo -ne "${HIGHLIGHT}Select option: ${RESET}"
        read -n 1 CHOICE
        echo ""
        
        case "$CHOICE" in
            1) confirm_and_process "h" ;;
            2) confirm_and_process "u" ;;
            3) confirm_and_process "free" ;;
            4) app_menu ;;
            5) file_picker ;;
            6) show_list ;;
            7) remover "" ;;
            8) show_status ;;
            9) update_cache; pause ;;
            h|H) show_help ;;
            0) 
                echo -e "${SUCCESS}[✓] Goodbye!${RESET}"
                exit 0
                ;;
            *) 
                echo -e "${WARNING}[!] Invalid option${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
#  MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════

# Detect mode: Interactive vs CLI
if [ -z "$CMD" ] || [ "$CMD" == "menu" ]; then
    # No argument or explicit "menu" = Interactive mode
    main_menu
else
    # CLI mode with commands
    case "$CMD" in
        # Protection modes
        h|hide|on)
            if [ "$ARG2" == "--force" ]; then
                process "h" "--force"
            else
                confirm_and_process "h"
            fi
            ;;
        
        u|unlock|off)
            if [ "$ARG2" == "--force" ]; then
                process "u" "--force"
            else
                confirm_and_process "u"
            fi
            ;;
        
        free|perm)
            if [ "$ARG2" == "--force" ]; then
                process "free" "--force"
            else
                confirm_and_process "free"
            fi
            ;;
        
        # App management
        all|browse)
            show_all_users
            ;;
        
        aa|search)
            if [ -z "$ARG2" ]; then
                app_search_picker ""
            else
                app_search_picker "$ARG2"
            fi
            ;;
        
        apps)
            app_menu
            ;;
        
        # Folder management
        af|folder)
            file_picker
            ;;
        
        # Remove
        r|rm|remove)
            remover "$ARG2"
            ;;
        
        # List
        l|list)
            show_list
            ;;
        
        # Utilities
        s|status)
            show_status
            ;;
        
        db|refresh)
            header
            update_cache
            pause
            ;;
        
        rescue)
            $0 hide --force
            ;;
        
        # Help
        help|--help|-h)
            show_help
            ;;
        
        # Unknown command
        *)
            echo -e "${WARNING}[!] Unknown command: $CMD${RESET}"
            echo -e "${INFO}[i] Run 'st help' for command list or 'st menu' for interactive mode${RESET}"
            exit 1
            ;;
    esac
fi

