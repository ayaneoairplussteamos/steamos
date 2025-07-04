#!/bin/bash
# shellcheck disable=SC1091,SC1128

set -eo pipefail

VERSION="0.3"   # 版本號

# =============================================================================
# SteamOS 增強工具
# curl -L "https://raw.githubusercontent.com/ayaneoairplussteamos/steamos/refs/heads/main/steamos/steamos-i.sh" | sh
# =============================================================================

# 基礎配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# DEBUG開關 - 設置為true跳過SteamOS檢查
DEBUG=${DEBUG:-false}

# 強制命令行模式 - 設置為true默認使用命令行界面
FORCE_CLI=${FORCE_CLI:-false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/steamos-installer.log"
UI_MODE=""

# 路徑定義
DECKY_HOME="$HOME/homebrew"
DECKY_PLUGINS_DIR="$DECKY_HOME/plugins"
POWER_BUTTON_HWDB_PATH="/etc/udev/hwdb.d/85-steamos-power-button.hwdb"
POWER_BUTTON_HWDB_URL="https://raw.githubusercontent.com/ayaneoairplussteamos/steamos/refs/heads/main/steamos/steamos-power-button.hwdb"

POWER_CONTROL_BIN_URL="https://github.com/ayaneoairplussteamos/steamos/raw/refs/heads/main/decky/plugins/PowerControl.tar.gz"
HUE_SYNC_BIN_URL="https://github.com/ayaneoairplussteamos/steamos/raw/refs/heads/main/decky/plugins/huesync.tar.gz"
DECKY_PLUMBER_BIN_URL="https://github.com/ayaneoairplussteamos/steamos/raw/refs/heads/main/decky/plugins/DeckyPlumber.tar.gz"
DECKY_CLASH_BIN_URL="https://github.com/ayaneoairplussteamos/steamos/raw/refs/heads/main/decky/plugins/DeckyClash.zip"

# =============================================================================
# 插件配置 - 便於維護和擴展
# =============================================================================

declare -A PLUGINS=(
    ["setup_password"]="01||🔐 設置用戶密碼||setup_user_password_internal"
    ["enable_ssh"]="02||🌐 啟用SSH服務||enable_ssh_service_internal"
    ["decky_loader"]="03||📦 安裝 Decky Loader (插件平台)||install_decky_loader"
    ["tomoon"]="04||🌙 安裝 ToMoon 插件 (小貓咪)||curl -L https://i.ohmydeck.net | sh"
    ["decky_clash"]="05||🐈 安裝 DeckyClash 插件 (另一個小貓咪)||curl -L https://github.com/chenx-dust/DeckyClash/raw/main/install.sh | sh"
    ["power_control"]="06||🔋 安裝 PowerControl 插件 (功耗控制)||curl -L https://github.com/mengmeet/PowerControl/raw/main/install.sh | sh"
    ["simple_deck_tdp"]="07||🔌 安裝 SimpleDeckTDP 插件 (另一個功耗控制)||curl -L https://github.com/aarron-lee/SimpleDeckyTDP/raw/main/install.sh | sh"
    ["huesync"]="08||🚥 安裝 HueSync 插件 (燈效設置)||curl -L https://github.com/honjow/huesync/raw/main/install.sh | sh"
    ["decky_plumber"]="09||🎮 安裝 DeckyPlumber 插件 (控制器映射管理)||curl -L https://github.com/aarron-lee/DeckyPlumber/raw/main/install.sh | sh"
    ["power_button"]="10||🔘 安裝電源按鈕支持||install_power_button_hwdb_internal"
)

# 插件目錄名映射（用於檢測）
declare -A PLUGIN_DIRS=(
    ["tomoon"]="ToMoon,tomoon,to-moon"
    ["decky_clash"]="DeckyClash,deckyclash,decky-clash"
    ["power_control"]="PowerControl,powercontrol,power-control,PowerTools"
    ["simple_deck_tdp"]="SimpleDeckTDP,simpledecktdp,simple-deck-tdp"
    ["huesync"]="HueSync,huesync,hue-sync"
    ["decky_plumber"]="DeckyPlumber,deckyplumber,decky-plumber,Plumber"
)

# 備用安裝URL配置（支持本地壓縮包安裝）
declare -A PLUGIN_BACKUP_URLS=(
    ["power_control"]="$POWER_CONTROL_BIN_URL"
    ["huesync"]="$HUE_SYNC_BIN_URL"
    ["decky_plumber"]="$DECKY_PLUMBER_BIN_URL"
    ["decky_clash"]="$DECKY_CLASH_BIN_URL"
)

# =============================================================================
# 工具函數
# =============================================================================

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"; }
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
    log "INFO: $1"
}
print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
    log "SUCCESS: $1"
}
print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
    log "WARNING: $1"
}
print_error() {
    echo -e "${RED}[錯誤]${NC} $1"
    log "ERROR: $1"
}
print_step() {
    echo -e "${PURPLE}[步驟]${NC} $1"
    log "STEP: $1"
}

