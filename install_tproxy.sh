#!/bin/bash

set -e

# Cores para UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

GITHUB_USER="TelksBr"
GITHUB_REPO="TproxyBin"
MENU_ALIAS="tproxy-menu"
INSTALL_PATH="/usr/local/bin"

# --- Argumentos ---
FORCE=0
for arg in "$@"; do
    case $arg in
        -f|--force)
            FORCE=1
            ;;
    esac
done

# Banner
clear
echo -e "${CYAN}"
echo "========================================="
echo "      TProxy - Instalador Automático     "
echo "========================================="
echo -e "${NC}"

# Checagem de dependências
for dep in curl sudo; do
    if ! command -v $dep &>/dev/null; then
        echo -e "${RED}Erro: dependência '$dep' não encontrada!${NC}"
        exit 1
    fi
done

if [ ! -w "$INSTALL_PATH" ]; then
    echo -e "${YELLOW}Permissão de root será solicitada para instalar em $INSTALL_PATH${NC}"
fi

# --- Checagem de instalação prévia ---
ALREADY=0
if [ -f "$INSTALL_PATH/tproxy" ] || [ -f "$INSTALL_PATH/$MENU_ALIAS" ]; then
    ALREADY=1
    if [ $FORCE -eq 0 ]; then
        echo -e "${YELLOW}Já existe uma instalação detectada em $INSTALL_PATH.${NC}"
        echo -e "${YELLOW}Use --force ou -f para atualizar/reinstalar, ou pressione Ctrl+C para cancelar.${NC}"
        read -p "Deseja continuar e sobrescrever? (s/N): " resp
        case "$resp" in
            s|S|y|Y)
                echo -e "${BLUE}Prosseguindo com update/reinstalação...${NC}" ;;
            *)
                echo -e "${RED}Instalação abortada.${NC}"; exit 1 ;;
        esac
    else
        echo -e "${BLUE}Update/reinstalação forçada ativada (--force).${NC}"
    fi
    # --- Systemd legado ---
    if systemctl list-unit-files | grep -q '^tproxy.service'; then
        echo -e "${YELLOW}Detectado serviço systemd legado: tproxy.service${NC}"
        echo -e "${YELLOW}Parando e removendo serviço antigo...${NC}"
        sudo systemctl stop tproxy.service 2>/dev/null || true
        sudo systemctl disable tproxy.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/tproxy.service
        sudo systemctl daemon-reload
        echo -e "${GREEN}Serviço systemd legado removido.${NC}"
    fi
fi

# Detecta arquitetura
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        BIN_NAME="tproxy-linux-amd64" ;;
    aarch64|arm64)
        BIN_NAME="tproxy-linux-arm64" ;;
    armv7l|armv6l|arm)
        BIN_NAME="tproxy-linux-arm" ;;
    i386|i686)
        BIN_NAME="tproxy-linux-386" ;;
    *)
        echo -e "${RED}Arquitetura $ARCH não suportada!${NC}" ; exit 1 ;;
esac

TMP_DIR="/tmp/tproxy_install_$$"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Download
BIN_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/refs/heads/main/$BIN_NAME"
echo -e "${BLUE}Baixando binário: $BIN_NAME${NC}"
curl -# -L -o "$BIN_NAME" "$BIN_URL"

if [ ! -f "$BIN_NAME" ] || [ ! -s "$BIN_NAME" ]; then
    echo -e "${RED}Download do binário falhou!${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

chmod +x "$BIN_NAME"

# Instalação
echo -e "${YELLOW}Instalando em $INSTALL_PATH...${NC}"
sudo cp "$BIN_NAME" $INSTALL_PATH/tproxy
sudo chmod +x $INSTALL_PATH/tproxy

# Cria comando global para o menu
cat <<EOF | sudo tee $INSTALL_PATH/$MENU_ALIAS > /dev/null
#!/bin/bash
$INSTALL_PATH/tproxy menu "\$@"
EOF
sudo chmod +x $INSTALL_PATH/$MENU_ALIAS

# --- Recarrega systemd se necessário ---
if [ $ALREADY -eq 1 ]; then
    sudo systemctl daemon-reload
fi

cd ~
rm -rf "$TMP_DIR"

# Mensagem final
clear
echo -e "${GREEN}========================================="
echo " TProxy instalado com sucesso! "
echo -e "========================================="
echo -e "${NC}"
echo -e "Use ${CYAN}tproxy${NC} para rodar o proxy."
echo -e "Use ${CYAN}tproxy-menu${NC} para acessar o menu de gerenciamento."
echo -e "${YELLOW}Dica:${NC} Rode 'tproxy-menu' para configurar e gerenciar via systemd."