#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função para exibir mensagens
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Função principal
configurar_rede() {
    info "Configurando interface de rede via Netplan"
    
    # Desativar NetworkManager se estiver ativo
    if systemctl is-active NetworkManager > /dev/null 2>&1; then
        warning "NetworkManager está ativo. Desativando para evitar conflitos..."
        sudo systemctl stop NetworkManager
        sudo systemctl disable NetworkManager
    fi
    
    # Listar interfaces
    info "Interfaces de rede disponíveis:"
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo | while read iface; do
        mac=$(ip link show $iface | awk '/link\/ether/ {print $2}')
        echo "  $iface: $mac"
    done
    
    # Coletar informações
    echo
    read -p "Nome da interface (ex: ens160): " INTERFACE
    read -p "Endereço IPv4 (ex: 10.22.0.24): " IP
    read -p "Máscara (ex: 16 para /16): " MASCARA
    read -p "Gateway (ex: 10.22.0.1): " GATEWAY
    read -p "DNS primário (ex: 10.7.0.230): " DNS1
    read -p "DNS secundário (ex: 10.7.0.231): " DNS2
    
    # Validar entrada
    if [[ -z "$INTERFACE" || -z "$IP" || -z "$MASCARA" || -z "$GATEWAY" ]]; then
        error "Todos os campos são obrigatórios!"
        exit 1
    fi
    
    # Formatar IP com máscara
    IP_COMPLETO="${IP}/${MASCARA}"
    
    info "Configurando $INTERFACE com:"
    echo "  IP: $IP_COMPLETO"
    echo "  Gateway: $GATEWAY"
    echo "  DNS: $DNS1, $DNS2"
    
    # Backup do arquivo atual
    if [ -f "/etc/netplan/00-installer-config.yaml" ]; then
        BACKUP="/etc/netplan/00-installer-config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        sudo cp /etc/netplan/00-installer-config.yaml "$BACKUP"
        info "Backup criado: $BACKUP"
    fi
    
    # Criar arquivo Netplan com permissões seguras
    TEMP_FILE=$(mktemp)
    cat > "$TEMP_FILE" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      dhcp6: no
      addresses:
        - $IP_COMPLETO
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
          - $DNS2
EOF
    
    # Mover arquivo com permissões corretas
    sudo cp "$TEMP_FILE" /etc/netplan/00-installer-config.yaml
    sudo chmod 600 /etc/netplan/00-installer-config.yaml
    sudo chown root:root /etc/netplan/00-installer-config.yaml
    
    rm -f "$TEMP_FILE"
    
    success "Arquivo de configuração criado com permissões seguras"
    
    # Testar configuração
    info "Testando configuração (tempo limite: 30 segundos)..."
    echo "Pressione ENTER para aceitar ou CTRL+C para cancelar"
    
    # Usar netplan try com timeout
    if sudo timeout 30 netplan try; then
        success "Configuração aplicada com sucesso!"
    else
        warning "Timeout atingido ou configuração cancelada"
        info "Restaurando backup anterior..."
        if [ -f "$BACKUP" ]; then
            sudo cp "$BACKUP" /etc/netplan/00-installer-config.yaml
            sudo netplan apply
        fi
        exit 1
    fi
    
    # Mostrar configuração atual
    echo
    info "=== CONFIGURAÇÃO ATUAL ==="
    echo "Interface: $INTERFACE"
    ip addr show $INTERFACE | grep "inet "
    echo
    echo "Rota padrão:"
    ip route show default
    echo
    echo "DNS configurado:"
    cat /etc/resolv.conf
    
    # Testar conectividade
    echo
    info "Testando conectividade..."
    
    if ping -c 2 -W 1 $GATEWAY > /dev/null 2>&1; then
        success "Gateway $GATEWAY está respondendo"
    else
        warning "Gateway $GATEWAY não respondendo"
    fi
    
    if ping -c 2 -W 1 $DNS1 > /dev/null 2>&1; then
        success "DNS primário $DNS1 está respondendo"
    else
        warning "DNS primário $DNS1 não respondendo (pode ser normal)"
    fi
    
    success "Configuração concluída!"
    info "Para editar manualmente: sudo nano /etc/netplan/00-installer-config.yaml"
    info "Para reaplicar: sudo netplan apply"
}

# Menu principal
echo "========================================"
echo "   CONFIGURADOR DE REDE - Ubuntu 24.04  "
echo "========================================"
echo
echo "1. Configurar interface de rede"
echo "2. Ver configuração atual"
echo "3. Testar conectividade"
echo "4. Sair"
echo

read -p "Escolha uma opção (1-4): " OPCAO

case $OPCAO in
    1)
        configurar_rede
        ;;
    2)
        echo "=== Configuração atual ==="
        ip addr show
        echo
        echo "=== Rotas ==="
        ip route show
        echo
        echo "=== DNS ==="
        cat /etc/resolv.conf
        ;;
    3)
        read -p "Digite um IP para testar (ex: 10.22.0.1): " TEST_IP
        ping -c 4 $TEST_IP
        ;;
    4)
        exit 0
        ;;
    *)
        error "Opção inválida!"
        exit 1
        ;;
esac