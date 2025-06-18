#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para convertir rutas de Windows a WSL
function fix_windows_path() {
    local input="$1"
    input="${input//\\//}"
    if [[ "$input" =~ ^[A-Za-z]: ]]; then
        drive="${input:0:1}"
        rest="${input:2}"
        rest="${rest#/}"
        input="/mnt/${drive,,}/$rest"
    fi
    echo "$input"
}

# Confirmar ruta
function confirm_path() {
    local path="$1"
    echo -e "${YELLOW}📂 ¿Usamos esta ruta? ${BLUE}\"$path\"${YELLOW} [s/N]: ${NC}"
    read -r confirm
    [[ "$confirm" =~ ^[Ss]$ ]] && return 0 || return 1
}

# Validar y confirmar una ruta
function prompt_for_path() {
    while true; do
        echo -ne "${CYAN}📁 ¿Dónde querés guardar el backup? (ej. /home/usuario/backups o D:\\Users\\usuario\\Downloads): ${NC}"
        read -r raw_path
        final_path=$(fix_windows_path "$raw_path")
        echo -e "${YELLOW}📂 Ruta convertida a WSL: ${BLUE}\"$final_path\"${NC}"
        confirm_path "$final_path" && echo "$final_path" && return
        echo -e "${RED}❌ Ruta cancelada. Intentá de nuevo.${NC}"
    done
}

# Verificar Docker
function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}❌ Docker no está instalado o no está en el PATH.${NC}"
        return 1
    fi
    return 0
}

# Backup
function backup() {
    check_docker || return
    BACKUP_DIR_PUBLIC=$(prompt_for_path)
    BACKUP_DIR_ROOT="/root/backups_docker"
    DATE=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="backup_$DATE"
    FULL_BACKUP_PATH="$BACKUP_DIR_ROOT/$BACKUP_NAME"

    mkdir -p "$BACKUP_DIR_ROOT" "$BACKUP_DIR_PUBLIC"

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

# Restaurar
function restore() {
    check_docker || return
    echo -ne "${CYAN}📁 ¿Desde qué carpeta querés restaurar el backup?: ${NC}"
    read -r raw_path
    restore_path=$(fix_windows_path "$raw_path")
    echo -e "${YELLOW}📂 Ruta convertida a WSL: ${BLUE}\"$restore_path\"${NC}"

    mapfile -t backups < <(ls -1 "$restore_path")
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}❌ No hay backups disponibles.${NC}"
        return
    fi

    echo -e "${YELLOW}Seleccione el backup a restaurar:${NC}"
    for i in "${!backups[@]}"; do
        echo -e "${BLUE}$((i+1))) ${backups[$i]}${NC}"
    done

    echo -ne "${CYAN}📝 Ingrese el número del backup: ${NC}"
    read -r option
    index=$((option-1))
    if [[ $index -lt 0 || $index -ge ${#backups[@]} ]]; then
        echo -e "${RED}❌ Opción inválida.${NC}"
        return
    fi

    RESTORE_NAME="${backups[$index]}"
    RESTORE_SRC="$restore_path/$RESTORE_NAME"
    RESTORE_TMP="/root/backups_docker/$RESTORE_NAME"

    echo -e "${YELLOW}📥 Copiando backup a /root...${NC}"
    cp -r "$RESTORE_SRC" "/root/backups_docker"

    echo -e "${CYAN}📦 Restaurando imágenes...${NC}"
    for tarfile in "$RESTORE_TMP/images/"*.tar; do
        docker load -i "$tarfile"
    done

    echo -e "${CYAN}💾 Restaurando volúmenes...${NC}"
    for archive in "$RESTORE_TMP/volumes/"*.tar.gz; do
        name=$(basename "$archive" .tar.gz)
        docker volume create "$name"
        docker run --rm -v "$name":/volume -v "$RESTORE_TMP/volumes":/backup alpine \
            sh -c "cd /volume && tar -xzf /backup/$name.tar.gz"
    done

    echo -e "${YELLOW}🧹 Limpiando temporales...${NC}"
    rm -rf "$RESTORE_TMP"
    echo -e "${GREEN}✅ Restauración completada.${NC}"
}

# Montar volúmenes
function mount_volumes() {
    check_docker || return
    echo -ne "${CYAN}🌐 Ruta donde montar los volúmenes: ${NC}"
    read -r raw_path
    mount_path=$(fix_windows_path "$raw_path")
    mkdir -p "$mount_path"
    echo -e "${CYAN}🔍 Montando volúmenes en: \"$mount_path\"${NC}"
    for volume in $(docker volume ls -q); do
        target="$mount_path/$volume"
        mkdir -p "$target"
        docker run --rm -v "$volume":/volume -v "$target":/copy alpine \
            sh -c "cp -a /volume/. /copy/ 2>/dev/null || true"
        chown -R $(whoami):$(whoami) "$target"
    done
    echo -e "${GREEN}✅ Montaje completado.${NC}"
}

# Menú
function menu() {
    while true; do
        echo -e "\n${BLUE}==== DOCKER BACKUP TOOL ==== ${NC}"
        echo -e "${YELLOW}1)${NC} Hacer backup completo"
        echo -e "${YELLOW}2)${NC} Restaurar backup"
        echo -e "${YELLOW}3)${NC} Montar volúmenes"
        echo -e "${YELLOW}4)${NC} Salir"
        echo -e "${BLUE}============================${NC}"
        echo -ne "${CYAN}Selecciona una opción [1-4]: ${NC}"
        read -r opcion
        case "$opcion" in
            1) backup ;;
            2) restore ;;
            3) mount_volumes ;;
            4) echo -e "${GREEN}👋 Saliendo...${NC}"; break ;;
            *) echo -e "${RED}❌ Opción no válida. Por favor elegí 1, 2, 3 o 4.${NC}" ;;
        esac
    done
}

menu
