#!/bin/bash
# shellcheck disable=SC1091,SC1128

set -eo pipefail

VERSION="0.3"   # 版本号

# =============================================================================
# SteamOS 增强工具
# curl -L "https://gitee.com/honjow/sk-chos-scripts/raw/master/steamos/steamos-i.sh" | sh
# curl -L https://tinyurl.com/steamos-tool | sh
# =============================================================================

# 基础配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# DEBUG开关 - 设置为true跳过SteamOS检查
DEBUG=${DEBUG:-false}

# 强制命令行模式 - 设置为true默认使用命令行界面
FORCE_CLI=${FORCE_CLI:-false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/steamos-installer.log"
UI_MODE=""

# 路径定义
DECKY_HOME="$HOME/homebrew"
DECKY_PLUGINS_DIR="$DECKY_HOME/plugins"
POWER_BUTTON_HWDB_PATH="/etc/udev/hwdb.d/85-steamos-power-button.hwdb"
POWER_BUTTON_HWDB_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/steamos/steamos-power-button.hwdb"

POWER_CONTROL_BIN_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/decky/plugins/PowerControl.tar.gz"
HUE_SYNC_BIN_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/decky/plugins/huesync.tar.gz"
DECKY_PLUMBER_BIN_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/decky/plugins/DeckyPlumber.tar.gz"
DECKY_CLASH_BIN_URL="https://gitee.com/honjow/sk-chos-scripts/raw/master/decky/plugins/DeckyClash.zip"

# =============================================================================
# 插件配置 - 便于维护和扩展
# =============================================================================

declare -A PLUGINS=(
    ["setup_password"]="01||🔐 设置用户密码||setup_user_password_internal"
    ["enable_ssh"]="02||🌐 启用SSH服务||enable_ssh_service_internal"
    ["decky_loader"]="03||📦 安装 Decky Loader (插件平台)||install_decky_loader"
    ["tomoon"]="04||🌙 安装 ToMoon 插件 (小猫咪)||curl -L https://i.ohmydeck.net | sh"
    ["decky_clash"]="05||🐈 安装 DeckyClash 插件 (另一个小猫咪)||curl -L https://github.com/chenx-dust/DeckyClash/raw/main/install.sh | sh"
    ["power_control"]="06||🔋 安装 PowerControl 插件 (功耗控制)||curl -L https://github.com/mengmeet/PowerControl/raw/main/install.sh | sh"
    ["simple_deck_tdp"]="07||🔌 安装 SimpleDeckTDP 插件 (另一个功耗控制)||curl -L https://github.com/aarron-lee/SimpleDeckyTDP/raw/main/install.sh | sh"
    ["huesync"]="08||🚥 安装 HueSync 插件 (灯效设置)||curl -L https://github.com/honjow/huesync/raw/main/install.sh | sh"
    ["decky_plumber"]="09||🎮 安装 DeckyPlumber 插件 (控制器映射管理)||curl -L https://github.com/aarron-lee/DeckyPlumber/raw/main/install.sh | sh"
    ["power_button"]="10||🔘 安装电源按钮支持||install_power_button_hwdb_internal"
)

# 插件目录名映射（用于检测）
declare -A PLUGIN_DIRS=(
    ["tomoon"]="ToMoon,tomoon,to-moon"
    ["decky_clash"]="DeckyClash,deckyclash,decky-clash"
    ["power_control"]="PowerControl,powercontrol,power-control,PowerTools"
    ["simple_deck_tdp"]="SimpleDeckTDP,simpledecktdp,simple-deck-tdp"
    ["huesync"]="HueSync,huesync,hue-sync"
    ["decky_plumber"]="DeckyPlumber,deckyplumber,decky-plumber,Plumber"
)

# 备用安装URL配置（支持本地压缩包安装）
declare -A PLUGIN_BACKUP_URLS=(
    ["power_control"]="$POWER_CONTROL_BIN_URL"
    ["huesync"]="$HUE_SYNC_BIN_URL"
    ["decky_plumber"]="$DECKY_PLUMBER_BIN_URL"
    ["decky_clash"]="$DECKY_CLASH_BIN_URL"
)

# =============================================================================
# 工具函数
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
    echo -e "${RED}[错误]${NC} $1"
    log "ERROR: $1"
}
print_step() {
    echo -e "${PURPLE}[步骤]${NC} $1"
    log "STEP: $1"
}

check_network() {
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1
}

