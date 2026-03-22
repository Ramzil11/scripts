#!/bin/bash
set -e

echo "==> Проверка прав..."
if [[ $EUID -ne 0 ]]; then
  echo "Запусти скрипт от root"
  exit 1
fi

# Определяем реального пользователя (даже если запущено через sudo)
REAL_USER="${SUDO_USER:-$USER}"

echo "==> Установка зависимостей..."
apt update
apt install -y ca-certificates curl

echo "==> Добавление GPG-ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "==> Добавление репозитория Docker..."
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "==> Установка Docker..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Запуск Docker..."
systemctl enable --now docker

echo "==> Добавление пользователя '$REAL_USER' в группу docker..."
groupadd -f docker
usermod -aG docker "$REAL_USER"

echo "==> Готово!"
echo "Docker версия: $(docker --version)"
echo "Compose версия: $(docker compose version)"
echo ""
echo "Пользователь '$REAL_USER' добавлен в группу docker."
echo "Чтобы изменения вступили в силу, выполни:"
echo "  newgrp docker"
echo "или перелогинься в систему."