check_network() {
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1
}

# 獲取按序號排序的插件鍵列表
get_ordered_keys() {
    local temp_array=()
    for key in "${!PLUGINS[@]}"; do
        local order_num="${PLUGINS[$key]%%||*}"  # 提取序號
        temp_array+=("$order_num:$key")
    done
    
    # 按序號排序並提取鍵名
    printf '%s\n' "${temp_array[@]}" | sort -n | cut -d: -f2
}

# =============================================================================
# Decky 插件安裝相關
# =============================================================================

install_decky_loader() {
    print_info "安裝 Decky Loader 插件系統..."

    if [ -d "${HOME}/.steam/steam/" ]; then
        touch "${HOME}/.steam/steam/.cef-enable-remote-debugging" || true
    fi
    if [ -d "${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/" ]; then
        touch "${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging" || true
    fi

    curl -L https://dl.ohmydeck.net | sh

    print_success "安裝 Decky Loader 插件系統完成"
}

install_decky_plugin_internal() {
    local plugin_name="$1"
    local plugin_url="$2"

    print_info "安裝 $plugin_name 插件..."

    # 下載壓縮包到臨時文件
    basename=$(basename "$plugin_url")
    ext=${basename##*.}

    if ! curl -sL "$plugin_url" -o "$basename"; then
        print_error "下載失敗"
        return 1
    fi

    tmp_dir=$(mktemp -d)

    if [[ "$ext" == "gz" && "$basename" =~ \.tar\.gz ]]; then
        tar -xzf "$basename" -C "$tmp_dir"
    elif [[ "$ext" == "zip" ]]; then
        unzip "$basename" -d "$tmp_dir"
    fi

    rm -rf "$tmp_dir/"*"/{node_modules,.git,.vscode}"

    chmod -R 777 "$DECKY_PLUGINS_DIR"

    cp -rv "$tmp_dir/"* "$DECKY_PLUGINS_DIR"
    rm -rf "$tmp_dir" "$basename"

    print_success "安裝 $plugin_name 插件完成"
    cmd="systemctl restart plugin_loader"
    execute_sudo "$cmd" "decky 插件重啟"
}

# 全局變量用於傳遞錯誤信息
LAST_ERROR_MSG=""

# 選擇安裝方式（原始方式 vs 備用方式）
choose_install_method() {
    local plugin_key="$1"
    local plugin_desc="$2"

    if [[ "$UI_MODE" == "gui" ]]; then
        choose_install_method_gui "$plugin_key" "$plugin_desc"
    else
        choose_install_method_cli "$plugin_key" "$plugin_desc"
    fi
}

# 命令行模式選擇安裝方式
choose_install_method_cli() {
    local plugin_key="$1"
    local plugin_desc="$2"

    echo -e "${YELLOW}檢測到 $plugin_desc 支持多種安裝方式：${NC}" >&2
    echo "1) 原始安裝方式 (從GitHub下載)" >&2
    echo "2) 備用安裝方式 (從備用地址下載)" >&2
    echo >&2

    while true; do
        read -r -p "請選擇安裝方式 (1/2): " choice </dev/tty >&2
        case $choice in
        1)
            echo "original"
            return 0
            ;;
        2)
            echo "backup"
            return 0
            ;;
        *)
            print_error "無效選擇，請輸入 1 或 2"
            ;;
        esac
    done
}

# 圖形模式選擇安裝方式
choose_install_method_gui() {
    local plugin_key="$1"
    local plugin_desc="$2"

    if zenity --question \
        --title="選擇安裝方式" \
        --text="檢測到 $plugin_desc 支持多種安裝方式：\n\n🌐 原始安裝方式 (從GitHub下載)\n📦 備用安裝方式 (從備用地址下載)\n\n是否使用備用安裝方式？" \
        --ok-label="備用方式" \
        --cancel-label="原始方式"; then
        echo "backup"
    else
        echo "original"
    fi
}

