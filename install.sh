#!/bin/bash
# =============================================================
# Интерактивная настройка Unattended Upgrades
# Совместим с: Ubuntu 20.04 / 22.04 / 24.04
# Принцип: только точечные изменения конфига, не перезапись файлов
# =============================================================

set -e

# --- Цвета ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✘]${NC} $1"; exit 1; }
info()    { echo -e "${CYAN}[i]${NC} $1"; }
section() { echo -e "\n${BOLD}══════════════════════════════════════${NC}"; echo -e "${BOLD}  $1${NC}"; echo -e "${BOLD}══════════════════════════════════════${NC}"; }

# --- Проверка root ---
if [[ $EUID -ne 0 ]]; then
    error "Запусти скрипт с правами root: sudo bash $0"
fi

# =============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ ТОЧЕЧНОГО РЕДАКТИРОВАНИЯ КОНФИГА
# =============================================================

CONFIG="/etc/apt/apt.conf.d/50unattended-upgrades"
PERIODIC="/etc/apt/apt.conf.d/20auto-upgrades"

# Раскомментировать строку с ключом и установить значение
# Работает как с закомментированными строками, так и с активными
set_option() {
    local key="$1"
    local value="$2"
    local file="${3:-$CONFIG}"

    if grep -qE "^\s*//.+${key}" "$file"; then
        # Строка закомментирована — раскомментировать и установить значение
        sed -i "s|^\(\s*\)//\(\s*.*${key}.*\)\"[^\"]*\"\(.*\)|\1\2\"${value}\"\3|" "$file"
        log "Включено: ${key} = \"${value}\""
    elif grep -qE "^\s*[^/].*${key}" "$file"; then
        # Строка активна — просто обновить значение
        sed -i "s|\(.*${key}.*\)\"[^\"]*\"|\1\"${value}\"|" "$file"
        log "Обновлено: ${key} = \"${value}\""
    else
        warn "Параметр '${key}' не найден в $file — пропуск"
    fi
}

# Закомментировать строку содержащую паттерн
comment_option() {
    local key="$1"
    local file="${2:-$CONFIG}"

    if grep -qE "^\s*[^/].*${key}" "$file"; then
        sed -i "s|^\(\s*\)\([^/].*${key}.*\)|\1// \2|" "$file"
        log "Отключено: ${key}"
    fi
}

# Раскомментировать строку внутри блока (например Allowed-Origins)
enable_in_block() {
    local pattern="$1"
    local file="${2:-$CONFIG}"
    local escaped
    escaped=$(echo "$pattern" | sed 's/[.*+?^${}()|[\]\\]/\\&/g')

    if grep -qE "^\s*//.*${escaped}" "$file"; then
        sed -i "s|^\(\s*\)//\(\s*.*${escaped}.*\)|\1\2|" "$file"
        log "Активировано в блоке: $pattern"
    elif grep -qE "^\s*[^/].*${escaped}" "$file"; then
        info "Уже активно: $pattern"
    else
        warn "Строка '$pattern' не найдена в конфиге"
    fi
}

# Установить значение в 20auto-upgrades
set_periodic() {
    local key="$1"
    local value="$2"
    if grep -q "$key" "$PERIODIC"; then
        sed -i "s|\(.*${key}.*\)\"[^\"]*\"|\1\"${value}\"|" "$PERIODIC"
        log "Periodic: ${key} = \"${value}\""
    else
        echo "APT::${key} \"${value}\";" >> "$PERIODIC"
        log "Periodic добавлено: ${key} = \"${value}\""
    fi
}

# Интерактивный вопрос да/нет
ask() {
    local question="$1"
    local hint="${2:-[y/N]}"
    echo -e "\n${BOLD}${question}${NC}"
    read -rp "  Ваш выбор $hint: " answer
    case "$answer" in
        [yYдД]*) return 0 ;;
        *) return 1 ;;
    esac
}

# Запрос значения с дефолтом
ask_value() {
    local question="$1"
    local default="$2"
    echo -e "\n${BOLD}${question}${NC}"
    read -rp "  Введите значение [по умолчанию: ${default}]: " val
    echo "${val:-$default}"
}

# =============================================================
# НАЧАЛО РАБОТЫ
# =============================================================

section "Установка пакетов"

info "Проверяю наличие unattended-upgrades..."
if dpkg -l | grep -q "^ii.*unattended-upgrades"; then
    log "Пакет уже установлен"
else
    apt-get update -qq
    apt-get install -y unattended-upgrades apt-listchanges > /dev/null
    log "Пакеты установлены"
fi

# Если конфига ещё нет — создать стандартный через dpkg
if [[ ! -f "$CONFIG" ]]; then
    warn "Конфиг не найден — создаю стандартный через dpkg..."
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades > /dev/null 2>&1
    log "Стандартный конфиг создан"
