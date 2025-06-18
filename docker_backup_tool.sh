#!/bin/bash

# Config file path
CONFIG_FILE="/home/$USER/.docker_backup_config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo -e "${CYAN}🛠 Configuración inicial${NC}"
    read -p "👤 Usuario Linux (ej. mrguillote): " DOCKER_USER
    read -p "📁 Ruta para guardar/restaurar backups (ej. /home/$DOCKER_USER/backups_docker): " BACKUP_DIR_PUBLIC
    read -p "🌐 Carpeta para montar volúmenes (ej. /home/$DOCKER_USER/www-docker): " MOUNT_DIR

    echo "DOCKER_USER=$DOCKER_USER" > "$CONFIG_FILE"
    echo "BACKUP_DIR_PUBLIC=$BACKUP_DIR_PUBLIC" >> "$CONFIG_FILE"
    echo "MOUNT_DIR=$MOUNT_DIR" >> "$CONFIG_FILE"
fi

# Constantes
BACKUP_DIR_ROOT="/root/backups_docker"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="backup_$DATE"
FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

mkdir -p "$BACKUP_DIR_ROOT"
mkdir -p "$BACKUP_DIR_PUBLIC"

function backup() {
    echo -e "${CYAN}📋 Guardando lista de imágenes...${NC}"
    docker image ls --format '{{.Repository}}:{{.Tag}}' > "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}📦 Exportando imágenes Docker...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/images"
    while IFS= read -r image; do
        docker save "$image" -o "$FULL_BACKUP_PATH/images/$(echo $image | tr '/:' '_').tar"
    done < "$FULL_BACKUP_PATH-images.txt"

    echo -e "${CYAN}💾 Exportando volúmenes...${NC}"
    mkdir -p "$FULL_BACKUP_PATH/volumes"
    for volume in $(docker volume ls -q); do
        docker run --rm -v "$volume":/volume -v "$FULL_BACKUP_PATH/volumes":/backup alpine \
            tar -czf "/backup/${volume}.tar.gz" -C /volume . > /dev/null 2>&1
    done

    echo -e "${CYAN}🧱 Guardando contenedores activos...${NC}"
    docker ps -a --format '{{.Names}}' > "$FULL_BACKUP_PATH-containers.txt"

    echo -e "${YELLOW}🚚 Moviendo backup a directorio accesible...${NC}"
    cp -r "$FULL_BACKUP_PATH" "$BACKUP_DIR_PUBLIC"

    echo -e "${GREEN}✅ Backup completado en: $FULL_BACKUP_PATH${NC}"
    echo -e "${BLUE}📁 Visible desde: $BACKUP_DIR_PUBLIC/$BACKUP_NAME${NC}"
}

function restore() {
    echo -e "${CYAN}📂 Backups disponibles en: $BACKUP_DIR_PUBLIC${NC}"
    mapfile -t backups < <(ls -1 "$BACKUP_DIR_PUBLIC")

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay backups disponibles.${NC}"
        return
    fi

    echo -e "${YELLOW}Seleccione el backup a restaurar:${NC}"
    for i in "${!backups[@]}"; do
        echo -e "${BLUE}$((i+1))) ${backups[$i]}${NC}"
    done

    echo -ne "${CYAN}📝 Ingrese el número del backup: ${NC}"
    read option

    index=$((option-1))
    if [[ $index -lt 0 || $index -ge ${#backups[@]} ]]; then
        echo -e "${RED}❌ Opción inválida.${NC}"
        return
    fi

    RESTORE_NAME="${backups[$index]}"
    RESTORE_SRC="$BACKUP_DIR_PUBLIC/$RESTORE_NAME"
    RESTORE_TMP="$BACKUP_DIR_ROOT/$RESTORE_NAME"

    echo -e "${YELLOW}📥 Copiando backup a $BACKUP_DIR_ROOT...${NC}"
    cp -r "$RESTORE_SRC" "$BACKUP_DIR_ROOT"

    echo -e "${CYAN}📦 Restaurando imágenes...${NC}"
    for tarfile in "$RESTORE_TMP/images/"*.tar; do
        docker load -i "$tarfile"
    done

    echo -e "${CYAN}💾 Restaurando volúmenes...${NC}"
    for volume_archive in "$RESTORE_TMP/volumes/"*.tar.gz; do
        volume_name=$(basename "$volume_archive" .tar.gz)
        docker volume create "$volume_name"
        docker run --rm -v "$volume_name":/volume -v "$RESTORE_TMP/volumes":/backup alpine \
            sh -c "cd /volume && tar -xzf /backup/$volume_name.tar.gz"
    done

    echo -e "${YELLOW}🧹 Limpiando archivos temporales...${NC}"
    rm -rf "$RESTORE_TMP"

    echo -e "${GREEN}✅ Restauración completada.${NC}"
}

function mount_volumes() {
    echo -e "${CYAN}📂 Montando todos los volúmenes en: $MOUNT_DIR ${NC}"
    mkdir -p "$MOUNT_DIR"
    for volume in $(docker volume ls -q); do
        TARGET="$MOUNT_DIR/$volume"
        echo "📦 $volume -> $TARGET"
        mkdir -p "$TARGET"
        docker run --rm -v "$volume":/volume -v "$TARGET":/copy alpine \
            sh -c "cp -a /volume/. /copy/ 2>/dev/null || true"
        chown -R "$DOCKER_USER":"$DOCKER_USER" "$TARGET"
    done
    echo -e "${GREEN}✅ Todos los volúmenes fueron montados en: $MOUNT_DIR${NC}"
    echo -e "💡 Accesible desde Windows: \\wsl.localhost\\Ubuntu\\${MOUNT_DIR#/home/}" 
}

function reset_config() {
    echo -e "${RED}⚠ Esto eliminará la configuración actual. ¿Continuar? (s/n)${NC}"
    read confirm
    if [[ "$confirm" == "s" ]]; then
        rm -f "$CONFIG_FILE"
        echo -e "${GREEN}✔ Configuración eliminada. Reinicie el script.${NC}"
        exit 0
    else
        echo -e "${YELLOW}🚫 Cancelado.${NC}"
    fi
}

function menu() {
    echo -e "\n${BLUE}==== DOCKER BACKUP TOOL ====${NC}"
    echo -e "${YELLOW}1)${NC} Hacer backup completo"
    echo -e "${YELLOW}2)${NC} Restaurar backup"
    echo -e "${YELLOW}3)${NC} Montar volúmenes en $MOUNT_DIR"
    echo -e "${YELLOW}4)${NC} Resetear configuración Solo si cargaste mal las variables/rutas"
    echo -e "${YELLOW}5)${NC} Salir"
    echo -e "${BLUE}============================${NC}"
    echo -ne "${CYAN}Selecciona una opción: ${NC}"
    read opcion
    case $opcion in
        1) backup ;;
        2) restore ;;
        3) mount_volumes ;;
        4) reset_config ;;
        5) echo -e "${GREEN}👋 Saliendo...${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción no válida${NC}"; menu ;;
    esac
}

menu