# =============================================================================
# 密碼和SSH相關函數
# =============================================================================

# 密碼狀態緩存變量
PASSWORD_STATUS_CACHE=""
PASSWORD_STATUS_CHECKED=false

# 檢查用戶是否設置了密碼
check_user_password() {
    # 如果已經檢查過，直接返回緩存結果
    if [[ "$PASSWORD_STATUS_CHECKED" == "true" ]]; then
        [[ "$PASSWORD_STATUS_CACHE" == "has_password" ]] && return 0 || return 1
    fi

    # 檢查passwd文件中的密碼字段
    local passwd_entry
    passwd_entry=$(getent passwd "$USER" 2>/dev/null)

    if [[ -z "$passwd_entry" ]]; then
        # 用戶不存在
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 解析passwd條目：username:password:uid:gid:gecos:home:shell
    local password_field
    password_field=$(echo "$passwd_entry" | cut -d: -f2)

    # 如果密碼字段為空，明確表示沒有密碼
    if [[ -z "$password_field" ]]; then
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 如果密碼字段是"!"或"*"，表示賬戶被鎖定或沒有密碼
    if [[ "$password_field" == "!" ]] || [[ "$password_field" == "*" ]]; then
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 如果密碼字段是"x"，表示密碼在shadow文件中
    # 使用passwd命令的行為來檢測是否有密碼
    if [[ "$password_field" == "x" ]]; then
        # 嘗試使用passwd命令，檢查是否要求當前密碼
        local passwd_output
        passwd_output=$(echo -e "\n" | timeout 1 passwd 2>&1)

        # 如果要求當前密碼，說明有密碼
        if echo "$passwd_output" | grep -q "當前的密碼\|Current password\|current password"; then
            PASSWORD_STATUS_CACHE="has_password"
            PASSWORD_STATUS_CHECKED=true
            return 0 # 有密碼
        fi

        # 如果直接要求新密碼，可能沒有密碼
        if echo "$passwd_output" | grep -q "新的密碼\|New password\|new password"; then
            PASSWORD_STATUS_CACHE="no_password"
            PASSWORD_STATUS_CHECKED=true
            return 1 # 沒有密碼
        fi

        # 如果無法確定，檢查是否是已知的無密碼環境
        if [[ "$USER" == "deck" ]] && [[ -f /etc/os-release ]]; then
            source /etc/os-release 2>/dev/null
            if [[ "$ID" == "steamos" ]]; then
                PASSWORD_STATUS_CACHE="no_password"
                PASSWORD_STATUS_CHECKED=true
                return 1 # Steam Deck默認沒有密碼
            fi
        fi

        # 其他情況，保守地假設有密碼
        PASSWORD_STATUS_CACHE="has_password"
        PASSWORD_STATUS_CHECKED=true
        return 0
    fi

    # 其他情況（如密碼字段直接包含加密密碼），假設有密碼
    PASSWORD_STATUS_CACHE="has_password"
    PASSWORD_STATUS_CHECKED=true
    return 0
}

# 設置用戶密碼
setup_user_password_internal() {
    print_info "設置用戶密碼..."

    if [[ "$UI_MODE" == "gui" ]]; then
        setup_password_gui
    else
        setup_password_cli
    fi
}

# 命令行模式設置密碼
setup_password_cli() {
    echo -e "${YELLOW}為了安全使用某些功能，需要為用戶 '$USER' 設置密碼${NC}"
    echo -e "${BLUE}請輸入新密碼（輸入時不會顯示）：${NC}"

    if passwd </dev/tty; then
        print_success "密碼設置成功"
        return 0
    else
        print_error "密碼設置失敗"
        return 1
    fi
}

# 圖形模式設置密碼
setup_password_gui() {
    local password1 password2

    # 第一次輸入密碼
    password1=$(zenity --password --title="設置用戶密碼" \
        --text="為了安全使用某些功能，請為用戶 '$USER' 設置密碼：")

    if [[ -z "$password1" ]]; then
        zenity --error --text="密碼設置已取消"
        return 1
    fi

    # 確認密碼
    password2=$(zenity --password --title="確認密碼" \
        --text="請再次輸入密碼以確認：")

    if [[ "$password1" != "$password2" ]]; then
        zenity --error --text="兩次輸入的密碼不一致，請重試"
        return 1
    fi

    # 設置密碼
    if echo -e "$password1\n$password1" | passwd "$USER" >/dev/null 2>&1; then
        zenity --info --text="✅ 密碼設置成功"
        print_success "密碼設置成功"
        return 0
    else
        zenity --error --text="❌ 密碼設置失敗"
        print_error "密碼設置失敗"
        return 1
    fi
}