# 获取按序号排序的插件键列表
get_ordered_keys() {
    local temp_array=()
    for key in "${!PLUGINS[@]}"; do
        local order_num="${PLUGINS[$key]%%||*}"  # 提取序号
        temp_array+=("$order_num:$key")
    done
    
    # 按序号排序并提取键名
    printf '%s\n' "${temp_array[@]}" | sort -n | cut -d: -f2
}

# =============================================================================
# Decky 插件安装相关
# =============================================================================

install_decky_loader() {
    print_info "安装 Decky Loader 插件系统..."

    if [ -d "${HOME}/.steam/steam/" ]; then
        touch "${HOME}/.steam/steam/.cef-enable-remote-debugging" || true
    fi
    if [ -d "${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/" ]; then
        touch "${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging" || true
    fi

    curl -L https://dl.ohmydeck.net | sh

    print_success "安装 Decky Loader 插件系统完成"
}

install_decky_plugin_internal() {
    local plugin_name="$1"
    local plugin_url="$2"

    print_info "安装 $plugin_name 插件..."

    # 下载压缩包到临时文件
    basename=$(basename "$plugin_url")
    ext=${basename##*.}

    if ! curl -sL "$plugin_url" -o "$basename"; then
        print_error "下载失败"
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

    print_success "安装 $plugin_name 插件完成"
    cmd="systemctl restart plugin_loader"
    execute_sudo "$cmd" "decky 插件重启"
}

# 全局变量用于传递错误信息
LAST_ERROR_MSG=""

# 选择安装方式（原始方式 vs 备用方式）
choose_install_method() {
    local plugin_key="$1"
    local plugin_desc="$2"

    if [[ "$UI_MODE" == "gui" ]]; then
        choose_install_method_gui "$plugin_key" "$plugin_desc"
    else
        choose_install_method_cli "$plugin_key" "$plugin_desc"
    fi
}

# 命令行模式选择安装方式
choose_install_method_cli() {
    local plugin_key="$1"
    local plugin_desc="$2"

    echo -e "${YELLOW}检测到 $plugin_desc 支持多种安装方式：${NC}" >&2
    echo "1) 原始安装方式 (从GitHub下载)" >&2
    echo "2) 备用安装方式 (从备用地址下载)" >&2
    echo >&2

    while true; do
        read -r -p "请选择安装方式 (1/2): " choice </dev/tty >&2
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
            print_error "无效选择，请输入 1 或 2"
            ;;
        esac
    done
}

# 图形模式选择安装方式
choose_install_method_gui() {
    local plugin_key="$1"
    local plugin_desc="$2"

    if zenity --question \
        --title="选择安装方式" \
        --text="检测到 $plugin_desc 支持多种安装方式：\n\n🌐 原始安装方式 (从GitHub下载)\n📦 备用安装方式 (从备用地址下载)\n\n是否使用备用安装方式？" \
        --ok-label="备用方式" \
        --cancel-label="原始方式"; then
        echo "backup"
    else
        echo "original"
    fi
}

# =============================================================================
# 密码和SSH相关函数
# =============================================================================

# 密码状态缓存变量
PASSWORD_STATUS_CACHE=""
PASSWORD_STATUS_CHECKED=false

# 检查用户是否设置了密码
check_user_password() {
    # 如果已经检查过，直接返回缓存结果
    if [[ "$PASSWORD_STATUS_CHECKED" == "true" ]]; then
        [[ "$PASSWORD_STATUS_CACHE" == "has_password" ]] && return 0 || return 1
    fi

    # 检查passwd文件中的密码字段
    local passwd_entry
    passwd_entry=$(getent passwd "$USER" 2>/dev/null)

    if [[ -z "$passwd_entry" ]]; then
        # 用户不存在
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 解析passwd条目：username:password:uid:gid:gecos:home:shell
    local password_field
    password_field=$(echo "$passwd_entry" | cut -d: -f2)

    # 如果密码字段为空，明确表示没有密码
    if [[ -z "$password_field" ]]; then
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 如果密码字段是"!"或"*"，表示账户被锁定或没有密码
    if [[ "$password_field" == "!" ]] || [[ "$password_field" == "*" ]]; then
        PASSWORD_STATUS_CACHE="no_password"
        PASSWORD_STATUS_CHECKED=true
        return 1
    fi

    # 如果密码字段是"x"，表示密码在shadow文件中
    # 使用passwd命令的行为来检测是否有密码
    if [[ "$password_field" == "x" ]]; then
        # 尝试使用passwd命令，检查是否要求当前密码
        local passwd_output
        passwd_output=$(echo -e "\n" | timeout 1 passwd 2>&1)

        # 如果要求当前密码，说明有密码
        if echo "$passwd_output" | grep -q "当前的密码\|Current password\|current password"; then
            PASSWORD_STATUS_CACHE="has_password"
            PASSWORD_STATUS_CHECKED=true
            return 0 # 有密码
        fi

        # 如果直接要求新密码，可能没有密码
        if echo "$passwd_output" | grep -q "新的密码\|New password\|new password"; then
            PASSWORD_STATUS_CACHE="no_password"
            PASSWORD_STATUS_CHECKED=true
            return 1 # 没有密码
        fi

        # 如果无法确定，检查是否是已知的无密码环境
        if [[ "$USER" == "deck" ]] && [[ -f /etc/os-release ]]; then
            source /etc/os-release 2>/dev/null
            if [[ "$ID" == "steamos" ]]; then
                PASSWORD_STATUS_CACHE="no_password"
                PASSWORD_STATUS_CHECKED=true
                return 1 # Steam Deck默认没有密码
            fi
        fi

        # 其他情况，保守地假设有密码
        PASSWORD_STATUS_CACHE="has_password"
        PASSWORD_STATUS_CHECKED=true
        return 0
    fi

    # 其他情况（如密码字段直接包含加密密码），假设有密码
    PASSWORD_STATUS_CACHE="has_password"
    PASSWORD_STATUS_CHECKED=true
    return 0
}

# 设置用户密码
setup_user_password_internal() {
    print_info "设置用户密码..."

    if [[ "$UI_MODE" == "gui" ]]; then
        setup_password_gui
    else
        setup_password_cli
    fi
}

# 命令行模式设置密码
setup_password_cli() {
    echo -e "${YELLOW}为了安全使用某些功能，需要为用户 '$USER' 设置密码${NC}"
    echo -e "${BLUE}请输入新密码（输入时不会显示）：${NC}"

    if passwd </dev/tty; then
        print_success "密码设置成功"
        return 0
    else
        print_error "密码设置失败"
        return 1
    fi
}

# 图形模式设置密码
setup_password_gui() {
    local password1 password2

    # 第一次输入密码
    password1=$(zenity --password --title="设置用户密码" \
        --text="为了安全使用某些功能，请为用户 '$USER' 设置密码：")

    if [[ -z "$password1" ]]; then
        zenity --error --text="密码设置已取消"
        return 1
    fi

    # 确认密码
    password2=$(zenity --password --title="确认密码" \
        --text="请再次输入密码以确认：")

    if [[ "$password1" != "$password2" ]]; then
        zenity --error --text="两次输入的密码不一致，请重试"
        return 1
    fi

    # 设置密码
    if echo -e "$password1\n$password1" | passwd "$USER" >/dev/null 2>&1; then
        zenity --info --text="✅ 密码设置成功"
        print_success "密码设置成功"
        return 0
    else
        zenity --error --text="❌ 密码设置失败"
        print_error "密码设置失败"
        return 1
    fi
}

# 检查SSH服务状态
check_ssh_service() {
    systemctl is-enabled sshd >/dev/null 2>&1 && systemctl is-active sshd >/dev/null 2>&1
}

# 检查SSH密码认证是否启用
check_ssh_password_auth() {
    if [[ -f /etc/ssh/sshd_config ]]; then
        # 检查PasswordAuthentication是否为yes
        grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null
    else
        return 1
    fi
}

# 启用SSH服务
enable_ssh_service_internal() {
    print_info "配置SSH服务..."

    # 检查是否已设置密码
    if ! check_user_password; then
        local msg="检测到用户未设置密码，SSH服务需要密码才能安全使用。是否现在设置密码？"
        local should_setup=false

        if [[ "$UI_MODE" == "gui" ]]; then
            if zenity --question --text="$msg"; then
                should_setup=true
            fi
        else
            echo -e "${YELLOW}$msg${NC}"
            read -p "是否现在设置密码？(y/N): " -n 1 -r </dev/tty
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && should_setup=true
        fi

        if $should_setup; then
            if ! setup_user_password_internal; then
                print_error "密码设置失败，无法继续配置SSH"
                return 1
            fi
        else
            print_warning "跳过SSH配置（建议先设置密码）"
            return 1
        fi
    fi

    # 配置SSH
    local ssh_config_cmd="
        # 启用SSH服务
        systemctl enable sshd
        systemctl start sshd
        
        # 备份原配置
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.\$(date +%Y%m%d_%H%M%S)
        
        # 启用密码认证
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        
        # 重启SSH服务
        systemctl restart sshd
        
        # 开放防火墙端口（如果有防火墙）
        if command -v ufw >/dev/null 2>&1; then
            ufw allow ssh
        fi
    "

    if execute_sudo "$ssh_config_cmd" "配置SSH服务"; then
        print_success "SSH服务配置完成"

        local msg="SSH服务已启用并配置完成！\n\n现在可以通过SSH连接到此设备\n用户名：$USER\n端口：22"

        if [[ "$UI_MODE" == "gui" ]]; then
            zenity --info --title="SSH配置完成" --text="$msg"
        else
            echo -e "${GREEN}$msg${NC}"
        fi

        return 0
    else
        print_error "SSH服务配置失败"
        return 1
    fi
}

# =============================================================================
# 环境检测（增强版）
# =============================================================================

detect_ui_mode() {
    # 强制命令行模式检查
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
    # 检查用户权限
    if [ "$EUID" -eq 0 ]; then
        local msg="请以普通用户身份运行此脚本"
        [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
        exit 1
    fi

    # 检查SteamOS
    if [[ "$DEBUG" != "true" ]]; then
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [ "$ID" != "steamos" ]; then
                local msg="此脚本仅适用于SteamOS系统"
                [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
                exit 1
            fi
        fi
    else
        print_warning "DEBUG模式：跳过SteamOS检查"
    fi

    # 检查网络
    if ! check_network; then
        local msg="网络连接失败，请检查网络设置"
        [[ "$UI_MODE" == "gui" ]] && zenity --error --text="$msg" || print_error "$msg"
        exit 1
    fi

    # 检查密码状态并提示
    check_password_and_prompt
}

# 检查密码并提示用户
check_password_and_prompt() {
    if ! check_user_password; then
        local msg="检测到用户未设置密码。\n\n为了安全使用sudo和SSH等功能，强烈建议设置密码。\n是否现在设置？"
        local should_setup=false

        if [[ "$UI_MODE" == "gui" ]]; then
            if zenity --question --title="密码设置建议" --text="$msg"; then
                should_setup=true
            fi
        else
            print_warning "检测到用户未设置密码"
            echo -e "${YELLOW}为了安全使用sudo和SSH等功能，强烈建议设置密码${NC}"
            read -p "是否现在设置密码？(y/N): " -n 1 -r </dev/tty
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && should_setup=true
        fi

        if $should_setup; then
            setup_user_password_internal
        else
            print_info "跳过密码设置（某些功能可能受限）"
        fi
    fi
}

# =============================================================================
# 状态检测
# =============================================================================

# 检查 Decky Loader
check_decky_loader() {
    [[ -d "$DECKY_HOME" ]] && [[ -d "$DECKY_PLUGINS_DIR" ]]
}

# 检查插件
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

# 检查电源按钮
check_power_button() {
    [[ -f "$POWER_BUTTON_HWDB_PATH" ]]
}

# 获取状态
get_status() {
    local format="${1:-simple}"
    local status=""

    # 系统状态
    if check_user_password; then
        status+="✓ 用户密码已设置\n"
    else
        status+="✗ 用户密码未设置\n"
    fi

    if check_ssh_service; then
        status+="✓ SSH服务已启用"
        if check_ssh_password_auth; then
            status+=" (密码认证已启用)"
        fi
        status+="\n"
    else
        status+="✗ SSH服务未启用\n"
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

    # 电源按钮
    if check_power_button; then
        status+="✓ 电源按钮支持\n"
    else
        status+="✗ 电源按钮支持\n"
    fi

    echo -e "$status"
}

# =============================================================================
# 权限管理
# =============================================================================

execute_sudo() {
    local cmd="$1"
    local desc="$2"

    if [[ "$UI_MODE" == "gui" ]]; then
        if command -v pkexec >/dev/null 2>&1; then
            pkexec bash -c "$cmd"
        else
            local password
            password=$(zenity --password --title="需要管理员权限")
            [[ -n "$password" ]] && echo "$password" | sudo -S bash -c "$cmd"
        fi
    else
        print_step "$desc"
        sudo bash -c "$cmd"
    fi
}

# =============================================================================
# 安装函数
# =============================================================================

# 电源按钮安装的内部函数
install_power_button_hwdb_internal() {
    local tmp_file="/tmp/steamos-power-button.hwdb"

    curl -sL "$POWER_BUTTON_HWDB_URL" -o "$tmp_file" || return 1

    local cmd="mkdir -p /etc/udev/hwdb.d && \
    cp '$tmp_file' '$POWER_BUTTON_HWDB_PATH' && \
    udevadm hwdb --update && \
    udevadm trigger && \
    rm -f '$tmp_file'"
    execute_sudo "$cmd" "安装电源按钮支持"
}

# 通用安装函数
install_item() {
    local key="$1"
    local info="${PLUGINS[$key]}"

    # 清空上次的错误信息
    LAST_ERROR_MSG=""

    [[ -z "$info" ]] && {
        LAST_ERROR_MSG="未知安装项: $key"
        print_error "$LAST_ERROR_MSG"
        return 1
    }

    # 使用参数展开正确解析三个部分
    local order="${info%%||*}"
    local rest="${info#*||}"
    local desc="${rest%%||*}"
    local cmd="${rest#*||}"
    print_info "$desc"

    # 检查已安装状态
    case $key in
    decky_loader)
        check_decky_loader && {
            print_warning "已安装"
            return 0
        }
        ;;
    power_button)
        check_power_button && {
            print_warning "已安装"
            return 0
        }
        ;;
    setup_password)
        check_user_password && {
            print_warning "密码已设置"
            return 0
        }
        ;;
    enable_ssh)
        if check_ssh_service && check_ssh_password_auth; then
            print_warning "SSH服务已启用且配置完成"
            return 0
        fi
        ;;
    *)
        if ! check_decky_loader; then
            LAST_ERROR_MSG="请先安装 Decky Loader"
            print_error "$LAST_ERROR_MSG"
            return 1
        fi
        check_plugin "$key" && {
            print_warning "已安装"
            return 0
        }
        ;;
    esac

    # 检查是否有备用安装方式
    print_info "检查是否有备用安装方式 key: $key"
    local backup_url="${PLUGIN_BACKUP_URLS[$key]}"
    print_info "backup_url: $backup_url"
    if [[ -n "$backup_url" ]]; then
        # 有备用安装方式，询问用户选择
        local method_choice
        method_choice=$(choose_install_method "$key" "$desc")

        case $method_choice in
        "original")
            # 选择原始安装方式
            print_info "使用原始安装方式..."
            if eval "$cmd"; then
                print_success "$desc 完成"
                return 0
            else
                LAST_ERROR_MSG="原始安装方式执行失败"
                print_error "$LAST_ERROR_MSG"
                return 1
            fi
            ;;
        "backup")
            # 选择备用安装方式
            print_info "使用备用安装方式..."
            if install_decky_plugin_internal "$desc" "$backup_url"; then
                print_success "$desc 完成"
                return 0
            else
                LAST_ERROR_MSG="备用安装方式执行失败"
                print_error "$LAST_ERROR_MSG"
                return 1
            fi
            ;;
        *)
            # 用户取消或其他情况
            LAST_ERROR_MSG="安装方式选择异常"
            print_error "$LAST_ERROR_MSG"
            return 1
            ;;
        esac
    else
        # 没有备用安装方式，直接执行原始安装
        if eval "$cmd"; then
            print_success "$desc 完成"
            return 0
        else
            LAST_ERROR_MSG="安装命令执行失败"
            print_error "$LAST_ERROR_MSG"
            return 1
        fi
    fi
}

