#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para limpiar texto
function clean_path() {
    local input="$1"
    # Convierte "C:\\Users" en "/mnt/c/Users"
    echo "$input" | sed 's#\\\\#/#g' | sed 's#\\#/#g' | sed -E 's#^([A-Za-z]):#/mnt/\L\1#'
}

# Función para hacer el backup
function backup() {
    echo -ne "${CYAN}📁 ¿Dónde querés guardar el backup? (ej. /home/usuario/backups o D:\\Users\\tuusuario\\Downloads): ${NC}"
    read BACKUP_DIR_RAW
    BACKUP_DIR_PUBLIC=$(clean_path "$BACKUP_DIR_RAW")
    BACKUP_DIR_ROOT="/root/backups_docker"
    DATE=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="backup_$DATE"
    FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

    mkdir -p "$BACKUP_DIR_ROOT"
    mkdir -p "$BACKUP_DIR_PUBLIC"

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

# Función para restaurar backup
function restore() {
    echo -ne "${CYAN}📁 ¿Desde qué carpeta querés restaurar el backup?: ${NC}"
    read BACKUP_RESTORE_RAW
    BACKUP_RESTORE=$(clean_path "$BACKUP_RESTORE_RAW")

    echo -e "${CYAN}📂 Backups disponibles en: $BACKUP_RESTORE${NC}"
    mapfile -t backups < <(ls -1 "$BACKUP_RESTORE")

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
    RESTORE_SRC="$BACKUP_RESTORE/$RESTORE_NAME"
    RESTORE_TMP="/root/backups_docker/$RESTORE_NAME"

    echo -e "${YELLOW}📥 Copiando backup a /root...${NC}"
    cp -r "$RESTORE_SRC" "/root/backups_docker"

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

    echo -e "${YELLOW}🧹 Limpiando temporales...${NC}"
    rm -rf "$RESTORE_TMP"
    echo -e "${GREEN}✅ Restauración completada.${NC}"
}

# Función para montar volúmenes
function mount_volumes() {
    echo -ne "${CYAN}🌐 Ruta donde montar los volúmenes (ej. /home/tuusuario/www-docker): ${NC}"
    read MOUNT_RAW
    MOUNT_DIR=$(clean_path "$MOUNT_RAW")
    mkdir -p "$MOUNT_DIR"

    echo -e "${CYAN}🔍 Montando volúmenes Docker en: $MOUNT_DIR ${NC}"
    for volume in $(docker volume ls -q); do
        TARGET="$MOUNT_DIR/$volume"
        mkdir -p "$TARGET"
        docker run --rm -v "$volume":/volume -v "$TARGET":/copy alpine \
            sh -c "cp -a /volume/. /copy/ 2>/dev/null || true"
        chown -R $(whoami):$(whoami) "$TARGET"
    done

    echo -e "${GREEN}✅ Todos los volúmenes han sido montados en: $MOUNT_DIR${NC}"
}

# Menú
function menu() {
    echo -e "\n${BLUE}==== DOCKER BACKUP TOOL ====${NC}"
    echo -e "${YELLOW}1)${NC} Hacer backup completo"
    echo -e "${YELLOW}2)${NC} Restaurar backup"
    echo -e "${YELLOW}3)${NC} Montar volúmenes"
    echo -e "${YELLOW}4)${NC} Salir"
    echo -e "${BLUE}============================${NC}"
    echo -ne "${CYAN}Selecciona una opción: ${NC}"
    read opcion
    case $opcion in
        1) backup ;;
        2) restore ;;
        3) mount_volumes ;;
        4) echo -e "${GREEN}👋 Saliendo...${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción no válida${NC}"; menu ;;
    esac
}

menu