# 檢查SSH服務狀態
check_ssh_service() {
    systemctl is-enabled sshd >/dev/null 2>&1 && systemctl is-active sshd >/dev/null 2>&1
}

# 檢查SSH密碼認證是否啟用
check_ssh_password_auth() {
    if [[ -f /etc/ssh/sshd_config ]]; then
        # 檢查PasswordAuthentication是否為yes
        grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null
    else
        return 1
    fi
}

# 啟用SSH服務
enable_ssh_service_internal() {
    print_info "配置SSH服務..."

    # 檢查是否已設置密碼
    if ! check_user_password; then
        local msg="檢測到用戶未設置密碼，SSH服務需要密碼才能安全使用。是否現在設置密碼？"
        local should_setup=false

        if [[ "$UI_MODE" == "gui" ]]; then
            if zenity --question --text="$msg"; then
                should_setup=true
            fi
        else
            echo -e "${YELLOW}$msg${NC}"
            read -p "是否現在設置密碼？(y/N): " -n 1 -r </dev/tty
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && should_setup=true
        fi

        if $should_setup; then
            if ! setup_user_password_internal; then
                print_error "密碼設置失敗，無法繼續配置SSH"
                return 1
            fi
        else
            print_warning "跳過SSH配置（建議先設置密碼）"
            return 1
        fi
    fi

    # 配置SSH
    local ssh_config_cmd="
        # 啟用SSH服務
        systemctl enable sshd
        systemctl start sshd
        
        # 備份原配置
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.\$(date +%Y%m%d_%H%M%S)
        
        # 啟用密碼認證
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        
        # 重啟SSH服務
        systemctl restart sshd
        
        # 開放防火墻端口（如果有防火墻）
        if command -v ufw >/dev/null 2>&1; then
            ufw allow ssh
        fi
    "

    if execute_sudo "$ssh_config_cmd" "配置SSH服務"; then
        print_success "SSH服務配置完成"

        local msg="SSH服務已啟用並配置完成！\n\n現在可以通過SSH連接到此設備\n用戶名：$USER\n端口：22"

        if [[ "$UI_MODE" == "gui" ]]; then
            zenity --info --title="SSH配置完成" --text="$msg"
        else
            echo -e "${GREEN}$msg${NC}"
        fi

        return 0
    else
        print_error "SSH服務配置失敗"
        return 1
    fi
}

# =============================================================================
# 環境檢測（增強版）
# =============================================================================

detect_ui_mode() {
    # 強制命令行模式檢查
    if [[ "$FORCE_CLI" == "true" ]]; then
        UI_MODE="cli"
        return
    fi

    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]] || [[ "$TERM" == "linux" ]]; then
        UI_MODE="cli"
    elif [[ -n "$DISPLAY" ]] && command -v zenity >/dev/null 2>&1; then
        UI_MODE="gui"
    else
        UI_MODE="cli"
    fi
}