# 一键安装
install_all() {
    print_info "开始一键安装..."
    local failed=0

    # 首先设置密码（如果需要）
    if ! check_user_password; then
        install_item "setup_password" || ((failed++))
    fi

    # 安装其他组件
    for key in decky_loader tomoon power_control huesync decky_plumber power_button enable_ssh; do
        install_item "$key" || ((failed++))
    done

    if [[ $failed -eq 0 ]]; then
        print_success "🎉 全部安装完成！"
    else
        print_warning "⚠️ 完成，但有 $failed 项失败"
    fi
}

# =============================================================================
# 命令行界面
# =============================================================================

show_cli_menu() {
    clear
    echo -e "${BLUE}=== SteamOS 增强工具 v${VERSION} ===${NC}"
    echo
    echo -e "${YELLOW}当前状态：${NC}"
    get_status simple
    echo

    # 动态生成菜单项
    local ordered_keys=()
    mapfile -t ordered_keys < <(get_ordered_keys)

    # 根据PLUGINS数组生成菜单
    local i=1
    for key in "${ordered_keys[@]}"; do
        local desc="${PLUGINS[$key]}"
        if [[ -n "$desc" ]]; then
            # 提取描述部分（跳过序号）
            desc="${desc#*||}"    # 去掉序号部分
            desc="${desc%%||*}"   # 提取描述部分
            printf "%2d) %s\n" "$i" "$desc"
            ((i++))
        fi
    done

    echo " a) 🚀 一键安装全部"
    echo " 0) 📊 检查详细状态"
    echo " q) 🚪 退出"
    echo
}

