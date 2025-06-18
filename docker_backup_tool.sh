#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
BACKUP_DIR_ROOT="/root/backups_docker"
BACKUP_DIR_PUBLIC="/home/guquintana/backups_docker"
MOUNT_DIR="/home/guquintana/docker_volumes_mounted"
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

    echo -e "${YELLOW}🔐 Ajustando permisos...${NC}"
    chown -R guquintana:guquintana "$FULL_BACKUP_PATH"

    echo -e "${YELLOW}🚚 Moviendo backup a directorio accesible desde Windows...${NC}"
    cp -r "$FULL_BACKUP_PATH" "$BACKUP_DIR_PUBLIC"
    chown -R guquintana:guquintana "$BACKUP_DIR_PUBLIC"
    chmod -R u+rwX,g+rwX,o+rX "$BACKUP_DIR_PUBLIC"

    echo -e "${GREEN}✅ Backup completado en: $FULL_BACKUP_PATH${NC}"
    echo -e "${BLUE}📁 Visible desde Windows: $BACKUP_DIR_PUBLIC/$BACKUP_NAME${NC}"
}

function restore() {
    echo -e "${CYAN}📂 Backups disponibles en: $BACKUP_DIR_PUBLIC${NC}"
    mapfile -t backups < <(ls -1 "$BACKUP_DIR_PUBLIC")

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay backups disponibles.${NC}"
        return
    fi

    echo ""
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

function montar_backup_dir() {
    echo -e "${CYAN}🔗 Montando backup en /home/guquintana para exploración y edición...${NC}"
    chown -R guquintana:guquintana "$BACKUP_DIR_PUBLIC"
    chmod -R u+rwX,g+rwX,o+rX "$BACKUP_DIR_PUBLIC"
    echo -e "${GREEN}✅ Permisos aplicados. Puedes explorar /home/guquintana/backups_docker en Ubuntu o desde Windows. ${NC}"
}

function montar_volumenes() {
    echo -e "${CYAN}🔍 Montando todos los volúmenes Docker en $MOUNT_DIR...${NC}"
    mkdir -p "$MOUNT_DIR"
    for volume in $(docker volume ls -q); do
        dest="$MOUNT_DIR/$volume"
        mkdir -p "$dest"
        docker run --rm -v "$volume":/source -v "$dest":/target alpine \
            sh -c "cd /source && cp -a . /target"
    done
    chown -R guquintana:guquintana "$MOUNT_DIR"
    chmod -R u+rwX,g+rwX,o+rX "$MOUNT_DIR"
    echo -e "${GREEN}✅ Volúmenes montados en: $MOUNT_DIR${NC}"
}

function menu() {
    echo -e "\n${BLUE}==== DOCKER BACKUP TOOL ====\n${NC}"
    echo -e "${YELLOW}1)${NC} Hacer backup completo"
    echo -e "${YELLOW}2)${NC} Restaurar backup"
    echo -e "${YELLOW}3)${NC} Salir"
    echo -e "${YELLOW}4)${NC} Eliminar este script y su carpeta"
    echo -e "${YELLOW}5)${NC} Montar carpeta de backups con permisos de usuario"
    echo -e "${YELLOW}6)${NC} Montar todos los volúmenes Docker como carpetas"
    echo -e "${BLUE}============================\n${NC}"
    echo -ne "${CYAN}Selecciona una opción: ${NC}"
    read opcion
    case $opcion in
        1) backup ;;
        2) restore ;;
        3) echo -e "${GREEN}👋 Saliendo...${NC}"; exit 0 ;;
        4)
            SCRIPT_PATH="$(realpath "$0")"
            SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
            echo -e "${RED}🗑️ Eliminando $SCRIPT_DIR ...${NC}"
            cd ~ || exit
            rm -rf "$SCRIPT_DIR"
            echo -e "${GREEN}✅ Eliminado.${NC}"
            exit 0
            ;;
        5) montar_backup_dir ;;
        6) montar_volumenes ;;
        *) echo -e "${RED}❌ Opción no válida${NC}"; menu ;;
    esac
}

menu