check_system() {
    # 檢查用戶權限
    if [ "$EUID" -eq 0 ]; then
        local msg="請以普通用戶身份運行此腳本"
        [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
        exit 1
    fi

    # 檢查SteamOS
    if [[ "$DEBUG" != "true" ]]; then
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [ "$ID" != "steamos" ]; then
                local msg="此腳本僅適用於SteamOS系統"
                [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
                exit 1
            fi
        fi
    else
        print_warning "DEBUG模式：跳過SteamOS檢查"
    fi

    # 檢查網絡
    if ! check_network; then
        local msg="網絡連接失敗，請檢查網絡設置"
        [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
        exit 1
    fi

    # 檢查密碼狀態並提示
    check_password_and_prompt
}

# 檢查密碼並提示用戶
check_password_and_prompt() {
    if ! check_user_password; then
        local msg="檢測到用戶未設置密碼。\n\n為了安全使用sudo和SSH等功能，強烈建議設置密碼。\n是否現在設置？"
        local should_setup=false

        if [[ "$UI_MODE" == "gui" ]]; then
            if zenity --question --title="密碼設置建議" --text="$msg"; then
                should_setup=true
            fi
        else
            print_warning "檢測到用戶未設置密碼"
            echo -e "${YELLOW}為了安全使用sudo和SSH等功能，強烈建議設置密碼${NC}"
            read -p "是否現在設置密碼？(y/N): " -n 1 -r </dev/tty
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && should_setup=true
        fi

        if $should_setup; then
            setup_user_password_internal
        else
            print_info "跳過密碼設置（某些功能可能受限）"
        fi
    fi
}

# =============================================================================
# 狀態檢測
# =============================================================================

# 檢查 Decky Loader
check_decky_loader() {
    [[ -d "$DECKY_HOME" ]] && [[ -d "$DECKY_PLUGINS_DIR" ]]
}

# 檢查插件
check_plugin() {
    local plugin_key="$1"
    local dirs="${PLUGIN_DIRS[$plugin_key]}"

    [[ -z "$dirs" ]] && return 1

    IFS=',' read -ra DIR_ARRAY <<<"$dirs"
    for dir in "${DIR_ARRAY[@]}"; do
        if [[ -f "$DECKY_PLUGINS_DIR/$dir/plugin.json" ]]; then
            return 0
        fi
    done
    return 1
}

# 檢查電源按鈕
check_power_button() {
    [[ -f "$POWER_BUTTON_HWDB_PATH" ]]
}

# 獲取狀態
get_status() {
    local format="${1:-simple}"
    local status=""

    # 系統狀態
    if check_user_password; then
        status+="✓ 用戶密碼已設置\n"
    else
        status+="✗ 用戶密碼未設置\n"
    fi

    if check_ssh_service; then
        status+="✓ SSH服務已啟用"
        if check_ssh_password_auth; then
            status+=" (密碼認證已啟用)"
        fi
        status+="\n"
    else
        status+="✗ SSH服務未啟用\n"
    fi

    # Decky Loader
    if check_decky_loader; then
        status+="✓ Decky Loader\n"
    else
        status+="✗ Decky Loader\n"
    fi

    # 插件
    for plugin in tomoon power_control huesync decky_plumber; do
        local name
        case $plugin in
        tomoon) name="ToMoon" ;;
        power_control) name="PowerControl" ;;
        huesync) name="HueSync" ;;
        decky_plumber) name="DeckyPlumber" ;;
        esac

        if check_plugin "$plugin"; then
            status+="✓ $name 插件\n"
        else
            status+="✗ $name 插件\n"
        fi
    done

    # 電源按鈕
    if check_power_button; then
        status+="✓ 電源按鈕支持\n"
    else
        status+="✗ 電源按鈕支持\n"
    fi

    echo -e "$status"
}

# =============================================================================
# 權限管理
# =============================================================================

execute_sudo() {
    local cmd="$1"
    local desc="$2"

    if [[ "$UI_MODE" == "gui" ]]; then
        if command -v pkexec >/dev/null 2>&1; then
            pkexec bash -c "$cmd"
        else
            local password
            password=$(zenity --password --title="需要管理員權限")
            [[ -n "$password" ]] && echo "$password" | sudo -S bash -c "$cmd"
        fi
    else
        print_step "$desc"
        sudo bash -c "$cmd"
    fi
}

# =============================================================================
# 安裝函數
# =============================================================================

# 電源按鈕安裝的內部函數
install_power_button_hwdb_internal() {
    local tmp_file="/tmp/steamos-power-button.hwdb"

    curl -sL "$POWER_BUTTON_HWDB_URL" -o "$tmp_file" || return 1

    local cmd="mkdir -p /etc/udev/hwdb.d && \
    cp '$tmp_file' '$POWER_BUTTON_HWDB_PATH' && \
    udevadm hwdb --update && \
    udevadm trigger && \
    rm -f '$tmp_file'"
    execute_sudo "$cmd" "安裝電源按鈕支持"
}