run_cli() {
    while true; do
        show_cli_menu
        read -r -p "请选择: " choice </dev/tty
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
            # 动态处理数字选项
            local ordered_keys=()
            mapfile -t ordered_keys < <(get_ordered_keys)
            if [[ $choice =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#ordered_keys[@]} ]]; then
                local index=$((choice - 1))
                local key="${ordered_keys[$index]}"
                install_item "$key"
            else
                print_error "无效选项"
            fi
            ;;
        esac

        echo
        read -r -p "按回车继续..." </dev/tty
    done
}

# =============================================================================
# 图形界面
# =============================================================================

show_gui_menu() {
    # 简化但直观的状态显示
    local password_status ssh_status decky_status
    check_user_password && password_status="已设置" || password_status="未设置"
    check_ssh_service && ssh_status="已启用" || ssh_status="未启用"
    check_decky_loader && decky_status="已安装" || decky_status="未安装"

    # 动态生成菜单项
    local menu_items=()

    # 动态生成菜单项
    local ordered_keys=()
    mapfile -t ordered_keys < <(get_ordered_keys)

    # 根据PLUGINS数组生成菜单项
    for key in "${ordered_keys[@]}"; do
        local desc="${PLUGINS[$key]}"
        if [[ -n "$desc" ]]; then
            # 提取描述部分（跳过序号）
            desc="${desc#*||}"    # 去掉序号部分
            desc="${desc%%||*}"   # 提取描述部分
            menu_items+=("$key" "$desc")  # desc已包含图标
        fi
    done

    # 添加固定的功能项
    menu_items+=("install_all" "🚀 一键安装全部")
    menu_items+=("check_status" "📊 检查详细状态")
    menu_items+=("exit" "🚪 退出")

    zenity --list \
        --title="SteamOS 增强工具 v${VERSION}" \
        --text="🔐 密码: $password_status | 🌐 SSH: $ssh_status | 📦 Decky: $decky_status" \
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
            if zenity --question --text="确定要一键安装全部吗？\n\n这将包括：\n• 设置密码（如需要）\n• 启用SSH服务\n• 安装所有Decky插件\n• 配置电源按钮"; then
                install_all
                zenity --info --text="批量安装完成，详情请查看终端"
            fi
            ;;
        check_status)
            local status
            status=$(get_status detailed)
            zenity --info --title="详细状态" --text="$status" --width=500
            ;;
        exit)
            exit 0
            ;;
        *)
            # 动态处理PLUGINS数组中的所有项目
            if [[ -n "${PLUGINS[$choice]}" ]]; then
                # 直接调用install_item，让它自己处理安装方式选择
                if install_item "$choice"; then
                    zenity --info --text="✅ 操作完成"
                else
                    # 显示具体的错误信息
                    local desc="${PLUGINS[$choice]}"
                    desc="${desc#*||}"    # 去掉序号部分
                    desc="${desc%%||*}"   # 提取描述部分
                    local error_text="❌ $desc 失败"
                    if [[ -n "$LAST_ERROR_MSG" ]]; then
                        error_text="$error_text\n\n错误原因：$LAST_ERROR_MSG"
                    fi
                    error_text="$error_text\n\n详细信息请查看终端输出"
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
    echo "=== SteamOS 增强工具 v${VERSION} 启动 $(date) ===" >"$LOG_FILE"

    detect_ui_mode
    print_info "运行模式: $UI_MODE"

    check_system

    if [[ "$UI_MODE" == "gui" ]]; then
        run_gui
    else
        run_cli
    fi
}

# 执行主程序
[[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ -z "${BASH_SOURCE[0]}" ]] && main "$@"
