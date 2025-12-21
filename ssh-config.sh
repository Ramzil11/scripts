#!/bin/bash

set -e

SSH_CONFIG="/etc/ssh/sshd_config"

echo "==> Проверка прав..."
if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт от root"
  exit 1
fi

# Проверка параметра
if [[ -z "$1" ]]; then
  echo "Использование: $0 <SSH_PORT>"
  exit 1
fi

SSH_PORT="$1"

# Проверка что порт — число
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
  echo "Ошибка: порт должен быть числом от 1 до 65535"
  exit 1
fi

echo "==> Используется SSH порт: $SSH_PORT"

echo "==> Резервная копия sshd_config"
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%F-%H%M%S)"

echo "==> Настройка SSH..."

set_ssh_option () {
  local key="$1"
  local value="$2"

  if grep -qE "^[#]*\s*${key}\s+" "$SSH_CONFIG"; then
    sed -i "s|^[#]*\s*${key}\s\+.*|${key} ${value}|" "$SSH_CONFIG"
  else
    echo "${key} ${value}" >> "$SSH_CONFIG"
  fi
}

set_ssh_option "Port" "$SSH_PORT"
set_ssh_option "PermitRootLogin" "no"
set_ssh_option "ClientAliveInterval" "300"
set_ssh_option "ClientAliveCountMax" "1"
set_ssh_option "MaxAuthTries" "2"
set_ssh_option "AuthorizedKeysFile" ".ssh/authorized_keys"

echo "==> Перезапуск SSH сервиса..."
systemctl restart ssh || systemctl restart sshd

echo "==> Настройка UFW..."

ufw --force reset
ufw default allow outgoing
ufw default deny incoming
ufw allow "$SSH_PORT"/tcp
ufw --force enable

echo "==> Готово!"
echo "SSH порт: $SSH_PORT"
echo "Firewall активирован"