# 通用安裝函數
install_item() {
    local key="$1"
    local info="${PLUGINS[$key]}"

    # 清空上次的錯誤信息
    LAST_ERROR_MSG=""

    [[ -z "$info" ]] && {
        LAST_ERROR_MSG="未知安裝項: $key"
        print_error "$LAST_ERROR_MSG"
        return 1
    }

    # 使用參數展開正確解析三個部分
    local order="${info%%||*}"
    local rest="${info#*||}"
    local desc="${rest%%||*}"
    local cmd="${rest#*||}"
    print_info "$desc"

    # 檢查已安裝狀態
    case $key in
    decky_loader)
        check_decky_loader && {
            print_warning "已安裝"
            return 0
        }
        ;;
    power_button)
        check_power_button && {
            print_warning "已安裝"
            return 0
        }
        ;;
    setup_password)
        check_user_password && {
            print_warning "密碼已設置"
            return 0
        }
        ;;
    enable_ssh)
        if check_ssh_service && check_ssh_password_auth; then
            print_warning "SSH服務已啟用且配置完成"
            return 0
        fi
        ;;
    *)
        if ! check_decky_loader; then
            LAST_ERROR_MSG="請先安裝 Decky Loader"
            print_error "$LAST_ERROR_MSG"
            return 1
        fi
        check_plugin "$key" && {
            print_warning "已安裝"
            return 0
        }
        ;;
    esac

    # 檢查是否有備用安裝方式
    print_info "檢查是否有備用安裝方式 key: $key"
    local backup_url="${PLUGIN_BACKUP_URLS[$key]}"
    print_info "backup_url: $backup_url"
    if [[ -n "$backup_url" ]]; then
        # 有備用安裝方式，詢問用戶選擇
        local method_choice
        method_choice=$(choose_install_method "$key" "$desc")

        case $method_choice in
        "original")
            # 選擇原始安裝方式
            print_info "使用原始安裝方式..."
            if eval "$cmd"; then
                print_success "$desc 完成"
                return 0
            else
                LAST_ERROR_MSG="原始安裝方式執行失敗"
                print_error "$LAST_ERROR_MSG"
                return 1
            fi
            ;;
        "backup")
            # 選擇備用安裝方式
            print_info "使用備用安裝方式..."
            if install_decky_plugin_internal "$desc" "$backup_url"; then
                print_success "$desc 完成"
                return 0
            else
                LAST_ERROR_MSG="備用安裝方式執行失敗"
                print_error "$LAST_ERROR_MSG"
                return 1
            fi
            ;;
        *)
            # 用戶取消或其他情況
            LAST_ERROR_MSG="安裝方式選擇異常"
            print_error "$LAST_ERROR_MSG"
            return 1
            ;;
        esac
    else
        # 沒有備用安裝方式，直接執行原始安裝
        if eval "$cmd"; then
            print_success "$desc 完成"
            return 0
        else
            LAST_ERROR_MSG="安裝命令執行失敗"
            print_error "$LAST_ERROR_MSG"
            return 1
        fi
    fi
}

# 一鍵安裝
install_all() {
    print_info "開始一鍵安裝..."
    local failed=0

    # 首先設置密碼（如果需要）
    if ! check_user_password; then
        install_item "setup_password" || ((failed++))
    fi

    # 安裝其他組件
    for key in decky_loader tomoon power_control huesync decky_plumber power_button enable_ssh; do
        install_item "$key" || ((failed++))
    done

    if [[ $failed -eq 0 ]]; then
        print_success "🎉 全部安裝完成！"
    else
        print_warning "⚠️ 完成，但有 $failed 項失敗"
    fi
}

# =============================================================================
# 命令行界面
# =============================================================================

show_cli_menu() {
    clear
    echo -e "${BLUE}=== SteamOS 增強工具 v${VERSION} ===${NC}"
    echo
    echo -e "${YELLOW}當前狀態：${NC}"
    get_status simple
    echo

    # 動態生成菜單項
    local ordered_keys=()
    mapfile -t ordered_keys < <(get_ordered_keys)

    # 根據PLUGINS數組生成菜單
    local i=1
    for key in "${ordered_keys[@]}"; do
        local desc="${PLUGINS[$key]}"
        if [[ -n "$desc" ]]; then
            # 提取描述部分（跳過序號）
            desc="${desc#*||}"    # 去掉序號部分
            desc="${desc%%||*}"   # 提取描述部分
            printf "%2d) %s\n" "$i" "$desc"
            ((i++))
        fi
    done

    echo " a) 🚀 一鍵安裝全部"
    echo " 0) 📊 檢查詳細狀態"
    echo " q) 🚪 退出"
    echo
}