else
    log "Конфиг уже существует — буду точечно редактировать существующие строки"
fi

# Если periodic-конфига нет — создать минимальный
if [[ ! -f "$PERIODIC" ]]; then
    cat > "$PERIODIC" << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    log "Создан $PERIODIC"
fi

# =============================================================
# БЛОК 1: ИСТОЧНИКИ ОБНОВЛЕНИЙ
# =============================================================

section "1. Источники обновлений"

info "По умолчанию включены только security-обновления."
info "Это самый безопасный вариант — только критические патчи безопасности."
info "Обычные обновления (updates) включают новые версии пакетов — выгодно,"
info "но иногда меняют поведение ПО. Backports — ещё менее стабильны."

if ask "Включить также обычные обновления пакетов (не только security)?" "[y/N]"; then
    enable_in_block "\${distro_codename}-updates"
    warn "Рекомендуется только если есть мониторинг сервера."
fi

if ask "Включить backports (более новые версии пакетов)?" "[y/N]"; then
    enable_in_block "\${distro_codename}-backports"
    warn "Backports менее стабильны. Не рекомендуется на критичных продакшн-серверах."
fi

# =============================================================
# БЛОК 2: РАСПИСАНИЕ
# =============================================================

section "2. Расписание обновлений"

info "Текущая настройка: обновления каждый день (~6 утра, с рандомной задержкой до 60 мин)."
info "Значение — интервал в днях: 1 = каждый день, 7 = раз в неделю, 0 = отключено."

if ask "Изменить частоту запуска обновлений (сейчас: каждый день)?" "[y/N]"; then
    interval=$(ask_value "Раз в сколько дней запускать обновления?" "1")
    set_periodic "Periodic::Unattended-Upgrade" "$interval"
    set_periodic "Periodic::Update-Package-Lists" "$interval"
fi

if ask "Изменить интервал автоочистки кеша apt (сейчас: каждые 7 дней)?" "[y/N]"; then
    clean=$(ask_value "Очищать кеш раз в сколько дней?" "7")
    set_periodic "Periodic::AutocleanInterval" "$clean"
fi

# =============================================================
# БЛОК 3: ПЕРЕЗАГРУЗКА
# =============================================================

section "3. Автоматическая перезагрузка"

info "Обновления ядра и glibc вступают в силу только после перезагрузки."
info "По умолчанию перезагрузка ОТКЛЮЧЕНА — сервер сам не перезагружается."
warn "На продакшн-сервере включай только если есть окно обслуживания!"

if ask "Включить автоматическую перезагрузку после обновлений?" "[y/N]"; then
    set_option "Automatic-Reboot" "true"

    reboot_time=$(ask_value "В какое время перезагружать сервер? (формат HH:MM)" "03:00")
    set_option "Automatic-Reboot-Time" "$reboot_time"
    log "Время перезагрузки: $reboot_time"

    info "Если в системе есть активные SSH-сессии — перезагружаться?"
    if ask "Перезагружаться даже если пользователи залогинены?" "[y/N]"; then
        set_option "Automatic-Reboot-WithUsers" "true"
        warn "Активные сессии будут прерваны!"
    else
        set_option "Automatic-Reboot-WithUsers" "false"
        info "Перезагрузка будет отложена при наличии активных сессий."
    fi
else
    comment_option "Automatic-Reboot-Time"
    log "Автоперезагрузка отключена"
fi

# =============================================================
# БЛОК 4: УВЕДОМЛЕНИЯ ПО EMAIL
# =============================================================

section "4. Email-уведомления"

info "Можно получать письма когда происходят обновления или ошибки."
info "Требует настроенного mail-агента на сервере (postfix, msmtp, ssmtp и т.п.)."
info "Без mail-агента письма не уйдут, но ошибок в работе unattended-upgrades не будет."

if ask "Настроить email-уведомления?" "[y/N]"; then
    email=$(ask_value "Email-адрес для уведомлений" "admin@example.com")
    set_option "Mail" "$email"

    echo -e "\n${BOLD}Когда отправлять письма?${NC}"
    echo "  1) only-on-error  — только при ошибках (рекомендуется, тихий режим)"
    echo "  2) on-change      — при любом изменении пакетов"
    echo "  3) always         — всегда, даже если ничего не изменилось"
    read -rp "  Выбери вариант [1/2/3, по умолчанию 1]: " mail_mode
    case "$mail_mode" in
        2) set_option "MailReport" "on-change" ;;
        3) set_option "MailReport" "always" ;;
        *) set_option "MailReport" "only-on-error" ;;
    esac
else
    comment_option "^Unattended-Upgrade::Mail "
