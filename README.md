# unattended-upgrades-setup

Интерактивный bash-скрипт для настройки автоматических обновлений безопасности на Ubuntu Server.

---

## Описание

Скрипт настраивает `unattended-upgrades` — стандартный механизм Ubuntu для автоматической установки обновлений безопасности без участия администратора.

**Принцип работы:** скрипт не перезаписывает конфигурационные файлы целиком — только точечно изменяет нужные строки в существующих конфигах. Остальные настройки остаются нетронутыми.

**Настраиваемые параметры:**
- источники обновлений (security / updates / backports)
- расписание запуска
- автоматическая перезагрузка
- email-уведомления
- очистка неиспользуемых пакетов и старых ядер
- надёжность установки (MinimalSteps, AutoFix)
- уровень логирования

## Требования

- Ubuntu 20.04 / 22.04 / 24.04
- права root

## Установка и запуск

**Через curl (рекомендуется):**

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/NiTzelum/unattended-upgrades-setup/main/install.sh)
```

**Скачать и запустить:**

```bash
curl -fsSL https://raw.githubusercontent.com/NiTzelum/unattended-upgrades-setup/main/install.sh -o install.sh
sudo bash install.sh
```

**Через git clone:**

```bash
git clone https://github.com/NiTzelum/unattended-upgrades-setup.git
cd unattended-upgrades-setup
sudo bash install.sh
```

Скрипт проведёт через все параметры в интерактивном режиме с описанием каждой опции.

## Тестирование без применения изменений

```bash
sudo unattended-upgrades --dry-run --debug
```

## Файлы конфигурации

| Файл | Назначение |
|------|------------|
| `/etc/apt/apt.conf.d/50unattended-upgrades` | основные параметры: источники, перезагрузка, очистка |
| `/etc/apt/apt.conf.d/20auto-upgrades` | расписание запуска |

## Логи

```bash
# статус таймера и время следующего запуска
systemctl list-timers apt-daily-upgrade.timer

# лог обновлений
tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

---
---

# unattended-upgrades-setup

Interactive bash script for configuring automatic security updates on Ubuntu Server.

---

## Description

The script configures `unattended-upgrades` — Ubuntu's built-in mechanism for automatically installing security updates without administrator involvement.

**How it works:** the script does not overwrite configuration files entirely — it only modifies the relevant lines in existing configs. All other settings remain untouched.

**Configurable parameters:**
- update sources (security / updates / backports)
- update schedule
- automatic reboot
- email notifications
- cleanup of unused packages and old kernels
- installation reliability (MinimalSteps, AutoFix)
- log verbosity

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04
- root privileges

## Installation

**Via curl (recommended):**

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/NiTzelum/unattended-upgrades-setup/main/install.sh)
```

**Download and run:**

```bash
curl -fsSL https://raw.githubusercontent.com/NiTzelum/unattended-upgrades-setup/main/install.sh -o install.sh
sudo bash install.sh
```

**Via git clone:**

```bash
git clone https://github.com/NiTzelum/unattended-upgrades-setup.git
cd unattended-upgrades-setup
sudo bash install.sh
```

The script walks through all parameters interactively with a description of each option.

## Dry run (no changes applied)

```bash
sudo unattended-upgrades --dry-run --debug
```

## Configuration files

| File | Purpose |
|------|---------|
| `/etc/apt/apt.conf.d/50unattended-upgrades` | main settings: sources, reboot, cleanup |
| `/etc/apt/apt.conf.d/20auto-upgrades` | update schedule |

## Logs

```bash
# timer status and next run time
systemctl list-timers apt-daily-upgrade.timer

# update log
tail -f /var/log/unattended-upgrades/unattended-upgrades.log
```

## License

MIT