run_cli() {
    while true; do
        show_cli_menu
        read -r -p "請選擇: " choice </dev/tty
        echo

        case $choice in
        0)
            echo
            get_status detailed
            ;;
        a)
            install_all
            ;;
        q | Q)
            print_info "退出"
            exit 0
            ;;
        *)
            # 動態處理數字選項
            local ordered_keys=()
            mapfile -t ordered_keys < <(get_ordered_keys)
            if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#ordered_keys[@]} ]]; then
                local index=$((choice - 1))
                local key="${ordered_keys[$index]}"
                install_item "$key"
            else
                print_error "無效選項"
            fi
            ;;
        esac

        echo
        read -r -p "按回車繼續..." </dev/tty
    done
}

# =============================================================================
# 圖形界面
# =============================================================================

show_gui_menu() {
    # 簡化但直觀的狀態顯示
    local password_status ssh_status decky_status
    check_user_password && password_status="已設置" || password_status="未設置"
    check_ssh_service && ssh_status="已啟用" || ssh_status="未啟用"
    check_decky_loader && decky_status="已安裝" || decky_status="未安裝"

    # 動態生成菜單項
    local menu_items=()

    # 動態生成菜單項
    local ordered_keys=()
    mapfile -t ordered_keys < <(get_ordered_keys)

    # 根據PLUGINS數組生成菜單項
    for key in "${ordered_keys[@]}"; do
        local desc="${PLUGINS[$key]}"
        if [[ -n "$desc" ]]; then
            # 提取描述部分（跳過序號）
            desc="${desc#*||}"    # 去掉序號部分
            desc="${desc%%||*}"   # 提取描述部分
            menu_items+=("$key" "$desc")  # desc已包含圖標
        fi
    done

    # 添加固定的功能項
    menu_items+=("install_all" "🚀 一鍵安裝全部")
    menu_items+=("check_status" "📊 檢查詳細狀態")
    menu_items+=("exit" "🚪 退出")

    zenity --list \
        --title="SteamOS 增強工具 v${VERSION}" \
        --text="🔐 密碼: $password_status | 🌐 SSH: $ssh_status | 📦 Decky: $decky_status" \
        --column="操作" --column="描述" \
        --width=750 --height=600 \
        "${menu_items[@]}"
}

run_gui() {
    while true; do
        local choice
        choice=$(show_gui_menu)

        [[ -z "$choice" ]] && exit 0

        case $choice in
        install_all)
            if zenity --question --text="確定要一鍵安裝全部嗎？\n\n這將包括：\n• 設置密碼（如需要）\n• 啟用SSH服務\n• 安裝所有Decky插件\n• 配置電源按鈕"; then
                install_all
                zenity --info --text="批量安裝完成，詳情請查看終端"
            fi
            ;;
        check_status)
            local status
            status=$(get_status detailed)
            zenity --info --title="詳細狀態" --text="$status" --width=500
            ;;
        exit)
            exit 0
            ;;
        *)
            # 動態處理PLUGINS數組中的所有項目
            if [[ -n "${PLUGINS[$choice]}" ]]; then
                # 直接調用install_item，讓它自己處理安裝方式選擇
                if install_item "$choice"; then
                    zenity --info --text="✅ 操作完成"
                else
                    # 顯示具體的錯誤信息
                    local desc="${PLUGINS[$choice]}"
                    desc="${desc#*||}"    # 去掉序號部分
                    desc="${desc%%||*}"   # 提取描述部分
                    local error_text="❌ $desc 失敗"
                    if [[ -n "$LAST_ERROR_MSG" ]]; then
                        error_text="$error_text\n\n錯誤原因：$LAST_ERROR_MSG"
                    fi
                    error_text="$error_text\n\n詳細信息請查看終端輸出"
                    zenity --error --text="$error_text"
                fi
            else
                zenity --error --text="未知操作: $choice"
            fi
            ;;
        esac
    done
}

# =============================================================================
# 主程序
# =============================================================================

main() {
    echo "=== SteamOS 增強工具 v${VERSION} 啟動 $(date) ===" >"$LOG_FILE"

    detect_ui_mode
    print_info "運行模式: $UI_MODE"

    check_system

    if [[ "$UI_MODE" == "gui" ]]; then
        run_gui
    else
        run_cli
    fi
}

# 執行主程序
[[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ -z "${BASH_SOURCE[0]}" ]] && main "$@"
