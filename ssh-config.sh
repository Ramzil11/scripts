#!/bin/bash
set -e

SSH_CONFIG="/etc/ssh/sshd_config"
PERMIT_ROOT_LOGIN="yes"

# Парсинг аргументов
SSH_PORT=""
for arg in "$@"; do
  case "$arg" in
    --no-root-login)
      PERMIT_ROOT_LOGIN="no"
      ;;
    *)
      if [[ -z "$SSH_PORT" ]]; then
        SSH_PORT="$arg"
      fi
      ;;
  esac
done

echo "==> Проверка прав..."
if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт от root"
  exit 1
fi

# Проверка параметра
if [[ -z "$SSH_PORT" ]]; then
  echo "Использование: $0 <SSH_PORT> [--no-root-login]"
  echo ""
  echo "  SSH_PORT          — порт для SSH (1-65535)"
  echo "  --no-root-login   — запретить вход под root (по умолчанию: разрешён)"
  exit 1
fi

# Проверка что порт — число
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
  echo "Ошибка: порт должен быть числом от 1 до 65535"
  exit 1
fi

echo "==> Используется SSH порт: $SSH_PORT"
echo "==> PermitRootLogin: $PERMIT_ROOT_LOGIN"

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
set_ssh_option "PermitRootLogin" "$PERMIT_ROOT_LOGIN"
set_ssh_option "PasswordAuthentication" "no"
set_ssh_option "ClientAliveInterval" "300"
set_ssh_option "ClientAliveCountMax" "1"
set_ssh_option "MaxAuthTries" "2"
set_ssh_option "AuthorizedKeysFile" ".ssh/authorized_keys"

sudo systemctl daemon-reload
sudo systemctl restart ssh.socket

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
echo "PermitRootLogin: $PERMIT_ROOT_LOGIN"
echo "Firewall активирован"
