#!/bin/bash

echo "=== CORRIGINDO CONFIGURAÇÃO DUPLICADA ==="

# Parar NetworkManager se estiver ativo
sudo systemctl stop NetworkManager 2>/dev/null

# Fazer backup
BACKUP_DIR="/etc/netplan/backup_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
sudo cp /etc/netplan/*.yaml "$BACKUP_DIR/" 2>/dev/null
echo "Backup criado em: $BACKUP_DIR"

# Remover arquivos problemáticos
echo "Limpando configurações antigas..."
sudo rm -f /etc/netplan/*.yaml

# Criar nova configuração limpa
echo "Criando nova configuração..."

read -p "Interface (padrão: ens160): " INTERFACE
INTERFACE=${INTERFACE:-ens160}

read -p "IP com máscara (padrão: 10.22.0.24/16): " IP
IP=${IP:-10.22.0.24/16}

read -p "Gateway (padrão: 10.22.0.1): " GATEWAY
GATEWAY=${GATEWAY:-10.22.0.1}

read -p "DNS1 (padrão: 10.7.0.230): " DNS1
DNS1=${DNS1:-10.7.0.230}

read -p "DNS2 (padrão: 10.7.0.231): " DNS2
DNS2=${DNS2:-10.7.0.231}

sudo tee /etc/netplan/00-netcfg.yaml << EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
EOF

# Ajustar permissões
sudo chmod 600 /etc/netplan/00-netcfg.yaml

# Testar e aplicar
echo "Testando configuração..."
if sudo netplan generate; then
    echo "Configuração válida. Aplicando..."
    sudo netplan apply
    echo "=== VERIFICAÇÃO ==="
    ip addr show $INTERFACE
    echo ""
    ip route show
else
    echo "ERRO: Configuração inválida. Verifique o arquivo."
    exit 1
fi

echo "=== CONCLUÍDO ==="