fi

# =============================================================
# БЛОК 5: ОЧИСТКА СИСТЕМЫ
# =============================================================

section "5. Очистка после обновлений"

info "После обновлений могут накапливаться неиспользуемые пакеты и старые ядра."
info "Рекомендуется включить для поддержания чистоты системы."

if ask "Автоматически удалять неиспользуемые зависимости (аналог: apt autoremove)?" "[y/N]"; then
    set_option "Remove-Unused-Dependencies" "true"
    info "Удаляются только пакеты помеченные как 'auto' и не нужные никаким другим пакетам."
else
    set_option "Remove-Unused-Dependencies" "false"
fi

if ask "Автоматически удалять старые ядра Linux после обновления?" "[y/N]"; then
    set_option "Remove-Unused-Kernel-Packages" "true"
    info "Текущее активное ядро и одно запасное всегда сохраняются — удаление безопасно."
else
    set_option "Remove-Unused-Kernel-Packages" "false"
fi

# =============================================================
# БЛОК 6: НАДЁЖНОСТЬ УСТАНОВКИ
# =============================================================

section "6. Надёжность установки"

info "MinimalSteps — устанавливать обновления по одному пакету за раз."
info "Это медленнее, но если процесс будет прерван — меньше риск сломать систему."

if ask "Включить MinimalSteps (безопаснее при прерывании, медленнее)?" "[y/N]"; then
    set_option "MinimalSteps" "true"
fi

info "AutoFixInterruptedDpkg — если предыдущая установка была прервана,"
info "запустить dpkg --force-confold --configure -a перед следующим обновлением."

if ask "Автоматически исправлять прерванные установки dpkg?" "[y/N]"; then
    set_option "AutoFixInterruptedDpkg" "true"
fi

# =============================================================
# БЛОК 7: ЛОГИРОВАНИЕ
# =============================================================

section "7. Логирование"

info "Логи хранятся в: /var/log/unattended-upgrades/"
info "  unattended-upgrades.log       — основной лог обновлений"
info "  unattended-upgrades-dpkg.log  — детальный лог dpkg"
info "  unattended-upgrades-shutdown.log — лог перезагрузок"

if ask "Изменить уровень подробности логов?" "[y/N]"; then
    echo -e "\n${BOLD}Уровень логирования:${NC}"
    echo "  0 — минимум (только ошибки)"
    echo "  1 — стандартный (рекомендуется)"
    echo "  2 — подробный (для отладки, много записей)"
    read -rp "  Выбери уровень [0/1/2, по умолчанию 1]: " verb
    case "$verb" in
        0|2) set_option "Verbose" "$verb" ;;
        *) set_option "Verbose" "1" ;;
    esac
fi

# =============================================================
# ФИНАЛ: ВКЛЮЧЕНИЕ ТАЙМЕРОВ И ПРОВЕРКА
# =============================================================

section "Активация таймеров"

log "Включаю и перезапускаю systemd таймеры..."
systemctl enable apt-daily.timer apt-daily-upgrade.timer > /dev/null 2>&1
systemctl restart apt-daily.timer apt-daily-upgrade.timer
log "Таймеры активны"

# Показать время следующего запуска
echo ""
info "Следующий запуск обновлений:"
systemctl list-timers apt-daily-upgrade.timer --no-pager 2>/dev/null | grep -v "^$" | tail -2 || true

echo ""
if ask "Запустить тестовый прогон --dry-run прямо сейчас?" "[Y/n]"; then
    echo ""
    info "Dry-run: изменения НЕ применяются, только проверка..."
    echo "--------------------------------------------"
    unattended-upgrades --dry-run --debug 2>&1 \
        | grep -E "(Checking|Packages|security|error|ERROR|fetch|Allowed|blacklist)" \
        | head -30 || true
    echo "--------------------------------------------"
    log "Dry-run завершён"
fi

# =============================================================
# ИТОГ
# =============================================================

section "Настройка завершена!"

echo ""
echo -e "  ${BOLD}Конфигурационные файлы:${NC}"
echo -e "  • $CONFIG"
echo -e "  • $PERIODIC"
echo ""
echo -e "  ${BOLD}Полезные команды:${NC}"
echo -e "  • Посмотреть конфиг:       cat $CONFIG"
echo -e "  • Статус таймера:          systemctl status apt-daily-upgrade.timer"
echo -e "  • Следующий запуск:        systemctl list-timers apt-daily-upgrade.timer"
echo -e "  • Логи обновлений:         tail -f /var/log/unattended-upgrades/unattended-upgrades.log"
echo -e "  • Тест вручную:            unattended-upgrades --dry-run --debug"
echo -e "  • Запустить сейчас:        unattended-upgrades -v"
echo ""
